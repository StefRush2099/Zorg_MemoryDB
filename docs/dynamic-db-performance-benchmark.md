# Dynamic DB Performance Benchmark

The dynamic DB performance benchmark is the going-forward backend speed test for Zorg MemoryDB. It replaces fixed legacy query-list timing with a workload discovered from the live database at run time.

The benchmark inspects installed public tables, recall functions, materialized recall views, recent query observations, task replay cases, runtime timing records, and PostgreSQL catalog statistics. It then selects representative cases, runs warmup and measured iterations, and records run/case/result metrics in additive benchmark tables.

Run it from an installed workspace:
OPENCLAW_WORKSPACE=/home/openclaw/.openclaw/workspace python /path/to/Zorg_MemoryDB/scripts/dynamic_db_performance_benchmark.py --apply-schema --json

The script reads the normal sql_memory_map.json connection settings. It does not read db_benchmark_queries.json and does not reuse the legacy memory_speed_test.py workload.

Stored result rows can include private live query text or runtime metadata, so public releases include only the schema, script, and documentation. Do not export live benchmark result data.

Created objects:

memory_dynamic_benchmark_runs

memory_dynamic_benchmark_cases

memory_dynamic_benchmark_results

The benchmark also writes a summary timing observation to memory_runtime_timing_observations when that table is present. This lets future tuning compare benchmark latency with worker/runtime timing without deleting or compacting source memory.

Use results as evidence for additive tuning only: indexes, materialized views, query-shape improvements, recall hints, or association layers. Never prune, truncate, or discard source memory to improve a score.
