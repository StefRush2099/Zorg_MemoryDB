# Connector installation and upgrade

This runbook is intentionally explicit so another operator or language model can install the connector without bypassing the database gate.

## 1. Preflight without mutation

1. Resolve the intended repository, branch/tag, package checksum, OpenClaw version, Node version, PostgreSQL server/client version, and pgvector version.
2. Read the official PostgreSQL privilege, extension, backup, and index documentation; pgvector installation/index guidance; OpenClaw plugin installation/runtime-inspection documentation; and the project release notes.
3. Inventory the current memory plugin slot, plugin allow/deny lists, installed plugin provenance, database DSN source, schema/object owners, extensions, source-row counts, queues, indexes, schedules, and connected surfaces.
4. Confirm the application role can CONNECT and has only the required schema/table/function rights. Do not confuse MAINTAIN with ownership: DDL that changes an existing object generally requires its owner or an owning role.
5. Run a logical backup with `pg_dump`, verify that the dump is non-empty and readable with `pg_restore --list`, compute SHA-256, and store it outside the public package.
6. Present facts, changes, surfaces, and rollback; wait for literal `GO`.

## 2. Database installation

1. Connect to the intended database explicitly. Print `current_database()`, `current_user`, `server_version`, and the server address before applying SQL.
2. Verify required extensions in `pg_available_extensions`. Install missing trusted extensions with an authorized owner. After `CREATE EXTENSION IF NOT EXISTS`, verify the actual extension name and version in `pg_extension`; the notice alone is not proof.
3. Apply schema and functions transactionally where PostgreSQL permits. Use idempotent migrations, explicit schema qualification, and `ON_ERROR_STOP=1`.
4. Revoke unintended PUBLIC privileges in the same transaction as sensitive function creation; grant only CONNECT, USAGE, SELECT/DML, sequence, and EXECUTE rights actually needed.
5. Seed canonical public-safe rules and schedules by stable identifiers. Never overwrite source memory or history. Retire conflicting executable schedule/task rows rather than leaving disabled executable copies.
6. Create or validate indexes. Use concurrent index creation on writable production tables when appropriate, understanding it cannot run inside a transaction and may leave an invalid index after failure. Check `pg_index.indisvalid` and remove only a newly created invalid index.
7. Run targeted ANALYZE after substantial schema/data changes. Do not use pruning or destructive vacuuming as a shortcut.

## 3. Plugin installation

1. Install from a pinned Git tag/commit or verified local package, never an ambiguous floating source.
2. Validate `openclaw.plugin.json`, package metadata, compiled distribution, checksums, and dependency lock before activation.
3. Configure the connector DSN through the approved secret/config source. Do not embed credentials in the repository, skill, logs, or chat.
4. Add the plugin ID to `plugins.allow` when an allowlist is present, remove it from deny, enable its entry, and select it for the memory slot if the host uses an exclusive slot.
5. Disable conflicting stock/legacy memory plugins only after the Zorg plugin is installed and configured. Do not leave two durable-memory paths active.
6. Restart the Gateway only when plugin code/config requires it. Verify with `openclaw plugins inspect <id> --runtime --json`; a cold manifest inspection is not runtime proof.
7. Verify the standalone MCP surface separately if deployed.

## 4. Direct turn gate

Every inbound request receives a database preparation call before reasoning or mutation. The request identity must include stable session/run/request identifiers plus a content hash. The database returns a durable receipt containing the recalled rules/context, timing, and status.

Required behavior:

- Accept only a fresh receipt for the exact current request identity.
- Reject a missing, stale, mismatched, duplicated, or failed receipt.
- Hold delivery while recovery is running.
- Do not set a small application timeout that can expire while PostgreSQL is still completing a valid preparation call.
- Record failures durably and emit one bounded operator alert; suppress duplicate alert storms.
- Resume only after a new direct preparation call succeeds and its receipt validates.

## 5. Upgrade order

1. Backup and baseline.
2. Stage and validate package.
3. Apply additive database migrations.
4. Build/test plugin.
5. Install and activate plugin configuration.
6. Restart only required services.
7. Run the acceptance matrix.
8. Update documentation/version/gauge.
9. Build and inspect the public archive.
10. Publish only after every gate passes.

Never remove the old runnable package or disable the current memory path until the replacement has passed its pre-activation checks. If activation fails, restore config/package from backup, restart the affected service, and verify the old direct gate before returning traffic.

## Official references

- PostgreSQL 18 privileges: https://www.postgresql.org/docs/18/ddl-priv.html
- CREATE EXTENSION: https://www.postgresql.org/docs/18/sql-createextension.html
- SQL dump/restore: https://www.postgresql.org/docs/18/backup-dump.html
- CREATE INDEX: https://www.postgresql.org/docs/18/sql-createindex.html
- ANALYZE: https://www.postgresql.org/docs/18/sql-analyze.html
- pgvector: https://github.com/pgvector/pgvector
- OpenClaw plugins: https://docs.openclaw.ai/tools/plugin
