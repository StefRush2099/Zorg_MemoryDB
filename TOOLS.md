# TOOLS.md - DB Memory Tools

## Canonical tools

- `scripts/memory_sql_tool.py` - direct DB recall, table listing, refresh, and row retrieval
- `scripts/memory_recall_router.py` - structured DB-first recall wrapper
- `scripts/import_markdown_memory.py` - imports local markdown into mapped DB tables
- `scripts/memory_speed_test.py` - basic DB lookup timing check
- `scripts/install_db_memory.sh` - schema and dependency bootstrap

## Environment variables

- `OPENCLAW_WORKSPACE` - workspace root; defaults to current directory
- `SQL_MEMORY_MAP` - path to `sql_memory_map.json`
- `PGPASSWORD` - optional password override so secrets do not have to be written into config
- `DATABASE_URL` - used by the installer for `psql`

## Public safety

Do not commit real `sql_memory_map.json`, credentials, database dumps with rows, logs, or personal memory files.
