#!/usr/bin/env bash
# Zorg MemoryDB overlay rule: install/upgrade must be additive to upstream OpenClaw and preserve existing OpenClaw behavior/user data unless an explicit migration documents otherwise. Permanent engineering rules are documented in docs/base-install-permanent-engineering-rules.md.
set -euo pipefail

# Native all-in-one install for Linux hosts.
# Installs OpenClaw from a Zorg MemoryDB branch of the original OpenClaw source checkout.

OPENCLAW_GIT_REPO="${OPENCLAW_GIT_REPO:-https://github.com/openclaw/openclaw.git}"
OPENCLAW_GIT_REF="${OPENCLAW_GIT_REF:-zorg-memorydb}"
OPENCLAW_GIT_DIR="${OPENCLAW_GIT_DIR:-$HOME/openclaw}"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$OPENCLAW_HOME/workspace}"
DB_NAME="${DB_NAME:-openclaw_memory}"
DB_USER="${DB_USER:-openclaw_memory}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-lan}"
OPENCLAW_GATEWAY_AUTH="${OPENCLAW_GATEWAY_AUTH:-trusted-proxy}"
LAN_CHAT_PORT="${LAN_CHAT_PORT:-3001}"
ZORG_MEMORY_3D_PORT="${ZORG_MEMORY_3D_PORT:-8097}"
REQUIRED_NODE_VERSION="${REQUIRED_NODE_VERSION:-22.19.0}"

have(){ command -v "$1" >/dev/null 2>&1; }
run_priv(){ if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }
run_postgres(){
  if have sudo; then sudo -u postgres "$@";
  elif [ "$(id -u)" -eq 0 ] && have runuser; then runuser -u postgres -- "$@";
  else echo "sudo or runuser is required to manage the local PostgreSQL role/database." >&2; exit 1; fi
}

if ! have sudo && [ "$(id -u)" -ne 0 ]; then
  echo "sudo is required for the native Ubuntu install." >&2
  exit 1
fi

detect_pm(){
  if have apt-get; then echo apt
  elif have dnf; then echo dnf
  elif have yum; then echo yum
  elif have zypper; then echo zypper
  elif have apk; then echo apk
  elif have pacman; then echo pacman
  elif have brew; then echo brew
  else echo ""; fi
}

install_packages(){
  pm="$(detect_pm)"
  if [ -z "$pm" ]; then
    echo "No supported package manager found. Install missing prerequisites manually, then rerun." >&2
    exit 1
  fi
  case "$pm" in
    apt)
      run_priv apt-get update
      DEBIAN_FRONTEND=noninteractive run_priv apt-get install -y "$@"
      ;;
    dnf) run_priv dnf install -y "$@" ;;
    yum) run_priv yum install -y "$@" ;;
    zypper) run_priv zypper --non-interactive install "$@" ;;
    apk) run_priv apk add --no-cache "$@" ;;
    pacman) run_priv pacman -Sy --noconfirm --needed "$@" ;;
    brew) brew install "$@" ;;
  esac
}

install_base_prereqs(){
  pm="$(detect_pm)"
  case "$pm" in
    apt)
      install_packages ca-certificates curl git python3 python3-pip python3-venv postgresql postgresql-contrib build-essential gnupg
      ;;
    dnf|yum)
      install_packages ca-certificates curl git python3 python3-pip postgresql postgresql-server postgresql-contrib make gcc gcc-c++ tar gzip
      ;;
    zypper)
      install_packages ca-certificates curl git python3 python3-pip postgresql postgresql-server postgresql-contrib patterns-devel-base-devel_basis tar gzip
      ;;
    apk)
      install_packages ca-certificates curl git python3 py3-pip postgresql postgresql-contrib build-base tar gzip
      ;;
    pacman)
      install_packages ca-certificates curl git python python-pip postgresql base-devel tar gzip
      ;;
    brew)
      install_packages ca-certificates curl git python postgresql@16
      ;;
    *)
      echo "No supported package manager found for automatic prerequisite install." >&2
      exit 1
      ;;
  esac
}

node_meets_requirement(){
  have node || return 1
  node -e "
const need = process.argv[1].split('.').map(Number);
const got = process.versions.node.split('.').map(Number);
for (let i = 0; i < need.length; i++) {
  if ((got[i] || 0) > need[i]) process.exit(0);
  if ((got[i] || 0) < need[i]) process.exit(1);
}
" "$REQUIRED_NODE_VERSION"
}

install_nodesource_node(){
  pm="$(detect_pm)"
  case "$pm" in
    apt)
      run_priv mkdir -p /etc/apt/keyrings
      curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | run_priv gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
      echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | run_priv tee /etc/apt/sources.list.d/nodesource.list >/dev/null
      run_priv apt-get update
      DEBIAN_FRONTEND=noninteractive run_priv apt-get install -y nodejs
      ;;
    dnf|yum)
      curl -fsSL https://rpm.nodesource.com/setup_22.x | run_priv bash -
      install_packages nodejs
      ;;
    zypper)
      curl -fsSL https://rpm.nodesource.com/setup_22.x | run_priv bash -
      install_packages nodejs
      ;;
    apk)
      install_packages nodejs-current npm
      ;;
    pacman)
      install_packages nodejs npm
      ;;
    brew)
      install_packages node
      ;;
    *)
      echo "Cannot install Node.js automatically on this OS. Need Node >= $REQUIRED_NODE_VERSION." >&2
      exit 1
      ;;
  esac
}

install_npm(){
  pm="$(detect_pm)"
  case "$pm" in
    apt|dnf|yum|zypper|brew)
      install_nodesource_node
      ;;
    apk|pacman)
      install_packages npm
      ;;
    *)
      echo "Cannot install npm automatically on this OS. Need npm before OpenClaw install." >&2
      exit 1
      ;;
  esac
}

ensure_node(){
  if node_meets_requirement && have npm; then
    return 0
  fi

  if node_meets_requirement && ! have npm; then
    echo "Detected Node $(node -v), but npm is missing. Installing npm before OpenClaw install."
    install_npm
  elif have node; then
    echo "Detected Node $(node -v), but OpenClaw requires Node >= $REQUIRED_NODE_VERSION. Upgrading Node before npm install."
    install_nodesource_node
  else
    echo "Node.js is missing. Installing Node >= $REQUIRED_NODE_VERSION before npm install."
    install_nodesource_node
  fi

  if ! node_meets_requirement; then
    echo "Node.js is still too old after automatic install: $(node -v 2>/dev/null || echo missing). Need >= $REQUIRED_NODE_VERSION." >&2
    exit 1
  fi
  if ! have npm; then
    echo "npm is still missing after automatic repair." >&2
    exit 1
  fi
}

ensure_postgresql_running(){
  if have systemctl; then
    run_priv systemctl enable --now postgresql 2>/dev/null && return 0
    run_priv systemctl enable --now postgresql@16-main 2>/dev/null && return 0
    run_priv systemctl enable --now postgresql@15-main 2>/dev/null && return 0
    run_priv systemctl enable --now postgresql@14-main 2>/dev/null && return 0
  fi
  if have service; then
    run_priv service postgresql start 2>/dev/null && return 0
  fi
  if have pg_ctlcluster; then
    cluster="$(pg_lsclusters 2>/dev/null | awk 'NR==2 {print $1, $2}')"
    if [ -n "$cluster" ]; then
      # shellcheck disable=SC2086
      run_priv pg_ctlcluster $cluster start 2>/dev/null && return 0
    fi
  fi
  if ! pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
    echo "PostgreSQL is installed but could not be started automatically on this OS." >&2
    exit 1
  fi
}

reload_postgresql(){
  if have systemctl; then
    run_priv systemctl reload postgresql 2>/dev/null && return 0
    run_priv systemctl reload postgresql@16-main 2>/dev/null && return 0
    run_priv systemctl reload postgresql@15-main 2>/dev/null && return 0
    run_priv systemctl reload postgresql@14-main 2>/dev/null && return 0
  fi
  if have service; then
    run_priv service postgresql reload 2>/dev/null && return 0
    run_priv service postgresql restart 2>/dev/null && return 0
  fi
  if have pg_ctlcluster; then
    cluster="$(pg_lsclusters 2>/dev/null | awk 'NR==2 {print $1, $2}')"
    if [ -n "$cluster" ]; then
      # shellcheck disable=SC2086
      run_priv pg_ctlcluster $cluster reload 2>/dev/null && return 0
    fi
  fi
  run_postgres pg_ctl reload 2>/dev/null || true
}

export DB_HOST=127.0.0.1 DB_PORT=5432 DB_NAME DB_USER

install_base_prereqs
ensure_node

mkdir -p "$OPENCLAW_HOME" "$OPENCLAW_WORKSPACE"
if [ ! -d "$OPENCLAW_GIT_DIR/.git" ]; then
  if git clone "$OPENCLAW_GIT_REPO" "$OPENCLAW_GIT_DIR" 2>/dev/null; then :; else run_priv git clone "$OPENCLAW_GIT_REPO" "$OPENCLAW_GIT_DIR"; run_priv chown -R "${USER:-$(id -un)}:${USER:-$(id -un)}" "$OPENCLAW_GIT_DIR" 2>/dev/null || true; fi
fi
git -C "$OPENCLAW_GIT_DIR" fetch --all --prune
git -C "$OPENCLAW_GIT_DIR" checkout "$OPENCLAW_GIT_REF"
curl -fsSL https://openclaw.ai/install.sh | OPENCLAW_INSTALL_METHOD=git OPENCLAW_GIT_DIR="$OPENCLAW_GIT_DIR" bash -s -- --install-method git --git-dir "$OPENCLAW_GIT_DIR" --version "$OPENCLAW_GIT_REF" --no-onboard

ensure_postgresql_running
PG_HBA="$(run_postgres psql -Atc "show hba_file;")"
if ! run_priv grep -q "zorg_memorydb_local_trust" "$PG_HBA"; then
  tmp_hba="$(mktemp)"
  {
    echo "# zorg_memorydb_local_trust"
    echo "host all $DB_USER 127.0.0.1/32 trust"
    echo "host all $DB_USER ::1/128 trust"
    cat "$PG_HBA"
  } > "$tmp_hba"
  run_priv cp "$tmp_hba" "$PG_HBA"
  rm -f "$tmp_hba"
  reload_postgresql
fi
run_postgres psql -v ON_ERROR_STOP=1 \
  -v db_name="$DB_NAME" -v db_user="$DB_USER" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN SUPERUSER', :'db_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'db_user')\gexec
SELECT format('ALTER ROLE %I WITH LOGIN SUPERUSER', :'db_user')\gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')\gexec
SELECT format('ALTER DATABASE %I OWNER TO %I', :'db_name', :'db_user')\gexec
SQL

cd "$OPENCLAW_GIT_DIR"
DB_HOST=127.0.0.1 DB_PORT=5432 DB_NAME="$DB_NAME" DB_USER="$DB_USER" OPENCLAW_WORKSPACE="$OPENCLAW_WORKSPACE" ./scripts/upgrade_existing_openclaw.sh

cd "$OPENCLAW_WORKSPACE"
OPENCLAW_HOME="$OPENCLAW_HOME" \
OPENCLAW_WORKSPACE="$OPENCLAW_WORKSPACE" \
GATEWAY_HOST=127.0.0.1 \
GATEWAY_SESSION_KEY=agent:main:main \
CHAT_SOURCE_LABEL="LAN Console" \
CHAT_HISTORY_LIMIT=20 \
LAN_CHAT_PORT="$LAN_CHAT_PORT" \
./scripts/install_lan_chat.sh

cat > "$OPENCLAW_WORKSPACE/.env.native" <<ENV
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=$DB_USER
OPENCLAW_GATEWAY_PORT=$OPENCLAW_GATEWAY_PORT
OPENCLAW_GATEWAY_BIND=$OPENCLAW_GATEWAY_BIND
OPENCLAW_GATEWAY_AUTH=$OPENCLAW_GATEWAY_AUTH
LAN_CHAT_PORT=$LAN_CHAT_PORT
ZORG_MEMORY_3D_PORT=$ZORG_MEMORY_3D_PORT
ENV
chmod 600 "$OPENCLAW_WORKSPACE/.env.native"

python3 - <<PY
import json, pathlib
home=pathlib.Path('$OPENCLAW_HOME')
path=home/'openclaw.json'
try:
    cfg=json.loads(path.read_text()) if path.exists() else {}
except Exception:
    cfg={}
gw=cfg.setdefault('gateway', {})
gw['mode']='local'
gw['bind']='$OPENCLAW_GATEWAY_BIND'
gw['port']=int('$OPENCLAW_GATEWAY_PORT')
gw['auth']={'mode':'$OPENCLAW_GATEWAY_AUTH','trustedProxy':{'userHeader':'x-openclaw-user'}}
gw['trustedProxies']=['0.0.0.0/0','::/0']
gw.setdefault('controlUi', {})['dangerouslyAllowHostHeaderOriginFallback']=True
agents=cfg.setdefault('agents', {})
defaults=agents.setdefault('defaults', {})
defaults['memorySearch']={
    'enabled': True,
    'provider': 'local',
    'fallback': 'none',
    'sources': ['memory'],
    'multimodal': {'enabled': False},
}
home.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(cfg, indent=2)+'\n')
PY

echo "Native Ubuntu OpenClaw + Zorg MemoryDB install complete."
echo "Config saved to $OPENCLAW_WORKSPACE/.env.native"
echo "LAN command console installed at http://127.0.0.1:$LAN_CHAT_PORT/"
echo "Service status: systemctl --user status lan-chat.service"
echo "Zorg Memory 3D installed at http://127.0.0.1:$ZORG_MEMORY_3D_PORT/"
echo "Zorg Memory 3D admin: http://127.0.0.1:$ZORG_MEMORY_3D_PORT/admin"
echo "Brain map service status: systemctl --user status zorg-memory-3d.service"
echo "Start gateway with:"
echo "  cd $OPENCLAW_WORKSPACE && source .env.native && OPENCLAW_WORKSPACE=$OPENCLAW_WORKSPACE SQL_MEMORY_MAP=$OPENCLAW_WORKSPACE/sql_memory_map.json openclaw gateway run --allow-unconfigured --bind \$OPENCLAW_GATEWAY_BIND --port \$OPENCLAW_GATEWAY_PORT --auth \$OPENCLAW_GATEWAY_AUTH"
