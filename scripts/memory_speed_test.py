#!/usr/bin/env python3
import json, os, statistics, time
from pathlib import Path
import psycopg2
BASE=Path(os.environ.get('OPENCLAW_WORKSPACE', Path.cwd()))
MAP=Path(os.environ.get('SQL_MEMORY_MAP', BASE/'sql_memory_map.json'))
QUERIES=['OpenClaw','memory','directive','project','database']; RUNS=10
cfg=json.loads(MAP.read_text())['postgres']; password=os.environ.get('PGPASSWORD', cfg.get('password',''))
def timed(fn,*args):
    t=time.perf_counter(); out=fn(*args); return out,(time.perf_counter()-t)*1000
with psycopg2.connect(host=cfg['host'],port=cfg['port'],dbname=cfg['database'],user=cfg['user'],password=password) as conn, conn.cursor() as cur:
    results={}
    for q in QUERIES:
        times=[]; count=0
        for _ in range(RUNS):
            def run():
                cur.execute('select count(*) from zorg_memory_search_mv where content ilike %s',(f'%{q}%',)); return cur.fetchone()[0]
            count,dt=timed(run); times.append(dt)
        results[q]={'db_count':count,'db_ms_avg':round(statistics.mean(times),3),'db_ms_p95':round(sorted(times)[int(RUNS*.95)-1],3)}
print(json.dumps({'runs_per_query':RUNS,'results':results}, indent=2))
