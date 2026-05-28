# Dockge Upgrade

Use this page only when upgrading the OpenClaw/Zorg assistant stack that is managed by Dockge.

This page does not upgrade the host Docker Engine or the Dockge manager container itself. For that infrastructure path, use [`upgrade-host-docker-dockge.md`](upgrade-host-docker-dockge.md).

If SSH, terminals, `cd`, or Linux paths are unfamiliar, read [`beginner-terminal-and-ssh.md`](beginner-terminal-and-ssh.md) first.

Example Dockge stack folder:
```text /opt/stacks/front-desk-assistant/ ```

Dockge is a web interface for managing Docker Compose stacks. The stack still uses a `docker-compose.yml` file, but Dockge gives you buttons for starting, stopping, and redeploying it.

In this install type, the Dockge stack folder is the assistant folder. The data you protect is the `openclaw-home/` folder inside that stack folder.

## Step 1: Open the Dockge Stack Folder

```bash cd /opt/stacks/front-desk-assistant ```

What this does: moves the terminal into the Dockge stack folder for this assistant. This folder contains `docker-compose.yml`, and Dockge uses that same file when it deploys the stack.

## Step 2: Confirm the State Folder Exists

```bash test -d openclaw-home ```

What this does: confirms the persistent state folder exists. `openclaw-home/` is where OpenClaw state, workspace files, embedded PostgreSQL data, and DB memory live for this stack.

Do not delete `openclaw-home/`. Redeploy the stack around it.

## Step 3: Download the Updated Stack Files

```bash sudo git pull --ff-only ```

What this does: downloads the updated Zorg MemoryDB overlay files into the Dockge stack folder. `sudo` is used because Dockge stacks commonly live under `/opt/stacks`, which may require administrator permission. The `--ff-only` part tells Git to stop if the local folder has unexpected edits that need human review.

## Step 4: Rebuild the Stack Image Without Cache

In the Dockge stack terminal, run:
```bash sudo docker compose build --pull --no-cache --build-arg OPENCLAW_VERSION=latest openclaw ```

What this does: rebuilds the Docker Compose service named `openclaw` from the updated files and forces Docker to fetch fresh base-image and `openclaw@latest` layers. This matters because a normal Dockge redeploy, or plain `sudo docker compose up -d --build`, may reuse Docker's cached `npm install -g openclaw@latest` layer and leave the old OpenClaw package inside the rebuilt container.

This command rebuilds the image only. It does not delete `openclaw-home/`.

## Step 5: Restart the Same Dockge Stack

In Dockge, redeploy or recreate the same stack using the same `docker-compose.yml` file after the clean image build above.

If you are using the terminal instead of the Dockge button, run:
```bash sudo docker compose up -d --force-recreate openclaw ```

What this does: replaces the running container with the cleanly rebuilt image while keeping the same stack folder and `openclaw-home/` state folder mounted into it. `sudo` is used because Dockge stacks and Docker access commonly need administrator permission on a fresh Ubuntu host.

## Step 6: Verify the Upgrade

```bash sudo docker compose ps ```

What this does: shows whether the stack services are running. It also shows which external host ports Docker selected for OpenClaw Gateway and LAN command chat. The Gateway listens on internal container port `18789`; LAN command chat listens on internal container port `3001`.

If the `PORTS` column does not show a host mapping for both `18789` and `3001`, the upgrade is not complete. Pull the current stack files again, rebuild without cache, and recreate the same `openclaw` service before reporting success. Older stack files may expose the Gateway while leaving LAN command chat unreachable.
```bash sudo docker compose exec openclaw openclaw --version ```

What this does: prints the OpenClaw version inside the running container so you can confirm the container is not still using an old cached package.
```bash sudo docker compose port openclaw 3001 ```

What this does: prints the selected external LAN command chat port. Docker chooses the first free host port from `8080-8180`, so a second Dockge stack on the same host can use the next available port while still keeping LAN chat inside its own Compose service/container named `openclaw`.

Verify the printed LAN command chat address from the Docker host and from the LAN before claiming the upgrade is finished:
```bash LAN_CHAT_URL="http://$(sudo docker compose port openclaw 3001)" curl -fsS "$LAN_CHAT_URL/api/chat/status" ```

What this does: proves the external host port selected by Docker reaches the real LAN command chat process inside the running container. A refused connection or empty `docker compose port openclaw 3001` result means the Dockge stack is still missing the current LAN chat port publication.

## Step 7: Verify DB Memory Was Populated

The Docker image runs `scripts/first_run.sh` at startup. After a major OpenClaw/Zorg upgrade, verify that it actually repopulated and refreshed the database recall surface:
```bash sudo docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5' ```

What this does: verifies database-backed recall inside the Docker Compose service named `openclaw`. Expected mode: `database-direct-vector-neural-weighted`.
```bash sudo docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables' sudo docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py refresh' sudo docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/db_only_memory_autoheal.py' ```

What this does: confirms the SQL memory tables are reachable, refreshes the materialized recall surfaces, and runs DB-only memory auto-heal. If any command fails, inspect the container logs before reporting the upgrade healthy:
```bash sudo docker compose logs --tail=200 openclaw ```

Do not report a Dockge upgrade as verified unless the live Gateway, the selected external LAN chat port, and database-backed recall all respond on the real runtime surface.
