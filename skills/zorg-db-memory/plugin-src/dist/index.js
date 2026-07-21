import { Type } from "typebox";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import pg from "pg";
import { defineToolPlugin } from "openclaw/plugin-sdk/tool-plugin";
const { Pool } = pg;
let pool;
const workspaceRoot = () => process.env.OPENCLAW_WORKSPACE || process.env.WORKSPACE_DIR || resolve(process.env.HOME || ".", ".openclaw/workspace");
async function getPool() {
    if (pool)
        return pool;
    const workspace = workspaceRoot();
    const mapPath = process.env.SQL_MEMORY_MAP || process.env.ZORG_SQL_MEMORY_MAP || resolve(workspace, "skills/zorg-db-memory/config/sql_memory_map.json");
    const cfg = JSON.parse(await readFile(mapPath, "utf8"));
    pool = new Pool(cfg.postgres);
    return pool;
}
async function query(text, values = []) {
    const client = await (await getPool()).connect();
    try {
        return (await client.query(text, values)).rows;
    }
    finally {
        client.release();
    }
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
            name: "memory_ann_status",
            description: "Inspect additive semantic/ANN queue, embedding, and failure counts without changing source memory.",
            parameters: Type.Object({}),
            execute: async () => ({ rows: await query(`select
        (select count(*) from public.memory_ann_model_embeddings where active) as active_embeddings,
        (select count(*) from public.memory_semantic_work_queue where status = 'queued') as queued_jobs,
        (select count(*) from public.memory_semantic_work_queue where status = 'failed') as failed_jobs,
        (select count(*) from public.memory_query_embedding_cache) as cached_queries`), }),
        }),
        tool({
            name: "memory_recall_preflight",
            description: "Run the canonical rank-one core-rule preflight before normal structured or ANN recall.",
            parameters: Type.Object({ query: Type.String({ minLength: 1 }), limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 50 })) }),
            execute: async ({ query: q, limit = 10 }) => ({ rows: await query("select row_data from public.memory_search_table_v1('all', $1, $2)", [q, limit]) }),
        }),
    ],
});
