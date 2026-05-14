
## 2026-05-14

- Added the LAN console (`lan-chat`) to the base Zorg MemoryDB repository and Docker Compose install so new deployments include a maintained web fallback communication path by default.
- Clarified that `lan-chat` is a built-in local command chat/back channel for the default install, not a separate optional add-on, and documented the maintenance responsibility to keep it available.


## 2026-05-14

- Added AI DJ agent reporting pattern for documenting memory-backed persona, artist-research, music-news, and streaming-station behavior in public-safe reports.


## 2026-05-14

- Added public-safe recall failure benchmark documentation and chart methodology for measuring confirmed memory/recall correction incidents without publishing private transcripts, credentials, contact data, or live database rows.

# Changelog

All meaningful changes to this project are documented here and released with a GitHub Release plus GHCR container image.

## [Unreleased]

### Added

### Changed

### Verified

## [v1.2.10] - 2026-05-12

### Added

- Added clean-install DB-only memory enforcement so fresh Docker/Ubuntu installs write OpenClaw memory settings that disable flat-file fallback and force Zorg MemoryDB recall.
- Added an optional `openclaw-cli` Docker Compose helper service for launching OpenClaw TUI/chat against the same folder-local `./openclaw-home` state.
- Documented Docker Compose TUI/chat commands: `docker compose run --rm openclaw-cli tui --local` and `docker compose run --rm openclaw-cli chat`.

### Changed

- `scripts/enforce_db_memory_search.py` now creates or patches `openclaw.json` even when the file does not already exist, and removes unsupported stale `zorgMemoryDb` draft config keys.
- Docker and standard Ubuntu startup now write DB-only `agents.defaults.memorySearch` settings during clean install.
- Strengthened core/template rules to prohibit durable `memory/` markdown files and require DB repair/restore instead of markdown fallback.
- Made `scripts/db_only_memory_autoheal.py` honor workspace/config environment variables for clean installs and non-default workspaces, avoid startup-time materialized-view refreshes unless explicitly requested, and preserve the SQL venv Python path instead of resolving it to the system interpreter.
- First-run bootstrap now invokes DB-only auto-heal after importing core rules and enforcing memory routing; startup continues after logging any retryable auto-heal warning.

### Verified

- Verified clean installs write DB-only `memorySearch` config and that `memory/` is absent after first run.
- Validated Docker Compose config includes the new `openclaw-cli` helper service.

## [v1.2.8] - 2026-05-10

### Changed

- Added automatic external host-port selection for Docker Compose installs by publishing OpenClaw from the `OPENCLAW_GATEWAY_PUBLISHED_PORTS` range, defaulting to `18789-18889`.
- Separated the internal container listen port (`OPENCLAW_GATEWAY_CONTAINER_PORT`) from the external host port range so Compose can move to the next free host port without changing the OpenClaw container port.
- Updated Docker, Dockge, quickstart, and release docs to tell users to check `docker compose ps` / `docker ps` for the selected external port.

### Verified

- Validated Docker Compose config resolves the default published range to `18789-18889:18789`.
- Tested a real port collision on `18789`; Compose selected the next available external port automatically.

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
## 2026-05-13 - Semantic neural recall v1

- Added queue-driven semantic association layer for weighted MemoryDB recall.
- Added `memory_semantic_work_queue`, tuner metadata, weighted recall audit rows, source/contact/success-query enqueue triggers, and `zorg_weighted_recall_context`.
- Added `scripts/memory_semantic_worker.py` to build semantic nodes, weighted edges, recall hints, and query observations outside PostgreSQL hot paths.
- Documented safety model: additive only, no source pruning, lightweight triggers, bounded worker batches, backup/benchmark gate.

