# Install Zorg MemoryDB Package

1. Install OpenClaw from upstream.
2. Copy or install `skills/zorg-db-memory` into the OpenClaw workspace skills directory.
3. Copy or install `package/zorg` into the OpenClaw package/workspace support path.
4. Run the PostgreSQL schema/install helpers from `package/zorg` for the target host.
5. Verify backend DB recall before normal assistant work.

## LAN services and Android separation

`package/zorg/install-zorg-memorydb.sh` installs three separate surfaces:

- **LAN Console browser:** Next.js LAN Chat, normally on port `3001`; its
  browser page owns browser light/dark controls and the Android APK download
  link.
- **Memory Brain 3D service:** Node/Express service `zorg-memory-3d` on port
  `8097`; it owns `/api/health`, `/api/graph`, and the interactive 3D browser
  visualizer.
- **Native Android app:** the separately built APK under
  `package/zorg/lan-command-chat-android/`; it uses authenticated JSON APIs,
  does not load the browser page, and never displays the browser APK link.

The installer runs `npm install --omit=dev` and `npm run check` in the Memory
3D directory, then enables/restarts the `zorg-memory-3d` systemd service. After
installation, verify the service before opening the clients:

```bash
systemctl status zorg-memory-3d
curl -fsS http://127.0.0.1:8097/api/health
curl -fsS http://127.0.0.1:8097/api/graph
```

The graph response must contain `nodes` and `links`. Empty arrays are a real
empty-database state; HTTP errors or timeouts are service/database failures and
must be repaired rather than replaced with fake graph data. See
`package/zorg/memory-3d/README.md` for manual startup, environment variables,
logs, and recovery.

The skill is the canonical agent-facing procedure. The package code is the mechanical support layer.

## Required Verification

```bash
/home/openclaw/.openclaw/workspace/memory_sql_tool.py tables
/home/openclaw/.openclaw/workspace/memory_speed_test.py
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

After installation, the packaged worker is available at `memory/memory_embedding_worker.py`. Run a controlled prefill with `python3 memory/memory_embedding_worker.py --maintenance --limit 100`; repeatable runs are safe. The query cache helper is `memory/cache_model_query_embedding.py` and is used by `memory_recall_router.py` for ANN queries. The semantic worker remains available at `skills/zorg-db-memory/scripts/memory_semantic_worker.py` for additive cue/association processing.

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
