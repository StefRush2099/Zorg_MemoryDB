# Documentation and Release Maintenance

Zorg MemoryDB documentation is part of the product, not an afterthought.

The repo should always explain the current design accurately enough that a new user understands why this build exists, what it adds to plain OpenClaw, how to install it, how to recover it, and what changed recently.

## Required update rule

Whenever a meaningful DB-memory, recall, schema, index, routing, install, automation, release, backup, privacy, communication, or operating-rule change is made, update all public-safe documentation surfaces that are affected.

At minimum, check:

- `README.md`
- `CHANGELOG.md`
- `docs/why-zorg-memorydb.md`
- `docs/rules-and-recall.md`
- `docs/schema-summary.md`
- `docs/database-recovery.md`
- install docs: Docker, Dockge, Docker run, Ubuntu, quickstart
- release notes under `docs/releases/`
- templates: `AGENTS.md`, `MEMORY.md`, and `templates/*`
- scripts/docs that teach fresh installs or existing-workspace upgrades

## Why this matters

Plain OpenClaw is a strong agent runtime. Zorg MemoryDB is the same base plus a living operational memory system:

- DB-only durable memory and recall
- structured operating rules
- recursive logic and proactive final checks
- contact/communication privacy rules
- rich-text email defaults
- DB-only recall auto-healing
- mandatory DB backups and private/off-host recovery recommendations
- production DB tuning gated by real recall failures
- additive semantic evolution toward weighted/vector/neural-style recall

If the docs do not describe those current capabilities, users cannot understand why Zorg MemoryDB is different from plain OpenClaw.

## Release duty

Releases must not lag behind meaningful changes. Every meaningful structural/install/runtime/schema/recall/rule update needs:

1. public-safe docs update
2. `CHANGELOG.md` update
3. curated release note file under `docs/releases/vX.Y.Z.md`
4. commit and push to `main`
5. semantic version tag
6. GitHub Release / GHCR workflow trigger

Patch-only typo fixes can be grouped. Feature/rule/schema/recovery changes should be released promptly so people can see what changed.

## Public-safety boundary

Publish structure, scripts, schema, templates, examples, and public-safe explanations only.

When a meaningful operating rule changes — especially DB-memory recall, no-scripted-policy behavior, LLM-governed cron/email/contact/scheduling behavior, publication verification, or recovery rules — update the relevant public markdown/runbooks and release notes before considering the local change complete. Local core-rule changes should not remain private if they teach future installs how to reproduce the current public-safe design.

Never publish:

- private DB dumps or rows
- contacts
- credentials
- transcripts
- emails
- live operator context
- internal private strategy

Private recovery backups belong in a private repository such as `Zorg_Hive`, not in the public `Zorg_MemoryDB` repo.

## Periodic review expectation

A maintenance agent should periodically scan the docs and releases against the current MemoryDB design and recent commits. If public-safe docs/releases are stale, update them and publish a new release. If no meaningful public-safe change is pending, stay quiet.
