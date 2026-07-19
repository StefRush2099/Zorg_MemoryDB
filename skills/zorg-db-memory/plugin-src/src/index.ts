import { Type } from "typebox";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import pg from "pg";
import { defineToolPlugin } from "openclaw/plugin-sdk/tool-plugin";

const { Pool } = pg;

type DbConfig = { postgres: { host: string; port: number; database: string; user: string; password: string } };
let pool: pg.Pool | undefined;

async function getPool() {
  if (pool) return pool;
  const workspace = process.env.OPENCLAW_WORKSPACE || process.env.WORKSPACE_DIR || resolve(process.env.HOME || ".", ".openclaw/workspace");
  const mapPath = process.env.SQL_MEMORY_MAP || process.env.ZORG_SQL_MEMORY_MAP || resolve(workspace, "skills/zorg-db-memory/config/sql_memory_map.json");
  const cfg = JSON.parse(await readFile(mapPath, "utf8")) as DbConfig;
  pool = new Pool(cfg.postgres);
  return pool;
}

async function query<T extends pg.QueryResultRow = pg.QueryResultRow>(text: string, values: unknown[] = []) {
  const client = await (await getPool()).connect();
  try { return (await client.query<T>(text, values)).rows; } finally { client.release(); }
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
  ],
});
