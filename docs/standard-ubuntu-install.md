# Standard Ubuntu Install

This path installs OpenClaw natively on Ubuntu and wires Zorg MemoryDB into the OpenClaw workspace during first run.

## One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/StefRush2099/Zorg_MemoryDB/main/scripts/install_standard_ubuntu.sh | bash
```

What it does:

1. installs Ubuntu packages needed for OpenClaw and local memory runtime
2. installs `openclaw@latest`
3. clones `Zorg_MemoryDB` into `~/Zorg_MemoryDB`
4. starts local PostgreSQL
5. creates the local OpenClaw memory role/database with local trust access
6. writes `sql_memory_map.json` into the OpenClaw workspace
7. applies the Zorg MemoryDB schema and recall surfaces
8. starts OpenClaw with memory already wired

## Start OpenClaw after install

```bash
cd ~/Zorg_MemoryDB
source .env.native
OPENCLAW_WORKSPACE=$PWD SQL_MEMORY_MAP=$PWD/sql_memory_map.json openclaw gateway run --allow-unconfigured --bind "$OPENCLAW_GATEWAY_BIND" --port "$OPENCLAW_GATEWAY_PORT" --auth "$OPENCLAW_GATEWAY_AUTH"
```

## Verify

```bash
cd ~/Zorg_MemoryDB
.venv-sqlmem/bin/python scripts/memory_sql_tool.py tables
.venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5
```

Expected recall mode: `database-direct-structured`.
