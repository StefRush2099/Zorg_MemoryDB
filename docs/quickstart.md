# Quickstart: All-in-One OpenClaw + Zorg MemoryDB

This repo is the clean-install template. It starts both OpenClaw and the Zorg PostgreSQL memory database together.

## Normal Docker start

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
cp .env.example .env
docker compose up -d --build
```

## Sudo-heavy systems

If Docker or clone location requires sudo:

```bash
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
sudo cp .env.example .env
sudo docker compose up -d --build
```

Or use the bootstrap helper:

```bash
curl -fsSL https://raw.githubusercontent.com/StefRush2099/Zorg_MemoryDB/main/scripts/bootstrap_full_openclaw.sh | bash
```

## Verify

```bash
docker compose ps
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "openclaw database memory" --limit 5'
```

## What you should not need to do

You should not need to manually connect the database to OpenClaw. The OpenClaw container does that on startup before launching the Gateway.
