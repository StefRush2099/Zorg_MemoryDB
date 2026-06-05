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

## 2026-05-25 recency/token/supersession repair

Recall ranking must not let an older high-priority row hide newer matching instructions about the same subject. The 2026-05-25 repair adds timestamp-aware scoring, meaningful query-token overlap, and supersession cues to the weighted recall path while preserving all source rows.

The migration is `db/recency_token_supersession_recall_2026_05_25.sql`. It updates:

- `zorg_search_memory(query, limit)` so important non-stopword tokens are used to build candidates before broad priority ordering dominates.
- `zorg_recall_context(query, limit)` so exact phrase and token overlap rank ahead of generic priority when selecting candidates.
- `zorg_weighted_recall_context(query, limit)` so returned weight breakdowns include `event_ts`, `category`, `token_overlap`, `recency`, and `supersession` components.

Operational rule: when two memories describe the same preference or instruction, compare timestamp, priority, category, and query-token overlap. Newer matching preference rows can supersede older preference rows without deleting either record.

Before applying this migration in production, create and verify the temporary local PostgreSQL backup. Do not commit, mirror, or push database dumps to GitHub. After applying, refresh materialized recall surfaces and verify with stale-vs-newer test queries.

## 2026-05-25 temporary deep-scan enforcement window

When an operator identifies avoidable recall misses and orders a temporary deep-scan period, the DB recall router can force every non-wiki/non-session memory lookup through the weighted recall path with a higher minimum candidate limit. This is intentionally temporary and evidence-driven: it increases recall depth long enough to collect query observations and tune weights without permanently adding latency to every response.

Set:

- `ZORG_DEEP_RECALL_UNTIL` to an ISO timestamp, for example `2026-05-27T07:56:00Z`.
- `ZORG_DEEP_RECALL_MIN_LIMIT` to the largest value that completes inside the live memory-search timeout on representative queries. On the 2026-05-25 incident, `18` worked for the original screenshot-dimension query but failed on a broader cron-repair query, so the enforced live default was reduced to `12`. Larger values such as `40` or `120` exceeded the live route timeout.

The router reports `mode: database-direct-structured-deep`, `requested_limit`, `effective_limit`, and `deep_scan_until` while the window is active. Verification must include the exact query that previously failed and a timing measurement that proves the route still completes before the caller timeout.

<!-- GO_ONLY_APPROVAL_RULE -->
## GO-Only Approval Rule

When Stefan gives a command that requires confirmation before execution, ask only for `GO`. Do not invent longer approval phrases, magic words, task-specific confirmations, or exact response strings such as `GO REIP ...`, `GO SCORCHED ...`, or any other expanded form. Stefan decides how to respond; the assistant may request only the simple approval token `GO`.

If the requested action is unsafe, ambiguous, destructive, externally risky, or missing a necessary decision, explain the blocker or the exact intended change briefly, then end with only `GO` as the approval request when approval is the only thing needed. Never require Stefan to repeat the task, include extra words, or match an assistant-authored phrase.
<!-- /GO_ONLY_APPROVAL_RULE -->

<!-- SAME_DAY_NEWS_FRESHNESS_RULE -->
## Same-Day News Freshness Rule

When writing multiple news articles or public reports on the same day, do not repeat the same information from article to article. Adjacent or continuing stories may reference earlier context only briefly when necessary, but each article must add fresh facts, new framing, new implications, new examples, or a clearly advanced continuation that was not already covered in earlier same-day articles.

Before drafting or publishing a new article, review the same-day feed/archive and compare titles, summaries, body claims, examples, and links. If information has already been used that day, either omit it, compress it to a short bridge, or explicitly advance it with new developments. Maintain editorial continuity without recycling paragraphs, talking points, examples, or conclusions.

The assistant owns the full article set and must keep the day’s coverage fresh, non-repetitive, and additive.
<!-- /SAME_DAY_NEWS_FRESHNESS_RULE -->


## 2026-05-13 production v1: queue-driven semantic association loop

The production-safe implementation uses database triggers only to enqueue work, not to run arbitrary generated code in PostgreSQL hot paths.

New additive objects:

- `memory_semantic_work_queue` - durable queue for source, contact, successful-query, and recall-query association work.
- `memory_semantic_tuner_versions` - records the active LLM-governed tuner/worker version and safety notes.
- `memory_recall_weight_runs` - audit trail for weighted recall calls and max score/result counts.
- `memory_enqueue_semantic_job(...)` - idempotent queue insert + `pg_notify` signal.
- Source triggers on `zorg_memory`, `zorg_contacts_crm`, and `zorg_success_query_index` enqueue lightweight jobs.
- `zorg_weighted_recall_context(query, limit)` - returns normal recall context plus `relevance_score`, `relevance_percent`, `score_reason`, and `weight_breakdown`.
- `scripts/memory_semantic_worker.py` - outside-DB worker that claims queue rows with `FOR UPDATE SKIP LOCKED`, extracts semantic cues, upserts nodes, creates weighted edges, adds recall hints, and refreshes derived search surfaces.

Safety/performance shape:

- Source rows are never deleted or compacted away.
- Trigger work is O(1): enqueue + notify only.
- Worker batches are bounded and can run periodically/opportunistically.
- Derived graph/vector-like layers are additive and rebuildable.
- LLM tuning must revise worker/migration logic only after recall evidence, backup, and before/after benchmarks.

Operational behavior:

- Existing recall surfaces are seeded into the queue with staggered due times.
- New memories, CRM contacts, and successful query records enqueue automatically.
- Calls to weighted recall enqueue `recall_query` jobs so query patterns become future association cues.

Research basis used for v1 implementation:

- PostgreSQL `CREATE TRIGGER` supports row-level/statement-level triggers and `AFTER` triggers that see completed row changes; v1 uses this only for enqueue metadata, not heavy work.
- PostgreSQL `NOTIFY` is intended for transaction-safe change signaling and recommends storing larger structured data in tables while sending a lightweight notification payload; v1 stores job payloads in `memory_semantic_work_queue` and sends only the queue signal.
- PostgreSQL `FOR UPDATE SKIP LOCKED` is documented as appropriate for avoiding lock contention among multiple consumers of a queue-like table; v1 worker uses it for bounded concurrent-safe queue claims.
## Dynamic Trigger Backpressure Rule

Database triggers and recall-adjacent hooks must not perform heavy immediate work. They enqueue tiny bounded work with statistically derived `due_at` delays based on at least a 90-day rolling activity window when available, observed request timestamps/durations, idle gaps, queue wait, worker runtime, backlog, CPU/load, and recall/query timing. Workers use dynamic batch limits and record timing observations after each batch. Deeper indexing, trigger, and recall tuning should be delayed into statistically idle/off-hours windows; during historically active periods, only short bounded tuning bursts may run when latency/load permits. Under high CPU/load/latency, delays increase and batch sizes shrink. Rule-following and recall correctness outrank speed, and source memory must never be deleted/pruned/compacted for performance.
