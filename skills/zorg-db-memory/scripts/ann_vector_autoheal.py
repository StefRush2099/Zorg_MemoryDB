#!/usr/bin/env python3
"""Verify and repair the critical PostgreSQL ANN/vector memory path.

Only derived ANN surfaces are repaired. Source memory rows are never deleted.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import fcntl
from pathlib import Path

import psycopg2

WORKSPACE = Path(os.environ.get("OPENCLAW_WORKSPACE", Path.home() / ".openclaw/workspace")).resolve()
SKILL_ROOT = Path(__file__).resolve().parents[1]
MAP = (SKILL_ROOT / "config" / "sql_memory_map.json").resolve()
MODEL = os.environ.get("ZORG_ANN_MODEL", "embeddinggemma-300m-qat-q8_0")
PROBE = "ANN vector critical self repair always repair 100 percent memory"


def cfg():
    return json.loads(MAP.read_text())["postgres"]


def connect():
    return psycopg2.connect(**cfg())


def ensure_derived_surfaces(conn):
    with conn.cursor() as cur:
        cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
        cur.execute(f"""
            CREATE INDEX IF NOT EXISTS idx_memory_ann_model_embeddings_hnsw_active_local_cosine
            ON public.memory_ann_model_embeddings USING hnsw (embedding vector_cosine_ops)
            WITH (m = 16, ef_construction = 64)
            WHERE active AND embedding_provider = 'local' AND embedding_model = '{MODEL}'
        """)
        cur.execute(f"""
            CREATE OR REPLACE FUNCTION public.memory_ann_recall(p_query text, p_limit integer DEFAULT 20)
            RETURNS TABLE(source_type text, source_id text, path text, line_start integer,
                          line_end integer, priority text, content text,
                          vector_distance double precision, vector_score numeric)
            LANGUAGE sql STABLE AS $$
              SELECT * FROM public.memory_provider_ann_recall(
                p_query, greatest(coalesce(p_limit, 20), 1), 'local', '{MODEL}'
              )
            $$
        """)
        cur.execute("ANALYZE public.memory_ann_model_embeddings")
    conn.commit()


def probe(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM public.memory_ann_model_embeddings WHERE active AND embedding_provider='local' AND embedding_model=%s", (MODEL,))
        active = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM public.zorg_memory_search_fast_mv WHERE btrim(coalesce(content,'')) <> ''")
        expected = cur.fetchone()[0]
        cur.execute("SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_memory_ann_model_embeddings_hnsw_active_local_cosine'")
        index_ok = cur.fetchone() is not None
        cur.execute("SELECT count(*) FROM public.memory_ann_recall(%s, 5)", (PROBE,))
        hits = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM public.memory_semantic_work_queue WHERE status IN ('queued','running','error')")
        pending = cur.fetchone()[0]
        return active, expected, index_ok, hits, pending


def worker():
    script = WORKSPACE / "skills/zorg-db-memory/scripts/memory_semantic_worker.py"
    py = WORKSPACE / ".venv-sqlmem/bin/python"
    result = subprocess.run([str(py), str(script), "--once", "--limit", "50", "--skip-refresh"], cwd=WORKSPACE,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=180)
    return result.returncode == 0, result.stdout[-1000:]


def model_backfill():
    script = WORKSPACE / "skills/zorg-db-memory/scripts/ollama_ann_sync.py"
    py = WORKSPACE / ".venv-sqlmem/bin/python"
    result = subprocess.run([str(py), str(script), "--model", MODEL, "--query", PROBE], cwd=WORKSPACE, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=600)
    return result.returncode == 0, result.stdout[-1000:] + result.stderr[-1000:]


def main():
    lock_path = WORKSPACE / "tmp/zorg-ann-vector-autoheal.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock_handle = lock_path.open("w")
    try:
        fcntl.flock(lock_handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("ANN_VECTOR_AUTOHEAL_SKIPPED already_running")
        return 0
    conn = connect()
    try:
        worker_ok, worker_out = worker()
        active, expected, index_ok, hits, pending = probe(conn)
        backfill_ok, backfill_out = True, "not-needed"
        if not (active > 0 and index_ok and hits > 0):
            backfill_ok, backfill_out = model_backfill()
            ensure_derived_surfaces(conn)
            worker_ok, worker_out = worker()
            active, expected, index_ok, hits, pending = probe(conn)
        status = {"active_embeddings": active, "expected_embeddings": expected,
                  "hnsw_index": index_ok, "ann_hits": hits, "queue_pending": pending,
                  "model": MODEL, "worker_ok": worker_ok}
        if not (active > 0 and index_ok and hits > 0 and worker_ok and backfill_ok):
            print("ANN_VECTOR_AUTOHEAL_FAILED " + json.dumps(status) + " " + backfill_out + worker_out, file=sys.stderr)
            return 1
        print("ANN_VECTOR_AUTOHEAL_OK " + json.dumps(status))
        return 0
    finally:
        conn.close()
        fcntl.flock(lock_handle.fileno(), fcntl.LOCK_UN)
        lock_handle.close()


if __name__ == "__main__":
    raise SystemExit(main())
