#!/usr/bin/env python3
"""Apply the public-safe v2.0.18 rule-scope migration.

The live install may additionally run the full private-overlay migration from
the local skill. This public copy intentionally exports no private rule text.
"""
from pathlib import Path
import json
import os
import psycopg2

ROOT = Path(__file__).resolve().parents[1]
cfg_path = Path(os.environ.get("SQL_MEMORY_MAP", ROOT / "config" / "sql_memory_map.json"))
cfg = json.loads(cfg_path.read_text())["postgres"]
sql = (ROOT.parent.parent / "package" / "zorg" / "db" / "memory_rule_scope_dedup_2026_07_15.sql").read_text()

with psycopg2.connect(**cfg) as conn:
    with conn.cursor() as cur:
        cur.execute(sql)
print("public-safe rule scope migration applied")
