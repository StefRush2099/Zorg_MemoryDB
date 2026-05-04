#!/usr/bin/env bash
set -euo pipefail

# Native all-in-one install for the latest Ubuntu release (currently Ubuntu 26.04 LTS).
# Installs OpenClaw latest + local PostgreSQL + sanitized Zorg MemoryDB template.

REPO_URL="${REPO_URL:-https://github.com/StefRush2099/Zorg_MemoryDB.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Zorg_MemoryDB}"
DB_NAME="${DB_NAME:-openclaw_memory}"
DB_USER="${DB_USER:-openclaw_memory}"
DB_PASSWORD="${DB_PASSWORD:-}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-lan}"
OPENCLAW_GATEWAY_AUTH="${OPENCLAW_GATEWAY_AUTH:-token}"
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-change-me-zorg-token}"

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

if [ -z "$DB_PASSWORD" ]; then
  DB_PASSWORD="$(openssl rand -base64 32 | tr -d '\n')"
fi
export DB_HOST=127.0.0.1 DB_PORT=5432 DB_NAME DB_USER DB_PASSWORD

run_priv apt-get update
run_priv apt-get install -y ca-certificates curl git openssl nodejs npm python3 python3-pip python3-venv postgresql postgresql-contrib build-essential
run_priv npm install -g openclaw@latest

if [ ! -d "$INSTALL_DIR/.git" ]; then
  if git clone "$REPO_URL" "$INSTALL_DIR" 2>/dev/null; then :; else run_priv git clone "$REPO_URL" "$INSTALL_DIR"; run_priv chown -R "${USER:-$(id -un)}:${USER:-$(id -un)}" "$INSTALL_DIR" 2>/dev/null || true; fi
fi

run_priv systemctl enable --now postgresql
run_postgres psql -v ON_ERROR_STOP=1 \
  -v db_name="$DB_NAME" -v db_user="$DB_USER" -v db_password="$DB_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN SUPERUSER PASSWORD %L', :'db_user', :'db_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'db_user')\gexec
SELECT format('ALTER ROLE %I WITH LOGIN SUPERUSER PASSWORD %L', :'db_user', :'db_password')\gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')\gexec
SELECT format('ALTER DATABASE %I OWNER TO %I', :'db_name', :'db_user')\gexec
SQL

cd "$INSTALL_DIR"
DB_HOST=127.0.0.1 DB_PORT=5432 DB_NAME="$DB_NAME" DB_USER="$DB_USER" DB_PASSWORD="$DB_PASSWORD" ./scripts/first_run.sh

cat > .env.native <<ENV
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
OPENCLAW_GATEWAY_PORT=$OPENCLAW_GATEWAY_PORT
OPENCLAW_GATEWAY_BIND=$OPENCLAW_GATEWAY_BIND
OPENCLAW_GATEWAY_AUTH=$OPENCLAW_GATEWAY_AUTH
OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN
ENV
chmod 600 .env.native

echo "Native Ubuntu OpenClaw + Zorg MemoryDB install complete."
echo "Config saved to $INSTALL_DIR/.env.native"
echo "Start gateway with:"
echo "  cd $INSTALL_DIR && source .env.native && OPENCLAW_WORKSPACE=$INSTALL_DIR SQL_MEMORY_MAP=$INSTALL_DIR/sql_memory_map.json openclaw gateway run --allow-unconfigured --bind \$OPENCLAW_GATEWAY_BIND --port \$OPENCLAW_GATEWAY_PORT --auth \$OPENCLAW_GATEWAY_AUTH --token \$OPENCLAW_GATEWAY_TOKEN"
