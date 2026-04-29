#!/usr/bin/env python3
"""Populate mapped markdown tables from a workspace. Does not ship private data; run locally after install."""
import glob, json, os
from pathlib import Path
import psycopg2
BASE=Path(os.environ.get('OPENCLAW_WORKSPACE', Path.cwd()))
MAP=Path(os.environ.get('SQL_MEMORY_MAP', BASE/'sql_memory_map.json'))
cfg=json.loads(MAP.read_text())
p=cfg['postgres']; password=os.environ.get('PGPASSWORD', p.get('password',''))
conn=psycopg2.connect(host=p['host'],port=p['port'],dbname=p['database'],user=p['user'],password=password)
md_tables={k:v for k,v in cfg['table_map'].items() if v.startswith('md_')}
with conn, conn.cursor() as cur:
    for pattern, table in md_tables.items():
        paths=glob.glob(str(BASE/pattern))
        cur.execute(f'truncate table {table}')
        for path in paths:
            for i,line in enumerate(Path(path).read_text(encoding='utf-8',errors='ignore').splitlines(),1):
                cur.execute(f'insert into {table}(line_no,line_text) values (%s,%s)',(i,line))

    # Import durable memory markdown into zorg_memory so the unified recall
    # surface can search it immediately on a fresh install.
    cur.execute('truncate table zorg_memory')
    memory_paths = []
    for pattern, table in cfg['table_map'].items():
        if table == 'zorg_memory':
            memory_paths.extend(glob.glob(str(BASE/pattern)))
    for path in sorted(set(memory_paths)):
        for i,line in enumerate(Path(path).read_text(encoding='utf-8',errors='ignore').splitlines(),1):
            text=line.strip()
            if not text or text.startswith('<!--'):
                continue
            low=text.lower()
            category='directive' if any(w in low for w in ['rule','must','always','never','before acting','memory']) else 'note'
            priority='high' if category == 'directive' else 'medium'
            key=f'{Path(path).name}:{i}'
            cur.execute(
                'insert into zorg_memory(chat_session_log,memory_key,memory_value,memory_category,memory_priority,memory_active) values (%s,%s,%s,%s,%s,true)',
                (f'Imported from {Path(path).name}:{i}', key, text, category, priority)
            )

    cur.execute('select refresh_zorg_memory_search_mv();')
    cur.execute('select refresh_zorg_master_context();')
print('imported markdown memory tables')
