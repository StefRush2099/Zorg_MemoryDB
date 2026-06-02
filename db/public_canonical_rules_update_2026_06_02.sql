-- Public-safe canonical rule update for Zorg MemoryDB installs.
--
-- Purpose:
-- 1. Move active rule enforcement to public.zorg_logic_rules.
-- 2. Retire active rows in the older compatibility tables.
-- 3. Seed/update only sanitized public-safe rules.
-- 4. Raise existing operator-visible chat timing rule weights without creating
--    replacement timing rules.
--
-- This file contains structure and sanitized operating rules only. It does not
-- include private memory rows, contacts, transcripts, credentials, live DB
-- dumps, account data, or operator-private context.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.zorg_logic_rule_dynamic_weights (
  rule_key text PRIMARY KEY,
  seed_weight numeric(12,5) NOT NULL DEFAULT 1,
  dynamic_weight numeric(12,5) NOT NULL DEFAULT 1,
  use_count integer NOT NULL DEFAULT 0,
  positive_feedback_count integer NOT NULL DEFAULT 0,
  negative_feedback_count integer NOT NULL DEFAULT 0,
  last_recalled_at timestamptz,
  last_feedback_at timestamptz,
  feedback_basis text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE VIEW public.zorg_logic_rule_dynamic_ranking_v AS
SELECT
  r.rule_key,
  r.title,
  r.priority,
  r.privacy_scope,
  r.rule_type,
  coalesce(w.seed_weight, 1) AS seed_weight,
  coalesce(w.dynamic_weight, 1) AS dynamic_weight,
  coalesce(w.seed_weight, 1) * coalesce(w.dynamic_weight, 1) AS effective_weight,
  coalesce(w.use_count, 0) AS use_count,
  coalesce(w.positive_feedback_count, 0) AS positive_feedback_count,
  coalesce(w.negative_feedback_count, 0) AS negative_feedback_count,
  w.last_recalled_at,
  w.last_feedback_at,
  r.updated_at AS rule_updated_at
FROM public.zorg_logic_rules r
LEFT JOIN public.zorg_logic_rule_dynamic_weights w
  ON w.rule_key = r.rule_key
WHERE coalesce(r.active, true) = true;

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
  performance_tuning_notes,
  active
)
VALUES
(
  'memorydb_news_updates_technical_overview_performance_impact',
  'MemoryDB News Updates Technical Overview And Performance Impact',
  'When publishing public MemoryDB or backend-memory news updates, include a fresh technical overview for new readers before describing the current change. Cover database-memory structure, SQL gate, DB-backed recall, durable rules, operational facts, runbooks, semantic/vector/weighted recall, additive performance structures, and how these support reliable assistant continuity. This is additive to normal reporting and must remain public-safe.',
  'database_memory_public_reporting',
  '95',
  'system_hard_mandatory',
  'canonicalized_public_rule_update',
  ARRAY['memorydb','public_reporting','backend_memory','documentation'],
  ARRAY['Explain the current MemoryDB structure before the change','Keep the report public-safe','Do not publish private DB rows or operator context'],
  'Public technical reporting should explain the additive recall architecture without exposing private state.',
  true
),
(
  'recursive_self_improvement_crons_preauthorized',
  'Recursive Self Improvement Crons Preauthorized',
  'Recursive self-improvement cron jobs may execute additive, non-destructive backend DB memory, recall, benchmark, index, materialized-view, semantic/vector/weighted-recall, documentation, and cron-prompt improvements without waiting for separate approval when the work preserves source data, follows DB-memory safety gates, records the change, and verifies the result. They must not encode hidden policy or destructive behavior in scripts.',
  'database_memory_maintenance_rule',
  '95',
  'system_hard_mandatory',
  'canonicalized_public_rule_update',
  ARRAY['memorydb','cron','recall','benchmark','semantic_recall','documentation'],
  ARRAY['Use additive changes only','Preserve source data','Verify recall after changes','Keep policy in rules and LLM instructions, not blind scripts'],
  'Supports neural/vector-style evolution while preserving source memory and public-safe documentation.',
  true
),
(
  'docker_change_restart_verify_browser',
  'Docker Change Restart Verify Browser',
  'When changing containerized services, restart or redeploy the affected container/service and verify the real browser-visible or runtime surface before reporting done.',
  'operating_rule',
  'critical',
  'public_safe',
  'canonicalized_public_rule_update',
  ARRAY['docker','container','service','verification'],
  ARRAY['Restart or redeploy the affected service','Verify the real runtime/browser surface','Report exact blocker if verification cannot be completed'],
  NULL,
  true
),
(
  'operator_instructions_additive_by_default',
  'Operator Instructions Additive By Default',
  'Treat current operator instructions as additive by default. Do not treat a newer instruction as replacing, removing, narrowing, or superseding an older instruction unless the operator explicitly says it supersedes, replaces, removes, overrides, or cancels the earlier instruction.',
  'operating_rule',
  'high',
  'public_safe',
  'canonicalized_public_rule_update',
  ARRAY['operator_instruction','scope','rule_interpretation'],
  ARRAY['Preserve older compatible instructions','Only supersede when explicitly told','Resolve conflicts by the narrower safe reading'],
  NULL,
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
  performance_tuning_notes = excluded.performance_tuning_notes,
  active = true,
  updated_at = now();

DO $$
BEGIN
  IF to_regclass('public.zorg_rules') IS NOT NULL THEN
    UPDATE public.zorg_rules SET enabled = false, updated_at = now() WHERE enabled = true;
  END IF;

  IF to_regclass('public.zorg_rule_catalog') IS NOT NULL THEN
    UPDATE public.zorg_rule_catalog SET enabled = false, updated_at = now() WHERE enabled = true;
  END IF;
END $$;

INSERT INTO public.zorg_logic_rule_dynamic_weights (
  rule_key,
  seed_weight,
  dynamic_weight,
  use_count,
  positive_feedback_count,
  negative_feedback_count,
  last_feedback_at,
  feedback_basis,
  metadata,
  created_at,
  updated_at
)
VALUES
(
  'operator-visible-db-scan-timestamp-duration-hard-rule-2026-05-23',
  100,
  30,
  0,
  1,
  0,
  now(),
  'public_update_chat_timing_bottom_response_weight',
  '{"operator_visible_timing":"bottom_time_summary_required","changed_surface":"dynamic weights only","no_new_rule":true}'::jsonb,
  now(),
  now()
),
(
  'chat-verified-backend-memory-checked-line-2026-05-24',
  100,
  30,
  0,
  1,
  0,
  now(),
  'public_update_chat_timing_bottom_response_weight',
  '{"operator_visible_timing":"verified_backend_memory_checked_line_required","changed_surface":"dynamic weights only","no_new_rule":true}'::jsonb,
  now(),
  now()
),
(
  'visible-chat-response-secret-query-timing-2026-06-01',
  100,
  30,
  0,
  1,
  0,
  now(),
  'public_update_chat_timing_bottom_response_weight',
  '{"operator_visible_timing":"bottom_time_summary_required","changed_surface":"dynamic weights only","no_new_rule":true}'::jsonb,
  now(),
  now()
),
(
  'operator-visible-reply-rule-audit-vector-neural-repair-2026-06-01',
  100,
  30,
  0,
  1,
  0,
  now(),
  'public_update_chat_timing_bottom_response_weight',
  '{"operator_visible_timing":"reply_format_rules_must_rank_first","changed_surface":"dynamic weights only","no_new_rule":true}'::jsonb,
  now(),
  now()
)
ON CONFLICT (rule_key) DO UPDATE SET
  seed_weight = greatest(public.zorg_logic_rule_dynamic_weights.seed_weight, excluded.seed_weight),
  dynamic_weight = greatest(public.zorg_logic_rule_dynamic_weights.dynamic_weight, excluded.dynamic_weight),
  positive_feedback_count = public.zorg_logic_rule_dynamic_weights.positive_feedback_count + 1,
  last_feedback_at = now(),
  feedback_basis = excluded.feedback_basis,
  metadata = coalesce(public.zorg_logic_rule_dynamic_weights.metadata, '{}'::jsonb) || excluded.metadata,
  updated_at = now();

DO $$
BEGIN
  IF to_regprocedure('public.refresh_zorg_memory_search_mv()') IS NOT NULL THEN
    PERFORM public.refresh_zorg_memory_search_mv();
  END IF;

  IF to_regprocedure('public.refresh_zorg_memory_search_fast_mv()') IS NOT NULL THEN
    PERFORM public.refresh_zorg_memory_search_fast_mv();
  END IF;

  IF to_regprocedure('public.refresh_zorg_master_context()') IS NOT NULL THEN
    PERFORM public.refresh_zorg_master_context();
  END IF;
END $$;
