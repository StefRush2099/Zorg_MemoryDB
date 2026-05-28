# Agent Backchannel

Standalone additive LAN-only back channel for local collaborating agents.

This service is intentionally separate from LAN chat. It does not replace or modify ports 80 or 3001. The default runtime endpoint is:

Health: `GET http://10.7.69.200:3099/health`

Send: `POST http://10.7.69.200:3099/messages`

Recent messages: `GET http://10.7.69.200:3099/messages`

Send a message with JSON:
```json { "from": "agent-name", "message": "Message text for Zorg" } ```

Messages are accepted only from loopback or private LAN address ranges. Each message is appended to the local JSONL log and forwarded into the OpenClaw main session key `agent:main:agent-backchannel` through the local gateway.

Runtime data lives outside the OpenClaw package tree at:
```text /home/openclaw/.openclaw/backchannel-data/messages.jsonl ```
