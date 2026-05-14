# LAN Console

Zorg MemoryDB includes a LAN web console (`lan-chat`) as a built-in local command chat and fallback communication path for OpenClaw.

Purpose:

- provide a browser-accessible local chat surface when another channel, such as Telegram, is unavailable,
- preserve chat traffic into the PostgreSQL-backed memory system,
- expose useful runtime/database status in the UI,
- keep operator communication recoverable from the local network,
- provide a default back channel for authorized local AI agents.

The LAN console is installed from `lan-chat/` and wired into the default install. It is not a separate optional tool; it is part of the base communication surface on top of other OpenClaw channels and connections.

## Default behavior

- `lan-chat` builds from `./lan-chat`.
- `lan-chat-nginx` publishes HTTP on port `80` by default.
- The console reads the OpenClaw gateway config from the shared `./openclaw-home` volume.
- It connects to the OpenClaw gateway over the compose network using `GATEWAY_HOST=openclaw`.
- Chat messages are stored as DB memory rows so the LAN console becomes part of durable recall.

## Runtime notes

The LAN console is intended to be maintained as base infrastructure, not a one-off side app. If it is broken after install or upgrade, repair it as part of normal Zorg MemoryDB/OpenClaw operational maintenance. A production host should run the service with restart policy and a lightweight health check so the local command chat stays online even if an external messaging channel fails.

Private operator data, credentials, and raw live database rows should not be published to public docs. This document describes only the public-safe install structure.
