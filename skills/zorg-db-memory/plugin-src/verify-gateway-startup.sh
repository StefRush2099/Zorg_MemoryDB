#!/usr/bin/env bash
set -euo pipefail
gateway_pid="${1:?gateway pid required}"
gateway_unit="${OPENCLAW_GATEWAY_UNIT:-openclaw-gateway.service}"
plugin_ready=false
for _ in $(seq 1 "${ZORG_MEMORYDB_STARTUP_ATTEMPTS:-20}"); do
  gateway_log="$(journalctl --user -u "$gateway_unit" "_PID=$gateway_pid" --no-pager -o cat 2>/dev/null || true)"
  if grep -Eq 'plugins: [^)]*(^|, )zorg-memorydb(, |;)' <<<"$gateway_log"; then plugin_ready=true; break; fi
  if grep -Eq 'failed to load plugin|zorg-memorydb failed to load' <<<"$gateway_log"; then
    echo "Mandatory zorg-memorydb plugin failed to load; refusing unenforced gateway startup." >&2; exit 1
  fi
  sleep 1
done
[[ "$plugin_ready" == true ]] || { echo "Mandatory zorg-memorydb plugin was not confirmed; refusing unenforced gateway startup." >&2; exit 1; }
plugin_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
map_path="${SQL_MEMORY_MAP:-${ZORG_SQL_MEMORY_MAP:-${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}/sql_memory_map.json}}"
ZORG_MEMORYDB_MAP_PATH="$map_path" ZORG_MEMORYDB_PLUGIN_ROOT="$plugin_root" node --input-type=module -e '
  import { readFile } from "node:fs/promises";
  const pg=(await import(`file://${process.env.ZORG_MEMORYDB_PLUGIN_ROOT}/node_modules/pg/lib/index.js`)).default;
  const cfg=JSON.parse(await readFile(process.env.ZORG_MEMORYDB_MAP_PATH,"utf8"));
  const client=new pg.Client(cfg.postgres);
  try {
    await client.connect();
    const result=await client.query(`select current_database()=$1 as correct_database,
      to_regclass($3) is not null as receipt_table,
      (select count(*)=4 from public.zorg_logic_rules where active and rule_key=any($2::text[])) as mandatory_rules`,[
      cfg.postgres.database,["universal-visible-response-time-enforcement-2026-08-08","unified-change-repair-summary-go-authorization-rule-v2-2026-08-09","zorg-memorydb-automatic-complete-self-repair-2026-08-09","self-created-blocker-repair-before-reporting-rule-2026-05-20"],"public.memory_turn_recall_receipts"]);
    if(!Object.values(result.rows[0]||{}).every(Boolean)) process.exitCode=1;
  } finally { await client.end().catch(()=>{}); }
' 2>/dev/null || { echo "Mandatory MemoryDB PostgreSQL prerequisites failed; refusing unenforced gateway startup." >&2; exit 1; }
