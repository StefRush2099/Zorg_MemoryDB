#!/usr/bin/env bash
set -euo pipefail

# Required env:
#   ZORG_TASK_TYPE=major|ops|general
#   ZORG_GO_TOKEN=GO for every mutation
# Optional:
#   ZORG_HEALTH_TARGET_URL=http://host:port/health
#   ZORG_DB_RECALL_STAMP=<set by caller when DB recall step completed>

fail() { echo "[ZORG_GATE][FAIL] $1" >&2; exit 1; }
pass() { echo "[ZORG_GATE][PASS] $1"; }

TASK_TYPE="${ZORG_TASK_TYPE:-general}"
GO_TOKEN="${ZORG_GO_TOKEN:-}"
DB_RECALL_STAMP="${ZORG_DB_RECALL_STAMP:-}"
HEALTH_URL="${ZORG_HEALTH_TARGET_URL:-}"

# 1) DB recall must be explicitly acknowledged first.
[[ -n "$DB_RECALL_STAMP" ]] || fail "DB recall step missing (ZORG_DB_RECALL_STAMP not set)."
pass "DB recall step acknowledged"

# 2) DB-backed rule enforcement policy must exist.
DB_RULE_COUNT="$("/home/openclaw/.openclaw/workspace/.venv-sqlmem/bin/python" - <<'PY'
import json
import psycopg2

cfg = json.load(open('/home/openclaw/.openclaw/workspace/skills/zorg-db-memory/config/sql_memory_map.json'))['postgres']
conn = psycopg2.connect(
    host=cfg['host'],
    port=cfg['port'],
    dbname=cfg['database'],
    user=cfg['user'],
    password=cfg.get('password', ''),
)
with conn, conn.cursor() as cur:
    cur.execute("""
        select count(*)
        from public.zorg_logic_rules
        where active
          and rule_key = 'prework-summary-requires-go-before-mutation-2026-07-14'
    """)
    print(cur.fetchone()[0])
PY
)"
[[ "$DB_RULE_COUNT" =~ ^[1-9][0-9]*$ ]] || fail "DB-backed rule enforcement rows missing"
pass "DB-backed rule enforcement rows present ($DB_RULE_COUNT)"

# 3) Every mutation class requires the exact operator GO token.
[[ "$GO_TOKEN" == "GO" ]] || fail "Mutation requires exact GO token: ZORG_GO_TOKEN=GO."
pass "Explicit GO token present for task type ($TASK_TYPE)"

# 4) If runtime task and health URL provided, require healthy response.
if [[ "$TASK_TYPE" == "ops" || "$TASK_TYPE" == "major" ]]; then
  if [[ -n "$HEALTH_URL" ]]; then
    code="$(curl -s -o /tmp/zorg_gate_health.out -w '%{http_code}' "$HEALTH_URL" || true)"
    [[ "$code" == "200" ]] || fail "Health check failed at $HEALTH_URL (code=$code)"
    pass "Health check ok ($HEALTH_URL)"
  fi
fi

pass "Preflight gate complete"
