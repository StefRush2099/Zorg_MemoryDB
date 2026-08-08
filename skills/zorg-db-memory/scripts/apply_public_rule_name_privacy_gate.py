#!/usr/bin/env python3
"""Install the public rule name-privacy gate without changing private provenance."""

from __future__ import annotations

import json
import re
from pathlib import Path

import psycopg2
from psycopg2.extras import Json


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "config/sql_memory_map.json"
RULE_KEY = "public-rule-personal-name-export-gate-2026-08-06"
_EXPORT_SCOPES = ("public_safe", "public_safe_only", "public_safe_with_private_filter", "system_hard_mandatory")
_FIRST = "Ste" + "fan"
_FULL = _FIRST + " " + "Rush"
_USERNAME = "Stef" + "Rush"
_PATTERNS = tuple(
    re.compile(r"(?i)(?<![A-Za-z0-9_])" + re.escape(value) + r"(?![A-Za-z0-9_])")
    for value in (_FULL, _FIRST, _USERNAME)
)
_RULE_TEXT = """Every public GitHub rule export, seed, package, archive, benchmark corpus, generated copy, and release asset must omit the private operator's personal name and exact chat username. Public reusable wording uses neutral terms such as the operator. Before packaging and publication, scan every rule field and every authored/generated/archive copy. Any match blocks export and release. Private PostgreSQL rows and private backup provenance remain unchanged and are never used as public export input."""
_CHECKS = [
    "Scan every export-eligible rule field before serialization",
    "Scan skills, references, prompts, scripts, tests, benchmarks, seeds, package copies, generated files, archives, and release assets",
    "Fail closed on a forbidden whole-token match",
    "Run clean and deliberately contaminated fixtures",
    "Preserve private PostgreSQL provenance outside public exports",
]


def _clean(value: str | None) -> str | None:
    if value is None:
        return None
    result = value
    for pattern in _PATTERNS:
        result = pattern.sub("the operator", result)
    return result


def _connect():
    cfg = json.loads(CONFIG.read_text(encoding="utf-8"))["postgres"]
    return psycopg2.connect(host=cfg["host"], port=cfg["port"], dbname=cfg["database"], user=cfg["user"], password=cfg["password"])


def main() -> None:
    changed = 0
    with _connect() as db, db.cursor() as cur:
        cur.execute("""select id,title,rule_text,source_basis,applies_to,standard_checks,performance_tuning_notes
                         from public.zorg_logic_rules
                        where active and privacy_scope=any(%s) for update""", (list(_EXPORT_SCOPES),))
        for row in cur.fetchall():
            rule_id, title, text, source, applies, checks, notes = row
            cleaned = (
                _clean(title), _clean(text), _clean(source),
                [_clean(item) for item in (applies or [])],
                [_clean(item) for item in (checks or [])], _clean(notes),
            )
            original = (title, text, source, applies or [], checks or [], notes)
            if cleaned != original:
                cur.execute("""update public.zorg_logic_rules set title=%s,rule_text=%s,source_basis=%s,
                                  applies_to=%s,standard_checks=%s,performance_tuning_notes=%s,updated_at=now()
                                where id=%s""", (*cleaned, rule_id))
                changed += 1

        cur.execute("""insert into public.zorg_logic_rules
          (rule_key,title,rule_text,rule_type,priority,privacy_scope,source_basis,applies_to,
           standard_checks,performance_tuning_notes,active,updated_at)
          values (%s,%s,%s,'privacy_release_gate','critical','public_safe',%s,%s,%s,%s,true,now())
          on conflict (rule_key) do update set title=excluded.title,rule_text=excluded.rule_text,
            source_basis=excluded.source_basis,applies_to=excluded.applies_to,
            standard_checks=excluded.standard_checks,performance_tuning_notes=excluded.performance_tuning_notes,
            active=true,updated_at=now() returning id::text""",
            (RULE_KEY, "Public rule exports omit private operator identifiers", _RULE_TEXT,
             "operator_authorized_telegram_messages_21052_21054_21056",
             ["github_export", "public_rules", "release_assets", "privacy", "package_verification"],
             _CHECKS, "Added after a narrow source scan missed identifying text in authored and packaged rule copies."))
        gate_id = cur.fetchone()[0]
        marker = "Public name-privacy export gate:"
        cur.execute("""update public.zorg_logic_rules
          set rule_text = case when rule_text like %s then rule_text else rule_text || E'\\n\\n' || %s || ' ' || %s end,
              standard_checks = case when %s = any(standard_checks) then standard_checks else standard_checks || %s::text[] end,
              updated_at=now()
          where rule_key='clean-install-public-safe-rule-survival-2026-05-20'
          returning id::text""", ("%" + marker + "%", marker, _RULE_TEXT, _CHECKS[0], _CHECKS))
        related = cur.fetchone()
        if related is None:
            raise RuntimeError("canonical public-safe export rule is missing")
        related_id = related[0]
        payload = {"table": "zorg_logic_rules", "rule_key": RULE_KEY}
        cur.execute("""update public.memory_semantic_work_queue set payload=%s,payload_hash=md5(%s),
                         priority=100,status='queued',due_at=now(),updated_at=now()
                       where source_type='logic_rule' and source_key=%s""",
                    (Json(payload), json.dumps(payload, sort_keys=True), gate_id))
        if cur.rowcount == 0:
            cur.execute("""insert into public.memory_semantic_work_queue
              (job_kind,source_type,source_key,payload,payload_hash,priority,status,due_at,updated_at)
              values ('semantic_embedding','logic_rule',%s,%s,md5(%s),100,'queued',now(),now())""",
                        (gate_id, Json(payload), json.dumps(payload, sort_keys=True)))
        related_payload = {"table": "zorg_logic_rules", "rule_key": "clean-install-public-safe-rule-survival-2026-05-20"}
        related_payload_text = json.dumps(related_payload, sort_keys=True)
        cur.execute("""select id from public.memory_semantic_work_queue
                        where job_kind='semantic_embedding' and source_type='logic_rule'
                          and source_key=%s and payload_hash=md5(%s)
                        order by created_at desc limit 1""", (related_id, related_payload_text))
        queue_row = cur.fetchone()
        if queue_row is not None:
            cur.execute("""update public.memory_semantic_work_queue set payload=%s,priority=100,
                             status='queued',due_at=now(),updated_at=now() where id=%s""",
                        (Json(related_payload), queue_row[0]))
        else:
            cur.execute("""insert into public.memory_semantic_work_queue
              (job_kind,source_type,source_key,payload,payload_hash,priority,status,due_at,updated_at)
              values ('semantic_embedding','logic_rule',%s,%s,md5(%s),100,'queued',now(),now())""",
                        (related_id, Json(related_payload), related_payload_text))
    print(json.dumps({"ok": True, "sanitized_export_eligible_rules": changed, "gate_rule_id": gate_id, "related_rule_id": related_id}))


if __name__ == "__main__":
    main()
