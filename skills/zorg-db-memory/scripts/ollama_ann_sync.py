#!/usr/bin/env python3
"""Synchronize searchable PostgreSQL rows with an Ollama/pgvector ANN index."""

import argparse
import hashlib
import json
from pathlib import Path
import urllib.request

import psycopg2


SOURCE_TYPES = {
    "zorg_logic_rules": "logic_rule",
    "zorg_memory": "memory",
    "memory_source_chunks": "source_chunk",
    "lan_chat_messages": "lan_chat",
}


def embed(endpoint, model, texts):
    body = json.dumps({"model": model, "input": texts}).encode()
    request = urllib.request.Request(endpoint, body, {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=300) as response:
        vectors = json.load(response)["embeddings"]
    if len(vectors) != len(texts) or any(len(vector) != 768 for vector in vectors):
        raise RuntimeError("Ollama returned an unexpected vector count or dimension")
    return vectors


def vector_literal(vector):
    return "[" + ",".join(format(value, ".9g") for value in vector) + "]"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dsn")
    parser.add_argument("--endpoint", default="http://127.0.0.1:11434/api/embed")
    parser.add_argument("--model", default="nomic-embed-text:latest")
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--missing-only", action="store_true")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--query", action="append", default=[])
    parser.add_argument("--source-key", action="append", default=[], help="embed only matching canonical source IDs")
    parser.add_argument("--skip-refresh", action="store_true", help="use the already refreshed search view")
    args = parser.parse_args()

    if args.dsn:
        connection = psycopg2.connect(args.dsn)
    else:
        config_path = Path(__file__).resolve().parents[1] / "config" / "sql_memory_map.json"
        connection = psycopg2.connect(**json.loads(config_path.read_text())["postgres"])
    connection.autocommit = False
    with connection, connection.cursor() as cursor:
        if not args.skip_refresh:
            cursor.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY public.zorg_memory_search_fast_mv")
        cursor.execute("""
            SELECT source_table, source_id, priority, event_ts, content
            FROM public.zorg_memory_search_fast_mv
            WHERE btrim(coalesce(content, '')) <> ''
            ORDER BY
              CASE source_table
                WHEN 'zorg_logic_rules' THEN 0
                WHEN 'runbook' THEN 1
                WHEN 'memory_source_chunks' THEN 2
                ELSE 3
              END,
              CASE lower(coalesce(priority, ''))
                WHEN 'critical' THEN 0
                WHEN '100' THEN 1
                WHEN '95' THEN 2
                ELSE 3
              END,
              source_table,
              source_id
        """)
        rows = cursor.fetchall()
        if args.source_key:
            wanted = set(args.source_key)
            rows = [row for row in rows if str(row[1]) in wanted]
        if args.missing_only:
            cursor.execute(
                """
                SELECT source_type, source_key
                FROM public.memory_ann_model_embeddings
                WHERE active AND embedding_provider='local' AND embedding_model=%s
                """,
                (args.model,),
            )
            existing = set(cursor.fetchall())
            rows = [
                row for row in rows
                if (SOURCE_TYPES.get(row[0], row[0]), str(row[1])) not in existing
            ]
        if args.limit is not None:
            rows = rows[:max(args.limit, 0)]

        active_keys = set()
        for offset in range(0, len(rows), args.batch_size):
            batch = rows[offset:offset + args.batch_size]
            vectors = embed(args.endpoint, args.model, [row[4] for row in batch])
            for row, vector in zip(batch, vectors):
                source_table, source_key, priority, event_ts, content = row
                source_type = SOURCE_TYPES.get(source_table, source_table)
                content_hash = hashlib.sha256(content.encode()).hexdigest()
                active_keys.add((source_type, source_key, content_hash))
                cursor.execute("""
                    UPDATE public.memory_ann_model_embeddings
                    SET active = false, updated_at = now()
                    WHERE source_type = %s AND source_key = %s
                      AND embedding_provider = 'local' AND embedding_model = %s
                      AND content_hash <> %s AND active
                """, (source_type, source_key, args.model, content_hash))
                cursor.execute("""
                    INSERT INTO public.memory_ann_model_embeddings
                      (source_type, source_key, embedding_provider, embedding_model,
                       embedding_dim, embedding, content_hash, content_text, priority,
                       event_ts, metadata, active)
                    VALUES (%s, %s, 'local', %s, 768, %s::vector, %s, %s, %s, %s,
                            jsonb_build_object('source_table', %s, 'sync', 'ollama'), true)
                    ON CONFLICT (source_type, source_key, embedding_provider, embedding_model, content_hash)
                    DO UPDATE SET embedding = EXCLUDED.embedding, content_text = EXCLUDED.content_text,
                                  priority = EXCLUDED.priority, event_ts = EXCLUDED.event_ts,
                                  metadata = EXCLUDED.metadata, active = true, updated_at = now()
                """, (source_type, source_key, args.model, vector_literal(vector), content_hash,
                      content, priority, event_ts, source_table))
            connection.commit()
            if offset == 0 or (offset // args.batch_size + 1) % 100 == 0:
                print(
                    json.dumps(
                        {"embedded": min(offset + len(batch), len(rows)), "total": len(rows)}
                    ),
                    flush=True,
                )

        queries = list(dict.fromkeys(args.query))
        if queries:
            for query, vector in zip(queries, embed(args.endpoint, args.model, queries)):
                query_hash = hashlib.md5(query.strip().lower().encode()).hexdigest()
                cursor.execute("""
                    INSERT INTO public.memory_query_embedding_cache
                      (query_hash, query_text, embedding_provider, embedding_model,
                       embedding_dim, embedding, metadata, active)
                    VALUES (%s, %s, 'local', %s, 768, %s::vector,
                            '{"sync":"ollama"}'::jsonb, true)
                    ON CONFLICT (query_hash, embedding_provider, embedding_model)
                    DO UPDATE SET query_text = EXCLUDED.query_text, embedding = EXCLUDED.embedding,
                                  metadata = EXCLUDED.metadata, active = true, updated_at = now()
                """, (query_hash, query, args.model, vector_literal(vector)))

    print(json.dumps({"source_rows": len(rows), "queries_cached": len(queries), "model": args.model}))


if __name__ == "__main__":
    main()
