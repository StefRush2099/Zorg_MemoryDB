#!/usr/bin/env bash
set -euo pipefail

# Native all-in-one install for the latest Ubuntu release (currently Ubuntu 26.04 LTS).
# Installs OpenClaw latest + local PostgreSQL + sanitized Zorg MemoryDB template.

REPO_URL="${REPO_URL:-https://github.com/StefRush2099/Zorg_MemoryDB.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Zorg_MemoryDB}"
DB_NAME="${DB_NAME:-openclaw_memory}"
DB_USER="${DB_USER:-openclaw_memory}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-lan}"
OPENCLAW_GATEWAY_AUTH="${OPENCLAW_GATEWAY_AUTH:-trusted-proxy}"
LAN_CHAT_PORT="${LAN_CHAT_PORT:-3001}"

have(){ command -v "$1" >/dev/null 2>&1; }
run_priv(){ if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }
run_postgres(){
  if have sudo; then sudo -u postgres "$@";
  elif [ "$(id -u)" -eq 0 ] && have runuser; then runuser -u postgres -- "$@";
  else echo "sudo or runuser is required to manage the local PostgreSQL role/database." >&2; exit 1; fi
}

if ! have sudo && [ "$(id -u)" -ne 0 ]; then
  echo "sudo is required for the native Ubuntu install." >&2
  exit 1
fi

export DB_HOST=127.0.0.1 DB_PORT=5432 DB_NAME DB_USER

run_priv apt-get update
run_priv apt-get install -y ca-certificates curl git nodejs npm python3 python3-pip python3-venv postgresql postgresql-contrib build-essential
run_priv npm install -g openclaw@latest

if [ ! -d "$INSTALL_DIR/.git" ]; then
  if git clone "$REPO_URL" "$INSTALL_DIR" 2>/dev/null; then :; else run_priv git clone "$REPO_URL" "$INSTALL_DIR"; run_priv chown -R "${USER:-$(id -un)}:${USER:-$(id -un)}" "$INSTALL_DIR" 2>/dev/null || true; fi
fi

run_priv systemctl enable --now postgresql
PG_HBA="$(run_postgres psql -Atc "show hba_file;")"
if ! run_priv grep -q "zorg_memorydb_local_trust" "$PG_HBA"; then
  tmp_hba="$(mktemp)"
  {
    echo "# zorg_memorydb_local_trust"
    echo "host all $DB_USER 127.0.0.1/32 trust"
    echo "host all $DB_USER ::1/128 trust"
    cat "$PG_HBA"
  } > "$tmp_hba"
  run_priv cp "$tmp_hba" "$PG_HBA"
  rm -f "$tmp_hba"
  run_priv systemctl reload postgresql
fi
run_postgres psql -v ON_ERROR_STOP=1 \
  -v db_name="$DB_NAME" -v db_user="$DB_USER" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN SUPERUSER', :'db_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'db_user')\gexec
SELECT format('ALTER ROLE %I WITH LOGIN SUPERUSER', :'db_user')\gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')\gexec
SELECT format('ALTER DATABASE %I OWNER TO %I', :'db_name', :'db_user')\gexec
SQL

cd "$INSTALL_DIR"
DB_HOST=127.0.0.1 DB_PORT=5432 DB_NAME="$DB_NAME" DB_USER="$DB_USER" ./scripts/first_run.sh

OPENCLAW_HOME="$HOME/.openclaw" \
OPENCLAW_WORKSPACE="$INSTALL_DIR" \
GATEWAY_HOST=127.0.0.1 \
GATEWAY_SESSION_KEY=agent:main:main \
CHAT_SOURCE_LABEL="LAN Console" \
CHAT_HISTORY_LIMIT=20 \
LAN_CHAT_PORT="$LAN_CHAT_PORT" \
./scripts/install_lan_chat.sh

cat > .env.native <<ENV
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=$DB_USER
OPENCLAW_GATEWAY_PORT=$OPENCLAW_GATEWAY_PORT
OPENCLAW_GATEWAY_BIND=$OPENCLAW_GATEWAY_BIND
OPENCLAW_GATEWAY_AUTH=$OPENCLAW_GATEWAY_AUTH
LAN_CHAT_PORT=$LAN_CHAT_PORT
ENV
chmod 600 .env.native

python3 - <<PY
import json, pathlib
home=pathlib.Path.home()/'.openclaw'
path=home/'openclaw.json'
try:
    cfg=json.loads(path.read_text()) if path.exists() else {}
except Exception:
    cfg={}
gw=cfg.setdefault('gateway', {})
gw['mode']='local'
gw['bind']='$OPENCLAW_GATEWAY_BIND'
gw['port']=int('$OPENCLAW_GATEWAY_PORT')
gw['auth']={'mode':'$OPENCLAW_GATEWAY_AUTH','trustedProxy':{'userHeader':'x-openclaw-user'}}
gw['trustedProxies']=['0.0.0.0/0','::/0']
gw.setdefault('controlUi', {})['dangerouslyAllowHostHeaderOriginFallback']=True
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

echo "Native Ubuntu OpenClaw + Zorg MemoryDB install complete."
echo "Config saved to $INSTALL_DIR/.env.native"
echo "LAN command console installed at http://127.0.0.1:$LAN_CHAT_PORT/"
echo "Service status: systemctl --user status lan-chat.service"
echo "Start gateway with:"
echo "  cd $INSTALL_DIR && source .env.native && OPENCLAW_WORKSPACE=$INSTALL_DIR SQL_MEMORY_MAP=$INSTALL_DIR/sql_memory_map.json openclaw gateway run --allow-unconfigured --bind \$OPENCLAW_GATEWAY_BIND --port \$OPENCLAW_GATEWAY_PORT --auth \$OPENCLAW_GATEWAY_AUTH"
