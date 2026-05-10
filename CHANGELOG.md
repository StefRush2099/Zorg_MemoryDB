# Changelog

All meaningful changes to this project are documented here and released with a GitHub Release plus GHCR container image.

## [Unreleased]

### Added

## [v1.2.7] - 2026-05-10

### Changed

- Removed hard-coded Docker Compose project naming so Compose/Dockge installs inherit the actual install folder instead of forcing `zorg_memorydb`.
- Replaced the global `zorg_openclaw_home` named volume with a folder-local `./openclaw-home` bind mount so runtime state, workspace files, embedded PostgreSQL data, and memory DB stay underneath the folder where `docker compose up --build` is run.
- Updated Docker, Dockge, quickstart, release, and base-setup docs to allow arbitrary install folder names and document unique ports for multiple simultaneous installs on one host.

### Verified

- Validated Docker Compose config and folder-local bind paths for two separate test installs.
- Built and started separate Compose installs from different folders with independent `openclaw-home` directories.

## [v1.2.6] - 2026-05-08

### Added

- Added public-safe hard system guidance for public conversation-loop suppression in email, messaging, voice, contact forms, and related public channels.
- Added adaptive cron self-repair guidance requiring assistant-owned cron jobs to check changed conditions and fix routine drift directly instead of asking the operator.
- Added core no-scripted-policy guidance: internal assistant routines should be expressed as natural-language rules, prompts, runbooks, cron payloads, and commands that an LLM applies live.
- Added LLM-governed email-check guidance: scheduled email triggers should only detect unread mail and provide neutral metadata; live LLM judgment applies all triage, reply, contact, CC/BCC, deletion, and escalation rules.
- Added duplicate-meeting prevention guidance for calendar/email scheduling: check existing events and threads first, update matching events instead of creating duplicates, and clean accidental duplicates quietly.
- Added exact Hyperdine/X article-link guidance: paired X posts must use the verified full per-article Hyperdine anchor URL and must never truncate anchors to fit post length.

### Changed

- Clarified that Hyperdine/news-feed style publishing should be LLM-governed from current rules and live feed state; scripts are allowed only as narrow mechanical helpers for I/O or API calls.
- Updated public templates and executive-assistant rules so future installs inherit the same dynamic operating pattern instead of embedding policy in code.

## [v1.2.5] - 2026-05-07

### Added

- Added public-safe guidance that individual/contact-specific email-copy rules override default operator CC behavior.
- Added `OPERATOR_BCC_RECIPIENTS` placeholder for recipient-specific BCC exceptions.
- Added public-safe guidance that cron jobs should be LLM instruction jobs with context and stop conditions, not blind mutator scripts.

### Changed

- Updated the rich-email helper template so configured BCC exceptions override default operator CC behavior before serialization/API send.

## [v1.2.4] - 2026-05-07

### Added

- Added `docs/before-you-get-started.md` to explain pre-install account, hosting, API key, OAuth, GitHub, backup, Cloudflare, Docker, and Dockge preparation.
- Added README guidance and `.env.example` placeholders for OpenRouter, OpenAI, messaging, email OAuth, GitHub backup, and Cloudflare setup.

### Clarified

- Documented OpenRouter as a practical minimum model-provider path and OpenAI API as the recommended entry-level production baseline.
- Clarified that email and GitHub access require provider-specific authorization tokens that must remain private.

## [v1.2.3] - 2026-05-07

### Added

- Added operator-copy email guidance for executive-assistant installs, including an `OPERATOR_CC_EMAIL` example and setup checklist item.
- Updated templates to require visible operator CC on outbound assistant email by default.

### Changed

- Hardened the shared rich-email helper template so configured operator CC is injected before message serialization/API send.
- Clarified that BCC is not a substitute for the default visible operator-copy rule unless explicitly approved for a specific message.

## [v1.2.2] - 2026-05-07

### Added

- Added public communication guidance for using truthful, public-safe lived operational examples without telegraphing the technique or exposing private context.
- Updated executive-assistant docs, recall rules, positioning docs, and templates so public communication can feel natural and grounded instead of mechanical.

## [v1.2.1] - 2026-05-07

### Added

- Added recommended base setup documentation for useful OpenClaw + Zorg MemoryDB installs: instant messaging, dedicated assistant email identity, governed personal-email access, private database-backup repo, Cloudflare Tunnel connector, Dockerized services, and Dockge visibility.

## [v1.2.0] - 2026-05-07

### Added

- Added DB-only memory migration/auto-heal support for retiring active `memory/` markdown fallback and archiving legacy files into PostgreSQL.
- Added structured logic-rule recall so operating rules can be stored and searched as first-class DB rows.
- Added rich-text email helper and public-safe communication rule requiring HTML with plain-text fallback by default.
- Added mandatory local + private/off-host database backup guidance before production DB structural/index/tuning changes.
- Added production tuning gate: DB/index/schema changes should happen only after real recall failures; otherwise tuning work remains sandbox/benchmark/design only.
- Added fresh-install recommendation to create a private GitHub recovery store when none exists because private repos are free and off-host DB recovery matters.
- Added documentation/release maintenance guidance to keep public docs and releases aligned with current MemoryDB design.

### Changed

- Removed active `memory/*.md` mapping from generated SQL memory maps and migration rules.
- Updated public positioning docs explaining why Zorg MemoryDB is more than plain OpenClaw: durable DB recall, structured rules, recovery discipline, auto-heal, and additive semantic evolution.
- Updated schema, rules, templates, and install/upgrade docs to reflect DB-only memory and recovery-first operation.

### Verification

- Python and shell syntax checks passed for MemoryDB scripts.
- Schema application verified in temporary PostgreSQL databases during development.
- DB recall verified for structured logic rules and key operating-rule searches.
- DB backup path verified locally and with private GitHub recovery in the maintainer environment.
- Legacy `memory/` fallback auto-heal verified by archive/import/removal behavior.

## [v1.1.3] - 2026-05-05

### Added

- Added public-safe executive-assistant operating rules distilled from the Dan Martell Exec Admin Playbook.
- Integrated executive-assistant rules into root markdown, templates, docs, and existing-workspace migration append rules so new OpenClaw + Zorg MemoryDB installs inherit inbox, email, calendar, logistics, confidentiality, and revenue/time-priority behavior.

## [v1.1.2] - 2026-05-04

### Changed

- Removed user-facing database credential setup from the integrated OpenClaw/Zorg build.
- Removed Gateway shared-secret examples from install docs and startup examples.
- Rewrote Docker, Dockge, Docker run, quickstart, and Ubuntu docs to present Zorg MemoryDB as integrated into OpenClaw startup rather than a separate database install.
- `sql_memory_map.json` generation no longer writes a database credential field.
- Docker/Dockge internal PostgreSQL initializes with local trust access inside the OpenClaw/Zorg container.

### Verification

- Shell, Python, and Compose config checks passed.
- Fresh Docker Compose startup verified with internal PostgreSQL, memory table listing, and `database-direct-structured` recall.

## [v1.1.1] - 2026-05-04

### Fixed

- Dockge install now uses the canonical lowercase folder/stack/project name `zorg_memorydb` to match Dockge and Docker Compose normalization.
- Added `COMPOSE_PROJECT_NAME=zorg_memorydb` and top-level Compose `name` to prevent resource identity drift from uppercase source folders.
- Dockge docs now explicitly warn that cloning/importing as `Zorg_MemoryDB` can cause Dockge to create a second lowercase folder, and provide a safe migration path.

### Verification

- Verified Compose config resolves project name as `zorg_memorydb`.
- Verified a fresh lowercase `/tmp/.../zorg_memorydb` clone builds and starts with a single `openclaw` service/container, embedded PostgreSQL, memory tables, and `database-direct-structured` recall.

## [v1.1.0] - 2026-05-04

### Added

- GitHub Actions CI workflow for shell, Python, Compose, and Docker build verification.
- GitHub Actions release workflow that publishes the Docker image to GitHub Container Registry.
- GHCR image path: `ghcr.io/stefrush2099/zorg-memorydb`.
- Docker run one-liner install path.
- Release/version-control process documentation.
- GitHub community/production files: `SECURITY.md`, `CONTRIBUTING.md`, `SUPPORT.md`, and `LICENSE`.

### Changed

- Docker and Dockge installs are now one self-contained OpenClaw/Zorg container with embedded PostgreSQL.
- Removed separate Compose PostgreSQL service from Docker/Dockge installs.
- Dockge documentation now emphasizes one Dockge-managed stack/container and no parallel unmanaged Docker startup.
- README and quickstart now include standard Ubuntu, Docker Compose, Dockge, and Docker run/GHCR paths.

### Verification

- Fresh Compose startup verified on alternate port `19892`.
- Embedded PostgreSQL accepted connections on `127.0.0.1:5432`.
- `memory_sql_tool.py tables` succeeded.
- `memory_recall_router.py "database memory" --limit 3` returned `database-direct-structured`.
- Fresh GitHub clone Compose config confirmed no separate PostgreSQL service.

## [v1.0.0] - 2026-04-29

### Added

- Initial public sanitized Zorg MemoryDB repository.
- PostgreSQL-backed memory schema, recall tooling, and OpenClaw integration documentation.

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->


## Unreleased

- Added scorched-memory recall guidance across markdown surfaces: no immediate response after shallow memory misses; exhaust DB memory first, then add recall hints/indexes/relationships for any phrasing that required deep scouring.
- Added `db/scorched_memory_recall_hardening_2026_05_09.sql` to include recall hints and query observations in the canonical search surface and rank critical/high-priority recall material ahead of arbitrary source ordering.

<!-- LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->
## LLM-Governed Performance Tuning Rule

Database and memory performance tuning must be governed by live LLM judgment, not hidden script policy. Tuning work starts with a natural-language hypothesis formed from current system evidence and internet/authoritative research. If research gives a credible reason to believe a database design, recall-path, materialized-view, vector/neural association, or query-structure change will improve performance, the LLM must run side-by-side before/after measurements on representative queries before claiming success.

If research does not support a design change, move to raw additive performance work: indexes, query-path improvements, materialized/search-support views, relationships, recall hints, semantic edges, weighted connections, token/FTS/trigram support, and other non-destructive logic that brings query times down while preserving all source memory. No original memory data may be pruned, deleted, truncated, compacted away, or aged out for speed.

Every meaningful tuning change must record the research basis, before/after benchmark results, changed structures, rollback path, and follow-up indexing/hinting implications in durable memory and public-safe docs when structural behavior changes.
<!-- /LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->


## Unreleased

- Added LLM-governed performance tuning guidance: tuning must begin with research-backed hypotheses and side-by-side before/after benchmarks. If research does not justify design changes, optimize raw query performance additively through indexes, relationships, materialized/search-support views, recall hints, semantic edges, weighted connections, token/FTS/trigram support, and other non-destructive structures.

<!-- GO_ONLY_APPROVAL_RULE -->
## GO-Only Approval Rule

When Stefan gives a command that requires confirmation before execution, ask only for `GO`. Do not invent longer approval phrases, magic words, task-specific confirmations, or exact response strings such as `GO REIP ...`, `GO SCORCHED ...`, or any other expanded form. Stefan decides how to respond; the assistant may request only the simple approval token `GO`.

If the requested action is unsafe, ambiguous, destructive, externally risky, or missing a necessary decision, explain the blocker or the exact intended change briefly, then end with only `GO` as the approval request when approval is the only thing needed. Never require Stefan to repeat the task, include extra words, or match an assistant-authored phrase.
<!-- /GO_ONLY_APPROVAL_RULE -->


## Unreleased

- Added GO-only approval guidance: when an operator confirmation is needed, request only `GO` rather than task-specific approval phrases.

<!-- SAME_DAY_NEWS_FRESHNESS_RULE -->
## Same-Day News Freshness Rule

When writing multiple news articles or public reports on the same day, do not repeat the same information from article to article. Adjacent or continuing stories may reference earlier context only briefly when necessary, but each article must add fresh facts, new framing, new implications, new examples, or a clearly advanced continuation that was not already covered in earlier same-day articles.

Before drafting or publishing a new article, review the same-day feed/archive and compare titles, summaries, body claims, examples, and links. If information has already been used that day, either omit it, compress it to a short bridge, or explicitly advance it with new developments. Maintain editorial continuity without recycling paragraphs, talking points, examples, or conclusions.

The assistant owns the full article set and must keep the day’s coverage fresh, non-repetitive, and additive.
<!-- /SAME_DAY_NEWS_FRESHNESS_RULE -->


## Unreleased

- Added same-day news freshness guidance: multiple articles published on the same day must be reviewed against each other and kept fresh, non-repetitive, and additive.
