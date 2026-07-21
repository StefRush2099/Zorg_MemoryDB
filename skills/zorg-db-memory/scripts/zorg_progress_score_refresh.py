#!/home/openclaw/.openclaw/workspace/.venv-sqlmem/bin/python
import json
from pathlib import Path

import psycopg2

cfg = json.loads(Path('/home/openclaw/.openclaw/workspace/skills/zorg-db-memory/config/sql_memory_map.json').read_text())['postgres']
conn = psycopg2.connect(
    host=cfg['host'],
    port=cfg['port'],
    dbname=cfg['database'],
    user=cfg['user'],
    password=cfg['password'],
)
conn.autocommit = True
cur = conn.cursor()
cur.execute("select * from zorg_compute_progress_score(%s)", ('scheduled refresh',))
print(cur.fetchall())
cur.close()
conn.close()
