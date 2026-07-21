-- Canonical source for the existing live rule-feedback procedure.
-- This migration preserves the deployed procedure name and signature.

CREATE OR REPLACE FUNCTION public.zorg_record_logic_rule_feedback(
  p_rule_key text,
  p_query_text text DEFAULT ''::text,
  p_delta numeric DEFAULT 0.25,
  p_feedback_kind text DEFAULT 'llm_runtime_feedback'::text,
  p_reason text DEFAULT NULL::text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
  v_delta numeric := greatest(-2.0, least(2.0, coalesce(p_delta, 0)));
  v_current numeric;
  v_rule_id uuid;
BEGIN
  INSERT INTO public.zorg_logic_rule_dynamic_weights(
    rule_key, seed_weight, dynamic_weight, feedback_basis, metadata
  )
  SELECT
    r.rule_key,
    public.zorg_logic_rule_seed_weight(r.priority, r.applies_to),
    1.0,
    p_reason,
    coalesce(p_metadata, '{}'::jsonb)
  FROM public.zorg_logic_rules r
  WHERE r.rule_key = p_rule_key
  ON CONFLICT (rule_key) DO NOTHING;

  SELECT id INTO v_rule_id FROM public.zorg_logic_rules WHERE rule_key = p_rule_key;
  SELECT dynamic_weight INTO v_current
  FROM public.zorg_logic_rule_dynamic_weights WHERE rule_key = p_rule_key;

  IF v_rule_id IS NOT NULL AND v_current IS NOT NULL THEN
    INSERT INTO public.memory_retrieval_feedback(
      query_text, source_type, source_key, feedback_score,
      feedback_kind, reason, metadata
    )
    VALUES (
      coalesce(p_query_text, ''), 'logic_rule', p_rule_key,
      v_delta, p_feedback_kind, p_reason, coalesce(p_metadata, '{}'::jsonb)
    );

    INSERT INTO public.memory_query_observations(
      query_text, query_intent, source_type, source_key,
      was_useful, usefulness_score, feedback_basis, metadata
    )
    VALUES (
      coalesce(p_query_text, ''), 'logic_rule_dynamic_ranking',
      'logic_rule', p_rule_key,
      CASE WHEN v_delta >= 0 THEN true ELSE false END,
      v_delta, p_reason, coalesce(p_metadata, '{}'::jsonb)
    );

    INSERT INTO public.memory_semantic_work_queue(
      job_kind, source_type, source_key, payload, payload_hash, priority, due_at
    ) VALUES (
      'dynamic_rule_feedback', 'logic_rule', v_rule_id::text,
      jsonb_build_object(
        'rule_id', v_rule_id, 'rule_key', p_rule_key,
        'query_text', coalesce(p_query_text, ''), 'delta', v_delta,
        'feedback_kind', p_feedback_kind, 'reason', p_reason,
        'metadata', coalesce(p_metadata, '{}'::jsonb),
        'source_event', 'zorg_record_logic_rule_feedback'
      ),
      public.memory_semantic_payload_hash(jsonb_build_object(
        'rule_id', v_rule_id, 'rule_key', p_rule_key,
        'query_text', coalesce(p_query_text, ''), 'delta', v_delta,
        'feedback_kind', p_feedback_kind, 'reason', p_reason,
        'metadata', coalesce(p_metadata, '{}'::jsonb),
        'source_event', 'zorg_record_logic_rule_feedback'
      )), 90, now()
    )
    ON CONFLICT (job_kind, source_type, source_key, payload_hash)
      WHERE status IN ('queued','running')
    DO UPDATE SET priority=greatest(public.memory_semantic_work_queue.priority, excluded.priority),
                  due_at=least(public.memory_semantic_work_queue.due_at, excluded.due_at),
                  payload=public.memory_semantic_work_queue.payload || excluded.payload,
                  updated_at=now();
  END IF;

  RETURN v_current;
END;
$$;

COMMENT ON FUNCTION public.zorg_record_logic_rule_feedback(
  text, text, numeric, text, text, jsonb
) IS 'Existing DB-owned rule feedback and dynamic-weight update procedure.';
