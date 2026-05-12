# Rules and Recall

## Permanent rules

1. Memory check is Priority 0.
2. DB-backed recall is primary.
3. Flat-file memory fallback is retired. If DB recall is unavailable, repair/restore DB memory or ask the operator before any exceptional non-DB fallback.
4. Weak first-pass recall requires deeper recall, not an immediate conclusion.
5. Before claiming inability, search prior working solutions, runbooks, project records, backups, mirrors, and related operational facts.
6. Preserve all source history forever; never prune, delete, truncate, age out, compact-by-removal, or discard original/source data for performance. The database must grow continuously.
7. Whenever any meaningful structural, configuration, routing, schema, indexing, recall, benchmark, enforcement, or operational-rule change is made to the memory database or recall system, publish the matching structural update to `Zorg_MemoryDB` and update the relevant markdown/runbooks.
8. Public exports must be schema/tooling/rules only unless all data is intentionally synthetic.
9. Recall quality must evolve additively toward vector/neural-style weighted semantic retrieval: add embeddings/vector slots, concepts/entities, aliases, graph edges, query feedback, LLM-readable recall hints, and materialized views without deleting source rows.
10. Database repair/recovery is a hard continuity rule: predictable backups must exist; repair is attempted first; backup candidates are tested if repair fails; the first verified working backup is promoted; DB health/recall tests must pass before claiming success. See [`database-recovery.md`](database-recovery.md).

## Clean-install enforcement

Clean installs must enforce DB-only memory in both rules and runtime configuration. The installer/startup path writes valid OpenClaw `agents.defaults.memorySearch` settings with `enabled: true`, `provider: local`, `fallback: none`, and `sources: [memory]`. `scripts/enforce_db_memory_search.py` must create or patch `openclaw.json` even when the file does not exist yet, and must avoid unsupported config keys so fresh OpenClaw gateways still pass schema validation.

The `memory/` subdirectory is retired. It must not be used for daily notes, project notes, people research, source notes, heartbeat state, JSON logs, or any durable memory. If a `memory/` directory appears during or after install, the auto-heal path archives/imports it into PostgreSQL, removes it from the filesystem, and records the repair in DB memory.

## Recall escalation

Recommended order:

1. `memory_sql_tool.py search "query" --table all`
2. `--table project`, `--table host`, or `--table runbook`
3. `memory_sql_tool.py master`
4. DB repair/restore path if recall is unavailable
5. exact source verification

## Repopulation model

Fresh downloads start with empty tables. Populate core markdown rules into DB and, for legacy workspaces, archive any retired `memory/` directory into `public.zorg_memory_file_archive` plus line-indexed `zorg_memory` rows before removing the filesystem directory. Then refresh materialized views. Do not recreate `memory/` as a durable memory surface.

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

## Contact/CRM Recall Rule

When an install has authorized Google Contacts access, sync contacts into the private `zorg_contacts_crm` tables using `scripts/sync_google_contacts_to_memory_db.py`. Contact sync is additive and recovery-oriented: keep the provider raw JSON, normalized lookup fields, sync run history, and indexed recall text. Do not prune original contact source data for performance.

Contact data is sensitive. Use it for private recall, CRM-style continuity, correct addressing, timezone/timing judgment, and relationship-aware communication, but never publish live contact contents or credentials. If a contact import changes memory schema, update public structure/docs only; do not publish rows.

## Associative Problem-Solving Before Escalation

Zorg MemoryDB is designed to support more than exact lookup. When a task fails, especially an authorized business-contact or recovery task, the assistant should combine structured memory, CRM records, prior correspondence, project context, public/official sources, and adjacent clues to infer the next safe action. A failed business email should trigger official-site/domain research and credible alternate contact paths before escalation, not a dead end.

This rule should remain public-safe in documentation: publish the reasoning pattern and schema support, never private contacts, live email contents, credentials, or operator-specific strategy.


## Contact Deduplication Rule

Contacts should be deduplicated/distilled for recall while preserving raw provider data. Never merge or delete raw contacts by name alone. Use strong evidence such as matching email, phone, or provider resource identifiers for automatic canonical grouping. Name-only collisions should become review flags so the assistant can inspect carefully without destroying source data.

CRM recall should prefer canonical contacts from `zorg_contact_canonical_crm`; raw `zorg_contacts_crm` rows remain the recovery/source-of-truth layer.


## Recursive Logic and Deduced Rule Formation

A MemoryDB-backed assistant should not only memorize explicit instructions; it should distill reusable logic from instructions, examples, public-safe executive-assistant references, and observed mistakes. When a rule implies a broader safeguard, the assistant should convert that implication into a durable check, runbook, recall hint, semantic edge, or logic-rule row.

Public-safe executive-assistant principles include: protect operator time, be preemptive, prioritize revenue/time/reputation, close loops, answer clearly and kindly, prepare concise options when escalation is needed, and perform final checks before reporting completion. Private relationship or contact context may guide decisions inside the operator environment, but live private details must never be published.

Recursive logic must remain additive: preserve source data, add derived logic structures, track review flags rather than deleting ambiguity, and tune indexes/materialized views/benchmarks so richer reasoning does not degrade recall speed.

## Public communication recall

For public-facing emails, posts, and sales/positioning messages, durable memory should provide more than facts. It should help the assistant recall truthful, public-safe operational experiences that make an explanation feel grounded.

The communication pattern is:

1. Search memory for relevant lived operational examples before drafting public communication.
2. Use only examples that are truthful, relevant, and safe to share.
3. Adapt tone using private recipient/operator context only as a silent filter.
4. Do not reveal the private filter, private strategy, or sensitive details.
5. Do not telegraph the writing technique with phrases like "here is a personal example." Just make the point naturally.

This matters because people often trust concrete lived examples more readily than abstract feature lists. Zorg MemoryDB's design should support both: hard factual recall internally, and natural public communication externally.

## DB-only memory auto-heal

Installations should periodically verify that recall uses the PostgreSQL backend exclusively and has not fallen back to retired markdown memory files. If a `memory/` directory or markdown fallback route appears, the system should archive/import those files into PostgreSQL, remove the filesystem directory, restore DB-only routing, refresh recall/search surfaces, and record the repair in DB memory. Successful self-healing is silent; notify only when blocked or unsafe.

## Database recovery and tuning gate

A DB-backed memory system should be treated as mission-critical state. Before any production schema/index/materialized-view/recall-routing/vector/weighted-memory change, create a full local PostgreSQL backup and push a full copy to a private recovery repository. Public distribution repos must never contain private database dumps or rows.

Performance/tuning cron jobs should be worded LLM instruction jobs. They may apply production DB/index changes only after a concrete recall failure where data existed in the DB but did not return in first-pass recall and was recovered only by deeper search, alternate query, direct inspection, or operator correction. Without that failure signal, they should restrict themselves to benchmarks, research, sandbox/temp experiments, and additive design work such as vector structures, neural-style weights, cue associations, and recall scoring prototypes.

Baseline recovery locations should be documented in local operator markdown. In Stefan's install they are: local `/home/openclaw/.openclaw/backups/postgres/local/`, private GitHub `Zorg_Hive/backups/postgres/openclaw/`, and optional shared mirror `/Zorg/backups/openclaw/postgres` or established jump-box mirror.

Fresh-install note: if no private GitHub/offsite DB backup target exists, local backup is the minimum, but the agent should explicitly recommend setting up a private GitHub repository because private repos are free and off-host recovery is critical for durable memory.

## LLM-governed operations, not scripted policy

Zorg MemoryDB's operating pattern should keep judgment in the LLM and durable rules, not buried in helper scripts. Internal assistant routines should be represented as natural-language instructions, DB-backed rules, runbooks, cron payloads, and explicit commands. The LLM should recall current rules, inspect current state, and decide the safe next action live.

Helper scripts may exist for narrow mechanical tasks such as reading provider metadata, formatting an already chosen message, querying a database, or calling an API. They must not encode dynamic policy: email triage, contact creation, scheduling decisions, publication pairing, duplicate handling, sender exceptions, loop suppression, deletion, escalation, or public/private judgment belong to current rules plus LLM reasoning.

## Email trigger pattern

Email checking should use a trigger pattern. A scheduled helper may detect unread mail and output neutral metadata. It should not decide whether a message is important, draft or send replies, create contacts, choose CC/BCC, delete mail, or suppress public conversation loops.

When unread mail exists, the scheduled job should queue or run an LLM instruction turn. The LLM then recalls current email/contact rules from DB memory and core markdown, inspects the relevant thread/contact context, and performs only the action allowed by current rules.

## Scheduling duplicate prevention

Meeting scheduling should check existing calendar events and relevant email threads for the same attendees, topic, date, and time before creating a new invite. If a match exists, update the existing event instead of creating a duplicate. Mistaken duplicate meetings should be de-duplicated quietly unless attendee-facing details actually changed.

## Paired publishing exact-link rule

When a public short post points to a long-form news/feed article, it should link to the exact verified article anchor. The model should verify the full per-article anchor in the live page HTML before posting. If character limits are tight, shorten prose or hashtags; do not truncate, guess, or replace the article anchor with a feed-top URL.

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->


## Scorched-memory recall implementation note

The canonical recall surface must include explicit recall hints and query observations alongside core rules, contacts, relationships, projects, hosts, runbooks, and operational facts. Query ranking should prefer critical/high-priority recall material and semantically useful hints before arbitrary source ordering. When an operator correction proves a known memory existed but was missed, treat it as a production recall failure: add aliases, hints, relationship edges, query observations, indexes, or materialized-search support so the same phrasing is not missed again.

<!-- LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->
## LLM-Governed Performance Tuning Rule

Database and memory performance tuning must be governed by live LLM judgment, not hidden script policy. Tuning work starts with a natural-language hypothesis formed from current system evidence and internet/authoritative research. If research gives a credible reason to believe a database design, recall-path, materialized-view, vector/neural association, or query-structure change will improve performance, the LLM must run side-by-side before/after measurements on representative queries before claiming success.

If research does not support a design change, move to raw additive performance work: indexes, query-path improvements, materialized/search-support views, relationships, recall hints, semantic edges, weighted connections, token/FTS/trigram support, and other non-destructive logic that brings query times down while preserving all source memory. No original memory data may be pruned, deleted, truncated, compacted away, or aged out for speed.

Every meaningful tuning change must record the research basis, before/after benchmark results, changed structures, rollback path, and follow-up indexing/hinting implications in durable memory and public-safe docs when structural behavior changes.
<!-- /LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->


## LLM-governed performance tuning

Performance tuning should be directed by a live LLM using current metrics, current research, and representative benchmark queries. Do not bury performance policy in blind scripts. For any structural or design change, record the research basis, the expected effect, a before/after benchmark, and a rollback path.

If research does not support a schema/design change, shift to additive raw-performance work: indexes, materialized/search-support views, relationships, recall hints, semantic edges, weighted connections, token fallback, FTS, trigram support, and query-path improvements. Preserve all original memory rows and source data.

<!-- GO_ONLY_APPROVAL_RULE -->
## GO-Only Approval Rule

When Stefan gives a command that requires confirmation before execution, ask only for `GO`. Do not invent longer approval phrases, magic words, task-specific confirmations, or exact response strings such as `GO REIP ...`, `GO SCORCHED ...`, or any other expanded form. Stefan decides how to respond; the assistant may request only the simple approval token `GO`.

If the requested action is unsafe, ambiguous, destructive, externally risky, or missing a necessary decision, explain the blocker or the exact intended change briefly, then end with only `GO` as the approval request when approval is the only thing needed. Never require Stefan to repeat the task, include extra words, or match an assistant-authored phrase.
<!-- /GO_ONLY_APPROVAL_RULE -->


## Operator approval wording

Approval prompts should not create unnecessary friction. If approval is the only missing input, request only `GO`; do not invent task-specific magic phrases.

<!-- SAME_DAY_NEWS_FRESHNESS_RULE -->
## Same-Day News Freshness Rule

When writing multiple news articles or public reports on the same day, do not repeat the same information from article to article. Adjacent or continuing stories may reference earlier context only briefly when necessary, but each article must add fresh facts, new framing, new implications, new examples, or a clearly advanced continuation that was not already covered in earlier same-day articles.

Before drafting or publishing a new article, review the same-day feed/archive and compare titles, summaries, body claims, examples, and links. If information has already been used that day, either omit it, compress it to a short bridge, or explicitly advance it with new developments. Maintain editorial continuity without recycling paragraphs, talking points, examples, or conclusions.

The assistant owns the full article set and must keep the day’s coverage fresh, non-repetitive, and additive.
<!-- /SAME_DAY_NEWS_FRESHNESS_RULE -->


## Same-day article recall before publishing

Before writing a new article or public report, recall/read same-day feed entries so the new piece does not repeat earlier coverage. Same-day publishing should be additive: each article should contribute new details, framing, examples, or developments.
