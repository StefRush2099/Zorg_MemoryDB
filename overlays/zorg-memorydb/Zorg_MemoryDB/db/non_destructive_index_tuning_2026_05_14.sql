-- Non-destructive recall/index performance tuning, 2026-05-14.
-- Preserve all source rows. These additive indexes support existing recall
-- functions and project/runbook/host/context lookups without changing data shape.
-- Run outside a transaction if using CONCURRENTLY.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_zlr_context_lower_no_applies_trgm
  ON public.zorg_logic_rules
  USING gin (lower(title || E'\n' || rule_text) gin_trgm_ops)
  WHERE coalesce(active,true) = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_zlr_updated_active_priority
  ON public.zorg_logic_rules (
    (case when lower(priority)='critical' then 1 when lower(priority)='high' then 2 when lower(priority)='medium' then 3 else 4 end),
    updated_at DESC
  )
  WHERE coalesce(active,true) = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_memory_runbooks_context_trgm
  ON public.memory_runbooks
  USING gin (lower(coalesce(title,'') || ' ' || coalesce(runbook_key,'') || ' ' || coalesce(trigger_text,'') || ' ' || coalesce(procedure_text,'')) gin_trgm_ops)
  WHERE coalesce(active,true) = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_memory_runbooks_updated_active
  ON public.memory_runbooks (updated_at DESC)
  WHERE coalesce(active,true) = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_memory_projects_context_trgm
  ON public.memory_projects
  USING gin (lower(coalesce(project_key,'') || ' ' || coalesce(name,'') || ' ' || coalesce(install_path,'') || ' ' || coalesce(purpose,'')) gin_trgm_ops)
  WHERE coalesce(active,true) = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_memory_project_aliases_alias_trgm
  ON public.memory_project_aliases
  USING gin (lower(coalesce(alias,'')) gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_memory_hosts_context_trgm
  ON public.memory_hosts
  USING gin (lower(coalesce(host_name,'') || ' ' || coalesce(host_key,'') || ' ' || coalesce(ip_address,'') || ' ' || coalesce(purpose,'')) gin_trgm_ops)
  WHERE coalesce(active,true) = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_memory_directives_context_trgm
  ON public.memory_directives
  USING gin (lower(coalesce(directive_text,'') || ' ' || coalesce(category,'') || ' ' || coalesce(priority,'')) gin_trgm_ops)
  WHERE coalesce(active,true) = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_memory_project_facts_text_trgm
  ON public.memory_project_facts
  USING gin (lower(coalesce(fact_text,'') || ' ' || coalesce(fact_type,'') || ' ' || coalesce(project_key,'')) gin_trgm_ops);

VACUUM (ANALYZE) public.zorg_logic_rules;
VACUUM (ANALYZE) public.memory_runbooks;
VACUUM (ANALYZE) public.memory_projects;
VACUUM (ANALYZE) public.memory_project_aliases;
VACUUM (ANALYZE) public.memory_hosts;
VACUUM (ANALYZE) public.memory_directives;
VACUUM (ANALYZE) public.memory_project_facts;
