# Docker Compose Install: Integrated OpenClaw + Zorg MemoryDB

This path starts OpenClaw from scratch with Zorg MemoryDB already integrated.

The database is not a separate user-facing install step. It starts internally inside the OpenClaw/Zorg container and stores its data under the same folder-local OpenClaw home bind mount:

```text
./openclaw-home
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
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git my-zorg-memorydb
cd my-zorg-memorydb
cp .env.example .env
docker compose up -d --build
```

This creates `./openclaw-home` inside the current folder and keeps that install's OpenClaw state, workspace, embedded PostgreSQL data, and memory DB there. Docker Compose publishes OpenClaw on the first free host port in `OPENCLAW_GATEWAY_PUBLISHED_PORTS` — default `18789-18889`. Run `docker compose ps` after startup to see the selected external port.

Open OpenClaw on the external port shown by `docker compose ps`. The built-in LAN/local command console is published by `lan-chat-nginx` on `LAN_CHAT_HTTP_PORT`, default `http://127.0.0.1:80/`.

That is the complete start path. You should not need to manually configure a database or attach memory afterward.

## Open the OpenClaw TUI or chat inside Docker

From the same folder as `docker-compose.yml`, run the OpenClaw terminal UI through the helper CLI service:

```bash
docker compose run --rm openclaw-cli tui --local
```

Or start OpenClaw chat mode:

```bash
docker compose run --rm openclaw-cli chat
```

The `openclaw-cli` service mounts the same `./openclaw-home` folder as the running `openclaw` service, so the CLI sees the same OpenClaw home, workspace, and local configuration.

## What the stack includes

- one `openclaw` Compose service
- one optional `openclaw-cli` Compose helper service for `tui` and `chat`
- one built-in `lan-chat` local command console service
- one `lan-chat-nginx` front door publishing the console on the LAN
- full latest OpenClaw install
- internal PostgreSQL running inside the same OpenClaw/Zorg container
- Zorg MemoryDB schema, scripts, config, imports, materialized views, and DB-backed recall enforcement
- one folder-local `./openclaw-home` bind mount containing OpenClaw state/workspace and internal memory data under `/home/openclaw/.openclaw` inside the container

## Verify

```bash
docker compose ps
docker compose logs -f openclaw

docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
curl -fsS http://127.0.0.1:${LAN_CHAT_HTTP_PORT:-80}/ | grep -i '<title>'
```

Expected recall mode: `database-direct-structured`.

## Upgrade

```bash
git pull
docker compose up -d --build
```

This rebuilds the container while reusing the same folder-local `./openclaw-home` state.

The template remains sanitized. Runtime memory data lives only in the local OpenClaw volume and is not committed to GitHub.

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

<!-- GO_ONLY_APPROVAL_RULE -->
## GO-Only Approval Rule

When Stefan gives a command that requires confirmation before execution, ask only for `GO`. Do not invent longer approval phrases, magic words, task-specific confirmations, or exact response strings such as `GO REIP ...`, `GO SCORCHED ...`, or any other expanded form. Stefan decides how to respond; the assistant may request only the simple approval token `GO`.

If the requested action is unsafe, ambiguous, destructive, externally risky, or missing a necessary decision, explain the blocker or the exact intended change briefly, then end with only `GO` as the approval request when approval is the only thing needed. Never require Stefan to repeat the task, include extra words, or match an assistant-authored phrase.
<!-- /GO_ONLY_APPROVAL_RULE -->

<!-- SAME_DAY_NEWS_FRESHNESS_RULE -->
## Same-Day News Freshness Rule

When writing multiple news articles or public reports on the same day, do not repeat the same information from article to article. Adjacent or continuing stories may reference earlier context only briefly when necessary, but each article must add fresh facts, new framing, new implications, new examples, or a clearly advanced continuation that was not already covered in earlier same-day articles.

Before drafting or publishing a new article, review the same-day feed/archive and compare titles, summaries, body claims, examples, and links. If information has already been used that day, either omit it, compress it to a short bridge, or explicitly advance it with new developments. Maintain editorial continuity without recycling paragraphs, talking points, examples, or conclusions.

The assistant owns the full article set and must keep the day’s coverage fresh, non-repetitive, and additive.
<!-- /SAME_DAY_NEWS_FRESHNESS_RULE -->
