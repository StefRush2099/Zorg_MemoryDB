# Before You Get Started

Before installing Zorg MemoryDB, decide where it will run and collect the API keys/tokens for the features you plan to enable. The software can be installed first and connected later, but the agent becomes useful much faster when the account prep is done up front.

This guide is public-safe. Use it as a checklist, not as a place to store secrets. Never commit API keys, OAuth tokens, private database dumps, email contents, transcripts, contact data, or private operator context to this repository.

## 1. Choose where Zorg will run

You have two normal paths.

### Local PC or home/office server

Best when you want direct control, local storage, and lower ongoing hosting cost.

Have ready:

- a computer or VM that can stay on
- Ubuntu/Debian or Docker Desktop / Docker Engine
- Docker Compose
- enough disk for OpenClaw state, PostgreSQL memory, logs, screenshots, and backups
- a plan for off-host backups, ideally a private GitHub repository or other private remote storage

For Mac users, a small Ubuntu VM in VMware Fusion/Workstation/Proxmox/UTM is also reasonable.

### Hosted server / VPS / cloud

Best when you want a machine that is always online.

Common choices include AWS, Google Cloud, Azure, DigitalOcean, Hetzner, Hostinger VPS, or another Docker-capable host.

Have ready:

- a Linux server with SSH access
- Docker Engine and Compose, or permission to install them
- firewall/security group access for the OpenClaw port you intend to expose, or a Cloudflare Tunnel token
- a persistent disk/volume for `/home/openclaw/.openclaw`
- a private backup target for PostgreSQL memory dumps

If the server will be reachable from the public internet, prefer Cloudflare Tunnel or another controlled connector over directly exposing origin services.

## 2. LLM API key: minimum and recommended paths

Zorg/OpenClaw needs at least one model provider. Pick one before you start.

### Minimum path: OpenRouter

OpenRouter is a practical minimum configuration because one API key can route to many models, including low-cost or free-tier options when available.

Prepare:

1. Create an OpenRouter account.
2. Create an API key in OpenRouter settings.
3. Add billing/credits if the models you want require it.
4. Store the key only in the private runtime environment, not in Git.

Typical private environment variable:

```bash
OPENROUTER_API_KEY=sk-or-...
```

Useful official docs:

- OpenRouter API keys: https://openrouter.ai/settings/keys
- OpenRouter quickstart: https://openrouter.ai/docs/quickstart

### Recommended path: OpenAI API

For a dependable entry-level production setup, OpenAI API access is the recommended baseline. It is usually more predictable than trying to build a business assistant on whichever free model happens to be available.

Prepare:

1. Create or sign in to an OpenAI Platform account.
2. Add billing if required for the model you plan to use.
3. Create a project API key.
4. Store the key only in the private runtime environment.

Typical private environment variable:

```bash
OPENAI_API_KEY=sk-...
```

Useful official docs:

- OpenAI API keys: https://platform.openai.com/api-keys
- OpenAI quickstart: https://platform.openai.com/docs/quickstart

You can configure both OpenRouter and OpenAI. That gives you a fallback path if one provider is unavailable or if a task is better suited to a different model.

## 3. Messaging channel token

A useful agent needs a fast control channel. Telegram, Signal, WhatsApp, Discord, Slack, or another OpenClaw-supported channel can work.

Prepare:

1. Choose the messaging app you actually use.
2. Create the bot/app/integration in that service.
3. Copy the bot token/client secret into your private runtime environment.
4. Restrict allowed senders/admins where the platform supports it.
5. Send a test message before trusting the agent with important work.

Do not publish bot tokens or chat IDs in public docs.

## 4. Email access: Google, Microsoft, or another provider

For executive-assistant work, a dedicated assistant email account is strongly recommended. Personal inbox access can be added later with stricter rules.

### Google / Gmail

Use OAuth for Gmail when possible.

Prepare:

1. Create or choose the assistant Gmail/Google Workspace account.
2. In Google Cloud Console, create/select a project.
3. Enable the Gmail API.
4. Configure the OAuth consent screen.
5. Create OAuth client credentials, usually a Desktop app or Web app depending on your runtime flow.
6. Authorize the account and generate/store a refresh token in the private runtime environment.
7. Test read/send with a harmless message.

Typical private values:

```bash
GOOGLE_OAUTH_CLIENT_ID=...
GOOGLE_OAUTH_CLIENT_SECRET=...
GOOGLE_OAUTH_REFRESH_TOKEN=...
GOOGLE_MAILBOX_EMAIL=assistant@example.com
OPERATOR_CC_EMAIL=operator@example.com
```

Important: if the agent sends email as an executive assistant, configure an operator copy address. Outbound assistant email should visibly CC the operator by default unless the operator gives a message-specific exception.

Useful official docs:

- Gmail API overview: https://developers.google.com/gmail/api/guides
- Google OAuth 2.0 overview: https://developers.google.com/identity/protocols/oauth2
- Google Cloud OAuth client setup: https://support.google.com/cloud/answer/15549257

### Microsoft / Outlook / Microsoft 365

Use Microsoft Entra app registration and Microsoft Graph permissions.

Prepare:

1. Create or choose the assistant mailbox.
2. Register an application in Microsoft Entra admin center.
3. Add Microsoft Graph permissions for the mail operations you need.
4. Create a client secret or certificate.
5. Complete admin/user consent as required by your tenant.
6. Generate and store refresh/client credentials privately.
7. Test read/send with a harmless message.

Typical private values vary by implementation, but commonly include:

```bash
MICROSOFT_TENANT_ID=...
MICROSOFT_CLIENT_ID=...
MICROSOFT_CLIENT_SECRET=...
MICROSOFT_REFRESH_TOKEN=...
MICROSOFT_MAILBOX_EMAIL=assistant@example.com
OPERATOR_CC_EMAIL=operator@example.com
```

Useful official docs:

- Microsoft Graph authentication: https://learn.microsoft.com/graph/auth/
- Microsoft identity platform OAuth 2.0: https://learn.microsoft.com/entra/identity-platform/v2-oauth2-auth-code-flow
- Microsoft Graph mail API: https://learn.microsoft.com/graph/api/resources/mail-api-overview

### Other mail providers

Some providers support app passwords, SMTP/IMAP, or their own OAuth flow.

Prepare:

- a dedicated assistant mailbox
- SMTP/IMAP or API credentials
- app password or OAuth token if required
- sending limits and anti-spam rules
- an operator CC rule for outbound assistant mail

Do not use a personal password directly when an app password or OAuth token is available.

## 5. GitHub access

Zorg MemoryDB uses GitHub in two different ways:

1. Public or private code/docs repository access.
2. Private off-host recovery backups for PostgreSQL memory dumps.

Prepare:

1. Create/sign in to a GitHub account.
2. Create any private repository you will use for backups.
3. Create a fine-grained personal access token or GitHub App token with the least permissions needed.
4. Store the token privately.
5. Test clone/push with a harmless README update or test branch.

Typical private environment variables:

```bash
GITHUB_TOKEN=ghp_or_fine_grained_token
GITHUB_BACKUP_REPO=github.com/you/private-openclaw-backups.git
```

Recommended backup path inside the private repo:

```text
backups/postgres/openclaw/
```

Never push full PostgreSQL dumps, transcripts, contact records, private operator memory, or credentials to the public `Zorg_MemoryDB` repository.

Useful official docs:

- GitHub personal access tokens: https://docs.github.com/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
- GitHub fine-grained token creation: https://docs.github.com/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
- GitHub Apps authentication: https://docs.github.com/apps/creating-github-apps/authenticating-with-a-github-app

## 6. Optional but strongly useful: Cloudflare Tunnel

If the agent will publish dashboards, reports, websites, or webhook endpoints, set up Cloudflare Tunnel or an equivalent connector.

Prepare:

1. Cloudflare account and domain/DNS control if needed.
2. A tunnel created in Cloudflare Zero Trust.
3. A tunnel token stored privately.
4. A Docker/Dockge service for `cloudflared`.
5. A list of local services that are approved to expose.

Typical private environment variable:

```bash
CLOUDFLARE_TUNNEL_TOKEN=...
```

Useful official docs:

- Cloudflare Tunnel get started: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/
- Run tunnel in Docker: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/#docker

## 7. Docker and Dockge visibility

For most users, Docker Compose is the practical baseline. Dockge is recommended when the operator wants a simple web UI to see, start, stop, and update stacks.

Prepare:

- Docker Engine
- Docker Compose plugin
- an install folder such as `/opt/stacks/zorg_memorydb` on Linux hosts
- optional Dockge stack manager
- a persistent OpenClaw/Zorg volume

Useful official docs:

- Docker Engine install: https://docs.docker.com/engine/install/
- Docker Compose: https://docs.docker.com/compose/
- Dockge: https://github.com/louislam/dockge

## 8. Pre-install checklist

Before you run the installer, you should know:

- [ ] Where Zorg will run: local PC/VM, home server, VPS, or cloud host.
- [ ] Which model provider you will start with: OpenRouter minimum, OpenAI recommended, or both.
- [ ] Where the provider API keys will be stored privately.
- [ ] Which messaging channel will be used for day-to-day control.
- [ ] Whether a dedicated assistant email account will be connected.
- [ ] Whether Google/Gmail OAuth, Microsoft Graph OAuth, or another mail credential path is needed.
- [ ] What operator email should be visibly CC'd on outbound assistant email.
- [ ] Which GitHub account/repo/token will be used for code/docs and private backups.
- [ ] Whether Cloudflare Tunnel or another connector will expose approved services.
- [ ] Where PostgreSQL memory backups will be stored off-host.
- [ ] Who is allowed to command the agent.

## 9. Secret-handling rules

Use `.env` or a private secret manager for real values. The repository should contain placeholders only.

Safe to commit:

- variable names
- setup instructions
- sanitized templates
- public docs
- schema templates

Never commit:

- API keys
- OAuth client secrets or refresh tokens
- GitHub tokens
- Cloudflare tunnel tokens
- mailbox contents
- database dumps
- live private rows
- transcripts
- contact exports
- private operator strategy/context

A useful assistant has access to valuable systems. Treat the credential setup as part of the security design, not as an afterthought.

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

