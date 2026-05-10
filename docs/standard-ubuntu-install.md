# Standard Ubuntu Install

This path installs OpenClaw natively on Ubuntu and wires Zorg MemoryDB into the OpenClaw workspace during first run.

## One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/StefRush2099/Zorg_MemoryDB/main/scripts/install_standard_ubuntu.sh | bash
```

What it does:

1. installs Ubuntu packages needed for OpenClaw and local memory runtime
2. installs `openclaw@latest`
3. clones `Zorg_MemoryDB` into `~/Zorg_MemoryDB`
4. starts local PostgreSQL
5. creates the local OpenClaw memory role/database with local trust access
6. writes `sql_memory_map.json` into the OpenClaw workspace
7. applies the Zorg MemoryDB schema and recall surfaces
8. starts OpenClaw with memory already wired

## Start OpenClaw after install

```bash
cd ~/Zorg_MemoryDB
source .env.native
OPENCLAW_WORKSPACE=$PWD SQL_MEMORY_MAP=$PWD/sql_memory_map.json openclaw gateway run --allow-unconfigured --bind "$OPENCLAW_GATEWAY_BIND" --port "$OPENCLAW_GATEWAY_PORT" --auth "$OPENCLAW_GATEWAY_AUTH"
```

## Verify

```bash
cd ~/Zorg_MemoryDB
.venv-sqlmem/bin/python scripts/memory_sql_tool.py tables
.venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5
```

Expected recall mode: `database-direct-structured`.

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

