# Zorg MemoryDB OpenClaw Template

Zorg MemoryDB is now an all-in-one OpenClaw install template. Clone this repository, start Docker Compose, and it brings up a complete clean OpenClaw Gateway with PostgreSQL-backed Zorg DB memory already installed, configured, connected, imported, and enforced.

This repository is **not** only a database add-on. The Docker build installs OpenClaw itself, starts PostgreSQL, seeds the OpenClaw workspace with the Zorg MemoryDB template, applies the schema, writes `sql_memory_map.json`, imports the markdown memory/rules, enforces DB-backed `memory_search`, and then starts the OpenClaw Gateway.

## What starts

- `openclaw` service: full OpenClaw CLI/Gateway install with Zorg DB memory enabled
- `postgres` service: PostgreSQL 16 memory database on the private Compose network
- persistent Docker volumes for OpenClaw state/workspace and PostgreSQL data
- first-run bootstrap that wires OpenClaw memory recall to PostgreSQL before Gateway startup

## Quick start: complete Docker OpenClaw install

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
cp .env.example .env
# Optional but recommended: edit OPENCLAW_GATEWAY_TOKEN and DB_PASSWORD in .env
docker compose up -d --build
```

OpenClaw Gateway starts on port `18789` by default. The default token is in `.env`; change it before exposing the service beyond a trusted local machine.

Check status:

```bash
docker compose ps
docker compose logs -f openclaw
```

Verify DB memory inside the OpenClaw container:

```bash
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

## Quick start for systems that need sudo for git clone or Docker

Some locked-down systems need elevated rights even to clone into the target directory, or require sudo for Docker. Use the bootstrap script path:

```bash
curl -fsSL https://raw.githubusercontent.com/StefRush2099/Zorg_MemoryDB/main/scripts/bootstrap_full_openclaw.sh | bash
```

Or manually:

```bash
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
sudo cp .env.example .env
sudo docker compose up -d --build
```

If the clone creates root-owned files but you want to manage the repo as your normal user afterward:

```bash
sudo chown -R "$USER:$USER" Zorg_MemoryDB
```

## Configuration

Copy `.env.example` to `.env` and edit as needed:

```bash
DB_NAME=openclaw_memory
DB_USER=openclaw_memory
DB_PASSWORD=openclaw_memory
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_GATEWAY_BIND=lan
OPENCLAW_GATEWAY_AUTH=token
OPENCLAW_GATEWAY_TOKEN=change-me-zorg-token
```

The container writes the matching OpenClaw memory configuration to:

```text
/home/openclaw/.openclaw/workspace/sql_memory_map.json
```

Inside Docker, `DB_HOST` is already set to the Compose service name `postgres`, so no manual host/container linking is required. PostgreSQL is not published to the host by default; OpenClaw reaches it over the private Compose network.

## First-run behavior

When the `openclaw` container starts, `docker/entrypoint.sh` runs the complete setup:

1. install/use the bundled full OpenClaw CLI from the Docker image
2. seed `/home/openclaw/.openclaw/workspace` from this template repository if needed
3. create `.venv-sqlmem`
4. write `sql_memory_map.json`
5. wait for the PostgreSQL service
6. apply `db/schema.sql`
7. import markdown memory/rule files into PostgreSQL
8. refresh recall/search materialized views
9. enforce OpenClaw built-in `memory_search` routing through Zorg DB memory
10. start `openclaw gateway run`

## Existing OpenClaw installs

The primary path is now the all-in-one Docker template above. If you intentionally need to attach Zorg MemoryDB to an already-installed OpenClaw workspace, the legacy upgrade helper remains available:

```bash
OPENCLAW_WORKSPACE=/path/to/existing/openclaw/workspace ./scripts/upgrade_existing_openclaw.sh
```

Use that only for migration/repair. New clean installs should use Docker Compose from this repo.

## Included

- `Dockerfile` — full OpenClaw + Zorg MemoryDB container image
- `docker-compose.yml` — OpenClaw Gateway + PostgreSQL all-in-one stack
- `docker/entrypoint.sh` — first-run OpenClaw/Zorg DB wiring before Gateway startup
- `scripts/bootstrap_full_openclaw.sh` — clone/start helper for sudo-heavy systems
- `db/schema.sql` — Zorg DB memory schema, functions, indexes, views, and recall structures
- `scripts/first_run.sh` — idempotent memory DB bootstrap
- `scripts/memory_sql_tool.py` and `scripts/memory_recall_router.py` — canonical DB recall tools
- `scripts/enforce_db_memory_search.py` — DB-backed OpenClaw `memory_search` enforcement
- `templates/` and top-level markdown files — clean memory/rule workspace templates

## Core rule

Zorg MemoryDB preserves original/source memory data and improves recall additively with schema, indexes, materialized views, summaries, concepts, and weighted associations. Do not prune or delete source memory for performance.
