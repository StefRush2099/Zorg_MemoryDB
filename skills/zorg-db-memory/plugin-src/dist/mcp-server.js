import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import pg from "pg";
import { z } from "zod";
const { Pool } = pg;
let pool;
async function getPool() {
    if (pool)
        return pool;
    const workspace = process.env.OPENCLAW_WORKSPACE || process.env.WORKSPACE_DIR || resolve(process.env.HOME || ".", ".openclaw/workspace");
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
const server = new McpServer({ name: "zorg-memorydb", version: "4.0.0" });
server.registerTool("memory_health", { description: "Check PostgreSQL MemoryDB connectivity.", inputSchema: {} }, async () => ({ content: [{ type: "text", text: JSON.stringify(await query("select current_database() as database, current_user as user, now() as server_time")) }] }));
server.registerTool("memory_tables", { description: "List canonical MemoryDB tables.", inputSchema: {} }, async () => ({ content: [{ type: "text", text: JSON.stringify(await query("select table_name from public.memory_tables_v1()")) }] }));
server.registerTool("memory_search", { description: "Search canonical structured MemoryDB records.", inputSchema: { query: z.string().min(1), limit: z.number().int().min(1).max(50).optional() } }, async ({ query: q, limit = 10 }) => ({ content: [{ type: "text", text: JSON.stringify(await query("select row_data from public.memory_search_table_v1('all', $1, $2)", [q, limit])) }] }));
server.registerTool("memory_recent", { description: "Return recent canonical MemoryDB context.", inputSchema: { limit: z.number().int().min(1).max(100).optional() } }, async ({ limit = 20 }) => ({ content: [{ type: "text", text: JSON.stringify(await query("select row_data from public.memory_recent_v1($1)", [limit])) }] }));
server.registerTool("memory_master_context", { description: "Return canonical MemoryDB master context.", inputSchema: { limit: z.number().int().min(1).max(100).optional() } }, async ({ limit = 40 }) => ({ content: [{ type: "text", text: JSON.stringify(await query("select row_data from public.memory_master_context_v1($1)", [limit])) }] }));
server.registerTool("memory_ann_status", { description: "Inspect additive semantic/ANN queue, embedding, and failure counts.", inputSchema: {} }, async () => ({ content: [{ type: "text", text: JSON.stringify(await query(`select (select count(*) from public.memory_ann_model_embeddings where active) as active_embeddings, (select count(*) from public.memory_semantic_work_queue where status = 'queued') as queued_jobs, (select count(*) from public.memory_semantic_work_queue where status = 'failed') as failed_jobs, (select count(*) from public.memory_query_embedding_cache) as cached_queries`)) }] }));
server.registerTool("memory_recall_preflight", { description: "Run canonical core-rule preflight before normal recall.", inputSchema: { query: z.string().min(1), limit: z.number().int().min(1).max(50).optional() } }, async ({ query: q, limit = 10 }) => ({ content: [{ type: "text", text: JSON.stringify(await query("select row_data from public.memory_search_table_v1('all', $1, $2)", [q, limit])) }] }));
await server.connect(new StdioServerTransport());
