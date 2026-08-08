#!/usr/bin/env python3
import json
import os
from pathlib import Path
import psycopg2

workspace = Path(os.environ.get("OPENCLAW_WORKSPACE") or os.environ.get("WORKSPACE_DIR") or Path(__file__).resolve().parents[3])
config_path = Path(os.environ.get("SQL_MEMORY_MAP") or os.environ.get("ZORG_SQL_MEMORY_MAP") or workspace / "skills/zorg-db-memory/config/sql_memory_map.json")
config = json.loads(config_path.read_text(encoding="utf-8"))["postgres"]
sql_path = Path(__file__).resolve().parents[1] / "references/cognitive-memory-v1.sql"
with psycopg2.connect(**config) as conn:
    with conn.cursor() as cur:
        cur.execute(sql_path.read_text(encoding="utf-8"))
print("Cognitive Memory v1 schema and functions applied.")
