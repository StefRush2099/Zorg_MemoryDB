-- Keep PostgreSQL-owned scheduled LLM jobs on the active OpenClaw model.
-- The dispatcher resolves this literal at execution time; no model ID belongs
-- in a durable job payload.

DO $$
BEGIN
  IF to_regclass('public.memory_llm_scheduled_jobs') IS NOT NULL THEN
    UPDATE public.memory_llm_scheduled_jobs
    SET payload = jsonb_set(payload, '{model}', to_jsonb('$CURRENT_MODEL'::text), true),
        external_state = CASE
          WHEN jsonb_typeof(external_state) = 'object'
           AND jsonb_typeof(external_state->'gateway_job') = 'object'
          THEN jsonb_set(
            external_state,
            '{gateway_job,payload,model}',
            to_jsonb('$CURRENT_MODEL'::text),
            true
          )
          ELSE external_state
        END,
        updated_at = now()
    WHERE coalesce(payload->>'kind', 'agentTurn') = 'agentTurn';
  END IF;
END $$;

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
  active,
  updated_at
)
VALUES (
  'db-scheduled-jobs-current-model-variable',
  'DB Scheduled Jobs Use Current Model Variable',
  'PostgreSQL-owned scheduled LLM jobs must store the literal $CURRENT_MODEL in payload.model instead of a pinned provider/model identifier. The DB dispatcher resolves $CURRENT_MODEL at execution time from the active OpenClaw agents.defaults.model.primary configuration and passes the resolved model to openclaw agent. This preserves each job function while allowing the configured current model to change safely. Before broad model changes, verify the active OpenClaw model is present in the live allowlist and run a bounded non-destructive probe.',
  'operating_rule',
  'critical',
  'public_safe',
  'current_model_scheduler_variable_2026_07_11',
  ARRAY['cron','scheduled_jobs','memory_llm_scheduled_jobs','payload.model','CURRENT_MODEL','dispatcher']::text[],
  ARRAY['Store payload.model as $CURRENT_MODEL','Resolve at dispatch time from active OpenClaw default','Do not embed a stale model ID in scheduled payloads','Verify the active model allowlist before broad changes']::text[],
  true,
  now()
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
