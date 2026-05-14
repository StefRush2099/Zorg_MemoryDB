# Zorg LAN Console

Next.js LAN web console for OpenClaw/Zorg MemoryDB deployments.

The console provides a local browser chat surface that talks to the OpenClaw Gateway, stores conversation traffic in PostgreSQL-backed memory, and keeps communication available if an external messaging channel is unavailable.

## Features

- Local web chat UI
- Gateway-backed `chat.send` / history access
- PostgreSQL memory ingestion for LAN chat messages
- Runtime and database status display
- Optional file upload support
- Nginx front-end for simple LAN access

## Configuration

Copy the example environment file if running outside the bundled Docker Compose setup:

```bash
cp .env.local.example .env.local
```

Useful environment variables:

- `GATEWAY_SESSION_KEY` — OpenClaw session key to expose, default `agent:main:main`
- `CHAT_SOURCE_LABEL` — label shown in injected metadata, default `LAN Console`
- `CHAT_HISTORY_LIMIT` — message count to return, default `50`
- `GATEWAY_CALL_TIMEOUT_MS` — gateway request timeout, default `15000`
- `GATEWAY_HOST` — gateway host, default `127.0.0.1`; bundled Compose sets this to `openclaw`

## Docker Compose

The top-level Zorg MemoryDB `docker-compose.yml` builds this app as `lan-chat` and publishes it through `lan-chat-nginx`.

The app mounts `./openclaw-home` read-only so it can read the local OpenClaw gateway/device auth configuration. Uploaded files are stored under `./lan-chat/uploads`.

## Privacy boundary

Do not commit `.env.local`, live OpenClaw state, credentials, uploaded files, build output, or node dependencies. This directory is intended to contain source and public-safe install structure only.
