# Changelog

All meaningful changes to this project are documented here and released with a GitHub Release plus GHCR container image.

## [Unreleased]

### Changed

- Updated the fast materialized-view recall fallback ranking so direct
  multi-token matches, recall hints, host rows, and project facts can outrank
  broad logic-rule or query-observation noise for concrete lookup questions.

- Added public-safe DB-only runtime memory writer rules for
  DB-before-visible-response, runtime markdown writer shutdown, emergency import
  of any recreated retired memory files, and real timestamp/duration handling on
  visible operational replies.

- Updated the DB-memory enforcer so it also patches OpenClaw's bundled
  `session-memory` and pre-compaction `memoryFlush` writer surfaces on DB-only
  installs.

- Extended the retired memory-file archive script with direct-file import
  support and updated templates/docs so clean installs and upgrades inherit the
  same structural MemoryDB rules.

- Fixed the canonical public rule seed to include all 91 active public rules
  (`public_safe` plus `public_safe_only`) and to fail if the full public set is
  not present after application.

- Existing OpenClaw upgrades now apply the public canonical rule SQL and install
  the built-in LAN command chat automatically after DB-memory verification.

- Added a public-safe canonical rule update SQL path for existing installs:
  active rule enforcement is consolidated into `zorg_logic_rules`,
  compatibility rule tables are disabled as active sources, and existing
  chat-response timing rule weights are raised without creating duplicate rules.

- Superseded older private-GitHub database-backup guidance with the current
  temporary-local-only rollback rule across docs, templates, schema seeds, and
  backup script behavior. Public `Zorg_MemoryDB` updates must never publish live
  DB dumps, rows, contacts, transcripts, credentials, or private memory.

- Zorg MemoryDB: document the root-level `RESURRECTION.md` recovery pointer so
  backups remain useful even when DB recall is unavailable.

- Backfilled the live pgvector ANN layer to full eligible local-hash coverage,
  including missing logic-rule embeddings, and refreshed planner statistics for
  ANN, model-embedding, query-cache, semantic-edge, and neural-result tables.

- Marked low-information derived ANN rows inactive when the vector payload was
  only a standalone HTML marker or date fragment, preserving source memory while
  reducing noisy nearest-neighbor candidates.

### Verified

- Verified the live router now returns the remote Zorg folder recall hint as the
  first hit for a concrete remote script-storage query.

- Syntax-checked the changed Python scripts, applied the public-safe runtime
  writer rule SQL against local PostgreSQL-backed memory, and verified DB recall
  can retrieve the new runtime DB-only writer rule.

- Validated the canonical-rule update SQL with PostgreSQL parsing and checked
  the repository docs describe the public-safe upgrade path.

- Verified the old private-GitHub backup requirement no longer appears in
  current rule docs, templates, or schema seed text.

- Confirmed the live ANN surface has zero missing eligible local-hash rows after
  the maintenance pass.

## [v1.2.54] - 2026-05-28

### Fixed

- Repaired README LAN console screenshot references so the public README points at the checked-in public-safe image asset.
- Refreshed the changelog so the released v1.2.12 through v1.2.53 documentation catch-up is reflected in the public release index instead of remaining under Unreleased.

### Verified

- Reviewed structured DB-backed documentation/release rules before editing.
- Verified release-note coverage through docs/releases/v1.2.53.md and kept this update public-safe.

## [v1.2.53] - 2026-05-28

### Added

- Added scripted PostgreSQL memory recovery support with list, drill, and explicitly gated live restore modes.

## [v1.2.52] - 2026-05-28

### Changed

- Clarified that a verified full backup is enough precaution for pruning bad generated memory rows; do not create extra tombstones or retained audit rows solely as an added precaution.

## [v1.2.51] - 2026-05-28

### Changed

- Documented the bad generated-row quarantine and prune rule for wrong, broken, superseded, or bad-path generated memory rows.

## [v1.2.50] - 2026-05-28

### Changed

- Documented that memory health means end-to-end ingestion and recall, including recent Telegram/chat ingestion, durable operational records, absence of retired markdown memory output, and natural-language recall verification.

## [v1.2.49] - 2026-05-28

### Added

- Added a Telegram-to-PostgreSQL memory bridge and systemd user timer units for compact chat-ingest rows.

## [v1.2.48] - 2026-05-26

### Fixed

- Hardened native Linux install prerequisite repair before OpenClaw/npm work, including Node.js >= 22.19.0 validation and npm repair.

## [v1.2.47] - 2026-05-26

### Fixed

- Updated Docker gateway bootstrap so host-side TUI connections to the published gateway port work with token authentication.

## [v1.2.46] - 2026-05-25

### Changed

- Documented the additive OpenClaw branch-overlay design and repaired first-use guide formatting.

## [v1.2.45] - 2026-05-21

### Added

- Added public-safe tail-latency tuning for DB recall while preserving all source memory.

## [v1.2.44] - 2026-05-21

### Fixed

- Hardened the native Ubuntu first-run install path from live install findings.

## [v1.2.43] - 2026-05-21

### Changed

- Published accumulated public-safe recall design updates including pgvector ANN recall, real model embedding recall, continuous neural maintenance, markdown statement recall, dynamic logic-rule ranking, benchmark guidance, public-safe rule seeds, and bootstrap cleanup.

## [v1.2.42] - 2026-05-20

### Added

- Added a public-safe logic-rule seed for clean installs and upgrades.

## [v1.2.41] - 2026-05-20

### Changed

- Added lower-priority rule migration and recall-noise filtering for structured logic-rule recall.

## [v1.2.40] - 2026-05-20

### Added

- Added bounded continuous neural recall maintenance for local ANN and related recall surfaces.

## [v1.2.39] - 2026-05-18

### Added

- Added a separate host Docker Engine and Dockge manager upgrade runbook.

## [v1.2.38] - 2026-05-18

### Fixed

- Corrected Docker Compose and Dockge upgrade docs to force a clean image rebuild and verify the version inside the running container.

## [v1.2.37] - 2026-05-18

### Added

- Added the real-model embedding ANN layer and query embedding cache.

## [v1.2.36] - 2026-05-18

### Added

- Added the pgvector ANN recall layer with HNSW cosine indexing and deterministic local hash embeddings as a rebuildable bridge.

## [v1.2.35] - 2026-05-18

### Added

- Added idle bootstrap and follow-up context pruning rules for DB-backed recall sessions.

## [v1.2.34] - 2026-05-18

### Changed

- Moved Docker LAN command chat publication to LAN_CHAT_PUBLISHED_PORTS, defaulting to 8080-8180.

## [v1.2.33] - 2026-05-18

### Fixed

- Corrected release-note and base setup LAN port examples before the v1.2.34 port-range model superseded them.

## [v1.2.32] - 2026-05-18

### Added

- Added the neural recall feedback layer public-safe structural update.

## [v1.2.31] - 2026-05-18

### Changed

- Updated fresh-Ubuntu Dockge terminal fallback commands to use sudo docker compose.

## [v1.2.30] - 2026-05-18

### Changed

- Updated Standard Ubuntu upgrade docs to refresh the overlay with sudo git pull --ff-only before verification.

## [v1.2.29] - 2026-05-18

### Added

- Added absolute-beginner terminal and SSH documentation.

## [v1.2.28] - 2026-05-18

### Added

- Added first-use and LAN chat password documentation.

## [v1.2.27] - 2026-05-18

### Added

- Added existing OpenClaw overlay upgrade documentation.

## [v1.2.26] - 2026-05-18

### Changed

- Split upgrade documentation into a chooser plus separate Standard Ubuntu, Docker Compose, Dockge, and Docker run pages.

## [v1.2.25] - 2026-05-18

### Changed

- Rechecked documentation for remaining install/upgrade folder examples that implied repository- or database-named assistant folders.

## [v1.2.24] - 2026-05-18

### Changed

- Updated upgrade documentation to use assistant-named folders such as front-desk-assistant and my-ai-assistant.

## [v1.2.23] - 2026-05-18

### Changed

- Added beginner-facing labels for install folder, Dockge stack folder, container/service, container name, image, and state folder.

## [v1.2.22] - 2026-05-18

### Changed

- Finished the Dockge naming pass in active setup docs.

## [v1.2.21] - 2026-05-18

### Changed

- Replaced MemoryDB-flavored folder examples with assistant-facing install names.

## [v1.2.20] - 2026-05-18

### Changed

- Reordered install and upgrade docs so readers see native Ubuntu first, then Docker Compose, Dockge, and Docker run.

## [v1.2.19] - 2026-05-18

### Fixed

- Corrected Docker Compose TUI instructions to attach to the running OpenClaw/Zorg container with docker compose exec -it openclaw openclaw tui.

## [v1.2.18] - 2026-05-18

### Fixed

- Removed remaining incorrect Docker Compose local-mode chat guidance from current docs and release notes.

## [v1.2.17] - 2026-05-18

### Fixed

- Corrected Docker Compose Control UI and TUI documentation around discovered published ports.

## [v1.2.16] - 2026-05-18

### Fixed

- Distinguished Gateway-connected Docker TUI startup from embedded local mode and added the missing upgrade runbook.

## [v1.2.15] - 2026-05-18

### Changed

- Corrected Docker TUI startup documentation and promoted the upstream/existing-implementation-first rule into the public-safe distribution.

## [v1.2.14] - 2026-05-18

### Changed

- Caught up public package documentation after rule, recall, LAN console, recovery, and verification hardening.

## [v1.2.13] - 2026-05-15

### Changed

- Updated the LAN command console WebSocket client for OpenClaw Gateway protocol v4.

## [v1.2.12] - 2026-05-15

### Fixed

- Hardened DB-only memory recall startup when OpenClaw launches from a home-directory working directory instead of the workspace.

## [v1.2.11] - 2026-05-14

### Added

- Added the built-in LAN console (`lan-chat`) to the base repository and Docker Compose install so new deployments include a local web command chat/back channel by default.
- Added public-safe documentation for the LAN console privacy rationale, explaining why local-first agent communication reduces dependence on outside chat-provider accounts, bot surfaces, metadata, and retention boundaries.
- Added queue-driven semantic neural recall v1 structures and worker support: durable semantic work queue, tuner metadata, enqueue helper, weighted semantic nodes/edges, recall hints, and query-observation generation.
- Added public-safe recall failure benchmark methodology and a benchmark chart asset for measuring confirmed memory/recall correction incidents without publishing private transcripts or live DB rows.
- Added an AI DJ agent reporting pattern for documenting memory-backed persona, artist-research, music-news, and streaming-station behavior in public-safe reports.
- Added individual communication profile guidance so contact-specific handling rules can be represented publicly without exposing private contacts or messages.

### Changed

- Clarified that `lan-chat` is a built-in local command chat for the default install, not a separate optional add-on, and documented the maintenance responsibility to keep it available.
- Updated schema and weighted-recall docs to describe the semantic queue/worker loop as an additive, source-preserving recall layer.
- Updated setup docs so new installs understand LAN console wiring and local-first communication boundaries.

### Verified

- Verified release documentation stays public-safe and excludes private memory rows, transcripts, contacts, credentials, emails, live account data, and operator-specific infrastructure.

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
