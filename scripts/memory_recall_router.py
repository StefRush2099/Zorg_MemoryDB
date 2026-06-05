#!/usr/bin/env python3
import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path

import psycopg2
from psycopg2 import errors
from psycopg2.extras import RealDictCursor

BASE = Path(os.environ.get('OPENCLAW_WORKSPACE', Path.cwd())).resolve()
SQL_CFG = Path(os.environ.get('SQL_MEMORY_MAP', BASE / 'sql_memory_map.json')).resolve()
PRIMARY_STATEMENT_TIMEOUT_MS = int(os.environ.get('ZORG_RECALL_PRIMARY_TIMEOUT_MS', '2500'))
FALLBACK_STATEMENT_TIMEOUT_MS = int(os.environ.get('ZORG_RECALL_FALLBACK_TIMEOUT_MS', '8000'))

STOP_WORDS = {
    'what', 'when', 'where', 'which', 'while', 'with', 'from', 'that', 'this',
    'your', 'youre', 'have', 'been', 'being', 'were', 'does', 'into', 'about',
    'supposed', 'remember', 'using', 'should', 'would', 'could', 'there',
    'their', 'they', 'them', 'then', 'than', 'time',
}


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
        password=p.get('password', ''),
    )


def query_tokens(query: str) -> list[str]:
    tokens = []
    current = []
    for ch in (query or '').lower():
        if ch.isalnum():
            current.append(ch)
            continue
        if current:
            token = ''.join(current)
            if len(token) >= 4 and token not in STOP_WORDS and token not in tokens:
                tokens.append(token)
            current = []
    if current:
        token = ''.join(current)
        if len(token) >= 4 and token not in STOP_WORDS and token not in tokens:
            tokens.append(token)
    return tokens[:12]


def normalize_source_type(source_table: str) -> str:
    return {
        'directive': 'directive',
        'runbook': 'runbook',
        'project': 'project',
        'project_fact': 'project_fact',
        'host': 'host',
        'service': 'service',
        'relationship': 'relationship',
        'recall_hint': 'recall_hint',
        'query_observation': 'query_observation',
        'operational_fact': 'operational_fact',
        'contact': 'contact',
        'logic_rule': 'logic_rule',
    }.get(source_table, 'memory')


def search_fast_fallback(cur, query: str, limit: int):
    tokens = query_tokens(query)
    if not tokens and query:
        tokens = [query.lower()[:80]]
    cur.execute('set local statement_timeout = %s', (FALLBACK_STATEMENT_TIMEOUT_MS,))
    cur.execute(
        """
        with tok(token) as (
          select unnest(%s::text[])
        ), candidates as (
          select
            z.source_table,
            z.source_id,
            z.priority,
            left(z.content, 4000) as content,
            z.source_rank,
            z.priority_rank,
            z.event_ts,
            z.content_len,
            (
              select count(*)::int
              from tok
              where z.content_lc like '%%' || tok.token || '%%'
            ) as token_hits
          from public.zorg_memory_search_fast_mv z
          where exists (
            select 1
            from tok
            where z.content_lc like '%%' || tok.token || '%%'
          )
          order by token_hits desc,
                   z.priority_rank, z.source_rank, z.event_ts desc nulls last
          limit greatest(%s * 20, 200)
        ), matches as (
          select *
          from candidates
          order by ((token_hits::numeric * greatest(1, 10 - priority_rank * 2) * greatest(1, 10 - source_rank)) / greatest(content_len, 100)) desc,
                   token_hits desc, priority_rank, source_rank,
                   event_ts desc nulls last
          limit greatest(%s * 4, 20)
        )
        select source_table, source_id, priority, content
        from matches
        order by token_hits desc,
                 case
                   when source_table = 'recall_hint' then 0
                   when source_table = 'host' then 1
                   when source_table in ('project_fact', 'project') then 2
                   when source_table = 'runbook' then 3
                   when source_table = 'logic_rule' then 4
                   when source_table = 'query_observation' then 6
                   else 5
                 end,
                 ((token_hits::numeric * greatest(1, 10 - priority_rank * 2) * greatest(1, 10 - source_rank)) / greatest(content_len, 100)) desc,
                 token_hits desc, priority_rank, source_rank,
                 event_ts desc nulls last
        limit %s
        """,
        (tokens, limit, limit, limit),
    )
    return [
        {
            'source_type': normalize_source_type(row['source_table']),
            'source_id': row['source_id'],
            'path': None,
            'line_start': None,
            'line_end': None,
            'priority': row['priority'] or 'medium',
            'content': row['content'],
        }
        for row in cur.fetchall()
    ]


def search_structured_db(query: str, limit: int):
    requested_limit = max(1, int(limit or 10))
    effective_limit = max(requested_limit, deep_scan_min_limit()) if deep_scan_active() else requested_limit
    recall_function = 'zorg_weighted_recall_context' if deep_scan_active() else 'zorg_recall_context'
    mode = 'database-direct-structured-deep' if deep_scan_active() else 'database-direct-structured'
    fallback_error = None
    with db_connect() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            try:
                cur.execute('set local statement_timeout = %s', (PRIMARY_STATEMENT_TIMEOUT_MS,))
                cur.execute(
                    f"""
                    select source_type, source_id, path, line_start, line_end, priority, content
                    from public.{recall_function}(%s, %s)
                    """,
                    (query, effective_limit),
                )
                rows = cur.fetchall()
            except errors.QueryCanceled as e:
                fallback_error = str(e)[:500]
                conn.rollback()
                with conn.cursor(cursor_factory=RealDictCursor) as fallback_cur:
                    rows = search_fast_fallback(fallback_cur, query, effective_limit)
                    mode += '-fallback-fast-mv'
    return {
        'mode': mode,
        'requested_limit': requested_limit,
        'effective_limit': effective_limit,
        'deep_scan_until': deep_scan_until().isoformat() if deep_scan_active() else None,
        'fallback_error': fallback_error,
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
