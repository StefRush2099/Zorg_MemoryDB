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

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
./scripts/openclaw-db-memory
```

That launcher runs the first-time setup automatically before starting OpenClaw:

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

## Using the memory tools

```bash
.venv-sqlmem/bin/python scripts/memory_sql_tool.py tables
.venv-sqlmem/bin/python scripts/memory_sql_tool.py search "project runbook" --table all --limit 10
.venv-sqlmem/bin/python scripts/memory_sql_tool.py master --limit 40
.venv-sqlmem/bin/python scripts/memory_speed_test.py
```

## Core rule

Memory is not an optional note system. It is the first context layer. OpenClaw should check DB memory before acting, prefer DB recall over flat files, and preserve original source history while adding indexes, views, and summaries around it.
