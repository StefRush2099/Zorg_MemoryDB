#!/usr/bin/env python3
import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path

import psycopg2
from psycopg2.extras import RealDictCursor

BASE = Path(os.environ.get('OPENCLAW_WORKSPACE', Path.cwd())).resolve()
SQL_CFG = Path(os.environ.get('SQL_MEMORY_MAP', BASE / 'sql_memory_map.json')).resolve()


def deep_scan_until() -> datetime | None:
    raw = os.environ.get('ZORG_DEEP_RECALL_UNTIL', '').strip()
    if not raw:
        return None
    if raw.endswith('Z'):
        raw = raw[:-1] + '+00:00'
    dt = datetime.fromisoformat(raw)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def deep_scan_active() -> bool:
    until = deep_scan_until()
    return bool(until and datetime.now(timezone.utc) < until)


def deep_scan_min_limit() -> int:
    return max(1, int(os.environ.get('ZORG_DEEP_RECALL_MIN_LIMIT', '12')))


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
    )


def search_structured_db(query: str, limit: int):
    requested_limit = max(1, int(limit or 10))
    effective_limit = max(requested_limit, deep_scan_min_limit()) if deep_scan_active() else requested_limit
    recall_function = 'zorg_weighted_recall_context' if deep_scan_active() else 'zorg_recall_context'
    with db_connect() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                f"""
                select source_type, source_id, path, line_start, line_end, priority, content
                from public.{recall_function}(%s, %s)
                """,
                (query, effective_limit),
            )
            rows = cur.fetchall()
    return {
        'mode': 'database-direct-structured-deep' if deep_scan_active() else 'database-direct-structured',
        'requested_limit': requested_limit,
        'effective_limit': effective_limit,
        'deep_scan_until': deep_scan_until().isoformat() if deep_scan_active() else None,
        'structured': rows,
    }


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
