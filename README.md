# Zorg MemoryDB for OpenClaw

A sanitized, public DB-memory variant for OpenClaw-compatible workspaces.

This repository publishes the database-memory structure and operating rules, not a copy of any private memory. It is designed so a downloaded instance can create the same schema and then repopulate it with its own local markdown/session/project data.

## What is included

- PostgreSQL schema-only structure in `db/schema.sql`
- DB-first recall tooling in `scripts/`
- sanitized config example in `config/sql_memory_map.example.json`
- permanent memory operating rules in `AGENTS.md`, `SOUL.md`, `TOOLS.md`, and `docs/`
- empty templates for workspace markdown files in `templates/`

## What is not included

- no personal memories
- no chat history rows
- no credentials or tokens
- no private hostnames/IPs
- no private project data
- no production database dump with data

## Quick start

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
createdb openclaw_memory
export DATABASE_URL='postgresql://USER:PASSWORD@127.0.0.1:5432/openclaw_memory'
./scripts/install_db_memory.sh
cp config/sql_memory_map.example.json sql_memory_map.json
# edit sql_memory_map.json for your database
.venv-sqlmem/bin/python scripts/memory_sql_tool.py tables
```

After installing, copy or create your own `AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md`, `IDENTITY.md`, `HEARTBEAT.md`, and `memory/*.md`, then run:

```bash
OPENCLAW_WORKSPACE="$PWD" .venv-sqlmem/bin/python scripts/import_markdown_memory.py
OPENCLAW_WORKSPACE="$PWD" .venv-sqlmem/bin/python scripts/memory_sql_tool.py refresh
```

## Core rule

Memory is not an optional note system. It is the first context layer. OpenClaw should check DB memory before acting, prefer DB recall over flat files, and preserve original source history while adding indexes, views, and summaries around it.
