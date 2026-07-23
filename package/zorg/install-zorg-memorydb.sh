#!/usr/bin/env bash
set -euo pipefail

# Zorg MemoryDB + LAN command chat bootstrap for OpenClaw installs.
# This is a GitHub package script. It installs prerequisites, copies packaged
# public-safe components into the OpenClaw workspace, initializes DB schema,
# configures PostgreSQL-backed recall and the native plugin/MCP path,
# and prepares LAN command chat. It ships no private memory rows or credentials.

ZORG_DB_NAME="${ZORG_DB_NAME:-zorgdb}"
ZORG_DB_USER="${ZORG_DB_USER:-zorg}"
ZORG_DB_HOST="${ZORG_DB_HOST:-127.0.0.1}"
ZORG_DB_PORT="${ZORG_DB_PORT:-5432}"
ZORG_DB_PASSWORD=""
LAN_CHAT_PORT="${LAN_CHAT_PORT:-3001}"
LAN_CHAT_HOST="${LAN_CHAT_HOST:-0.0.0.0}"
OPENCLAW_CONTROL_UI_DISABLE_DEVICE_AUTH="${OPENCLAW_CONTROL_UI_DISABLE_DEVICE_AUTH:-true}"
ZORG_INSTALL_MODE="${ZORG_INSTALL_MODE:-first-run}"
ZORG_PATCH_EXISTING_DOCKER_CONFIG="${ZORG_PATCH_EXISTING_DOCKER_CONFIG:-0}"

default_openclaw_home() {
  if [[ -n "${OPENCLAW_HOME:-}" ]]; then
    printf '%s\n' "$OPENCLAW_HOME"
    return 0
  fi
  if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
    local sudo_home
    sudo_home="$(getent passwd "$SUDO_USER" 2>/dev/null | awk -F: '{print $6}')"
    if [[ -n "$sudo_home" && -d "$sudo_home" ]]; then
      printf '%s\n' "$sudo_home"
      return 0
    fi
  fi
  printf '%s\n' "$HOME"
}

OPENCLAW_EFFECTIVE_HOME="$(default_openclaw_home)"
if [[ "$OPENCLAW_EFFECTIVE_HOME" == "~" ]]; then
  OPENCLAW_EFFECTIVE_HOME="$HOME"
elif [[ "$OPENCLAW_EFFECTIVE_HOME" == ~/* ]]; then
  OPENCLAW_EFFECTIVE_HOME="$HOME/${OPENCLAW_EFFECTIVE_HOME#~/}"
fi

OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$OPENCLAW_EFFECTIVE_HOME/.openclaw/workspace}"
ZORG_WORKSPACE_DIR="${ZORG_WORKSPACE_DIR:-$OPENCLAW_WORKSPACE/zorg-memorydb}"
LAN_CHAT_DIR="${LAN_CHAT_DIR:-$OPENCLAW_WORKSPACE/lan-chat}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
PACKAGE_ROOT="$SCRIPT_DIR"
SKILL_SOURCE_DIR="$(cd "$SCRIPT_DIR/../../skills/zorg-db-memory" 2>/dev/null && pwd -P || true)"
PLUGIN_SOURCE_DIR="$SKILL_SOURCE_DIR/plugin-src"

log() { printf '%s\n' "zorg-memorydb: $*"; }
warn() { printf '%s\n' "zorg-memorydb warning: $*" >&2; }
is_root() { [[ "$(id -u)" -eq 0 ]]; }
has_passwordless_sudo() { command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; }
sudo_if_needed() {
  if is_root; then
    "$@"
  elif has_passwordless_sudo; then
    sudo -n "$@"
  else
    return 127
  fi
}

maybe_chown_sudo_workspace() {
  if [[ "$(id -u)" -ne 0 || -z "${SUDO_USER:-}" || "${SUDO_USER:-}" == "root" ]]; then
    return 0
  fi
  local sudo_home
  sudo_home="$(getent passwd "$SUDO_USER" 2>/dev/null | awk -F: '{print $6}')"
  if [[ -n "$sudo_home" && "$OPENCLAW_WORKSPACE" == "$sudo_home"/.openclaw/workspace* ]]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$OPENCLAW_WORKSPACE" 2>/dev/null || true
  fi
}

install_packages() {
  local packages=("$@")
  [[ "${#packages[@]}" -gt 0 ]] || return 0
  if ! is_root && ! has_passwordless_sudo && ! command -v brew >/dev/null 2>&1; then
    warn "Missing prerequisites require root or passwordless sudo: ${packages[*]}"
    warn "Continuing with packaged Zorg files only. Install those packages as root, then rerun: $0"
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    sudo_if_needed env DEBIAN_FRONTEND=noninteractive apt-get update -qq || {
      warn "apt-get update failed; continuing with packaged Zorg files only."
      return 0
    }
    sudo_if_needed env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${packages[@]}" || {
      warn "apt-get install failed; continuing with packaged Zorg files only."
      return 0
    }
  elif command -v dnf >/dev/null 2>&1; then
    sudo_if_needed dnf install -y -q "${packages[@]}" || warn "dnf install failed; continuing with packaged Zorg files only."
  elif command -v yum >/dev/null 2>&1; then
    sudo_if_needed yum install -y -q "${packages[@]}" || warn "yum install failed; continuing with packaged Zorg files only."
  elif command -v pacman >/dev/null 2>&1; then
    sudo_if_needed pacman -Sy --noconfirm "${packages[@]}" || warn "pacman install failed; continuing with packaged Zorg files only."
  elif command -v apk >/dev/null 2>&1; then
    sudo_if_needed apk add --no-cache "${packages[@]}" || warn "apk add failed; continuing with packaged Zorg files only."
  elif command -v brew >/dev/null 2>&1; then
    brew install "${packages[@]}" || warn "brew install failed; continuing with packaged Zorg files only."
  else
    warn "No supported package manager found; install missing prerequisites manually."
  fi
}

ensure_prerequisites() {
  local missing=()
  command -v git >/dev/null 2>&1 || missing+=(git)
  command -v python3 >/dev/null 2>&1 || missing+=(python3)
  python3 -c "import ensurepip" >/dev/null 2>&1 || missing+=(python3-venv)
  command -v psql >/dev/null 2>&1 || missing+=(postgresql-client)
  command -v pg_isready >/dev/null 2>&1 || missing+=(postgresql)
  command -v npm >/dev/null 2>&1 || missing+=(npm)
  command -v node >/dev/null 2>&1 || missing+=(nodejs)
  command -v openssl >/dev/null 2>&1 || missing+=(openssl)
  if [[ "${#missing[@]}" -gt 0 ]]; then
    log "Installing missing prerequisites: ${missing[*]}"
    install_packages "${missing[@]}"
  fi
}

ensure_workspace_layout() {
  mkdir -p "$OPENCLAW_WORKSPACE" "$ZORG_WORKSPACE_DIR" "$LAN_CHAT_DIR"
  mkdir -p "$ZORG_WORKSPACE_DIR/db"
}

copy_packaged_components() {
  log "Copying packaged Zorg MemoryDB components into $ZORG_WORKSPACE_DIR"
  cp -R "$PACKAGE_ROOT/db/." "$ZORG_WORKSPACE_DIR/db/"
  if [[ -f "$PACKAGE_ROOT/requirements.txt" ]]; then
    cp "$PACKAGE_ROOT/requirements.txt" "$ZORG_WORKSPACE_DIR/requirements.txt"
  fi
  log "Copying LAN command chat source into $LAN_CHAT_DIR"
  cp -R "$PACKAGE_ROOT/lan-command-chat/." "$LAN_CHAT_DIR/"
}

ensure_db_password() {
  case "$ZORG_DB_HOST" in
    127.0.0.1|localhost|::1) ZORG_DB_PASSWORD="" ;;
    *)
      warn "Remote PostgreSQL requires authentication; refusing an unauthenticated database configuration for $ZORG_DB_HOST. Set up a protected remote credential separately."
      return 1
      ;;
  esac
}

is_safe_pg_identifier() {
  [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

sql_quote_literal() {
  printf "%s" "$1" | sed "s/'/''/g"
}

run_postgres_superuser_sql() {
  local sql="$1"
  if is_root; then
    su - postgres -c "psql -v ON_ERROR_STOP=1 -Atqc \"$sql\""
  elif has_passwordless_sudo; then
    sudo -n -u postgres psql -v ON_ERROR_STOP=1 -Atqc "$sql"
  else
    return 127
  fi
}

run_postgres_superuser_target_sql() {
  local sql="$1"
  if is_root; then
    su - postgres -c "psql -v ON_ERROR_STOP=1 -d \"$ZORG_DB_NAME\" -Atqc \"$sql\""
  elif has_passwordless_sudo; then
    sudo -n -u postgres psql -v ON_ERROR_STOP=1 -d "$ZORG_DB_NAME" -Atqc "$sql"
  else
    return 127
  fi
}

start_local_postgres() {
  if command -v pg_isready >/dev/null 2>&1 && pg_isready -h "$ZORG_DB_HOST" -p "$ZORG_DB_PORT" >/dev/null 2>&1; then
    return 0
  fi
  if command -v systemctl >/dev/null 2>&1; then
    sudo_if_needed systemctl enable --now postgresql >/dev/null 2>&1 || true
  fi
  if command -v pg_ctlcluster >/dev/null 2>&1; then
    local cluster
    while read -r cluster; do
      [[ -n "$cluster" ]] || continue
      sudo_if_needed pg_ctlcluster $cluster start >/dev/null 2>&1 || true
    done < <(pg_lsclusters --no-header 2>/dev/null | awk '{print $1 " " $2}')
  fi
}

postgres_major_version() {
  if command -v psql >/dev/null 2>&1; then
    psql --version 2>/dev/null | awk '{print $3}' | cut -d. -f1
  fi
}

ensure_postgres_extension_packages() {
  case "$ZORG_DB_HOST" in
    127.0.0.1|localhost|::1) ;;
    *) return 0 ;;
  esac
  [[ "$ZORG_DB_PORT" == "5432" ]] || return 0

  local pg_major
  pg_major="$(postgres_major_version)"
  [[ -n "$pg_major" ]] || pg_major="16"

  if command -v apt-get >/dev/null 2>&1; then
    install_packages "postgresql-$pg_major-pgvector" "postgresql-$pg_major-cron"
  else
    warn "Install PostgreSQL pgvector and pg_cron packages for PostgreSQL $pg_major, then rerun this script if schema apply reports missing extensions."
  fi
}

restart_local_postgres_if_possible() {
  if command -v systemctl >/dev/null 2>&1; then
    sudo_if_needed systemctl restart postgresql >/dev/null 2>&1 && return 0
  fi
  if command -v pg_ctlcluster >/dev/null 2>&1; then
    local cluster
    while read -r cluster; do
      [[ -n "$cluster" ]] || continue
      sudo_if_needed pg_ctlcluster $cluster restart >/dev/null 2>&1 || true
    done < <(pg_lsclusters --no-header 2>/dev/null | awk '{print $1 " " $2}')
    return 0
  fi
  return 1
}

ensure_pg_cron_configuration() {
  case "$ZORG_DB_HOST" in
    127.0.0.1|localhost|::1) ;;
    *) return 0 ;;
  esac
  [[ "$ZORG_DB_PORT" == "5432" ]] || return 0
  is_safe_pg_identifier "$ZORG_DB_NAME" || return 0

  if ! run_postgres_superuser_sql "SELECT 1" >/dev/null 2>&1; then
    warn "PostgreSQL superuser access is unavailable; configure pg_cron manually before using DB-owned scheduled jobs."
    return 0
  fi

  local restart_needed=0
  local libraries
  libraries="$(run_postgres_superuser_sql "SELECT current_setting('shared_preload_libraries', true)" 2>/dev/null || true)"
  if [[ ",$libraries," != *",pg_cron,"* ]]; then
    if [[ -n "$libraries" ]]; then
      libraries="$libraries, pg_cron"
    else
      libraries="pg_cron"
    fi
    run_postgres_superuser_sql "ALTER SYSTEM SET shared_preload_libraries = '$(sql_quote_literal "$libraries")'" >/dev/null || {
      warn "Could not add pg_cron to shared_preload_libraries; configure it manually before DB-owned scheduled jobs can run."
      return 0
    }
    restart_needed=1
  fi

  local cron_database
  cron_database="$(run_postgres_superuser_sql "SELECT current_setting('cron.database_name', true)" 2>/dev/null || true)"
  if [[ "$cron_database" != "$ZORG_DB_NAME" ]]; then
    restart_needed=1
  fi
  run_postgres_superuser_sql "ALTER SYSTEM SET cron.database_name = '$(sql_quote_literal "$ZORG_DB_NAME")'" >/dev/null || true
  run_postgres_superuser_sql "ALTER SYSTEM SET cron.timezone = 'America/Los_Angeles'" >/dev/null || true
  if [[ "$restart_needed" == "1" ]]; then
    restart_local_postgres_if_possible || warn "Restart PostgreSQL before creating or using pg_cron jobs."
  fi
  run_postgres_superuser_target_sql "CREATE EXTENSION IF NOT EXISTS pg_cron" >/dev/null || warn "pg_cron extension could not be created in $ZORG_DB_NAME; scheduled job tables will still install, but database-owned cron activation needs manual pg_cron setup."
}

ensure_local_postgres_role_database() {
  case "$ZORG_DB_HOST" in
    127.0.0.1|localhost|::1) ;;
    *) return 0 ;;
  esac
  [[ "$ZORG_DB_PORT" == "5432" ]] || return 0
  is_safe_pg_identifier "$ZORG_DB_USER" || { warn "Skipping automatic PostgreSQL role creation because ZORG_DB_USER is not a simple identifier."; return 0; }
  is_safe_pg_identifier "$ZORG_DB_NAME" || { warn "Skipping automatic PostgreSQL database creation because ZORG_DB_NAME is not a simple identifier."; return 0; }

  if ! run_postgres_superuser_sql "SELECT 1" >/dev/null 2>&1; then
    warn "PostgreSQL superuser access is unavailable; create role/database manually or set ZORG_DB_* variables."
    return 0
  fi

  if [[ "$(run_postgres_superuser_sql "SELECT 1 FROM pg_roles WHERE rolname = '$ZORG_DB_USER'" 2>/dev/null || true)" != "1" ]]; then
    run_postgres_superuser_sql "CREATE ROLE \"$ZORG_DB_USER\" WITH LOGIN" >/dev/null || {
      warn "Could not create PostgreSQL role $ZORG_DB_USER."
      return 0
    }
  else
    run_postgres_superuser_sql "ALTER ROLE \"$ZORG_DB_USER\" WITH LOGIN PASSWORD NULL" >/dev/null || true
  fi

  if [[ "$(run_postgres_superuser_sql "SELECT 1 FROM pg_database WHERE datname = '$ZORG_DB_NAME'" 2>/dev/null || true)" != "1" ]]; then
    run_postgres_superuser_sql "CREATE DATABASE \"$ZORG_DB_NAME\" OWNER \"$ZORG_DB_USER\"" >/dev/null || {
      warn "Could not create PostgreSQL database $ZORG_DB_NAME."
      return 0
    }
  fi
}

configure_passwordless_local_auth() {
  case "$ZORG_DB_HOST" in
    127.0.0.1|localhost|::1) ;;
    *) return 0 ;;
  esac
  local hba_file
  hba_file="$(run_postgres_superuser_sql "SHOW hba_file" 2>/dev/null || true)"
  [[ -n "$hba_file" && -f "$hba_file" ]] || {
    warn "Could not locate pg_hba.conf; local passwordless access was not configured."
    return 0
  }
  local python_cmd=(python3 - "$hba_file" "$ZORG_DB_NAME" "$ZORG_DB_USER")
  if ! is_root; then
    if has_passwordless_sudo; then
      python_cmd=(sudo -n python3 - "$hba_file" "$ZORG_DB_NAME" "$ZORG_DB_USER")
    else
      warn "Cannot update pg_hba.conf without root; local passwordless access was not configured."
      return 0
    fi
  fi
  "${python_cmd[@]}" <<'PY'
from pathlib import Path
import os
import re
import sys

path = Path(sys.argv[1])
database = sys.argv[2]
user = sys.argv[3]
stat = path.stat()
lines = path.read_text(encoding="utf-8").splitlines()
rule_re = re.compile(
    rf"^\s*host\s+{re.escape(database)}\s+{re.escape(user)}\s+127\.0\.0\.1/32\s+trust(?:\s|$)"
)
comment = "# Zorg MemoryDB: passwordless local-only access; never expose this rule beyond loopback."
lines = [line for line in lines if not rule_re.match(line) and line != comment]
insert_at = next(
    (
        i
        for i, line in enumerate(lines)
        if re.match(r"^\s*host\s+all\s+all\s+127\.0\.0\.1/32\s+", line)
    ),
    len(lines),
)
lines[insert_at:insert_at] = [
    comment,
    f"host    {database}    {user}    127.0.0.1/32    trust",
]
tmp = path.with_name(path.name + ".zorg-memorydb.tmp")
tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
os.chown(tmp, stat.st_uid, stat.st_gid)
os.chmod(tmp, stat.st_mode & 0o7777)
os.replace(tmp, path)
PY
  run_postgres_superuser_sql "SELECT pg_reload_conf()" >/dev/null
}

ensure_postgres_database() {
  ensure_db_password || return 0
  if ! command -v psql >/dev/null 2>&1; then
    warn "psql is unavailable; database schema was copied but not applied."
    return 0
  fi
  start_local_postgres
  ensure_local_postgres_role_database
  configure_passwordless_local_auth
  ensure_postgres_extension_packages
  ensure_pg_cron_configuration
  run_postgres_superuser_target_sql "CREATE EXTENSION IF NOT EXISTS vector" >/dev/null || {
    warn "The vector extension requires PostgreSQL superuser installation."
    return 1
  }
  psql -h "$ZORG_DB_HOST" -p "$ZORG_DB_PORT" -U "$ZORG_DB_USER" -d "$ZORG_DB_NAME" -v ON_ERROR_STOP=1 -f "$ZORG_WORKSPACE_DIR/db/schema.sql" || {
    warn "Schema apply failed. Create database/role or set ZORG_DB_* variables, then rerun this script."
    return 1
  }
  for sql_file in \
    memory_file_archive_schema.sql \
    memory_typed_events_2026_07_16.sql \
    public_canonical_rules_update_2026_06_02.sql \
    memory_recall_procedure_api_2026_07_10.sql \
    memory_runtime_compat_2026_07_21.sql \
    memory_core_rule_preflight_2026_07_15.sql \
    memory_recall_exact_alias_fast_2026_07_10.sql \
    memory_recall_fast_mv_bounded_2026_07_10.sql \
    memory_recall_v2_bounded_2026_07_10.sql \
    memory_llm_due_enqueue_api_2026_07_10.sql \
    memory_correction_learning_2026_07_11.sql \
    memory_ann_bootstrap_2026_07_12.sql \
    memory_ann_provider_defaults_2026_07_12.sql \
    memory_logic_rule_feedback_2026_07_17.sql \
    memory_complete_self_repair_rule_2026_07_21.sql \
    memory_rule_scope_dedup_2026_07_15.sql \
    memory_semantic_capture_triggers_2026_07_17.sql; do
    if [[ -f "$ZORG_WORKSPACE_DIR/db/$sql_file" ]]; then
      psql -h "$ZORG_DB_HOST" -p "$ZORG_DB_PORT" -U "$ZORG_DB_USER" -d "$ZORG_DB_NAME" -v ON_ERROR_STOP=1 -f "$ZORG_WORKSPACE_DIR/db/$sql_file"
    fi
  done
  if [[ -f "$ZORG_WORKSPACE_DIR/db/memory_semantic_capture_triggers_2026_07_17.sql" ]]; then
    psql -h "$ZORG_DB_HOST" -p "$ZORG_DB_PORT" -U "$ZORG_DB_USER" -d "$ZORG_DB_NAME" -Atqc \
      "SELECT CASE WHEN count(*) = 11 AND bool_and(trigger_enabled) THEN 'semantic-capture-triggers-ok' ELSE 'semantic-capture-triggers-incomplete' END FROM public.memory_semantic_capture_trigger_status_v1" \
      | grep -qx 'semantic-capture-triggers-ok' \
      || { warn "Semantic capture trigger verification failed; live runtime capture is not complete."; return 1; }
  fi
  psql -h "$ZORG_DB_HOST" -p "$ZORG_DB_PORT" -U "$ZORG_DB_USER" -d "$ZORG_DB_NAME" -v ON_ERROR_STOP=1 -Atqc \
    "SELECT public.refresh_zorg_memory_search_fast_mv(); SELECT public.refresh_zorg_master_context();"
  ensure_memorydb_pg_cron_jobs
}

ensure_memorydb_pg_cron_jobs() {
  run_postgres_superuser_target_sql "GRANT USAGE ON SCHEMA cron TO \"$ZORG_DB_USER\"; GRANT SELECT ON cron.job, cron.job_run_details TO \"$ZORG_DB_USER\"; GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA cron TO \"$ZORG_DB_USER\";" >/dev/null || return 1
  psql -h "$ZORG_DB_HOST" -p "$ZORG_DB_PORT" -U "$ZORG_DB_USER" -d "$ZORG_DB_NAME" -v ON_ERROR_STOP=1 -Atqc \
    "SELECT cron.schedule('zorg-memorydb-core-runner','* * * * *','SELECT public.memory_db_run_due_jobs_sql(10);'); SELECT cron.schedule('zorg-memorydb-llm-enqueuer','* * * * *','SELECT public.memory_llm_enqueue_due_jobs_v1(50);');" >/dev/null || {
    warn "Could not install the two PostgreSQL MemoryDB firing jobs."
    return 1
  }
}

write_memory_config() {
  cat > "$OPENCLAW_WORKSPACE/sql_memory_map.json" <<JSON
{
  "postgres": {
    "host": "$ZORG_DB_HOST",
    "port": $ZORG_DB_PORT,
    "database": "$ZORG_DB_NAME",
    "user": "$ZORG_DB_USER",
    "password": ""
  },
  "table_map": {
    "memory": "zorg_memory",
    "rules": "zorg_logic_rules",
    "markdown_imports": "zorg_markdown_imports",
    "lan_chat": "lan_chat_messages",
    "associations": "memory_associations",
    "entities": "memory_entities",
    "source_chunks": "memory_source_chunks",
    "query_observations": "query_observations"
  }
}
JSON
  mkdir -p "$OPENCLAW_WORKSPACE/skills/zorg-db-memory/config"
  cp "$OPENCLAW_WORKSPACE/sql_memory_map.json" \
    "$OPENCLAW_WORKSPACE/skills/zorg-db-memory/config/sql_memory_map.json"
  # MemoryDB access is owned exclusively by the installed native plugin/MCP.
  # Remove known legacy launch surfaces before each update so stale installs
  # cannot win plugin discovery or silently become a fallback.
  rm -f "$OPENCLAW_WORKSPACE/memory_sql_tool.py" "$OPENCLAW_WORKSPACE/memory_recall_router.py" \
    "$OPENCLAW_WORKSPACE/memory_speed_test.py" "$OPENCLAW_WORKSPACE/enforce_db_memory_search.py"
  rm -rf "$OPENCLAW_WORKSPACE/skills/db-memory" "$OPENCLAW_WORKSPACE/skills/memory-db"
  rm -f "$OPENCLAW_WORKSPACE/skills/zorg-db-memory/scripts/install_db_memory.sh" \
    "$OPENCLAW_WORKSPACE/skills/zorg-db-memory/scripts/install_db_memory_full.sh"
  local plugin_dir="$OPENCLAW_WORKSPACE/skills/zorg-db-memory/plugin-src"
  mkdir -p "$plugin_dir"
  if [[ -n "$PLUGIN_SOURCE_DIR" && -d "$PLUGIN_SOURCE_DIR" ]]; then
    rm -rf "$plugin_dir"
    cp -R "$PLUGIN_SOURCE_DIR" "$plugin_dir"
    (cd "$plugin_dir" && npm ci --omit=optional --ignore-scripts)
    npm --prefix "$plugin_dir" run build
    if is_root && [[ -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
      local sudo_home openclaw_bin
      sudo_home="$(getent passwd "$SUDO_USER" | awk -F: '{print $6}')"
      openclaw_bin="$(command -v openclaw)"
      chown -R "$SUDO_USER:$SUDO_USER" "$OPENCLAW_WORKSPACE/skills/zorg-db-memory"
      sudo -u "$SUDO_USER" env \
        HOME="$sudo_home" \
        OPENCLAW_WORKSPACE="$OPENCLAW_WORKSPACE" \
        "$openclaw_bin" plugins install "$plugin_dir" --force
      sudo -u "$SUDO_USER" env \
        HOME="$sudo_home" \
        OPENCLAW_WORKSPACE="$OPENCLAW_WORKSPACE" \
        "$openclaw_bin" plugins enable zorg-memorydb
    else
      openclaw plugins install "$plugin_dir" --force
      openclaw plugins enable zorg-memorydb
    fi
  else
    warn "Canonical Zorg MemoryDB plugin source is missing; refusing to install legacy launchers."
  fi
  return 0
}

enforce_plugin_only_memory_config() {
  python3 - "$OPENCLAW_EFFECTIVE_HOME" "$OPENCLAW_WORKSPACE" <<'PY'
from pathlib import Path
import json
import os
import shutil
import sys
import tempfile

home = Path(sys.argv[1]).expanduser()
workspace = Path(sys.argv[2]).expanduser()
candidates = []
for candidate in (
    home / "openclaw.json",
    home / ".openclaw" / "openclaw.json",
    workspace.parent / "openclaw.json",
):
    if candidate not in candidates:
        candidates.append(candidate)

existing_candidates = [path for path in candidates if path.exists()]
if not existing_candidates:
    canonical = home / ".openclaw" / "openclaw.json"
    canonical.parent.mkdir(parents=True, exist_ok=True)
    canonical.write_text("{}\n", encoding="utf-8")
    existing_candidates = [canonical]

updated = False
for path in existing_candidates:
    try:
        config = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"zorg-memorydb warning: cannot enforce Markdown lockout in {path}: {exc}", file=sys.stderr)
        continue
    if not isinstance(config, dict):
        continue

    agents = config.setdefault("agents", {})
    defaults = agents.setdefault("defaults", {})
    defaults["memorySearch"] = {"enabled": False}
    compaction = defaults.setdefault("compaction", {})
    compaction["memoryFlush"] = {"enabled": False}
    for agent in agents.get("list", []):
        if isinstance(agent, dict):
            agent["memorySearch"] = {"enabled": False}
            agent_compaction = agent.setdefault("compaction", {})
            if isinstance(agent_compaction, dict):
                agent_compaction["memoryFlush"] = {"enabled": False}

    hooks = config.setdefault("hooks", {})
    internal = hooks.setdefault("internal", {})
    entries = internal.setdefault("entries", {})
    session_memory = entries.setdefault("session-memory", {})
    session_memory["enabled"] = False

    plugins = config.setdefault("plugins", {})
    plugin_entries = plugins.setdefault("entries", {})
    zorg_plugin = plugin_entries.setdefault("zorg-memorydb", {})
    zorg_plugin["enabled"] = True

    backup = path.with_name(path.name + ".pre-zorg-memory-lockout.bak")
    if not backup.exists():
        shutil.copy2(path, backup)
    payload = json.dumps(config, indent=2) + "\n"
    fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp_name, path.stat().st_mode & 0o7777)
        os.replace(tmp_name, path)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
    print(f"zorg-memorydb: enforced plugin-only memory and disabled Markdown memory runtime: {path}")
    updated = True

if not updated:
    raise SystemExit("zorg-memorydb: plugin-only Markdown lockout could not be enforced")
PY
}

write_gateway_tui_compat_config() {
  python3 - "$OPENCLAW_EFFECTIVE_HOME" "$OPENCLAW_WORKSPACE" "$OPENCLAW_CONTROL_UI_DISABLE_DEVICE_AUTH" <<'PY'
from pathlib import Path
import json
import sys

home = Path(sys.argv[1]).expanduser()
workspace = Path(sys.argv[2]).expanduser()
disable_device_auth = sys.argv[3].strip().lower() in {"1", "true", "yes", "on"}

candidates = []
for candidate in (
    home / "openclaw.json",
    home / ".openclaw" / "openclaw.json",
    workspace.parent / "openclaw.json",
):
    if candidate not in candidates:
        candidates.append(candidate)

updated = False
for path in candidates:
    if not path.exists():
        continue
    try:
        config = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        continue
    if not isinstance(config, dict):
        continue
    gateway = config.setdefault("gateway", {})
    if not isinstance(gateway, dict):
        continue
    control_ui = gateway.setdefault("controlUi", {})
    if not isinstance(control_ui, dict):
        gateway["controlUi"] = control_ui = {}

    control_ui["allowInsecureAuth"] = True
    if disable_device_auth:
        control_ui["dangerouslyDisableDeviceAuth"] = True

    path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    print(f"zorg-memorydb: updated Docker/TUI gateway compatibility config: {path}")
    updated = True

if not updated:
    print("zorg-memorydb warning: no existing OpenClaw gateway config found for Docker/TUI compatibility patch", file=sys.stderr)
PY
  if [[ "$OPENCLAW_CONTROL_UI_DISABLE_DEVICE_AUTH" =~ ^([Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|1|[Oo][Nn])$ ]]; then
    warn "Enabled token-protected Docker/TUI compatibility by disabling Control UI device-auth checks. Set OPENCLAW_CONTROL_UI_DISABLE_DEVICE_AUTH=false for hardened HTTPS or paired-device deployments."
  fi
}

prepare_lan_chat() {
  if [[ ! -f "$LAN_CHAT_DIR/.env.local" && -f "$LAN_CHAT_DIR/.env.local.example" ]]; then
    cp "$LAN_CHAT_DIR/.env.local.example" "$LAN_CHAT_DIR/.env.local"
    {
      printf '\nDATABASE_URL=postgresql://%s@%s:%s/%s\n' "$ZORG_DB_USER" "$ZORG_DB_HOST" "$ZORG_DB_PORT" "$ZORG_DB_NAME"
      printf 'LAN_CHAT_PORT=%s\n' "$LAN_CHAT_PORT"
      printf 'PORT=%s\n' "$LAN_CHAT_PORT"
    } >> "$LAN_CHAT_DIR/.env.local"
  fi
  if command -v npm >/dev/null 2>&1 && [[ -f "$LAN_CHAT_DIR/package.json" ]]; then
    (cd "$LAN_CHAT_DIR" && npm install)
    (cd "$LAN_CHAT_DIR" && npm run build) || warn "LAN chat build failed; inspect $LAN_CHAT_DIR and rerun npm run build."
  fi
}

install_memorydb_dispatcher_service() {
  local source_unit="$PACKAGE_ROOT/systemd/zorg-memorydb-llm-dispatcher.service"
  [[ -f "$source_unit" ]] || { warn "MemoryDB LLM dispatcher unit template is missing."; return 1; }
  if [[ "$(id -u)" == "0" && -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
    local sudo_home
    sudo_home="$(getent passwd "$SUDO_USER" | awk -F: '{print $6}')"
    install -d -o "$SUDO_USER" -g "$SUDO_USER" "$sudo_home/.config/systemd/user"
    sed "s|%h|$sudo_home|g" "$source_unit" > "$sudo_home/.config/systemd/user/zorg-memorydb-llm-dispatcher.service"
    chown "$SUDO_USER:$SUDO_USER" "$sudo_home/.config/systemd/user/zorg-memorydb-llm-dispatcher.service"
    sudo -u "$SUDO_USER" env HOME="$sudo_home" systemctl --user daemon-reload
    sudo -u "$SUDO_USER" env HOME="$sudo_home" systemctl --user enable --now zorg-memorydb-llm-dispatcher.service
  else
    mkdir -p "$HOME/.config/systemd/user"
    cp "$source_unit" "$HOME/.config/systemd/user/zorg-memorydb-llm-dispatcher.service"
    systemctl --user daemon-reload
    systemctl --user enable --now zorg-memorydb-llm-dispatcher.service
  fi
}

install_lan_chat_service() {
  if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemd is unavailable; LAN chat source is installed but no service was created."
    return 0
  fi
  local npm_bin
  npm_bin="$(command -v npm || true)"
  if [[ -z "$npm_bin" ]]; then
    warn "npm is unavailable; LAN chat source is installed but no service was created."
    return 0
  fi
  local service_path
  service_path="$(dirname "$npm_bin"):/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  local openclaw_bin
  openclaw_bin="$(command -v openclaw || true)"
  if [[ "$(id -u)" == "0" ]]; then
    local service_user
    service_user="$(stat -c '%U' "$OPENCLAW_WORKSPACE" 2>/dev/null || true)"
    if [[ -z "$service_user" || "$service_user" == "UNKNOWN" || "$service_user" == "root" ]]; then
      service_user="${SUDO_USER:-root}"
    fi
    if [[ "$service_user" == "root" ]]; then
      warn "Running as root and no non-root OpenClaw workspace owner was found; LAN chat source is installed but no service was created."
      return 0
    fi
    cat > /etc/systemd/system/lan-chat.service <<SERVICE
[Unit]
Description=Zorg LAN command chat
After=network-online.target postgresql.service

[Service]
Type=simple
User=$service_user
WorkingDirectory=$LAN_CHAT_DIR
Environment=PATH=$service_path
Environment=OPENCLAW_BIN=$openclaw_bin
Environment=PORT=$LAN_CHAT_PORT
Environment=HOSTNAME=$LAN_CHAT_HOST
ExecStart=$npm_bin run start
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
    systemctl daemon-reload || true
    systemctl enable lan-chat.service || true
    systemctl restart lan-chat.service || warn "LAN chat service restart failed; run: systemctl status lan-chat.service"
    return 0
  fi
  mkdir -p "$HOME/.config/systemd/user"
  cat > "$HOME/.config/systemd/user/lan-chat.service" <<SERVICE
[Unit]
Description=Zorg LAN command chat
After=network-online.target

[Service]
Type=simple
WorkingDirectory=$LAN_CHAT_DIR
Environment=PATH=$service_path
Environment=OPENCLAW_BIN=$openclaw_bin
Environment=PORT=$LAN_CHAT_PORT
Environment=HOSTNAME=$LAN_CHAT_HOST
ExecStart=$npm_bin run start
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
SERVICE
  systemctl --user daemon-reload || true
  systemctl --user enable lan-chat.service || true
  systemctl --user restart lan-chat.service || warn "LAN chat service restart failed; run: systemctl --user status lan-chat.service"
}

main() {
  while [[ "${1:-}" == --* ]]; do
    case "$1" in
      --from-openclaw-install) shift ;;
      --install-mode)
        ZORG_INSTALL_MODE="${2:-first-run}"
        shift 2
        ;;
      --patch-existing-docker-config)
        ZORG_PATCH_EXISTING_DOCKER_CONFIG=1
        shift
        ;;
      *) warn "Ignoring unknown option: $1"; shift ;;
    esac
  done
  ensure_prerequisites
  ensure_workspace_layout
  copy_packaged_components
  ensure_postgres_database
  write_memory_config
  enforce_plugin_only_memory_config
  if [[ "$ZORG_PATCH_EXISTING_DOCKER_CONFIG" == "1" ]]; then
    write_gateway_tui_compat_config
  else
    log "Skipping existing Docker/TUI gateway config patch; set ZORG_PATCH_EXISTING_DOCKER_CONFIG=1 only for an intentional existing Docker repair."
  fi
  if [[ -d "$OPENCLAW_WORKSPACE/memory" && -x "$OPENCLAW_WORKSPACE/archive_retired_memory_dir.py" ]]; then
    ZORG_SKIP_RECALL_REFRESH=1 "$OPENCLAW_WORKSPACE/.venv-sqlmem/bin/python" "$OPENCLAW_WORKSPACE/archive_retired_memory_dir.py" || true
  fi
  prepare_lan_chat
  maybe_chown_sudo_workspace
  install_lan_chat_service
  install_memorydb_dispatcher_service
  log "Zorg MemoryDB and LAN command chat bootstrap complete."
}
main "$@"
