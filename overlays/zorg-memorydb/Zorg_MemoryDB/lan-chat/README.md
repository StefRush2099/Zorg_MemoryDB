# Zorg LAN Console

Next.js LAN/local command chat console for OpenClaw/Zorg MemoryDB deployments.

The console provides a local browser chat surface that talks to the OpenClaw Gateway, stores conversation traffic in PostgreSQL-backed memory, and keeps communication available if an external channel such as Telegram is unavailable. It is part of the default Zorg MemoryDB install, not a separate optional side app.

## Built-in install behavior

- Docker run: the packaged image starts an internal LAN console on port `3001` when `ENABLE_LAN_CHAT_INTERNAL=true` (default).
- Docker Compose/Dockge: the top-level stack runs `lan-chat` as a dedicated service and publishes it through `lan-chat-nginx` on `LAN_CHAT_HTTP_PORT` (default `80`).
- Native Ubuntu: `scripts/install_lan_chat.sh` builds this app and registers `lan-chat.service` as a user-level systemd service on `LAN_CHAT_PORT` (default `3001`).

## Features

- Local web chat UI
- Dynamic browser tab title from the running agent identity
- Unified latest-20 command stream across LAN/back-channel, Gateway/session history, transcript history, and DB-ingested chat rows
- Gateway-backed `chat.send` / history access
- PostgreSQL memory ingestion for LAN chat messages
- Runtime and database status display
- Optional file upload support
- Built-in fallback command chat for operator and authorized local agent coordination

## Configuration

Copy the example environment file if running outside the bundled service setup:

```bash
cp .env.local.example .env.local
```

Useful environment variables:

- `GATEWAY_SESSION_KEY` — OpenClaw session key to expose, default `agent:main:main`
- `CHAT_SOURCE_LABEL` — label shown in injected metadata, default `LAN Console`
- `CHAT_HISTORY_LIMIT` — visible history limit, default `20`
- `GATEWAY_CALL_TIMEOUT_MS` — gateway request timeout, default `15000`
- `GATEWAY_HOST` — gateway host (`openclaw` in Compose, `127.0.0.1` on native installs)
- `PORT` / `LAN_CHAT_PORT` — Next.js listen port, default `3001`

## Privacy boundary

Do not commit `.env.local`, live OpenClaw state, credentials, uploaded files, build output, node dependencies, private screenshots, transcripts, or operator-specific context. This directory contains source and public-safe install structure only.

## Login password reset procedure

The default landing page is a password login gate for the LAN command chat. To rotate access, generate a new strong random password, update `LAN_CHAT_PASSWORD_HASH` with a salted PBKDF2-SHA256 hash, update/keep `LAN_CHAT_AUTH_SECRET` for signed login cookies, rebuild/restart `lan-chat`, then send the new plaintext password to the operator at the approved email address. If email is unavailable, use the backup secure-channel procedure: direct the operator/user to open the OpenClaw TUI on the LAN and provide the password there, keeping the password on an internal LAN channel. Do not commit plaintext passwords.
