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
