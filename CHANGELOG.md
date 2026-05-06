# Changelog

All meaningful changes to this project are documented here and released with a GitHub Release plus GHCR container image.

## [Unreleased]

### Added
- Added business-contact failure persistence guidance: use structured memory, CRM records, and official public sources to find safe alternate contact paths before escalation.
- Added private Contacts CRM memory schema and Google Contacts sync support so authorized installs can preserve contacts in DB-backed recall without publishing live contact data.
- Added bounced-email and known-bad-address handling rules: report unread only, mark reported mail read, delete known-bad bounce notices, recover corrected addresses, resend intended messages, and apologize for wrong-address delays.
- Added operator prosperity and continuity purpose guidance, framing memory/rules/monitoring as serving operator safety, reputation, time, and leverage without creating independent assistant self-preservation goals.
- Added database backup, repair, and recovery hard rule plus `docs/database-recovery.md`, documenting predictable backup paths, repair-first handling, backup candidate testing, restore promotion, and post-recovery DB/recall verification.
- Added `docs/why-zorg-memorydb.md`, a detailed evolving public pitch explaining why Zorg MemoryDB is a clean additive OpenClaw memory layer, how it preserves upstream update paths, and what operational advantages database-backed recall provides.
- Added email-address failure recovery guidance: search/validate corrected contact details, send confirmation, resend intended messages, and apologize for wrong-address delays before escalating uncertain cases.
- Added adaptive agent terminology guidance to avoid static workflow framing for dynamic agent behavior and keep terminology exploratory until a better industry or coined term emerges.

- Added the Executive Assistant Privacy / Communication Filter rule to docs, templates, and migration append rules. Outward communication is shaped by safe public facts, relationship context, and private operator handling instructions without exposing private strategy.
- Clarified that operator-provided information is private by default, uncertain disclosure requires clarification, and recipients should not be told they are being filtered through private context.

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
