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
