# Zorg MemoryDB OpenClaw Template

Zorg MemoryDB is a sanitized, all-in-one OpenClaw install template for the latest Ubuntu release, currently **Ubuntu 26.04 LTS**.

It installs and runs the full latest OpenClaw package (`openclaw@latest`) with PostgreSQL-backed Zorg DB memory already installed, configured, connected, imported, refreshed, and enforced. This repository is not just a database add-on.

Fresh installs include schema and public templates only. They do **not** include live database rows, private memory, credentials, transcripts, contact data, or operator context.

## Packages and releases

- GitHub Releases: https://github.com/StefRush2099/Zorg_MemoryDB/releases
- GHCR image: `ghcr.io/stefrush2099/zorg-memorydb`
- Release/process docs: [`docs/release-process.md`](docs/release-process.md)

Every meaningful structural/install/runtime update should be committed, tagged, released, and published as a GHCR container image.

## Install paths

Choose one:

1. **Standard Ubuntu install** — native OpenClaw + local PostgreSQL on latest Ubuntu.
2. **Docker install** — one self-contained OpenClaw/Zorg container with embedded PostgreSQL, managed by Docker Compose.
3. **Dockge install** — one Dockge-managed OpenClaw/Zorg container with embedded PostgreSQL for latest Ubuntu servers.
4. **Docker run** — one-line install using the published GHCR image.

## 1. Standard Ubuntu install

Docs: [`docs/standard-ubuntu-install.md`](docs/standard-ubuntu-install.md)

```bash
curl -fsSL https://raw.githubusercontent.com/StefRush2099/Zorg_MemoryDB/main/scripts/install_standard_ubuntu.sh | bash
```

This installs Ubuntu packages, `openclaw@latest`, local PostgreSQL, the Zorg MemoryDB schema/tools, and DB-backed OpenClaw memory routing.

## 2. Docker install

Docs: [`docs/docker-install.md`](docs/docker-install.md)

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
cp .env.example .env
# edit OPENCLAW_GATEWAY_TOKEN and DB_PASSWORD in .env before real use
docker compose up -d --build
```

OpenClaw Gateway starts on port `18789` by default.

## 3. Dockge install

Docs: [`docs/dockge-install.md`](docs/dockge-install.md)

Recommended Dockge path — intentionally lowercase to match Dockge/Compose normalization and prevent a second lowercase duplicate folder:

```bash
cd /opt/stacks
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg_memorydb
sudo chown -R "$USER:$USER" /opt/stacks/zorg_memorydb
cd /opt/stacks/zorg_memorydb
cp .env.example .env
```

Then import/start `/opt/stacks/zorg_memorydb/docker-compose.yml` in Dockge with stack name `zorg_memorydb`.

## 4. Docker run one-liner

Docs: [`docs/docker-run.md`](docs/docker-run.md)

```bash
docker run -d --name zorg-memorydb --restart unless-stopped -p 18789:18789 -e OPENCLAW_GATEWAY_TOKEN=change-this-token -e DB_PASSWORD=change-this-password -v zorg_openclaw_home:/home/openclaw/.openclaw ghcr.io/stefrush2099/zorg-memorydb:latest
```

## Sudo-heavy Ubuntu systems

Some systems require sudo for clone or Docker. Use:

```bash
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg_memorydb
cd zorg_memorydb
sudo cp .env.example .env
sudo docker compose up -d --build
```

If desired afterward:

```bash
sudo chown -R "$USER:$USER" zorg_memorydb
```

## What starts in Docker/Dockge

- one `openclaw` service/container: full latest OpenClaw CLI/Gateway install with Zorg DB memory enabled
- embedded PostgreSQL server running inside that same container on `127.0.0.1`
- one persistent Docker volume for OpenClaw state/workspace and embedded PostgreSQL data
- first-run bootstrap that wires OpenClaw memory recall to the embedded PostgreSQL server before Gateway startup

## First-run behavior

When the `openclaw` container starts, `docker/entrypoint.sh` runs the complete setup:

1. uses the full latest OpenClaw CLI installed in the image
2. seeds `/home/openclaw/.openclaw/workspace` from this sanitized template repository if needed
3. creates `.venv-sqlmem`
4. writes `sql_memory_map.json`
5. starts/uses embedded PostgreSQL inside the same container
6. applies `db/schema.sql`
7. imports public/template markdown memory rules into PostgreSQL
8. refreshes recall/search materialized views
9. enforces OpenClaw built-in `memory_search` routing through Zorg DB memory
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

Docs: [`docs/sanitized-template.md`](docs/sanitized-template.md)

Included:

- full OpenClaw latest install path
- Dockerfile, Compose/Dockge stack, and GHCR package workflow
- native Ubuntu install script
- PostgreSQL schema, functions, indexes, materialized views, recall tooling, and bootstrap scripts
- public markdown templates and operating rules

Not included:

- live DB rows/dumps
- private `MEMORY.md` or `memory/*.md`
- credentials, `.env`, `sql_memory_map.json`, cookies, OAuth tokens, API keys, SSH keys, contacts, emails, transcripts, or private operator context

## Existing OpenClaw installs

The primary path is now a clean all-in-one install. If you intentionally need to attach Zorg MemoryDB to an already-installed OpenClaw workspace, the migration helper remains available:

```bash
OPENCLAW_WORKSPACE=/path/to/existing/openclaw/workspace ./scripts/upgrade_existing_openclaw.sh
```

Use that only for migration/repair. New installs should use the standard Ubuntu, Docker, or Dockge paths above.

## Core rule

Zorg MemoryDB preserves original/source memory data and improves recall additively with schema, indexes, materialized views, summaries, concepts, and weighted associations. Do not prune or delete source memory for performance.


## Project files

- [`CHANGELOG.md`](CHANGELOG.md)
- [`CONTRIBUTING.md`](CONTRIBUTING.md)
- [`SECURITY.md`](SECURITY.md)
- [`SUPPORT.md`](SUPPORT.md)
- [`LICENSE`](LICENSE)

