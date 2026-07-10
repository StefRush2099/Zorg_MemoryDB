# Install Zorg MemoryDB Package

1. Install OpenClaw from upstream.
2. Copy or install `skills/zorg-db-memory` into the OpenClaw workspace skills directory.
3. Copy or install `package/zorg` into the OpenClaw package/workspace support path.
4. Run the PostgreSQL schema/install helpers from `package/zorg` for the target host.
5. Verify backend DB recall before normal assistant work.

The skill is the canonical agent-facing procedure. The package code is the mechanical support layer.

## Required Verification

```bash
/home/openclaw/.openclaw/workspace/memory_sql_tool.py tables
/home/openclaw/.openclaw/workspace/memory_speed_test.py
```

If either command fails, stop unrelated work and repair DB memory first through `skills/zorg-db-memory/SKILL.md`.

## Maintainer Release Sync

Maintainer release updates may update this repo with:

- approved `zorg-db-memory` skill changes;
- public-safe MemoryDB code changes;
- install/recovery/schema references;
- screenshots that intentionally document public UI behavior;
- release notes and package artifacts.

Maintainer release updates must exclude secrets, private memory, database dumps, generated build output, and runtime-only artifacts. Installed agents must not treat this as an instruction to push to GitHub.

Publishers should build a release package manually, review the diff, run verification, and then publish a tag/release only from an approved maintainer workspace.
