# Sanitized Template Policy

`Zorg_MemoryDB` is a public, sanitized OpenClaw build template.

It should contain only:

- OpenClaw/Zorg startup structure
- Docker/Dockge/Ubuntu install scripts
- DB-backed memory schema and recall tooling
- public templates and runbooks
- release/package automation

It must not contain:

- live DB rows or dumps
- private `MEMORY.md` content
- private `memory/*.md` content
- account data
- cookies or OAuth material
- API keys or SSH keys
- contacts, emails, chats, transcripts, or private operator context

The memory database is integrated into the OpenClaw runtime and stored under OpenClaw's own home/workspace layout during installation. It should not be presented to users as a separate database product they need to manually install or connect.

## Sanity checks

```bash
git status --short
git ls-files | grep -E '(^|/)\.env$|sql_memory_map\.json|memory/|\.dump$|\.sql\.gz$' && echo "unexpected private/runtime file tracked"
grep -RInE 'BEGIN (RSA|OPENSSH|PRIVATE)|cookie|oauth|credential|private_key' . --exclude-dir=.git
```

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

