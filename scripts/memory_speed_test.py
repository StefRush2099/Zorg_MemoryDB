#!/usr/bin/env python3
import glob
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

DEFAULT_QUERIES = ['OpenClaw', 'memory', 'directive', 'project', 'database']
FLAT_FILES = [
    BASE / 'MEMORY.md',
    BASE / 'AGENTS.md',
    BASE / 'SOUL.md',
    BASE / 'USER.md',
    BASE / 'TOOLS.md',
    BASE / 'IDENTITY.md',
    BASE / 'HEARTBEAT.md',
]
FLAT_FILES += [Path(p) for p in glob.glob(str(BASE / 'memory' / '*.md'))]


def load_queries():
    try:
        data = json.loads(CORPUS.read_text(encoding='utf-8'))
        queries = data.get('queries', data if isinstance(data, list) else [])
        return [str(q) for q in queries if str(q).strip()] or DEFAULT_QUERIES
    except Exception:
        return DEFAULT_QUERIES


def load_cfg():
    return json.loads(MAP.read_text(encoding='utf-8'))['postgres']


def flat_search_count(query):
    q = query.lower()
    terms = q.split()
    count = 0
    for fp in FLAT_FILES:
        try:
            text = fp.read_text(encoding='utf-8', errors='ignore').lower()
        except Exception:
            continue
        count += text.count(q)
        if len(terms) > 1 and all(term in text for term in terms[: min(len(terms), 5)]):
            count += 1
    return count


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
    password = os.environ.get('PGPASSWORD', cfg.get('password', ''))
    results = {}
    with psycopg2.connect(host=cfg['host'], port=cfg['port'], dbname=cfg['database'], user=cfg['user'], password=password) as conn:
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute('select public.refresh_zorg_memory_search_fast_mv()')
            for obj in ['zorg_memory_search_fast_mv', 'zorg_memory_search_mv', 'zorg_master_context_mv', 'zorg_success_query_index']:
                try:
                    cur.execute('analyze ' + obj)
                except Exception:
                    conn.rollback()
            for q in queries:
                flat_times, db_times = [], []
                flat_count = db_count = 0
                for _ in range(RUNS):
                    flat_count, dt = timed(flat_search_count, q)
                    flat_times.append(dt)

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
                flat_avg = statistics.mean(flat_times)
                db_avg = statistics.mean(db_times)
                results[q] = {
                    'flat_count': flat_count,
                    'db_count': db_count,
                    'flat_ms_avg': round(flat_avg, 3),
                    'flat_ms_p95': round(percentile(flat_times, 0.95), 3),
                    'db_ms_avg': round(db_avg, 3),
                    'db_ms_p95': round(percentile(db_times, 0.95), 3),
                    'speedup_x_avg': round(flat_avg / db_avg, 2) if db_avg > 0 else None,
                }
    print(json.dumps({'runs_per_query': RUNS, 'query_count': len(queries), 'corpus': str(CORPUS), 'results': results}, indent=2))


if __name__ == '__main__':
    main()
