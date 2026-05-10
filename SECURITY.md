# Security Policy

## Supported versions

Use the latest GitHub Release and the matching GHCR image tag for security-sensitive installs.

## Reporting a vulnerability

Open a private/security report through GitHub if available, or contact the repository owner directly.

Do not include private memory rows, credentials, cookies, OAuth material, SSH keys, chat logs, email contents, or other sensitive data in public issues.

## Security model

`Zorg_MemoryDB` is a sanitized install template. It should contain structure, schema, scripts, docs, and public templates only.

The repository must never include:

- real database dumps or live rows
- private `MEMORY.md` contents
- private `memory/*.md` files
- `.env` files with real secrets
- `sql_memory_map.json` with real credentials
- API keys, OAuth tokens, cookies, SSH keys, contact data, email content, transcripts, or private operator context

Docker/Dockge installs run OpenClaw and PostgreSQL inside one self-contained container. Do not expose the Gateway publicly without appropriate network controls.

## GitHub Actions

Workflows use the least required `GITHUB_TOKEN` permissions per job:

- CI: read-only contents
- release: package/release publishing permissions only when a semver tag is pushed

Container images are published to GitHub Container Registry using the repository-scoped `GITHUB_TOKEN`.

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

