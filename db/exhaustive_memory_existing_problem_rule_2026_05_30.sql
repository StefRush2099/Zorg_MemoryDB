-- 2026-05-30 exhaustive memory existing-problem recovery rule
-- Public-safe structured rule seed. This updates DB rule rows only when applied;
-- it does not change installer/runtime behavior by itself.

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
  performance_tuning_notes
)
VALUES (
  'exhaustive-memory-existing-problem-recovery',
  'Exhaustive memory recovery for existing problems',
  'For an existing system, job, setting, integration, workflow, or prior assistant-built process failure, assume a working path previously existed and must be recovered from backend DB memory plus live state before asking the operator for help. Memory has priority over fresh reasoning because current context is often only the symptom. Search backend DB memory deeply and creatively with alternate names, relationships, adjacent projects, prior similar tasks, runbooks, cron payloads, scripts, credential-path references, and live configuration clues. If the first deep search finds no useful result, search the entire memory again with a different framing: what previously worked, what job or process created the surface, what helper or credential path was used, what repair fixed a similar failure, and what rule was violated by stopping early. Immediate answers, blockers, or help requests are disallowed while memory could contain the answer.',
  'memory_recall_enforcement',
  'critical',
  'public_safe',
  'operator_instruction_2026_05_30',
  ARRAY['memory','recall','existing_systems','cron','email','calendar','credentials_paths','runbooks','repair','support'],
  ARRAY[
    'Query backend DB memory before replying or acting',
    'For existing failures, assume a prior working path exists until exhausted',
    'Search alternate phrasing, related systems, runbooks, cron payloads, scripts, and credential-path references',
    'If the first deep search misses, rerun with a different framing before escalating',
    'When deeper search succeeds after a miss, add aliases, hints, observations, indexes, or rule rows without deleting source data'
  ],
  'Additive recall only: improve rule rows, recall hints, query observations, indexes, and materialized/search support while preserving all source memory.'
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
  updated_at = now(),
  active = true;

INSERT INTO public.memory_recall_hints (
  source_type,
  source_key,
  hint_kind,
  hint_text,
  related_keys,
  weight,
  source_model,
  metadata,
  active
)
VALUES (
  'logic_rule',
  'exhaustive-memory-existing-problem-recovery',
  'operator_phrase_alias',
  'Existing systems, jobs, settings, integrations, workflows, cron jobs, email/calendar flows, scripts, credential paths, and prior assistant-built processes must be recovered from backend DB memory and live state before asking the operator for help. Search prior working path, what previously worked, job payload, helper script, credential path, runbook, similar repair, and rule violation from stopping early.',
  ARRAY['scorched-memory-before-response','backend-memory-repair-supremacy','db-memory-first','prior-working-path','existing-system-recovery'],
  10,
  'manual-rule-publication-2026-05-30',
  jsonb_build_object('public_safe', true, 'repo_file', 'db/exhaustive_memory_existing_problem_rule_2026_05_30.sql'),
  true
)
ON CONFLICT DO NOTHING;
