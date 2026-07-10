#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

BASE = Path('/home/openclaw/.openclaw/workspace')
SQL_CFG = BASE / 'sql_memory_map.json'
VENV_PYTHON = BASE / '.venv-sqlmem' / 'bin' / 'python'

try:
    import psycopg2
    from psycopg2 import errors
    from psycopg2.extras import RealDictCursor
except ModuleNotFoundError as exc:
    if exc.name != 'psycopg2':
        raise
    if VENV_PYTHON.exists() and Path(sys.executable).resolve() != VENV_PYTHON.resolve():
        os.execv(str(VENV_PYTHON), [str(VENV_PYTHON), __file__, *sys.argv[1:]])
    raise SystemExit(
        'psycopg2 is missing from the active Python. '
        f'Use {VENV_PYTHON} or reinstall the SQL memory environment.'
    )
DEEP_SCAN_UNTIL = datetime(2026, 6, 23, 2, 43, 0, tzinfo=timezone.utc)
DEEP_SCAN_MIN_LIMIT = 12
PRIMARY_STATEMENT_TIMEOUT_MS = int(os.environ.get('ZORG_RECALL_PRIMARY_TIMEOUT_MS', '8000'))
FALLBACK_STATEMENT_TIMEOUT_MS = 8000
ANN_STATEMENT_TIMEOUT_MS = int(os.environ.get('ZORG_RECALL_ANN_TIMEOUT_MS', '6000'))
ANN_MIN_LIMIT = int(os.environ.get('ZORG_RECALL_ANN_MIN_LIMIT', '5'))
ANN_QUERY_CACHE_TIMEOUT_MS = int(os.environ.get('ZORG_RECALL_ANN_QUERY_CACHE_TIMEOUT_MS', '12000'))
ANN_QUERY_CACHE_SCRIPT = BASE / 'scripts' / 'cache_model_query_embedding.mjs'
WEIGHTED_FIRST = os.environ.get('ZORG_RECALL_WEIGHTED_FIRST', '1').lower() not in {'0', 'false', 'no', 'off'}
PRIMARY_FIRST = os.environ.get('ZORG_RECALL_PRIMARY_FIRST', '').lower() in {'1', 'true', 'yes'}
WEIGHTED_RECALL_ENABLED = os.environ.get('ZORG_RECALL_WEIGHTED_ENABLED', '1').lower() not in {'0', 'false', 'no', 'off'}

STOP_WORDS = {
    'what', 'when', 'where', 'which', 'while', 'with', 'from', 'that', 'this',
    'your', 'youre', 'have', 'been', 'being', 'were', 'does', 'into', 'about',
    'supposed', 'remember', 'using', 'should', 'would', 'could', 'there',
    'their', 'they', 'them', 'then', 'than', 'time',
}

OLD_PATTERN_SOURCE_CHAT_FILTER = """
not (
  z.source_table = 'zorg_memory'
  and z.category like 'chat_ingest%%'
  and z.content_lc like '%%source%%'
  and (
    z.content_lc like '%%preserve source memory%%'
    or z.content_lc like '%%preserve source data%%'
    or z.content_lc like '%%preserve all source%%'
    or z.content_lc like '%%source memory must never be deleted%%'
    or z.content_lc like '%%source memory must never be%%pruned%%'
    or z.content_lc like '%%do not delete source memory%%'
    or z.content_lc like '%%do not delete source rows%%'
    or z.content_lc like '%%source memory rows%%'
    or z.content_lc like '%%source rows%%'
    or z.content_lc like '%%additive only%%'
    or z.content_lc like '%%improve recall additively%%'
    or z.content_lc like '%%preserving source memory%%'
    or z.content_lc like '%%preserve source rows%%'
    or z.content_lc like '%%never delete%%source memory%%'
    or z.content_lc like '%%never prune%%source memory%%'
    or z.content_lc like '%%additive%%'
    or z.content_lc like '%%preserve%%'
    or z.content_lc like '%%prune%%'
    or z.content_lc like '%%delete%%'
    or z.content_lc like '%%source rows%%'
  )
)
"""


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
        password=p['password'],
    )


def deep_scan_active() -> bool:
    return datetime.now(timezone.utc) < DEEP_SCAN_UNTIL


def weighted_recall_active() -> bool:
    return WEIGHTED_RECALL_ENABLED or deep_scan_active()


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


def search_emergency_fts(cur, query: str, limit: int):
    cur.execute('set local statement_timeout = %s', (FALLBACK_STATEMENT_TIMEOUT_MS,))
    cur.execute(
        """
        with tok(token) as (
          select unnest(%s::text[])
        ), ranked as (
          select
            source_table,
            source_id,
            priority,
            left(content, 4000) as content,
            source_rank,
            priority_rank,
            event_ts,
            content_len,
            (
              select count(*)::int
              from tok
              where content_lc like '%%' || tok.token || '%%'
            ) as token_hits
          from public.zorg_memory_search_fast_mv
          where content_fts_simple @@ plainto_tsquery('simple', %s)
             or content_lc like %s
        )
        select source_table, source_id, priority, content
        from ranked
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
                 priority_rank, source_rank, event_ts desc nulls last
        limit %s
        """,
        (query_tokens(query), query, f"%{query.lower()[:80]}%", limit),
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


def format_fast_rows(rows):
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
        for row in rows
    ]


def search_exact_hint_promotions(cur, query: str, limit: int) -> list[dict]:
    normalized_query = ' '.join((query or '').lower().split())
    if not normalized_query:
        return []
    cur.execute('set local statement_timeout = %s', (FALLBACK_STATEMENT_TIMEOUT_MS,))
    cur.execute(
        """
        with exact_hints as (
          select h.id, h.source_type, h.source_key, h.hint_kind, h.hint_text, h.weight
          from public.memory_recall_hints h
          where coalesce(h.active, true)
            and h.hint_kind = 'exact_query_alias'
            and lower(regexp_replace(h.hint_text, '\\s+', ' ', 'g')) = %s
          order by h.weight desc, h.updated_at desc
          limit greatest(%s * 2, 10)
        ), linked_rules as (
          select
            'logic_rule'::text as source_type,
            r.id::text as source_id,
            r.priority,
            left(concat_ws(E'\\n', r.rule_key, r.title, r.rule_text), 4000) as content,
            h.weight,
            0 as source_order
          from exact_hints h
          join public.zorg_logic_rules r
            on h.source_type = 'logic_rule'
           and r.rule_key = h.source_key
           and coalesce(r.active, true)
        ), linked_memories as (
          select
            'memory'::text as source_type,
            z.id::text as source_id,
            z.memory_priority as priority,
            left(z.memory_value, 4000) as content,
            h.weight,
            0 as source_order
          from exact_hints h
          join public.zorg_memory z
            on h.source_type in ('memory', 'zorg_memory', 'recall_hint')
           and z.memory_key = h.source_key
           and coalesce(z.memory_active, true)
        ), hint_rows as (
          select
            'recall_hint'::text as source_type,
            h.id::text as source_id,
            'critical'::text as priority,
            left(concat_ws(E'\\n', h.source_key, h.hint_kind, h.hint_text), 4000) as content,
            h.weight,
            1 as source_order
          from exact_hints h
        )
        select source_type, source_id, priority, content
        from (
          select * from linked_rules
          union all
          select * from linked_memories
          union all
          select * from hint_rows
        ) promoted
        order by source_order, weight desc
        limit %s
        """,
        (normalized_query, limit, limit),
    )
    return [
        {
            'source_type': normalize_source_type(row['source_type']),
            'source_id': row['source_id'],
            'path': None,
            'line_start': None,
            'line_end': None,
            'priority': row['priority'] or 'critical',
            'content': row['content'],
        }
        for row in cur.fetchall()
    ]


def search_rule_preflight(cur, query: str, limit: int) -> list[dict]:
    """Fetch matching active logic rules before mixed memory recall can dilute them."""
    rule_limit = max(6, min(max(limit, 1), 16))
    cur.execute('set local statement_timeout = %s', (FALLBACK_STATEMENT_TIMEOUT_MS,))
    cur.execute(
        """
        select source_type, source_id, path, line_start, line_end, priority, content
        from public.zorg_get_logic_context(%s, %s)
        """,
        (query, rule_limit),
    )
    return [
        {
            'source_type': normalize_source_type(row['source_type']),
            'source_id': row['source_id'],
            'path': row['path'],
            'line_start': row['line_start'],
            'line_end': row['line_end'],
            'priority': row['priority'] or 'critical',
            'content': row['content'],
        }
        for row in cur.fetchall()
    ]


def prepend_promotions(promoted_rows: list[dict], rows: list[dict], limit: int) -> list[dict]:
    if not promoted_rows:
        return rows[:limit]
    seen = set()
    merged = []

    def add(row):
        key = (row.get('source_type'), str(row.get('source_id')))
        if key in seen:
            return
        seen.add(key)
        merged.append(row)

    for row in promoted_rows:
        add(row)
    for row in rows:
        add(row)
        if len(merged) >= limit:
            break
    return merged[:limit]


def search_fast_fallback(cur, query: str, limit: int):
    tokens = query_tokens(query)
    if not tokens and query:
        tokens = [query.lower()[:80]]
    patterns = [f"%{token}%" for token in tokens]
    phrase_pattern = f"%{query.lower()[:160]}%"
    token_hit_expr = ' + '.join(
        ['case when z.content_lc like %s then 1 else 0 end'] * len(patterns)
    ) or '0'
    token_where_expr = ' or '.join(['z.content_lc like %s'] * len(patterns))
    where_expr = 'z.content_fts_simple @@ plainto_tsquery(\'simple\', %s)'
    if token_where_expr:
        where_expr = f"({where_expr} or {token_where_expr})"
    cur.execute('set local statement_timeout = %s', (FALLBACK_STATEMENT_TIMEOUT_MS,))
    if len(tokens) >= 2:
        cur.execute(
            f"""
            with candidates as (
              select
                z.source_table,
                z.source_id,
                z.priority,
                left(z.content, 4000) as content,
                z.source_rank,
                z.priority_rank,
                z.event_ts,
                z.content_len,
                ({token_hit_expr}
                 + case when z.content_fts_simple @@ plainto_tsquery('simple', %s) then 1 else 0 end
                 + case when z.content_lc like %s then 2 else 0 end) as token_hits
              from public.zorg_memory_search_fast_mv z
              where {OLD_PATTERN_SOURCE_CHAT_FILTER}
                and (z.content_fts_simple @@ plainto_tsquery('simple', %s)
                 or z.content_lc like %s)
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
            (
                *patterns,
                query,
                phrase_pattern,
                query,
                phrase_pattern,
                limit,
                limit,
                limit,
            ),
        )
        rows = cur.fetchall()
        if len(rows) >= min(limit, 5):
            return format_fast_rows(rows)
    cur.execute(
        f"""
        with candidates as (
          select
            z.source_table,
            z.source_id,
            z.priority,
            left(z.content, 4000) as content,
            z.source_rank,
            z.priority_rank,
            z.event_ts,
            z.content_len,
            ({token_hit_expr}
             + case when z.content_fts_simple @@ plainto_tsquery('simple', %s) then 1 else 0 end) as token_hits
          from public.zorg_memory_search_fast_mv z
          where {OLD_PATTERN_SOURCE_CHAT_FILTER}
            and {where_expr}
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
        (
            *patterns,
            query,
            query,
            *patterns,
            limit,
            limit,
            limit,
        ),
    )
    return format_fast_rows(cur.fetchall())


def merge_ranked_rows(primary_rows: list[dict], ann_rows: list[dict], limit: int) -> list[dict]:
    """Interleave ANN recall without letting slower semantic neighbors dominate exact hits."""
    seen = set()
    merged = []
    max_rows = max(limit, 1)
    ann_budget = min(len(ann_rows), max(2, max_rows // 3)) if ann_rows else 0
    primary_head_budget = max(1, max_rows - ann_budget)

    def add(row):
        key = (row.get('source_type'), str(row.get('source_id')), row.get('content'))
        if key in seen:
            return
        seen.add(key)
        merged.append(row)

    for row in primary_rows[:primary_head_budget]:
        add(row)
    for row in ann_rows[:ann_budget]:
        add(row)
        if len(merged) >= max_rows:
            break
    for row in primary_rows[primary_head_budget:]:
        add(row)
        if len(merged) >= max_rows:
            break
    return merged[:max_rows]


def search_ann_recall(cur, query: str, limit: int):
    ann_limit = max(ANN_MIN_LIMIT, min(max(limit, 1), 8))
    if not ensure_model_query_embedding_cached(query):
        return []
    cur.execute('set local statement_timeout = %s', (ANN_STATEMENT_TIMEOUT_MS,))
    cur.execute('set local jit = off')
    cur.execute('set local hnsw.ef_search = 40')
    cur.execute(
        """
        select source_type, source_id, path, line_start, line_end, priority,
               left(content, 4000) as content
        from public.memory_provider_ann_recall(%s, %s, 'local', 'embeddinggemma-300m-qat-q8_0')
        """,
        (query, ann_limit),
    )
    return [
        {
            'source_type': normalize_source_type(row['source_type']),
            'source_id': row['source_id'],
            'path': row['path'],
            'line_start': row['line_start'],
            'line_end': row['line_end'],
            'priority': row['priority'] or 'medium',
            'content': row['content'],
        }
        for row in cur.fetchall()
    ]


def ensure_model_query_embedding_cached(query: str) -> bool:
    if not ANN_QUERY_CACHE_SCRIPT.exists():
        return False
    try:
        result = subprocess.run(
            ['node', str(ANN_QUERY_CACHE_SCRIPT)],
            input=query or '',
            text=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=max(1, ANN_QUERY_CACHE_TIMEOUT_MS / 1000),
            cwd=str(BASE),
            check=False,
        )
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def search_fast_with_ann(cur, query: str, limit: int):
    rows = search_fast_fallback(cur, query, limit)
    try:
        ann_rows = search_ann_recall(cur, query, limit)
    except (errors.QueryCanceled, errors.UndefinedFunction, errors.UndefinedTable):
        cur.connection.rollback()
        return rows, False
    return merge_ranked_rows(rows, ann_rows, limit), bool(ann_rows)


def search_structured_db(query: str, limit: int):
    requested_limit = max(1, int(limit or 10))
    effective_limit = max(requested_limit, DEEP_SCAN_MIN_LIMIT) if weighted_recall_active() else requested_limit
    recall_function = 'zorg_weighted_recall_context' if weighted_recall_active() else 'zorg_recall_context'
    mode = 'database-direct-structured-weighted' if weighted_recall_active() else 'database-direct-structured'
    fallback_error = None
    with db_connect() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            exact_promotions = search_exact_hint_promotions(cur, query, effective_limit)
            if exact_promotions:
                mode += '-exact-alias'
                rule_promotions = search_rule_preflight(cur, query, effective_limit)
                promoted_rows = prepend_promotions(exact_promotions, rule_promotions, effective_limit)
                return {
                    'mode': mode,
                    'requested_limit': requested_limit,
                    'effective_limit': effective_limit,
                    'deep_scan_until': DEEP_SCAN_UNTIL.isoformat(),
                    'fallback_error': None,
                    'structured': promoted_rows,
                }
            rule_promotions = search_rule_preflight(cur, query, effective_limit)
            promoted_rows = rule_promotions
            use_fast_first = weighted_recall_active() and not WEIGHTED_FIRST
            if not weighted_recall_active() and not PRIMARY_FIRST:
                use_fast_first = True
                mode += '-fast-first'
            if use_fast_first:
                try:
                    rows, used_ann = search_fast_with_ann(cur, query, effective_limit)
                    mode += '-fast-mv'
                    if used_ann:
                        mode += '-pgvector-ann'
                except errors.QueryCanceled as e:
                    fallback_error = str(e)[:500]
                    conn.rollback()
                    with conn.cursor(cursor_factory=RealDictCursor) as emergency_cur:
                        rows = search_emergency_fts(emergency_cur, query, effective_limit)
                        mode += '-fast-mv-emergency-fts'
                rows = prepend_promotions(promoted_rows, rows, effective_limit)
                return {
                    'mode': mode,
                    'requested_limit': requested_limit,
                    'effective_limit': effective_limit,
                    'deep_scan_until': DEEP_SCAN_UNTIL.isoformat(),
                    'fallback_error': fallback_error,
                    'structured': rows,
                }
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
                try:
                    ann_rows = search_ann_recall(cur, query, effective_limit)
                    if ann_rows:
                        rows = merge_ranked_rows(rows, ann_rows, effective_limit)
                        mode += '-pgvector-ann'
                except (errors.QueryCanceled, errors.UndefinedFunction, errors.UndefinedTable):
                    conn.rollback()
                rows = prepend_promotions(promoted_rows, rows, effective_limit)
            except errors.QueryCanceled as e:
                fallback_error = str(e)[:500]
                conn.rollback()
                with conn.cursor(cursor_factory=RealDictCursor) as fallback_cur:
                    promoted_rows = search_rule_preflight(fallback_cur, query, effective_limit) + search_exact_hint_promotions(fallback_cur, query, effective_limit)
                    try:
                        rows, used_ann = search_fast_with_ann(fallback_cur, query, effective_limit)
                        mode += '-fallback-fast-mv'
                        if used_ann:
                            mode += '-pgvector-ann'
                    except errors.QueryCanceled as fallback_exc:
                        fallback_error = (fallback_error + ' | fallback: ' + str(fallback_exc))[:500]
                        conn.rollback()
                        with conn.cursor(cursor_factory=RealDictCursor) as emergency_cur:
                            promoted_rows = search_rule_preflight(emergency_cur, query, effective_limit) + search_exact_hint_promotions(emergency_cur, query, effective_limit)
                            rows = search_emergency_fts(emergency_cur, query, effective_limit)
                            mode += '-fallback-fast-mv-emergency-fts'
                    rows = prepend_promotions(promoted_rows, rows, effective_limit)
    return {
        'mode': mode,
        'requested_limit': requested_limit,
        'effective_limit': effective_limit,
        'deep_scan_until': DEEP_SCAN_UNTIL.isoformat(),
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
