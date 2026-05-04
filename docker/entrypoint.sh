#!/usr/bin/env bash
set -euo pipefail

log(){ printf '[Zorg OpenClaw] %s\n' "$*"; }

: "${OPENCLAW_HOME:=/home/openclaw/.openclaw}"
: "${OPENCLAW_WORKSPACE:=$OPENCLAW_HOME/workspace}"
: "${DB_HOST:=postgres}"
: "${DB_PORT:=5432}"
: "${DB_NAME:=openclaw_memory}"
: "${DB_USER:=openclaw_memory}"
: "${DB_PASSWORD:=openclaw_memory}"
: "${OPENCLAW_GATEWAY_PORT:=18789}"
: "${OPENCLAW_GATEWAY_BIND:=lan}"
: "${OPENCLAW_GATEWAY_AUTH:=token}"
: "${OPENCLAW_GATEWAY_TOKEN:=change-me-zorg-token}"
export OPENCLAW_HOME OPENCLAW_WORKSPACE DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD OPENCLAW_GATEWAY_TOKEN

mkdir -p "$OPENCLAW_HOME" "$OPENCLAW_WORKSPACE"

if [ ! -f "$OPENCLAW_WORKSPACE/scripts/first_run.sh" ] || [ ! -f "$OPENCLAW_WORKSPACE/db/schema.sql" ]; then
  log "seeding OpenClaw workspace with Zorg MemoryDB template"
  shopt -s dotglob
  cp -a /opt/zorg-memorydb/* "$OPENCLAW_WORKSPACE"/
  shopt -u dotglob
fi

cd "$OPENCLAW_WORKSPACE"

log "initializing PostgreSQL-backed Zorg memory"
./scripts/first_run.sh

case "${1:-gateway}" in
  gateway|openclaw-gateway)
    shift || true
    log "starting OpenClaw Gateway on port ${OPENCLAW_GATEWAY_PORT} with Zorg DB memory enabled"
    exec openclaw gateway run \
      --allow-unconfigured \
      --bind "$OPENCLAW_GATEWAY_BIND" \
      --port "$OPENCLAW_GATEWAY_PORT" \
      --auth "$OPENCLAW_GATEWAY_AUTH" \
      --token "$OPENCLAW_GATEWAY_TOKEN" \
      "$@"
    ;;
  openclaw)
    shift || true
    exec openclaw "$@"
    ;;
  bash|sh)
    exec "$@"
    ;;
  *)
    exec "$@"
    ;;
esac
