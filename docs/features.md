# Consolidated Features

`zorg-db-memory` packages the MemoryDB-dependent behavior that used to be spread across separate processes.

## Memory Control

- DB-first recall before work or visible replies.
- Markdown memory lockout for normal operation.
- Rule Zero repair before unrelated work when memory tools fail.
- Secret-safe handling rules for database maps, environment files, backups, and local inventories.

## Bundled Tools

- SQL inspection through `skills/zorg-db-memory/scripts/memory_sql_tool.py`.
- Recall routing through `skills/zorg-db-memory/scripts/memory_recall_router.py`.
- Health checks through `memory_speed_test.py`.
- DB-only memory auto-heal through `db_only_memory_autoheal.py`.
- Fail-closed turn preparation through the native plugin hook and exact-request PostgreSQL receipts.
- ANN/vector bootstrap through the model-slot registry, source queue, query cache helper, and idempotent PostgreSQL-owned maintenance functions.
- PostgreSQL backup, recovery, install, and display helpers under `scripts/`.

## Context Window Process

- DB recall expansion before long work.
- Memory-addressed execution slices.
- Full process summaries stored through database-backed continuity.
- Current-slice-only active context so long jobs can continue without relying on large markdown memory files.

## Supporting Software

- LAN Command Chat source map and public-safe package references.
- Memory Brain 3D source map and screenshots.
- OpenClaw-as-base-install documentation so this repository stays focused on the Zorg MemoryDB layer.

## Release Boundary

The public package is not an instruction for every installed agent to update this GitHub repository. Publishing new package releases is a maintainer action after review, scans, and verification.
