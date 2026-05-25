#!/usr/bin/env bash
# Thin compatibility wrapper for the Zorg MemoryDB overlay.
# Keep this root path so existing install commands continue to work while the
# actual Zorg files stay isolated under overlays/zorg-memorydb/.
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/StefRush2099/Zorg_MemoryDB.git}"
REPO_REF="${REPO_REF:-zorg-memorydb-additive-overlay}"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
INSTALL_DIR="${INSTALL_DIR:-$OPENCLAW_HOME/overlays/zorg-memorydb-source}"
OVERLAY_DIR="overlays/zorg-memorydb/Zorg_MemoryDB"

have(){ command -v "$1" >/dev/null 2>&1; }
run_priv(){ if [ "$(id -u)" -eq 0 ]; then "$@"; elif have sudo; then sudo "$@"; else "$@"; fi; }

if ! have git; then
  if have apt-get; then run_priv apt-get update && run_priv apt-get install -y git ca-certificates;
  elif have dnf; then run_priv dnf install -y git ca-certificates;
  elif have yum; then run_priv yum install -y git ca-certificates;
  elif have apk; then run_priv apk add --no-cache git ca-certificates;
  else echo "git is required to fetch the Zorg MemoryDB overlay." >&2; exit 1; fi
fi

if [ ! -d "$INSTALL_DIR/.git" ]; then
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone --branch "$REPO_REF" --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>/dev/null || {
    git clone "$REPO_URL" "$INSTALL_DIR"
    git -C "$INSTALL_DIR" checkout "$REPO_REF"
  }
else
  git -C "$INSTALL_DIR" fetch origin "$REPO_REF"
  git -C "$INSTALL_DIR" checkout "$REPO_REF"
  git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_REF" || true
fi

cd "$INSTALL_DIR"
if [ ! -x "$OVERLAY_DIR/scripts/install_standard_ubuntu.sh" ]; then
  echo "Zorg MemoryDB overlay installer not found at $INSTALL_DIR/$OVERLAY_DIR/scripts/install_standard_ubuntu.sh" >&2
  exit 1
fi

exec "$OVERLAY_DIR/scripts/install_standard_ubuntu.sh" "$@"
