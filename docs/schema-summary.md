# Schema Summary

The schema is exported structure-only from a working OpenClaw DB-memory installation.

Main recall objects:

- `zorg_memory` - durable memory and remembered context
- `md_agents`, `md_soul`, `md_user`, `md_tools`, `md_identity`, `md_heartbeat` - line-imported markdown context
- `memory_projects`, `memory_hosts`, `memory_services`, `memory_runbooks`, `memory_relationships` - structured operational context
- `zorg_operational_facts` - promoted operational facts
- `zorg_memory_search_mv` - unified search surface
- `zorg_master_context_mv` - prioritized master context
- `zorg_recall_context(query, limit)` - broad recall entry point
- `zorg_get_project_context`, `zorg_get_host_context`, `zorg_get_runbook_context` - targeted recall entry points

Fresh installs contain no data. The structure is intended to be repopulated locally.

## Weighted semantic recall objects

The schema includes additive tables for vector/neural-style recall evolution:

- `memory_semantic_nodes` - LLM-derived concepts/entities/intents/rules/projects/etc.
- `memory_semantic_edges` - weighted graph edges between source rows, semantic nodes, and other recall objects.
- `memory_embedding_slots` - provider-agnostic embedding/vector metadata and optional vector payload storage.
- `memory_recall_hints` - LLM-readable explanations that make familiarity/relevance explicit for future models.
- `memory_query_observations` - query/result feedback used to strengthen useful associations over time.

These objects are derived/additive. They may be rebuilt, but source memory rows must not be removed for performance.

## Fast recall surface

`zorg_memory_search_fast_mv` is an additive derived materialized view over `zorg_memory_search_mv`. It precomputes lowercase content, English/simple tsvectors, source rank, and content length so recall queries avoid repeated per-row text normalization/vectorization. It is refreshable/rebuildable derived data and must not replace or prune source memory.
