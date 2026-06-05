# Recommended Base Setup for a Useful OpenClaw + Zorg MemoryDB Install

Zorg MemoryDB is most useful when it is not only installed as a local agent, but connected to the communication, backup, and publishing surfaces that let an assistant actually operate for you. Before installation, gather the provider keys and account tokens in [`before-you-get-started.md`](before-you-get-started.md).

Plain OpenClaw can run with very little connected. That is useful for testing. A working executive-assistant style agent needs a fuller base setup:

1. The built-in LAN/local command chat where you can reach the local agent from a normal browser page.
2. An optional instant messaging channel where you can reach the agent quickly when away from the LAN.
3. A dedicated assistant email account that becomes the public-facing assistant identity.
4. Optional, carefully governed access to your personal email account for triage and drafting.
5. A private GitHub repository or other private off-host backup target for database recovery.
6. A Cloudflare Tunnel/connector so the agent can publish web-accessible pages and services without opening inbound ports.
7. Dockerized services on the same system that runs OpenClaw/Zorg where practical.
8. Dockge or an equivalent Docker stack UI so less technical operators can see, stop, start, and update the moving pieces.

This is the practical baseline before OpenClaw + Zorg MemoryDB starts feeling fully useful rather than merely installed.

## Base architecture

Recommended single-host layout:

```text
Ubuntu/Debian host
├─ Docker Engine + Docker Compose plugin
├─ Dockge web UI
│  ├─ zorg_memorydb / openclaw container
│  ├─ cloudflared tunnel container
│  ├─ optional website/static publishing containers
│  └─ optional support containers
├─ OpenClaw/Zorg folder-local home (`openclaw-home/`)
│  ├─ PostgreSQL-backed Zorg MemoryDB state
│  ├─ channel credentials and config
│  ├─ email OAuth/app credentials
│  └─ backup scripts/verification
└─ Private off-host backup target
   └─ private GitHub repo, private Git remote, or another encrypted/off-host store
```

Keep the baseline services visible in Dockge when possible. The point is not only convenience; it makes the system easier to operate. A non-specialist should be able to open one web page, see the OpenClaw/Zorg stack, see the Cloudflare connector, and stop/start/update services without memorizing shell commands.

## 1. LAN/local command chat: the private first control surface

Zorg MemoryDB includes a local web command chat (`lan-chat`) by default. This should be the first control surface available on the network where the agent is running. It gives the operator a normal browser page for talking to the agent without SSH, terminal commands, raw API calls, or an outside chat provider.

This matters for security and privacy. Telegram, Discord, Slack, Signal gateways, WhatsApp connectors, and similar integrations are useful, but they route private prompts through another provider, account, bot token, app, device, metadata trail, and retention boundary before the text reaches the agent. That may be acceptable for convenience, but it should not be mandatory for private local work. If the operator is on the same LAN or VPN as the agent, sensitive conversations can often remain entirely inside local infrastructure.

The local console is also the better expectation for nontechnical users. They should not have to memorize a command line or type API calls just to use their own assistant. Future versions can add stronger front-end security such as passwords, tokens, device pairing, HTTPS, access roles, connection audit views, and friendlier discovery/setup flows while preserving the same local-first architecture.

Use instant messaging as a remote/mobile convenience layer, not as the only practical way to speak to the agent.

## 2. Instant messaging channel: the fast remote control surface

Connect Zorg/OpenClaw to Telegram, WhatsApp, Signal, Discord, Slack, or another instant messaging app you actually use.

This channel is a remote/mobile control surface:

- send quick tasks from your phone
- approve sensitive actions
- receive alerts only when something matters
- ask status questions without opening a terminal
- interact with the assistant while away from the server

Telegram is a good first choice because bot setup is straightforward and it works well as a direct-message command surface. WhatsApp, Signal, Discord, Slack, or another supported channel may be better if that is where you already live.

General setup pattern:

1. Create a bot/app/integration in the messaging platform.
2. Store the token/secret only in the local OpenClaw/Zorg environment or secret store.
3. Configure OpenClaw's messaging provider for that channel.
4. Restrict allowed senders/admins where the channel supports it.
5. Send a test message and verify the assistant can reply.
6. Record the safe, non-secret setup notes in memory or docs; never publish the token.

For a production personal assistant, use direct-message authorization and least privilege. Do not expose a public group chat as an admin surface unless you intentionally want that behavior.

## 3. Dedicated assistant email: the recommended public-facing identity

A dedicated assistant email account is not merely a fallback. It is the recommended public-facing executive-assistant identity.

The goal is that people no longer need your personal email address for routine communication. They email the assistant identity instead, and the agent filters, triages, drafts, replies, schedules, escalates, and remembers the relationship context.

Example pattern:

```text
assistant@example.com
Executive Assistant to <Your Name>
```

Use the dedicated assistant email for:

- public contact pages
- introductions
- scheduling requests
- inbound vendor/customer/family coordination
- newsletters or sources the agent should monitor
- outbound notes where the assistant is the right sender
- a durable searchable communication identity separate from the operator's private inbox

Benefits:

- protects the operator's personal email address
- gives the AI agent a stable professional identity
- creates a clean boundary between assistant-handled mail and private personal mail
- makes it easier to revoke/rebuild credentials without touching the operator's main account
- improves trust because recipients interact with a consistent executive-assistant address
- lets memory rules attach to contact history, reply permissions, CC/BCC behavior, and business-hours timing

Recommended behavior:

1. Create a dedicated email account for the assistant.
2. Configure OAuth or app-password access according to the email provider's safest supported method.
3. Store credentials locally/private only.
4. Use rich HTML email with a plain-text fallback by default.
5. Add a clear signature with the assistant's name, role, and preferred contact method.
6. Configure a required operator CC address, for example with `OPERATOR_CC_EMAIL` in the private runtime environment, so every outbound assistant email visibly copies the operator by default.
7. Let the assistant triage and reply within explicit rules.
8. Keep sensitive operator context private; use it only as a silent filter for tone, timing, and escalation.

The operator-copy rule is important. If the agent is acting as an executive assistant, the operator must be able to see what it is sending. The LLM should recall the current copy rule before sending. A mechanical send helper may verify and serialize the LLM-selected copy fields, but it should not independently decide recipient-specific CC/BCC policy.

## 4. Personal email access: useful, but not the default public address

Direct access to the operator's personal email can be powerful, but it should be treated differently from the dedicated assistant email.

Recommended default:

- give people the assistant email address
- let the assistant manage that inbox as the main communication surface
- optionally grant carefully scoped access to the operator's personal email for triage, search, drafting, and escalation

Personal email access should be governed with stricter rules:

- read/triage is safer than unrestricted sending
- money/funds requests should require human review
- new contacts or changed addresses should require confirmation
- outbound replies should follow business-hours and privacy rules
- sensitive personal mail should be summarized minimally or escalated rather than broadly processed

This gives you the benefit of an AI executive assistant without turning the operator's private inbox into the public-facing address.

## 5. Temporary local database rollback backups

Zorg MemoryDB's database is operational memory. Losing it means losing rules, decisions, contact context, recovery paths, and accumulated working knowledge.

Production structural changes must first create and verify a temporary local PostgreSQL backup. Do not commit, mirror, or push database dumps to GitHub from the public MemoryDB update path. Temporary rollback dumps should be purged after verification.

Recommended pattern:

```text
/home/openclaw/.openclaw/backups/postgres/tmp/
├─ zorgdb-YYYY-MM-DD_HHMMSS.sql.gz
└─ zorgdb-schema-YYYY-MM-DD_HHMMSS.sql.gz
```

Rules:

- keep DB dumps local/private and temporary unless the operator separately approves an encrypted/off-host recovery process
- never publish dumps, rows, transcripts, credentials, contacts, or private operator context to GitHub from the public `Zorg_MemoryDB` update path
- verify that backups are restorable, not merely created
- run backups before production database/index/schema/recall-routing changes
- keep public docs and schema templates separate from private recovery data

Example high-level flow:

```bash
# Run the install's backup script.
./scripts/postgres_memory_backup.sh
```

For a fresh install, verify the local rollback path before the system becomes important. Off-host recovery can be designed later as a separately approved private operations process.

## 6. Cloudflare connector: web-accessible publishing surface

A useful assistant eventually needs to publish things the operator can open from anywhere: status pages, reports, dashboards, temporary review pages, public articles, private web tools, or webhook endpoints.

Cloudflare Tunnel is a practical default for this because `cloudflared` runs on your server and creates outbound-only connections to Cloudflare. Cloudflare's current docs describe this as avoiding public IP exposure and not requiring inbound ports or firewall changes. The official Docker form is also simple: run the `cloudflare/cloudflared` image with a tunnel token.

Recommended role for Cloudflare in a Zorg setup:

- expose selected local web services through stable URLs
- let Zorg publish pages/reports without asking the operator to set up port forwarding
- provide remotely accessible review links
- keep origin services private behind the tunnel when possible
- centralize DNS/tunnel management in a known operator-approved account

Recommended Docker Compose/Dockge service pattern:

```yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TUNNEL_TOKEN}
    environment:
      TUNNEL_TOKEN: ${CLOUDFLARE_TUNNEL_TOKEN}
```

Store `CLOUDFLARE_TUNNEL_TOKEN` in `.env` or a secret store, never in public docs or commits.

A common remotely-managed setup flow:

1. Add your domain to Cloudflare.
2. In Cloudflare Zero Trust, create a Tunnel.
3. Choose Docker as the connector environment.
4. Copy the generated token into the private `.env` for the Dockge stack.
5. Start the `cloudflared` container in Dockge.
6. Add public hostnames/routes in Cloudflare for the services Zorg should publish.
7. Test the URL externally.
8. Record only public-safe route names and runbook steps; keep tokens private.

Cloudflare should not become an uncontrolled public exposure surface. Only publish routes that are intentionally public or protected by the appropriate Cloudflare Access/security policy.

Official references:

- Cloudflare Tunnel overview: <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/>
- Cloudflare Tunnel dashboard setup: <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel/>
- cloudflared downloads and Docker image reference: <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/downloads/>

## 7. Docker + Dockge: visibility for the whole assistant stack

Zorg MemoryDB can run with plain Docker or Docker Compose, but Dockge is a strong recommendation for less technical users and for operator visibility.

Dockge gives you a simple web UI for Docker Compose stacks. That matters because a useful assistant may eventually depend on several local services:

- OpenClaw/Zorg MemoryDB
- Cloudflare Tunnel connector
- website or report publishing container
- local database or support services
- optional task-specific tools

Recommended principles:

- keep stack names lowercase and predictable, such as `zorg_memorydb`
- keep related services on the same host where practical
- prefer one visible Dockge stack per major service group
- use `.env` for local secrets and never commit it
- keep persistent state folder-local, normally `./openclaw-home` beside `docker-compose.yml`
- restart with `unless-stopped`
- verify service health after changes

Example Dockge stack shape:

```yaml
name: zorg_base

services:
  openclaw:
    image: ghcr.io/stefrush2099/zorg-memorydb:latest
    restart: unless-stopped
    ports:
      - "18789-18889:18789"
    volumes:
      - ./openclaw-home:/home/openclaw/.openclaw

  cloudflared:
    image: cloudflare/cloudflared:latest
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TUNNEL_TOKEN}

```

The exact stack may vary, but the goal should stay the same: make the working assistant visible, restartable, and understandable from one local operations page.

## Recommended readiness checklist

A Zorg/OpenClaw install should not be considered fully useful until most of this checklist is complete:

- [ ] OpenClaw/Zorg MemoryDB starts cleanly.
- [ ] DB-backed recall verifies as `database-direct-structured`.
- [ ] At least one instant messaging channel works for quick operator control.
- [ ] A dedicated assistant email account exists and can send/receive safely.
- [ ] The assistant identity/signature is configured.
- [ ] A required operator CC address is configured for outbound assistant email.
- [ ] Personal email access, if enabled, is governed separately and not treated as the public address.
- [ ] Local PostgreSQL backups run and are verified.
- [ ] Private/off-host database backup storage exists.
- [ ] Cloudflare Tunnel or equivalent remote publishing connector is configured.
- [ ] Public routes are intentional and protected where needed.
- [ ] Dockge or equivalent service visibility is available.
- [ ] Secrets are kept out of public repos and docs.
- [ ] Recovery and verification commands are documented.

## Why this baseline matters

The database gives the agent continuity. Messaging gives it reachability. The dedicated email gives it a professional public identity. Private backups protect its memory. Cloudflare gives it a controlled way to publish and expose useful web surfaces. Docker and Dockge make the whole thing visible enough for humans to operate.

Together, those components turn OpenClaw + Zorg MemoryDB from a local experiment into a practical personal executive-assistant system.

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

<!-- LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->
## LLM-Governed Performance Tuning Rule

Database and memory performance tuning must be governed by live LLM judgment, not hidden script policy. Tuning work starts with a natural-language hypothesis formed from current system evidence and internet/authoritative research. If research gives a credible reason to believe a database design, recall-path, materialized-view, vector/neural association, or query-structure change will improve performance, the LLM must run side-by-side before/after measurements on representative queries before claiming success.

If research does not support a design change, move to raw additive performance work: indexes, query-path improvements, materialized/search-support views, relationships, recall hints, semantic edges, weighted connections, token/FTS/trigram support, and other non-destructive logic that brings query times down while preserving all source memory. No original memory data may be pruned, deleted, truncated, compacted away, or aged out for speed.

Every meaningful tuning change must record the research basis, before/after benchmark results, changed structures, rollback path, and follow-up indexing/hinting implications in durable memory and public-safe docs when structural behavior changes.
<!-- /LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->

<!-- GO_ONLY_APPROVAL_RULE -->
## GO-Only Approval Rule

When Stefan gives a command that requires confirmation before execution, ask only for `GO`. Do not invent longer approval phrases, magic words, task-specific confirmations, or exact response strings such as `GO REIP ...`, `GO SCORCHED ...`, or any other expanded form. Stefan decides how to respond; the assistant may request only the simple approval token `GO`.

If the requested action is unsafe, ambiguous, destructive, externally risky, or missing a necessary decision, explain the blocker or the exact intended change briefly, then end with only `GO` as the approval request when approval is the only thing needed. Never require Stefan to repeat the task, include extra words, or match an assistant-authored phrase.
<!-- /GO_ONLY_APPROVAL_RULE -->

<!-- SAME_DAY_NEWS_FRESHNESS_RULE -->
## Same-Day News Freshness Rule

When writing multiple news articles or public reports on the same day, do not repeat the same information from article to article. Adjacent or continuing stories may reference earlier context only briefly when necessary, but each article must add fresh facts, new framing, new implications, new examples, or a clearly advanced continuation that was not already covered in earlier same-day articles.

Before drafting or publishing a new article, review the same-day feed/archive and compare titles, summaries, body claims, examples, and links. If information has already been used that day, either omit it, compress it to a short bridge, or explicitly advance it with new developments. Maintain editorial continuity without recycling paragraphs, talking points, examples, or conclusions.

The assistant owns the full article set and must keep the day’s coverage fresh, non-repetitive, and additive.
<!-- /SAME_DAY_NEWS_FRESHNESS_RULE -->

## Permanent engineering rules

System changes, code writing, and software changes are governed by permanent base-install rules, not personal preferences. See [`base-install-permanent-engineering-rules.md`](base-install-permanent-engineering-rules.md). Zorg MemoryDB must be installed/upgraded as an additive OpenClaw overlay that preserves existing OpenClaw behavior and user data unless an explicit migration says otherwise.
