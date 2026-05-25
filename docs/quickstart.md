# Quickstart: OpenClaw + Zorg MemoryDB

Zorg MemoryDB is installed as a branch or fork of the original `openclaw/openclaw` repository. Do not install it as a separate application folder. The source checkout is OpenClaw itself, and the runtime home/workspace remain OpenClaw's normal folders.

## Native Git Install

Clone the OpenClaw fork or branch that contains Zorg MemoryDB:

```bash
git clone https://github.com/<your-account>/openclaw.git "$HOME/openclaw"
cd "$HOME/openclaw"
git checkout zorg-memorydb
```

Install OpenClaw from that same checkout with OpenClaw's official git installer:

```bash
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --install-method git --git-dir "$HOME/openclaw" --version zorg-memorydb --no-onboard
```

The installer path is the same one OpenClaw documents for source/git installs. Zorg MemoryDB belongs on that OpenClaw branch, not in `~/Zorg_MemoryDB`, `~/.openclaw/workspace/Zorg_MemoryDB`, or another long-lived folder.

## Runtime Workspace

OpenClaw's runtime home stays at:

```text
$HOME/.openclaw
```

OpenClaw's runtime workspace stays at:

```text
$HOME/.openclaw/workspace
```

Zorg MemoryDB runtime files, DB recall configuration, rule templates, and LAN command chat support are applied into that OpenClaw runtime path by the branch install.

## Verify

```bash
openclaw --version
openclaw doctor
openclaw gateway status
cd "$HOME/.openclaw/workspace"
.venv-sqlmem/bin/python scripts/memory_sql_tool.py tables
.venv-sqlmem/bin/python scripts/memory_recall_router.py "openclaw database memory" --limit 5
```

Expected recall mode: `database-direct-structured` or a newer database-direct mode.

## What You Should Not Do

Do not clone `Zorg_MemoryDB` as the install target. Do not make a second assistant folder for native installs. Do not put the MemoryDB repo under the OpenClaw workspace as `Zorg_MemoryDB/`. The branch is OpenClaw.
