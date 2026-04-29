#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path

import psycopg2
from psycopg2.extras import RealDictCursor

BASE = Path(os.environ.get('OPENCLAW_WORKSPACE', Path.cwd())).resolve()
SQL_CFG = Path(os.environ.get('SQL_MEMORY_MAP', BASE / 'sql_memory_map.json')).resolve()


def load_sql_cfg():
    return json.loads(SQL_CFG.read_text(encoding='utf-8'))


def db_connect():
    cfg = load_sql_cfg()
    p = cfg['postgres']
    return psycopg2.connect(
        host=p['host'],
        port=p['port'],
        dbname=p['database'],
        user=p['user'],
        password=p.get('password', ''),
    )


def search_structured_db(query: str, limit: int):
    with db_connect() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                select source_type, source_id, path, line_start, line_end, priority, content
                from zorg_recall_context(%s, %s)
                """,
                (query, limit),
            )
            rows = cur.fetchall()
    return {'mode': 'database-direct-structured', 'structured': rows}


def main():
    ap = argparse.ArgumentParser(description='DB-only structured recall router')
    ap.add_argument('query')
    ap.add_argument('--limit', type=int, default=10)
    args = ap.parse_args()

    try:
        print(json.dumps(search_structured_db(args.query, args.limit), indent=2, default=str))
    except Exception as e:
        print(json.dumps({
            'mode': 'database-unavailable',
            'error': str(e),
            'structured': []
        }, indent=2))


if __name__ == '__main__':
    main()
