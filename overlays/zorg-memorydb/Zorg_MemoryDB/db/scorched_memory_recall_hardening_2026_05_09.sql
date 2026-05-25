-- 2026-05-09 scorched memory recall hardening
-- Add recall hints into the canonical search surface and rank recall by priority/relevance before source ordering.

DROP MATERIALIZED VIEW IF EXISTS public.zorg_memory_search_fast_mv;
DROP MATERIALIZED VIEW IF EXISTS public.zorg_memory_search_mv;

CREATE MATERIALIZED VIEW public.zorg_memory_search_mv AS
 SELECT 'directive'::text AS source_table,
    d.id::text AS source_id,
    d.updated_at AS event_ts,
    d.category,
    d.priority,
    d.directive_text AS content
   FROM public.memory_directives d
  WHERE COALESCE(d.active, true) = true
UNION ALL
 SELECT 'runbook'::text AS source_table,
    r.id::text AS source_id,
    r.updated_at AS event_ts,
    'runbook'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', COALESCE(r.title, r.runbook_key), COALESCE(r.trigger_text, ''::text), r.procedure_text) AS content
   FROM public.memory_runbooks r
  WHERE COALESCE(r.active, true) = true
UNION ALL
 SELECT 'project'::text AS source_table,
    p.id::text AS source_id,
    p.updated_at AS event_ts,
    'project'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', COALESCE(p.name, p.project_key), p.project_key, COALESCE(p.install_path, ''::text), COALESCE(p.purpose, ''::text), COALESCE(p.deployment_path, ''::text)) AS content
   FROM public.memory_projects p
  WHERE COALESCE(p.active, true) = true
UNION ALL
 SELECT 'project_alias'::text AS source_table,
    a.id::text AS source_id,
    a.created_at AS event_ts,
    'project_alias'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', a.project_key, a.alias, COALESCE(a.alias_type, ''::text)) AS content
   FROM public.memory_project_aliases a
UNION ALL
 SELECT 'project_fact'::text AS source_table,
    f.id::text AS source_id,
    f.updated_at AS event_ts,
    f.fact_type AS category,
    'high'::text AS priority,
    concat_ws(E'\n', f.project_key, COALESCE(f.fact_type, ''::text), f.fact_text) AS content
   FROM public.memory_project_facts f
UNION ALL
 SELECT 'host'::text AS source_table,
    h.id::text AS source_id,
    h.updated_at AS event_ts,
    'host'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', COALESCE(h.host_name, ''::text), COALESCE(h.host_key, ''::text), COALESCE(h.ip_address, ''::text), COALESCE(h.purpose, ''::text)) AS content
   FROM public.memory_hosts h
  WHERE COALESCE(h.active, true) = true
UNION ALL
 SELECT 'service'::text AS source_table,
    s.id::text AS source_id,
    s.updated_at AS event_ts,
    'service'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', s.service_name, COALESCE(s.project_key, ''::text), COALESCE(s.host_key, ''::text), COALESCE(s.service_path, ''::text)) AS content
   FROM public.memory_services s
  WHERE COALESCE(s.active, true) = true
UNION ALL
 SELECT 'relationship'::text AS source_table,
    rel.id::text AS source_id,
    COALESCE(rel.created_at, now()) AS event_ts,
    'relationship'::text AS category,
    'high'::text AS priority,
    concat_ws(' '::text, (rel.subject_type || ':'::text) || rel.subject_key, rel.relation, (rel.object_type || ':'::text) || rel.object_key, COALESCE(array_to_string(rel.tags, ' '::text), ''::text)) AS content
   FROM public.memory_relationships rel
UNION ALL
 SELECT 'recall_hint'::text AS source_table,
    h.id::text AS source_id,
    COALESCE(h.updated_at, h.created_at, now()) AS event_ts,
    h.hint_kind AS category,
    CASE WHEN h.weight >= 8 THEN 'critical'::text WHEN h.weight >= 4 THEN 'high'::text ELSE 'medium'::text END AS priority,
    concat_ws(E'\n', h.source_key, h.hint_kind, h.hint_text, COALESCE(array_to_string(h.related_keys, ' '::text), ''::text)) AS content
   FROM public.memory_recall_hints h
  WHERE COALESCE(h.active, true) = true
UNION ALL
 SELECT 'query_observation'::text AS source_table,
    q.id::text AS source_id,
    q.observed_at AS event_ts,
    COALESCE(q.query_intent, 'query_observation'::text) AS category,
    CASE WHEN COALESCE(q.was_useful, false) THEN 'high'::text ELSE 'medium'::text END AS priority,
    concat_ws(E'\n', q.query_text, COALESCE(q.query_intent, ''::text), q.source_type || ':' || q.source_key, COALESCE(q.feedback_basis, ''::text)) AS content
   FROM public.memory_query_observations q
UNION ALL
 SELECT 'logic_rule'::text AS source_table,
    lr.id::text AS source_id,
    COALESCE(lr.updated_at, lr.created_at, now()) AS event_ts,
    COALESCE(lr.rule_type, 'logic_rule'::text) AS category,
    COALESCE(lr.priority, 'high'::text) AS priority,
    concat_ws(E'\n', lr.rule_key, lr.title, lr.rule_text, COALESCE(array_to_string(lr.applies_to, ' '::text), ''::text), COALESCE(array_to_string(lr.standard_checks, ' '::text), ''::text)) AS content
   FROM public.zorg_logic_rules lr
  WHERE COALESCE(lr.active, true) = true
UNION ALL
 SELECT 'zorg_memory'::text AS source_table,
    z.id::text AS source_id,
    z.logged_at AS event_ts,
    z.memory_category AS category,
    z.memory_priority AS priority,
    COALESCE(z.memory_value, z.chat_session_log, ''::text) AS content
   FROM public.zorg_memory z
UNION ALL
 SELECT 'operational_fact'::text AS source_table,
    zf.id::text AS source_id,
    zf.updated_at AS event_ts,
    zf.fact_category AS category,
    zf.fact_priority AS priority,
    zf.fact_value AS content
   FROM public.zorg_operational_facts zf
  WHERE COALESCE(zf.active, true) = true
UNION ALL
 SELECT c.source_table,
    c.source_id,
    c.event_ts,
    c.category,
    c.priority,
    c.content
   FROM public.zorg_contacts_crm_recall_v c;

CREATE UNIQUE INDEX idx_zms_mv_pk ON public.zorg_memory_search_mv USING btree (source_table, source_id);
CREATE INDEX idx_zms_mv_content_fts ON public.zorg_memory_search_mv USING gin (to_tsvector('english'::regconfig, content));
CREATE INDEX idx_zms_mv_content_fts_simple ON public.zorg_memory_search_mv USING gin (to_tsvector('simple'::regconfig, content));
CREATE INDEX idx_zms_mv_content_trgm ON public.zorg_memory_search_mv USING gin (content gin_trgm_ops);
CREATE INDEX idx_zms_mv_event_ts_desc ON public.zorg_memory_search_mv USING btree (event_ts DESC);
CREATE INDEX idx_zms_mv_source_rank_event_ts ON public.zorg_memory_search_mv USING btree (((CASE WHEN source_table = 'logic_rule' THEN 0 WHEN source_table = 'recall_hint' THEN 1 WHEN source_table = 'contact' THEN 2 WHEN source_table = 'relationship' THEN 3 WHEN source_table = 'zorg_memory' THEN 4 ELSE 5 END)), event_ts DESC);

CREATE MATERIALIZED VIEW public.zorg_memory_search_fast_mv AS
 SELECT source_table,
    source_id,
    event_ts,
    category,
    priority,
    content,
    lower(content) AS content_lc,
    to_tsvector('english'::regconfig, content) AS content_fts_en,
    to_tsvector('simple'::regconfig, content) AS content_fts_simple,
    CASE
      WHEN source_table = 'logic_rule'::text THEN 0
      WHEN source_table = 'recall_hint'::text THEN 1
      WHEN source_table = 'contact'::text THEN 2
      WHEN source_table = 'relationship'::text THEN 3
      WHEN source_table = 'zorg_memory'::text THEN 4
      ELSE 5
    END AS source_rank,
    CASE
      WHEN lower(coalesce(priority,'')) = 'critical' THEN 0
      WHEN lower(coalesce(priority,'')) = 'high' THEN 1
      WHEN lower(coalesce(priority,'')) = 'medium' THEN 2
      ELSE 3
    END AS priority_rank,
    length(content) AS content_len
   FROM public.zorg_memory_search_mv;

CREATE UNIQUE INDEX idx_zms_fast_mv_pk ON public.zorg_memory_search_fast_mv USING btree (source_table, source_id);
CREATE INDEX idx_zms_fast_mv_content_lc_trgm ON public.zorg_memory_search_fast_mv USING gin (content_lc gin_trgm_ops);
CREATE INDEX idx_zms_fast_mv_fts_en ON public.zorg_memory_search_fast_mv USING gin (content_fts_en);
CREATE INDEX idx_zms_fast_mv_fts_simple ON public.zorg_memory_search_fast_mv USING gin (content_fts_simple);
CREATE INDEX idx_zms_fast_mv_priority_rank_ts ON public.zorg_memory_search_fast_mv USING btree (priority_rank, source_rank, event_ts DESC);
CREATE INDEX idx_zms_fast_mv_rank_ts ON public.zorg_memory_search_fast_mv USING btree (source_rank, event_ts DESC);

CREATE OR REPLACE FUNCTION public.zorg_recall_context(p_query text, p_limit integer DEFAULT 10)
 RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
 LANGUAGE sql
AS $function$
  with combined as (
    select * from public.zorg_get_logic_context(p_query, greatest(2, coalesce(p_limit, 10) / 2))
    union all
    select * from public.zorg_get_runbook_context(p_query, greatest(2, coalesce(p_limit, 10) / 2))
    union all
    select * from public.zorg_get_project_context(p_query, greatest(2, coalesce(p_limit, 10) / 2))
    union all
    select * from public.zorg_get_host_context(p_query, greatest(2, coalesce(p_limit, 10) / 3))
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
        when 'recall_hint' then 'recall_hint'
        when 'query_observation' then 'query_observation'
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
    from public.zorg_search_memory(p_query, greatest(coalesce(p_limit, 10) * 4, 20)) z
  ), ranked as (
    select distinct on (source_type, source_id, content)
      source_type, source_id, path, line_start, line_end, priority, content,
      case when lower(priority) = 'critical' then 0
           when lower(priority) = 'high' then 1
           when lower(priority) = 'medium' then 2
           else 3 end as priority_rank,
      case source_type
           when 'logic_rule' then 0
           when 'recall_hint' then 1
           when 'contact' then 2
           when 'relationship' then 3
           when 'memory' then 4
           else 5 end as source_rank
    from combined
  )
  select source_type, source_id, path, line_start, line_end, priority, content
  from ranked
  order by priority_rank, source_rank, length(content) desc
  limit greatest(coalesce(p_limit, 10), 1);
$function$;

ANALYZE public.zorg_memory_search_mv;
ANALYZE public.zorg_memory_search_fast_mv;
