# Install Zorg MemoryDB v4.1.1 Package

## Command-line install from GitHub

```bash
git clone --branch v4.1.1 https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
bash package/zorg/install-zorg-memorydb.sh
```

This is the supported clean-install path. The install initializes and enables the OpenClaw-native
`zorg-memorydb` plugin/MCP as the first and canonical memory path. It must not
create, copy, import, or activate Markdown memory or rule files; Markdown is
not a fallback store.

During installation, the existing OpenClaw JSON configuration is merged and
backed up before the installer disables built-in `memorySearch`, compaction
`memoryFlush`, and the `session-memory` hook. The `zorg-memorydb` plugin remains
enabled as the only active durable-memory path. Existing Markdown instruction
files are preserved for bootstrap/recovery reference, but are not searched or
written as memory.

1. Install OpenClaw from upstream.
2. For a clean install, create the target database and run the tagged installer.
3. Install `skills/zorg-db-memory` and its `plugin-src` into the OpenClaw
   workspace skills directory.
4. Copy or install `package/zorg` into the OpenClaw package/workspace support path.
5. Install Node.js/npm, PostgreSQL and required extensions, the configured
   local embedding provider/model, and run every SQL migration under
   `package/zorg/db`.
6. Build/install the plugin, enable it, restart the Gateway, and verify
   `openclaw plugins inspect zorg-memorydb --runtime --json` plus
   `node skills/zorg-db-memory/plugin-src/dist/mcp-server.js`.
7. Verify backend DB recall, ANN/vector index/cache/weights, scheduler
   mappings, LAN Command Chat, and the clean-install/upgrade path. Validate
   Neural Recall Activity separately against its production service.

## Existing OpenClaw or Zorg MemoryDB upgrade

1. Stop new application writes briefly and take a logical PostgreSQL backup,
   plus copies of the active OpenClaw JSON, plugin directory, service units,
   and current package tree. Verify the database archive can be listed.
2. Clone `v4.1.1` into a new staging directory. Do not delete the running
   package, database, memory rows, or history.
3. Run the installer from the staged tag. Its SQL is idempotent and upgrades
   the existing database in place; the two named pg_cron jobs are reconciled.
4. Restart the Gateway and the single dispatcher service, then verify plugin
   version, PostgreSQL objects, exactly two active named pg_cron jobs, recent
   successful cron history, queue claim/completion, recall, ANN/vector,
   semantic triggers, LAN Command Chat, and Neural Recall Activity boundaries.
5. Keep the backup and prior package until verification passes. On failure,
   stop the new runtime, restore the prior package/config atomically, and use
   the verified logical backup only if an in-place database rollback is
   actually required.

Control UI device authentication stays enabled by default. Set
`OPENCLAW_CONTROL_UI_DISABLE_DEVICE_AUTH=true` only as an explicit compatibility
override for a protected deployment that cannot use paired-device auth.

## LAN services and Android separation

`package/zorg/install-zorg-memorydb.sh` installs the connected OpenClaw/Zorg
surfaces. LAN Command Chat remains inside the same OpenClaw/Zorg runtime and
workspace; it is not a separate application or service in the standard install.

- **LAN Console browser:** Next.js LAN Chat, normally on internal port `3001`; its
  browser page owns browser light/dark controls and the Android APK download
  link.
- **Neural Recall Activity:** a separate PostgreSQL-backed production service
  on port `8097`. This repository captures its public browser assets under
  `package/zorg/neural-recall-activity/`, but does not publish the
  production-host server, database environment, or credentials.
- **Native Android app:** the separately built APK under
  `package/zorg/lan-command-chat-android/`; it uses authenticated JSON APIs,
  does not load the browser page, and never displays the browser APK link.

The retired `package/zorg/memory-3d/` package must not be restored or installed.
When a separately deployed Neural Recall Activity service is available, verify
it before opening the clients:

```bash
curl -fsS http://127.0.0.1:8097/api/health
curl -fsS http://127.0.0.1:8097/api/activity
```

See `package/zorg/neural-recall-activity/README.md` for the production boundary
and verification contract. HTTP errors or timeouts are service/database
failures and must not be replaced with fabricated activity data.

The skill is the canonical agent-facing procedure. The package code is the mechanical support layer.

## Required Verification

```bash
/home/openclaw/.openclaw/workspace/.venv-sqlmem/bin/python /home/openclaw/.openclaw/workspace/skills/zorg-db-memory/scripts/memory_sql_tool.py tables
/home/openclaw/.openclaw/workspace/.venv-sqlmem/bin/python /home/openclaw/.openclaw/workspace/skills/zorg-db-memory/scripts/memory_speed_test.py
```

If either command fails, stop unrelated work and repair DB memory first through `skills/zorg-db-memory/SKILL.md`.

## Maintainer Release Sync

Maintainer release updates may update this repo with:

- approved `zorg-db-memory` skill changes;
- public-safe MemoryDB code changes;
- install/recovery/schema references;
- screenshots that intentionally document public UI behavior;
- release notes and package artifacts.

Maintainer release updates must exclude secrets, private memory, database dumps, generated build output, and runtime-only artifacts. Installed agents must not treat this as an instruction to push to GitHub.

Publishers should build a release package manually, review the diff, run verification, and then publish a tag/release only from an approved maintainer workspace.
## ANN/vector recall bootstrap

The installer applies `db/memory_ann_bootstrap_2026_07_12.sql` after the base schema. It creates the local embedding-model slot, source-work queue, idempotent prefill/maintenance job definitions, and the `memory_ann_bootstrap_status_v1` view. It also seeds queue rows for existing `zorg_memory`, active `zorg_logic_rules`, and `memory_source_chunks` records without deleting or rewriting source memory.

The default provider is local Ollama with model `nomic-embed-text:latest` at `http://127.0.0.1:11434/api/embed`. Install and pull that model before starting the worker: `ollama pull nomic-embed-text:latest`. The public package does not download large models automatically. Set `ZORG_EMBEDDING_ENDPOINT` and `ZORG_EMBEDDING_MODEL` before running the worker when using another compatible local endpoint.

After installation, the packaged worker is available at `skills/zorg-db-memory/scripts/memory_semantic_worker.py`. The query cache helper is `skills/zorg-db-memory/scripts/cache_model_query_embedding.mjs` and is used by the skill router for ANN queries. All recall entry points remain inside `skills/zorg-db-memory`; no root-level compatibility launcher is installed.

The installer must also apply `db/memory_semantic_capture_triggers_2026_07_17.sql`.
This is the activation step for live typed runtime capture: it creates the trigger
bridge on the eleven `memory_*` capture tables and forwards each inserted or
updated source row to the existing semantic and ANN queues. The SQL file being
present in an export is not sufficient. Verify with:

```sql
select * from public.memory_semantic_capture_trigger_status_v1;
```

All eleven rows must report `trigger_enabled = true`. If the installer does not
report `semantic-capture-triggers-ok`, the update is not functionally complete.

Check setup with:

```sql
select * from public.memory_ann_bootstrap_status_v1;
select job_key, enabled, cron_expr from public.memory_llm_scheduled_jobs where job_key like 'zorg-memory-ann-%';
select status, count(*) from public.memory_semantic_work_queue group by status order by status;
```

If `enabled_model_slots` is zero, the migration did not apply. If queue rows remain queued, start the worker after confirming the Ollama endpoint and model. If rows become `error`, inspect `last_error`, correct the endpoint/model or dependency, reset only those rows to `queued`, and rerun the worker. ANN recall is not considered enabled until embeddings exist, the query cache can be populated, and a representative `memory_sql_tool.py search ... --table ann` returns rows.

### ANN activation contract

A clean install is not considered ANN-ready until `memory_ann_bootstrap_status_v1` reports an enabled default slot, the embedding worker has drained the supported source queue, and a query has a row in `memory_query_embedding_cache`. The supported default is `local` / `nomic-embed-text:latest`; set `ZORG_EMBEDDING_ENDPOINT`, `ZORG_EMBEDDING_MODEL`, and `ZORG_EMBEDDING_PROVIDER` together when using another Ollama-compatible model. Do not silently fall back to a different model: a model mismatch produces no ANN rows.

## Native PostgreSQL option

For installations that must keep PostgreSQL outside Docker, use a clean
workspace-local PostgreSQL 18 cluster and restore the databases logically.
Never point PostgreSQL 18 at a PostgreSQL 16 data directory. Follow the
backup, restore, acceptance, and rollback boundaries in
[Native PostgreSQL operation](native-postgresql.md) before switching any
dependent service.
