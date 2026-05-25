#!/usr/bin/env bash
set -euo pipefail

# Install the built-in Zorg MemoryDB LAN command console for native OpenClaw hosts.
# This installs/builds lan-chat and registers a user-level systemd service on port 3001.

INSTALL_DIR="${INSTALL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LAN_CHAT_DIR="${LAN_CHAT_DIR:-$INSTALL_DIR/lan-chat}"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$INSTALL_DIR}"
LAN_CHAT_PORT="${LAN_CHAT_PORT:-3001}"
GATEWAY_HOST="${GATEWAY_HOST:-127.0.0.1}"
GATEWAY_SESSION_KEY="${GATEWAY_SESSION_KEY:-agent:main:main}"
CHAT_SOURCE_LABEL="${CHAT_SOURCE_LABEL:-LAN Console}"
CHAT_HISTORY_LIMIT="${CHAT_HISTORY_LIMIT:-20}"
GATEWAY_CALL_TIMEOUT_MS="${GATEWAY_CALL_TIMEOUT_MS:-15000}"

have(){ command -v "$1" >/dev/null 2>&1; }
run_priv(){ if [ "$(id -u)" -eq 0 ]; then "$@"; elif have sudo; then sudo "$@"; else "$@"; fi; }

ensure_npm(){
  if have npm; then
    return 0
  fi

  echo "npm is not installed; attempting to install Node.js/npm for the LAN command console." >&2
  if have apt-get; then
    run_priv apt-get update
    run_priv apt-get install -y nodejs npm
  elif have dnf; then
    run_priv dnf install -y nodejs npm
  elif have yum; then
    run_priv yum install -y nodejs npm
  elif have apk; then
    run_priv apk add --no-cache nodejs npm
  else
    echo "npm is required to build the LAN command console, and no supported package manager was found." >&2
    echo "Install Node.js/npm, then rerun this script." >&2
    exit 1
  fi
}

if [ ! -d "$LAN_CHAT_DIR" ]; then
  echo "lan-chat source not found at $LAN_CHAT_DIR" >&2
  exit 1
fi

ensure_npm

cd "$LAN_CHAT_DIR"
if [ -f package-lock.json ]; then npm ci; else npm install; fi
npm run build

cat > .env.local <<ENV
HOME=$HOME
OPENCLAW_HOME=$OPENCLAW_HOME
OPENCLAW_WORKSPACE=$OPENCLAW_WORKSPACE
GATEWAY_HOST=$GATEWAY_HOST
GATEWAY_SESSION_KEY=$GATEWAY_SESSION_KEY
CHAT_SOURCE_LABEL=$CHAT_SOURCE_LABEL
CHAT_HISTORY_LIMIT=$CHAT_HISTORY_LIMIT
GATEWAY_CALL_TIMEOUT_MS=$GATEWAY_CALL_TIMEOUT_MS
PORT=$LAN_CHAT_PORT
ENV
chmod 600 .env.local

mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/lan-chat.service" <<SERVICE
[Unit]
Description=Zorg MemoryDB LAN Command Console
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$LAN_CHAT_DIR
EnvironmentFile=$LAN_CHAT_DIR/.env.local
Environment=PORT=$LAN_CHAT_PORT
ExecStart=$(command -v npm) run start
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
SERVICE

if have systemctl; then
  systemctl --user daemon-reload || true
  systemctl --user enable --now lan-chat.service || {
    echo "LAN console service file installed, but systemctl --user could not start it in this shell." >&2
    echo "Start later with: systemctl --user enable --now lan-chat.service" >&2
  }
fi

echo "Zorg MemoryDB LAN command console installed."
echo "URL: http://127.0.0.1:$LAN_CHAT_PORT/"
echo "Service: systemctl --user status lan-chat.service"
