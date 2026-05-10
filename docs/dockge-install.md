# Dockge Install: Integrated OpenClaw + Zorg MemoryDB

Dockge should manage **one OpenClaw/Zorg stack**. The stack starts one OpenClaw/Zorg container. Zorg MemoryDB runs internally inside that same container and stores its data inside the normal OpenClaw home volume.

## Important: use the lowercase Dockge folder

Dockge and Docker Compose normalize stack/project names to lowercase. If the repo is cloned as `/opt/stacks/Zorg_MemoryDB` and imported as `Zorg_MemoryDB`, Dockge may create a second lowercase folder such as `/opt/stacks/zorg_memorydb`.

To keep the install confined to the same subfolder it starts in, use this lowercase folder and stack name from the beginning:

```text
/opt/stacks/zorg_memorydb
```

## Recommended Dockge start path

On the Ubuntu Dockge host:

```bash
sudo apt-get update
sudo apt-get install -y git docker.io docker-compose-plugin
sudo systemctl enable --now docker

cd /opt/stacks
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg_memorydb
sudo chown -R "$USER:$USER" /opt/stacks/zorg_memorydb
cd /opt/stacks/zorg_memorydb
cp .env.example .env
```

Then in Dockge:

1. Create/import one stack named `zorg_memorydb`.
2. Use `/opt/stacks/zorg_memorydb/docker-compose.yml` as the stack Compose file.
3. Start/stop/update it only from Dockge.

Open OpenClaw on port `18789`.

## If you already have duplicate folders

If Dockge created both uppercase and lowercase folders, keep the lowercase Dockge-managed folder and move any edited `.env` values into it:

```bash
sudo mkdir -p /opt/stacks/zorg_memorydb
sudo rsync -a --exclude .git /opt/stacks/Zorg_MemoryDB/ /opt/stacks/zorg_memorydb/
sudo chown -R "$USER:$USER" /opt/stacks/zorg_memorydb
```

Then point Dockge to `/opt/stacks/zorg_memorydb/docker-compose.yml` and use stack name `zorg_memorydb`.

After confirming Dockge is using `/opt/stacks/zorg_memorydb`, the old uppercase folder is only a stale source checkout. Do not remove it until you confirm there is no unique `.env` or local edit you still need.

## Paste-only Dockge stack

If you prefer to paste a stack directly into Dockge, name the stack `zorg_memorydb` and use this Compose file:

```yaml
name: zorg_memorydb

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
      - "18789:18789"
    volumes:
      - zorg_openclaw_home:/home/openclaw/.openclaw

volumes:
  zorg_openclaw_home:
```

## Verify from Dockge

Use the Dockge terminal/console or SSH into the Ubuntu host:

```bash
cd /opt/stacks/zorg_memorydb
docker compose ps
docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

Expected recall mode: `database-direct-structured`.

## Cleanup for older duplicate installs

If an earlier Dockge attempt created duplicate unmanaged containers, stop the Dockge stack first, then inspect Docker for leftovers:

```bash
docker ps -a --filter name=zorg --filter name=openclaw
```

Remove only old duplicate/unmanaged containers after confirming Dockge is stopped and the container is not the active Dockge-managed one:

```bash
docker rm <old-container-name-or-id>
```

Do not delete volumes unless you intentionally want to discard that install's local OpenClaw state and memory data.

## Recommended companion stacks

For a fully useful assistant install, Dockge should also make the surrounding assistant infrastructure visible. Consider adding companion stacks or services for:

- `cloudflared` for Cloudflare Tunnel publishing/access routes
- a website/report publishing service if Zorg will publish pages
- any local support services the assistant needs

Keep secrets in private `.env` files or secret stores, not in the public repo. See [`base-setup.md`](base-setup.md) for the recommended baseline.

## Notes

- Use lowercase `zorg_memorydb` for the Dockge folder, Dockge stack name, and Compose project name.
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

