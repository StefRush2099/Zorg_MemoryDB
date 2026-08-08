#!/usr/bin/env python3
import json
import os
import time
import subprocess
from pathlib import Path
import psycopg2
from psycopg2.extras import Json

workspace = Path(os.environ.get("OPENCLAW_WORKSPACE") or os.environ.get("WORKSPACE_DIR") or Path(__file__).resolve().parents[3])
config_path = Path(os.environ.get("SQL_MEMORY_MAP") or os.environ.get("ZORG_SQL_MEMORY_MAP") or workspace / "skills/zorg-db-memory/config/sql_memory_map.json")
config = json.loads(config_path.read_text(encoding="utf-8"))["postgres"]
checks = {}
details = {}
started = time.perf_counter()
TARGET_RULE = "f5629b7b-8b5c-452f-b6fe-97eab42a0733"
ANN_VARIANTS = [
  "make the memory database work like a real brain",
  "cognitive memory working episodic semantic procedural prospective spreading activation",
  "remember contradictions unfinished goals intentions corrections and superseded beliefs",
]
cache_script = Path(__file__).resolve().parent / "cache_query_embedding.py"
cache_results = [subprocess.run([str(workspace / ".venv-sqlmem/bin/python"), str(cache_script), query], capture_output=True, text=True, timeout=30).returncode == 0 for query in ANN_VARIANTS]
with psycopg2.connect(**config) as conn:
    with conn.cursor() as cur:
        names = [
          "memory_cognitive_working_set","memory_cognitive_episodes","memory_cognitive_beliefs",
          "memory_cognitive_procedures","memory_cognitive_intentions","memory_cognitive_consolidation_runs"
        ]
        cur.execute("select count(*) from information_schema.tables where table_schema='public' and table_name=any(%s)",(names,))
        checks["schema"] = cur.fetchone()[0] == len(names)

        cur.execute("select source_type,rank,source_id from public.memory_cognitive_recall_v1(%s,8,%s) order by rank",(
          "You have full access to GitHub; check memory before saying you cannot create the repository",
          Json({"goal":"recover prior capability"})
        ))
        rows=cur.fetchall()
        checks["rank_one_preflight"] = bool(rows and rows[0][1] == 1 and rows[0][0] == "logic_rule" and rows[0][2] == "06c34f0e-c294-4b40-a46b-3bb3073aeb39")
        details["recall_rows"] = len(rows)

        cur.execute("select count(*) from public.memory_cognitive_spreading_activation_v1(array(select node_key from public.memory_semantic_nodes where active limit 1),'memory',3,.62,20)")
        details["activation_rows"] = cur.fetchone()[0]
        checks["spreading_activation"] = details["activation_rows"] >= 1

        cur.execute("savepoint cognitive_fixture")
        cur.execute("""
          insert into public.memory_cognitive_beliefs(
            belief_key,proposition,belief_status,confidence,source_quality,provenance
          ) values('benchmark:cognitive-belief','Cognitive benchmark fixture','current',.9,.9,'{"fixture":true}')
        """)
        cur.execute("select count(*) from public.memory_cognitive_current_beliefs_v1('cognitive benchmark',20)")
        details["belief_rows"] = cur.fetchone()[0]
        checks["belief_selection"] = details["belief_rows"] >= 1

        cur.execute("""
          insert into public.memory_cognitive_intentions(
            intention_key,goal_text,trigger_context,status,priority,due_at,provenance
          ) values('benchmark:cognitive-intention','Exercise prospective recall',
                   '{"project":"cognitive-memory-v1"}','pending',90,now()-interval '1 second','{"fixture":true}')
        """)
        cur.execute("""
          select count(*) from public.memory_cognitive_due_intentions_v1(
            '{"project":"cognitive-memory-v1"}'::jsonb,now(),20
          ) where intention_key='benchmark:cognitive-intention'
        """)
        details["due_intentions"] = cur.fetchone()[0]
        checks["prospective_memory"] = details["due_intentions"] == 1
        cur.execute("rollback to savepoint cognitive_fixture")

        cur.execute("select count(*) from public.memory_cognitive_consolidation_runs where status='ok'")
        checks["consolidation_evidence"] = cur.fetchone()[0] > 0

        cur.execute("select count(*) from public.memory_ann_model_embeddings where active")
        details["active_embeddings"] = cur.fetchone()[0]
        checks["ann_embeddings"] = details["active_embeddings"] > 0

        ann_ranks = {}
        for query, cached in zip(ANN_VARIANTS, cache_results):
            cur.execute("set local hnsw.ef_search=400")
            cur.execute("select source_id from public.memory_provider_ann_recall_fast_v1(%s,20,'local','embeddinggemma-300m-qat-q8_0')", (query,))
            ids = [row[0] for row in cur.fetchall()]
            ann_ranks[query] = ids.index(TARGET_RULE) + 1 if TARGET_RULE in ids else None
        details["cognitive_ann_ranks"] = ann_ranks
        checks["ann_cognitive_variants"] = all(cache_results) and all(rank is not None and rank <= 20 for rank in ann_ranks.values())

        cur.execute("savepoint contradiction_fixture")
        cur.execute("insert into public.memory_cognitive_beliefs(belief_key,proposition,belief_status,confidence,source_quality,contradiction_group,provenance) values('benchmark:old-belief','The old state is active','superseded',.6,.7,'benchmark-state','{\"fixture\":true}') returning id")
        old_id = cur.fetchone()[0]
        cur.execute("insert into public.memory_cognitive_beliefs(belief_key,proposition,belief_status,confidence,source_quality,contradiction_group,supersedes_id,provenance) values('benchmark:new-belief','The corrected state is active','current',.95,.95,'benchmark-state',%s,'{\"fixture\":true}')", (old_id,))
        cur.execute("select proposition from public.memory_cognitive_current_beliefs_v1('corrected state',10)")
        current = [row[0] for row in cur.fetchall()]
        details["contradiction_current"] = current
        checks["contradiction_supersession"] = 'The corrected state is active' in current and 'The old state is active' not in current
        cur.execute("rollback to savepoint contradiction_fixture")

        cur.execute("select count(*) from public.memory_cognitive_recall_v1(%s,8,%s)", ('I corrected this failure before; remember the successful repair and unfinished goal', Json({'goal':'correction replay','unfinished':True})))
        details["correction_replay_rows"] = cur.fetchone()[0]
        checks["correction_replay"] = details["correction_replay_rows"] == 8

        cur.execute("select count(*) from public.memory_event_occurrences")
        details["source_event_rows"] = cur.fetchone()[0]
        checks["source_preserved"] = details["source_event_rows"] > 0

ok=all(checks.values())
print(json.dumps({"ok":ok,"checks":checks,"details":details,"duration_ms":round((time.perf_counter()-started)*1000,3)},sort_keys=True))
raise SystemExit(0 if ok else 1)
