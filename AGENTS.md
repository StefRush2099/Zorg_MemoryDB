# AGENTS.md - DB Memory Operating Rules

## Priority 0: memory before action

Before any reply, tool call, command, file change, external action, or claim of inability:

1. Query the database-backed memory system for the current request category, project, system, and likely prior solution.
2. If first-pass recall is weak or empty, perform a deeper DB recall using alternate phrasings and adjacent concepts.
3. Use flat-file markdown only as a fallback when the DB path is confirmed unavailable, or as a source for repopulating the DB.
4. If memory cannot be checked, fail closed: do not proceed except to repair or verify the memory path.

## DB-first recall rule

- DB memory is the primary recall source.
- Markdown files are durable source material and bootstrap inputs, not the primary semantic lookup path.
- Prior working solutions, runbooks, project history, backups, and service paths must be searched before asking the operator for help.

## Preservation rule

- Never prune or delete durable source history as an optimization.
- Improve recall additively with indexes, materialized views, summaries, link tables, weighted associations, and query-plan tuning.
- Sanitization for public sharing must remove data rows and secrets while preserving schema and repopulation structure.

## Verification rule

Do not claim DB memory is installed, repaired, migrated, or working until these pass:

```bash
python scripts/memory_sql_tool.py tables
python scripts/memory_sql_tool.py refresh
python scripts/memory_speed_test.py
```
