import pg from "pg";
export declare function query<T extends pg.QueryResultRow = pg.QueryResultRow>(text: string, values?: unknown[]): Promise<T[]>;
export declare function recallPreflight(queryText: string, limit: number): Promise<import("pg").QueryResultRow[]>;
declare const plugin: any;
export default plugin;
