# Docker Install: OpenClaw + Zorg MemoryDB

Target OS: the latest Ubuntu release, currently **Ubuntu 26.04 LTS**.

This is the recommended clean install path. Docker Compose starts **one self-contained OpenClaw/Zorg container**. PostgreSQL runs inside that same container, matching the Zorg memory structure instead of creating a separate Docker-managed PostgreSQL service.

No separate OpenClaw container, separate PostgreSQL container, or manual database attachment is required.

## Install Docker on Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git docker.io docker-compose-plugin
sudo systemctl enable --now docker
```

If your user is not in the Docker group, either use `sudo docker ...` or add yourself and log out/in:

```bash
sudo usermod -aG docker "$USER"
```

## Start the full single-container stack

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
cp .env.example .env
# edit .env and change OPENCLAW_GATEWAY_TOKEN and DB_PASSWORD before real use
docker compose up -d --build
```

If Docker requires sudo:

```bash
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
sudo cp .env.example .env
sudo docker compose up -d --build
```

## What the stack includes

- one `openclaw` Compose service built from this repo's Dockerfile
- full latest OpenClaw install
- embedded PostgreSQL server running inside the same container
- Zorg MemoryDB schema, scripts, config, imports, materialized views, and DB-backed recall enforcement
- one persistent `zorg_openclaw_home` volume containing OpenClaw state/workspace and embedded PostgreSQL data under `/home/openclaw/.openclaw/postgresql/data`

This is intentionally not a two-container `openclaw` + `postgres` layout.

## Verify

```bash
docker compose ps
docker compose logs -f openclaw

docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

Expected recall mode: `database-direct-structured`.

## Upgrade

```bash
git pull
docker compose up -d --build
```

The template remains sanitized. Database rows live only in the local Docker volume and are not committed to GitHub.
