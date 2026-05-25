#!/usr/bin/env bash
# Zorg MemoryDB overlay rule: install/upgrade must be additive to upstream OpenClaw and preserve existing OpenClaw behavior/user data unless an explicit migration documents otherwise. Permanent engineering rules are documented in docs/base-install-permanent-engineering-rules.md.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
exec ./scripts/first_run.sh "$@"
