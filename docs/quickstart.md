# Quickstart: OpenClaw + Zorg MemoryDB on Latest Ubuntu

Target OS for all install paths: the latest Ubuntu release, currently **Ubuntu 26.04 LTS**.

This repo is the clean-install template. It starts or installs full OpenClaw with Zorg PostgreSQL memory already connected. In Docker/Dockge, OpenClaw and PostgreSQL run inside the same self-contained OpenClaw/Zorg container.

## Option 1: Standard Ubuntu install

Native install on Ubuntu, no Docker required:

```bash
curl -fsSL https://raw.githubusercontent.com/StefRush2099/Zorg_MemoryDB/main/scripts/install_standard_ubuntu.sh | bash
```

Details: [`standard-ubuntu-install.md`](standard-ubuntu-install.md)

## Option 2: Docker install

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
cp .env.example .env
docker compose up -d --build
```

Details: [`docker-install.md`](docker-install.md)

## Option 3: Docker run one-liner

```bash
docker run -d --name zorg-memorydb --restart unless-stopped -p 18789:18789 -e OPENCLAW_GATEWAY_TOKEN=change-this-token -e DB_PASSWORD=change-this-password -v zorg_openclaw_home:/home/openclaw/.openclaw ghcr.io/stefrush2099/zorg-memorydb:latest
```

Details: [`docker-run.md`](docker-run.md)

## Option 4: Dockge install

Clone the repo into the Dockge stacks folder using the lowercase target folder `zorg_memorydb`. Dockge/Compose normalize stack names to lowercase; using this folder up front prevents Dockge from creating a second lowercase duplicate beside `Zorg_MemoryDB`:

```bash
cd /opt/stacks
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg_memorydb
sudo chown -R "$USER:$USER" /opt/stacks/zorg_memorydb
cd /opt/stacks/zorg_memorydb
cp .env.example .env
```

Details: [`dockge-install.md`](dockge-install.md)

## Sudo-heavy systems

If Docker or clone location requires sudo:

```bash
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg_memorydb
cd zorg_memorydb
sudo cp .env.example .env
sudo docker compose up -d --build
```

## Verify

Docker/Dockge:

```bash
docker compose ps
docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "openclaw database memory" --limit 5'
```

Native:

```bash
cd ~/Zorg_MemoryDB
.venv-sqlmem/bin/python scripts/memory_sql_tool.py tables
.venv-sqlmem/bin/python scripts/memory_recall_router.py "openclaw database memory" --limit 5
```

Expected recall mode: `database-direct-structured`.

## What you should not need to do

You should not need to manually connect the database to OpenClaw. Each install path handles that during startup/bootstrap.
