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

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

<!-- LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->
## LLM-Governed Performance Tuning Rule

Database and memory performance tuning must be governed by live LLM judgment, not hidden script policy. Tuning work starts with a natural-language hypothesis formed from current system evidence and internet/authoritative research. If research gives a credible reason to believe a database design, recall-path, materialized-view, vector/neural association, or query-structure change will improve performance, the LLM must run side-by-side before/after measurements on representative queries before claiming success.

If research does not support a design change, move to raw additive performance work: indexes, query-path improvements, materialized/search-support views, relationships, recall hints, semantic edges, weighted connections, token/FTS/trigram support, and other non-destructive logic that brings query times down while preserving all source memory. No original memory data may be pruned, deleted, truncated, compacted away, or aged out for speed.

Every meaningful tuning change must record the research basis, before/after benchmark results, changed structures, rollback path, and follow-up indexing/hinting implications in durable memory and public-safe docs when structural behavior changes.
<!-- /LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->


## Performance tuning discipline

Weighted semantic recall changes must be measured. A tuning pass should begin with research and a hypothesis, then compare before/after results on representative recall queries. If no research-backed design change is justified, tune raw performance additively: indexes, edges, hints, materialized views, token/FTS/trigram support, and ranking improvements. Do not prune source memory for speed.

<!-- GO_ONLY_APPROVAL_RULE -->
## GO-Only Approval Rule

When Stefan gives a command that requires confirmation before execution, ask only for `GO`. Do not invent longer approval phrases, magic words, task-specific confirmations, or exact response strings such as `GO REIP ...`, `GO SCORCHED ...`, or any other expanded form. Stefan decides how to respond; the assistant may request only the simple approval token `GO`.

If the requested action is unsafe, ambiguous, destructive, externally risky, or missing a necessary decision, explain the blocker or the exact intended change briefly, then end with only `GO` as the approval request when approval is the only thing needed. Never require Stefan to repeat the task, include extra words, or match an assistant-authored phrase.
<!-- /GO_ONLY_APPROVAL_RULE -->

