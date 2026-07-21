#!/usr/bin/env python3
"""Backfill OpenClaw trajectory/tool events into typed Zorg MemoryDB tables."""
import argparse, glob, hashlib, json, os, uuid
from pathlib import Path
import psycopg2
from psycopg2.extras import Json

BASE=Path(os.environ.get('OPENCLAW_WORKSPACE','/home/openclaw/.openclaw/workspace'))
MAP=Path(os.environ.get('SQL_MEMORY_MAP', BASE/'skills/zorg-db-memory/config/sql_memory_map.json'))

def db():
    p=json.loads(MAP.read_text())['postgres']
    return psycopg2.connect(host=p['host'],port=p['port'],dbname=p['database'],user=p['user'],password=p['password'])

def safe(v, limit=20000):
    # Preserve operational shape while avoiding accidental credential/config capture.
    if isinstance(v, dict):
        return {k: safe(x, limit) for k,x in v.items() if k.lower() not in {'config','env','environment','authorization','token','password','secret','api_key','credential','headers'}}
    if isinstance(v, list): return [safe(x, limit) for x in v[:100]]
    s=str(v) if v is not None else ''
    return ''.join(ch for ch in s[:limit] if ch in '\n\r\t' or ord(ch) >= 32)

def classify(e):
    t=e.get('type',''); d=safe(e.get('data',{}));
    if t in ('toolCall','tool.call','tool_call') or e.get('name'): return 'tool_call', {'tool_name':e.get('name',t),'arguments':safe(e.get('arguments',d)),'status':'recorded','metadata':{'source_type':t,'seq':e.get('seq')}}
    if t in ('toolResult','tool.result','tool_result'): return 'tool_result', {'result_kind':t,'result_text':safe(e.get('content',d)),'result_hash':hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest(),'status':'recorded'}
    if t in ('assistant.message','assistant_message','model.completed') or e.get('role')=='assistant':
        content=e.get('content') or d
        if t=='model.completed': content={'assistantTexts':d.get('assistantTexts',[]),'messagesSnapshot':d.get('messagesSnapshot',[]),'modelId':e.get('modelId')}
        return 'model_output', {'content':safe(content),'metadata':{'source_type':t,'seq':e.get('seq'),'model_id':e.get('modelId')}}
    if t in ('code.operation','code_operation','patch','command'): return 'code_operation', {'operation_kind':t,'target_path':e.get('path') or e.get('target'),'detail':safe(d)}
    if t in ('correction','operator.correction'): return 'correction', {'correction_kind':t,'before_text':safe(e.get('before')),'after_text':safe(e.get('after') or e.get('content') or d),'metadata':{'seq':e.get('seq')}}
    if t in ('verification','verify','test.result'): return 'verification', {'verification_kind':t,'subject_type':e.get('subjectType','event'),'passed':bool(e.get('passed',e.get('ok',False))),'evidence':safe(d)}
    if 'error' in t.lower() or e.get('isError'): return 'error', {'error_kind':t,'error_text':safe(e.get('error',d)),'metadata':{'seq':e.get('seq')}}
    if t.startswith('session.') or t.startswith('trace.'):
        return 'external_action', {'action_kind':t,'target':'openclaw-runtime','request':{'sequence':e.get('seq'),'source':e.get('source')},'outcome':safe(d),'status':'recorded'}
    return 'decision', {'decision_kind':t or 'runtime_event','decision_text':json.dumps(safe(d),sort_keys=True),'basis':{'source':e.get('source'),'seq':e.get('seq')}}

def run(paths):
    inserted=0; seen=0
    with db() as conn, conn.cursor() as cur:
        for path in paths:
            source=str(path)
            with open(path,encoding='utf-8',errors='replace') as fh:
                for line in fh:
                    try: e=json.loads(line)
                    except json.JSONDecodeError: continue
                    expanded=[e]
                    snapshot=e.get('data',{}).get('messagesSnapshot',[]) if isinstance(e.get('data'),dict) else []
                    expanded.extend(x for x in snapshot if isinstance(x,dict))
                    for event_no, item in enumerate(expanded):
                        seen+=1; digest=hashlib.sha256((line+'#'+str(event_no)).encode()).hexdigest()
                        kind,payload=classify(item); turn=str(e.get('traceId') or e.get('sessionId') or path.stem)
                        if item is not e:
                            payload.setdefault('metadata',{}).update({'parent_type':e.get('type'),'parent_seq':e.get('seq')})
                        cur.execute("select 1 from public.memory_ingestion_ledger where source_name=%s and source_event_hash=%s",(source,digest))
                        if cur.fetchone(): continue
                        cur.execute("select public.memory_record_typed_event(%s,%s,%s,%s)",(kind,turn,None,Json(payload)))
                        typed_id=cur.fetchone()[0]
                        cur.execute("insert into public.memory_ingestion_ledger(source_name,source_event_hash,event_kind,typed_id) values(%s,%s,%s,%s)",(source,digest,kind,typed_id)); inserted+=1
        conn.commit()
    return seen,inserted

if __name__=='__main__':
    ap=argparse.ArgumentParser(); ap.add_argument('--glob',default=str(Path.home()/'.openclaw/agents/main/sessions/*.trajectory.jsonl')); ap.add_argument('--limit-files',type=int,default=0); a=ap.parse_args()
    paths=[Path(x) for x in glob.glob(a.glob)]; paths=paths[:a.limit_files] if a.limit_files else paths
    seen,inserted=run(paths); print(json.dumps({'files':len(paths),'events_seen':seen,'events_inserted':inserted}))
