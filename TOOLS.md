# TOOLS.md - DB Memory Tools

## Backend Memory Repair Supremacy Rule

Backend Zorg MemoryDB health is Priority 0 above approval gates, normal workflow, conversation, external tasks, code work, and reporting. If DB memory, recall routing, timing enforcement, SQL connectivity, materialized recall views, memory benchmark tooling, or DB-only recall surfaces are broken, degraded, timing out, returning `database-unavailable`, using retired flat-file memory, or otherwise below fully functional status, the assistant must repair the exact backend memory failure immediately without asking Stefan for approval. The only permitted pre-repair action is DB-backed recall/health inspection needed to identify the fault. This exception applies only to restoring backend memory function and its rule surfaces; unrelated auth, routing, UI, external communication, or non-memory changes still follow their own approval rules.

## Clean-install DB-only memory hard stop

A clean Zorg MemoryDB install must never recreate `memory/` markdown files as durable memory. The only durable memory backend is PostgreSQL through Zorg MemoryDB. Core markdown files such as `AGENTS.md`, `MEMORY.md`, `SOUL.md`, `USER.md`, `TOOLS.md`, `IDENTITY.md`, and `HEARTBEAT.md` are bootstrap/rule sources only; they are imported into the database and are not a flat-file memory fallback. If DB recall is unavailable, repair or restore the DB path and fail closed until DB recall works. Do not create `memory/YYYY-MM-DD.md`, `memory/projects/*.md`, `memory/people-research/*.md`, `memory/*.json`, or any other `memory/` subdirectory file. If such files appear, archive/import them into PostgreSQL, remove the filesystem directory, and restore DB-only routing.


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

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. Memory has priority over fresh reasoning because current context is often only the symptom; durable memory contains the prior working path that explains what broke.

For an existing system, job, setting, integration, or workflow failure, assume the process previously had a function and a working path. A failure state is evidence that something drifted, broke, or was forgotten, not evidence that the process never existed. The assistant built or configured this environment and is responsible for recovering its own prior work by finding the stored history, path, prompt, script, credential location, job payload, or runbook that made it work before.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour backend DB memory and related live state deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, scripts, credentials-path references, and live configuration clues until the relevant context is found or genuinely exhausted. A fast or shallow miss is never evidence of absence.

If the first deep search finds no useful result for an existing problem, search the entire memory again with a different framing. Use past examples where memory was missed as query guidance: ask what previously worked, what job/process created the surface, what helper or credential path was used, what repair fixed a similar failure, and what rule was violated by stopping early. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

<!-- LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->
## LLM-Governed Performance Tuning Rule

Database and memory performance tuning must be governed by live LLM judgment, not hidden script policy. Tuning work starts with a natural-language hypothesis formed from current system evidence and internet/authoritative research. If research gives a credible reason to believe a database design, recall-path, materialized-view, vector/neural association, or query-structure change will improve performance, the LLM must run side-by-side before/after measurements on representative queries before claiming success.

If research does not support a design change, move to raw additive performance work: indexes, query-path improvements, materialized/search-support views, relationships, recall hints, semantic edges, weighted connections, token/FTS/trigram support, and other non-destructive logic that brings query times down while preserving all source memory. No original memory data may be pruned, deleted, truncated, compacted away, or aged out for speed.

Every meaningful tuning change must record the research basis, before/after benchmark results, changed structures, rollback path, and follow-up indexing/hinting implications in durable memory and public-safe docs when structural behavior changes.
<!-- /LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->

<!-- OPENCLAW_HOST_IDENTITY_RULE -->
## OpenClaw Host Identity Rule

This installation is the local OpenClaw host named openclaw at LAN IP 10.7.69.200. Treat 10.7.69.200 as this system's own address unless live network checks prove otherwise.

Do not confuse this host with Vorg (10.7.69.44), the shared-folder source host (10.7.69.46), or the jump/root host (10.7.69.104). Before service, routing, recovery, LAN command, memory, or backup work, verify whether the task targets local OpenClaw (openclaw / 10.7.69.200) or a separate named system.
<!-- /OPENCLAW_HOST_IDENTITY_RULE -->

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
