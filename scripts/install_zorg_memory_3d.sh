#!/usr/bin/env bash
set -euo pipefail

# Installs Zorg Memory 3D as a native user-level service.

INSTALL_DIR="${INSTALL_DIR:-${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}}"
ZORG_MEMORY_3D_DIR="${ZORG_MEMORY_3D_DIR:-$INSTALL_DIR/zorg-memory-3d}"
ZORG_MEMORY_3D_PORT="${ZORG_MEMORY_3D_PORT:-8097}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-openclaw_memory}"
DB_USER="${DB_USER:-openclaw_memory}"
NODE_BIN="${NODE_BIN:-$(command -v node || true)}"
NPM_BIN="${NPM_BIN:-$(command -v npm || true)}"
SERVICE_NAME="${ZORG_MEMORY_3D_SERVICE_NAME:-zorg-memory-3d.service}"

if [ ! -d "$ZORG_MEMORY_3D_DIR" ]; then
  echo "Zorg Memory 3D source not found at $ZORG_MEMORY_3D_DIR" >&2
  exit 1
fi

if [ -z "$NODE_BIN" ] || [ ! -x "$NODE_BIN" ]; then
  echo "node is required before installing Zorg Memory 3D" >&2
  exit 1
fi

if [ -z "$NPM_BIN" ] || [ ! -x "$NPM_BIN" ]; then
  echo "npm is required before installing Zorg Memory 3D" >&2
  exit 1
fi

cd "$ZORG_MEMORY_3D_DIR"
if [ -f package-lock.json ]; then
  "$NPM_BIN" ci --omit=dev
else
  "$NPM_BIN" install --omit=dev
fi
"$NPM_BIN" run check

mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/$SERVICE_NAME" <<SERVICE
[Unit]
Description=Zorg MemoryDB 3D brain map
After=network-online.target

[Service]
Type=simple
WorkingDirectory=$ZORG_MEMORY_3D_DIR
Environment=PORT=$ZORG_MEMORY_3D_PORT
Environment=OPENCLAW_WORKSPACE=$INSTALL_DIR
Environment=PGHOST=$DB_HOST
Environment=PGPORT=$DB_PORT
Environment=PGDATABASE=$DB_NAME
Environment=PGUSER=$DB_USER
ExecStart=$NODE_BIN server.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
SERVICE

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload
  systemctl --user enable --now "$SERVICE_NAME" || {
    echo "Could not start $SERVICE_NAME automatically." >&2
    echo "Start later with: systemctl --user enable --now $SERVICE_NAME" >&2
    exit 1
  }
fi

echo "Zorg Memory 3D installed."
echo "Service: systemctl --user status $SERVICE_NAME"
echo "Local URL: http://127.0.0.1:$ZORG_MEMORY_3D_PORT/"
echo "Admin URL: http://127.0.0.1:$ZORG_MEMORY_3D_PORT/admin"
