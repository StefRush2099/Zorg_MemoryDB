-- Additive recursive logic / proactive quality-control layer for Zorg MemoryDB.
-- Stores deduced operating logic, source basis, and standard precaution checks.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS public.zorg_logic_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key text NOT NULL UNIQUE,
  title text NOT NULL,
  rule_text text NOT NULL,
  rule_type text NOT NULL DEFAULT 'deduced_operating_logic',
  priority text NOT NULL DEFAULT 'high',
  privacy_scope text NOT NULL DEFAULT 'private',
  source_basis text NOT NULL DEFAULT 'operator_instruction',
  applies_to text[] NOT NULL DEFAULT ARRAY[]::text[],
  standard_checks text[] NOT NULL DEFAULT ARRAY[]::text[],
  performance_tuning_notes text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.zorg_logic_rule_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key text NOT NULL REFERENCES public.zorg_logic_rules(rule_key) ON DELETE CASCADE,
  source_type text NOT NULL,
  source_ref text,
  source_summary text NOT NULL,
  private_context boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.zorg_logic_rule_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key text NOT NULL REFERENCES public.zorg_logic_rules(rule_key) ON DELETE CASCADE,
  applied_at timestamptz NOT NULL DEFAULT now(),
  task_category text,
  object_type text,
  object_ref text,
  check_performed text NOT NULL,
  result_summary text,
  followup_needed boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_type_priority ON public.zorg_logic_rules(rule_type, priority);
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_applies_gin ON public.zorg_logic_rules USING gin(applies_to);
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_text_trgm ON public.zorg_logic_rules USING gin ((title || E'\n' || rule_text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_text_fts_en ON public.zorg_logic_rules USING gin (to_tsvector('english', title || E'\n' || rule_text));
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rule_apps_key_time ON public.zorg_logic_rule_applications(rule_key, applied_at DESC);

CREATE OR REPLACE FUNCTION public.zorg_logic_rule_content(r public.zorg_logic_rules)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT concat_ws(E'\n',
    'Logic rule: ' || coalesce(r.title,''),
    'Key: ' || coalesce(r.rule_key,''),
    'Type: ' || coalesce(r.rule_type,''),
    'Priority: ' || coalesce(r.priority,''),
    'Privacy: ' || coalesce(r.privacy_scope,''),
    'Source basis: ' || coalesce(r.source_basis,''),
    'Rule: ' || coalesce(r.rule_text,''),
    'Applies to: ' || coalesce(array_to_string(r.applies_to, ', '),''),
    'Standard checks: ' || coalesce(array_to_string(r.standard_checks, '; '),''),
    'Performance tuning: ' || coalesce(r.performance_tuning_notes,'')
  )
$$;

CREATE OR REPLACE VIEW public.zorg_logic_rules_recall_v AS
SELECT
  'logic_rule'::text AS source_table,
  r.id::text AS source_id,
  r.updated_at AS event_ts,
  r.rule_type AS category,
  r.priority,
  public.zorg_logic_rule_content(r) AS content
FROM public.zorg_logic_rules r
WHERE coalesce(r.active,true) = true;

CREATE OR REPLACE FUNCTION public.zorg_get_logic_context(p_query text, p_limit integer DEFAULT 5)
RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
LANGUAGE sql
AS $$
  SELECT
    'logic_rule'::text,
    r.id::text,
    null::text,
    null::integer,
    null::integer,
    r.priority,
    public.zorg_logic_rule_content(r)
  FROM public.zorg_logic_rules r
  WHERE coalesce(r.active,true) = true
    AND (
      lower(r.title || E'\n' || r.rule_text || E'\n' || coalesce(array_to_string(r.applies_to,' '),'')) LIKE '%' || lower(coalesce(p_query,'')) || '%'
      OR to_tsvector('english', r.title || E'\n' || r.rule_text || E'\n' || coalesce(array_to_string(r.applies_to,' '),'')) @@ plainto_tsquery('english', coalesce(p_query,''))
      OR to_tsvector('simple', r.title || E'\n' || r.rule_text || E'\n' || coalesce(array_to_string(r.applies_to,' '),'')) @@ plainto_tsquery('simple', coalesce(p_query,''))
    )
  ORDER BY
    CASE WHEN lower(r.priority)='critical' THEN 1 WHEN lower(r.priority)='high' THEN 2 WHEN lower(r.priority)='medium' THEN 3 ELSE 4 END,
    r.updated_at DESC
  LIMIT greatest(coalesce(p_limit,5),1);
$$;

CREATE OR REPLACE FUNCTION public.zorg_recall_context(p_query text, p_limit integer DEFAULT 10)
 RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
 LANGUAGE sql
AS $$
  with combined as (
    select * from public.zorg_get_logic_context(p_query, greatest(1, coalesce(p_limit, 10) / 3))
    union all
    select * from public.zorg_get_runbook_context(p_query, greatest(1, coalesce(p_limit, 10) / 2))
    union all
    select * from public.zorg_get_project_context(p_query, greatest(1, coalesce(p_limit, 10) / 2))
    union all
    select * from public.zorg_get_host_context(p_query, greatest(1, coalesce(p_limit, 10) / 3))
    union all
    select
      case z.source_table
        when 'directive' then 'directive'
        when 'runbook' then 'runbook'
        when 'project' then 'project'
        when 'project_fact' then 'project_fact'
        when 'host' then 'host'
        when 'service' then 'service'
        when 'relationship' then 'relationship'
        when 'operational_fact' then 'operational_fact'
        when 'contact' then 'contact'
        when 'logic_rule' then 'logic_rule'
        else 'memory'
      end as source_type,
      z.source_id,
      null::text as path,
      null::integer as line_start,
      null::integer as line_end,
      coalesce(z.priority, 'medium') as priority,
      z.snippet as content
    from public.zorg_search_memory(p_query, greatest(coalesce(p_limit, 10), 1)) z
  )
  select distinct on (source_type, source_id, content)
    source_type, source_id, path, line_start, line_end, priority, content
  from combined
  order by source_type, source_id, content,
    case when lower(priority) = 'critical' then 1
         when lower(priority) = 'high' then 2
         when lower(priority) = 'medium' then 3
         else 4 end
  limit greatest(coalesce(p_limit, 10), 1);
$$;

INSERT INTO public.zorg_logic_rules(rule_key,title,rule_text,rule_type,priority,privacy_scope,source_basis,applies_to,standard_checks,performance_tuning_notes)
VALUES
('standard-precautions-for-new-memory-features','Standard precautions for new memory/database features','When creating a new memory, CRM, recall, schema, automation, or data-ingestion feature, proactively check the obvious integrity and usability risks before claiming success. The CRM example is the lesson: after first building contact import, duplicate/distilled contact checks should have been an automatic quality gate. Future features need recursive self-checks such as duplicate detection, count reconciliation, source preservation, recall integration, index/performance checks, privacy boundary checks, sync/recovery verification, and representative query tests.','proactive_quality_control','critical','private','operator_instruction_plus_crm_dedupe_lesson',ARRAY['memory_db','crm','contacts','schema','data_import','recall','automation'],ARRAY['Check for duplicates or ambiguous canonicalization','Verify raw/source data preservation','Verify derived/canonical view is used for recall','Run representative recall/search queries','Check indexes/materialized views/performance impact','Check privacy/publication boundary','Record follow-up review flags instead of deleting uncertain data'], 'Additive structures only; use indexes/materialized views/observations to preserve speed while adding richer logic.'),
('recursive-logic-extraction-and-application','Recursive logic extraction and application','Treat operator rules, explicit examples, private relationship context, public-safe executive-assistant playbook principles, and observed mistakes as source material for deduced operating logic. Convert them into reusable decision structures that shape future behavior before escalation: protect the operator time, design the play, close loops, prioritize revenue/time/reputation, answer clearly and kindly, and anticipate problems. Use private person context silently for better decisions and communications, never as outward disclosure unless explicitly authorized.','recursive_decision_logic','critical','private','operator_instruction_plus_executive_assistant_playbook',ARRAY['email','calendar','contacts','crm','public_private_filter','task_prioritization','quality_control','decision_making'],ARRAY['Before acting, identify applicable explicit and deduced rules','Use private context as a silent decision filter','Infer adjacent safeguards from the task type','Close the loop or create a durable waiting item','Escalate with concise options only after self-service paths are exhausted'], 'Store rules as structured rows; tune recall queries/indexes so logic rules surface quickly for related tasks.'),
('executive-assistant-proactive-final-checks','Executive assistant proactive final checks','For executive-assistant work, perform final checks proactively: verify the affected surface, confirm counts/status, inspect likely edge cases, reduce repeat noise, preserve follow-up state, and prepare concise options only when a decision is actually needed. This distills the playbook pattern of protecting time, being preemptive, and coming prepared.','executive_assistant_logic','high','private','dan_martell_playbook_distillation',ARRAY['email','calendar','travel','contacts','crm','website','publishing','monitoring'],ARRAY['Confirm the intended recipient/time/context','Check for duplicate or stale records when building lists/databases','Verify the live result or affected endpoint','Mark reported items read / prevent repeat reporting where applicable','Create reminders/waiting states for unresolved loops'], 'Track which final checks prevent errors and promote recurring checks into indexes/rules/runbooks when useful.')
ON CONFLICT (rule_key) DO UPDATE SET
  title=excluded.title,
  rule_text=excluded.rule_text,
  rule_type=excluded.rule_type,
  priority=excluded.priority,
  privacy_scope=excluded.privacy_scope,
  source_basis=excluded.source_basis,
  applies_to=excluded.applies_to,
  standard_checks=excluded.standard_checks,
  performance_tuning_notes=excluded.performance_tuning_notes,
  updated_at=now(),
  active=true;

INSERT INTO public.zorg_logic_rule_sources(rule_key,source_type,source_ref,source_summary,private_context)
VALUES
('standard-precautions-for-new-memory-features','operator_example','CRM contact import duplicate miss','After building the CRM contact import, duplicate-name/canonicalization checks were not automatic; Stefan identified this as a standard logical precaution that should have happened proactively.',true),
('recursive-logic-extraction-and-application','operator_instruction','2026-05-05 recursive logic instruction','Stefan instructed Zorg to build recursive logic rules from explicit rules, deduced implications, private person context, and executive-assistant playbook logic, continuously tuning MemoryDB association structures.',true),
('executive-assistant-proactive-final-checks','public_safe_playbook_distillation','Dan Martell Exec Admin Playbook','Distilled public-safe principles: protect CEO time, be preemptive/design the play, prioritize revenue, answer clearly/kindly, solve problems before CEO escalation, and perform final checks.',false)
ON CONFLICT DO NOTHING;
