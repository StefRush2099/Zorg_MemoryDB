#!/usr/bin/env bash
set -euo pipefail

WORKDIR=${1:-/home/openclaw/.openclaw/workspace}
DB_CONT=${2:-local-postgres}
DB_USER=${3:-zorg}
DB_NAME=${4:-zorgdb}
DB_HOST=${5:-10.7.69.200}
DB_PORT=${6:-5432}
DB_PASS=${7:-zorg_local_2026}

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SELF_DIR/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

SRC_BASE="/home/openclaw/.openclaw/workspace/Zorg_Hive/apps/by-host/openclaw/Zorg_spawn"

mkdir -p "$WORKDIR"
mkdir -p "$WORKDIR/scripts"
mkdir -p "$WORKDIR/skills"

if [ ! -d "$WORKDIR/.venv-sqlmem" ]; then
  python3 -m venv "$WORKDIR/.venv-sqlmem"
fi

"$WORKDIR/.venv-sqlmem/bin/pip" install --upgrade pip >/dev/null
"$WORKDIR/.venv-sqlmem/bin/pip" install psycopg2-binary >/dev/null

STAMP=$(date +%F_%H%M%S)
mkdir -p "$TMPDIR/rollback"
docker exec "$DB_CONT" pg_dump -U "$DB_USER" -d "$DB_NAME" --no-owner --no-privileges | gzip -9 > "$TMPDIR/rollback/preapply-$STAMP.sql.gz"

cat "$SRC_BASE/db/schema.sql" | docker exec -i "$DB_CONT" psql -U "$DB_USER" -d "$DB_NAME"
cat "$SRC_BASE/db/zorg_objects.sql" | docker exec -i "$DB_CONT" psql -U "$DB_USER" -d "$DB_NAME"
if [ -f "$SRC_BASE/db/zorg_operational_facts_seed.sql" ]; then
  cat "$SRC_BASE/db/zorg_operational_facts_seed.sql" | docker exec -i "$DB_CONT" psql -U "$DB_USER" -d "$DB_NAME"
fi
if [ -f "$SRC_BASE/db/zorg_success_query_index_seed.sql" ]; then
  cat "$SRC_BASE/db/zorg_success_query_index_seed.sql" | docker exec -i "$DB_CONT" psql -U "$DB_USER" -d "$DB_NAME"
fi

cp -f "$SRC_BASE/scripts/memory_sql_tool.py" "$WORKDIR/memory_sql_tool.py"
cp -f "$SRC_BASE/scripts/memory_recall_router.py" "$WORKDIR/memory_recall_router.py"
cp -f "$SRC_BASE/scripts/memory_speed_test.py" "$WORKDIR/memory_speed_test.py"
cp -f "$SRC_BASE/scripts/memory_sql_tool" "$WORKDIR/memory_sql_tool"
cp -f "$SRC_BASE/scripts/memory_recall" "$WORKDIR/memory_recall"
chmod +x "$WORKDIR/memory_sql_tool" "$WORKDIR/memory_recall"

cat > "$WORKDIR/sql_memory_map.json" <<JSON
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
echo "  python $WORKDIR/memory_sql_tool.py tables"
echo "  python $WORKDIR/memory_speed_test.py"
