#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-${WORKSPACE_DIR:-${HOME:?}/.openclaw/workspace}}"
SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP_PATH="$SKILL_ROOT/config/sql_memory_map.json"
BACKUP_DIR="${BACKUP_DIR:-${OPENCLAW_HOME:-${HOME:?}/.openclaw}/backups/postgres/tmp}"
MODE="${1:-drill}"
BACKUP_FILE="${2:-}"
PG_BIN="${ZORG_POSTGRES_BIN:-$WORKSPACE/postgresql-18/native/bin}"

usage() {
  cat <<USAGE
Usage: $0 drill [backup.sql.gz] | list | restore-active backup.sql.gz

This recovery tool is native PostgreSQL only and has no compatibility or
alternate backend path. restore-active requires CONFIRM_RESTORE_ACTIVE=YES.
USAGE
}

log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }

DB_ENV="$(python3 - "$MAP_PATH" <<'PY'
import json, shlex, sys
p = json.load(open(sys.argv[1], encoding='utf-8'))['postgres']
for env_key, cfg_key in [('PGHOST','host'),('PGPORT','port'),('PGDATABASE','database'),('PGUSER','user'),('PGPASSWORD','password')]:
    print(f'export {env_key}={shlex.quote(str(p[cfg_key]))}')
PY
)"
eval "$DB_ENV"
PSQL="$PG_BIN/psql"
PG_DUMP="$PG_BIN/pg_dump"
[[ -x "$PSQL" && -x "$PG_DUMP" ]] || { echo "native PostgreSQL client tools are missing under $PG_BIN" >&2; exit 1; }

list_backups() {
  find "$BACKUP_DIR" -maxdepth 1 -type f -name 'zorgdb-*.sql.gz' ! -name 'zorgdb-schema-*.sql.gz' -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk '{ $1=""; sub(/^ /, ""); print }'
}

require_backup() {
  local candidate="${1:-}"
  [[ -n "$candidate" ]] || candidate="$(list_backups | head -n 1)"
  [[ -s "$candidate" ]] || { echo "no readable native PostgreSQL backup found" >&2; exit 2; }
  printf '%s\n' "$candidate"
}

verify_db() {
  local db="$1" count
  "$PSQL" -d "$db" -Atc "select to_regclass('public.zorg_memory') is not null" | grep -qx t
  count="$($PSQL -d "$db" -Atc 'select count(*) from public.zorg_memory')"
  [[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]] || { echo "restored database has no source memory rows" >&2; exit 3; }
  log "verified database $db with zorg_memory rows=$count"
}

restore_plain_sql() {
  local backup="$1" db="$2"
  log "restoring $(basename "$backup") into $db"
  gunzip -c "$backup" | "$PSQL" -d "$db" -v ON_ERROR_STOP=1 >"/tmp/zorg-memorydb-restore-$$.log"
}

drill_restore() {
  local backup temp_db
  backup="$(require_backup "$BACKUP_FILE")"
  temp_db="zorg_recovery_drill_$(date +%Y%m%d_%H%M%S)_$$"
  "$PSQL" -d postgres -v ON_ERROR_STOP=1 -c "create database \"$temp_db\" owner \"$PGUSER\";" >/dev/null
  trap '"$PSQL" -d postgres -c "drop database if exists \"$temp_db\" with (force);" >/dev/null 2>&1 || true' EXIT
  restore_plain_sql "$backup" "$temp_db"
  verify_db "$temp_db"
  log "native PostgreSQL recovery drill passed"
}

restore_active() {
  local backup="$1" safety_db
  [[ "${CONFIRM_RESTORE_ACTIVE:-}" == YES ]] || { echo "restore-active requires CONFIRM_RESTORE_ACTIVE=YES" >&2; exit 4; }
  backup="$(require_backup "$backup")"
  BACKUP_FILE="$backup" "$0" drill "$backup"
  safety_db="zorg_restore_safety_$(date +%Y%m%d_%H%M%S)"
  "$PSQL" -d postgres -v ON_ERROR_STOP=1 -c "select pg_terminate_backend(pid) from pg_stat_activity where datname = current_database();" >/dev/null
  "$PSQL" -d postgres -v ON_ERROR_STOP=1 -c "alter database \"$PGDATABASE\" rename to \"$safety_db\"; create database \"$PGDATABASE\" owner \"$PGUSER\";" >/dev/null
  restore_plain_sql "$backup" "$PGDATABASE"
  verify_db "$PGDATABASE"
  log "native PostgreSQL live restore verified; safety database retained as $safety_db"
}

case "$MODE" in
  list) list_backups ;;
  drill) drill_restore ;;
  restore-active) restore_active "${2:-}" ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
