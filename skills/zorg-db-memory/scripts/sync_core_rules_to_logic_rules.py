#!/usr/bin/env python3
"""Upsert core markdown operating rules into structured zorg_logic_rules.

This keeps human-readable rule files and DB-enforced structured recall aligned.
It imports rules from core markdown in the local workspace only; it ships no data.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import psycopg2

BASE = Path(__file__).resolve().parents[1]
WORKSPACE = Path.cwd()
MAP = BASE / 'config' / 'sql_memory_map.json'
FILES = ['ZORG_MEMORYDB_MASTER_RULES.md', 'AGENTS.md', 'SOUL.md', 'USER.md', 'TOOLS.md', 'IDENTITY.md', 'HEARTBEAT.md']
KEYWORDS = re.compile(r'\b(rule|directive|policy|mandate|must|always|never|hard|critical|before|default|do not|required|only)\b', re.I)
EMAIL_RE = re.compile(r'email|gmail|outbound|rich text|html|cc|bcc|recipient|contact|communication', re.I)


def main() -> None:
    cfg = json.loads(MAP.read_text())['postgres']
    rows = []
    for fn in FILES:
        path = WORKSPACE / fn
        if not path.exists():
            continue
        current = ''
        for i, line in enumerate(path.read_text(encoding='utf-8', errors='ignore').splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith('#'):
                current = stripped.lstrip('#').strip()
            if not stripped or stripped.startswith('<!--'):
                continue
            if KEYWORDS.search(stripped) or KEYWORDS.search(current):
                text = f'{current}: {stripped}' if current and not stripped.startswith('#') else stripped
                priority = 'critical' if re.search(r'hard|critical|never|must|always|non-negotiable|mandatory', text, re.I) else 'high'
                rule_type = 'email' if EMAIL_RE.search(text) else 'operating_rule'
                rows.append((f'core-rule::{fn}:{i}', f'{fn}:{i} {current or "Core rule"}', text, rule_type, priority, [fn, 'core_markdown']))
    conn = psycopg2.connect(host=cfg['host'], port=cfg['port'], dbname=cfg['database'], user=cfg['user'], password=cfg.get('password', ''))
    with conn:
        with conn.cursor() as cur:
            for key, title, text, typ, priority, applies in rows:
                cur.execute(
                    """
                    insert into public.zorg_logic_rules
                      (rule_key,title,rule_text,rule_type,priority,privacy_scope,source_basis,applies_to,standard_checks,active)
                    values (%s,%s,%s,%s,%s,%s,%s,%s,%s,true)
                    on conflict (rule_key) do update set
                      title=excluded.title, rule_text=excluded.rule_text, rule_type=excluded.rule_type,
                      priority=excluded.priority, privacy_scope=excluded.privacy_scope,
                      source_basis=excluded.source_basis, applies_to=excluded.applies_to,
                      standard_checks=excluded.standard_checks, active=true, updated_at=now()
                    """,
                    (key, title, text, typ, priority, 'private', 'core_markdown_structured_sync', applies,
                     ['Recall this structured rule before acting when relevant', 'Prefer structured DB rule over stale flat-file habits']),
                )
            for proc in ['refresh_zorg_memory_search_mv', 'refresh_zorg_memory_search_fast_mv', 'refresh_zorg_master_context']:
                cur.execute('select to_regprocedure(%s)', (f'public.{proc}()',))
                if cur.fetchone()[0]:
                    cur.execute(f'select public.{proc}()')
    print(f'structured_rules_upserted={len(rows)}')


if __name__ == '__main__':
    main()
