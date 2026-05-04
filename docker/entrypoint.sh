#!/usr/bin/env bash
set -euo pipefail

log(){ printf '[Zorg OpenClaw] %s\n' "$*"; }

: "${OPENCLAW_HOME:=/home/openclaw/.openclaw}"
: "${OPENCLAW_WORKSPACE:=$OPENCLAW_HOME/workspace}"
: "${PGDATA:=$OPENCLAW_HOME/postgresql/data}"
: "${DB_HOST:=127.0.0.1}"
: "${DB_PORT:=5432}"
: "${DB_NAME:=openclaw_memory}"
: "${DB_USER:=openclaw_memory}"
: "${DB_PASSWORD:=openclaw_memory}"
: "${OPENCLAW_GATEWAY_PORT:=18789}"
: "${OPENCLAW_GATEWAY_BIND:=lan}"
: "${OPENCLAW_GATEWAY_AUTH:=token}"
: "${OPENCLAW_GATEWAY_TOKEN:=change-me-zorg-token}"
export OPENCLAW_HOME OPENCLAW_WORKSPACE PGDATA DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD OPENCLAW_GATEWAY_TOKEN
export ZORG_FORCE_WRITE_CONFIG=1

POSTGRES_INITDB="$(find /usr/lib/postgresql -type f -name initdb | sort -V | tail -1)"
POSTGRES_BIN="$(dirname "$POSTGRES_INITDB")"
export PATH="$POSTGRES_BIN:$PATH"

mkdir -p "$OPENCLAW_HOME" "$OPENCLAW_WORKSPACE" "$(dirname "$PGDATA")"
chmod 755 /home /home/openclaw "$OPENCLAW_HOME" 2>/dev/null || true

pg_ident(){ printf '"%s"' "$(printf '%s' "$1" | sed 's/"/""/g')"; }
pg_lit(){ printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"; }

start_local_postgres(){
  log "starting embedded PostgreSQL inside the OpenClaw/Zorg container"
  mkdir -p "$PGDATA" /run/postgresql
  chown -R postgres:postgres "$(dirname "$PGDATA")" "$PGDATA" /run/postgresql
  chmod 700 "$PGDATA"

  if [ ! -s "$PGDATA/PG_VERSION" ]; then
    log "initializing embedded PostgreSQL data directory"
    gosu postgres initdb -D "$PGDATA" --auth-local=trust --auth-host=scram-sha-256 >/dev/null
  fi

  gosu postgres pg_ctl -D "$PGDATA" \
    -o "-c listen_addresses='127.0.0.1' -c unix_socket_directories='/run/postgresql' -p ${DB_PORT}" \
    -w start >/dev/null

  log "ensuring Zorg memory database and role exist"
  role_exists="$(psql -v ON_ERROR_STOP=1 -h /run/postgresql -p "$DB_PORT" -U postgres -d postgres -Atc "SELECT 1 FROM pg_roles WHERE rolname = $(pg_lit "$DB_USER")" || true)"
  if [ "$role_exists" = "1" ]; then
    psql -v ON_ERROR_STOP=1 -h /run/postgresql -p "$DB_PORT" -U postgres -d postgres \
      -c "ALTER ROLE $(pg_ident "$DB_USER") WITH LOGIN SUPERUSER PASSWORD $(pg_lit "$DB_PASSWORD")" >/dev/null
  else
    psql -v ON_ERROR_STOP=1 -h /run/postgresql -p "$DB_PORT" -U postgres -d postgres \
      -c "CREATE ROLE $(pg_ident "$DB_USER") LOGIN SUPERUSER PASSWORD $(pg_lit "$DB_PASSWORD")" >/dev/null
  fi
  createdb -h /run/postgresql -p "$DB_PORT" -U postgres -O "$DB_USER" "$DB_NAME" >/dev/null 2>&1 || true
  psql -v ON_ERROR_STOP=1 -h /run/postgresql -p "$DB_PORT" -U postgres -d postgres \
    -c "ALTER DATABASE $(pg_ident "$DB_NAME") OWNER TO $(pg_ident "$DB_USER")" >/dev/null
}

stop_local_postgres(){
  if [ -s "$PGDATA/PG_VERSION" ]; then
    gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop >/dev/null 2>&1 || true
  fi
}
trap stop_local_postgres EXIT

start_local_postgres

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
