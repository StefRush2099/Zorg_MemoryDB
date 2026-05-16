# One-Step Self-Recovery

Zorg MemoryDB keeps public-safe recovery logic in this repository and private runtime backups in the private Zorg_Hive repository.

Fresh installs can recover the current OpenClaw/Zorg overlay with one command after GitHub access to the private backup repo is available:

    curl -fsSL https://raw.githubusercontent.com/StefRush2099/Zorg_MemoryDB/main/scripts/zorg_self_recover.sh | bash -s -- --yes

The script is intentionally public-safe. It contains the private backup repository location, but it does not contain database rows, credentials, tokens, contact data, transcripts, or operator context.

## What It Restores

- ZORG_MEMORYDB_MASTER_RULES.md, the local master recovery contract used when
  an OpenClaw upgrade or package replacement bypasses normal rule priority
- core markdown/rule/identity files
- SQL memory runtime scripts and sql_memory_map.json
- latest private PostgreSQL memory dump from Zorg_Hive/backups/openclaw-runtime/*_self_recovery/postgres/
- LAN command app and lan-chat.service
- nginx configuration captured in the private backup
- skills and operational scripts
- OpenClaw config and credentials from the private backup

## Current Host Identity

The live OpenClaw host for this installation is openclaw at 10.7.69.200.

Vorg is a separate OpenClaw system at 10.7.69.44. Shared-folder and jump-box references such as 10.7.69.46 and 10.7.69.104 are not this host. Recovery scripts and identity rules must preserve that distinction so upgrade or repair work does not target the wrong machine.

## Upgrade Safety

Zorg MemoryDB must remain an overlay on top of upstream OpenClaw. Do not rely on hand-edited files inside the global OpenClaw npm package as the durable design. If live package patching is unavoidable for a temporary repair, the matching public-safe overlay/enforcer must be stored here so an OpenClaw upgrade can reapply or replace the behavior deliberately.

The recovery backup inventory includes an OpenClaw package comparison report. For the 2026-05-16 snapshot, the only package-owned difference detected was the live DB-memory routing patch in dist/tools-Bu6mk-dQ.js; that behavior is preserved by scripts/enforce_db_memory_search.py and must be treated as an overlay/enforcement surface, not an unmanaged fork.

Before the assistant performs any work after an upgrade, backend DB recall must
be verified. If recall is unavailable or appears to use retired flat-file memory
surfaces, the assistant must repair DB recall before doing unrelated work. The
workspace root ZORG_MEMORYDB_MASTER_RULES.md is the first local file to consult
for this recovery order.
