# Markdown Statement Neural Import

Zorg MemoryDB can import active workspace markdown into statement-level database rows. The goal is to make markdown bootstrap/config material addressable by DB recall without treating markdown files as the active memory store.

## What It Creates

One registry row per active markdown file in `markdown_file_registry`.

One decomposed row per heading, list item, rule statement, paragraph, or line statement in `markdown_statement_entries`.

One physical per-file mirror table named `md_stmt_<hash>` for each markdown file.

One append-only import audit row in `markdown_statement_import_runs`.

Search integration through `markdown_statement_recall_v` and `zorg_search_memory(query, limit)`.

Each statement row stores source path, source hash, line range, heading path, statement kind, priority, canonical text, DB/neural/recency/query weights, and minimum/maximum context token hints. These fields let recall choose smaller or larger context slices from the database instead of injecting entire markdown files by default.

## Startup Import

`scripts/import_markdown_memory.py` performs the import. On startup or first run it:

Reads active markdown files under the workspace while excluding backups, dependency folders, caches, temporary folders, private recovery repos, and generated runtime artifacts.

Updates `markdown_file_registry` with the file hash, timestamp, path, and statement count.

Decomposes markdown into statement rows and upserts them into `markdown_statement_entries`.

Ensures and refreshes the matching `md_stmt_<hash>` per-file table.

Adds matching `memory_semantic_nodes` entries so weighted semantic recall can associate statements with other DB memory.

Refreshes existing DB recall materialized views when those refresh functions exist.

The import is additive. It does not delete source memory, prune historical rows, or discard original content for speed.

## Canonical Direction

The database is the active memory and recall surface. Markdown remains bootstrap/config/documentation unless a human explicitly requests a markdown update. If the database contains newer or richer statement data than a markdown file, the DB should win during reconciliation and can be used to update the markdown file through an explicit controlled write path.

## Verification

After applying `db/markdown_statement_neural_import_2026_05_20.sql`, run:
```bash OPENCLAW_WORKSPACE=$PWD SQL_MEMORY_MAP=$PWD/sql_memory_map.json python3 scripts/import_markdown_memory.py ```

Then verify counts:
```sql select count(*) from markdown_file_registry where active; select count(*) from markdown_statement_entries where active; select count(*) from pg_class where relname like 'md_stmt_%'; select status, files_seen, statements_seen from markdown_statement_import_runs order by started_at desc limit 1; ```

Verify recall:
```sql select source_table, source_id, category, priority, left(snippet, 160) from zorg_search_memory('markdown statement neural import fluid context', 8); ```

Expected result: active markdown files are represented in the registry, statement rows exist, the number of `md_stmt_%` tables matches the registry count, the latest import run is `completed`, and recall runs without errors.
