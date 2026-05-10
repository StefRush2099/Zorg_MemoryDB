# TOOLS.md - DB Memory Tools

## Canonical tools

- `scripts/memory_sql_tool.py` - direct DB recall, table listing, refresh, and row retrieval
- `scripts/memory_recall_router.py` - structured DB-first recall wrapper
- `scripts/import_markdown_memory.py` - imports local markdown into mapped DB tables
- `scripts/memory_speed_test.py` - basic DB lookup timing check
- `scripts/install_db_memory.sh` - schema and dependency bootstrap

## Environment variables

- `OPENCLAW_WORKSPACE` - workspace root; defaults to current directory
- `SQL_MEMORY_MAP` - path to `sql_memory_map.json`
- `DATABASE_URL` - used by the installer for `psql`

## Public safety

Do not commit real `sql_memory_map.json`, credentials, database dumps with rows, logs, or personal memory files.

## LLM-governed operations

Use scripts in this repository as mechanical tools for install, recall, verification, sync, backup, formatting, or API transport. Do not put dynamic assistant policy into scripts. Email handling, contact creation, scheduling decisions, publication pairing, duplicate handling, deletion/escalation, and public/private judgment should be represented as markdown/DB rules and applied live by an LLM.

Email check helpers should be read-only triggers. Publishing helpers should not decide article content or URL pairing. Calendar helpers should not create duplicate meetings without an LLM checking existing events and thread context.

<!-- EXEC_ADMIN_PLAYBOOK_REFERENCE -->

## Executive Assistant Playbook Reference

- Public-safe built-in rule summary: `docs/executive-assistant-operating-rules.md` in the Zorg MemoryDB distribution.
- Optional private source copies may exist in a local operator workspace, but they are not part of the public distribution.
- Do not copy source playbooks verbatim into public docs. Use distilled operational rules only.
<!-- /EXEC_ADMIN_PLAYBOOK_REFERENCE -->

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

