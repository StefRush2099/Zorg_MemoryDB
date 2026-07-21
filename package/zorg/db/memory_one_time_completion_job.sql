-- Clean-install source for the bounded one-time completion job.
-- The canonical migration is db/migrations/2026-07-16_one_time_memory_completion_job.sql.
-- Keep this package copy discoverable by clean installers and release verification.
\i ../../../../db/migrations/2026-07-16_one_time_memory_completion_job.sql
