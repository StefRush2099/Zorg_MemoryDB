# Host Docker/Dockge Manager Upgrade

Use this page when upgrading the host Docker Engine or the Dockge manager container itself. This is separate from upgrading an OpenClaw/Zorg assistant stack managed by Docker Compose or Dockge.

Official basis:

Docker Engine on Ubuntu: https://docs.docker.com/engine/install/ubuntu/

Dockge upstream README: https://github.com/louislam/dockge

Do not use Docker's convenience script to upgrade an existing production host. Docker's official Ubuntu guide warns that the convenience script is intended for new installs and is not designed for upgrading an existing Docker installation.

## Before You Start

For a VM, create a hypervisor snapshot or equivalent host backup first. The upgrade can restart Docker and therefore restart containers.

Record the current state:
```bash docker --version docker compose version systemctl is-active docker docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' ```

What this does: captures the current Docker version, Compose plugin version, Docker service state, and running containers before any package changes.

## Upgrade Docker Engine

The host must already use Docker's official apt repository. Confirm the Docker repository is configured:
```bash test -f /etc/apt/sources.list.d/docker.list ```

What this does: checks that Docker Engine upgrades will come from Docker's official package repository instead of Ubuntu's `docker.io` package stream.

Refresh package metadata and upgrade only Docker's packages:
```bash sudo apt-get update sudo apt-get install -y --only-upgrade \ docker-ce \ docker-ce-cli \ containerd.io \ docker-buildx-plugin \ docker-compose-plugin \ docker-ce-rootless-extras ```

What this does: upgrades Docker Engine, CLI, containerd, Buildx, Compose, and rootless extras through Docker's official apt repository. Docker may restart containers during this step.

Verify Docker after the package upgrade:
```bash docker --version docker compose version systemctl is-active docker docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' ```

Expected result: Docker is active, Compose prints a version, and the expected containers are running or restarting normally.

## Upgrade the Dockge Manager

Upgrade Dockge from the terminal or SSH session on the Docker host. Do not run a Dockge self-update from inside the Dockge UI when Dockge manages its own container; the manager container can be stopped during the update.
```bash cd /opt/dockge docker compose config >/dev/null docker compose pull docker compose up -d ```

What this does: validates the Dockge Compose file, pulls the current Dockge image, and recreates the Dockge manager container from the terminal.

Verify Dockge:
```bash cd /opt/dockge docker compose ps docker compose logs --tail=80 dockge ```

If Dockge publishes port `5001` on the host, check the local HTTP surface:
```bash curl -fsS http://127.0.0.1:5001/ >/dev/null ```

Expected result: the Dockge container is running and the web UI responds.

## Verify Managed Assistant Stacks

For each OpenClaw/Zorg stack that Dockge manages:
```bash cd /opt/stacks/front-desk-assistant docker compose ps docker compose exec openclaw openclaw --version docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5' ```

What this does: verifies the assistant stack survived the host Docker/Dockge upgrade, the container still runs OpenClaw, and DB-backed recall still returns through the expected runtime path.

## Tested Reference

This procedure was tested on Ubuntu 22.04 with Docker upgraded from `29.4.2` to `29.5.1`, Docker remaining active, the Dockge manager staying healthy on port `5001`, and the Dockge-managed OpenClaw/Zorg stack restarting normally.
