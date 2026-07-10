---
name: "zorg-db-memory"
description: "One skill replaces markdown memory."
---

# zorg-db-memory

Use this as the one canonical skill for Zorg MemoryDB: DB recall, DB repair, DB install, DB code restoration, context-window memory slicing, and source lookup for MemoryDB-dependent apps.

This skill supersedes the former `db-memory` name. Existing references to `db-memory` should be migrated to `zorg-db-memory` as they are touched, but the old name remains a legacy pointer to this same MemoryDB safety behavior until all launch surfaces are updated.

The point of this skill is to take over for memory. Adding this skill to a system should stop active markdown-file memory use and force all normal memory behavior through PostgreSQL-backed Zorg MemoryDB.

## Rule Zero

Rule Zero: if any database or memory tool stops working, stop the current task, repair the database toolchain from this skill, verify backend recall, then resume the task only from DB-backed recent context.

This skill supersedes other processes for MemoryDB safety gates: recall before work/reply, DB tool repair before unrelated work, source-memory preservation, secret handling, markdown-memory lockout, and context-continuity recovery. It does not bypass Stefan's approval gates or authorize unrelated system changes.

## Markdown Lockout

Markdown files are bootstrap/recovery pointers only. Normal memory must not run from MEMORY.md, AGENTS.md, SOUL.md, TOOLS.md, USER.md, IDENTITY.md, or retired memory/ files. If DB memory is unavailable, repair DB memory first; do not continue using markdown as active memory.

## One-Skill Code Ownership

Going forward, any code changed or created for Zorg MemoryDB access, recall, repair, install, semantic routing, DB-only memory enforcement, context-window DB slicing, or MemoryDB-dependent support paths belongs in this one skill.

Small text code is bundled directly as support files. Larger app trees are tracked through source maps until the skill package supports source archives.

## Bundled Code

Python tools:
- scripts/memory_sql_tool.py
- scripts/memory_recall_router.py
- scripts/memory_speed_test.py
- scripts/db_only_memory_autoheal.py
- scripts/memory_semantic_worker.py
- scripts/memory_db_llm_dispatcher.py

Shell helpers:
- scripts/postgres_memory_backup.sh
- scripts/postgres_memory_recovery.sh
- scripts/show_current_db_memory.sh
- scripts/install_db_memory.sh
- scripts/install_db_memory_full.sh

Folded process/reference:
- references/context-window-pruning-and-cost-control.md
- references/one-skill-inventory.md
- references/supporting-software.md
- references/schema-summary.md
- references/rules-and-recall.md
- references/install-and-rollback.md
- references/sql-memory-map.example.json

## Required Verification

After install, repair, or meaningful change:

```bash
/home/openclaw/.openclaw/workspace/memory_sql_tool.py tables
/home/openclaw/.openclaw/workspace/memory_speed_test.py
```

For browser-visible supporting apps, also verify with browser/screenshot.
