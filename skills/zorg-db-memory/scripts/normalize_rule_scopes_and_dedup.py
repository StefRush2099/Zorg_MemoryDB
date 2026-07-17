#!/usr/bin/env python3
"""Apply the canonical public/private rule placement and safe dedup pass.

This migration is intentionally additive: source rows are retained as inactive
provenance, while one canonical structured rule owns each behavior.  It is the
skill-owned source for the 2026-07-15 rule-placement correction.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

import psycopg2


ROOT = Path(__file__).resolve().parents[1]
CFG = json.loads((ROOT / "config/sql_memory_map.json").read_text())['postgres']


def norm(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", (text or "").lower())


def rule(cur, key: str, title: str, text: str, kind: str, priority: str,
         scope: str, basis: str, applies: list[str], checks: list[str]):
    cur.execute(
        """insert into public.zorg_logic_rules
        (rule_key,title,rule_text,rule_type,priority,privacy_scope,source_basis,
         applies_to,standard_checks,performance_tuning_notes,active)
        values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,true)
        on conflict (rule_key) do update set
          title=excluded.title, rule_text=excluded.rule_text,
          rule_type=excluded.rule_type, priority=excluded.priority,
          privacy_scope=excluded.privacy_scope, applies_to=excluded.applies_to,
          standard_checks=excluded.standard_checks,
          performance_tuning_notes=excluded.performance_tuning_notes,
          active=true, updated_at=now()""",
        (key, title, text, kind, priority, scope, basis, applies, checks,
         'Canonical source owned by zorg-db-memory; source fragments remain inactive provenance.',),
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true', help='commit the migration')
    args = ap.parse_args()
    conn = psycopg2.connect(**CFG)
    try:
        with conn:
            with conn.cursor() as cur:
                if not args.apply:
                    cur.execute("select count(*) from public.zorg_logic_rules where active")
                    print({'active_rules': cur.fetchone()[0], 'mode': 'dry-run'})
                    return 0

                # Current-install variables are the only path authority.
                cur.execute("""update public.zorg_logic_rules
                    set rule_text=%s, privacy_scope='system_hard_mandatory',
                        performance_tuning_notes=coalesce(performance_tuning_notes,'') ||
                        E'\n2026-07-15: replaced install-specific locations with OPENCLAW_WORKSPACE/WORKSPACE_DIR and OPENCLAW_HOME.',
                        updated_at=now()
                    where rule_key='canonical-ea-email-calendar-contact-33-database-backup-and-recovery-paths'""", (
                    "Use current-install variables for predictable database backup and recovery paths: "
                    "OPENCLAW_WORKSPACE (or WORKSPACE_DIR) for workspace-relative backups and OPENCLAW_HOME "
                    "for OpenClaw home backups. If DB access fails, try safe repair first; if repair fails, "
                    "test configured backups until a working DB is found, promote it, refresh recall surfaces, "
                    "and verify with DB health/recall tests. Never embed an installation-specific absolute path "
                    "in this rule or its public deployment package.",
                ))

                rule(cur,
                     'db-before-visible-response-proof-2026-07-15',
                     'Backend DB recall and visible-response proof',
                     'Before every visible response, perform current-turn PostgreSQL/Zorg MemoryDB recall for the request, relevant rules, and related history. Preserve the trusted inbound timestamp and, immediately before the visible send attempt, calculate the real wall-clock elapsed duration. Fail closed if recall or either trusted timestamp is missing. End the visible response with the runtime-generated Time summary line.',
                     'memory_recall_enforcement', 'critical', 'system_hard_mandatory',
                     'zorg-db-memory_rule-normalization_2026-07-15',
                     ['memory_recall', 'visible_response', 'timing', 'fail_closed'],
                     ['Run DB recall before response composition', 'Use trusted current-turn timestamps', 'Fail closed on missing recall or timing', 'Emit the runtime-generated bottom duration proof'])

                rule(cur,
                     'credential-source-locator-core-2026-07-15',
                     'Credential Source Locator',
                     'Before asking the operator for credentials, recall durable DB memory and inspect the current install inventory and Compose/env/config sources. Use secret values only locally; never place secret values in chat, Markdown, summaries, logs, or public packages. Public documentation may describe variable names and generic inventory locations, but not secret values.',
                     'credential_lookup_rule', 'critical', 'system_hard_mandatory',
                     'zorg-db-memory_rule-normalization_2026-07-15',
                     ['credentials', 'inventory', 'secret_handling'],
                     ['Recall DB first', 'Inspect current install sources before asking', 'Never disclose secret values'])

                rule(cur,
                     'rule-failure-lockout-canonical-2026-07-15',
                     'Rule Failure Lockout',
                     'Do not mutate before the exact fact-based summary and approval gate. Do not widen scope, remove authentication, create fake or disconnected behavior, or claim completion without affected-surface evidence. When a prior rule failure is reported, repair only the exact failed scope and report the earliest violated gate first.',
                     'operating_rule', 'critical', 'system_hard_mandatory',
                     'zorg-db-memory_rule-normalization_2026-07-15',
                     ['approval', 'exact_scope', 'verification', 'failure_reporting'],
                     ['Require exact scope', 'Require evidence before done claims', 'Report earliest gate first'])

                # These were explicitly supplied as public/core rules.  The
                # private list below is applied afterward and wins on overlap.
                public_keys = [
                    'markdown-marker-block::openclaw-host-identity-rule',
                    'core-rule::AGENTS.md:41', 'core-rule::AGENTS.md:158',
                    'core-rule::AGENTS.md:238', 'markdown-marker-block::go-only-approval-rule',
                    'go-only-approval-rule', 'core-rule::HEARTBEAT.md:19',
                    'core-rule::HEARTBEAT.md:20', 'core-rule::HEARTBEAT.md:31',
                    'core-rule::HEARTBEAT.md:54', 'core-rule::HEARTBEAT.md:58',
                    'core-rule::HEARTBEAT.md:69', 'core-rule::HEARTBEAT.md:77',
                    'core-rule::HEARTBEAT.md:87', 'markdown-marker-block::os-patch-reboot-maintenance-rule',
                    'public-conversation-loop-suppression-public-safe-2026-05-20',
                    'private-markdown-email-rule-public-conversation-loop-suppression-hard-system-rule-802c815ff7',
                    'canonical-ea-email-calendar-contact-17-rich-text-email-formatting-hard-rule',
                    'rich-text-email-formatting-public-safe-2026-05-20',
                    'telegram-audio-in-audio-out-no-extra-text-2026-06-09',
                    'canonical-ea-email-calendar-contact-02-daily-ea-loop',
                    'canonical-ea-email-calendar-contact-09-disk-free-space-monitoring',
                    'executive-assistant-proactive-final-checks', 'core-rule::HEARTBEAT.md:110',
                ]
                cur.execute("update public.zorg_logic_rules set privacy_scope='system_hard_mandatory', updated_at=now() where rule_key = any(%s)", (public_keys,))

                # Keep only the explicitly private install overlays.
                private_keys = [
                    'private-hyperdine-news-reports-detailed-exciting-optimization-2026-05-20',
                    'private-x-managed-account-path-recall-2026-05-20',
                    'canonical-ea-email-calendar-contact-35-public-email-identity-signature',
                    'core-rule::TOOLS.md:122', 'core-rule::TOOLS.md:148',
                    'generic-base-e57a74815178b2a6', 'la-dj-beta-zorg-backchannel-access',
                ]
                cur.execute("update public.zorg_logic_rules set privacy_scope='private', updated_at=now() where rule_key = any(%s)", (private_keys,))

                # Retire repeated source fragments without deleting provenance.
                fragment_patterns = [
                    "rule_key like 'core-rule::%' and title ilike '%Priority 0: Backend DB Recall Proof%'",
                    "rule_key like 'core-rule::%' and title ilike '%Credential Source Locator%'",
                    "rule_key like 'core-rule::HEARTBEAT.md:%' and title like 'HEARTBEAT.md:% Base Install Permanent Engineering Rules'",
                    "rule_key like 'core-rule::HEARTBEAT.md:%' and title like 'HEARTBEAT.md:% Rule Failure Lockout'",
                ]
                for where in fragment_patterns:
                    cur.execute("update public.zorg_logic_rules set active=false, updated_at=now(), performance_tuning_notes=coalesce(performance_tuning_notes,'') || E'\\n2026-07-15: superseded by a canonical structured rule; retained as inactive provenance.' where active and (" + where + ")")

                # Exact duplicate text is safely collapsed to the strongest
                # non-fragment row; no source row is physically deleted.
                cur.execute("""select id,rule_key,rule_text,source_basis,priority,privacy_scope
                    from public.zorg_logic_rules where active and rule_text is not null""")
                groups = {}
                for row in cur.fetchall():
                    groups.setdefault(norm(row[2]), []).append(row)
                for rows in groups.values():
                    if len(rows) < 2 or not rows[0][0]:
                        continue
                    keep = sorted(rows, key=lambda r: (
                        0 if not (r[1].startswith('core-rule::') or r[3] == 'core_markdown_structured_sync') else 1,
                        -len(r[2] or ''), r[1]))[0]
                    for row in rows:
                        if row[0] != keep[0]:
                            cur.execute("update public.zorg_logic_rules set active=false, updated_at=now(), performance_tuning_notes=coalesce(performance_tuning_notes,'') || E'\\n2026-07-15: exact duplicate collapsed to ' || %s where id=%s", (keep[1], row[0]))

                # Deactivated source rules must not remain active in the
                # derived ANN surface.  Source embeddings are preserved but
                # excluded from the filtered HNSW path.
                cur.execute("""update public.memory_ann_model_embeddings m
                    set active=false, updated_at=now()
                    where m.source_type='logic_rule'
                      and exists (select 1 from public.zorg_logic_rules r
                                 where r.id::text=m.source_key and not r.active)""")
                # A changed active rule can have an older content-hash
                # embedding. Preserve it for audit, but make only the current
                # source text eligible for filtered ANN recall.
                cur.execute("""update public.memory_ann_model_embeddings m
                    set active=false, updated_at=now()
                    from public.zorg_logic_rules r
                    where m.source_type='logic_rule' and m.source_key=r.id::text
                      and r.active
                      and m.active
                      and m.content_hash <> md5(concat_ws(E'\\n', r.rule_key, r.title,
                          r.rule_text, coalesce(array_to_string(r.applies_to,' '),''),
                          coalesce(array_to_string(r.standard_checks,' '),'')))""")

                affected = ['db-before-visible-response-proof-2026-07-15', 'credential-source-locator-core-2026-07-15', 'rule-failure-lockout-canonical-2026-07-15', 'canonical-ea-email-calendar-contact-33-database-backup-and-recovery-paths']
                for key in affected:
                    cur.execute("""insert into public.zorg_logic_rule_dynamic_weights
                        (rule_key,seed_weight,dynamic_weight,feedback_basis,metadata)
                        values (%s,90000,90000,'rule-normalization-2026-07-15',%s)
                        on conflict (rule_key) do update set dynamic_weight=greatest(public.zorg_logic_rule_dynamic_weights.dynamic_weight, excluded.dynamic_weight), updated_at=now()""", (key, json.dumps({'canonical': True, 'preflight_aware': True})))
                    cur.execute("""insert into public.memory_recall_hints
                        (source_type,source_key,hint_kind,hint_text,related_keys,weight,source_model,metadata,active)
                        select 'logic_rule',%s,'operator_exact_alias',%s,%s,900,'zorg-db-memory-migration',%s,true
                        where not exists (select 1 from public.memory_recall_hints where source_key=%s and hint_text=%s)""", (key, key.replace('-', ' '), affected, json.dumps({'migration':'2026-07-15'}), key, key.replace('-', ' ')))
                    payload = json.dumps({'source_type':'logic_rule','source_key':key,'reason':'scope-normalization-and-dedup'})
                    cur.execute("""insert into public.memory_semantic_work_queue
                        (job_kind,source_type,source_key,payload,payload_hash,priority,status,due_at)
                        values ('rule_embedding_refresh','logic_rule',%s,%s,%s,100,'queued',now())
                        on conflict do nothing""", (key, payload, hashlib.sha256(payload.encode()).hexdigest()))
                print({'canonical_rules': affected, 'mode': 'applied'})
    finally:
        conn.close()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
