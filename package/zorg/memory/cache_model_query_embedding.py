#!/usr/bin/env python3
"""Cache one query embedding for DB-owned ANN recall."""
import hashlib, json, os, sys, urllib.request
from pathlib import Path
import psycopg2

BASE=Path(os.environ.get('OPENCLAW_WORKSPACE') or Path.home()/'.openclaw'/'workspace').expanduser()
PROVIDER=os.environ.get('ZORG_EMBEDDING_PROVIDER','local')
MODEL=os.environ.get('ZORG_EMBEDDING_MODEL','nomic-embed-text:latest')
ENDPOINT=os.environ.get('ZORG_EMBEDDING_ENDPOINT','http://127.0.0.1:11434/api/embed')
def main():
    query=sys.stdin.read().strip()
    if not query: return 0
    cfg=json.loads((Path(os.environ.get('SQL_MEMORY_MAP') or BASE/'sql_memory_map.json')).read_text())['postgres']
    req=urllib.request.Request(ENDPOINT,data=json.dumps({'model':MODEL,'input':query}).encode(),headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(req,timeout=30) as r: data=json.loads(r.read())
    vectors=data.get('embeddings') or ([data['embedding']] if data.get('embedding') else [])
    if not vectors: raise RuntimeError('embedding endpoint returned no vector')
    with psycopg2.connect(host=cfg['host'],port=cfg['port'],dbname=cfg['database'],user=cfg['user'],password=cfg.get('password','')) as conn:
      with conn.cursor() as cur:
        cur.execute("""insert into memory_query_embedding_cache(query_hash,query_text,embedding_provider,embedding_model,embedding_dim,embedding,metadata) values (%s,%s,%s,%s,%s,%s::vector,%s) on conflict(query_hash,embedding_provider,embedding_model) do update set embedding=excluded.embedding,embedding_dim=excluded.embedding_dim,updated_at=now()""",(hashlib.md5(query.lower().strip().encode()).hexdigest(),query,PROVIDER,MODEL,len(vectors[0]),'['+','.join(map(str,vectors[0]))+']',json.dumps({'source':'cache_model_query_embedding.py'})))
    return 0
if __name__=='__main__': raise SystemExit(main())
