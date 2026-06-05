-- Public-safe runtime DB-only memory writer and visible timing rules.
-- This publishes rule structure only. It contains no private memory rows,
-- credentials, contacts, transcripts, or live database dumps.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.zorg_logic_rules (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  rule_key text UNIQUE NOT NULL,
  title text NOT NULL,
  rule_text text NOT NULL,
  rule_type text NOT NULL DEFAULT 'operating_rule',
  priority text NOT NULL DEFAULT 'high',
  privacy_scope text NOT NULL DEFAULT 'public_safe',
  source_basis text,
  applies_to text[] NOT NULL DEFAULT ARRAY[]::text[],
  standard_checks text[] NOT NULL DEFAULT ARRAY[]::text[],
  performance_tuning_notes text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.zorg_logic_rules (
  rule_key,
  title,
  rule_text,
  rule_type,
  priority,
  privacy_scope,
  source_basis,
  applies_to,
  standard_checks,
  active
)
VALUES
(
  'db-memory-before-visible-response',
  'DB Memory Before Visible Response',
  'Before any user-visible response, status update, question, blocker report, completion claim, tool-changing action, or file/config/database mutation, route through PostgreSQL-backed Zorg MemoryDB first. If DB recall is unavailable, repair or restore the DB path before normal response generation.',
  'memory_rule',
  'critical',
  'public_safe',
  'public_runtime_rule_update_2026_06_04',
  ARRAY['memory','recall','visible_reply','status_update','tool_use']::text[],
  ARRAY['Run DB-backed recall before visible response','Repair DB recall instead of falling back to markdown memory','Do not answer from chat context alone']::text[],
  true
),
(
  'runtime-db-only-memory-writer-hard-stop',
  'Runtime DB-Only Memory Writer Hard Stop',
  'DB-only installs must not allow OpenClaw runtime hooks to create retired markdown memory files such as memory/YYYY-MM-DD.md or memory/YYYY-MM-DD-HHMM.md. Patch or disable file-backed session-memory and pre-compaction memoryFlush writers. If a retired memory file still appears, import it into PostgreSQL and remove the filesystem copy after successful import.',
  'memory_rule',
  'critical',
  'public_safe',
  'public_runtime_rule_update_2026_06_04',
  ARRAY['memory','runtime','session-memory','memoryFlush','autoheal']::text[],
  ARRAY['Patch session-memory markdown writer','Disable file-backed compaction memoryFlush','Import any recreated memory file into DB','Remove filesystem copy only after DB import']::text[],
  true
),
(
  'user-visible-timestamp-duration-rule',
  'User-Visible Timestamp / Duration Rule',
  'Operational progress updates, blocker reports, completion claims, and final source-channel replies must include concrete timestamps when timing is relevant or after timing behavior has been challenged. Use the inbound message timestamp as request time, the actual send time as response time, and compute duration from those two real values only after the response time is known.',
  'operating_rule',
  'critical',
  'public_safe',
  'public_runtime_rule_update_2026_06_04',
  ARRAY['visible_reply','timing','duration','status_update']::text[],
  ARRAY['Use inbound timestamp as request time','Use actual send time as response time','Compute duration only after response time is known']::text[],
  true
)
ON CONFLICT (rule_key) DO UPDATE SET
  title = excluded.title,
  rule_text = excluded.rule_text,
  rule_type = excluded.rule_type,
  priority = excluded.priority,
  privacy_scope = excluded.privacy_scope,
  source_basis = excluded.source_basis,
  applies_to = excluded.applies_to,
  standard_checks = excluded.standard_checks,
  active = true,
  updated_at = now();
