# Zorg Memory 3D

Zorg Memory 3D is the standard local visualizer for a Zorg MemoryDB install.
It renders PostgreSQL-backed memory relationships, recall traces, rule weights,
scheduled-job activity, and runtime timing observations as an interactive 3D
graph with light and dark modes.

The service reads database connection details from the installed
`sql_memory_map.json` file by default. You can override that with
`ZORG_MEMORY_MAP`, `SQL_MEMORY_MAP`, `DATABASE_URL`, or the usual `PG*` /
`ZORG_DB_*` environment variables.

Default URL on a Standard Ubuntu install:

```bash
http://127.0.0.1:8097/
```

Default URL on Docker Compose or Dockge installs:

```bash
docker compose port zorg-memory-3d 8097
```

Use `?theme=light` to open directly in light view.
