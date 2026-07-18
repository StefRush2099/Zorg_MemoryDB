# Native PostgreSQL operation

Zorg MemoryDB can run against a workspace-local PostgreSQL installation rather
than a PostgreSQL container. The native deployment used for the current
release is PostgreSQL 18.4 with the existing databases restored logically into
a clean cluster. The public package documents the procedure, but never ships
the server binaries, database directory, dumps, logs, credentials, or rollback
volume.

## Migration order

1. Stop or quiesce MemoryDB writers and dependent services.
2. Create and verify fresh logical backups of every user database and globals.
3. Install PostgreSQL 18 in a workspace-local directory and initialize a new
   cluster. Do not reuse a PostgreSQL 16 data directory.
4. Restore globals, roles, extensions, and each user database. Apply the
   public schema/migrations required by the install.
5. Verify SQL connectivity, structured recall, weighted recall, ANN/vector
   recall, semantic-worker scheduling, LAN Command Chat, and Memory Brain 3D.
6. Switch dependent services to the native endpoint only after all checks pass.
7. Stop and remove the retired PostgreSQL container after the acceptance gate.
   Keep its volume untouched during the rollback window; deleting rollback data
   is a separate authorization.

## Runtime helpers

Keep start/stop helpers beside the native installation. They should resolve
their own installation root, use `pg_ctl`, write to a local log directory, and
wait for PostgreSQL to become ready. Service configuration must resolve the
database through `SQL_MEMORY_MAP` or `ZORG_SQL_MEMORY_MAP`; do not hard-code an
operator's home directory or publish credentials in a repository.

Typical acceptance checks are:

```bash
skills/zorg-db-memory/scripts/memory_sql_tool.py tables
skills/zorg-db-memory/scripts/memory_speed_test.py
skills/zorg-db-memory/scripts/memory_sql_tool.py search "native PostgreSQL 18 ANN vector recall" --table ann
```

The old container profile should be marked retired so a normal Compose start
cannot recreate it accidentally. Retain the old volume only as a private,
local rollback artifact.

## Release boundary

Public GitHub updates may include this procedure, safe schema/migration files,
portable helpers, and verified source changes. They must exclude database
dumps, live rows, transcripts, contacts, credentials, `.env` files,
`sql_memory_map.json`, binaries, data directories, logs, backups, build output,
and retired runtime artifacts.
