# Verification

## Integrated Docker smoke test

From the repository root:

```bash
cp .env.example .env
docker compose config >/tmp/zorg-memorydb-compose.yml
docker compose build openclaw
docker compose up -d
docker compose ps
docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

Expected:

- one `openclaw` service/container is running
- internal PostgreSQL accepts local connections inside the same container
- `memory_sql_tool.py tables` lists Zorg memory tables
- `memory_recall_router.py` returns JSON using DB-backed recall
- OpenClaw Gateway logs show startup after memory bootstrap

## Shell/static checks

```bash
bash -n scripts/*.sh docker/entrypoint.sh
python3 -m py_compile scripts/*.py
docker compose config >/tmp/zorg-memorydb-compose.yml
```

## Schema smoke test

```bash
createdb openclaw_memory_test
psql -d openclaw_memory_test -v ON_ERROR_STOP=1 -f db/schema.sql
```

## Tool smoke test outside Docker

```bash
cp config/sql_memory_map.example.json sql_memory_map.json
python scripts/memory_sql_tool.py tables
python scripts/memory_sql_tool.py refresh
python scripts/memory_recall_router.py "project runbook" --limit 5
python scripts/memory_speed_test.py
```

`memory_speed_test.py` loads a benchmark corpus from `DB_BENCHMARK_QUERIES`, then `db_benchmark_queries.json` in the OpenClaw workspace, and finally `config/db_benchmark_queries.example.json`.

Useful knobs:

```bash
MEMORY_SPEED_RUNS=20 python scripts/memory_speed_test.py
DB_BENCHMARK_QUERIES=/path/to/db_benchmark_queries.json python scripts/memory_speed_test.py
```

## Built-in memory_search routing smoke test

Run this from an OpenClaw workspace after setup or after an OpenClaw update:

```bash
OPENCLAW_WORKSPACE=/path/to/openclaw/workspace python scripts/enforce_db_memory_search.py
```

Expected result: JSON with `"ok": true`. If OpenClaw runtime files are present, the script reports them under `runtimeFiles` and patches default memory recall to route through Zorg MemoryDB via `memory_recall_router.py`.

## Private-data scan before publishing

```bash
grep -RInE 'BEGIN (RSA|OPENSSH|PRIVATE)|cookie|oauth|credential|private_key' . \
  --exclude-dir=.git \
  --exclude='README.md' \
  --exclude='verification.md'
```

Review every match before publishing. Do not add live memory exports, database dumps, account data, contacts, or private transcripts to this repository.

## Database recovery verification

For DB corruption or inaccessible recall, follow [`docs/database-recovery.md`](database-recovery.md): safe repair first, backup recovery if repair fails, then health/recall tests. Do not claim recovery until PostgreSQL reachability, table listing, materialized-view refresh, and recall-router checks pass.

## Contacts CRM Verification

For installs with authorized Google People/Contacts OAuth scope:

```bash
python scripts/sync_google_contacts_to_memory_db.py
python scripts/memory_sql_tool.py search "contact email" --table all --limit 5
```

Expected result: the sync script prints counts only, `zorg_contact_sync_runs` records an `ok` run, `zorg_contacts_crm` contains contact rows, and DB-backed recall can return source type `contact`. Do not paste live contact output into public tickets or docs.
