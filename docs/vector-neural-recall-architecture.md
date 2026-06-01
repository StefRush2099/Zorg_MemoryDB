# Vector/Neural Recall Architecture

Zorg MemoryDB is moving toward a source-preserving vector/neural recall database. PostgreSQL remains the durable system of record, while derived semantic, vector, graph, feedback, and ranking layers make recall more fluid over time.

## Architecture Direction

The database should not be treated as a static keyword store or a fixed set of seed priorities. Current and future recall paths should combine:

Durable source rows and structured logic rules.

Statement-level markdown decomposition.

Semantic nodes, aliases, and weighted edges.

Recall hints and query observations.

pgvector ANN candidates from deterministic local vectors.

Real model embeddings through the active local embedding provider.

Query-result feedback and positive/negative retrieval feedback.

Dynamic logic-rule ranking from use and feedback.

Materialized/search views for fast DB-first recall.

Continuous bounded maintenance that updates derived surfaces without

deleting source memory.

## Clean-Install Layers

`scripts/first_run.sh` applies these public-safe additive layers after the base schema and seed rules:

`dynamic_trigger_backpressure_2026_05_16.sql`

`semantic_neural_recall_v1.sql`

`neural_recall_layer_2026_05_18.sql`

`pgvector_ann_recall_2026_05_18.sql`

`provider_model_embeddings_2026_05_18.sql`

`local_model_embeddings_768_2026_05_18.sql`

`recency_weighted_recall_context_2026_05_18.sql`

`neural_recall_continuous_maintenance_2026_05_20.sql`

`ann_recall_active_logic_filter_2026_05_20.sql`

`markdown_statement_neural_import_2026_05_20.sql`

`dynamic_logic_rule_ranking_2026_05_20.sql`

This order keeps the base schema intact, creates vector and feedback surfaces, then imports statement-level markdown and dynamic logic-rule weights.

## Source Preservation

Source rows are durable history. Performance and recall improvements must add derived structures rather than pruning, compacting, truncating, deleting, or aging out source data. Derived rows may be rebuilt, marked inactive, or superseded when the source content changes, but the original source remains.

## Dynamic Weighting

Seed priorities are only the starting point. The live system can adjust derived weights through:

`memory_retrieval_feedback` for positive/negative recall evidence.

`memory_query_observations` for query patterns and intent signals.

`memory_neural_query_results` for returned result/rank history.

`memory_semantic_edges` for weighted associations.

`zorg_logic_rule_dynamic_weights` for existing rule promotion/demotion.

These weights may change without operator approval because they are derived recall metadata, not new operating rules or source-memory deletion.

## Runtime Boundaries

Database triggers and recall-adjacent hooks enqueue tiny bounded work only. Heavy association, ANN-neighbor, feedback, and embedding maintenance runs in workers or maintenance functions with dynamic backpressure. Correct recall and rule-following outrank speed.

## Verification

Use `docs/verification.md#full-vectorneural-recall-stack-verification` after clean installs and upgrades. A passing install proves the vector extension, semantic queue, weighted edges, ANN tables, model embedding tables, query cache, markdown statement tables, dynamic rule weights, and recall functions exist.

## Live Maintenance Notes

2026-06-01 live ANN maintenance filled a local-hash coverage gap by
backfilling every eligible unified search-surface row into
`memory_ann_embeddings`, including logic-rule rows that were missing from the
derived ANN layer. The same maintenance pass refreshed planner statistics,
added a bounded batch of `ann_nearest_neighbor` semantic edges, and marked
low-information derived ANN rows inactive when the ANN payload was only a
standalone HTML marker or date fragment.

This is source-preserving maintenance: source memory, rules, search views, and
legacy embedding slots remain intact. The inactive ANN rows can be rebuilt from
source if the low-information filter changes later.
