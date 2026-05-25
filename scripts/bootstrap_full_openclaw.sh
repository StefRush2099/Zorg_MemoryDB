#!/usr/bin/env bash
# Thin compatibility wrapper for the all-in-one Docker bootstrap.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAY_SCRIPT="$ROOT/overlays/zorg-memorydb/Zorg_MemoryDB/scripts/bootstrap_full_openclaw.sh"

if [ ! -x "$OVERLAY_SCRIPT" ]; then
  echo "Zorg MemoryDB overlay bootstrap script not found at $OVERLAY_SCRIPT" >&2
  exit 1
fi

exec "$OVERLAY_SCRIPT" "$@"
