# Dynamic Trigger Backpressure

Zorg MemoryDB triggers must preserve immediate operator function. Database triggers and recall-adjacent hooks should not perform heavy work directly. They enqueue small, bounded, deferred work and let workers process it in statistically sized batches.

## Design rule

- Triggers enqueue at most tiny bounded work.
- `due_at` is delayed by `public.memory_dynamic_defer_interval(priority)` unless a caller explicitly provides a due time.
- The delay is derived from at least a 90-day rolling activity window when available, observed operator request timestamps/durations, idle gaps, queue wait, worker runtime, recall/query timing, backlog, CPU/load, and priority.
- Worker batch size is capped by `public.memory_dynamic_worker_batch_limit(requested_limit)`.
- Deeper indexing, trigger, and recall tuning should be postponed into statistically idle/off-hours windows. During historically active periods, workers should run only short bounded tuning bursts when current latency/load permits.
- High CPU/load/latency increases delay and reduces batch size.
- Rule-following and recall correctness outrank speed. Performance tuning must never prune, delete, or compact away source memory.

## Structural objects

Migration: `db/dynamic_trigger_backpressure_2026_05_16.sql`

Adds/updates:

- `memory_runtime_timing_observations`
- `memory_deferred_work_control`
- `memory_record_runtime_timing(...)`
- `memory_dynamic_defer_interval(priority)`
- `memory_dynamic_worker_batch_limit(requested_limit)`
- `memory_enqueue_semantic_job(...)`
- `zorg_weighted_recall_context(...)` timing observation
- `dynamic-trigger-backpressure-2026-05-16` structured logic rule

## Worker behavior

`memory_semantic_worker.py` now asks the database for an effective batch limit before claiming jobs. Failed jobs are requeued using the same dynamic delay logic instead of a fixed five-minute delay. Each batch records timing observations so future delay/batch decisions adapt to actual runtime conditions. Request/activity timing observations should be retained and evaluated as a rolling 90-day scheduling baseline wherever the install has enough history.

## Verification

Representative checks:

```bash
python scripts/memory_sql_tool.py search "dynamic trigger backpressure delay batch limit CPU recall" --table all --limit 5
python scripts/memory_semantic_worker.py --once --limit 25
```

Expected:

- search returns the dynamic trigger backpressure rule near the top;
- worker output includes `recommended_delay_seconds`;
- queued work has future `due_at` values under load instead of immediate CPU-heavy execution.
- scheduling decisions account for request activity and idle windows instead of using a same-day-only or fixed-delay model.
