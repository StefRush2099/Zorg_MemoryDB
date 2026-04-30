# Rules and Recall

## Permanent rules

1. Memory check is Priority 0.
2. DB-backed recall is primary.
3. Flat-file fallback is allowed only after DB unavailability is confirmed or explicitly allowed.
4. Weak first-pass recall requires deeper recall, not an immediate conclusion.
5. Before claiming inability, search prior working solutions, runbooks, project records, backups, mirrors, and related operational facts.
6. Preserve all source history forever; never prune, delete, truncate, age out, compact-by-removal, or discard original/source data for performance. The database must grow continuously.
7. Whenever any meaningful structural, configuration, routing, schema, indexing, recall, benchmark, enforcement, or operational-rule change is made to the memory database or recall system, publish the matching structural update to `Zorg_MemoryDB` and update the relevant markdown/runbooks.
8. Public exports must be schema/tooling/rules only unless all data is intentionally synthetic.
9. Recall quality must evolve additively toward vector/neural-style weighted semantic retrieval: add embeddings/vector slots, concepts/entities, aliases, graph edges, query feedback, LLM-readable recall hints, and materialized views without deleting source rows.

## Recall escalation

Recommended order:

1. `memory_sql_tool.py search "query" --table all`
2. `--table project`, `--table host`, or `--table runbook`
3. `memory_sql_tool.py master`
4. markdown fallback if allowed
5. exact source verification

## Repopulation model

Fresh downloads start with empty tables. Populate from the local operator's own markdown/session/project sources, then refresh materialized views.

## Additive semantic evolution

The DB-memory structure should evolve like a vector/semantic memory graph while preserving all source rows. New recall layers should be additive only:

- semantic nodes for concepts, entities, projects, hosts, services, people, tools, dates, runbooks, intents, and rules
- weighted edges from source rows to nodes and from row-to-row or node-to-node associations
- provider-agnostic embedding/vector slots, with room for pgvector/ANN backends when available
- LLM-readable recall hints explaining why records are related
- query-observation feedback so successful retrievals can strengthen future weights
- materialized recall surfaces that combine text, vector scores, graph weights, recency, hard-rule priority, and user corrections

Superseded or bad process records are marked as superseded/deprecated with additive metadata. They are not deleted from source history.

## Fast-path optimization rule

Recall fast paths may use additive derived materialized views such as `zorg_memory_search_fast_mv` for precomputed lowercase text, tsvectors, ranking helpers, and indexes. These surfaces are rebuildable caches only; they must not be treated as replacements for source memory and must never justify source-data pruning.
