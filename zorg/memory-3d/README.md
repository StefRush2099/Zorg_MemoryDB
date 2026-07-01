# Zorg Memory 3D

Zorg Memory 3D is the standard local visualizer for a Zorg MemoryDB install.
It renders a PostgreSQL-backed memory install as an interactive 3D graph with
light and dark modes.

The public package is schema-neutral by design. It does not ship a built-in
table map, relationship map, or private graph shape. Each install discovers its
own local PostgreSQL catalog at runtime, and private structure remains local to
that install.

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

Discovery defaults to the `public` schema and tables whose names begin with
`memory_` or `zorg_`. Override discovery without changing the public package:

```bash
ZORG_MEMORY_3D_DB_SCHEMA=public
ZORG_MEMORY_3D_TABLE_PREFIXES=memory_,zorg_
ZORG_MEMORY_3D_MAX_TABLES=40
ZORG_MEMORY_3D_MAX_ROWS_PER_TABLE=12
ZORG_MEMORY_3D_STATEMENT_TIMEOUT_MS=2500
```
