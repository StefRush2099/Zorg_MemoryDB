import express from "express";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { WebSocketServer } from "ws";
import pg from "pg";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const port = Number(process.env.PORT || 8097);
const { Pool } = pg;

function readJson(pathname) {
  try {
    return JSON.parse(fs.readFileSync(pathname, "utf8"));
  } catch {
    return null;
  }
}

function loadDbConfig() {
  if (process.env.DATABASE_URL) return { connectionString: process.env.DATABASE_URL };

  const configuredMap = process.env.ZORG_MEMORY_MAP || process.env.SQL_MEMORY_MAP;
  const candidates = [
    configuredMap,
    process.env.OPENCLAW_WORKSPACE && path.join(process.env.OPENCLAW_WORKSPACE, "sql_memory_map.json"),
    process.env.OPENCLAW_WORKSPACE_DIR && path.join(process.env.OPENCLAW_WORKSPACE_DIR, "sql_memory_map.json"),
    path.join(os.homedir(), ".openclaw", "workspace", "sql_memory_map.json"),
    "/home/openclaw/.openclaw/workspace/sql_memory_map.json",
    "/home/node/.openclaw/workspace/sql_memory_map.json"
  ].filter(Boolean);

  for (const candidate of candidates) {
    const config = readJson(candidate);
    if (config?.postgres) {
      const pgConfig = config.postgres;
      return {
        host: pgConfig.host,
        port: Number(pgConfig.port || 5432),
        database: pgConfig.database,
        user: pgConfig.user,
        password: pgConfig.password
      };
    }
  }

  return {
    host: process.env.PGHOST || process.env.ZORG_DB_HOST || "127.0.0.1",
    port: Number(process.env.PGPORT || process.env.ZORG_DB_PORT || 5432),
    database: process.env.PGDATABASE || process.env.ZORG_DB_NAME || "zorgdb",
    user: process.env.PGUSER || process.env.ZORG_DB_USER || "zorg",
    password: process.env.PGPASSWORD || process.env.ZORG_DB_PASSWORD
  };
}

const pool = new Pool({
  ...loadDbConfig(),
  max: 8,
  idleTimeoutMillis: 30000
});

app.use(express.json({ limit: "1mb" }));
app.use(express.static(path.join(__dirname, "public")));
app.use("/vendor/3d-force-graph", express.static(path.join(__dirname, "node_modules/3d-force-graph/dist")));

function textLabel(value, fallback = "unknown") {
  if (value === null || value === undefined || value === "") return fallback;
  const text = String(value).replace(/\s+/g, " ").trim();
  return text.length > 92 ? `${text.slice(0, 89)}...` : text;
}

function addNode(map, id, group, label, extra = {}) {
  if (!id) return;
  if (!map.has(id)) {
    map.set(id, { id, group, label: textLabel(label || id), val: 1, ...extra });
    return;
  }
  const current = map.get(id);
  current.val = Math.min(14, (current.val || 1) + 0.4);
  if (extra.lastSeen && (!current.lastSeen || extra.lastSeen > current.lastSeen)) current.lastSeen = extra.lastSeen;
}

function addLink(links, source, target, type, value = 1, extra = {}) {
  if (!source || !target) return;
  links.push({ source, target, type, value: Number(value || 1), ...extra });
}

async function tableExists(tableName) {
  const result = await pool.query("select to_regclass($1) as table_name", [`public.${tableName}`]);
  return Boolean(result.rows[0]?.table_name);
}

async function tableColumns(tableName) {
  if (!(await tableExists(tableName))) return new Set();
  const result = await pool.query(
    `
      select column_name
      from information_schema.columns
      where table_schema = 'public' and table_name = $1
    `,
    [tableName]
  );
  return new Set(result.rows.map((row) => row.column_name));
}

async function optionalQuery(tableName, sql, params = []) {
  if (!(await tableExists(tableName))) return { rows: [], rowCount: 0 };
  return pool.query(sql, params);
}

async function loadSemanticNodes() {
  return optionalQuery("memory_semantic_nodes", `
    select node_key, node_type, canonical_label, confidence, updated_at
    from memory_semantic_nodes
    where active is distinct from false
    order by updated_at desc nulls last, created_at desc nulls last
    limit 180
  `);
}

async function loadRecallHints() {
  const columns = await tableColumns("memory_recall_hints");
  if (columns.has("source_type") && columns.has("source_key")) {
    return pool.query(`
      select source_type, source_key, hint_kind, hint_text, weight, updated_at
      from memory_recall_hints
      where active is distinct from false
      order by updated_at desc nulls last, created_at desc nulls last
      limit 140
    `);
  }
  if (columns.has("target_table")) {
    return pool.query(`
      select target_table as source_type,
             coalesce(target_key, query_pattern) as source_key,
             query_pattern as hint_kind,
             hint_text,
             weight,
             created_at as updated_at
      from memory_recall_hints
      order by created_at desc
      limit 140
    `);
  }
  return { rows: [], rowCount: 0 };
}

async function loadQueryObservations() {
  if (await tableExists("memory_query_observations")) {
    return pool.query(`
      select query_text, query_intent, source_type, source_key, rank_seen, usefulness_score, observed_at
      from memory_query_observations
      order by observed_at desc
      limit 130
    `);
  }
  if (await tableExists("query_observations")) {
    return pool.query(`
      select query_text,
             'recall' as query_intent,
             coalesce(matched_source, 'query') as source_type,
             coalesce(matched_source, query_text) as source_key,
             null::integer as rank_seen,
             coalesce(result_count, 1)::numeric as usefulness_score,
             observed_at
      from query_observations
      order by observed_at desc
      limit 130
    `);
  }
  return { rows: [], rowCount: 0 };
}

async function loadLogicRules() {
  const columns = await tableColumns("zorg_logic_rules");
  if (columns.has("title")) {
    return pool.query(`
      select rule_key, title, rule_type, priority, updated_at
      from zorg_logic_rules
      where active is distinct from false
      order by updated_at desc nulls last, created_at desc nulls last
      limit 80
    `);
  }
  if (columns.has("rule_title")) {
    return pool.query(`
      select rule_key, rule_title as title, rule_type, priority, updated_at
      from zorg_logic_rules
      where active is distinct from false
      order by updated_at desc nulls last, created_at desc nulls last
      limit 80
    `);
  }
  return { rows: [], rowCount: 0 };
}

async function countTable(tableName, whereClause = "") {
  if (!(await tableExists(tableName))) return 0;
  const result = await pool.query(`select count(*)::int as count from ${tableName}${whereClause}`);
  return result.rows[0]?.count || 0;
}

async function loadTableCounts() {
  return {
    rows: [
      { label: "memories", count: await countTable("zorg_memory") },
      { label: "semantic edges", count: await countTable("memory_semantic_edges", " where active is distinct from false") },
      { label: "recall hints", count: await countTable("memory_recall_hints") },
      {
        label: "query observations",
        count: (await countTable("memory_query_observations")) || (await countTable("query_observations"))
      },
      { label: "logic rules", count: await countTable("zorg_logic_rules", " where active is distinct from false") },
      { label: "scheduled jobs", count: await countTable("memory_llm_job_queue") }
    ]
  };
}

async function loadGraph(queryText = "") {
  const [
    semanticEdges,
    semanticNodes,
    recallHints,
    queryObservations,
    neuralResults,
    logicRules,
    dynamicWeights,
    relationships,
    jobs,
    timings,
    tableCounts
  ] = await Promise.all([
    optionalQuery("memory_semantic_edges", `
        select subject_type, subject_key, relation, object_type, object_key, weight, weight_basis, updated_at
        from memory_semantic_edges
        where active is distinct from false
        order by updated_at desc nulls last, created_at desc nulls last
        limit 260
      `),
    loadSemanticNodes(),
    loadRecallHints(),
    loadQueryObservations(),
    optionalQuery("memory_neural_query_results", `
        select query_hash, query_text, source_type, source_key, result_rank, total_score, last_seen_at
        from memory_neural_query_results
        where active_for_latest is distinct from false
        order by last_seen_at desc nulls last, observed_at desc nulls last
        limit 150
      `),
    loadLogicRules(),
    optionalQuery("zorg_logic_rule_dynamic_weights", `
        select rule_key, dynamic_weight, use_count, last_recalled_at
        from zorg_logic_rule_dynamic_weights
        order by last_recalled_at desc nulls last, updated_at desc nulls last
        limit 80
      `),
    optionalQuery("memory_relationships", `
        select subject_type, subject_key, relation, object_type, object_key, created_at
        from memory_relationships
        order by created_at desc
        limit 160
      `),
    optionalQuery("memory_llm_job_queue", `
        select job_key, status, due_at, started_at, finished_at, attempts, updated_at
        from memory_llm_job_queue
        order by updated_at desc nulls last, created_at desc
        limit 60
      `),
    optionalQuery("memory_runtime_timing_observations", `
        select observation_kind, source_key, duration_ms, queue_wait_ms, processed_count, backlog_count, observed_at
        from memory_runtime_timing_observations
        order by observed_at desc
        limit 80
      `),
    loadTableCounts()
  ]);

    const nodes = new Map();
    const links = [];
    addNode(nodes, "zorg-memorydb", "core", "Zorg MemoryDB", { val: 10 });
    addNode(nodes, "live-activity", "activity", "Live activity", { val: 7 });
    addNode(nodes, "recall-engine", "query", "Recall engine", { val: 8 });

    for (const row of semanticNodes.rows) {
      addNode(nodes, `node:${row.node_key}`, row.node_type || "semantic", row.canonical_label || row.node_key, {
        confidence: row.confidence,
        lastSeen: row.updated_at
      });
      addLink(links, "zorg-memorydb", `node:${row.node_key}`, "semantic node", row.confidence || 1);
    }

    for (const row of semanticEdges.rows) {
      const source = `${row.subject_type || "source"}:${row.subject_key}`;
      const target = `${row.object_type || "target"}:${row.object_key}`;
      addNode(nodes, source, row.subject_type || "semantic", row.subject_key, { lastSeen: row.updated_at });
      addNode(nodes, target, row.object_type || "semantic", row.object_key, { lastSeen: row.updated_at });
      addLink(links, source, target, row.relation || "semantic edge", row.weight || 1, {
        reason: row.weight_basis,
        lastSeen: row.updated_at
      });
    }

    for (const row of relationships.rows) {
      const source = `${row.subject_type || "subject"}:${row.subject_key}`;
      const target = `${row.object_type || "object"}:${row.object_key}`;
      addNode(nodes, source, row.subject_type || "relationship", row.subject_key, { lastSeen: row.created_at });
      addNode(nodes, target, row.object_type || "relationship", row.object_key, { lastSeen: row.created_at });
      addLink(links, source, target, row.relation || "relationship", 1.2, { lastSeen: row.created_at });
    }

    for (const row of recallHints.rows) {
      const source = `${row.source_type || "hint-source"}:${row.source_key}`;
      const hintId = `hint:${row.source_key}:${row.hint_kind || "hint"}`;
      addNode(nodes, source, row.source_type || "memory", row.source_key, { lastSeen: row.updated_at });
      addNode(nodes, hintId, "hint", row.hint_text || row.hint_kind, { val: 2, lastSeen: row.updated_at });
      addLink(links, "recall-engine", hintId, "recall hint", row.weight || 1);
      addLink(links, hintId, source, row.hint_kind || "points to", row.weight || 1, { lastSeen: row.updated_at });
    }

    for (const row of queryObservations.rows) {
      const queryId = `query:${Buffer.from(row.query_text || "").toString("base64").slice(0, 36)}`;
      const source = `${row.source_type || "result"}:${row.source_key}`;
      addNode(nodes, queryId, "query", row.query_text, { val: 3, intent: row.query_intent, lastSeen: row.observed_at });
      addNode(nodes, source, row.source_type || "result", row.source_key, { lastSeen: row.observed_at });
      addLink(links, "recall-engine", queryId, "observed query", 2, { lastSeen: row.observed_at });
      addLink(links, queryId, source, `rank ${row.rank_seen ?? "?"}`, row.usefulness_score || 1, { lastSeen: row.observed_at });
    }

    for (const row of neuralResults.rows) {
      const queryId = `neural:${row.query_hash}`;
      const source = `${row.source_type || "result"}:${row.source_key}`;
      addNode(nodes, queryId, "neural", row.query_text, { val: 4, lastSeen: row.last_seen_at });
      addNode(nodes, source, row.source_type || "result", row.source_key, { lastSeen: row.last_seen_at });
      addLink(links, queryId, source, `ANN rank ${row.result_rank ?? "?"}`, row.total_score || 1, { lastSeen: row.last_seen_at });
      addLink(links, "recall-engine", queryId, "neural result", 2.5);
    }

    for (const row of logicRules.rows) {
      const id = `rule:${row.rule_key}`;
      addNode(nodes, id, "rule", row.title || row.rule_key, {
        val: row.priority === "critical" ? 7 : 4,
        priority: row.priority,
        ruleType: row.rule_type,
        lastSeen: row.updated_at
      });
      addLink(links, "zorg-memorydb", id, "governs", row.priority === "critical" ? 4 : 2);
    }

    for (const row of dynamicWeights.rows) {
      const id = `rule:${row.rule_key}`;
      addNode(nodes, id, "rule", row.rule_key, { lastSeen: row.last_recalled_at });
      addLink(links, "recall-engine", id, "dynamic weight", row.dynamic_weight || 1, {
        useCount: row.use_count,
        lastSeen: row.last_recalled_at
      });
    }

    for (const row of jobs.rows) {
      const id = `job:${row.job_key}:${row.status}`;
      addNode(nodes, id, "job", `${row.job_key} (${row.status})`, { val: 3, status: row.status, lastSeen: row.updated_at });
      addLink(links, "live-activity", id, "queued work", row.status === "failed" ? 4 : 1.5, { lastSeen: row.updated_at });
    }

    for (const row of timings.rows) {
      const id = `timing:${row.observation_kind}:${row.source_key}`;
      addNode(nodes, id, "timing", `${row.observation_kind}: ${row.source_key}`, {
        val: Math.max(1, Math.min(8, Number(row.duration_ms || 0) / 200)),
        durationMs: row.duration_ms,
        queueWaitMs: row.queue_wait_ms,
        backlog: row.backlog_count,
        lastSeen: row.observed_at
      });
      addLink(links, "live-activity", id, "timing", Math.max(1, Number(row.duration_ms || 1) / 100), { lastSeen: row.observed_at });
    }

    let highlight = null;
    if (queryText.trim()) {
      const recallFunction = await pool.query("select to_regprocedure('public.zorg_recall_context(text, integer)') as recall_function");
      const recall = recallFunction.rows[0]?.recall_function
        ? await pool.query("select * from zorg_recall_context($1, 18)", [queryText.trim()])
        : { rows: [], rowCount: 0 };
      const queryId = `manual:${Date.now()}`;
      addNode(nodes, queryId, "manual-query", queryText.trim(), { val: 8, lastSeen: new Date().toISOString() });
      addLink(links, "recall-engine", queryId, "manual recall", 5);
      recall.rows.forEach((row, index) => {
        const key = row.source_id || row.id || row.key || row.path || JSON.stringify(row).slice(0, 40);
        const type = row.source_type || row.table_name || "recall-result";
        const id = `${type}:${key}`;
        addNode(nodes, id, type, row.content || row.memory_key || key, { val: Math.max(2, 8 - index * 0.25) });
        addLink(links, queryId, id, `recall #${index + 1}`, Math.max(1, 10 - index));
      });
      highlight = { query: queryText.trim(), resultCount: recall.rowCount };
    }

    return {
      generatedAt: new Date().toISOString(),
      stats: Object.fromEntries(tableCounts.rows.map((row) => [row.label, row.count])),
      highlight,
      nodes: [...nodes.values()],
      links
    };
}

async function loadActivity() {
  const sources = [];
  if (await tableExists("app_query_log")) {
    sources.push(`
      select logged_at as at, 'query' as kind, query_label as title,
             coalesce(query_text, row_count::text, 'query') as detail
      from app_query_log
    `);
  }
  if (await tableExists("app_activity_events")) {
    sources.push(`
      select created_at as at, activity_type as kind, activity_key as title, 'activity event' as detail
      from app_activity_events
    `);
  }
  if (await tableExists("memory_llm_job_queue")) {
    sources.push(`
      select updated_at as at, status as kind, job_key as title,
             coalesce(result_summary, error_text, 'queued job') as detail
      from memory_llm_job_queue
    `);
  }
  if (await tableExists("memory_runtime_timing_observations")) {
    sources.push(`
      select observed_at as at, observation_kind as kind, source_key as title,
             concat('duration ', coalesce(duration_ms::text, '?'), ' ms, backlog ', coalesce(backlog_count::text, '0')) as detail
      from memory_runtime_timing_observations
    `);
  }
  if (sources.length === 0) return [];
  const result = await pool.query(`
    select *
    from (${sources.join("\nunion all\n")}) events
    where at is not null
    order by at desc
    limit 50
  `);
  return result.rows.map((row) => ({
    at: row.at,
    kind: row.kind,
    title: textLabel(row.title, "event"),
    detail: textLabel(row.detail, "")
  }));
}

app.get("/api/health", async (_req, res) => {
  try {
    const result = await pool.query("select now() as now");
    res.json({ ok: true, dbTime: result.rows[0].now });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.get("/api/graph", async (req, res) => {
  try {
    res.json(await loadGraph(String(req.query.q || "")));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/activity", async (_req, res) => {
  try {
    res.json(await loadActivity());
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const server = app.listen(port, "0.0.0.0", () => {
  console.log(`Zorg Memory 3D listening on ${port}`);
});

const wss = new WebSocketServer({ server, path: "/ws" });
wss.on("connection", (socket) => {
  let closed = false;
  const send = async () => {
    if (closed || socket.readyState !== socket.OPEN) return;
    try {
      socket.send(JSON.stringify({ type: "activity", data: await loadActivity() }));
    } catch (error) {
      socket.send(JSON.stringify({ type: "error", error: error.message }));
    }
  };
  const timer = setInterval(send, 5000);
  socket.on("close", () => {
    closed = true;
    clearInterval(timer);
  });
  send();
});
