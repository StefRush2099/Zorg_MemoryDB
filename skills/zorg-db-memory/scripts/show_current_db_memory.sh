#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${OPENCLAW_WORKSPACE:-${WORKSPACE_DIR:-${HOME:?}/.openclaw/workspace}}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP="${SQL_MEMORY_MAP:-${ZORG_SQL_MEMORY_MAP:-$SKILL_DIR/config/sql_memory_map.json}}"
TOOL="$WORKDIR/skills/zorg-db-memory/scripts/memory_sql_tool.py"
VENV="$WORKDIR/.venv-sqlmem"

printf 'DB memory workspace: %s\n' "$WORKDIR"
printf 'Map file: %s\n' "$MAP"
printf 'Tool: %s\n' "$TOOL"
printf 'Venv: %s\n' "$VENV"
printf '\nCurrent sql_memory_map.json:\n'
cat "$MAP"
printf '\n\nVerification commands:\n'
printf 'python %s tables\n' "$TOOL"
printf 'python %s recent --limit 5\n' "$TOOL"
printf 'python %s master --limit 10\n' "$TOOL"
