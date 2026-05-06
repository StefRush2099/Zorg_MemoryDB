-- Additive Google Contacts / CRM memory schema for Zorg MemoryDB.
-- Private live data belongs only in the local DB. This file contains structure only.

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.zorg_contact_sync_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL DEFAULT 'google_people_api',
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  status text NOT NULL DEFAULT 'running',
  contacts_seen integer NOT NULL DEFAULT 0,
  contacts_upserted integer NOT NULL DEFAULT 0,
  contact_points_upserted integer NOT NULL DEFAULT 0,
  error_text text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.zorg_contacts_crm (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL DEFAULT 'google_people_api',
  source_resource_name text NOT NULL,
  source_etag text,
  display_name text,
  given_name text,
  family_name text,
  middle_name text,
  nickname text,
  company text,
  job_title text,
  department text,
  email_primary text,
  phone_primary text,
  timezone text,
  notes text,
  names jsonb NOT NULL DEFAULT '[]'::jsonb,
  email_addresses jsonb NOT NULL DEFAULT '[]'::jsonb,
  phone_numbers jsonb NOT NULL DEFAULT '[]'::jsonb,
  addresses jsonb NOT NULL DEFAULT '[]'::jsonb,
  organizations jsonb NOT NULL DEFAULT '[]'::jsonb,
  urls jsonb NOT NULL DEFAULT '[]'::jsonb,
  birthdays jsonb NOT NULL DEFAULT '[]'::jsonb,
  events jsonb NOT NULL DEFAULT '[]'::jsonb,
  relations jsonb NOT NULL DEFAULT '[]'::jsonb,
  memberships jsonb NOT NULL DEFAULT '[]'::jsonb,
  user_defined jsonb NOT NULL DEFAULT '[]'::jsonb,
  photos jsonb NOT NULL DEFAULT '[]'::jsonb,
  raw_person jsonb NOT NULL DEFAULT '{}'::jsonb,
  search_text text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_synced_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (source, source_resource_name)
);

CREATE TABLE IF NOT EXISTS public.zorg_contact_points_crm (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES public.zorg_contacts_crm(id) ON DELETE CASCADE,
  point_type text NOT NULL,
  label text,
  value text NOT NULL,
  value_norm text NOT NULL,
  primary_flag boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (contact_id, point_type, value_norm)
);

CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_display_name ON public.zorg_contacts_crm (display_name);
CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_email_primary ON public.zorg_contacts_crm (email_primary);
CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_company ON public.zorg_contacts_crm (company);
CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_updated_at ON public.zorg_contacts_crm (updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_search_trgm ON public.zorg_contacts_crm USING gin (search_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_search_fts_en ON public.zorg_contacts_crm USING gin (to_tsvector('english', search_text));
CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_search_fts_simple ON public.zorg_contacts_crm USING gin (to_tsvector('simple', search_text));
CREATE INDEX IF NOT EXISTS idx_zorg_contact_points_crm_type_value ON public.zorg_contact_points_crm (point_type, value_norm);
CREATE INDEX IF NOT EXISTS idx_zorg_contact_points_crm_value_trgm ON public.zorg_contact_points_crm USING gin (value_norm gin_trgm_ops);

CREATE OR REPLACE FUNCTION public.zorg_contact_search_text(c public.zorg_contacts_crm)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT concat_ws(E'\n',
    'Contact: ' || coalesce(c.display_name, ''),
    'Given: ' || coalesce(c.given_name, ''),
    'Family: ' || coalesce(c.family_name, ''),
    'Nickname: ' || coalesce(c.nickname, ''),
    'Company: ' || coalesce(c.company, ''),
    'Title: ' || coalesce(c.job_title, ''),
    'Department: ' || coalesce(c.department, ''),
    'Primary email: ' || coalesce(c.email_primary, ''),
    'Primary phone: ' || coalesce(c.phone_primary, ''),
    'Timezone: ' || coalesce(c.timezone, ''),
    'Notes: ' || coalesce(c.notes, ''),
    'Emails: ' || coalesce(c.email_addresses::text, ''),
    'Phones: ' || coalesce(c.phone_numbers::text, ''),
    'Addresses: ' || coalesce(c.addresses::text, ''),
    'Organizations: ' || coalesce(c.organizations::text, ''),
    'URLs: ' || coalesce(c.urls::text, ''),
    'Relations: ' || coalesce(c.relations::text, ''),
    'User defined: ' || coalesce(c.user_defined::text, '')
  )
$$;

CREATE OR REPLACE VIEW public.zorg_contacts_crm_recall_v AS
SELECT
  'contact'::text AS source_table,
  c.id::text AS source_id,
  c.updated_at AS event_ts,
  'contact_crm'::text AS category,
  'high'::text AS priority,
  public.zorg_contact_search_text(c) AS content
FROM public.zorg_contacts_crm c
WHERE coalesce(c.active, true) = true;

DROP MATERIALIZED VIEW IF EXISTS public.zorg_memory_search_fast_mv;
DROP MATERIALIZED VIEW IF EXISTS public.zorg_memory_search_mv;

CREATE MATERIALIZED VIEW public.zorg_memory_search_mv AS
 SELECT 'directive'::text AS source_table,
    (d.id)::text AS source_id,
    d.updated_at AS event_ts,
    d.category,
    d.priority,
    d.directive_text AS content
   FROM memory_directives d
  WHERE (COALESCE(d.active, true) = true)
UNION ALL
 SELECT 'runbook'::text AS source_table,
    (r.id)::text AS source_id,
    r.updated_at AS event_ts,
    'runbook'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', COALESCE(r.title, r.runbook_key), COALESCE(r.trigger_text, ''::text), r.procedure_text) AS content
   FROM memory_runbooks r
  WHERE (COALESCE(r.active, true) = true)
UNION ALL
 SELECT 'project'::text AS source_table,
    (p.id)::text AS source_id,
    p.updated_at AS event_ts,
    'project'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', COALESCE(p.name, p.project_key), p.project_key, COALESCE(p.install_path, ''::text), COALESCE(p.purpose, ''::text), COALESCE(p.deployment_path, ''::text)) AS content
   FROM memory_projects p
  WHERE (COALESCE(p.active, true) = true)
UNION ALL
 SELECT 'project_alias'::text AS source_table,
    (a.id)::text AS source_id,
    a.created_at AS event_ts,
    'project_alias'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', a.project_key, a.alias, COALESCE(a.alias_type, ''::text)) AS content
   FROM memory_project_aliases a
UNION ALL
 SELECT 'project_fact'::text AS source_table,
    (f.id)::text AS source_id,
    f.updated_at AS event_ts,
    f.fact_type AS category,
    'high'::text AS priority,
    concat_ws(E'\n', f.project_key, COALESCE(f.fact_type, ''::text), f.fact_text) AS content
   FROM memory_project_facts f
UNION ALL
 SELECT 'host'::text AS source_table,
    (h.id)::text AS source_id,
    h.updated_at AS event_ts,
    'host'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', COALESCE(h.host_name, ''::text), COALESCE(h.host_key, ''::text), COALESCE(h.ip_address, ''::text), COALESCE(h.purpose, ''::text)) AS content
   FROM memory_hosts h
  WHERE (COALESCE(h.active, true) = true)
UNION ALL
 SELECT 'service'::text AS source_table,
    (s.id)::text AS source_id,
    s.updated_at AS event_ts,
    'service'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', s.service_name, COALESCE(s.project_key, ''::text), COALESCE(s.host_key, ''::text), COALESCE(s.service_path, ''::text)) AS content
   FROM memory_services s
  WHERE (COALESCE(s.active, true) = true)
UNION ALL
 SELECT 'relationship'::text AS source_table,
    (rel.id)::text AS source_id,
    COALESCE(rel.created_at, now()) AS event_ts,
    'relationship'::text AS category,
    'medium'::text AS priority,
    concat_ws(' '::text, ((rel.subject_type || ':'::text) || rel.subject_key), rel.relation, ((rel.object_type || ':'::text) || rel.object_key)) AS content
   FROM memory_relationships rel
UNION ALL
 SELECT 'zorg_memory'::text AS source_table,
    (z.id)::text AS source_id,
    z.logged_at AS event_ts,
    z.memory_category AS category,
    z.memory_priority AS priority,
    COALESCE(z.memory_value, z.chat_session_log, ''::text) AS content
   FROM zorg_memory z
UNION ALL
 SELECT 'operational_fact'::text AS source_table,
    (zf.id)::text AS source_id,
    zf.updated_at AS event_ts,
    zf.fact_category AS category,
    zf.fact_priority AS priority,
    zf.fact_value AS content
   FROM zorg_operational_facts zf
  WHERE (COALESCE(zf.active, true) = true)
UNION ALL
 SELECT source_table, source_id, event_ts, category, priority, content
   FROM public.zorg_contacts_crm_recall_v;

CREATE UNIQUE INDEX idx_zms_mv_pk ON public.zorg_memory_search_mv (source_table, source_id);
CREATE INDEX idx_zms_mv_event_ts_desc ON public.zorg_memory_search_mv (event_ts DESC);
CREATE INDEX idx_zms_mv_source_rank_event_ts ON public.zorg_memory_search_mv (((CASE WHEN source_table = 'zorg_memory' THEN 1 ELSE 0 END)), event_ts DESC);
CREATE INDEX idx_zms_mv_content_trgm ON public.zorg_memory_search_mv USING gin (content gin_trgm_ops);
CREATE INDEX idx_zms_mv_content_fts ON public.zorg_memory_search_mv USING gin (to_tsvector('english', content));
CREATE INDEX idx_zms_mv_content_fts_simple ON public.zorg_memory_search_mv USING gin (to_tsvector('simple', content));

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
    CASE WHEN (source_table = 'zorg_memory'::text) THEN 1 WHEN (source_table = 'contact'::text) THEN 2 ELSE 0 END AS source_rank,
    length(content) AS content_len
   FROM public.zorg_memory_search_mv;

CREATE UNIQUE INDEX idx_zms_fast_mv_pk ON public.zorg_memory_search_fast_mv (source_table, source_id);
CREATE INDEX idx_zms_fast_mv_rank_ts ON public.zorg_memory_search_fast_mv (source_rank, event_ts DESC);
CREATE INDEX idx_zms_fast_mv_priority_rank_ts ON public.zorg_memory_search_fast_mv (priority, source_rank, event_ts DESC);
CREATE INDEX idx_zms_fast_mv_content_lc_trgm ON public.zorg_memory_search_fast_mv USING gin (content_lc gin_trgm_ops);
CREATE INDEX idx_zms_fast_mv_fts_en ON public.zorg_memory_search_fast_mv USING gin (content_fts_en);
CREATE INDEX idx_zms_fast_mv_fts_simple ON public.zorg_memory_search_fast_mv USING gin (content_fts_simple);

CREATE OR REPLACE FUNCTION public.zorg_refresh_memory_search()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW public.zorg_memory_search_mv;
  REFRESH MATERIALIZED VIEW public.zorg_memory_search_fast_mv;
END;
$$;

CREATE OR REPLACE FUNCTION public.zorg_recall_context(p_query text, p_limit integer DEFAULT 10)
 RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
 LANGUAGE sql
AS $$
  with combined as (
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
