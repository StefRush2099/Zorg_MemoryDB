# Standard Ubuntu Upgrade

Use this page only when the assistant was installed with the Standard Ubuntu one-line installer.

If SSH, terminals, `cd`, or Linux paths are unfamiliar, read [`beginner-terminal-and-ssh.md`](beginner-terminal-and-ssh.md) first.

This page upgrades a native Ubuntu install. Native means OpenClaw is installed directly on Ubuntu, not inside a Docker container. The assistant folder stores the Zorg MemoryDB overlay scripts and memory wiring.

Example assistant folder:
```text ~/front-desk-assistant/ ```

## Step 1: Check OpenClaw Before Changing Anything

```bash openclaw update --dry-run ```

What this does: asks OpenClaw what it would update without applying changes.
```bash openclaw doctor ```

What this does: runs OpenClaw's built-in diagnostic checks before the upgrade.

## Step 2: Run the Upstream OpenClaw Upgrade

```bash openclaw update ```

What this does: uses OpenClaw's official updater to refresh the installed OpenClaw runtime while preserving its state.
```bash openclaw doctor ```

What this does: checks the upgraded OpenClaw install.

## Step 3: Enter the Assistant Folder

```bash cd ~/front-desk-assistant ```

What this does: moves the terminal into the assistant folder created by the installer. If you chose a different assistant name during install, use that folder name instead.

## Step 4: Verify Zorg MemoryDB Recall

```bash sudo git pull --ff-only ```

What this does: downloads the latest Zorg MemoryDB overlay files into the assistant folder. `sudo` is used here because the Standard Ubuntu installer may have created or repaired this folder with administrator ownership. The `--ff-only` part tells Git to stop instead of trying to merge unexpected local edits.
```bash test -f sql_memory_map.json ```

What this does: confirms the folder still contains the database-memory wiring file.
```bash .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5 ```

What this does: asks Zorg MemoryDB to recall from the database. Expected mode: `database-direct-vector-neural-weighted`.

## Step 5: Restart the Gateway if Needed

```bash source .env.native ```

What this does: loads the saved Gateway settings from the native install.
```bash OPENCLAW_WORKSPACE=$PWD SQL_MEMORY_MAP=$PWD/sql_memory_map.json openclaw gateway run --allow-unconfigured --bind "$OPENCLAW_GATEWAY_BIND" --port "$OPENCLAW_GATEWAY_PORT" --auth "$OPENCLAW_GATEWAY_AUTH" ```

What this does: starts OpenClaw from the assistant folder using the same memory map and Gateway settings created during install.

## If You Are Repairing an Existing Plain OpenClaw Workspace

Most users should not need this from the Standard Ubuntu page. If OpenClaw was already installed before Zorg MemoryDB, use [Existing OpenClaw install upgrade](upgrade-existing-openclaw.md).
