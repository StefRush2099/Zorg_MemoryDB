#!/usr/bin/env python3
"""Populate mapped core-rule markdown tables from a workspace.

Does not ship private data; run locally after install. MEMORY.md is imported as
namespaced bootstrap/recovery rows, not as the active durable memory source.
"""
import glob, json, os
from pathlib import Path
import psycopg2
BASE=Path(os.environ.get('OPENCLAW_WORKSPACE', Path.cwd()))
MAP=Path(os.environ.get('SQL_MEMORY_MAP', BASE/'sql_memory_map.json'))
cfg=json.loads(MAP.read_text())
p=cfg['postgres']
conn=psycopg2.connect(host=p['host'],port=p['port'],dbname=p['database'],user=p['user'],password=p.get('password',''))
md_tables={k:v for k,v in cfg['table_map'].items() if v.startswith('md_')}
memory_files={k:v for k,v in cfg['table_map'].items() if v == 'zorg_memory'}
with conn, conn.cursor() as cur:
    for pattern, table in md_tables.items():
        paths=glob.glob(str(BASE/pattern))
        cur.execute(f'truncate table {table}')
        for path in paths:
            for i,line in enumerate(Path(path).read_text(encoding='utf-8',errors='ignore').splitlines(),1):
                cur.execute(f'insert into {table}(line_no,line_text) values (%s,%s)',(i,line))

    for pattern, table in memory_files.items():
        paths=glob.glob(str(BASE/pattern))
        for path in paths:
            rel_path=str(Path(path).relative_to(BASE))
            for i,line in enumerate(Path(path).read_text(encoding='utf-8',errors='ignore').splitlines(),1):
                cur.execute(
                    """
                    insert into public.zorg_memory
                      (chat_session_log,logged_at,memory_key,memory_value,memory_effective_date,memory_category,memory_priority,memory_active)
                    values
                      (%s,now(),%s,%s,current_date,%s,%s,true)
                    on conflict (memory_key) where memory_key like 'core-markdown::%%'
                    do update set
                      chat_session_log=excluded.chat_session_log,
                      logged_at=excluded.logged_at,
                      memory_value=excluded.memory_value,
                      memory_effective_date=excluded.memory_effective_date,
                      memory_category=excluded.memory_category,
                      memory_priority=excluded.memory_priority,
                      memory_active=true
                    """,
                    (f'{rel_path}:{i} {line}', f'core-markdown::{rel_path}:{i}', line, 'core_markdown_bootstrap', 'high'),
                )

    cur.execute('select refresh_zorg_memory_search_mv();')
    cur.execute('select refresh_zorg_memory_search_fast_mv();')
    cur.execute('select refresh_zorg_master_context();')
print('imported markdown memory tables')
