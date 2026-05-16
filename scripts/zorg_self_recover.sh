#!/usr/bin/env bash
# One-step Zorg/OpenClaw self-recovery entrypoint.
# Public-safe script: it knows where the private recovery repo lives, but it
# does not contain private rows, credentials, tokens, or live backups.
set -euo pipefail

PUBLIC_REPO_URL="\${PUBLIC_REPO_URL:-https://github.com/StefRush2099/Zorg_MemoryDB.git}"
PRIVATE_REPO_URL="\${PRIVATE_REPO_URL:-git@github.com:StefRush2099/Zorg_Hive.git}"
OPENCLAW_HOME="\${OPENCLAW_HOME:-/home/openclaw/.openclaw}"
WORKSPACE="\${OPENCLAW_WORKSPACE:-$OPENCLAW_HOME/workspace}"
PUBLIC_DIR="\${PUBLIC_DIR:-$WORKSPACE/Zorg_MemoryDB}"
PRIVATE_DIR="\${PRIVATE_DIR:-$WORKSPACE/Zorg_Hive}"
BACKUP_DIR="\${BACKUP_DIR:-}"
DB_CONTAINER="\${DB_CONTAINER:-local-postgres}"
DB_NAME="\${DB_NAME:-zorgdb}"
DB_USER="\${DB_USER:-zorg}"
LAN_CHAT_PORT="\${LAN_CHAT_PORT:-3001}"
DRY_RUN=0
YES=0

usage() {
  cat <<USAGE
Usage: $0 [--yes] [--dry-run] [--backup /path/to/*_self_recovery]

Restores the current Zorg/OpenClaw overlay from the latest private Zorg_Hive backup.

Default target:
  OPENCLAW_HOME=$OPENCLAW_HOME
  OPENCLAW_WORKSPACE=$WORKSPACE

USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes|-y) YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --backup) BACKUP_DIR="\${2:-}"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

have() { command -v "$1" >/dev/null 2>&1; }
run() {
  printf '+ %s\n' "$*" >&2
  if [ "$DRY_RUN" -eq 0 ]; then "$@"; fi
}
run_priv() {
  if [ "$(id -u)" -eq 0 ]; then run "$@"
  elif have sudo; then run sudo "$@"
  else run "$@"; fi
}

if [ "$YES" -ne 1 ]; then
  cat >&2 <<WARN
This will restore Zorg/OpenClaw runtime state from the private backup repo.
Rerun with --yes to proceed, or --dry-run to inspect planned commands.
WARN
  exit 2
fi

mkdir -p "$WORKSPACE"

if ! have git; then
  if have apt-get; then run_priv apt-get update; run_priv apt-get install -y git
  else echo "git is required; install git and rerun." >&2; exit 1; fi
fi

if ! have rsync; then
  if have apt-get; then run_priv apt-get update; run_priv apt-get install -y rsync
  else echo "rsync is required; install rsync and rerun." >&2; exit 1; fi
fi

if ! have openclaw; then
  if have npm; then run npm install -g openclaw@latest
  else echo "npm/openclaw is missing. Install Node/npm or OpenClaw first." >&2; exit 1; fi
fi

if [ ! -d "$PUBLIC_DIR/.git" ]; then
  run git clone "$PUBLIC_REPO_URL" "$PUBLIC_DIR"
else
  run git -C "$PUBLIC_DIR" pull --ff-only
fi

if [ ! -d "$PRIVATE_DIR/.git" ]; then
  run git clone "$PRIVATE_REPO_URL" "$PRIVATE_DIR"
else
  run git -C "$PRIVATE_DIR" pull --ff-only
fi

if [ -z "$BACKUP_DIR" ]; then
  BACKUP_DIR="$(find "$PRIVATE_DIR/backups/openclaw-runtime" -maxdepth 1 -type d -name '*_self_recovery' 2>/dev/null | sort | tail -1)"
fi
[ -n "$BACKUP_DIR" ] || { echo "No private self-recovery backup found." >&2; exit 1; }
[ -f "$BACKUP_DIR/MANIFEST.tsv" ] || { echo "Backup lacks MANIFEST.tsv: $BACKUP_DIR" >&2; exit 1; }

echo "Using backup: $BACKUP_DIR"

run mkdir -p "$OPENCLAW_HOME" "$WORKSPACE"

restore_dir() {
  src="$1"
  dst="$2"
  if [ -d "$src" ]; then
    run mkdir -p "$dst"
    run rsync -a "$src"/ "$dst"/
  fi
}

restore_dir "$BACKUP_DIR/core" "$WORKSPACE"
restore_dir "$BACKUP_DIR/db-memory" "$WORKSPACE"
restore_dir "$BACKUP_DIR/scripts" "$WORKSPACE/scripts"
restore_dir "$BACKUP_DIR/skills" "$WORKSPACE/skills"
restore_dir "$BACKUP_DIR/lan-chat" "$WORKSPACE/lan-chat"

if [ -d "$BACKUP_DIR/openclaw-config/home/openclaw/.openclaw" ]; then
  restore_dir "$BACKUP_DIR/openclaw-config/home/openclaw/.openclaw" "$OPENCLAW_HOME"
fi
if [ -d "$BACKUP_DIR/credentials" ]; then
  restore_dir "$BACKUP_DIR/credentials" "$OPENCLAW_HOME/credentials"
  run chmod -R go-rwx "$OPENCLAW_HOME/credentials"
fi

if [ -f "$BACKUP_DIR/systemd/lan-chat.service" ]; then
  run mkdir -p /home/openclaw/.config/systemd/user
  run cp "$BACKUP_DIR/systemd/lan-chat.service" /home/openclaw/.config/systemd/user/lan-chat.service
  run systemctl --user daemon-reload
  run systemctl --user enable --now lan-chat.service
fi

if [ -d "$BACKUP_DIR/nginx-tree/etc/nginx" ]; then
  run_priv rsync -a "$BACKUP_DIR/nginx-tree/etc/nginx"/ /etc/nginx/
  run_priv nginx -t
  run_priv systemctl reload nginx
fi

latest_dump="$(find "$BACKUP_DIR/postgres" -maxdepth 1 -type f -name 'zorgdb-[0-9]*.sql.gz' ! -name 'zorgdb-schema-*' 2>/dev/null | sort | tail -1)"
if [ -n "$latest_dump" ]; then
  if have docker && docker ps --format '{{.Names}}' | grep -qx "$DB_CONTAINER"; then
    echo "Restoring PostgreSQL dump: $latest_dump"
    if [ "$DRY_RUN" -eq 0 ]; then
      gunzip -c "$latest_dump" | docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME"
    fi
  else
    echo "WARN: Docker container $DB_CONTAINER is not running; DB dump is available at $latest_dump" >&2
  fi
fi

if [ -f "$WORKSPACE/scripts/enforce_db_memory_search.py" ]; then
  run python3 "$WORKSPACE/scripts/enforce_db_memory_search.py"
fi

if [ -f "$WORKSPACE/memory_speed_test.py" ] && [ -x "$WORKSPACE/.venv-sqlmem/bin/python" ]; then
  run "$WORKSPACE/.venv-sqlmem/bin/python" "$WORKSPACE/memory_speed_test.py"
fi

curl -fsS "http://127.0.0.1:$LAN_CHAT_PORT/" >/dev/null && echo "LAN chat responded on $LAN_CHAT_PORT" || echo "WARN: LAN chat did not respond on $LAN_CHAT_PORT" >&2
openclaw --version
echo "Zorg/OpenClaw self-recovery completed."
