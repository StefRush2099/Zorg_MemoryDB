#!/usr/bin/env python3
"""Install the bounded derived-result cache used by MemoryDB recall v2."""

import json
from pathlib import Path

import psycopg2


SKILL_ROOT = Path(__file__).resolve().parents[1]
CFG_PATH = SKILL_ROOT / "config" / "sql_memory_map.json"
SQL_PATH = SKILL_ROOT / "references" / "memory_recall_fast_cache.sql"


def main() -> None:
    cfg = json.loads(CFG_PATH.read_text(encoding="utf-8"))["postgres"]
    sql = SQL_PATH.read_text(encoding="utf-8")
    with psycopg2.connect(
        host=cfg["host"],
        port=cfg["port"],
        dbname=cfg["database"],
        user=cfg["user"],
        password=cfg["password"],
    ) as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
    print("installed memory_recall_fast_cached_v1")


if __name__ == "__main__":
    main()
