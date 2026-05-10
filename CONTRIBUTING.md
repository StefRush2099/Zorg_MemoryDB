# Contributing

Thanks for improving `Zorg_MemoryDB`.

## Project goals

This repository is a sanitized, production-oriented OpenClaw + Zorg DB memory install template. It should make the install reproducible without exposing private data.

## Required rules

- Preserve original/source memory data in real installs; do not design pruning/deletion as a performance strategy.
- Improve memory recall additively with schema, indexes, materialized views, concepts, associations, summaries, or other non-destructive structures.
- Keep the public repo sanitized.
- Keep all supported install paths working:
  - standard Ubuntu
  - Docker Compose
  - Dockge
  - Docker run / GHCR
- Docker/Dockge must remain one self-contained OpenClaw/Zorg container with embedded PostgreSQL.

## Before submitting changes

Run:

```bash
bash -n scripts/*.sh docker/entrypoint.sh
python3 -m py_compile scripts/*.py
docker compose config >/tmp/zorg-memorydb-compose.yml
docker build --build-arg OPENCLAW_VERSION=latest -t zorg-memorydb-openclaw:local .
```

For runtime changes, perform a fresh Compose startup verification as described in [`docs/release-process.md`](docs/release-process.md).

## Documentation expectations

If behavior changes, update the matching docs in the same pull request/commit.

Meaningful changes require release notes under `docs/releases/` and a new GitHub Release/tag.

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

