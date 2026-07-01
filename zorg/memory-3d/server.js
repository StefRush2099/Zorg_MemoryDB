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

const graphSchema = process.env.ZORG_MEMORY_3D_DB_SCHEMA || "public";
const maxTables = Number(process.env.ZORG_MEMORY_3D_MAX_TABLES || 40);
const maxRowsPerTable = Number(process.env.ZORG_MEMORY_3D_MAX_ROWS_PER_TABLE || 12);
const maxActivityTables = Number(process.env.ZORG_MEMORY_3D_MAX_ACTIVITY_TABLES || 20);
const statementTimeoutMs = Number(process.env.ZORG_MEMORY_3D_STATEMENT_TIMEOUT_MS || 2500);
const tablePrefixes = splitList(process.env.ZORG_MEMORY_3D_TABLE_PREFIXES || "memory_,zorg_");

function splitList(value) {
  return String(value || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

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
  idleTimeoutMillis: 30000,
  statement_timeout: statementTimeoutMs,
  query_timeout: statementTimeoutMs + 500
});

app.use(express.json({ limit: "1mb" }));
app.use(express.static(path.join(__dirname, "public")));
app.use("/vendor/3d-force-graph", express.static(path.join(__dirname, "node_modules/3d-force-graph/dist")));

function textLabel(value, fallback = "unknown") {
  if (value === null || value === undefined || value === "") return fallback;
  const text = String(value).replace(/\s+/g, " ").trim();
  return text.length > 92 ? `${text.slice(0, 89)}...` : text;
}

function quoteIdent(value) {
  return `"${String(value).replace(/"/g, '""')}"`;
}

function quoteLiteral(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
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
  if (!source || !target || source === target) return;
  links.push({ source, target, type, value: Number(value || 1), ...extra });
}

function tableAllowed(tableName) {
  return tablePrefixes.length === 0 || tablePrefixes.some((prefix) => tableName.startsWith(prefix));
}

async function loadCatalog() {
  const result = await pool.query(
    `
      select
        c.table_name,
        json_agg(
          json_build_object(
            'name', c.column_name,
            'type', c.data_type,
            'ordinal', c.ordinal_position
          )
          order by c.ordinal_position
        ) as columns,
        coalesce(s.n_live_tup, 0)::int as estimated_rows
      from information_schema.columns c
      join information_schema.tables t
        on t.table_schema = c.table_schema
       and t.table_name = c.table_name
       and t.table_type = 'BASE TABLE'
      left join pg_stat_user_tables s
        on s.schemaname = c.table_schema
       and s.relname = c.table_name
      where c.table_schema = $1
      group by c.table_name, s.n_live_tup
      order by coalesce(s.n_live_tup, 0) desc, c.table_name asc
      limit $2
    `,
    [graphSchema, maxTables * 2]
  );

  return result.rows
    .filter((row) => tableAllowed(row.table_name))
    .slice(0, maxTables)
    .map((row) => ({
      name: row.table_name,
      columns: row.columns || [],
      estimatedRows: row.estimated_rows || 0
    }));
}

function findColumn(table, candidates) {
  const names = new Set(table.columns.map((column) => column.name));
  return candidates.find((candidate) => names.has(candidate)) || null;
}

function likelyLabelColumn(table) {
  return (
    findColumn(table, ["title", "name", "label", "summary", "description", "path", "key", "id"]) ||
    table.columns.find((column) => ["text", "character varying", "uuid", "integer", "bigint"].includes(column.type))?.name ||
    null
  );
}

function likelyTimeColumn(table) {
  return findColumn(table, [
    "updated_at",
    "created_at",
    "observed_at",
    "logged_at",
    "last_seen_at",
    "finished_at",
    "started_at",
    "inserted_at"
  ]);
}

function likelyIdColumn(table) {
  return findColumn(table, ["id", "uuid", "key"]) || likelyLabelColumn(table);
}

function referenceColumns(table) {
  return table.columns
    .filter((column) => /(^id$|_id$|_key$|_uuid$)/.test(column.name))
    .slice(0, 6)
    .map((column) => column.name);
}

async function tableCount(tableName) {
  const result = await pool.query(`select count(*)::int as count from ${quoteIdent(graphSchema)}.${quoteIdent(tableName)}`);
  return result.rows[0]?.count || 0;
}

async function loadRows(table) {
  const idColumn = likelyIdColumn(table);
  const labelColumn = likelyLabelColumn(table);
  const timeColumn = likelyTimeColumn(table);
  const refs = referenceColumns(table);
  const selectParts = [];

  if (idColumn) selectParts.push(`${quoteIdent(idColumn)}::text as row_id`);
  if (labelColumn && labelColumn !== idColumn) selectParts.push(`${quoteIdent(labelColumn)}::text as row_label`);
  if (timeColumn) selectParts.push(`${quoteIdent(timeColumn)}::timestamptz as row_time`);
  for (const ref of refs) {
    if (![idColumn, labelColumn, timeColumn].includes(ref)) selectParts.push(`${quoteIdent(ref)}::text as ${quoteIdent(`ref__${ref}`)}`);
  }

  if (selectParts.length === 0) return [];

  const result = await pool.query(
    `
      select ${selectParts.join(", ")}
      from ${quoteIdent(graphSchema)}.${quoteIdent(table.name)}
      ${timeColumn ? `order by ${quoteIdent(timeColumn)} desc` : ""}
      limit $1
    `,
    [maxRowsPerTable]
  );
  return result.rows;
}

function newestTimestamp(rows) {
  let newest = null;
  for (const row of rows) {
    if (!row.row_time) continue;
    const timestamp = new Date(row.row_time).getTime();
    if (!Number.isFinite(timestamp)) continue;
    if (!newest || timestamp > new Date(newest).getTime()) newest = row.row_time;
  }
  return newest;
}

function addRowGraph(nodes, links, table, row, queryText) {
  const recordKey = row.row_id || row.row_label || JSON.stringify(row);
  const rowId = `row:${table.name}:${recordKey}`;
  const rowLabel = row.row_label || row.row_id || table.name;
  const haystack = Object.values(row).join(" ").toLowerCase();
  const matchesQuery = queryText && haystack.includes(queryText.toLowerCase());

  addNode(nodes, rowId, matchesQuery ? "query" : "record", rowLabel, {
    table: table.name,
    lastSeen: row.row_time || null
  });
  addLink(links, `table:${table.name}`, rowId, "contains", 1);

  const refs = Object.entries(row).filter(([key, value]) => key.startsWith("ref__") && value);
  for (const [key, value] of refs) {
    const columnName = key.slice(5);
    const refId = `ref:${columnName}:${value}`;
    addNode(nodes, refId, "reference", value, { column: columnName });
    addLink(links, rowId, refId, columnName, 1.2);
  }

  if (refs.length >= 2) {
    const [firstKey, firstValue] = refs[0];
    const [secondKey, secondValue] = refs[1];
    addLink(links, `ref:${firstKey.slice(5)}:${firstValue}`, `ref:${secondKey.slice(5)}:${secondValue}`, table.name, 2);
  }

  if (matchesQuery) addLink(links, "manual-query", rowId, "matches", 3);
}

async function loadGraph(queryText = "") {
  const nodes = new Map();
  const links = [];
  const catalog = await loadCatalog();
  let sampledRows = 0;
  let inferredLinks = 0;

  addNode(nodes, "zorg-memorydb", "core", "Zorg MemoryDB", { val: 9 });
  addNode(nodes, "catalog", "core", "PostgreSQL catalog", { val: 6 });
  addLink(links, "zorg-memorydb", "catalog", "discovers", 4);

  if (queryText) {
    addNode(nodes, "manual-query", "manual-query", queryText, { val: 5 });
    addLink(links, "zorg-memorydb", "manual-query", "filters", 3);
  }

  for (const table of catalog) {
    const tableNode = `table:${table.name}`;
    addNode(nodes, tableNode, "table", table.name, {
      val: Math.max(2, Math.min(10, Math.log10(Math.max(1, table.estimatedRows)) + 2)),
      rows: table.estimatedRows,
      columns: table.columns.length
    });
    addLink(links, "catalog", tableNode, "table", Math.max(1, Math.min(6, table.columns.length / 3)));

    for (const column of table.columns.slice(0, 18)) {
      const columnNode = `column:${table.name}:${column.name}`;
      addNode(nodes, columnNode, "schema", column.name, { type: column.type });
      addLink(links, tableNode, columnNode, "column", 0.8);
    }

    try {
      const rows = await loadRows(table);
      sampledRows += rows.length;
      const latestRowSeen = newestTimestamp(rows);
      if (latestRowSeen) addNode(nodes, tableNode, "table", table.name, { lastSeen: latestRowSeen });
      const beforeLinks = links.length;
      for (const row of rows) addRowGraph(nodes, links, table, row, queryText);
      inferredLinks += links.length - beforeLinks;
    } catch {
      addNode(nodes, `table-error:${table.name}`, "activity", `${table.name} unavailable`);
      addLink(links, tableNode, `table-error:${table.name}`, "read error", 1);
    }
  }

  const stats = {
    tables: catalog.length,
    columns: catalog.reduce((total, table) => total + table.columns.length, 0),
    sampledRows,
    inferredLinks
  };

  return {
    nodes: Array.from(nodes.values()),
    links,
    stats,
    generatedAt: new Date().toISOString(),
    highlight: queryText ? { query: queryText, resultCount: nodes.size } : null
  };
}

async function loadActivity() {
  const catalog = await loadCatalog();
  const candidates = catalog
    .map((table) => ({
      table,
      timeColumn: likelyTimeColumn(table),
      labelColumn: likelyLabelColumn(table)
    }))
    .filter((item) => item.timeColumn)
    .slice(0, maxActivityTables);

  const rows = [];
  for (const candidate of candidates) {
    const labelExpr = candidate.labelColumn ? `${quoteIdent(candidate.labelColumn)}::text` : quoteLiteral(candidate.table.name);
    try {
      const result = await pool.query(
        `
          select
            ${quoteLiteral(candidate.table.name)} as kind,
            ${labelExpr} as title,
            ${quoteIdent(candidate.timeColumn)}::timestamptz as at
          from ${quoteIdent(graphSchema)}.${quoteIdent(candidate.table.name)}
          where ${quoteIdent(candidate.timeColumn)} is not null
          order by ${quoteIdent(candidate.timeColumn)} desc
          limit 8
        `
      );
      rows.push(...result.rows);
    } catch {
      // Schema discovery is best effort so one table cannot stop the feed.
    }
  }

  return rows
    .sort((a, b) => new Date(b.at || 0).getTime() - new Date(a.at || 0).getTime())
    .slice(0, 40)
    .map((row) => ({
      kind: textLabel(row.kind, "table"),
      title: textLabel(row.title, row.kind),
      detail: graphSchema,
      at: row.at
    }));
}

app.get("/api/health", async (_req, res) => {
  const started = Date.now();
  try {
    const db = await pool.query("select now() as now");
    const catalog = await loadCatalog();
    res.json({
      ok: true,
      dbTime: db.rows[0]?.now,
      schema: graphSchema,
      tables: catalog.length,
      latencyMs: Date.now() - started
    });
  } catch (error) {
    res.status(503).json({ ok: false, error: error.message });
  }
});

app.get("/api/graph", async (req, res) => {
  try {
    res.json(await loadGraph(String(req.query.q || "").trim()));
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

const server = app.listen(port, () => {
  console.log(`Zorg Memory 3D listening on http://127.0.0.1:${port}`);
});

const wss = new WebSocketServer({ server, path: "/ws" });
wss.on("connection", (socket) => {
  const timer = setInterval(async () => {
    if (socket.readyState !== socket.OPEN) return;
    try {
      socket.send(JSON.stringify({ type: "activity", data: await loadActivity() }));
    } catch {
      // The HTTP polling path remains active when websocket updates fail.
    }
  }, 5000);
  socket.on("close", () => clearInterval(timer));
});
