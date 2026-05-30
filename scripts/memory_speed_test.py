#!/usr/bin/env python3
import json
import os
import statistics
import time
from pathlib import Path

import psycopg2

BASE = Path(os.environ.get('OPENCLAW_WORKSPACE', Path.cwd()))
MAP = Path(os.environ.get('SQL_MEMORY_MAP', BASE / 'sql_memory_map.json'))
CORPUS = Path(os.environ.get('DB_BENCHMARK_QUERIES', BASE / 'db_benchmark_queries.json'))
if not CORPUS.exists():
    repo_corpus = Path(__file__).resolve().parents[1] / 'config' / 'db_benchmark_queries.example.json'
    CORPUS = repo_corpus if repo_corpus.exists() else CORPUS
RUNS = int(os.environ.get('MEMORY_SPEED_RUNS', '10'))
STATEMENT_TIMEOUT_MS = int(os.environ.get('MEMORY_SPEED_STATEMENT_TIMEOUT_MS', '5000'))
REFRESH_BEFORE_TEST = os.environ.get('MEMORY_SPEED_REFRESH', '').lower() in {'1', 'true', 'yes'}

DEFAULT_QUERIES = ['OpenClaw', 'memory', 'directive', 'project', 'database']
def load_queries():
    try:
        data = json.loads(CORPUS.read_text(encoding='utf-8'))
        queries = data.get('queries', data if isinstance(data, list) else [])
        return [str(q) for q in queries if str(q).strip()] or DEFAULT_QUERIES
    except Exception:
        return DEFAULT_QUERIES


def load_cfg():
    return json.loads(MAP.read_text(encoding='utf-8'))['postgres']


def timed(fn, *args):
    t = time.perf_counter()
    out = fn(*args)
    return out, (time.perf_counter() - t) * 1000


def percentile(values, p):
    values = sorted(values)
    if not values:
        return None
    idx = min(len(values) - 1, max(0, int(len(values) * p) - 1))
    return values[idx]


def main():
    queries = load_queries()
    cfg = load_cfg()
    results = {}
    with psycopg2.connect(host=cfg['host'], port=cfg['port'], dbname=cfg['database'], user=cfg['user']) as conn:
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute('set statement_timeout = %s', (STATEMENT_TIMEOUT_MS,))
            if REFRESH_BEFORE_TEST:
                cur.execute('select public.refresh_zorg_memory_search_fast_mv()')
            for obj in ['zorg_memory_search_fast_mv', 'zorg_memory_search_mv', 'zorg_master_context_mv', 'zorg_success_query_index']:
                try:
                    cur.execute('analyze ' + obj)
                except Exception:
                    conn.rollback()
            for q in queries:
                db_times = []
                db_count = 0
                for _ in range(RUNS):
                    def run_db():
                        cur.execute(
                            """
                            select count(*)
                            from zorg_memory_search_fast_mv
                            where content_lc like %s
                               or content_fts_simple @@ plainto_tsquery('simple', %s)
                            """,
                            (f'%{q.lower()}%', q),
                        )
                        return cur.fetchone()[0]

                    db_count, dt = timed(run_db)
                    db_times.append(dt)
                db_avg = statistics.mean(db_times)
                results[q] = {
                    'db_count': db_count,
                    'db_ms_avg': round(db_avg, 3),
                    'db_ms_p95': round(percentile(db_times, 0.95), 3),
                }
    print(json.dumps({
        'runs_per_query': RUNS,
        'query_count': len(queries),
        'corpus': str(CORPUS),
        'statement_timeout_ms': STATEMENT_TIMEOUT_MS,
        'refresh_before_test': REFRESH_BEFORE_TEST,
        'results': results
    }, indent=2))


if __name__ == '__main__':
    main()
