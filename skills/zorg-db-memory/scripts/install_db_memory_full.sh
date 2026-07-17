#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${1:-${OPENCLAW_WORKSPACE:-${WORKSPACE_DIR:-${HOME:?}/.openclaw/workspace}}}"
DB_USER="${3:-${ZORG_DB_USER:-zorg}}"
DB_NAME="${4:-${ZORG_DB_NAME:-zorgdb}}"
DB_HOST="${5:-${ZORG_DB_HOST:-127.0.0.1}}"
DB_PORT="${6:-${ZORG_DB_PORT:-5432}}"
DB_PASS="${7:-${ZORG_DB_PASSWORD:-}}"

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SELF_DIR/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

SRC_BASE="${ZORG_SOURCE_BASE:-$(cd "$SELF_DIR/../../../package/zorg" && pwd)}"

mkdir -p "$WORKDIR"
mkdir -p "$WORKDIR/scripts"
mkdir -p "$WORKDIR/skills"
MAP_OUTPUT="${ZORG_SQL_MEMORY_MAP_PATH:-$SKILL_DIR/config/sql_memory_map.json}"
mkdir -p "$(dirname "$MAP_OUTPUT")"

if [ ! -d "$WORKDIR/.venv-sqlmem" ]; then
  python3 -m venv "$WORKDIR/.venv-sqlmem"
fi

"$WORKDIR/.venv-sqlmem/bin/pip" install --upgrade pip >/dev/null
"$WORKDIR/.venv-sqlmem/bin/pip" install psycopg2-binary >/dev/null

STAMP=$(date +%F_%H%M%S)
mkdir -p "$TMPDIR/rollback"
export PGHOST="$DB_HOST" PGPORT="$DB_PORT" PGUSER="$DB_USER" PGDATABASE="$DB_NAME" PGPASSWORD="$DB_PASS"
PG_BIN="${ZORG_POSTGRES_BIN:-$WORKDIR/postgresql-18/native/bin}"
command -v "$PG_BIN/pg_dump" >/dev/null 2>&1 || { echo "native PostgreSQL 18 client tools are required under $PG_BIN" >&2; exit 1; }
"$PG_BIN/pg_dump" --no-owner --no-privileges | gzip -9 > "$TMPDIR/rollback/preapply-$STAMP.sql.gz"

cat "$SRC_BASE/db/schema.sql" | "$PG_BIN/psql" -v ON_ERROR_STOP=1
cat "$SRC_BASE/db/zorg_objects.sql" | "$PG_BIN/psql" -v ON_ERROR_STOP=1
if [ -f "$SRC_BASE/db/zorg_operational_facts_seed.sql" ]; then
  cat "$SRC_BASE/db/zorg_operational_facts_seed.sql" | "$PG_BIN/psql" -v ON_ERROR_STOP=1
fi
if [ -f "$SRC_BASE/db/zorg_success_query_index_seed.sql" ]; then
  cat "$SRC_BASE/db/zorg_success_query_index_seed.sql" | "$PG_BIN/psql" -v ON_ERROR_STOP=1
fi

cp -f "$SRC_BASE/scripts/memory_sql_tool.py" "$WORKDIR/memory_sql_tool.py"
cp -f "$SRC_BASE/scripts/memory_recall_router.py" "$WORKDIR/memory_recall_router.py"
cp -f "$SRC_BASE/scripts/memory_speed_test.py" "$WORKDIR/memory_speed_test.py"
cp -f "$SRC_BASE/scripts/memory_sql_tool" "$WORKDIR/memory_sql_tool"
cp -f "$SRC_BASE/scripts/memory_recall" "$WORKDIR/memory_recall"
chmod +x "/memory_sql_tool.py" "/memory_speed_test.py" "/memory_sql_tool" "/memory_recall"

cat > "$MAP_OUTPUT" <<JSON
{
  "postgres": {
    "host": "$DB_HOST",
    "port": $DB_PORT,
    "database": "$DB_NAME",
    "user": "$DB_USER",
    "password": "$DB_PASS"
  },
  "table_map": {
    "MEMORY.md": "zorg_memory",
    "AGENTS.md": "md_agents",
    "SOUL.md": "md_soul",
    "USER.md": "md_user",
    "TOOLS.md": "md_tools",
    "IDENTITY.md": "md_identity",
    "HEARTBEAT.md": "md_heartbeat"
  }
}
JSON

echo "Rollback dump created at: $TMPDIR/rollback/preapply-$STAMP.sql.gz"
echo "Installed tools into: $WORKDIR"
echo "Run verification next:"
echo "  $WORKDIR/memory_sql_tool.py tables"
echo "  $WORKDIR/memory_speed_test.py"
