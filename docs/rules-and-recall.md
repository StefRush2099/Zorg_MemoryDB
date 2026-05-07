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

## DB-only memory auto-heal

Installations should periodically verify that recall uses the PostgreSQL backend exclusively and has not fallen back to retired markdown memory files. If a `memory/` directory or markdown fallback route appears, the system should archive/import those files into PostgreSQL, remove the filesystem directory, restore DB-only routing, refresh recall/search surfaces, and record the repair in DB memory. Successful self-healing is silent; notify only when blocked or unsafe.

## Database recovery and tuning gate

A DB-backed memory system should be treated as mission-critical state. Before any production schema/index/materialized-view/recall-routing/vector/weighted-memory change, create a full local PostgreSQL backup and push a full copy to a private recovery repository. Public distribution repos must never contain private database dumps or rows.

Performance/tuning cron jobs should be worded LLM instruction jobs. They may apply production DB/index changes only after a concrete recall failure where data existed in the DB but did not return in first-pass recall and was recovered only by deeper search, alternate query, direct inspection, or operator correction. Without that failure signal, they should restrict themselves to benchmarks, research, sandbox/temp experiments, and additive design work such as vector structures, neural-style weights, cue associations, and recall scoring prototypes.

Baseline recovery locations should be documented in local operator markdown. In Stefan's install they are: local `/home/openclaw/.openclaw/backups/postgres/local/`, private GitHub `Zorg_Hive/backups/postgres/openclaw/`, and optional shared mirror `/Zorg/backups/openclaw/postgres` or established jump-box mirror.

Fresh-install note: if no private GitHub/offsite DB backup target exists, local backup is the minimum, but the agent should explicitly recommend setting up a private GitHub repository because private repos are free and off-host recovery is critical for durable memory.
