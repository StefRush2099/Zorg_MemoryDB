# Zorg MemoryDB for OpenClaw

Zorg MemoryDB is an OpenClaw variation with PostgreSQL-backed memory attached from the start.

Instead of treating memory as loose markdown that has to be scanned repeatedly, this design gives OpenClaw a structured recall layer with tables, indexes, materialized views, and query functions. The result is a more useful assistant: it can retrieve prior rules, project context, runbooks, host/service relationships, and operational facts faster and with better structure than flat-file lookup alone.

The goal is simple: make OpenClaw remember more like an operational system. Database memory improves recall quality, keeps important context queryable, supports performance tuning as the memory grows, and gives future instances a clean structure they can immediately populate and use.

## Included

- PostgreSQL memory schema in `db/schema.sql`
- automatic first-run bootstrap in `scripts/first_run.sh`
- OpenClaw launch wrapper in `scripts/openclaw-db-memory`
- Docker Compose PostgreSQL fallback in `docker-compose.yml`
- DB-first recall tooling in `scripts/`
- default database config template in `config/sql_memory_map.example.json`
- permanent memory operating rules in `AGENTS.md`, `SOUL.md`, `TOOLS.md`, and `docs/`
- workspace markdown templates in `templates/`

## Quick start

### Local or VM install

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
./scripts/openclaw-db-memory
```

### Docker container install

Start the PostgreSQL memory database with the included Compose file:

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
docker compose up -d postgres
```

Then run the OpenClaw DB-memory setup inside your OpenClaw container:

```bash
docker exec -it <openclaw-container> bash
cd /workspace
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
DB_HOST=host.docker.internal DB_PORT=5432 DB_NAME=openclaw_memory DB_USER=openclaw_memory DB_PASSWORD=openclaw_memory ./scripts/first_run.sh
./scripts/openclaw-db-memory
```

On Linux hosts where `host.docker.internal` is not available, start the OpenClaw container with:

```bash
docker run --add-host=host.docker.internal:host-gateway ...
```

If the database runs in the same Docker Compose network as OpenClaw, use the Compose service name instead:

```bash
DB_HOST=postgres DB_PORT=5432 DB_NAME=openclaw_memory DB_USER=openclaw_memory DB_PASSWORD=openclaw_memory ./scripts/first_run.sh
```

The launcher runs the first-time setup automatically before starting OpenClaw:

1. creates the Python memory-tool environment
2. creates `sql_memory_map.json` if needed
3. starts the bundled PostgreSQL container when no reachable database is configured and Docker is available
4. creates/applies the database schema
5. imports local markdown memory files into the database
6. refreshes recall materialized views
7. verifies the memory tool can list tables
8. launches `openclaw`

If you only want to initialize the database memory layer without launching OpenClaw:

```bash
./scripts/first_run.sh
```

Optional environment overrides:

```bash
DB_HOST=127.0.0.1 DB_PORT=5432 DB_NAME=openclaw_memory DB_USER=openclaw_memory DB_PASSWORD=openclaw_memory ./scripts/first_run.sh
```


## Add DB memory to an existing OpenClaw install

Use this path when OpenClaw is already installed and you want to attach the database-memory layer without replacing your current workspace.

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
OPENCLAW_WORKSPACE=/path/to/existing/openclaw/workspace ./scripts/upgrade_existing_openclaw.sh
```

The upgrade script performs the full attachment process:

1. creates or reuses `.venv-sqlmem` in the existing OpenClaw workspace
2. copies the DB-memory tools into that workspace
3. creates `sql_memory_map.json`
4. starts the bundled PostgreSQL container when no reachable database is configured and Docker is available
5. applies the memory database schema
6. updates the existing markdown files with the permanent DB-memory rules
7. imports existing `MEMORY.md`, `memory/*.md`, `AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md`, `IDENTITY.md`, and `HEARTBEAT.md` content into the database
8. refreshes the recall materialized views
9. verifies the attached database can list recall tables

You can also point the upgrade at an external PostgreSQL database:

```bash
OPENCLAW_WORKSPACE=/path/to/existing/openclaw/workspace DB_HOST=postgres.example.local DB_PORT=5432 DB_NAME=openclaw_memory DB_USER=openclaw_memory DB_PASSWORD=openclaw_memory ./scripts/upgrade_existing_openclaw.sh
```

After the upgrade, run recall checks from the existing OpenClaw workspace:

```bash
cd /path/to/existing/openclaw/workspace
.venv-sqlmem/bin/python memory_sql_tool.py tables
.venv-sqlmem/bin/python memory_sql_tool.py search "important project rule" --table all --limit 10
```

To launch OpenClaw through the DB-memory wrapper from this repository:

```bash
cd Zorg_MemoryDB
OPENCLAW_WORKSPACE=/path/to/existing/openclaw/workspace ./scripts/openclaw-db-memory
```

## Using the memory tools

```bash
.venv-sqlmem/bin/python scripts/memory_sql_tool.py tables
.venv-sqlmem/bin/python scripts/memory_sql_tool.py search "project runbook" --table all --limit 10
.venv-sqlmem/bin/python scripts/memory_sql_tool.py master --limit 40
.venv-sqlmem/bin/python scripts/memory_speed_test.py
```

## Core rule

Memory is not an optional note system. It is the first context layer. OpenClaw should check DB memory before acting, prefer DB recall over flat files, and preserve original source history while adding indexes, views, and summaries around it.
