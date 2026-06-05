#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%F_%H%M%S)"
BASE_LOCAL="/home/openclaw/.openclaw/backups/postgres/tmp"
LOG_DIR="/home/openclaw/.openclaw/backups/postgres/logs"
LOG_FILE="$LOG_DIR/backup-$TS.log"
DB_CONT="local-postgres"
DB_USER="zorg"
DB_NAME="zorgdb"
LOCAL_TTL_HOURS="${ZORG_TEMP_BACKUP_TTL_HOURS:-24}"

mkdir -p "$BASE_LOCAL" "$LOG_DIR"

OUT_SQL="$BASE_LOCAL/zorgdb-$TS.sql.gz"
OUT_SCHEMA="$BASE_LOCAL/zorgdb-schema-$TS.sql.gz"

{
  echo "[$(date -Is)] starting postgres backup"

  docker exec "$DB_CONT" pg_dump -U "$DB_USER" -d "$DB_NAME" --no-owner --no-privileges | gzip -9 > "$OUT_SQL"
  docker exec "$DB_CONT" pg_dump -U "$DB_USER" -d "$DB_NAME" --schema-only --no-owner --no-privileges | gzip -9 > "$OUT_SCHEMA"

  # Temporary local retention only. Do not mirror DB backups to GitHub.
  # Backups are transaction artifacts for immediate rollback and are purged.
  find "$BASE_LOCAL" -type f -name 'zorgdb-*.sql.gz' -mmin "+$((LOCAL_TTL_HOURS * 60))" -delete || true
  find "$BASE_LOCAL" -type f -name 'zorgdb-schema-*.sql.gz' -mmin "+$((LOCAL_TTL_HOURS * 60))" -delete || true

  SIZE_MAIN=$(du -h "$OUT_SQL" | awk '{print $1}')
  SIZE_SCHEMA=$(du -h "$OUT_SCHEMA" | awk '{print $1}')
  echo "[$(date -Is)] local backup complete main=$SIZE_MAIN schema=$SIZE_SCHEMA"

  echo "[$(date -Is)] GitHub backup mirror disabled by operator rule"
  echo "[$(date -Is)] temporary local backup path=$BASE_LOCAL ttl_hours=$LOCAL_TTL_HOURS"

  echo "[$(date -Is)] backup run finished"
} | tee "$LOG_FILE"
