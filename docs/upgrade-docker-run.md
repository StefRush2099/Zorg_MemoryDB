# Docker Run Upgrade

Use this page only when the assistant was started with a direct `docker run` command.

If SSH, terminals, `cd`, or Linux paths are unfamiliar, read [`beginner-terminal-and-ssh.md`](beginner-terminal-and-ssh.md) first.

Example assistant folder:
```text ~/front-desk-assistant/ ```

This path is different from Docker Compose and Dockge. A direct `docker run` install does not have a `docker-compose.yml` stack file. Do not use Compose commands on this page.

In this install type, Docker runs one named container. The container can be replaced during an upgrade. The `openclaw-home/` folder inside the assistant folder is the part that keeps the assistant's state and memory.

## Step 1: Enter the Assistant Folder

```bash cd ~/front-desk-assistant ```

What this does: moves the terminal into the assistant folder. This is the folder you created for this assistant, and it contains the `openclaw-home/` state folder.

## Step 2: Confirm the State Folder Exists

```bash test -d openclaw-home ```

What this does: confirms the persistent OpenClaw state folder exists. `openclaw-home/` stores OpenClaw state, workspace files, embedded PostgreSQL data, and DB memory.

Do not delete `openclaw-home/`. The upgrade replaces the container wrapper and image, not this data folder.

## Step 3: Set the Container Name From the Folder Name

```bash INSTALL_ID="${PWD##*/}" ```

What this does: saves the current folder name, such as `front-desk-assistant`, into `INSTALL_ID`. The next commands use that value to find the existing container name. If your folder is `front-desk-assistant`, the container name is `front-desk-example-placeholder`.

## Step 4: Download the New Image

```bash sudo docker pull ghcr.io/stefrush2099/zorg-memorydb:latest ```

What this does: downloads the newest packaged Zorg MemoryDB image. The image is the reusable package Docker runs. Pulling the image does not change `openclaw-home/`.

## Step 5: Stop the Old Container

```bash sudo docker stop "${INSTALL_ID}-zorg-memorydb" ```

What this does: stops the currently running container so it can be replaced. This pauses the assistant. It does not delete `openclaw-home/`.

## Step 6: Remove the Old Container Wrapper

```bash sudo docker rm "${INSTALL_ID}-zorg-memorydb" ```

What this does: removes the stopped container wrapper so Docker can create a new one with the same name. This removes the old shell around the assistant, not the assistant's memory folder.

## Step 7: Start the New Container With the Same State Folder

```bash sudo docker run -d --name "${INSTALL_ID}-zorg-memorydb" --restart unless-stopped \ -p 18789-18889:18789 \ -p 8080-8180:3001 \ -v "$PWD/openclaw-home:/home/openclaw/.openclaw" \ ghcr.io/stefrush2099/zorg-memorydb:latest ```

What this does: starts a new container from the updated image. The `-v "$PWD/openclaw-home:/home/openclaw/.openclaw"` part mounts the same state folder back into OpenClaw, so the new container uses the existing assistant memory and workspace.

The `-p 18789-18889:18789` part publishes the OpenClaw Gateway from internal container port `18789` onto the first free external host port in the `18789-18889` range. The `-p 8080-8180:3001` part publishes LAN command chat from internal container port `3001` onto the first free external host port in the `8080-8180` range. Those ranges let more than one OpenClaw/Zorg container run on the same Docker host without fighting over the same outside port.

## Step 8: Verify the Upgrade

```bash sudo docker ps --filter "name=${INSTALL_ID}-zorg-memorydb" ```

What this does: confirms the new container is running.
```bash sudo docker port "${INSTALL_ID}-zorg-memorydb" 3001/tcp ```

What this does: prints the external host port Docker selected for LAN command chat. Open that port in the browser, not the internal container port number, when Docker selected a different outside port.
```bash sudo docker exec "${INSTALL_ID}-zorg-memorydb" bash -lc 'pg_isready -h 127.0.0.1 -p 5432' ```

What this does: checks whether PostgreSQL is answering inside the container.
```bash sudo docker exec "${INSTALL_ID}-zorg-memorydb" bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5' ```

What this does: verifies database-backed recall. Expected mode: `database-direct-vector-neural-weighted`.
