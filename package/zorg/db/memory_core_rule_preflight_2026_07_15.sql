-- Core rule preflight weights and semantic structure.
-- Additive and source-preserving: this makes the approval gate the first
-- recall pipeline layer before any new or existing rule is selected.

insert into public.zorg_logic_rule_dynamic_weights
  (rule_key, seed_weight, dynamic_weight, use_count, positive_feedback_count,
   feedback_basis, metadata)
values
  ('prework-summary-requires-go-before-mutation-2026-07-14', 90000, 90000,
   1, 1, 'core mutation preflight gate',
   jsonb_build_object('core_rule_preflight', true, 'first_pipeline', true,
                      'reason', 'summary_then_GO_before_mutation'))
on conflict (rule_key) do update set
  seed_weight = greatest(public.zorg_logic_rule_dynamic_weights.seed_weight, excluded.seed_weight),
  dynamic_weight = greatest(public.zorg_logic_rule_dynamic_weights.dynamic_weight, excluded.dynamic_weight),
  positive_feedback_count = public.zorg_logic_rule_dynamic_weights.positive_feedback_count + 1,
  feedback_basis = excluded.feedback_basis,
  metadata = coalesce(public.zorg_logic_rule_dynamic_weights.metadata, '{}'::jsonb) || excluded.metadata,
  updated_at = now();

do $$
begin
  update public.memory_semantic_edges
  set weight = greatest(weight, 900),
      weight_basis = 'core rule preflight gate',
      llm_reason = 'Every rule execution must pass summary then uppercase GO mutation gate first',
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('core_rule_preflight', true),
      updated_at = now()
  where subject_type = 'logic_rule'
    and subject_key = 'prework-summary-requires-go-before-mutation-2026-07-14'
    and relation = 'precedes'
    and object_type = 'rule_pipeline'
    and object_key = 'all_core_rules';

  if not found then
    insert into public.memory_semantic_edges
      (subject_type, subject_key, relation, object_type, object_key, weight,
       weight_basis, llm_reason, source_model, evidence_source, metadata)
    values
      ('logic_rule', 'prework-summary-requires-go-before-mutation-2026-07-14',
       'precedes', 'rule_pipeline', 'all_core_rules', 900,
       'core rule preflight gate',
       'Every rule execution must pass summary then uppercase GO mutation gate first',
       'zorg-db-memory', 'operator_correction_2026-07-15',
       jsonb_build_object('core_rule_preflight', true));
  end if;
end $$;

create or replace function public.zorg_core_rule_preflight_v1()
returns table(rule_key text, rule_id text, title text, rule_text text, priority text, gate_order integer)
language sql stable as $$
  select r.rule_key, r.id::text, r.rule_title, r.rule_text, r.priority, 1
  from public.zorg_logic_rules r
  where r.rule_key = 'prework-summary-requires-go-before-mutation-2026-07-14'
    and coalesce(r.active,true)
$$;
