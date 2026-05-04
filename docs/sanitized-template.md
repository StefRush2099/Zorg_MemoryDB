# Sanitized Full Template Policy

`Zorg_MemoryDB` is the public, sanitized full install template for OpenClaw + Zorg DB memory.

## Included

- Full OpenClaw install path using `openclaw@latest`
- Dockerfile for an all-in-one OpenClaw container
- Docker Compose stack with OpenClaw + PostgreSQL
- Dockge-ready stack instructions
- Docker run / GHCR package instructions
- Native Ubuntu install script
- PostgreSQL schema, indexes, functions, materialized views, recall tooling, and bootstrap scripts
- Public markdown templates and operating rules

## Not included

Never commit any of the following:

- live database rows or dumps
- private `MEMORY.md` contents
- private `memory/*.md` files
- `sql_memory_map.json` with real credentials
- `.env` with real tokens/passwords
- OpenClaw session transcripts
- cookies, OAuth tokens, API keys, SSH keys, contact data, email content, chat logs, or private operator context

## Database state

Fresh installs start with an empty PostgreSQL database except for schema objects and public template/rule imports. Real memory accumulates only on the local installed system after startup.

## Sanitization check before publishing

```bash
git status --short
find . -maxdepth 4 -type f \
  \( -name '*.dump' -o -name '*.backup' -o -name '*.sqlite' -o -name '*.db' -o -name 'sql_memory_map.json' \) -print
grep -RInE 'BEGIN (RSA|OPENSSH|PRIVATE)|cookie|oauth|credential|private_key' . --exclude-dir=.git
```

Review all matches before pushing.
