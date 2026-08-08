import type pg from "pg";
import type { OpenClawPluginApi } from "openclaw/plugin-sdk";
export type QueryFn = <T extends pg.QueryResultRow = pg.QueryResultRow>(sql: string, values?: unknown[]) => Promise<T[]>;
export type RecallFn = (text: string, limit: number) => Promise<pg.QueryResultRow[]>;
export declare function registerZorgMemoryHooks(api: OpenClawPluginApi, deps: {
    query: QueryFn;
    recall: RecallFn;
}): void;
