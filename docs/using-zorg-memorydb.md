# Using Zorg MemoryDB After Install

Use this page after the install or upgrade finishes. It explains how a nontechnical operator gets into the system, asks for the LAN command chat password, and knows which local web address to open.

Official OpenClaw basis:

Control UI: https://docs.openclaw.ai/web/control-ui

Gateway CLI: https://docs.openclaw.ai/cli/gateway

TUI CLI: https://docs.openclaw.ai/cli/tui

Install guide: https://docs.openclaw.ai/install

Zorg MemoryDB is installed as an additive branch or fork of upstream OpenClaw. OpenClaw still supplies the Gateway, Control UI, TUI, chat channels, device pairing, and gateway authentication behavior. Zorg MemoryDB adds DB-backed recall, public-safe operating-rule templates, the local LAN command chat, and the Zorg Memory 3D brain map on top of that normal OpenClaw runtime.

For LLM agents that support skills, install or expose the `db-memory` skill and
instruct agents to load it before MemoryDB recall, inspection, repair, health
checks, DB-backed writes, or MemoryDB documentation work. The skill is the
portable operating procedure; the markdown files remain bootstrap and
public-safe recovery documentation.

## The Three Ways to Talk to the Assistant

A finished install should give the operator at least one of these access paths:

**LAN command chat:** a private local browser page for talking to the assistant on the same computer, LAN, or VPN.

**OpenClaw Control UI:** the official OpenClaw browser dashboard served by the Gateway.

**OpenClaw TUI:** the terminal UI that connects to the running Gateway.

**Zorg Memory 3D:** a local browser page that shows MemoryDB as an interactive
3D relationship map with an ADMIN page for graph settings.

Optional instant messaging channels such as Telegram, Signal, Discord, Slack, or WhatsApp are useful after they are configured. They are not the same as the LAN command chat; they travel through an outside provider.

## Step 1: Open the LAN Command Chat

Pick the row that matches the install type.

| Install type | Local browser address on the machine running it | From another device on the same LAN/VPN |
| --- | --- | --- |
| Standard Ubuntu / git branch overlay | `http://127.0.0.1:3001/` | `http://<server-lan-ip>:3001/` |
| Existing OpenClaw upgraded to Zorg branch | `http://127.0.0.1:3001/` when LAN chat is installed | `http://<server-lan-ip>:3001/` when LAN chat is installed |
| Docker Compose | `http://127.0.0.1:<selected-lan-chat-port>/` | `http://<server-lan-ip>:<selected-lan-chat-port>/` |
| Dockge | `http://127.0.0.1:<selected-lan-chat-port>/` | `http://<server-lan-ip>:<selected-lan-chat-port>/` |
| Docker run | `http://127.0.0.1:<selected-lan-chat-port>/` | `http://<server-lan-ip>:<selected-lan-chat-port>/` |

What this means:

`127.0.0.1` means this same computer.

`<server-lan-ip>` means the LAN address of the computer or server running OpenClaw/Zorg MemoryDB.

The current preferred path is the Standard Ubuntu / existing OpenClaw branch-overlay path. It publishes the LAN command chat directly on port `3001` by default when the LAN chat component has been installed.

Docker Compose, Dockge, and Docker run keep LAN command chat on internal container port `3001`, then publish it on the first free external host port from `8080-8180` by default.

Docker Compose and Dockge run the LAN command chat inside the same Docker Compose service/container named `openclaw` as OpenClaw/Zorg MemoryDB. `openclaw` is the service/container name, not the assistant name. They do not run a separate LAN chat container.

If the page asks for a password and you do not have one yet, continue to Step 2.

## Step 1B: Open the Zorg Memory 3D Brain Map

Standard Ubuntu and existing OpenClaw branch-overlay installs include the 3D
brain map as a native service:

```text
http://127.0.0.1:8097/
```

From another device on the same LAN or VPN, replace `127.0.0.1` with the server
LAN IP:

```text
http://<server-lan-ip>:8097/
```

The ADMIN settings page is:

```text
http://127.0.0.1:8097/admin
```

Use the brain map to inspect MemoryDB relationships, semantic nodes, recall
hints, runtime events, and graph activity. Use ADMIN to tune the graph history
window, node size, collision radius, vector size, packet behavior, and opacity.
See [`zorg-memory-3d.md`](zorg-memory-3d.md).

## Step 2: Ask OpenClaw to Create the First LAN Chat Password

The LAN command chat has a password gate. The password should be generated after install or after an upgrade, then sent to the operator through a private channel.

If an instant messaging channel is already configured, send the assistant a message there:

```text
Create or rotate the LAN command chat password, restart the LAN chat service if needed, and send me the new password here.
```

If the assistant email account is already configured, ask through email instead:

```text
Create or rotate the LAN command chat password and email it to the operator address.
```

If no messaging or email channel is available yet, use the OpenClaw TUI from Step 3 and ask the same thing there. That keeps the first password request inside the local OpenClaw install instead of sending it through an outside provider.

## Step 3: Open the OpenClaw TUI When No Other Channel Works

Standard Ubuntu:

```bash
openclaw tui
```

Docker Compose or Dockge, from the assistant folder or Dockge stack folder:

```bash
docker compose exec -it openclaw openclaw tui
```

Docker run:

```bash
cd ~/front-desk-assistant
INSTALL_ID="${PWD##*/}"
sudo docker exec -it "${INSTALL_ID}-zorg-memorydb" openclaw tui
```

What this does: opens the official OpenClaw terminal UI connected to the running Gateway. Ask it to create or rotate the LAN command chat password.

Do not use `openclaw chat` for the installed Gateway path. Official OpenClaw documents `openclaw chat` and `openclaw terminal` as aliases for `openclaw tui --local`, which is embedded local mode without the Gateway.

## Step 4: Manual Password Creation Fallback

Use this section only if you are operating the server yourself or the assistant cannot perform the password rotation for you.

Docker Compose or Dockge:

```bash
cd ~/my-ai-assistant
python3 scripts/generate_lan_chat_password.py --env-file .env
docker compose up -d --build openclaw
```

What this does: writes `LAN_CHAT_PASSWORD_HASH` and `LAN_CHAT_AUTH_SECRET` into `.env`, prints the one-time plaintext password, and rebuilds/restarts the same Docker Compose service/container named `openclaw`. The LAN command chat starts inside that container and reads the updated password settings.

Standard Ubuntu:

```bash
cd ~/front-desk-assistant
python3 scripts/generate_lan_chat_password.py --env-file lan-chat/.env.local
systemctl --user restart lan-chat.service
```

Docker run:

```bash
cd ~/front-desk-assistant
curl -fsSL https://raw.githubusercontent.com/StefRush2099/Zorg_MemoryDB/main/scripts/generate_lan_chat_password.py -o generate_lan_chat_password.py
python3 generate_lan_chat_password.py --env-file lan-chat.env
INSTALL_ID="${PWD##*/}"
sudo docker stop "${INSTALL_ID}-zorg-memorydb"
sudo docker rm "${INSTALL_ID}-zorg-memorydb"
sudo docker run -d --name "${INSTALL_ID}-zorg-memorydb" --restart unless-stopped --env-file lan-chat.env -p 18789-18889:18789 -p 8080-8180:3001 -v "$PWD/openclaw-home:/home/openclaw/.openclaw" ghcr.io/stefrush2099/zorg-memorydb:latest
```

What this does: writes the LAN chat password hash and cookie secret into `lan-chat.env`, replaces the container wrapper, keeps the same `openclaw-home/` state folder, and lets Docker select the first free external LAN chat port from `8080-8180`.

Only send the printed `LAN_CHAT_PASSWORD` through an approved private channel. Do not commit it, paste it into public issues, or store it in documentation.

## Step 5: Open the OpenClaw Control UI

OpenClaw's official Control UI is served by the Gateway. The default local address is:

```text
http://127.0.0.1:18789/
```

Docker Compose and Dockge may use the next free port in the configured range. From the assistant folder or Dockge stack folder, print the selected port:

```bash
docker compose port openclaw 18789
```

Print the selected LAN command chat port with:

```bash
docker compose port openclaw 3001
```

If this command prints nothing, or the printed port refuses connections, the Docker Compose/Dockge stack is not fully upgraded. Re-run the matching upgrade page and verify that `docker compose ps` shows an external host mapping for internal container port `3001`.

If Docker prints `0.0.0.0:18790`, open:

```text
http://127.0.0.1:18790/
```

OpenClaw may require device pairing or Gateway authentication for the Control UI. Official OpenClaw documents local loopback behavior, pairing approval, token/password auth, and Gateway options in the Control UI and Gateway docs linked at the top of this page.

## Step 6: Confirm It Works

After login, send a short LAN command chat message:

```text
Confirm you can hear me from the LAN command chat and tell me the current OpenClaw session name.
```

Expected result: the assistant replies in the LAN command chat, and future recall can see that local command chat traffic through the DB-backed memory path.

Then verify the brain map:

```bash
curl -fsS http://127.0.0.1:8097/api/health
curl -fsS http://127.0.0.1:8097/admin | grep -i 'Memory Brain Admin'
```

Expected result: the health endpoint returns JSON with `"ok":true`, and the
ADMIN page loads the adjustable graph settings.
