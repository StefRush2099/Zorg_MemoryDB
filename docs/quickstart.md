# Quickstart: OpenClaw + Zorg MemoryDB

This repo starts OpenClaw with Zorg MemoryDB already integrated. The memory database is internal to the OpenClaw runtime and stored under OpenClaw's own home/workspace folders.

## Option 1: Docker run

```bash
docker run -d --name zorg-memorydb --restart unless-stopped -p 18789:18789 -v zorg_openclaw_home:/home/openclaw/.openclaw ghcr.io/stefrush2099/zorg-memorydb:latest
```

Open OpenClaw on port `18789`.

## Option 2: Docker Compose

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg_memorydb
cd zorg_memorydb
cp .env.example .env
docker compose up -d --build
```

Open OpenClaw on port `18789`.

## Option 3: Dockge

Use the lowercase target folder `zorg_memorydb` so Dockge does not create a second normalized folder.

```bash
cd /opt/stacks
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg_memorydb
sudo chown -R "$USER:$USER" /opt/stacks/zorg_memorydb
cd /opt/stacks/zorg_memorydb
cp .env.example .env
```

Then import `/opt/stacks/zorg_memorydb/docker-compose.yml` in Dockge with stack name `zorg_memorydb`.

## Option 4: Standard Ubuntu

```bash
curl -fsSL https://raw.githubusercontent.com/StefRush2099/Zorg_MemoryDB/main/scripts/install_standard_ubuntu.sh | bash
```

## Recommended next connections

After the container is running, make the assistant practically useful by connecting the baseline surfaces described in [`base-setup.md`](base-setup.md):

1. Connect a direct instant messaging channel for fast operator control.
2. Create a dedicated assistant email account as the public-facing executive-assistant identity.
3. Optionally grant carefully governed personal-email access for triage/search/drafting.
4. Configure private/off-host PostgreSQL backup storage, such as a private GitHub repo.
5. Add a Cloudflare Tunnel connector in Docker/Dockge for operator-approved remote URLs.
6. Keep the services visible in Dockge where possible.

## Verify

Docker/Dockge:

```bash
docker compose ps
docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "openclaw database memory" --limit 5'
```

Native:

```bash
cd ~/Zorg_MemoryDB
.venv-sqlmem/bin/python scripts/memory_sql_tool.py tables
.venv-sqlmem/bin/python scripts/memory_recall_router.py "openclaw database memory" --limit 5
```

Expected recall mode: `database-direct-structured`.

## What you should not need to do

You should not need to manually connect a database to OpenClaw. Each install path wires memory during startup/bootstrap.

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

