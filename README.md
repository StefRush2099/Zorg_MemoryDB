# Zorg MemoryDB

Zorg MemoryDB is the PostgreSQL-backed memory package for OpenClaw-based assistants.

This repository is intentionally **not** a full OpenClaw fork. OpenClaw is the base install and runtime. This repo carries the Zorg MemoryDB layer: the `zorg-db-memory` skill, public-safe database/install code, recovery procedures, LAN Command Chat source package, and documentation needed to reproduce the memory behavior without falling back to markdown files.

## Release Focus

`zorg-db-memory` consolidates the MemoryDB work into one portable skill package:

- DB-first recall before work or replies.
- Markdown memory lockout so `MEMORY.md`, `AGENTS.md`, `SOUL.md`, `TOOLS.md`, `USER.md`, and `IDENTITY.md` stay recovery pointers instead of active memory stores.
- Rule Zero repair behavior when memory/database tools fail.
- Bundled Python and shell tools for SQL inspection, recall routing, speed checks, auto-heal, semantic workers, LLM dispatch, backup, recovery, and install.
- Context-window pruning through DB-backed execution slices instead of markdown summaries.
- PostgreSQL schema, recall rules, install/rollback guidance, and public-safe canonical rule import material.
- LAN Command Chat support files and Memory Brain 3D source maps/screenshots for operator-facing memory visibility.

## What This Repository Contains

- `skills/zorg-db-memory/` - the complete portable skill package.
- `package/zorg/` - public-safe install, schema, recall, recovery, LAN Command Chat, and verification code.
- `docs/` - public-safe install, operation, screenshot, and release documentation.
- `scripts/` - packaging and verification helpers for this repo.
- `release/` - release notes for published Zorg MemoryDB package releases.

## Base Install

Install OpenClaw first from the upstream project:

- <https://github.com/openclaw/openclaw>
- <https://docs.openclaw.ai/start/getting-started>

Then add this package's `zorg-db-memory` skill and `package/zorg` support files to the OpenClaw workspace or install path.

The public package does not instruct installed agents to publish back to this GitHub repository. Release publishing is a maintainer action.

## Memory Rule

`zorg-db-memory` replaces active markdown-file memory with PostgreSQL-backed Zorg MemoryDB behavior. Markdown files such as `AGENTS.md`, `MEMORY.md`, `SOUL.md`, `TOOLS.md`, `USER.md`, and `IDENTITY.md` are bootstrap or recovery pointers only.

Rule Zero:

> If any database or memory tool stops working, stop the current task, repair the database toolchain from this skill, verify backend recall, then resume the task only from DB-backed recent context.

## Package Layout

```text
skills/zorg-db-memory/
  SKILL.md
  scripts/
  references/

package/zorg/
  install-zorg-memorydb.sh
  db/
  memory/
  rules/
  lan-command-chat/
  requirements.txt

docs/
  install.md
  screenshots.md
  openclaw-base.md
```

## Screenshots

The release includes inspected screenshots for:

- Memory Brain 3D populated map, desktop dark mode.
- Memory Brain 3D populated map, desktop light mode.
- Memory Brain 3D populated map, mobile dark mode.
- Memory Brain 3D populated map, mobile light mode.
- LAN Command Chat with the Memory 3D toggle panel visible.

See [docs/screenshots.md](docs/screenshots.md).

## Public References

This package is designed to support public-safe writeups and posts about Zorg MemoryDB, OpenClaw-based agent operations, and Hyperdine Systems work. Exact X or Hyperdine article URLs should only be added after they are verified as matching public links. Do not add feed-top URLs, placeholders, guessed slugs, or stale X status links.

## Verification

After installing or updating the skill/package, verify DB access:

```bash
/home/openclaw/.openclaw/workspace/memory_sql_tool.py tables
/home/openclaw/.openclaw/workspace/memory_speed_test.py
```

For browser-visible supporting apps such as LAN Command Chat or Memory Brain 3D, verify with screenshots before claiming the UI works.

## Public Safety

This repo must not publish:

- live database dumps or rows;
- transcripts, contacts, emails, credentials, account data, or private operator context;
- live `sql_memory_map.json`, `.env`, backup archives, browser profiles, `node_modules`, `.next`, build output, or temporary files.

Only public-safe structure, code, documentation, templates, and screenshots belong here.
