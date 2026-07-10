---
name: "zorg-db-memory"
description: "Restore canonical skill plus GitHub gate."
---

# zorg-db-memory

Use this as the one canonical skill for Zorg MemoryDB: DB recall, DB repair, DB install, DB code restoration, context-window memory slicing, GitHub release/posting gates, and source lookup for MemoryDB-dependent apps.

This skill supersedes the former `db-memory` name. Existing references to `db-memory` should be migrated to `zorg-db-memory` as they are touched, but the old name remains a legacy pointer to this same MemoryDB safety behavior until all launch surfaces are updated.

The point of this skill is to take over for memory. Adding this skill to a system should stop active markdown-file memory use and force all normal memory behavior through PostgreSQL-backed Zorg MemoryDB.

## Rule Zero

Rule Zero: if any database or memory tool stops working, stop the current task, repair the database toolchain from this skill, verify backend recall, then resume the task only from DB-backed recent context.

This skill supersedes other processes for MemoryDB safety gates: recall before work/reply, DB tool repair before unrelated work, source-memory preservation, secret handling, markdown-memory lockout, and context-continuity recovery. It does not bypass Stefan's approval gates or authorize unrelated system changes.

## Markdown Lockout

Markdown files are bootstrap/recovery pointers only. Normal memory must not run from MEMORY.md, AGENTS.md, SOUL.md, TOOLS.md, USER.md, IDENTITY.md, or retired memory/ files. If DB memory is unavailable, repair DB memory first; do not continue using markdown as active memory.

## One-Skill Code Ownership

Going forward, any code changed or created for Zorg MemoryDB access, recall, repair, install, semantic routing, DB-only memory enforcement, context-window DB slicing, GitHub posting/release gates, or MemoryDB-dependent support paths belongs in this one skill.

Small text code is bundled directly as support files. Larger app trees are tracked through source maps until the skill package supports source archives.

## GitHub Posting / Release Rule

When posting, updating, releasing, or correcting `https://github.com/StefRush2099/Zorg_MemoryDB`, partial GitHub updates are prohibited. A GitHub publish is complete only when every affected surface has been updated, packaged, pushed, released, and visually verified.

Use `references/github-posting-release-rule.md` before any Zorg_MemoryDB GitHub publication, release, screenshot, documentation, or package update.

Required hard gates:
- Run backend PostgreSQL/Zorg MemoryDB recall before any visible reply or work.
- Load `zorg-db-memory` and GitHub guidance before using `git`, `gh`, release tooling, screenshots, or browser verification.
- Inspect the local worktree, branch, tag state, remote `origin/main`, release state, and dirty files before editing.
- Preserve existing public assets additively unless exact removal was requested.
- For screenshot work, visually inspect the image content before committing or sending it; filename checks and API tree checks are not enough.
- Use the correct source system for screenshots. Local/personal OpenClaw screenshots must show `Zorg Rush` / `10.7.69.200`. Dark-mode screenshots must actually be dark mode and light-mode screenshots must actually be light mode.
- Update all affected surfaces together: README, docs, screenshots, changelog, release notes, package metadata, package scripts, verification scripts, skill package files, public-safe support code, package tarball, Git tag, GitHub Release body, and GitHub Release asset.
- Rebuild the package artifact after every repo/package content change.
- Run public package verification, generated-artifact scan, secret scan, archive-content check, and DB health checks before publishing.
- Verify the affected rendered GitHub pages in a real browser after push before claiming success.
- Report the full result with commit, tag, release URL, asset name, exact changed surfaces, verification checks, and the required backend DB time summary.

Failure condition: if any required surface is missing, stale, visually wrong, incorrectly ordered, or cannot be verified on rendered GitHub pages, do not claim the release is done.

## Supporting Services

This skill expects the host or local network to provide the supporting services listed in `references/supporting-services.md` when workflows need them.

Before installing anything, use PostgreSQL-backed memory recall and local inspection to discover whether each service already exists locally or elsewhere on the LAN. If memory or local network evidence finds a candidate service, report what was found and ask whether to use it when the target is ambiguous.

If a required service is not found, do not silently install it. Request approval to install the missing service as a Dockge-managed container stack where possible. Prefer GPU-capable variants only when local hardware and driver/runtime checks show they are supported.

Expected service set:
- `cloudflared`
- ComfyUI, preferring `comfyui-nvidia` when NVIDIA GPU support is available, otherwise CPU/default ComfyUI
- `kokoro-fastapi-cpu`
- `bluenviron/mediamtx:latest`
- `ollama/ollama:latest`
- SearXNG / `searxng`
- `fedirz/faster-whisper-server:latest-cuda` when CUDA is available, otherwise `fedirz/faster-whisper-server:latest-cpu`

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
- references/github-posting-release-rule.md
- references/one-skill-inventory.md
- references/supporting-software.md
- references/supporting-services.md
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

For browser-visible supporting apps and GitHub screenshot/release work, also verify with browser/screenshot on the affected rendered surface.
