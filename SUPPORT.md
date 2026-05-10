# Support

Start with the docs:

- [Quickstart](docs/quickstart.md)
- [Standard Ubuntu install](docs/standard-ubuntu-install.md)
- [Docker install](docs/docker-install.md)
- [Dockge install](docs/dockge-install.md)
- [Docker run one-liner](docs/docker-run.md)
- [Verification](docs/verification.md)

## Verification commands

Docker/Dockge/Docker run:

```bash
docker exec zorg-memorydb bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker exec zorg-memorydb bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker exec zorg-memorydb bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

Docker Compose/Dockge service name may be `openclaw`; in that case use:

```bash
docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
```

Expected recall mode: `database-direct-structured`.

## Issues

When opening an issue, include:

- install path used: standard Ubuntu, Docker Compose, Dockge, or Docker run
- host OS/version
- Docker/Dockge version if relevant
- command run
- exact error text
- verification command output

Do not include secrets, private memory data, email content, chat logs, cookies, or private database rows.

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

