#!/usr/bin/env python3
import argparse, json, os
from pathlib import Path
from typing import List
import psycopg2
from psycopg2.extras import RealDictCursor
from memory_recall_router import search_structured_db

BASE = Path(os.environ.get("OPENCLAW_WORKSPACE", Path.cwd()))
MAP_PATH = Path(os.environ.get("SQL_MEMORY_MAP", BASE / "sql_memory_map.json"))

def load_cfg(path: Path = MAP_PATH):
    with open(path, "r", encoding="utf-8") as f: return json.load(f)

def connect(cfg):
    p = cfg["postgres"]
    return psycopg2.connect(host=p["host"], port=p["port"], dbname=p["database"], user=p["user"], password=p.get("password", ""))

def mapped_tables(cfg) -> List[str]: return sorted(set(cfg["table_map"].values()))

def search(cur, table: str, q: str, limit: int = 10):
    if table == "all":
        return search_structured_db(q, limit)["structured"]

    routes = {"project":"zorg_get_project_context", "host":"zorg_get_host_context", "runbook":"zorg_get_runbook_context"}
    if table in routes:
        cur.execute(f"""select source_type, source_id, path, line_start, line_end, priority, left(content, 400) as content from {routes[table]}(%s, %s)""", (q, limit))
        return cur.fetchall()
    if table == "zorg_memory":
        like=f"%{q}%"
        cur.execute("""
        with matches as (
          select id, logged_at, memory_category, memory_priority, left(coalesce(memory_value, chat_session_log, ''), 400) as snippet
          from zorg_memory
          where coalesce(memory_value, '') ilike %s or coalesce(chat_session_log, '') ilike %s or coalesce(memory_key, '') ilike %s or coalesce(system_prompt, '') ilike %s or coalesce(ai_response, '') ilike %s
        ) select * from matches order by logged_at desc limit %s
        """, (like, like, like, like, like, limit))
        return cur.fetchall()
    cur.execute(f"select id, line_no, imported_at, left(coalesce(line_text,''), 400) as snippet from {table} where coalesce(line_text,'') ilike %s order by line_no asc limit %s", (f"%{q}%", limit))
    return cur.fetchall()

def get_row(cur, table: str, key: str):
    if table == "zorg_memory":
        cur.execute("select * from zorg_memory where id=%s" if "-" in key else "select * from zorg_memory order by logged_at asc offset %s limit 1", (key if "-" in key else max(int(key)-1,0),))
    else:
        cur.execute(f"select * from {table} where id=%s" if "-" in key else f"select * from {table} where line_no=%s", (key if "-" in key else int(key),))
    return cur.fetchone()

def recent(cur, limit:int=20):
    cur.execute("select id, logged_at, memory_category, memory_priority, left(coalesce(memory_value, chat_session_log, ''), 400) as snippet from zorg_memory order by logged_at desc limit %s", (limit,))
    return cur.fetchall()

def master(cur, limit:int=40):
    cur.execute("""select source_type, source_id, priority, sort_ts, title, left(content, 400) as content from zorg_master_context_mv order by case when lower(priority)='critical' then 1 when lower(priority)='high' then 2 when lower(priority)='medium' then 3 else 4 end, sort_ts desc limit %s""", (limit,))
    return cur.fetchall()

def refresh(cur):
    cur.execute("select refresh_zorg_memory_search_mv();")
    cur.execute("select refresh_zorg_memory_search_fast_mv();")
    cur.execute("select refresh_zorg_master_context();")

def main():
    ap=argparse.ArgumentParser(description="SQL-backed OpenClaw memory/context tool")
    sub=ap.add_subparsers(dest="cmd", required=True)
    sp=sub.add_parser("search"); sp.add_argument("query"); sp.add_argument("--table", default="all"); sp.add_argument("--limit", type=int, default=10)
    gp=sub.add_parser("get"); gp.add_argument("table"); gp.add_argument("key")
    rp=sub.add_parser("recent"); rp.add_argument("--limit", type=int, default=20)
    mp=sub.add_parser("master"); mp.add_argument("--limit", type=int, default=40)
    sub.add_parser("tables"); sub.add_parser("refresh")
    args=ap.parse_args(); cfg=load_cfg()
    with connect(cfg) as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        if args.cmd=="tables": print("\n".join(mapped_tables(cfg)+["all","project","host","runbook"])); return
        if args.cmd=="search": print(json.dumps({args.table: search(cur,args.table,args.query,args.limit)}, default=str, indent=2)); return
        if args.cmd=="get": print(json.dumps(get_row(cur,args.table,args.key), default=str, indent=2)); return
        if args.cmd=="recent": print(json.dumps(recent(cur,args.limit), default=str, indent=2)); return
        if args.cmd=="master": print(json.dumps(master(cur,args.limit), default=str, indent=2)); return
        if args.cmd=="refresh": refresh(cur); print("refreshed"); return
if __name__=='__main__': main()
