# LAN Console

Zorg MemoryDB includes a LAN web console (`lan-chat`) as a built-in local command chat and fallback communication path for OpenClaw. It is installed with the base Zorg MemoryDB distribution in the Docker Compose/Dockge and native Ubuntu install paths, the same way database memory is installed as base infrastructure. This is a minimum usability feature: an operator should be able to open a normal web page on the same LAN and talk to the local agent without logging into a terminal, knowing CLI commands, or sending private prompts through an outside chat provider first.

![LAN command console in use](assets/lan-console-in-use-2026-05-14.png)

_Public-safe documentation screenshot. The live console should show the local agent identity, runtime/database readouts, and a browser command line attached to the local OpenClaw TUI without exposing private messages in public docs._

Purpose:

- provide a browser-accessible local chat surface when another channel, such as Telegram, is unavailable,
- provide a browser command line that opens and controls the local `openclaw tui`,
- preserve chat traffic into the PostgreSQL-backed memory system,
- expose useful runtime/database status in the UI,
- keep operator communication recoverable from the local network,
- provide a default back channel for authorized local AI agents.

The LAN console is installed from `lan-chat/` and wired into the default install. It is not a separate optional tool; it is part of the base communication surface on top of other OpenClaw channels and connections.

## Why this matters for privacy

External chat providers such as Telegram, Discord, Slack, Signal gateways, or similar integrations are useful remote-control surfaces, but they are not the same as a local/private control path. When a user sends private information to an agent through an outside chat provider, the message necessarily passes through that provider's account, network, retention, metadata, device, and integration surfaces before it reaches the agent. Even if the provider is trustworthy, that adds another system, account, token, bot, and policy boundary to information that might otherwise have stayed entirely on the user's own LAN.

The LAN console gives the install a local-first option: for sensitive prompts, internal system details, private documents, family/business context, or agent-to-agent coordination on the same network, the user can keep the conversation inside their own local infrastructure. Remote chat is still valuable for convenience and mobile use, but it should not be the only practical way to talk to a personal agent.

## Usability expectation

A serious personal-agent install should not require the operator to SSH into a box, launch a command prompt, remember CLI syntax, or type raw API calls just to speak to the agent. The minimum expected connection is a browser-accessible local page. Future versions should make this even easier through discovery, friendlier URLs, QR/setup flows, bookmarks, and optional front-end authentication, but the baseline is already clear: talking to the local agent should feel like opening a local app, not operating a server.

## Security roadmap

The current public template is intentionally simple and LAN-scoped. It can easily grow stronger front-end security in future versions without changing the basic architecture, including:

- password or token gate at the LAN console front end,
- device pairing / approved-client lists,
- optional HTTPS with local certificates,
- per-session access controls,
- read-only vs send permissions,
- audit display for recent local connections,
- LAN/VPN allowlists and reverse-proxy policy.

Those additions should harden the local surface while preserving the core privacy benefit: users should have a direct local path to their local agent before they are forced to involve any outside messaging provider.

## Default behavior

- `lan-chat` builds from `./lan-chat`.
- Docker Compose/Dockge starts `lan-chat` and `lan-chat-nginx` automatically with the main OpenClaw/Zorg service.
- `lan-chat-nginx` publishes HTTP on port `80` by default (`LAN_CHAT_HTTP_PORT=80`).
- Native Ubuntu installs `lan-chat.service` as a user-level systemd service on port `3001` (`LAN_CHAT_PORT=3001`).
- The console reads the OpenClaw gateway config from the shared OpenClaw home (`./openclaw-home` in Compose or `$HOME/.openclaw` on native installs).
- It connects to the OpenClaw gateway over the compose network using `GATEWAY_HOST=openclaw` in Docker, or `127.0.0.1` on native installs.
- Chat messages are stored as DB memory rows so the LAN console becomes part of durable recall.
- The browser tab title uses the running agent's full identity name instead of a hard-coded product title.
- The main command tile is a tmux-backed web command line attached to `openclaw tui`.
- Status, activity, DB gauges, live query readout, browser audio state, and Memory 3D remain visible around the TUI panel.

## Install and verification

### Docker Compose / Dockge

The top-level `docker-compose.yml` includes both services by default:

- `lan-chat` — the Next.js command console
- `lan-chat-nginx` — the LAN HTTP front door

After startup:

```bash
docker compose ps
curl -fsS http://127.0.0.1:${LAN_CHAT_HTTP_PORT:-80}/ | grep -i '<title>'
```

### Native Ubuntu

The native installer calls:

```bash
./scripts/install_lan_chat.sh
```

That helper installs dependencies, builds `./lan-chat`, writes `.env.local`, and registers `~/.config/systemd/user/lan-chat.service`.

Verify with:

```bash
systemctl --user status lan-chat.service
curl -fsS http://127.0.0.1:${LAN_CHAT_PORT:-3001}/ | grep -i '<title>'
```

After login, verify the browser UI or authenticated local curls can reach
`/api/tui`, `/api/chat/status`, `/api/chat/activity`, `/api/db/status`, and
`/api/db/queries`.

## Runtime notes

The LAN console is intended to be maintained as base infrastructure, not a one-off side app. If it is broken after install or upgrade, repair it as part of normal Zorg MemoryDB/OpenClaw operational maintenance. A production host should run the service with restart policy and a lightweight health check so the local command chat stays online even if an external messaging channel fails.

Private operator data, credentials, and raw live database rows should not be published to public docs. This document describes only the public-safe install structure.
