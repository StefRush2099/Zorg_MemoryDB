# Schema Summary

The schema is exported structure-only from a working OpenClaw DB-memory installation.

Main recall objects:

- `zorg_memory` - durable memory and remembered context
- `zorg_memory_file_archive` - archive of retired legacy `memory/` files before filesystem removal
- `md_agents`, `md_soul`, `md_user`, `md_tools`, `md_identity`, `md_heartbeat` - line-imported core markdown context
- `memory_projects`, `memory_hosts`, `memory_services`, `memory_runbooks`, `memory_relationships` - structured operational context
- `zorg_operational_facts` - promoted operational facts
- `zorg_memory_search_mv` - unified search surface
- `zorg_master_context_mv` - prioritized master context
- `zorg_recall_context(query, limit)` - broad recall entry point
- `zorg_get_project_context`, `zorg_get_host_context`, `zorg_get_runbook_context` - targeted recall entry points

Fresh installs contain no private data. The structure is intended to be repopulated locally. Legacy workspaces should archive any retired `memory/` directory into `zorg_memory_file_archive` and line-index it into `zorg_memory`, then remove the directory; new durable memory should be written to DB tables only.

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

`zorg_search_memory(query, limit)` ranks exact full-text and exact phrase matches first. If those do not fill the requested limit, it now falls back to token-level OR matching against the same precomputed indexed tsvector columns. This improves natural-language recall when a query contains several useful terms that may be split across different memory rows, while preserving the faster exact-match path for focused queries.

## Contacts CRM / Google Contacts Memory

Zorg MemoryDB includes an additive private contacts/CRM layer for installs that have authorized Google People/Contacts access. The structure is designed to preserve contact data if a mail provider account is lost and to make contact facts available to the same DB recall path as other memory.

Tables/views/functions:

- `zorg_contacts_crm` — one row per external contact record. Stores normalized fields such as display name, company, job title, primary email/phone, notes, JSONB arrays for People API fields, and the full raw person JSON for durable recovery.
- `zorg_contact_points_crm` — normalized email/phone/url points linked to contacts for lookup and dedupe.
- `zorg_contact_sync_runs` — append-only sync run history and counts.
- `zorg_contacts_crm_recall_v` — crawler/recall-safe contact text projection.
- `zorg_refresh_memory_search()` — refreshes memory search materialized views after contact sync/import.
- `zorg_memory_search_mv` / `zorg_memory_search_fast_mv` include contact rows as source type `contact`, so contact data participates in the normal DB-backed recall path.

Privacy boundary: live contact rows, phone numbers, email addresses, raw People API JSON, credentials, and sync outputs are private operator data and must not be published in public docs, examples, issues, or release notes. Public repos may include only schema, scripts, and sanitized operational guidance.

## Contacts CRM Deduplication / Distillation

The contacts layer is intentionally non-destructive. Provider rows remain in `zorg_contacts_crm`, while distilled recall should use canonical contacts.

Additional structures:

- `zorg_contact_canonical_crm` — canonical/distilled contacts used by recall. Strong dedupe uses email, phone, or provider-resource evidence; the table stores source contact IDs and source counts.
- `zorg_contact_canonical_members` — membership links from canonical contacts back to preserved raw provider contacts.
- `zorg_contact_dedupe_flags` — review flags for name-only collisions and ambiguous matches. Name-only matches are flagged, not automatically destroyed.
- `zorg_contact_duplicates_review_v` — safe review surface that exposes counts/evidence metadata without requiring raw contact deletion.
- `zorg_distill_contacts_crm()` — rebuilds canonical groups and review flags, then refreshes the memory search materialized views.

Recall uses `zorg_contacts_crm_recall_v`, which points at canonical/distilled contacts. This keeps the number of recallable contacts deduplicated while preserving every raw source row for recovery and later review.

## Recursive Logic Rules / Proactive Quality Control

Zorg MemoryDB includes an additive logic-rule layer for turning operator instructions, examples, public-safe executive-assistant principles, and observed mistakes into reusable decision structures.

Tables/views/functions:

- `zorg_logic_rules` — durable operating logic, priority, privacy scope, applicable categories, standard checks, and tuning notes.
- `zorg_logic_rule_sources` — source summaries for why a rule exists. Public docs should include only sanitized source summaries.
- `zorg_logic_rule_applications` — optional audit trail when a rule/check is applied to a task.
- `zorg_logic_rules_recall_v` — recall projection for logic rules.
- `zorg_get_logic_context(query, limit)` — logic-specific recall path.

The CRM dedupe miss is the model lesson: when a new database/list/import/CRM/memory feature is built, duplicate detection, canonicalization, count reconciliation, source preservation, recall integration, privacy checks, representative searches, and performance checks are standard final checks before declaring completion.

## Private DB backup/recovery requirement

Schema/index/recall changes require a verified full database backup first. Keep full dumps only in local/private recovery locations, never in this public structural repo. Fresh installs should configure a private GitHub recovery target equivalent to `Zorg_Hive/backups/postgres/openclaw/`.

Fresh-install note: if no private GitHub/offsite DB backup target exists, local backup is the minimum, but the agent should explicitly recommend setting up a private GitHub repository because private repos are free and off-host recovery is critical for durable memory.

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->


## Recall hints in search surface

`memory_recall_hints` and `memory_query_observations` are part of the canonical recall surface. They should be materialized into the main search view so alternate wording, relationship labels, operator corrections, and prior query failures become first-class retrieval cues. This keeps recall behavior neural/vector-like: source rows remain preserved, while additive hints and weighted associations improve future retrieval without pruning history.
