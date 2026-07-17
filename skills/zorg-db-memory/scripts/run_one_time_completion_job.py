#!/usr/bin/env python3
"""Run the approved one-time completion job through the PostgreSQL scheduler."""
import json, os, socket, subprocess, sys
from pathlib import Path
import psycopg2

BASE = Path(os.environ.get('OPENCLAW_WORKSPACE','/home/openclaw/.openclaw/workspace'))
SQL_TOOL = BASE / 'memory_sql_tool.py'

def run_sql(sql):
    mapping = json.loads((BASE/'skills/zorg-db-memory/config/sql_memory_map.json').read_text())['postgres']
    with psycopg2.connect(**mapping) as conn, conn.cursor() as cur:
        cur.execute(sql)
        return cur.fetchone()[0]

def main():
    # Backfill is ledger-idempotent; cap files per pass to avoid a large transaction.
    backfill = BASE/'skills/zorg-db-memory/scripts/backfill_typed_runtime_events.py'
    python = BASE/'.venv-sqlmem/bin/python'
    subprocess.run([str(python if python.exists() else sys.executable), str(backfill), '--limit-files', '25'], check=True)
    out = run_sql("select public.memory_db_run_due_jobs_sql(1)")
    print(json.dumps({'worker':socket.gethostname(),'scheduler_result':out}, ensure_ascii=False, default=str))

if __name__ == '__main__': main()
