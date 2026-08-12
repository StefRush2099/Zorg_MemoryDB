-- Additive/reversible repair for exact-turn mandatory rule recall.
-- Source rules and source memory are not modified.

create table if not exists public.memory_function_recovery_copies (
  recovery_key text primary key,
  function_identity text not null,
  function_definition text not null,
  captured_at timestamptz not null default now()
);

insert into public.memory_function_recovery_copies(recovery_key,function_identity,function_definition)
select 'zorg_get_logic_context-before-2026-08-09',
       'public.zorg_get_logic_context(text,integer)',
       pg_get_functiondef('public.zorg_get_logic_context(text,integer)'::regprocedure)
on conflict(recovery_key) do nothing;

create or replace function public.zorg_get_logic_context(p_query text, p_limit integer default 5)
returns table(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
language sql
as $function$
  with q as (
    select coalesce(p_query,'') raw_query,
           lower(btrim(coalesce(p_query,''))) query_lc,
           plainto_tsquery('english',coalesce(p_query,'')) ts_en,
           plainto_tsquery('simple',coalesce(p_query,'')) ts_simple
  ), tokens as (
    select distinct token
    from q, regexp_split_to_table(q.query_lc,'[^a-z0-9]+') token
    where length(token)>=3
      and token<>all(array['the','and','for','that','this','with','from','your','you','are','not','but','have','has','was','were','what','when','where','why','how','into','before','after','again','right','now','everything','anything','saying','doing'])
    limit 24
  ), token_count as (
    select count(*)::integer n from tokens
  ), mandatory(rule_key,mandatory_order) as (
    values
      ('universal-visible-response-time-enforcement-2026-08-08',1),
      ('unified-change-repair-summary-go-authorization-rule-v2-2026-08-09',2),
      ('zorg-memorydb-automatic-complete-self-repair-2026-08-09',3),
      ('self-created-blocker-repair-before-reporting-rule-2026-05-20',4)
  ), scored as (
    select r.*,
      lower(r.title||E'\n'||r.rule_text||E'\n'||coalesce(array_to_string(r.applies_to,' '),'')) haystack_lc,
      (r.title||E'\n'||r.rule_text||E'\n'||coalesce(array_to_string(r.applies_to,' '),'')) haystack,
      m.mandatory_order
    from public.zorg_logic_rules r left join mandatory m using(rule_key)
    where coalesce(r.active,true)
  ), matched as (
    select s.*,tc.n query_token_count,
      (select count(*)::integer from tokens t where s.haystack_lc like '%'||t.token||'%') token_hits,
      case when length(q.query_lc)>=3 and s.haystack_lc like '%'||q.query_lc||'%' then 1 else 0 end exact_phrase_hit,
      case when to_tsvector('english',s.haystack)@@q.ts_en or to_tsvector('simple',s.haystack)@@q.ts_simple then 1 else 0 end fts_all_hit
    from scored s cross join q cross join token_count tc
  ), eligible as (
    select * from matched
    where mandatory_order is not null
       or exact_phrase_hit=1
       or fts_all_hit=1
       or (query_token_count>0 and token_hits>=greatest(2,ceil(query_token_count*0.40)::integer))
  )
  select 'logic_rule'::text,e.id::text,null::text,null::integer,null::integer,e.priority,
    concat_ws(E'\n','Logic rule: '||coalesce(e.title,''),'Key: '||coalesce(e.rule_key,''),
      'Type: '||coalesce(e.rule_type,''),'Priority: '||coalesce(e.priority,''),
      'Privacy: '||coalesce(e.privacy_scope,''),'Source basis: '||coalesce(e.source_basis,''),
      'Rule: '||coalesce(e.rule_text,''),'Applies to: '||coalesce(array_to_string(e.applies_to,', '),''),
      'Standard checks: '||coalesce(array_to_string(e.standard_checks,'; '),''),
      'Performance tuning: '||coalesce(e.performance_tuning_notes,''))
  from eligible e
  order by case when e.mandatory_order is not null then 0 else 1 end,
           e.mandatory_order nulls last,e.exact_phrase_hit desc,e.fts_all_hit desc,e.token_hits desc,
           case when lower(e.priority)='critical' then 1 when lower(e.priority)='high' then 2 when lower(e.priority)='medium' then 3 else 4 end,
           e.updated_at desc
  limit greatest(coalesce(p_limit,5),4);
$function$;
