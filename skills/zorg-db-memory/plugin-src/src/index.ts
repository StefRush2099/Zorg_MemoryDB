import { Type } from "typebox";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import pg from "pg";
import { defineToolPlugin } from "openclaw/plugin-sdk/tool-plugin";

const { Pool } = pg;

type DbConfig = { postgres: { host: string; port: number; database: string; user: string; password: string } };
let pool: pg.Pool | undefined;

const workspaceRoot = () => process.env.OPENCLAW_WORKSPACE || process.env.WORKSPACE_DIR || resolve(process.env.HOME || ".", ".openclaw/workspace");

async function getPool() {
  if (pool) return pool;
  const workspace = workspaceRoot();
  const explicitMap = process.env.SQL_MEMORY_MAP || process.env.ZORG_SQL_MEMORY_MAP;
  const candidates = explicitMap
    ? [explicitMap]
    : [
        resolve(workspace, "skills/zorg-db-memory/config/sql_memory_map.json"),
        resolve(workspace, "sql_memory_map.json"),
      ];
  let cfg: DbConfig | undefined;
  let lastError: unknown;
  for (const mapPath of candidates) {
    try {
      cfg = JSON.parse(await readFile(mapPath, "utf8")) as DbConfig;
      break;
    } catch (error) {
      lastError = error;
    }
  }
  if (!cfg) throw lastError;
  pool = new Pool(cfg.postgres);
  return pool;
}

async function query<T extends pg.QueryResultRow = pg.QueryResultRow>(text: string, values: unknown[] = []) {
  const client = await (await getPool()).connect();
  try { return (await client.query<T>(text, values)).rows; } finally { client.release(); }
}

type EmbeddingSlot = { embedding_provider: string; embedding_model: string; embedding_dim: number; endpoint: string };

async function ensureQueryEmbedding(queryText: string) {
  const [slot] = await query<EmbeddingSlot>(`select embedding_provider,embedding_model,embedding_dim,endpoint
    from public.memory_embedding_model_slots where enabled and is_default order by updated_at desc limit 1`);
  if (!slot?.endpoint) return null;
  const [cached] = await query(`select 1 from public.memory_query_embedding_cache
    where active and query_hash=md5(lower(btrim($1))) and embedding_provider=$2 and embedding_model=$3 limit 1`,
    [queryText, slot.embedding_provider, slot.embedding_model]);
  if (cached) return slot;
  const response = await fetch(slot.endpoint, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ model: slot.embedding_model, input: queryText }),
    signal: AbortSignal.timeout(120000),
  });
  if (!response.ok) throw new Error(`embedding endpoint failed: ${response.status}`);
  const payload = await response.json() as { embeddings?: number[][] };
  const vector = payload.embeddings?.[0];
  if (!vector || vector.length !== Number(slot.embedding_dim)) throw new Error("embedding dimension mismatch");
  await query(`insert into public.memory_query_embedding_cache
    (query_hash,query_text,embedding_provider,embedding_model,embedding_dim,embedding,metadata,active)
    values(md5(lower(btrim($1))),$1,$2,$3,$4,$5::vector,'{"source":"zorg-memorydb-plugin-preflight"}'::jsonb,true)
    on conflict(query_hash,embedding_provider,embedding_model) do update
    set query_text=excluded.query_text,embedding=excluded.embedding,active=true,updated_at=now()`,
    [queryText, slot.embedding_provider, slot.embedding_model, slot.embedding_dim, `[${vector.join(",")}]`]);
  return slot;
}

async function recallPreflight(queryText: string, limit: number) {
  const slot = await ensureQueryEmbedding(queryText);
  const context = { mode: "deep", embedding_provider: slot?.embedding_provider || "local", embedding_model: slot?.embedding_model || "nomic-embed-text:latest", caller: "zorg-memorydb-plugin" };
  return query("select * from public.memory_recall_v2($1,$2,$3::jsonb)", [queryText, limit, JSON.stringify(context)]);
}

export default defineToolPlugin({
  id: "zorg-memorydb",
  name: "Zorg MemoryDB",
  description: "Typed PostgreSQL access to the canonical Zorg MemoryDB.",
  tools: (tool) => [
    tool({
      name: "memory_health",
      description: "Check PostgreSQL connectivity and return the database identity.",
      parameters: Type.Object({}),
      execute: async () => ({ rows: await query("select current_database() as database, current_user as user, now() as server_time") }),
    }),
    tool({
      name: "memory_tables",
      description: "List the canonical MemoryDB search tables exposed by the database.",
      parameters: Type.Object({}),
      execute: async () => ({ rows: await query("select table_name from public.memory_tables_v1()") }),
    }),
    tool({
      name: "memory_search",
      description: "Search canonical structured MemoryDB records through the approved database function.",
      parameters: Type.Object({ query: Type.String({ minLength: 1 }), limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 50 })) }),
      execute: async ({ query: q, limit = 10 }) => ({ rows: await query("select row_data from public.memory_search_table_v1('all', $1, $2)", [q, limit]) }),
    }),
    tool({
      name: "memory_recent",
      description: "Return recent canonical MemoryDB context rows.",
      parameters: Type.Object({ limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100 })) }),
      execute: async ({ limit = 20 }) => ({ rows: await query("select row_data from public.memory_recent_v1($1)", [limit]) }),
    }),
    tool({
      name: "memory_master_context",
      description: "Return the canonical master context assembled by MemoryDB.",
      parameters: Type.Object({ limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100 })) }),
      execute: async ({ limit = 40 }) => ({ rows: await query("select row_data from public.memory_master_context_v1($1)", [limit]) }),
    }),
    tool({
      name: "memory_graph",
      description: "Return a paginated semantic node/edge graph with complete live totals.",
      parameters: Type.Object({ limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 5000 })), offset: Type.Optional(Type.Integer({ minimum: 0 })) }),
      execute: async ({ limit = 1000, offset = 0 }) => ({ rows: await query(`with selected as (
        select node_key,node_type,canonical_label,description,confidence,updated_at
        from public.memory_semantic_nodes where active
        order by confidence desc nulls last, updated_at desc, node_key
        limit $1 offset $2
      ), graph_edges as (
        select e.subject_key,e.object_key,e.relation,e.weight
        from public.memory_semantic_edges e join selected s on s.node_key=e.subject_key join selected o on o.node_key=e.object_key
        where e.active order by e.weight desc nulls last limit 20000
      ) select jsonb_build_object(
        'nodes',(select coalesce(jsonb_agg(to_jsonb(s) order by s.confidence desc nulls last,s.updated_at desc),'[]'::jsonb) from selected s),
        'links',(select coalesce(jsonb_agg(to_jsonb(e) order by e.weight desc nulls last),'[]'::jsonb) from graph_edges e),
        'totalNodes',(select count(*) from public.memory_semantic_nodes where active),
        'totalLinks',(select count(*) from public.memory_semantic_edges where active),'offset',$2,'limit',$1) as graph`, [limit, offset]) }),
    }),
    tool({
      name: "memory_ann_status",
      description: "Inspect additive semantic/ANN queue, embedding, and failure counts without changing source memory.",
      parameters: Type.Object({}),
      execute: async () => ({ rows: await query(`select
        (select count(*) from public.memory_ann_model_embeddings where active) as active_embeddings,
        (select count(*) from public.memory_semantic_work_queue where status = 'queued') as queued_jobs,
        (select count(*) from public.memory_semantic_work_queue where status in ('failed','error')) as failed_jobs,
        (select count(*) from public.memory_query_embedding_cache where active) as cached_queries,
        (select embedding_model from public.memory_embedding_model_slots where enabled and is_default order by updated_at desc limit 1) as default_model,
        (select count(*) from public.memory_ann_model_embeddings e where e.active and e.embedding_model=(select embedding_model from public.memory_embedding_model_slots where enabled and is_default order by updated_at desc limit 1)) as default_active_embeddings,
        (select count(*) from (select source_type,source_key,embedding_provider,embedding_model from public.memory_ann_model_embeddings where active group by 1,2,3,4 having count(*)>1) d) as duplicate_active_identities,
        (select count(*) from public.memory_ann_model_embeddings where active and vector_norm(embedding)=0) as zero_norm_vectors,
        (select count(*) from pg_index i join pg_class c on c.oid=i.indexrelid where c.relname like 'idx_memory_ann_model_embeddings_hnsw%' and i.indisvalid and i.indisready) as valid_hnsw_indexes`), }),
    }),
    tool({
      name: "memory_recall_preflight",
      description: "Run the canonical rank-one core-rule preflight before normal structured or ANN recall.",
      parameters: Type.Object({ query: Type.String({ minLength: 1 }), limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 50 })) }),
      execute: async ({ query: q, limit = 10 }) => ({ rows: await recallPreflight(q, limit) }),
    }),
  ],
});
