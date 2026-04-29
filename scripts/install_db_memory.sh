#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?Set DATABASE_URL, e.g. postgresql://user:pass@127.0.0.1:5432/openclaw_memory}"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/schema.sql
cp -n config/sql_memory_map.example.json sql_memory_map.json || true
python3 -m venv .venv-sqlmem
. .venv-sqlmem/bin/activate
pip install --upgrade pip >/dev/null
pip install psycopg2-binary >/dev/null
printf 'Installed schema and Python dependencies. Edit sql_memory_map.json, then run:\n  .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables\n'
