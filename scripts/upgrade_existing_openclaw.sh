#!/usr/bin/env bash
# Thin compatibility wrapper for applying Zorg MemoryDB to an existing OpenClaw
# workspace while keeping the implementation in overlays/zorg-memorydb/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAY_SCRIPT="$ROOT/overlays/zorg-memorydb/Zorg_MemoryDB/scripts/upgrade_existing_openclaw.sh"

if [ ! -x "$OVERLAY_SCRIPT" ]; then
  echo "Zorg MemoryDB overlay upgrade script not found at $OVERLAY_SCRIPT" >&2
  exit 1
fi

exec "$OVERLAY_SCRIPT" "$@"
