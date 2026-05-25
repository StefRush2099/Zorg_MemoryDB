# Zorg MemoryDB Overlay Manifest

Base branch: `openclaw/openclaw main`
Overlay path: `overlays/zorg-memorydb/`

Root compatibility wrappers:

- `scripts/install_standard_ubuntu.sh`
- `scripts/upgrade_existing_openclaw.sh`
- `scripts/bootstrap_full_openclaw.sh`

Those wrappers are intentionally thin. They preserve the established public commands while delegating to `overlays/zorg-memorydb/Zorg_MemoryDB/scripts/` so upstream OpenClaw files can still be updated from the original project without mixing Zorg implementation into unrelated source paths.

## Public-safe unique features included

- PostgreSQL-backed durable memory and DB-only recall routing.
- Structured operating rules and recursive logic-rule recall.
- Base-install permanent engineering rules for system/code/software changes.
- Additive recall hardening: token fallback, semantic/weighted recall, query observations, recall hints, materialized search support.
- Backup/recovery guidance and PostgreSQL backup scripts.
- Clean-install and upgrade scripts that preserve existing OpenClaw data.
- LAN/local command console documentation and assets.
- Four-screenshot UI verification rule.
- Executive assistant operating-rule templates and privacy filters.
- First-run DB grafting: upstream OpenClaw installs first, then Zorg MemoryDB applies schema, config, recall routing, bootstrap rules, and verification before the assistant answers with normal OpenClaw startup behavior.

## Non-destructive requirement

The overlay must not delete, prune, compact away, or overwrite existing OpenClaw user data. Any future migration that touches existing state must document the exact source, destination, rollback, and verification.
