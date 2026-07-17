#!/usr/bin/env python3
"""Resumable historical runner; PostgreSQL owns the durable cursor and audit."""
import glob,json,os,subprocess,sys
from pathlib import Path
import psycopg2

BASE=Path(os.environ.get('OPENCLAW_WORKSPACE','/home/openclaw/.openclaw/workspace'))
ROOT=Path.home()/'.openclaw/agents/main/sessions'
JOB='memory-completion-full-historical-20260716'
MAP=json.loads((BASE/'skills/zorg-db-memory/config/sql_memory_map.json').read_text())['postgres']
PY=BASE/'.venv-sqlmem/bin/python'

def main():
    files=sorted(Path(x) for x in glob.glob(str(ROOT/'*.trajectory.jsonl')))
    with psycopg2.connect(**MAP) as c, c.cursor() as cur:
        cur.execute("select next_path,files_done,events_seen,events_inserted from public.memory_completion_checkpoints where job_key=%s",(JOB,)); row=cur.fetchone()
    start=row[0] if row else None; idx=next((i for i,p in enumerate(files) if str(p)==start),0) if start else 0
    done,seen,inserted=(row[1],row[2],row[3]) if row else (0,0,0)
    for i,path in enumerate(files[idx:],idx):
        try:
            r=subprocess.run([str(PY),str(BASE/'skills/zorg-db-memory/scripts/backfill_typed_runtime_events.py'),'--glob',str(path)],capture_output=True,text=True,check=True)
            x=json.loads(r.stdout); seen+=x['events_seen']; inserted+=x['events_inserted']; done+=1
            nxt=str(files[i+1]) if i+1<len(files) else None
            with psycopg2.connect(**MAP) as c, c.cursor() as cur:
                cur.execute("select public.memory_completion_checkpoint(%s,%s,%s,%s,%s,%s,%s,%s)",(JOB,str(ROOT),nxt,len(files),done,seen,inserted,'completed' if nxt is None else 'running'))
        except Exception as e:
            with psycopg2.connect(**MAP) as c, c.cursor() as cur:
                cur.execute("select public.memory_completion_checkpoint(%s,%s,%s,%s,%s,%s,%s,%s,%s)",(JOB,str(ROOT),str(path),len(files),done,seen,inserted,'error',str(e)[:2000]))
            raise
    print(json.dumps({'job':JOB,'files_total':len(files),'files_done':done,'events_seen':seen,'events_inserted':inserted}))

if __name__=='__main__': main()
