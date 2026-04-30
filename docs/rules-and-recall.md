# Rules and Recall

## Permanent rules

1. Memory check is Priority 0.
2. DB-backed recall is primary.
3. Flat-file fallback is allowed only after DB unavailability is confirmed or explicitly allowed.
4. Weak first-pass recall requires deeper recall, not an immediate conclusion.
5. Before claiming inability, search prior working solutions, runbooks, project records, backups, mirrors, and related operational facts.
6. Preserve all source history; do not prune original data for performance.
7. Whenever any meaningful structural, configuration, routing, schema, indexing, recall, benchmark, enforcement, or operational-rule change is made to the memory database or recall system, publish the matching structural update to `Zorg_MemoryDB` and update the relevant markdown/runbooks.
8. Public exports must be schema/tooling/rules only unless all data is intentionally synthetic.

## Recall escalation

Recommended order:

1. `memory_sql_tool.py search "query" --table all`
2. `--table project`, `--table host`, or `--table runbook`
3. `memory_sql_tool.py master`
4. markdown fallback if allowed
5. exact source verification

## Repopulation model

Fresh downloads start with empty tables. Populate from the local operator's own markdown/session/project sources, then refresh materialized views.
