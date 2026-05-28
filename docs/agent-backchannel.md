# Agent Backchannel Sidecar

The agent backchannel is an optional standalone sidecar for local agent-to-agent messages. It is intentionally separate from LAN command chat so OpenClaw package updates, LAN chat UI changes, or port 80/3001 routing changes do not remove the basic coordination path.

Default local deployment:

Service name: `agent-backchannel.service`

Listen address: `0.0.0.0`

Port: `3099`

Health endpoint: `GET http://<openclaw-lan-ip>:3099/health`

Send endpoint: `POST http://<openclaw-lan-ip>:3099/messages`

Recent-message endpoint: `GET http://<openclaw-lan-ip>:3099/messages`

Self URL: `BACKCHANNEL_SELF_URL=http://<this-agent-lan-ip>:3099`

Peer fan-out: `BACKCHANNEL_PEERS=http://<peer-1>:3099,http://<peer-2>:3099`

OpenClaw session key: `agent:main:agent-backchannel`

Durable local log: `~/.openclaw/backchannel-data/messages.jsonl`

Message body:
```json { "from": "agent-name", "message": "Message text for Zorg" } ```

The service accepts only loopback and private LAN source addresses. Every accepted message is appended to the JSONL log before gateway forwarding, so the backchannel still preserves the inbound note if the OpenClaw gateway is temporarily unavailable.

The backchannel is a directed agent-to-agent communication channel, not a general activity broadcast stream. Use it only when the operator explicitly directs use of the backchannel, when the operator asks one agent to use other agents to get work done, or when an agent contacts another agent for information the operator authorized it to retrieve. Do not post routine status, implementation steps, verification details, or completion summaries into the backchannel by default.

When a valid backchannel message does occur, it must be mirrored into the LAN command chat on every receiving agent. The backchannel is the transport/intake path; LAN command chat remains the operator-visible command surface and should receive the filtered content of backchannel messages. Peer-delivered messages must still be injected into the receiving agent's LAN command chat, but must not fan out again.

For multidirectional agent communication, run the same sidecar on every agent host and configure `BACKCHANNEL_PEERS` with every other agent backchannel URL. Original inbound messages are forwarded to all configured peers. Peer-delivered messages include `peerDelivery: true` and are not fanned out again, which prevents message loops while still logging and forwarding the message into each agent's local command path.

In Docker/Dockge installs, pass the same private Gateway token and LAN-chat auth secret into the sidecar. If direct Gateway forwarding rejects the requested scope, the sidecar falls back to the local LAN command chat API and feeds the message into the same command-chat path that has already been verified. This is still additive: LAN chat remains the command surface, while the sidecar remains the LAN-only intake path for agent-to-agent notes.

This sidecar must remain additive:

Do not replace LAN command chat.

Do not change LAN chat authentication, routing, or ports to install it.

Do not store gateway tokens in the repository.

Do not expose the endpoint to the public internet.

Verify the live health endpoint, POST flow, systemd status, and JSONL append

before reporting the backchannel as working.

For multi-agent setups, verify `GET /health` and a real `POST /messages` from

at least one remote LAN host to every peer endpoint.

The reference implementation lives in `agent-backchannel/`.
