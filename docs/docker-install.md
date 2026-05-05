# Docker Compose Install: Integrated OpenClaw + Zorg MemoryDB

This path starts OpenClaw from scratch with Zorg MemoryDB already integrated.

The database is not a separate user-facing install step. It starts internally inside the OpenClaw/Zorg container and stores its data under the same OpenClaw home volume:

```text
/home/openclaw/.openclaw
```

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

## Start OpenClaw

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg_memorydb
cd zorg_memorydb
cp .env.example .env
docker compose up -d --build
```

Open OpenClaw on port `18789`.

That is the complete start path. You should not need to manually configure a database or attach memory afterward.

## What the stack includes

- one `openclaw` Compose service
- full latest OpenClaw install
- internal PostgreSQL running inside the same OpenClaw/Zorg container
- Zorg MemoryDB schema, scripts, config, imports, materialized views, and DB-backed recall enforcement
- one persistent `zorg_openclaw_home` volume containing OpenClaw state/workspace and internal memory data under `/home/openclaw/.openclaw`

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

The template remains sanitized. Runtime memory data lives only in the local OpenClaw volume and is not committed to GitHub.
