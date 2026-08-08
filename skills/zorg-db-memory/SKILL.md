---
name: "zorg-db-memory"
description: "Install, recover, and verify the PostgreSQL MemoryDB connector safely."
---

# Zorg DB Memory

Use this skill for every MemoryDB install, upgrade, recall, recovery, performance, or release task.

## Non-negotiable contract

- PostgreSQL is the sole durable memory and rule source.
- Run the direct database turn-preparation gate before answering or mutating state.
- Fail closed when the gate, receipt, or database is unavailable. Never substitute model memory, Markdown, flat files, a subagent, or a task executor.
- Use the live LLM only for reasoning. Schedules may enqueue prompts, but no delegated or scripted task executor may perform autonomous work.
- Preserve source memories, events, history, contradictions, embeddings, and provenance. Derived indexes and caches are rebuildable; source records are not.
- Before any mutation, report verified current facts, exact proposed changes, affected surfaces, and rollback. Continue only after the operator's next trimmed message is exactly `GO`.
- Keep public releases operator-neutral and free of credentials, private records, internal addresses, transcripts, backups, and personal context.
- End every visible response with the required elapsed-time proof line.

## Route by task

- Install or upgrade: read [references/connector-installation.md](references/connector-installation.md) and [references/install-and-rollback.md](references/install-and-rollback.md).
- Failure or recovery: read [references/connector-recovery.md](references/connector-recovery.md).
- Verification or release: read [references/connector-acceptance.md](references/connector-acceptance.md) and [references/github-posting-release-rule.md](references/github-posting-release-rule.md).
- Recall/ranking work: read [references/rules-and-recall.md](references/rules-and-recall.md).
- Schema work: read [references/schema-summary.md](references/schema-summary.md).
- Performance work: read [references/nightly-performance-tuning.md](references/nightly-performance-tuning.md).

## Mandatory completion evidence

Do not claim success from a process exit code alone. Require database identity/version, plugin runtime registration, direct turn-gate receipt, rank-one safety recall, exact-versus-ANN quality, queue health, connected-surface health, source-preservation proof, and rollback evidence. A release also requires version/gauge parity and remote GitHub verification.
