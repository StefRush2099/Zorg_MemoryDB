# Docker Compose Upgrade

Use this page only when the assistant was installed by cloning this repository into an assistant folder and starting it with Docker Compose.

If SSH, terminals, `cd`, or Linux paths are unfamiliar, read [`beginner-terminal-and-ssh.md`](beginner-terminal-and-ssh.md) first.

Example assistant folder:
```text ~/my-ai-assistant/ ```

In this install type, the assistant folder contains the instructions Docker Compose reads. Docker Compose runs the assistant inside a service named `openclaw`; that is only the service/container name, not the assistant name. The data you must protect is the `openclaw-home/` folder inside the assistant folder.

This upgrade replaces the container build and overlay files. It should not replace the `openclaw-home/` state folder.

## Step 1: Enter the Assistant Folder

```bash cd ~/my-ai-assistant ```

What this does: moves the terminal into the assistant folder. This is the folder created by the final part of the `git clone` command. It contains `docker-compose.yml`, which is the file Docker Compose reads when it starts or upgrades the assistant.

## Step 2: Confirm the State Folder Exists

```bash test -d openclaw-home ```

What this does: checks that `openclaw-home/` exists. That folder is the assistant's persistent OpenClaw home. It holds OpenClaw state, workspace files, embedded PostgreSQL data, and DB memory. If this command prints nothing and returns to the prompt, the folder exists.

Do not delete `openclaw-home/`. The upgrade is meant to replace the container wrapper, not the assistant's memory.

## Step 3: Download the Updated Overlay Files

```bash git pull --ff-only ```

What this does: downloads the latest Zorg MemoryDB overlay files into the assistant folder. This updates documentation, scripts, the Dockerfile, and Compose files. The `--ff-only` part tells Git to stop instead of trying to merge unexpected local edits.

## Step 4: Rebuild the Docker Image Without Cache

```bash docker compose build --pull --no-cache --build-arg OPENCLAW_VERSION=latest openclaw ```

What this does: rebuilds the Docker Compose service named `openclaw` from the updated files and forces Docker to fetch fresh base-image and `openclaw@latest` layers. This matters because plain `docker compose up -d --build` may reuse Docker's cached `npm install -g openclaw@latest` layer and leave the old OpenClaw package inside the rebuilt container.

This command rebuilds the image only. It does not delete `openclaw-home/`.

## Step 5: Restart the Same Docker Compose Service

```bash docker compose up -d --force-recreate openclaw ```

What this does: replaces the running container with the cleanly rebuilt image while keeping the same `openclaw-home/` state folder mounted into it.

## Step 6: Verify the Upgrade

```bash docker compose ps ```

What this does: shows whether the Compose services are running. It also shows which external host ports Docker selected for OpenClaw Gateway and LAN command chat. The Gateway listens on internal container port `18789`; LAN command chat listens on internal container port `3001`.

If the `PORTS` column does not show a host mapping for both `18789` and `3001`, the upgrade is not complete. Pull the current stack files again, rebuild without cache, and recreate the same `openclaw` service before reporting success. Older stack files may expose the Gateway while leaving LAN command chat unreachable.
```bash docker compose exec openclaw openclaw --version ```

What this does: prints the OpenClaw version inside the running container so you can confirm the container is not still using an old cached package.
```bash docker compose port openclaw 3001 ```

What this does: prints the selected external LAN command chat port. Docker chooses the first free host port from `8080-8180`, so a second assistant on the same Docker host can use the next available port while still keeping LAN chat inside its own Compose service/container named `openclaw`.

Verify the printed LAN command chat address from the Docker host and from the LAN before claiming the upgrade is finished:
```bash LAN_CHAT_URL="http://$(docker compose port openclaw 3001)" curl -fsS "$LAN_CHAT_URL/api/chat/status" ```

What this does: proves the external host port selected by Docker reaches the real LAN command chat process inside the running container. A refused connection or empty `docker compose port openclaw 3001` result means the Compose stack is still missing the current LAN chat port publication.
```bash docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432' ```

What this does: checks whether PostgreSQL is answering inside the running `openclaw` container.
```bash docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5' ```

What this does: verifies database-backed recall inside the container. Expected mode: `database-direct-vector-neural-weighted`.
```bash docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables' docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py refresh' docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/db_only_memory_autoheal.py' ```

What this does: confirms the SQL memory tables are reachable, refreshes the materialized recall surfaces, and runs DB-only memory auto-heal. If any command fails, inspect the container logs before reporting the upgrade healthy:
```bash docker compose logs --tail=200 openclaw ```
```bash docker compose exec openclaw openclaw doctor ```

What this does: runs OpenClaw diagnostics from inside the running container.

Do not report a Docker Compose upgrade as verified unless the live Gateway, the selected external LAN chat port, and database-backed recall all respond on the real runtime surface.
