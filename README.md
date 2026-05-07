# Zorg MemoryDB OpenClaw Build

Zorg MemoryDB is a clean OpenClaw build with DB-backed memory integrated into the normal OpenClaw home and workspace layout.

It installs and runs the latest OpenClaw package (`openclaw@latest`) with Zorg MemoryDB already sewn into startup. A fresh install should feel like starting OpenClaw from scratch: clone, start, open OpenClaw. The database is an internal implementation detail, stored inside OpenClaw's own folders, and should not require separate setup or user-facing credentials.

The public repository is sanitized. It includes structure, scripts, schema, docs, and templates only — no private rows, transcripts, account data, or operator context.

## Why Zorg MemoryDB?

Zorg MemoryDB is the OpenClaw base with a durable PostgreSQL-backed memory spine, executive-assistant operating rules, privacy-aware communication filters, adaptive recovery patterns, and public-safe templates. It is designed as a clean add-on layer so you can keep the upside of upstream OpenClaw while gaining operational continuity.

- Why install Zorg MemoryDB over plain OpenClaw? [`docs/why-zorg-memorydb.md`](docs/why-zorg-memorydb.md)

## Packages and releases

- GitHub Releases: https://github.com/StefRush2099/Zorg_MemoryDB/releases
- GHCR image: `ghcr.io/stefrush2099/zorg-memorydb`
- Release/process docs: [`docs/release-process.md`](docs/release-process.md)

Every meaningful structural/install/runtime update is committed, tagged, released, and published as a GHCR container image.

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
- PostgreSQL schema, functions, indexes, materialized views, recall tooling, and bootstrap scripts
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

Zorg MemoryDB also includes built-in executive-assistant operating rules for inbox triage, email formatting, calendar discipline, proactive follow-through, confidentiality, and revenue/time-priority filtering. See [`docs/executive-assistant-operating-rules.md`](docs/executive-assistant-operating-rules.md).

## Project files

- [`CHANGELOG.md`](CHANGELOG.md)
- [`CONTRIBUTING.md`](CONTRIBUTING.md)
- [`SECURITY.md`](SECURITY.md)
- [`SUPPORT.md`](SUPPORT.md)
- [`LICENSE`](LICENSE)
