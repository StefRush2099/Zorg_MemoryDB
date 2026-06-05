# Zorg MemoryDB Master Recovery Rules

This template is copied into the workspace root as ZORG_MEMORYDB_MASTER_RULES.md.

The live file is the local recovery contract for the Zorg MemoryDB/OpenClaw
overlay. It must say, at minimum:

1. PostgreSQL Zorg MemoryDB is the primary source for durable rules, processes, and operating memory.
2. Backend DB memory must be functional before any work of any kind.
3. If DB recall is unavailable, repair or restore the DB path before acting.
4. Do not use MEMORY.md or a memory/ directory as active memory surfaces.
5. Ask for approval before mutation or external communication unless the exact
   action has already been authorized.
6. Repair only the exact failed scope.
7. Verify the real affected runtime surface before reporting success.
8. Preserve DB source history forever; tune recall additively only.
9. Keep Zorg MemoryDB as an add-on overlay to upstream OpenClaw.
10. Publish public-safe structure/docs/scripts/templates to Zorg_MemoryDB when
   rules, recall, schema, installers, or recovery behavior changes.
11. Runtime memory writers must not recreate retired `memory/*.md` files. Patch
    or disable file-backed `session-memory` and pre-compaction `memoryFlush`
    writers on DB-only installs. Any retired file that still appears is
    emergency import input: import it into PostgreSQL, then remove it.
12. User-visible operational replies must use real request and response
    timestamps when timing is relevant, and durations must be computed only
    from those real values after the response is sent.

For the current canonical text, see docs/master-recovery-rules.md in this
repository and the workspace root ZORG_MEMORYDB_MASTER_RULES.md on a restored
system.
