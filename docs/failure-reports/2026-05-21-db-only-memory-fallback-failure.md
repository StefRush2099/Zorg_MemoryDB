# DB-Only Memory Fallback Failure Report - 2026-05-21

## Summary

Using markdown files or silent fallback paths for active memory was a process failure. The DB-only rule means durable memory, recall routing, operating lessons, and recovery records must live in PostgreSQL-backed MemoryDB. Markdown may document public-safe structure or emergency recovery contracts, but it must not be an active memory store, a hidden recall source, or a fallback when DB recall breaks.

## What Failed

The prior hardening correctly removed several markdown memory surfaces, but it left compatibility behavior in the recall tools:

the recall router could return a database-unavailable payload with empty results instead of failing;

the SQL tool could downgrade from weighted PostgreSQL recall to an older DB recall function;

the runtime memory-search helper could silently continue with an empty result set when DB recall failed;

the retired memory/ directory had been treated as something to clean up after creation rather than something that must be impossible to write to.

That was wrong. It let the system appear operational while bypassing the exact memory path the operator required.

## Why It Happened

The bad assumption was that fallback behavior was safer because it avoided a broken user-facing turn. That is acceptable for ordinary optional enrichment, but memory is Priority 0 state. For memory, silent degradation corrupts process discipline: it lets the assistant continue without the required durable context and hides the repair signal.

The correct model is:

DB recall working: proceed.

DB recall unavailable or structurally broken: stop normal work, repair or restore DB recall, then proceed.

Markdown memory fallback: prohibited.

Empty-result fallback: prohibited.

Older recall-function downgrade as substitute: prohibited.

## Corrective Action

Commit 960c360d96 removed silent fallback behavior:

scripts/memory_recall_router.py now calls only zorg_weighted_recall_context().

scripts/memory_sql_tool.py search --table all now calls only weighted PostgreSQL recall.

scripts/enforce_db_memory_search.py now patches runtime memory search to throw when DB recall fails.

db/db_memory_no_fallback_fail_closed_2026_05_21.sql seeds the DB rule and recall hint for this correction.

memory/ is replaced with an inaccessible guard directory after archive/removal.

root MEMORY.md is excluded from active maps and chmodded closed on installs that still have it.

## Future Install Rule

Future installs must not ship with active markdown memory, disabled-but-writable markdown memory, or compatibility fallback routes. The installer must verify:

authoritative DB recall returns live weighted PostgreSQL results;

intentionally broken DB config fails nonzero and emits no fake recall JSON;

runtime memory search has no database-unavailable empty-result path;

memory/ ordinary writes fail at the filesystem boundary;

MEMORY.md is not mapped as an active memory source.

The failure standard is strict: if memory cannot come from DB, the correct behavior is fail closed and repair DB memory.
