#!/usr/bin/env bash
# Zorg MemoryDB overlay rule: install/upgrade must be additive to upstream OpenClaw and preserve existing OpenClaw behavior/user data unless an explicit migration documents otherwise. Permanent engineering rules are documented in docs/base-install-permanent-engineering-rules.md.
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/StefRush2099/Zorg_MemoryDB.git}"
TARGET_DIR="${1:-Zorg_MemoryDB}"

have(){ command -v "$1" >/dev/null 2>&1; }
run_priv(){
  if [ "$(id -u)" -eq 0 ]; then "$@"; elif have sudo; then sudo "$@"; else "$@"; fi
}

if ! have git; then
  if have apt-get; then run_priv apt-get update && run_priv apt-get install -y git;
  elif have dnf; then run_priv dnf install -y git;
  elif have yum; then run_priv yum install -y git;
  elif have apk; then run_priv apk add --no-cache git;
  else echo "git is required; install git and rerun." >&2; exit 1; fi
fi

if ! have docker; then
  echo "Docker is required before starting the all-in-one OpenClaw/Zorg MemoryDB stack." >&2
  echo "Install Docker, then rerun this script." >&2
  exit 1
fi

if [ ! -d "$TARGET_DIR/.git" ]; then
  if git clone "$REPO_URL" "$TARGET_DIR" 2>/dev/null; then :; else run_priv git clone "$REPO_URL" "$TARGET_DIR"; fi
fi

cd "$TARGET_DIR"
if [ ! -f .env ]; then cp .env.example .env; fi

if docker compose version >/dev/null 2>&1; then
  run_priv docker compose up -d --build
elif have docker-compose; then
  run_priv docker-compose up -d --build
else
  echo "Docker Compose is required. Install the Docker Compose plugin or docker-compose." >&2
  exit 1
fi

echo "Zorg OpenClaw is starting. Gateway port: ${OPENCLAW_GATEWAY_PORT:-18789}"
echo "OpenClaw is ready on the configured port when the container health checks/logs show gateway ready."
