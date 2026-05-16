#!/usr/bin/env python3
"""Populate mapped core-rule markdown tables from a workspace.

Does not ship private data; run locally after install. MEMORY.md is not a
durable memory source and is intentionally excluded from this importer.
"""
import glob, json, os
from pathlib import Path
import psycopg2
BASE=Path(os.environ.get('OPENCLAW_WORKSPACE', Path.cwd()))
MAP=Path(os.environ.get('SQL_MEMORY_MAP', BASE/'sql_memory_map.json'))
cfg=json.loads(MAP.read_text())
p=cfg['postgres']
conn=psycopg2.connect(host=p['host'],port=p['port'],dbname=p['database'],user=p['user'])
md_tables={k:v for k,v in cfg['table_map'].items() if v.startswith('md_')}
with conn, conn.cursor() as cur:
    for pattern, table in md_tables.items():
        paths=glob.glob(str(BASE/pattern))
        cur.execute(f'truncate table {table}')
        for path in paths:
            for i,line in enumerate(Path(path).read_text(encoding='utf-8',errors='ignore').splitlines(),1):
                cur.execute(f'insert into {table}(line_no,line_text) values (%s,%s)',(i,line))

    cur.execute('select refresh_zorg_memory_search_mv();')
    cur.execute('select refresh_zorg_memory_search_fast_mv();')
    cur.execute('select refresh_zorg_master_context();')
print('imported markdown memory tables')
