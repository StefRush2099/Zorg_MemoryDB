# Install or upgrade Zorg MemoryDB v4.1.3

This document is the public entry point. The canonical detailed procedures are in:

- [Connector installation and upgrade](../skills/zorg-db-memory/references/connector-installation.md)
- [Connector recovery](../skills/zorg-db-memory/references/connector-recovery.md)
- [Connector acceptance and release gates](../skills/zorg-db-memory/references/connector-acceptance.md)
- [Install and rollback](../skills/zorg-db-memory/references/install-and-rollback.md)

## Supported architecture

OpenClaw is the host runtime. The `zorg-memorydb` native plugin and MCP expose PostgreSQL-backed recall. PostgreSQL is the only durable memory/rule store. The connector performs authoritative recall for every turn, writes a receipt tied to the exact run/session/request hash, and fails closed if that receipt cannot be produced.

The package does not enable Markdown memory, model-memory fallback, a second memory plugin, delegated agents, task executors, or per-job host scripts as substitutes for the direct database gate.

## Obtain the pinned release

```bash
git clone --branch v4.1.3 --depth 1 https://github.com/StefRush2099/Zorg_MemoryDB.git
cd Zorg_MemoryDB
```

Verify the release asset/tag and checksum before installation. Do not combine files from different releases.

## Preflight

Run this procedure only on a separately supplied target. Never run it on the
source/authoring OpenClaw system, and never use that system as a fallback test
target. If no separate target exists, installation, upgrade, recovery,
rollback, restart, and runtime-registration acceptance remain pending. Source
publication may continue only under [the source and test boundary](source-and-test-boundary.md).

Before changing the host:

1. Record OpenClaw, Node, PostgreSQL, and pgvector versions.
2. Inspect `openclaw plugins list --enabled --verbose`, the current memory slot, allow/deny policy, and `openclaw plugins inspect zorg-memorydb --runtime --json` when already installed.
3. Resolve the approved database configuration source without printing its password.
4. Verify the target database identity, schema owners, installed extensions, source-row counts, semantic queue state, and invalid-index count.
5. Create a logical backup, prove it is listable with `pg_restore --list`, and compute SHA-256.
6. Read the complete connector-installation runbook, present the proposed mutation/rollback, and wait for literal `GO`.

## Install

Run the package installer only after authorization:

```bash
bash package/zorg/install-zorg-memorydb.sh
```

The installer must stop on SQL errors, validate the actual installed extension versions and schema objects, preserve source data, stage the plugin from this pinned release, and avoid activating a competing memory path.

Configure the DSN through the approved protected configuration file or environment reference. Never put credentials into the repository, command history, logs, screenshots, or documentation.

Explicitly trust and enable the plugin according to host policy. If `plugins.allow` is used, include `zorg-memorydb`; ensure deny does not override it. Select it for the memory slot where that OpenClaw version exposes the exclusive slot. Disable the conflicting stock/legacy memory plugin only after the Zorg plugin has passed pre-activation checks.

Installing or changing plugin code on the separate target requires a Gateway restart. After the target restart, runtime proof is mandatory:

```bash
openclaw plugins inspect zorg-memorydb --runtime --json
node skills/zorg-db-memory/plugin-src/dist/mcp-server.js
```

A manifest-only inspection is not runtime proof.

## Required acceptance

Run the complete connector matrix from the acceptance reference. At minimum prove:

- a healthy turn produces a fresh receipt for the exact request;
- missing, stale, or mismatched receipts block tool use and output;
- a database disconnect holds the request and emits only one bounded alert;
- restoration performs new recall and never reuses the old receipt;
- critical safety recall ranks first;
- exact and HNSW quality are non-regressive;
- semantic/vector queues and indexes are healthy;
- source memory/history/provenance counts are preserved;
- LAN Command Chat and Memory Brain 3D use the same database route;
- the full 13-gate production suite passes.

Do not claim a successful install from a zero exit code alone.

## Rollback

If activation fails, hold affected requests, restore the prior plugin/config package, restart only the affected service, and verify the previous direct PostgreSQL gate before reopening delivery. Restore the database dump only when an additive migration cannot be safely reversed and the operator has authorized that restoration.

Keep rollback files private. Never publish database dumps, credentials, internal endpoints, private receipts, transcripts, or operator context.

## Official sources

- PostgreSQL 18 privileges: https://www.postgresql.org/docs/18/ddl-priv.html
- PostgreSQL CREATE EXTENSION: https://www.postgresql.org/docs/18/sql-createextension.html
- PostgreSQL SQL dump/restore: https://www.postgresql.org/docs/18/backup-dump.html
- PostgreSQL CREATE INDEX: https://www.postgresql.org/docs/18/sql-createindex.html
- PostgreSQL ANALYZE: https://www.postgresql.org/docs/18/sql-analyze.html
- pgvector: https://github.com/pgvector/pgvector
- OpenClaw plugins: https://docs.openclaw.ai/tools/plugin
- GitHub releases: https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository
