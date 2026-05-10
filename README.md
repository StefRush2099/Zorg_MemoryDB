# Zorg MemoryDB OpenClaw Build

Zorg MemoryDB is a clean OpenClaw build with DB-backed memory integrated into the normal OpenClaw home and workspace layout.

It installs and runs the latest OpenClaw package (`openclaw@latest`) with Zorg MemoryDB already sewn into startup. A fresh install should feel like starting OpenClaw from scratch: clone, start, open OpenClaw. The database is an internal implementation detail, stored inside OpenClaw's own folders, and should not require separate setup or user-facing credentials.

The public repository is sanitized. It includes structure, scripts, schema, docs, and templates only — no private rows, transcripts, account data, or operator context.

## Why Zorg MemoryDB?

Zorg MemoryDB is the OpenClaw base with a durable PostgreSQL-backed memory spine, structured operating rules, privacy-aware communication filters, adaptive recovery patterns, automatic DB-only recall repair, private/off-host backup guidance, and public-safe templates. It is designed as a clean add-on layer so you can keep the upside of upstream OpenClaw while gaining operational continuity.

- Why install Zorg MemoryDB over plain OpenClaw? [`docs/why-zorg-memorydb.md`](docs/why-zorg-memorydb.md)
- Before you get started: [`docs/before-you-get-started.md`](docs/before-you-get-started.md)
- Recommended baseline for a fully useful assistant install: [`docs/base-setup.md`](docs/base-setup.md)
- How docs/releases stay current: [`docs/documentation-maintenance.md`](docs/documentation-maintenance.md)

## Packages and releases

- GitHub Releases: https://github.com/StefRush2099/Zorg_MemoryDB/releases
- GHCR image: `ghcr.io/stefrush2099/zorg-memorydb`
- Release/process docs: [`docs/release-process.md`](docs/release-process.md)

Every meaningful structural/install/runtime update should be documented, committed, tagged, released, and published as a GHCR container image so users can see what changed.

## Before you get started

Before installing, collect the model-provider API key, messaging token, email OAuth/app credentials, GitHub/private-backup access, and hosting details for the path you plan to use. See [`docs/before-you-get-started.md`](docs/before-you-get-started.md).

## Install paths

Choose one:

1. **Docker run** — simplest packaged OpenClaw start.
2. **Docker Compose** — clone the repo and start the integrated OpenClaw build.
3. **Dockge** — Dockge-managed stack using the lowercase `zorg_memorydb` folder.
4. **Standard Ubuntu** — native OpenClaw + local integrated memory runtime.

## 1. Docker run

```bash
docker run -d --name zorg-memorydb --restart unless-stopped -p 18789:18789 -v zorg_openclaw_home:/home/openclaw/.openclaw ghcr.io/stefrush2099/zorg-memorydb:latest
```

Open OpenClaw on port `18789`.

Docs: [`docs/docker-run.md`](docs/docker-run.md)

## 2. Docker Compose

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg_memorydb
cd zorg_memorydb
cp .env.example .env
docker compose up -d --build
```

Open OpenClaw on port `18789`.

Docs: [`docs/docker-install.md`](docs/docker-install.md)

## 3. Dockge

Use the lowercase folder from the beginning. Dockge and Compose normalize stack names to lowercase, so this avoids duplicate uppercase/lowercase folders.

```bash
cd /opt/stacks
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg_memorydb
sudo chown -R "$USER:$USER" /opt/stacks/zorg_memorydb
cd /opt/stacks/zorg_memorydb
cp .env.example .env
```

Then import/start `/opt/stacks/zorg_memorydb/docker-compose.yml` in Dockge with stack name `zorg_memorydb`.

Docs: [`docs/dockge-install.md`](docs/dockge-install.md)

## 4. Standard Ubuntu

```bash
curl -fsSL https://raw.githubusercontent.com/StefRush2099/Zorg_MemoryDB/main/scripts/install_standard_ubuntu.sh | bash
```

Docs: [`docs/standard-ubuntu-install.md`](docs/standard-ubuntu-install.md)

## Recommended base setup

A fully useful OpenClaw + Zorg MemoryDB install should have more than the memory container alone:

- a fast instant messaging control channel such as Telegram, WhatsApp, Signal, Discord, or Slack
- a dedicated assistant email account used as the public-facing executive-assistant identity, so routine mail is filtered through the agent instead of the operator's private address
- optional, separately governed access to the operator's personal email for triage/search/drafting
- a private GitHub repo or other private off-host target for PostgreSQL memory backups
- a Cloudflare Tunnel/connector so Zorg can publish operator-approved web URLs without exposing origin services directly
- Dockerized services on the same host where practical, with Dockge as the recommended web UI for visibility and stop/start control

See [`docs/base-setup.md`](docs/base-setup.md).

## What starts in Docker/Dockge

- one OpenClaw/Zorg container
- latest OpenClaw CLI/Gateway installed in the image
- internal PostgreSQL running only inside the same container
- OpenClaw state, workspace, and memory data under `/home/openclaw/.openclaw`
- first-run bootstrap that wires memory recall before OpenClaw Gateway starts

## First-run behavior

When the container starts, `docker/entrypoint.sh`:

1. starts internal PostgreSQL inside the OpenClaw/Zorg container
2. seeds `/home/openclaw/.openclaw/workspace` from this sanitized template if needed
3. creates `.venv-sqlmem`
4. writes `sql_memory_map.json` into the OpenClaw workspace
5. applies `db/schema.sql`
6. archives any legacy retired `memory/` directory into DB if present
7. imports public template/rule markdown
8. refreshes recall/search surfaces
9. enforces OpenClaw built-in `memory_search` routing through Zorg MemoryDB
10. starts `openclaw gateway run`

## Verify

```bash
docker compose ps
docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

Expected recall mode: `database-direct-structured`.

## Sanitized full template

Included:

- full OpenClaw latest install/start path
- Dockerfile, Compose/Dockge stack, and GHCR package workflow
- native Ubuntu install script
- PostgreSQL schema, functions, indexes, materialized views, structured logic rules, recall tooling, backup/auto-heal helpers, and bootstrap scripts
- public markdown templates and operating rules

Not included:

- live DB rows/dumps
- private `MEMORY.md` content or private legacy `memory/*.md` contents
- account data, cookies, OAuth material, API keys, SSH keys, contacts, emails, transcripts, or private operator context

## Existing OpenClaw installs

The primary path is a clean integrated OpenClaw build. If you intentionally need to attach Zorg MemoryDB to an already-installed OpenClaw workspace, the migration helper remains available:

```bash
OPENCLAW_WORKSPACE=/path/to/existing/openclaw/workspace ./scripts/upgrade_existing_openclaw.sh
```

Use that only for migration/repair. New installs should use Docker run, Docker Compose, Dockge, or standard Ubuntu.

## Database recovery

Zorg MemoryDB includes a hard database backup/repair/recovery rule: backups should live in predictable local locations, safe repair is attempted first, backup candidates are tested if repair fails, and recovery is not complete until DB health/recall tests pass. See [`docs/database-recovery.md`](docs/database-recovery.md).

## Core rule

Zorg MemoryDB preserves original/source memory data and improves recall additively with schema, indexes, materialized views, summaries, concepts, and weighted associations. Do not prune or delete source memory for performance.

## Executive assistant behavior

Zorg MemoryDB also includes built-in executive-assistant operating rules for inbox triage, email formatting, calendar discipline, proactive follow-through, confidentiality, and revenue/time-priority filtering. Current public-safe rules emphasize LLM-governed operation: scheduled triggers should queue model judgment, not hide policy in scripts; duplicate meetings should be updated rather than recreated; and paired publishing should verify exact article anchors before posting short-form links. See [`docs/executive-assistant-operating-rules.md`](docs/executive-assistant-operating-rules.md).

## Project files

- [`CHANGELOG.md`](CHANGELOG.md)
- [`CONTRIBUTING.md`](CONTRIBUTING.md)
- [`SECURITY.md`](SECURITY.md)
- [`SUPPORT.md`](SUPPORT.md)
- [`LICENSE`](LICENSE)

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

