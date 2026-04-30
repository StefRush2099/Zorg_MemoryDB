# Weighted Semantic Recall Design

This design makes DB memory evolve toward vector/neural-style recall while preserving all original data.

## Non-negotiable retention rule

Original/source memory rows are permanent durable history. Do not prune, delete, truncate, age out, compact-by-removal, or discard them for performance. Performance work must add structures instead of removing source information.

## Additive recall layers

1. **Source layer** - immutable durable memory rows and imported markdown/session/project records.
2. **Semantic node layer** - LLM-extracted concepts, entities, projects, hosts, tools, people, dates, intents, rules, and aliases.
3. **Weighted edge layer** - relationships between source rows, nodes, projects, runbooks, tools, and query intents.
4. **Embedding/vector slot layer** - provider-agnostic embedding metadata and optional vector payloads so pgvector/ANN search can be added without changing source rows.
5. **Recall hint layer** - short LLM-readable explanations of why memories are related, familiar, important, superseded, or operationally useful.
6. **Query feedback layer** - records query patterns and which memories actually helped, then increases/decreases derived weights without deleting source history.
7. **Materialized recall layer** - precomputed context surfaces combining text rank, vector similarity, graph weight, recency, frequency, priority, user correction, and successful-use feedback.

## Weight model

Recommended composite score inputs:

- semantic/vector similarity
- full-text/trigram match
- graph edge strength
- hard-rule priority
- explicit user correction or approval
- project/host/tool/runbook relevance
- recency where useful, without aging old data out
- frequency of successful recall
- contradiction/supersession metadata

## LLM familiarity objective

Future LLMs should not receive only raw matches. They should also receive:

- related concepts/entities/aliases
- weighted reasons the record is relevant
- nearby operational facts/runbooks
- whether a record is current, superseded, deprecated, or a hard rule
- source pointers proving where the memory came from

This gives any future model clear familiarity cues and lets it recall data through a weighted semantic neighborhood instead of brittle exact-string search.
