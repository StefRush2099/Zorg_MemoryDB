#!/usr/bin/env python3
"""Nightly Zorg MemoryDB health check and bounded semantic backlog repair."""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

import psycopg2

WORKSPACE = Path("/home/openclaw/.openclaw/workspace")
SKILL_ROOT = Path(__file__).resolve().parents[1]
PYTHON = WORKSPACE / ".venv-sqlmem" / "bin" / "python"
SQL_MAP = SKILL_ROOT / "config" / "sql_memory_map.json"
WORKER = SKILL_ROOT / "scripts" / "memory_semantic_worker.py"

# The packaged scheduler owns the semantic/ANN maintenance path through this
# timer. Keep the health check aligned with the public systemd catalog.
SEMANTIC_TIMER = "zorg-ann-vector-autoheal.timer"
MAX_CATCHUP_BATCHES = 4
WORKER_LIMIT = 25
DUE_BACKLOG_WARN = 1000
STALE_WORKER_HOURS = 24


def load_db_cfg() -> dict[str, object]:
    cfg = json.loads(SQL_MAP.read_text(encoding="utf-8"))["postgres"]
    return {
        "host": cfg["host"],
        "port": cfg["port"],
        "dbname": cfg["database"],
        "user": cfg["user"],
        "password": cfg.get("password", ""),
    }


def run(cmd: list[str], *, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(WORKSPACE),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )


def systemctl_user(*args: str) -> subprocess.CompletedProcess[str]:
    return run(["systemctl", "--user", *args], timeout=45)


def ensure_timer() -> list[str]:
    actions: list[str] = []
    enabled = systemctl_user("is-enabled", SEMANTIC_TIMER)
    active = systemctl_user("is-active", SEMANTIC_TIMER)
    if enabled.returncode != 0 or active.returncode != 0:
        fix = systemctl_user("enable", "--now", SEMANTIC_TIMER)
        actions.append(
            f"timer_repair enabled_rc={enabled.returncode} active_rc={active.returncode} "
            f"fix_rc={fix.returncode}"
        )
        if fix.returncode != 0:
            actions.append(f"timer_repair_stderr={fix.stderr.strip()[:500]}")
    return actions


def fetch_health(cur) -> dict[str, object]:
    cur.execute(
        """
        select
          count(*) filter (where status='queued')::int as queued,
          count(*) filter (where status='queued' and due_at <= now())::int as due,
          min(due_at) filter (where status='queued' and due_at <= now()) as oldest_due
        from public.memory_semantic_work_queue
        """
    )
    queued, due, oldest_due = cur.fetchone()
    cur.execute(
        """
        select observed_at, duration_ms, processed_count, backlog_count
        from public.memory_runtime_timing_observations
        where observation_kind='semantic_worker_batch'
        order by observed_at desc
        limit 1
        """
    )
    worker = cur.fetchone()
    cur.execute(
        """
        select count(*)::int
        from public.zorg_logic_rules r
        left join public.zorg_logic_rule_dynamic_weights w using(rule_key)
        where r.active and r.priority in ('100','95','critical') and w.rule_key is null
        """
    )
    missing_rule_weights = cur.fetchone()[0]
    return {
        "queued": queued,
        "due": due,
        "oldest_due": oldest_due.isoformat() if oldest_due else None,
        "last_worker_observed_at": worker[0].isoformat() if worker else None,
        "last_worker_duration_ms": float(worker[1]) if worker and worker[1] is not None else None,
        "last_worker_processed_count": int(worker[2]) if worker and worker[2] is not None else None,
        "last_worker_backlog_count": int(worker[3]) if worker and worker[3] is not None else None,
        "missing_priority_rule_weights": missing_rule_weights,
    }


def backfill_missing_priority_rule_weights(cur) -> int:
    cur.execute(
        """
        insert into public.zorg_logic_rule_dynamic_weights(
          rule_key, seed_weight, dynamic_weight, feedback_basis, metadata
        )
        select
          r.rule_key,
          public.zorg_logic_rule_seed_weight(r.priority, r.applies_to),
          1.0,
          'nightly health priority-rule weight backfill',
          jsonb_build_object(
            'repair', 'nightly-health-priority-rule-weight-backfill',
            'reason', 'active priority rule lacked dynamic weight row and could be outranked'
          )
        from public.zorg_logic_rules r
        left join public.zorg_logic_rule_dynamic_weights w using(rule_key)
        where r.active and r.priority in ('100','95','critical') and w.rule_key is null
        on conflict (rule_key) do nothing
        returning rule_key
        """
    )
    return len(cur.fetchall())


def worker_is_stale(cur) -> bool:
    cur.execute(
        """
        select coalesce(
          now() - max(observed_at) > make_interval(hours => %s),
          true
        )
        from public.memory_runtime_timing_observations
        where observation_kind='semantic_worker_batch'
        """,
        (STALE_WORKER_HOURS,),
    )
    return bool(cur.fetchone()[0])


def run_worker_batch() -> dict[str, object]:
    result = run(
        [str(PYTHON), str(WORKER), "--once", "--limit", str(WORKER_LIMIT)],
        timeout=240,
    )
    payload: dict[str, object] = {
        "returncode": result.returncode,
        "stdout": result.stdout.strip()[:1000],
        "stderr": result.stderr.strip()[:1000],
    }
    try:
        payload["json"] = json.loads(result.stdout)
    except Exception:
        pass
    return payload


def recall_probe() -> dict[str, object]:
    start = time.perf_counter()
    result = run(
        [
            str(PYTHON),
            str(SKILL_ROOT / "scripts" / "memory_sql_tool.py"),
            "search",
            "bottom DB memory scan duration rule visible response",
            "--table",
            "all",
            "--limit",
            "5",
        ],
        timeout=60,
    )
    duration = time.perf_counter() - start
    ok = result.returncode == 0 and "Time summary: backend DB memory scan <duration>." in result.stdout
    return {
        "ok": ok,
        "returncode": result.returncode,
        "duration_seconds": round(duration, 3),
        "stderr": result.stderr.strip()[:500],
    }


def main() -> int:
    report: dict[str, object] = {
        "check": "nightly_memory_health_check",
        "actions": [],
        "worker_batches": [],
    }
    report["actions"].extend(ensure_timer())
    with psycopg2.connect(**load_db_cfg()) as conn:
        with conn.cursor() as cur:
            before = fetch_health(cur)
            stale = worker_is_stale(cur)
            report["before"] = before
            report["worker_stale"] = stale
            backfilled = backfill_missing_priority_rule_weights(cur)
            report["priority_rule_weights_backfilled"] = backfilled
            due = int(before["due"])
            batches = 0
            while batches < MAX_CATCHUP_BATCHES and (due > DUE_BACKLOG_WARN or stale):
                batch = run_worker_batch()
                report["worker_batches"].append(batch)
                batches += 1
                if batch["returncode"] != 0:
                    break
                conn.rollback()
                with conn.cursor() as cur2:
                    after_batch = fetch_health(cur2)
                    stale = worker_is_stale(cur2)
                    due = int(after_batch["due"])
                    report["after_batch"] = after_batch
                    if batch.get("json", {}).get("processed", 0) == 0:
                        break
            conn.rollback()
            with conn.cursor() as cur3:
                report["after"] = fetch_health(cur3)
    report["recall_probe"] = recall_probe()
    print(json.dumps(report, indent=2, default=str))
    after = report.get("after", {})
    probe = report.get("recall_probe", {})
    hard_fail = (
        isinstance(after, dict)
        and int(after.get("due", 0)) > DUE_BACKLOG_WARN
        and not report["worker_batches"]
    ) or not bool(probe.get("ok"))
    return 2 if hard_fail else 0


if __name__ == "__main__":
    sys.exit(main())
