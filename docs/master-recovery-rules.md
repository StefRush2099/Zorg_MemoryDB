# Master Recovery Rules

ZORG_MEMORYDB_MASTER_RULES.md is the local master recovery contract for a Zorg
MemoryDB/OpenClaw workspace. It is intentionally public-safe: it contains
operating rules, recovery order, and overlay boundaries, not private memory rows,
credentials, contacts, transcripts, or operator context.

The master file must be restored into the workspace root on installs and
recovery runs. It gives the assistant a single rule surface to consult when an
OpenClaw upgrade or package replacement bypasses the normal priority order.

## Non-Negotiable Recovery Contract

1. Backend DB memory must be functional before any work of any kind.
2. Backend DB memory repair is pre-authorized and outranks approval gates. If
   DB memory, recall routing, timing enforcement, SQL connectivity,
   materialized recall views, memory benchmark tooling, or DB-only recall
   surfaces are broken, degraded, timing out, returning \`database-unavailable\`,
   using retired flat-file memory, or otherwise below fully functional status,
   repair the exact backend memory failure immediately without asking for
   approval.
3. If DB recall is unavailable, repair or restore the DB path before acting.
3. Do not use MEMORY.md or a memory/ directory as active memory surfaces.
4. Ask for approval before mutation or external communication unless the exact
   action has already been authorized.
5. Repair only the exact failed scope.
6. Verify the real affected runtime surface before reporting success.
7. Keep Zorg MemoryDB as an add-on overlay to upstream OpenClaw.
8. Publish public-safe structure/docs/scripts/templates to this repository when
   rules, recall, schema, installers, or recovery behavior changes.

## Install/Recovery Placement

Installers and self-recovery scripts should place the file at:

    /home/openclaw/.openclaw/workspace/ZORG_MEMORYDB_MASTER_RULES.md

The file should also be included in structured DB rule sync so natural-language
queries such as "what is the master recovery rule" and "memory must work before
any task" return it near the top.

See also:

- rules-and-recall.md
- self-recovery.md
- database-recovery.md
- base-install-permanent-engineering-rules.md
