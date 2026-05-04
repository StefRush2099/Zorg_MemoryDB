# Docker Install: OpenClaw + Zorg MemoryDB

Target OS: the latest Ubuntu release, currently **Ubuntu 26.04 LTS**.

This is the recommended clean install path. Docker Compose starts the complete OpenClaw + Zorg MemoryDB stack. No separate OpenClaw container or manual database attachment is required.

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

## Start the full stack

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

- `openclaw`: full OpenClaw latest install, built from this repo's Dockerfile
- `postgres`: PostgreSQL 16 memory database on the private Compose network
- `zorg_openclaw_home`: persistent OpenClaw state/workspace volume
- `zorg_memorydb_pgdata`: persistent PostgreSQL data volume

The OpenClaw container automatically connects to PostgreSQL using the Compose service name `postgres`.

## Verify

```bash
docker compose ps
docker compose logs -f openclaw

docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

Expected recall mode: `database-direct-structured`.

## Upgrade

```bash
git pull
docker compose up -d --build
```

The template remains sanitized. Database rows live only in the Docker volume and are not committed to GitHub.
