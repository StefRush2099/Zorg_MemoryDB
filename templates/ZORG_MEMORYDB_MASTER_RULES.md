# Zorg MemoryDB Master Recovery Rules

This template is copied into the workspace root as ZORG_MEMORYDB_MASTER_RULES.md.

The live file is the local recovery contract for the Zorg MemoryDB/OpenClaw
overlay. It must say, at minimum:

1. Backend DB memory must be functional before any work of any kind.
2. If DB recall is unavailable, repair or restore the DB path before acting.
3. Do not use MEMORY.md or a memory/ directory as active memory surfaces.
4. Ask for approval before mutation or external communication unless the exact
   action has already been authorized.
5. Repair only the exact failed scope.
6. Verify the real affected runtime surface before reporting success.
7. Preserve DB source history forever; tune recall additively only.
8. Keep Zorg MemoryDB as an add-on overlay to upstream OpenClaw.
9. Publish public-safe structure/docs/scripts/templates to Zorg_MemoryDB when
   rules, recall, schema, installers, or recovery behavior changes.

For the current canonical text, see docs/master-recovery-rules.md in this
repository and the workspace root ZORG_MEMORYDB_MASTER_RULES.md on a restored
system.

