# Docker Compose Install: Integrated OpenClaw + Zorg MemoryDB

This path starts OpenClaw from scratch with Zorg MemoryDB already integrated.

The database is not a separate user-facing install step. It starts internally inside the OpenClaw/Zorg container and stores its data under the same OpenClaw home volume:

```text
/home/openclaw/.openclaw
```

## Install Docker on Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git docker.io docker-compose-plugin
sudo systemctl enable --now docker
```

If your user is not in the Docker group, either use `sudo docker ...` or add yourself and log out/in:

```bash
sudo usermod -aG docker "$USER"
```

## Start OpenClaw

```bash
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg_memorydb
cd zorg_memorydb
cp .env.example .env
docker compose up -d --build
```

Open OpenClaw on port `18789`.

That is the complete start path. You should not need to manually configure a database or attach memory afterward.

## What the stack includes

- one `openclaw` Compose service
- full latest OpenClaw install
- internal PostgreSQL running inside the same OpenClaw/Zorg container
- Zorg MemoryDB schema, scripts, config, imports, materialized views, and DB-backed recall enforcement
- one persistent `zorg_openclaw_home` volume containing OpenClaw state/workspace and internal memory data under `/home/openclaw/.openclaw`

## Verify

```bash
docker compose ps
docker compose logs -f openclaw

docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

Expected recall mode: `database-direct-structured`.

## Upgrade

```bash
git pull
docker compose up -d --build
```

The template remains sanitized. Runtime memory data lives only in the local OpenClaw volume and is not committed to GitHub.

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

