#!/usr/bin/env python3
"""Cache one canonical 768-dimension query embedding without refreshing source views."""
import argparse, hashlib, json, os, urllib.request
from pathlib import Path
import psycopg2

MODEL = "embeddinggemma-300m-qat-q8_0"
def vector_literal(values): return "[" + ",".join(format(v, ".9g") for v in values) + "]"
def main():
    ap=argparse.ArgumentParser(); ap.add_argument("query"); ap.add_argument("--endpoint",default=os.environ.get("ZORG_QUERY_EMBED_ENDPOINT","http://127.0.0.1:11434/api/embed")); args=ap.parse_args()
    workspace=Path(os.environ.get("OPENCLAW_WORKSPACE") or os.environ.get("WORKSPACE_DIR") or Path(__file__).resolve().parents[3])
    cfg_path=Path(os.environ.get("SQL_MEMORY_MAP") or os.environ.get("ZORG_SQL_MEMORY_MAP") or workspace/"skills/zorg-db-memory/config/sql_memory_map.json")
    cfg=json.loads(cfg_path.read_text())["postgres"]
    query=args.query.strip()
    if not query: return 0
    with psycopg2.connect(**cfg) as conn, conn.cursor() as cur:
        cur.execute("select public.memory_query_embedding_cache_exists_v1(%s,'local',%s)",(query,MODEL))
        if cur.fetchone()[0]: print(json.dumps({"ok":True,"cached":True,"existing":True})); return 0
        req=urllib.request.Request(args.endpoint,json.dumps({"model":MODEL,"input":query}).encode(),{"Content-Type":"application/json"})
        with urllib.request.urlopen(req,timeout=20) as response: body=json.load(response)
        vector=(body.get("embeddings") or [body.get("embedding")])[0]
        if not vector or len(vector)!=768: raise RuntimeError(f"invalid vector dimension {len(vector) if vector else 0}")
        cur.execute("select public.memory_cache_query_embedding(%s,%s::vector,'local',%s,%s::jsonb)",(query,vector_literal(vector),MODEL,json.dumps({"source":"query_only_cache"})))
        cur.execute("select public.memory_query_embedding_cache_exists_v1(%s,'local',%s)",(query,MODEL))
        verified=bool(cur.fetchone()[0])
    print(json.dumps({"ok":verified,"cached":verified,"existing":False})); return 0 if verified else 1
if __name__=="__main__": raise SystemExit(main())
