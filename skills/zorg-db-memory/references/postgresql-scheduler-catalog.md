# PostgreSQL Scheduler Catalog

This catalog is part of the canonical `zorg-db-memory` skill package. It is
the source-level checklist for new systems and must stay synchronized with the
live PostgreSQL scheduler tables.

## Scheduler classes

| Class | PostgreSQL surface | Purpose |
| --- | --- | --- |
| Core system maintenance | `public.memory_db_scheduled_jobs` | Database-owned MemoryDB maintenance and run history |
| Private/LLM scheduled jobs | `public.memory_llm_scheduled_jobs` and `public.memory_llm_job_queue` | Natural-language tasks dispatched by the single LLM listener |
| Active pg_cron | `cron.job` | Database firing layer that enqueues or invokes named jobs |

### Core/LLM schedule class

The following MemoryDB-owned LLM schedules are classified as `core_llm`.
They are platform maintenance and operating jobs, not personal/operator jobs:

`nightly-rule-weight-review`, `daily-db-memory-performance-repair`,
`daily-work-and-rules-summary`, `memory-db-performance-tuning-review`,
`openclaw-cron-health-audit-and-repair`, `local-disk-free-space-threshold-check`,
`db-only-memory-recall-autoheal`, `memory-semantic-neural-association-worker`,
`zorg-progress-score-refresh`, `zorg-memory-ann-maintenance`, and
`zorg-memory-ann-prefill`.

For these rows, set `source_scheduler = 'core-llm'`,
`metadata.job_class = 'core_llm'`, and `metadata.owner = 'core_llm'`.
Do not retain operator names, personal chat IDs, personal delivery targets, or
operator-specific failure alerts in their payload, delivery, or metadata.
ANN jobs must invoke the canonical scripts shipped in this skill; they must not
refer to retired workspace `memory/` paths.

## Core maintenance catalog

Every row below must exist, be enabled, and have the listed function in the
live `public.memory_db_scheduled_jobs` table. The catalog contains no
host-specific credentials or connection values.

| `job_key` | `job_kind` | Schedule | PostgreSQL function |
| --- | --- | --- | --- |
| `memory-nightly-health-0320` | `memory_nightly_health_check` | Daily at 03:20 America/Los_Angeles | `public.memory_db_health_check_sql()` |
| `memory-semantic-worker-15m` | `memory_semantic_worker` | Every 900 seconds | `public.memory_db_semantic_worker_batch_sql(integer)` |

## New-system verification

After applying the skill's PostgreSQL schema/functions and seed/upsert path:

1. Ensure each catalog row is enabled, has its schedule/timezone, owner
   `database`, correct `db_function` metadata, and run-history support.
2. Configure `cron.job` only as a firing layer. Every active pg_cron row must
   map to a named database schedule or function; it must not contain policy.
3. Run the catalog count and mapping checks:

```sql
select job_key, job_kind, enabled, metadata->>'db_function'
from public.memory_db_scheduled_jobs order by job_key;

select count(*) as core_jobs,
       count(*) filter (where enabled) as enabled_core_jobs
from public.memory_db_scheduled_jobs;

select count(*) as private_llm_jobs,
       count(*) filter (where enabled) as enabled_private_llm_jobs
from public.memory_llm_scheduled_jobs;

select count(*) as active_pg_cron_jobs from cron.job where active;
```

Release verification must fail if a catalog job is missing, disabled, has a
different function, lacks run history, or exists only in live database state.
The catalog, schema/function source, seed/upsert path, and verification path
must all be included in the GitHub repository and package artifact.
