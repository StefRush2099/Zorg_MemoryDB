#!/usr/bin/env bash
set -euo pipefail

log(){ printf '[Zorg OpenClaw] %s\n' "$*"; }

HOME=/home/openclaw
: "${OPENCLAW_HOME:=/home/openclaw/.openclaw}"
: "${OPENCLAW_WORKSPACE:=$OPENCLAW_HOME/workspace}"
: "${PGDATA:=$OPENCLAW_HOME/postgresql/data}"
: "${DB_HOST:=127.0.0.1}"
: "${DB_PORT:=5432}"
: "${DB_NAME:=openclaw_memory}"
: "${DB_USER:=openclaw_memory}"
: "${OPENCLAW_GATEWAY_PORT:=18789}"
: "${OPENCLAW_GATEWAY_BIND:=lan}"
: "${OPENCLAW_GATEWAY_AUTH:=trusted-proxy}"
: "${LAN_CHAT_PORT:=3001}"
: "${ENABLE_LAN_CHAT_INTERNAL:=true}"
export HOME OPENCLAW_HOME OPENCLAW_WORKSPACE PGDATA DB_HOST DB_PORT DB_NAME DB_USER LAN_CHAT_PORT
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
    gosu postgres initdb -D "$PGDATA" --auth-local=trust --auth-host=trust >/dev/null
  fi

  gosu postgres pg_ctl -D "$PGDATA" \
    -o "-c listen_addresses='127.0.0.1' -c unix_socket_directories='/run/postgresql' -p ${DB_PORT}" \
    -w start >/dev/null

  log "ensuring Zorg memory database and role exist"
  role_exists="$(psql -v ON_ERROR_STOP=1 -h /run/postgresql -p "$DB_PORT" -U postgres -d postgres -Atc "SELECT 1 FROM pg_roles WHERE rolname = $(pg_lit "$DB_USER")" || true)"
  if [ "$role_exists" = "1" ]; then
    psql -v ON_ERROR_STOP=1 -h /run/postgresql -p "$DB_PORT" -U postgres -d postgres \
      -c "ALTER ROLE $(pg_ident "$DB_USER") WITH LOGIN SUPERUSER" >/dev/null
  else
    psql -v ON_ERROR_STOP=1 -h /run/postgresql -p "$DB_PORT" -U postgres -d postgres \
      -c "CREATE ROLE $(pg_ident "$DB_USER") LOGIN SUPERUSER" >/dev/null
  fi
  createdb -h /run/postgresql -p "$DB_PORT" -U postgres -O "$DB_USER" "$DB_NAME" >/dev/null 2>&1 || true
  psql -v ON_ERROR_STOP=1 -h /run/postgresql -p "$DB_PORT" -U postgres -d postgres \
    -c "ALTER DATABASE $(pg_ident "$DB_NAME") OWNER TO $(pg_ident "$DB_USER")" >/dev/null
}

LAN_CHAT_PID=""

start_lan_chat_internal(){
  if [ "${ENABLE_LAN_CHAT_INTERNAL}" = "false" ] || [ "${ENABLE_LAN_CHAT_INTERNAL}" = "0" ]; then
    log "internal LAN command console disabled for this container"
    return 0
  fi
  if [ ! -d /opt/zorg-memorydb/lan-chat/.next ]; then
    log "LAN command console build not found; skipping internal lan-chat start"
    return 0
  fi
  log "starting built-in LAN command console on port ${LAN_CHAT_PORT}"
  (
    cd /opt/zorg-memorydb/lan-chat
    export HOME OPENCLAW_HOME OPENCLAW_WORKSPACE
    export GATEWAY_HOST=127.0.0.1
    export GATEWAY_SESSION_KEY="${GATEWAY_SESSION_KEY:-agent:main:main}"
    export CHAT_SOURCE_LABEL="${CHAT_SOURCE_LABEL:-LAN Console}"
    export CHAT_HISTORY_LIMIT="${CHAT_HISTORY_LIMIT:-20}"
    export GATEWAY_CALL_TIMEOUT_MS="${GATEWAY_CALL_TIMEOUT_MS:-15000}"
    export PORT="${LAN_CHAT_PORT}"
    exec npm run start
  ) &
  LAN_CHAT_PID="$!"
}

stop_lan_chat_internal(){
  if [ -n "${LAN_CHAT_PID:-}" ]; then
    kill "$LAN_CHAT_PID" >/dev/null 2>&1 || true
    wait "$LAN_CHAT_PID" >/dev/null 2>&1 || true
  fi
}

stop_local_postgres(){
  stop_lan_chat_internal
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
else
  log "refreshing Zorg MemoryDB runtime files"
  mkdir -p "$OPENCLAW_WORKSPACE/scripts" "$OPENCLAW_WORKSPACE/db" "$OPENCLAW_WORKSPACE/config" "$OPENCLAW_WORKSPACE/docs"
  cp -a /opt/zorg-memorydb/scripts/. "$OPENCLAW_WORKSPACE/scripts"/
  cp -a /opt/zorg-memorydb/db/. "$OPENCLAW_WORKSPACE/db"/
  cp -a /opt/zorg-memorydb/config/. "$OPENCLAW_WORKSPACE/config"/
  cp -a /opt/zorg-memorydb/docs/. "$OPENCLAW_WORKSPACE/docs"/
  rm -rf "$OPENCLAW_WORKSPACE/lan-chat"
  cp -a /opt/zorg-memorydb/lan-chat "$OPENCLAW_WORKSPACE/lan-chat"
fi

cd "$OPENCLAW_WORKSPACE"

log "initializing PostgreSQL-backed Zorg memory"
./scripts/first_run.sh

write_gateway_config(){
  python3 - <<'PY'
import json, os, pathlib
homes=[
    pathlib.Path(os.environ.get('OPENCLAW_HOME','/home/openclaw/.openclaw')),
    pathlib.Path(os.environ.get('OPENCLAW_HOME','/home/openclaw/.openclaw'))/'.openclaw',
]
for home in homes:
    path=home/'openclaw.json'
    try:
        cfg=json.loads(path.read_text()) if path.exists() else {}
    except Exception:
        cfg={}
    gw=cfg.setdefault('gateway', {})
    gw['mode']='local'
    gw['bind']=os.environ.get('OPENCLAW_GATEWAY_BIND','lan')
    gw['port']=int(os.environ.get('OPENCLAW_GATEWAY_PORT','18789'))
    gw['auth']={
        'mode': os.environ.get('OPENCLAW_GATEWAY_AUTH','trusted-proxy'),
        'trustedProxy': {'userHeader': 'x-openclaw-user'}
    }
    gw['trustedProxies']=['0.0.0.0/0','::/0']
    control=gw.setdefault('controlUi', {})
    control['dangerouslyAllowHostHeaderOriginFallback']=True
    agents=cfg.setdefault('agents', {})
    defaults=agents.setdefault('defaults', {})
    defaults['memorySearch']={
        'enabled': True,
        'provider': 'local',
        'fallback': 'none',
        'sources': ['memory'],
        'multimodal': {'enabled': False},
    }
    home.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(cfg, indent=2)+'\n')
PY
}
write_gateway_config

case "${1:-gateway}" in
  gateway|openclaw-gateway)
    shift || true
    start_lan_chat_internal
    log "starting OpenClaw Gateway on port ${OPENCLAW_GATEWAY_PORT} with Zorg DB memory enabled"
    exec openclaw gateway run \
      --allow-unconfigured \
      --bind "$OPENCLAW_GATEWAY_BIND" \
      --port "$OPENCLAW_GATEWAY_PORT" \
      --auth "$OPENCLAW_GATEWAY_AUTH" \
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
