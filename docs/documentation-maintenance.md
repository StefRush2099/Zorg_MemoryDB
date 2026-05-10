# Documentation and Release Maintenance

Zorg MemoryDB documentation is part of the product, not an afterthought.

The repo should always explain the current design accurately enough that a new user understands why this build exists, what it adds to plain OpenClaw, how to install it, how to recover it, and what changed recently.

## Required update rule

Whenever a meaningful DB-memory, recall, schema, index, routing, install, automation, release, backup, privacy, communication, or operating-rule change is made, update all public-safe documentation surfaces that are affected.

At minimum, check:

- `README.md`
- `CHANGELOG.md`
- `docs/why-zorg-memorydb.md`
- `docs/rules-and-recall.md`
- `docs/schema-summary.md`
- `docs/database-recovery.md`
- install docs: Docker, Dockge, Docker run, Ubuntu, quickstart
- release notes under `docs/releases/`
- templates: `AGENTS.md`, `MEMORY.md`, and `templates/*`
- scripts/docs that teach fresh installs or existing-workspace upgrades

## Why this matters

Plain OpenClaw is a strong agent runtime. Zorg MemoryDB is the same base plus a living operational memory system:

- DB-only durable memory and recall
- structured operating rules
- recursive logic and proactive final checks
- contact/communication privacy rules
- rich-text email defaults
- DB-only recall auto-healing
- mandatory DB backups and private/off-host recovery recommendations
- production DB tuning gated by real recall failures
- additive semantic evolution toward weighted/vector/neural-style recall

If the docs do not describe those current capabilities, users cannot understand why Zorg MemoryDB is different from plain OpenClaw.

## Release duty

Releases must not lag behind meaningful changes. Every meaningful structural/install/runtime/schema/recall/rule update needs:

1. public-safe docs update
2. `CHANGELOG.md` update
3. curated release note file under `docs/releases/vX.Y.Z.md`
4. commit and push to `main`
5. semantic version tag
6. GitHub Release / GHCR workflow trigger

Patch-only typo fixes can be grouped. Feature/rule/schema/recovery changes should be released promptly so people can see what changed.

## Public-safety boundary

Publish structure, scripts, schema, templates, examples, and public-safe explanations only.

When a meaningful operating rule changes — especially DB-memory recall, no-scripted-policy behavior, LLM-governed cron/email/contact/scheduling behavior, publication verification, or recovery rules — update the relevant public markdown/runbooks and release notes before considering the local change complete. Local core-rule changes should not remain private if they teach future installs how to reproduce the current public-safe design.

Never publish:

- private DB dumps or rows
- contacts
- credentials
- transcripts
- emails
- live operator context
- internal private strategy

Private recovery backups belong in a private repository such as `Zorg_Hive`, not in the public `Zorg_MemoryDB` repo.

## Periodic review expectation

A maintenance agent should periodically scan the docs and releases against the current MemoryDB design and recent commits. If public-safe docs/releases are stale, update them and publish a new release. If no meaningful public-safe change is pending, stay quiet.

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

