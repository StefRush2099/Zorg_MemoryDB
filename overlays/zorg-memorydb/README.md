# Zorg MemoryDB Additive Overlay for OpenClaw

This branch starts from upstream `openclaw/openclaw` `main` and adds Zorg MemoryDB under `overlays/zorg-memorydb/` as an additive overlay. Upstream OpenClaw remains the base install; Zorg MemoryDB is grafted on afterward by wrapper scripts and overlay scripts.

The overlay is intentionally isolated from upstream OpenClaw source paths. It documents and packages Zorg MemoryDB features without replacing unrelated OpenClaw files or destroying existing user data.

## Overlay contract

- Preserve upstream OpenClaw behavior by default.
- Add DB-backed durable memory, structured rule recall, install/upgrade docs, PostgreSQL schema, helper scripts, LAN/local console docs, and verification practices as a separate overlay package.
- Treat system changes, code writing, and software changes as base-install permanent engineering rules, not personal operator preferences.
- For visible UI work, require the full four-screenshot verification matrix: desktop light, desktop dark, mobile/cellphone light, and mobile/cellphone dark.
- Upgrade by applying overlay files and migrations additively; do not delete OpenClaw user state or unrelated configuration.
- Keep upstream OpenClaw files mergeable. Zorg-specific documentation, schema, templates, and LAN command chat files belong in this overlay path; root-level files are limited to thin compatibility wrappers that preserve established install commands.

## Contents

- `Zorg_MemoryDB/README.md` — public install overview.
- `Zorg_MemoryDB/docs/base-install-permanent-engineering-rules.md` — permanent engineering rule contract.
- `Zorg_MemoryDB/db/` — public-safe PostgreSQL schema/migration files.
- `Zorg_MemoryDB/scripts/` — install, upgrade, recall, backup, and verification helpers.
- `Zorg_MemoryDB/templates/` — clean-install bootstrap rule templates.
- `Zorg_MemoryDB/lan-chat/` — LAN/local command console documentation/assets.

## Apply model

Use the established root wrapper commands or the overlay scripts directly. The wrapper commands preserve older public install paths while delegating to this isolated overlay:

```bash
curl -fsSL https://raw.githubusercontent.com/StefRush2099/Zorg_MemoryDB/zorg-memorydb-additive-overlay/scripts/install_standard_ubuntu.sh | bash
OPENCLAW_WORKSPACE=/path/to/openclaw/workspace ./scripts/upgrade_existing_openclaw.sh
```

The overlay is designed to be copied into an OpenClaw home/workspace and applied as an additive layer after upstream OpenClaw is installed. On first connection, the DB memory scripts write `sql_memory_map.json`, apply the public schema, import bootstrap rules, enforce DB-backed `memory_search`, and verify database recall before normal OpenClaw startup continues.

If direct upstream source changes become necessary in the future, keep them as small patches with explicit rollback notes and runtime verification. Do not silently merge Zorg-specific behavior into unrelated upstream paths.
