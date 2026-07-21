#!/usr/bin/env python3
"""Populate the local pgvector ANN store through an Ollama-compatible embed API."""
import argparse, hashlib, json, os, socket, sys, urllib.request
from pathlib import Path
import psycopg2
from psycopg2.extras import Json, RealDictCursor

BASE = Path(os.environ.get('OPENCLAW_WORKSPACE') or Path.home() / '.openclaw' / 'workspace').expanduser()
MAP = Path(os.environ.get('SQL_MEMORY_MAP') or BASE / 'sql_memory_map.json')
PROVIDER = os.environ.get('ZORG_EMBEDDING_PROVIDER', 'local')
MODEL = os.environ.get('ZORG_EMBEDDING_MODEL', 'nomic-embed-text:latest')
OLLAMA_URL = os.environ.get('ZORG_EMBEDDING_ENDPOINT', 'http://127.0.0.1:11434/api/embed')
WORKER = f'embedding-worker@{socket.gethostname()}'
SUPPORTED_SOURCE_TYPES = ('zorg_memory', 'logic_rule', 'source_chunk')

def connect():
    cfg = json.loads(MAP.read_text())['postgres']
    return psycopg2.connect(host=cfg['host'], port=cfg['port'], dbname=cfg['database'], user=cfg['user'], password=cfg.get('password', ''))

def embed(text):
    req = urllib.request.Request(OLLAMA_URL, data=json.dumps({'model': MODEL, 'input': text}).encode(), headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=int(os.environ.get('ZORG_EMBEDDING_TIMEOUT', '120'))) as response:
        data = json.loads(response.read())
    vectors = data.get('embeddings') or ([data['embedding']] if data.get('embedding') else [])
    if not vectors:
        raise RuntimeError('embedding endpoint returned no vector')
    return vectors[0]

def source_text(cur, source_type, source_key):
    queries = {
        'memory': ("select concat_ws(E'\\n', memory_key, memory_value, chat_session_log, system_prompt, ai_response) as content from zorg_memory where id=%s",),
        'zorg_memory': ("select concat_ws(E'\\n', memory_key, memory_value, chat_session_log, system_prompt, ai_response) as content from zorg_memory where id=%s",),
        'logic_rule': ('select rule_text as content from zorg_logic_rules where id=%s and active',),
        'source_chunk': ('select content from memory_source_chunks where id=%s',),
    }
    query = queries.get(source_type)
    if not query: return ''
    lookup_key = source_key.rsplit(':', 1)[-1]
    cur.execute(query[0], (lookup_key,)); row = cur.fetchone()
    return (row['content'] or '').strip() if row else ''

def run(limit):
    count = 0
    with connect() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""select * from memory_semantic_work_queue where status='queued' and due_at<=now() and attempts<max_attempts and source_type = any(%s) order by created_at limit %s for update skip locked""", (list(SUPPORTED_SOURCE_TYPES), limit))
            jobs = cur.fetchall()
            for job in jobs:
                cur.execute("savepoint ann_job")
                try:
                    cur.execute("update memory_semantic_work_queue set status='running',locked_at=now(),locked_by=%s,attempts=attempts+1,updated_at=now() where id=%s", (WORKER, job['id']))
                    text = source_text(cur, job['source_type'], job['source_key'])
                    if not text: raise RuntimeError('source text unavailable')
                    vector = embed(text)
                    digest = hashlib.sha256(text.encode()).hexdigest()
                    cur.execute("""insert into memory_ann_model_embeddings(source_type,source_key,embedding_provider,embedding_model,embedding_dim,embedding,content_hash,content_text,priority,event_ts,metadata) values (%s,%s,%s,%s,%s,%s::vector,%s,%s,'medium',now(),%s) on conflict (source_type,source_key,embedding_provider,embedding_model,content_hash) do update set embedding=excluded.embedding,embedding_dim=excluded.embedding_dim,content_text=excluded.content_text,active=true,updated_at=now()""", (job['source_type'],job['source_key'],PROVIDER,MODEL,len(vector),'['+','.join(map(str,vector))+']',digest,text,Json({'worker':WORKER})))
                    cur.execute("update memory_semantic_work_queue set status='done',completed_at=now(),updated_at=now(),last_error=null where id=%s", (job['id'],)); count += 1
                except Exception as exc:
                    cur.execute("rollback to savepoint ann_job")
                    cur.execute("update memory_semantic_work_queue set status=case when attempts>=max_attempts then 'failed' else 'queued' end,last_error=%s,updated_at=now() where id=%s", (str(exc)[:1000],job['id']))
                finally:
                    cur.execute("release savepoint ann_job")
        conn.commit()
    return count

def enqueue_sources():
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("insert into memory_semantic_work_queue(job_kind,source_type,source_key,payload,payload_hash) select 'semantic_embedding','zorg_memory',id::text,jsonb_build_object('table','zorg_memory'),md5(jsonb_build_object('table','zorg_memory')::text) from zorg_memory where not exists (select 1 from memory_semantic_work_queue q where q.source_type='zorg_memory' and q.source_key=zorg_memory.id::text)")
            cur.execute("insert into memory_semantic_work_queue(job_kind,source_type,source_key,payload,payload_hash) select 'semantic_embedding','logic_rule',id::text,jsonb_build_object('table','zorg_logic_rules'),md5(jsonb_build_object('table','zorg_logic_rules')::text) from zorg_logic_rules where active and not exists (select 1 from memory_semantic_work_queue q where q.source_type='logic_rule' and q.source_key=zorg_logic_rules.id::text)")
            cur.execute("insert into memory_semantic_work_queue(job_kind,source_type,source_key,payload,payload_hash) select 'semantic_embedding','source_chunk',id::text,jsonb_build_object('table','memory_source_chunks'),md5(jsonb_build_object('table','memory_source_chunks')::text) from memory_source_chunks where not exists (select 1 from memory_semantic_work_queue q where q.source_type='source_chunk' and q.source_key=memory_source_chunks.id::text)")
        conn.commit()

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--once',action='store_true'); ap.add_argument('--limit',type=int,default=50); ap.add_argument('--maintenance',action='store_true'); args=ap.parse_args()
    if args.maintenance: enqueue_sources()
    print(json.dumps({'embedded': run(max(1,args.limit)), 'model': MODEL, 'endpoint': OLLAMA_URL}))
if __name__ == '__main__': main()
