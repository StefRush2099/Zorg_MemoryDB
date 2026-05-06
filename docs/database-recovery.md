# Database Backup, Repair, and Recovery Rule

This is a top-level hard rule for Zorg MemoryDB installs.

A future agent or large language model must be able to recover memory service even if the active database is badly corrupted and normal DB recall is unavailable. The markdown files are the emergency map. They must clearly tell the next agent where backups live, what to try first, and how to verify recovery.

## Hard rule

1. **Backups must be predictable.** Database backups must be written to a predictable local location so any future model can find them from markdown instructions alone.
2. **Repair first.** If the active database is inaccessible or corrupted, attempt safe database repair first when possible.
3. **Recover from backup if repair fails.** If repair cannot restore a working DB, search the predictable backup locations and test backup versions until a working one is found.
4. **Promote the first verified working backup.** Restore the first backup that passes health and recall verification, then use it as the active database going forward.
5. **Verify before claiming success.** After repair or restore, run database health and recall tests before declaring the system fixed.
6. **Never delete source memory to recover performance.** Recovery may rebuild derived views/indexes/caches, but original/source memory should be preserved.

## Predictable backup locations

Use these locations in order:

1. `$OPENCLAW_WORKSPACE/backups/database/`
2. `$OPENCLAW_WORKSPACE/backups/postgres/`
3. `$OPENCLAW_HOME/backups/database/`
4. `$OPENCLAW_HOME/backups/postgres/`
5. `/home/openclaw/.openclaw/backups/database/`
6. `/home/openclaw/.openclaw/backups/postgres/`

Recommended filename pattern:

```text
zorg-memorydb-YYYYMMDD-HHMMSS.dump
zorg-memorydb-YYYYMMDD-HHMMSS.sql.gz
zorg-memorydb-YYYYMMDD-HHMMSS.pgcustom
```

Backups may be PostgreSQL custom-format dumps, compressed SQL dumps, or implementation-specific snapshots, but they should be named clearly and stored under the predictable directories above.

## Repair-first process

When the database appears broken:

1. Read markdown rules first, because DB recall may be unavailable.
2. Identify the active OpenClaw workspace and home:
   - `OPENCLAW_WORKSPACE`, if set
   - otherwise `/home/openclaw/.openclaw/workspace`
   - `OPENCLAW_HOME`, if set
   - otherwise `/home/openclaw/.openclaw`
3. Check PostgreSQL availability:

```bash
pg_isready -h 127.0.0.1 -p 5432 || true
```

4. Try safe repair steps appropriate to the install:
   - restart only the DB service/container if the service is down
   - run `ANALYZE`/refresh materialized views if the DB is online but recall surfaces are stale
   - refresh derived recall views/functions from schema scripts when available
   - rerun import/bootstrap scripts only when they are known to be non-destructive for the current install

Suggested non-destructive checks from an OpenClaw workspace:

```bash
.venv-sqlmem/bin/python scripts/memory_sql_tool.py tables
.venv-sqlmem/bin/python scripts/memory_sql_tool.py refresh
.venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5
```

If safe repair restores health, stop and verify. Do not restore a backup unnecessarily.

## Backup recovery process

If repair fails:

1. Search predictable backup locations.
2. Sort backups newest-first unless there is a known reason to prefer another order.
3. For each candidate backup:
   - restore into a temporary test database or isolated test container first when possible
   - run health and recall verification
   - reject backups that fail to restore, fail schema checks, or cannot answer recall tests
4. Restore/promote the first verified working backup to the active DB.
5. Refresh materialized views and recall surfaces.
6. Re-run verification.
7. Record which backup was used and why older/newer candidates were rejected.

Example candidate search:

```bash
find "$OPENCLAW_WORKSPACE/backups" "$OPENCLAW_HOME/backups" /home/openclaw/.openclaw/backups \
  -type f \( -name '*.dump' -o -name '*.sql.gz' -o -name '*.pgcustom' -o -name '*postgres*' -o -name '*memorydb*' \) \
  2>/dev/null | sort -r
```

## Verification after repair or recovery

A database is not recovered until tests pass.

Minimum checks:

```bash
pg_isready -h 127.0.0.1 -p 5432
cd /home/openclaw/.openclaw/workspace
.venv-sqlmem/bin/python scripts/memory_sql_tool.py tables
.venv-sqlmem/bin/python scripts/memory_sql_tool.py refresh
.venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory recovery verification" --limit 5
```

For packaged repo testing:

```bash
bash -n scripts/*.sh docker/entrypoint.sh
python3 -m py_compile scripts/*.py
docker compose config >/tmp/zorg-memorydb-compose.yml
```

Expected result:

- PostgreSQL is reachable.
- Zorg memory tables are visible.
- Materialized views refresh successfully.
- Recall router returns DB-backed results or a clearly explained empty result with DB mode active.
- OpenClaw memory_search routing remains enforced when runtime files are available.

## What to report

Stay concise, but include:

- whether repair succeeded or backup recovery was required
- backup path used, if any
- candidates tested/rejected, if relevant
- final DB health/recall verification result
- any data-loss risk or unresolved blocker

## Public-safety note

Do not publish database backups, dumps, private memory rows, transcripts, contacts, emails, credentials, account data, or operator context to the public `Zorg_MemoryDB` repository. Public docs should describe structure and recovery procedure only.
