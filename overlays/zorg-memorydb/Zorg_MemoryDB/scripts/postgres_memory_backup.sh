#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%F_%H%M%S)"
BASE_LOCAL="/home/openclaw/.openclaw/backups/postgres/local"
PRIVATE_GITHUB_REPO="/home/openclaw/.openclaw/workspace/Zorg_Hive"
PRIVATE_GITHUB_BACKUP_DIR="$PRIVATE_GITHUB_REPO/backups/postgres/openclaw"
LOG_DIR="/home/openclaw/.openclaw/backups/postgres/logs"
LOG_FILE="$LOG_DIR/backup-$TS.log"
DB_CONT="local-postgres"
DB_USER="zorg"
DB_NAME="zorgdb"

# No direct SSH copies by policy.
LOCAL_MIRROR_046="/Zorg/backups/openclaw/postgres"

mkdir -p "$BASE_LOCAL" "$LOG_DIR"

OUT_SQL="$BASE_LOCAL/zorgdb-$TS.sql.gz"
OUT_SCHEMA="$BASE_LOCAL/zorgdb-schema-$TS.sql.gz"

{
  echo "[$(date -Is)] starting postgres backup"

  docker exec "$DB_CONT" pg_dump -U "$DB_USER" -d "$DB_NAME" --no-owner --no-privileges | gzip -9 > "$OUT_SQL"
  docker exec "$DB_CONT" pg_dump -U "$DB_USER" -d "$DB_NAME" --schema-only --no-owner --no-privileges | gzip -9 > "$OUT_SCHEMA"

  # 7-day local retention
  find "$BASE_LOCAL" -type f -name 'zorgdb-*.sql.gz' -mtime +7 -delete || true
  find "$BASE_LOCAL" -type f -name 'zorgdb-schema-*.sql.gz' -mtime +7 -delete || true

  SIZE_MAIN=$(du -h "$OUT_SQL" | awk '{print $1}')
  SIZE_SCHEMA=$(du -h "$OUT_SCHEMA" | awk '{print $1}')
  echo "[$(date -Is)] local backup complete main=$SIZE_MAIN schema=$SIZE_SCHEMA"

  # optional local mirror if /Zorg is mounted on this host
  if [ -d "/Zorg" ] || mkdir -p "$LOCAL_MIRROR_046" 2>/dev/null; then
    cp -f "$OUT_SQL" "$OUT_SCHEMA" "$LOCAL_MIRROR_046/"
    echo "[$(date -Is)] mirrored to local /Zorg path"
  else
    echo "[$(date -Is)] WARN: /Zorg not available locally; skipped mirror copy"
  fi

  # mandatory private GitHub recovery mirror (Zorg_Hive).
  # This repo is private; do not copy DB dumps into public repos such as Zorg_MemoryDB.
  if [ -d "$PRIVATE_GITHUB_REPO/.git" ]; then
    mkdir -p "$PRIVATE_GITHUB_BACKUP_DIR"
    cp -f "$OUT_SQL" "$OUT_SCHEMA" "$PRIVATE_GITHUB_BACKUP_DIR/"
    {
      echo "# OpenClaw PostgreSQL backup recovery manifest"
      echo
      echo "Last backup UTC: $(date -u -Is)"
      echo "Latest full dump: $(basename "$OUT_SQL")"
      echo "Latest schema dump: $(basename "$OUT_SCHEMA")"
      echo "Local source: $BASE_LOCAL"
      echo "Private GitHub path: backups/postgres/openclaw/"
      echo "Restore full dump: gunzip -c <dump.sql.gz> | psql -h <host> -U zorg -d zorgdb"
      echo
      echo "This database contains private durable memory. Keep this repo private."
    } > "$PRIVATE_GITHUB_BACKUP_DIR/README.md"
    git -C "$PRIVATE_GITHUB_REPO" add -f backups/postgres/openclaw
    if git -C "$PRIVATE_GITHUB_REPO" diff --cached --quiet; then
      echo "[$(date -Is)] private GitHub mirror unchanged"
    else
      git -C "$PRIVATE_GITHUB_REPO" commit -m "Backup OpenClaw PostgreSQL memory database $TS"
      git -C "$PRIVATE_GITHUB_REPO" push origin main
      echo "[$(date -Is)] private GitHub backup committed and pushed"
    fi
  else
    echo "[$(date -Is)] ERROR: private GitHub repo not found at $PRIVATE_GITHUB_REPO"
    exit 2
  fi

  echo "[$(date -Is)] backup run finished"
} | tee "$LOG_FILE"
