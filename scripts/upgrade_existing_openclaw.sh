#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_WORKSPACE="${OPENCLAW_WORKSPACE:-${1:-}}"
if [ -z "$TARGET_WORKSPACE" ]; then
  cat >&2 <<'EOF'
Usage:
  OPENCLAW_WORKSPACE=/path/to/existing/openclaw/workspace ./scripts/upgrade_existing_openclaw.sh
  ./scripts/upgrade_existing_openclaw.sh /path/to/existing/openclaw/workspace
EOF
  exit 2
fi
TARGET_WORKSPACE="$(cd "$TARGET_WORKSPACE" && pwd)"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-openclaw_memory}"
DB_USER="${DB_USER:-openclaw_memory}"
DB_PASSWORD="${DB_PASSWORD:-openclaw_memory}"
export DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD

log(){ printf '[Zorg MemoryDB upgrade] %s\n' "$*"; }

ensure_python_env(){
  cd "$TARGET_WORKSPACE"
  if [ -n "${SQLMEM_PYTHON:-}" ] && [ -x "$SQLMEM_PYTHON" ]; then
    PYTHON="$SQLMEM_PYTHON"
  elif [ -x .venv-sqlmem/bin/python ]; then
    PYTHON=".venv-sqlmem/bin/python"
  else
    log "creating Python environment in existing OpenClaw workspace"
    if python3 -m venv .venv-sqlmem >/dev/null 2>&1; then
      PYTHON=".venv-sqlmem/bin/python"
    elif python3 - <<'PY' >/dev/null 2>&1
import psycopg2
PY
    then
      PYTHON="python3"
    else
      log "python3 venv support is unavailable and psycopg2 is not installed"
      log "install python3-venv or set SQLMEM_PYTHON to a Python that has psycopg2"
      exit 1
    fi
  fi
  if ! "$PYTHON" - <<'PY' >/dev/null 2>&1
import psycopg2
PY
  then
    log "installing database driver"
    "$PYTHON" -m pip install --upgrade pip >/dev/null
    "$PYTHON" -m pip install psycopg2-binary >/dev/null
  fi
  export PYTHON
}

copy_files(){
  log "copying DB-memory tools into existing workspace"
  mkdir -p "$TARGET_WORKSPACE/scripts" "$TARGET_WORKSPACE/config" "$TARGET_WORKSPACE/db" "$TARGET_WORKSPACE/memory"
  cp "$REPO_ROOT/scripts/memory_sql_tool.py" "$TARGET_WORKSPACE/memory_sql_tool.py"
  cp "$REPO_ROOT/scripts/memory_recall_router.py" "$TARGET_WORKSPACE/memory_recall_router.py"
  cp "$REPO_ROOT/scripts/memory_speed_test.py" "$TARGET_WORKSPACE/memory_speed_test.py"
  cp "$REPO_ROOT/scripts/import_markdown_memory.py" "$TARGET_WORKSPACE/scripts/import_markdown_memory.py"
  cp "$REPO_ROOT/db/schema.sql" "$TARGET_WORKSPACE/db/schema.sql"
  chmod +x "$TARGET_WORKSPACE/memory_sql_tool.py" "$TARGET_WORKSPACE/memory_recall_router.py" "$TARGET_WORKSPACE/memory_speed_test.py" "$TARGET_WORKSPACE/scripts/import_markdown_memory.py"
}

write_config(){
  cd "$TARGET_WORKSPACE"
  log "writing database memory config"
  "$PYTHON" - <<'PY'
import json, os
cfg={
  "postgres": {
    "host": os.environ["DB_HOST"],
    "port": int(os.environ["DB_PORT"]),
    "database": os.environ["DB_NAME"],
    "user": os.environ["DB_USER"],
    "password": os.environ["DB_PASSWORD"]
  },
  "table_map": {
    "MEMORY.md": "zorg_memory",
    "memory/*.md": "zorg_memory",
    "AGENTS.md": "md_agents",
    "SOUL.md": "md_soul",
    "USER.md": "md_user",
    "TOOLS.md": "md_tools",
    "IDENTITY.md": "md_identity",
    "HEARTBEAT.md": "md_heartbeat"
  }
}
open("sql_memory_map.json","w",encoding="utf-8").write(json.dumps(cfg, indent=2)+"\n")
PY
}

can_connect_db(){
  cd "$TARGET_WORKSPACE"
  "$PYTHON" - <<'PY' >/dev/null 2>&1
import json, psycopg2
cfg=json.load(open('sql_memory_map.json'))['postgres']
conn=psycopg2.connect(host=cfg['host'],port=cfg['port'],dbname=cfg['database'],user=cfg['user'],password=cfg.get('password',''))
conn.close()
PY
}

start_postgres_if_needed(){
  if can_connect_db; then return 0; fi
  cd "$REPO_ROOT"
  if command -v docker >/dev/null 2>&1; then
    log "starting bundled PostgreSQL"
    if docker compose version >/dev/null 2>&1; then
      docker compose up -d postgres >/dev/null
    elif command -v docker-compose >/dev/null 2>&1; then
      docker-compose up -d postgres >/dev/null
    fi
    for _ in $(seq 1 40); do
      if can_connect_db; then return 0; fi
      sleep 2
    done
  fi
  if command -v createdb >/dev/null 2>&1; then
    createdb "$DB_NAME" >/dev/null 2>&1 || true
  fi
  can_connect_db
}

apply_schema(){
  cd "$TARGET_WORKSPACE"
  log "applying memory database schema"
  "$PYTHON" - <<'PY'
import json, pathlib, psycopg2
cfg=json.load(open('sql_memory_map.json'))['postgres']
schema=pathlib.Path('db/schema.sql').read_text(encoding='utf-8')
conn=psycopg2.connect(host=cfg['host'],port=cfg['port'],dbname=cfg['database'],user=cfg['user'],password=cfg.get('password',''))
with conn:
    with conn.cursor() as cur:
        cur.execute(schema)
        cur.execute('select refresh_zorg_memory_search_mv();')
        cur.execute('select refresh_zorg_master_context();')
conn.close()
PY
}

append_rules(){
  cd "$TARGET_WORKSPACE"
  log "updating OpenClaw markdown files with DB-memory rules"
  touch AGENTS.md SOUL.md TOOLS.md MEMORY.md
  marker='<!-- ZORG_MEMORYDB_RULES -->'
  block='<!-- ZORG_MEMORYDB_RULES -->

## Zorg MemoryDB Rules

- Check database memory before acting.
- Prefer DB-backed recall over flat-file lookup.
- Use markdown files as durable source material and as fallback when DB recall is unavailable.
- Import existing markdown memory into the DB after setup and refresh materialized views.
- Preserve original memory history; improve recall additively with indexes, views, summaries, and relationship tables.
<!-- /ZORG_MEMORYDB_RULES -->
'
  for file in AGENTS.md SOUL.md TOOLS.md MEMORY.md; do
    if ! grep -q "$marker" "$file"; then
      printf '\n%s\n' "$block" >> "$file"
    fi
  done
}

import_and_verify(){
  cd "$TARGET_WORKSPACE"
  log "importing existing markdown memory into database"
  OPENCLAW_WORKSPACE="$TARGET_WORKSPACE" SQL_MEMORY_MAP="$TARGET_WORKSPACE/sql_memory_map.json" "$PYTHON" scripts/import_markdown_memory.py >/dev/null
  OPENCLAW_WORKSPACE="$TARGET_WORKSPACE" SQL_MEMORY_MAP="$TARGET_WORKSPACE/sql_memory_map.json" "$PYTHON" memory_sql_tool.py refresh >/dev/null
  OPENCLAW_WORKSPACE="$TARGET_WORKSPACE" SQL_MEMORY_MAP="$TARGET_WORKSPACE/sql_memory_map.json" "$PYTHON" memory_sql_tool.py tables
  log "existing OpenClaw workspace is now attached to DB memory"
}

ensure_python_env
copy_files
write_config
start_postgres_if_needed || { log "could not reach PostgreSQL. Start PostgreSQL/Docker or provide DB_* env vars, then rerun."; exit 1; }
apply_schema
append_rules
import_and_verify
