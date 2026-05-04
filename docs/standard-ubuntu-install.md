# Standard Ubuntu Install: OpenClaw + Zorg MemoryDB

Target OS: the latest Ubuntu release, currently **Ubuntu 26.04 LTS**.

This is the native, non-Docker install path. It installs OpenClaw latest, local PostgreSQL, and the sanitized Zorg MemoryDB template on the Ubuntu host.

## One-command native install

```bash
curl -fsSL https://raw.githubusercontent.com/StefRush2099/Zorg_MemoryDB/main/scripts/install_standard_ubuntu.sh | bash
```

The script:

1. installs Ubuntu packages: Git, Node/npm, Python venv, PostgreSQL, build tools
2. installs `openclaw@latest`
3. clones this sanitized template repo if needed
4. creates a local PostgreSQL database/user
5. writes `sql_memory_map.json`
6. applies the Zorg MemoryDB schema
7. imports only the public/template markdown files present in the repo
8. refreshes DB recall materialized views
9. enforces DB-backed OpenClaw memory search

## Manual native install

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git openssl nodejs npm python3 python3-pip python3-venv postgresql postgresql-contrib build-essential
sudo npm install -g openclaw@latest

git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB

sudo systemctl enable --now postgresql
sudo -u postgres psql <<'SQL'
CREATE ROLE openclaw_memory LOGIN PASSWORD 'change-this-password';
CREATE DATABASE openclaw_memory OWNER openclaw_memory;
SQL

DB_HOST=127.0.0.1 \
DB_PORT=5432 \
DB_NAME=openclaw_memory \
DB_USER=openclaw_memory \
DB_PASSWORD=change-this-password \
./scripts/first_run.sh
```

Start OpenClaw Gateway with Zorg DB memory enabled:

```bash
OPENCLAW_WORKSPACE="$PWD" \
SQL_MEMORY_MAP="$PWD/sql_memory_map.json" \
OPENCLAW_GATEWAY_TOKEN="change-this-token" \
openclaw gateway run --allow-unconfigured --bind lan --port 18789 --auth token --token "$OPENCLAW_GATEWAY_TOKEN"
```

## Sudo clone variant

If the target location requires sudo for clone:

```bash
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git /opt/Zorg_MemoryDB
sudo chown -R "$USER:$USER" /opt/Zorg_MemoryDB
cd /opt/Zorg_MemoryDB
./scripts/install_standard_ubuntu.sh
```

## Verify

```bash
cd ~/Zorg_MemoryDB
.venv-sqlmem/bin/python scripts/memory_sql_tool.py tables
.venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5
```

Expected recall mode: `database-direct-structured`.
