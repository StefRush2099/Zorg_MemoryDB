#!/home/openclaw/.openclaw/workspace/.venv-sqlmem/bin/python
import argparse
import json
from typing import List

import psycopg2
from psycopg2.extras import RealDictCursor
from memory_recall_router import ensure_model_query_embedding_cached, search_structured_db

MAP_PATH = "/home/openclaw/.openclaw/workspace/sql_memory_map.json"


def load_cfg(path: str = MAP_PATH):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def connect(cfg):
    p = cfg["postgres"]
    return psycopg2.connect(
        host=p["host"],
        port=p["port"],
        dbname=p["database"],
        user=p["user"],
        password=p["password"],
    )


def mapped_tables(cfg) -> List[str]:
    return sorted(set(cfg["table_map"].values()))


def search(cur, table: str, q: str, limit: int = 10):
    if table == "all":
        return search_structured_db(q, limit)["structured"]

    if table == "ann":
        ensure_model_query_embedding_cached(q)
        cur.execute(
            """
            select source_type, source_id, path, line_start, line_end, priority,
                   left(content, 280) as content
            from public.memory_ann_recall(%s, %s)
            """,
            (q, limit),
        )
        return cur.fetchall()

    if table == "project":
        cur.execute(
            """
            select source_type, source_id, path, line_start, line_end, priority,
                   left(content, 280) as content
            from zorg_get_project_context(%s, %s)
            """,
            (q, limit),
        )
        return cur.fetchall()

    if table == "host":
        cur.execute(
            """
            select source_type, source_id, path, line_start, line_end, priority,
                   left(content, 280) as content
            from zorg_get_host_context(%s, %s)
            """,
            (q, limit),
        )
        return cur.fetchall()

    if table == "runbook":
        cur.execute(
            """
            select source_type, source_id, path, line_start, line_end, priority,
                   left(content, 280) as content
            from zorg_get_runbook_context(%s, %s)
            """,
            (q, limit),
        )
        return cur.fetchall()

    if table == "zorg_memory":
        like = f"%{q}%"
        cur.execute(
            """
            with matches as (
                select id, logged_at, memory_category, memory_priority,
                       left(coalesce(memory_value, chat_session_log, ''), 240) as snippet
                from zorg_memory
                where coalesce(memory_value, '') ilike %s

                union

                select id, logged_at, memory_category, memory_priority,
                       left(coalesce(memory_value, chat_session_log, ''), 240) as snippet
                from zorg_memory
                where coalesce(chat_session_log, '') ilike %s

                union

                select id, logged_at, memory_category, memory_priority,
                       left(coalesce(memory_value, chat_session_log, ''), 240) as snippet
                from zorg_memory
                where coalesce(memory_key, '') ilike %s

                union

                select id, logged_at, memory_category, memory_priority,
                       left(coalesce(memory_value, chat_session_log, ''), 240) as snippet
                from zorg_memory
                where coalesce(system_prompt, '') ilike %s

                union

                select id, logged_at, memory_category, memory_priority,
                       left(coalesce(memory_value, chat_session_log, ''), 240) as snippet
                from zorg_memory
                where coalesce(ai_response, '') ilike %s
            )
            select id, logged_at, memory_category, memory_priority, snippet
            from matches
            order by logged_at desc
            limit %s
            """,
            (like, like, like, like, like, limit),
        )
        return cur.fetchall()

    cur.execute(
        f"""
        select id, line_no, imported_at,
               left(coalesce(line_text,''), 240) as snippet
        from {table}
        where coalesce(line_text,'') ilike %s
        order by line_no asc
        limit %s
        """,
        (f"%{q}%", limit),
    )
    return cur.fetchall()


def get_row(cur, table: str, key: str):
    if table == "zorg_memory":
        if "-" in key:
            cur.execute("select * from zorg_memory where id=%s", (key,))
        else:
            cur.execute(
                "select * from zorg_memory order by logged_at asc offset %s limit 1",
                (max(int(key) - 1, 0),),
            )
    else:
        if "-" in key:
            cur.execute(f"select * from {table} where id=%s", (key,))
        else:
            cur.execute(f"select * from {table} where line_no=%s", (int(key),))
    return cur.fetchone()


def recent(cur, limit: int = 20):
    cur.execute(
        """
        select id, logged_at, memory_category, memory_priority,
               left(coalesce(memory_value, chat_session_log, ''), 240) as snippet
        from zorg_memory
        order by logged_at desc
        limit %s
        """,
        (limit,),
    )
    return cur.fetchall()


def master(cur, limit: int = 40):
    cur.execute(
        """
        select source_type, source_id, priority, sort_ts, title,
               left(content, 280) as content
        from zorg_master_context_mv
        order by
          case when lower(priority)='critical' then 1
               when lower(priority)='high' then 2
               when lower(priority)='medium' then 3
               else 4 end,
          sort_ts desc
        limit %s
        """,
        (limit,),
    )
    return cur.fetchall()


def main():
    ap = argparse.ArgumentParser(description="SQL-backed memory/context tool")
    sub = ap.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("search")
    sp.add_argument("query")
    sp.add_argument("--table", default="all")
    sp.add_argument("--limit", type=int, default=10)

    gp = sub.add_parser("get")
    gp.add_argument("table")
    gp.add_argument("key", help="uuid id or line_no")

    rp = sub.add_parser("recent")
    rp.add_argument("--limit", type=int, default=20)

    mp = sub.add_parser("master")
    mp.add_argument("--limit", type=int, default=40)

    sub.add_parser("tables")

    args = ap.parse_args()
    cfg = load_cfg()

    with connect(cfg) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            if args.cmd == "tables":
                print("\n".join(mapped_tables(cfg) + ["all", "ann", "project", "host", "runbook"]))
                return

            if args.cmd == "search":
                if args.table == "all":
                    out = {"all": search(cur, "all", args.query, args.limit)}
                else:
                    out = {args.table: search(cur, args.table, args.query, args.limit)}
                print(json.dumps(out, default=str, indent=2))
                return

            if args.cmd == "get":
                row = get_row(cur, args.table, args.key)
                print(json.dumps(row, default=str, indent=2))
                return

            if args.cmd == "recent":
                rows = recent(cur, args.limit)
                print(json.dumps(rows, default=str, indent=2))
                return

            if args.cmd == "master":
                rows = master(cur, args.limit)
                print(json.dumps(rows, default=str, indent=2))
                return


if __name__ == "__main__":
    main()
