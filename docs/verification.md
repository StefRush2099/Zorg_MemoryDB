# Verification

## Integrated Docker smoke test

From the repository root:

```bash
cp .env.example .env
docker compose config >/tmp/zorg-memorydb-compose.yml
docker compose build openclaw
docker compose up -d
docker compose ps
docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

Expected:

- one `openclaw` service/container is running
- internal PostgreSQL accepts local connections inside the same container
- `memory_sql_tool.py tables` lists Zorg memory tables
- `memory_recall_router.py` returns JSON using DB-backed recall
- OpenClaw Gateway logs show startup after memory bootstrap

## Shell/static checks

```bash
bash -n scripts/*.sh docker/entrypoint.sh
python3 -m py_compile scripts/*.py
docker compose config >/tmp/zorg-memorydb-compose.yml
```

## Schema smoke test

```bash
createdb openclaw_memory_test
psql -d openclaw_memory_test -v ON_ERROR_STOP=1 -f db/schema.sql
```

## Tool smoke test outside Docker

```bash
cp config/sql_memory_map.example.json sql_memory_map.json
python scripts/memory_sql_tool.py tables
python scripts/memory_sql_tool.py refresh
python scripts/memory_recall_router.py "project runbook" --limit 5
python scripts/memory_speed_test.py
```

`memory_speed_test.py` loads a benchmark corpus from `DB_BENCHMARK_QUERIES`, then `db_benchmark_queries.json` in the OpenClaw workspace, and finally `config/db_benchmark_queries.example.json`.

Useful knobs:

```bash
MEMORY_SPEED_RUNS=20 python scripts/memory_speed_test.py
DB_BENCHMARK_QUERIES=/path/to/db_benchmark_queries.json python scripts/memory_speed_test.py
```

## Built-in memory_search routing smoke test

Run this from an OpenClaw workspace after setup or after an OpenClaw update:

```bash
OPENCLAW_WORKSPACE=/path/to/openclaw/workspace python scripts/enforce_db_memory_search.py
```

Expected result: JSON with `"ok": true`. If OpenClaw runtime files are present, the script reports them under `runtimeFiles` and patches default memory recall to route through Zorg MemoryDB via `memory_recall_router.py`.

## Private-data scan before publishing

```bash
grep -RInE 'BEGIN (RSA|OPENSSH|PRIVATE)|cookie|oauth|credential|private_key' . \
  --exclude-dir=.git \
  --exclude='README.md' \
  --exclude='verification.md'
```

Review every match before publishing. Do not add live memory exports, database dumps, account data, contacts, or private transcripts to this repository.

## Database recovery verification

For DB corruption or inaccessible recall, follow [`docs/database-recovery.md`](database-recovery.md): safe repair first, backup recovery if repair fails, then health/recall tests. Do not claim recovery until PostgreSQL reachability, table listing, materialized-view refresh, and recall-router checks pass.

## Contacts CRM Verification

For installs with authorized Google People/Contacts OAuth scope:

```bash
python scripts/sync_google_contacts_to_memory_db.py
python scripts/memory_sql_tool.py search "contact email" --table all --limit 5
```

Expected result: the sync script prints counts only, `zorg_contact_sync_runs` records an `ok` run, `zorg_contacts_crm` contains contact rows, and DB-backed recall can return source type `contact`. Do not paste live contact output into public tickets or docs.


## Contacts CRM Dedupe Verification

After a contacts sync, verify counts only:

```sql
select count(*) from zorg_contacts_crm where active;
select count(*) from zorg_contact_canonical_crm where active;
select count(*) from zorg_contact_dedupe_flags where review_status = 'open';
select source_table, count(*) from zorg_memory_search_mv where source_table = 'contact' group by source_table;
```

Expected: raw contacts are preserved, canonical contacts are fewer than or equal to raw contacts, review flags capture ambiguous/name-only collisions, and memory search rows use the canonical contact count. Do not paste live contact names, emails, or phones into public verification logs.


## Recursive Logic Verification

After applying recursive-logic schema, verify structure and recall without exposing private context:

```sql
select count(*) from zorg_logic_rules where active;
select * from zorg_get_logic_context('duplicate', 5);
```

Expected: active logic rules exist, logic recall can return proactive quality-control rules, and public documentation contains only sanitized rule summaries.


## DB-only clean-install configuration

Verify a clean install writes DB-only memory settings into OpenClaw config:

```bash
docker compose exec openclaw python3 - <<'PY'
import json, pathlib
for path in [pathlib.Path('/home/openclaw/.openclaw/openclaw.json'), pathlib.Path('/home/openclaw/.openclaw/.openclaw/openclaw.json')]:
    cfg=json.loads(path.read_text())
    ms=cfg.get('agents',{}).get('defaults',{}).get('memorySearch',{})
    assert ms.get('enabled') is True
    assert ms.get('fallback') == 'none'
print('DB-only memory config verified')
PY
```

No `memory/` directory should remain after first run:

```bash
docker compose exec openclaw test ! -d /home/openclaw/.openclaw/workspace/memory
```

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

