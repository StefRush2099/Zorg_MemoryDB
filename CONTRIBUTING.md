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
