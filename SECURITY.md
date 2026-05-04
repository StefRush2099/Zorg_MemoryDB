# Security Policy

## Supported versions

Use the latest GitHub Release and the matching GHCR image tag for security-sensitive installs.

## Reporting a vulnerability

Open a private/security report through GitHub if available, or contact the repository owner directly.

Do not include private memory rows, credentials, tokens, cookies, OAuth material, SSH keys, chat logs, email contents, or other sensitive data in public issues.

## Security model

`Zorg_MemoryDB` is a sanitized install template. It should contain structure, schema, scripts, docs, and public templates only.

The repository must never include:

- real database dumps or live rows
- private `MEMORY.md` contents
- private `memory/*.md` files
- `.env` files with real secrets
- `sql_memory_map.json` with real credentials
- API keys, OAuth tokens, cookies, SSH keys, contact data, email content, transcripts, or private operator context

Docker/Dockge installs run OpenClaw and PostgreSQL inside one self-contained container. Protect the OpenClaw Gateway token and do not expose the Gateway publicly without appropriate network controls.

## GitHub Actions

Workflows use the least required `GITHUB_TOKEN` permissions per job:

- CI: read-only contents
- release: package/release publishing permissions only when a semver tag is pushed

Container images are published to GitHub Container Registry using the repository-scoped `GITHUB_TOKEN`.
