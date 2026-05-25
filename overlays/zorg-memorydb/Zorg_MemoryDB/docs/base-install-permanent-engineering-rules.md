# Base Install Permanent Engineering Rules

These rules are part of the Zorg MemoryDB/OpenClaw overlay contract. They are not personal operator preferences and must survive a clean install, clone, restore, upgrade, memory rebuild, or migration.

## Covered work categories

The rules apply to:

- system changes;
- code writing and code edits;
- software changes;
- service, routing, auth, browser, UI, database, cron, recall, indexing, documentation, deployment, and screenshot/verification changes;
- changes to skills, templates, runbooks, installers, and project overlays.

## Permanent requirements

1. **Change gate:** summarize exact intended changes and affected surfaces before mutation unless the operator is ordering exact correction of Zorg's own failed scope.
2. **Exact scope:** change only the requested scope; do not widen into adjacent auth, routing, HTTPS, login, UI, service, or cleanup work without explicit authorization.
3. **Real implementation:** no fake, placeholder, mock, display-only, or disconnected UI/code. Real data/control sources are required; unavailable sources must be clearly marked unavailable/degraded.
4. **Verification:** do not claim done/fixed/working until the real affected runtime surface is verified.
5. **Publication:** push system/project/rule/recall/docs changes to the correct GitHub repository and update docs/runbooks/templates/skills at the same time.
6. **Visual proof:** visible UI changes require the full four-screenshot matrix — desktop light, desktop dark, mobile/cellphone light, and mobile/cellphone dark — delivered to the operator, not merely saved.
7. **Recall durability:** sync rule/process changes into DB structured recall, refresh materialized/search surfaces, and verify natural-language recall returns the rule near the top.
8. **Overlay-safe upgrade:** Zorg MemoryDB custom behavior must be packaged as an add-on overlay to OpenClaw, not as a destructive fork. Overlay installs/upgrades must preserve existing OpenClaw behavior and user data unless an explicit migration says otherwise.
9. **Base install promotion:** when a rule governs system/code/software behavior, promote it into base install templates, public-safe Zorg MemoryDB docs, installer/upgrade paths, and structured DB rules so it survives clean installs.

If any requirement cannot be completed, report the exact blocker and do not silently omit the step.

## Clean-install implication

A clean Zorg MemoryDB install must include these rules in:

- root markdown templates such as `AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md`, `IDENTITY.md`, `HEARTBEAT.md`, and `MEMORY.md` when present;
- installer/upgrade documentation;
- structured DB logic rules;
- recall hints/observations for natural-language process queries;
- public-safe overlay documentation.

## Overlay boundary

Zorg MemoryDB should extend OpenClaw as an overlay. The overlay may add DB memory, recall hardening, rule templates, runbooks, skills, LAN console support, and verification processes, but should not overwrite unrelated OpenClaw files or remove existing user behavior. When direct patching is unavoidable, document the exact changed files, rollback path, and verification.
## Dynamic Trigger Backpressure Rule

Database triggers and recall-adjacent hooks must not perform heavy immediate work. They enqueue tiny bounded work with statistically derived `due_at` delays based on observed queue wait, worker runtime, backlog, and recall/query timing. Workers use dynamic batch limits and record timing observations after each batch. Under high CPU/load/latency, delays increase and batch sizes shrink. Rule-following and recall correctness outrank speed, and source memory must never be deleted/pruned/compacted for performance.
