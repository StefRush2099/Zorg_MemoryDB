# Dockge Install: Integrated OpenClaw + Zorg MemoryDB

Dockge should manage **one OpenClaw/Zorg stack per install folder**. Zorg MemoryDB runs inside the OpenClaw/Zorg container and persists under that same stack folder in `./openclaw-home`.

## Folder-local rule

This stack is now folder-local by default:

- no top-level hard-coded Compose `name`
- no hard-coded `COMPOSE_PROJECT_NAME` in `.env.example`
- no global named Docker volume for OpenClaw state
- persistent state lives under the folder that contains `docker-compose.yml`

You may clone/import the repo into any folder name. If multiple installs run on the same Docker host, Docker Compose selects the first free external port from `OPENCLAW_GATEWAY_PUBLISHED_PORTS` — default `18789-18889`.

## Recommended Dockge start path

On the Ubuntu Dockge host, choose any stack folder name you want:

```bash
sudo apt-get update
sudo apt-get install -y git docker.io docker-compose-plugin
sudo systemctl enable --now docker

cd /opt/stacks
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git my-zorg-memorydb
sudo chown -R "$USER:$USER" /opt/stacks/my-zorg-memorydb
cd /opt/stacks/my-zorg-memorydb
cp .env.example .env
```

Then in Dockge:

1. Create/import one stack using the same folder.
2. Use that folder's `docker-compose.yml` as the stack Compose file.
3. Start/stop/update it only from Dockge.

Open OpenClaw on the external port shown by `docker compose ps`. The default range starts at `18789`.

## Open the OpenClaw TUI or chat

From the stack folder on the Docker host, run:

```bash
docker compose run --rm openclaw-cli tui --local
```

Or start OpenClaw chat mode:

```bash
docker compose run --rm openclaw-cli chat
```

The helper service uses the same `./openclaw-home` folder as the main OpenClaw/Zorg container.

## Multiple installs on the same host

For two installs, use two folders. Both can keep the default external port range; Docker will assign the first available port in the range:

```bash
cd /opt/stacks
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg-memory-a
git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg-memory-b

cd /opt/stacks/zorg-memory-a
cp .env.example .env

cd /opt/stacks/zorg-memory-b
cp .env.example .env
```

Each folder gets its own `openclaw-home/` subfolder; Docker must not create state in a shared default folder. Use `docker compose ps` in each folder to see which external port was selected.

## Paste-only Dockge stack

If you paste a stack directly into Dockge, keep the bind mount relative so state stays under the stack folder Dockge creates:

```yaml
services:
  openclaw:
    image: ghcr.io/stefrush2099/zorg-memorydb:latest
    restart: unless-stopped
    environment:
      OPENCLAW_HOME: /home/openclaw/.openclaw
      OPENCLAW_WORKSPACE: /home/openclaw/.openclaw/workspace
      PGDATA: /home/openclaw/.openclaw/postgresql/data
      DB_HOST: 127.0.0.1
      DB_PORT: 5432
      DB_NAME: openclaw_memory
      DB_USER: openclaw_memory
      OPENCLAW_GATEWAY_PORT: 18789
      OPENCLAW_GATEWAY_BIND: lan
      OPENCLAW_GATEWAY_AUTH: trusted-proxy
    ports:
      - "18789-18889:18789"
    volumes:
      - ./openclaw-home:/home/openclaw/.openclaw
```

## Verify from Dockge

Use the Dockge terminal/console or SSH into the Ubuntu host:

```bash
cd /opt/stacks/my-zorg-memorydb
docker compose ps
docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

Expected recall mode: `database-direct-structured`.

## Cleanup for older duplicate installs

If an earlier Dockge attempt created duplicate unmanaged containers or folders, stop the Dockge stack first, then inspect Docker for leftovers:

```bash
docker ps -a --filter name=zorg --filter name=openclaw
```

Remove only old duplicate/unmanaged containers after confirming Dockge is stopped and the container is not the active Dockge-managed one:

```bash
docker rm <old-container-name-or-id>
```

Do not delete `openclaw-home/` folders unless you intentionally want to discard that install's local OpenClaw state and memory data.

## Recommended companion stacks

For a fully useful assistant install, Dockge should also make the surrounding assistant infrastructure visible. Consider adding companion stacks or services for:

- `cloudflared` for Cloudflare Tunnel publishing/access routes
- a website/report publishing service if Zorg will publish pages
- any local support services the assistant needs

Keep secrets in private `.env` files or secret stores, not in the public repo. See [`base-setup.md`](base-setup.md) for the recommended baseline.

## Notes

- Use any install folder name; keep generated state in that folder's `openclaw-home/` subfolder.
- If multiple copies run at the same time, Docker selects the first free external port from `OPENCLAW_GATEWAY_PUBLISHED_PORTS`; use `docker compose ps` to see the selected port.
- Do not paste private memory rows or private operator context into the public repo.
- The repo remains a sanitized OpenClaw build template.

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

