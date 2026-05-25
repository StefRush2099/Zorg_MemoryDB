-- Recency/token/supersession recall weighting repair, 2026-05-25.
-- Public-safe structural migration. Preserves all source memory rows.
-- Apply after a verified PostgreSQL backup. Refresh search materialized views after applying.

CREATE OR REPLACE FUNCTION public.zorg_search_memory(p_query text, p_limit integer DEFAULT 10)
 RETURNS TABLE(source_table text, source_id text, event_ts timestamp with time zone, category text, priority text, snippet text)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_limit integer := greatest(coalesce(p_limit, 10), 1);
  v_query_lc text := lower(coalesce(p_query, ''));
  v_ts_en tsquery := plainto_tsquery('english', coalesce(p_query, ''));
  v_ts_simple tsquery := plainto_tsquery('simple', coalesce(p_query, ''));
  v_ts_any_en tsquery;
  v_ts_any_simple tsquery;
BEGIN
  WITH raw_tokens AS (
    SELECT DISTINCT t.token, regexp_replace(t.token, 's$', '') AS token_root
    FROM regexp_split_to_table(v_query_lc, '[^a-z0-9]+') AS t(token)
    WHERE length(t.token) >= 4
      AND t.token NOT IN (
        'what','when','where','which','while','with','from','that','this','your','youre',
        'have','been','being','were','does','into','about','supposed','remember','using',
        'should','would','could','there','their','they','them','then','than','time'
      )
    LIMIT 20
  ), token_queries AS (
    SELECT
      NULLIF((plainto_tsquery('english', token))::text, '') AS q_en,
      NULLIF((plainto_tsquery('simple', token))::text, '') AS q_simple
    FROM raw_tokens
  )
  SELECT
    NULLIF(string_agg(q_en, ' | ') FILTER (WHERE q_en IS NOT NULL), '')::tsquery,
    NULLIF(string_agg(q_simple, ' | ') FILTER (WHERE q_simple IS NOT NULL), '')::tsquery
  INTO v_ts_any_en, v_ts_any_simple
  FROM token_queries;

  RETURN QUERY
  WITH raw_tokens AS (
    SELECT DISTINCT t.token, regexp_replace(t.token, 's$', '') AS token_root
    FROM regexp_split_to_table(v_query_lc, '[^a-z0-9]+') AS t(token)
    WHERE length(t.token) >= 4
      AND t.token NOT IN (
        'what','when','where','which','while','with','from','that','this','your','youre',
        'have','been','being','were','does','into','about','supposed','remember','using',
        'should','would','could','there','their','they','them','then','than','time'
      )
    LIMIT 20
  ), important_token_matches AS (
    SELECT z.source_table, z.source_id, z.event_ts, z.category, z.priority,
           left(z.content, 240) AS snippet, -1 AS match_rank,
           (SELECT count(*)::numeric FROM raw_tokens rt
            WHERE z.content_lc LIKE '%' || rt.token || '%'
               OR (length(rt.token_root) >= 4 AND z.content_lc LIKE '%' || rt.token_root || '%')) AS token_hits,
           z.source_rank
    FROM public.zorg_memory_search_fast_mv z
    WHERE EXISTS (
      SELECT 1 FROM raw_tokens rt
      WHERE z.content_lc LIKE '%' || rt.token || '%'
         OR (length(rt.token_root) >= 4 AND z.content_lc LIKE '%' || rt.token_root || '%')
    )
    ORDER BY token_hits DESC, z.event_ts DESC, z.priority_rank, z.source_rank
    LIMIT greatest(v_limit * 2, 20)
  ), fts_matches AS (
    SELECT z.source_table, z.source_id, z.event_ts, z.category, z.priority,
           left(z.content, 240) AS snippet, 0 AS match_rank, 0::numeric AS token_hits, z.source_rank
    FROM public.zorg_memory_search_fast_mv z
    WHERE (z.content_fts_en @@ v_ts_en OR z.content_fts_simple @@ v_ts_simple)
      AND NOT EXISTS (SELECT 1 FROM important_token_matches i WHERE i.source_table=z.source_table AND i.source_id=z.source_id)
    ORDER BY z.source_rank, z.event_ts DESC
    LIMIT v_limit
  ), exact_matches AS (
    SELECT z.source_table, z.source_id, z.event_ts, z.category, z.priority,
           left(z.content, 240) AS snippet, 1 AS match_rank, 0::numeric AS token_hits, z.source_rank
    FROM public.zorg_memory_search_fast_mv z
    WHERE z.content_lc LIKE '%' || v_query_lc || '%'
      AND NOT EXISTS (SELECT 1 FROM important_token_matches i WHERE i.source_table=z.source_table AND i.source_id=z.source_id)
      AND NOT EXISTS (SELECT 1 FROM fts_matches f WHERE f.source_table=z.source_table AND f.source_id=z.source_id)
    ORDER BY z.source_rank, z.event_ts DESC
    LIMIT v_limit
  ), token_matches AS (
    SELECT z.source_table, z.source_id, z.event_ts, z.category, z.priority,
           left(z.content, 240) AS snippet, 2 AS match_rank,
           greatest(
             CASE WHEN v_ts_any_en IS NULL THEN 0 ELSE ts_rank_cd(z.content_fts_en, v_ts_any_en)::numeric END,
             CASE WHEN v_ts_any_simple IS NULL THEN 0 ELSE ts_rank_cd(z.content_fts_simple, v_ts_any_simple)::numeric END
           ) AS token_hits,
           z.source_rank
    FROM public.zorg_memory_search_fast_mv z
    WHERE (v_ts_any_en IS NOT NULL OR v_ts_any_simple IS NOT NULL)
      AND ((v_ts_any_en IS NOT NULL AND z.content_fts_en @@ v_ts_any_en)
        OR (v_ts_any_simple IS NOT NULL AND z.content_fts_simple @@ v_ts_any_simple))
      AND NOT EXISTS (SELECT 1 FROM important_token_matches i WHERE i.source_table=z.source_table AND i.source_id=z.source_id)
      AND NOT EXISTS (SELECT 1 FROM fts_matches f WHERE f.source_table=z.source_table AND f.source_id=z.source_id)
      AND NOT EXISTS (SELECT 1 FROM exact_matches e WHERE e.source_table=z.source_table AND e.source_id=z.source_id)
    ORDER BY token_hits DESC, z.source_rank, z.event_ts DESC
    LIMIT v_limit
  ), ranked AS (
    SELECT i.source_table, i.source_id, i.event_ts, i.category, i.priority, i.snippet, i.match_rank, i.token_hits, i.source_rank FROM important_token_matches i
    UNION ALL
    SELECT f.source_table, f.source_id, f.event_ts, f.category, f.priority, f.snippet, f.match_rank, f.token_hits, f.source_rank FROM fts_matches f
    UNION ALL
    SELECT e.source_table, e.source_id, e.event_ts, e.category, e.priority, e.snippet, e.match_rank, e.token_hits, e.source_rank FROM exact_matches e
    UNION ALL
    SELECT t.source_table, t.source_id, t.event_ts, t.category, t.priority, t.snippet, t.match_rank, t.token_hits, t.source_rank FROM token_matches t
  )
  SELECT r.source_table, r.source_id, r.event_ts, r.category, r.priority, r.snippet
  FROM ranked r
  ORDER BY r.token_hits DESC,
           CASE WHEN r.source_table = 'logic_rule' THEN 1 ELSE 0 END,
           CASE WHEN r.priority = 'critical' THEN 0 WHEN r.priority='high' THEN 1 WHEN r.priority='medium' THEN 2 ELSE 3 END,
           r.match_rank,
           r.source_rank,
           r.event_ts DESC
  LIMIT v_limit;
END;
$function$;


CREATE OR REPLACE FUNCTION public.zorg_recall_context(p_query text, p_limit integer DEFAULT 10)
 RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
 LANGUAGE sql
AS $function$
  WITH q AS (
    SELECT lower(coalesce(p_query,'')) AS query_lc
  ), tokens AS (
    SELECT DISTINCT token, regexp_replace(token, 's$', '') AS token_root
    FROM q, regexp_split_to_table(q.query_lc, '[^a-z0-9]+') AS token
    WHERE length(token) >= 4
      AND token NOT IN (
        'what','when','where','which','while','with','from','that','this','your','youre',
        'have','been','being','were','does','into','about','supposed','remember','using',
        'should','would','could','there','their','they','them','then','than','time'
      )
    LIMIT 20
  ), combined as (
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
    from public.zorg_search_memory(p_query, greatest(coalesce(p_limit, 10) * 6, 40)) z
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
           when 'query_observation' then 1
           when 'contact' then 2
           when 'relationship' then 3
           when 'memory' then 4
           else 5 end as source_rank,
      case when length((select query_lc from q)) >= 3 and lower(content) like '%' || (select query_lc from q) || '%' then 1 else 0 end as exact_phrase_hit,
      (select count(*)::integer from tokens t
       where lower(content) like '%' || t.token || '%'
          or (length(t.token_root) >= 4 and lower(content) like '%' || t.token_root || '%')) as token_hits,
      coalesce(meta.event_ts, 'epoch'::timestamptz) as event_ts
    from combined
    left join lateral (
      select coalesce(z.event_ts, zm.logged_at, h.created_at, hzm.logged_at) as event_ts
      from (select 1) seed
      left join public.zorg_memory_search_fast_mv z
        on z.source_id = combined.source_id
        and (
          z.source_table = combined.source_type
          or (combined.source_type='memory' and z.source_table in ('memory','directive','project','project_fact','host','service','operational_fact'))
          or (combined.source_type='logic_rule' and z.source_table='logic_rule')
          or (combined.source_type='recall_hint' and z.source_table='recall_hint')
        )
      left join public.zorg_memory zm on zm.id::text = combined.source_id
      left join public.memory_recall_hints h on combined.source_type='recall_hint' and h.id::text = combined.source_id
      left join public.zorg_memory hzm on hzm.id::text = h.source_key
      limit 1
    ) meta on true
  )
  select source_type, source_id, path, line_start, line_end, priority, content
  from ranked
  order by exact_phrase_hit desc, token_hits desc, priority_rank, source_rank, event_ts desc, length(content) asc
  limit greatest(coalesce(p_limit, 10), 1);
$function$;


CREATE OR REPLACE FUNCTION public.zorg_weighted_recall_context(p_query text, p_limit integer DEFAULT 10)
 RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text, relevance_score numeric, relevance_percent integer, score_reason text, weight_breakdown jsonb)
 LANGUAGE plpgsql
AS $function$
declare
  v_query text := coalesce(p_query, '');
  v_limit integer := greatest(coalesce(p_limit, 10), 1);
  v_query_key text := md5(lower(coalesce(p_query,'')));
begin
  perform public.memory_enqueue_semantic_job('recall_query', 'query', v_query_key, jsonb_build_object('query_text', v_query), 40);

  return query
  with q_tokens as (
    select distinct token, regexp_replace(token, 's$', '') as token_root
    from regexp_split_to_table(lower(v_query), '[^a-z0-9]+') as token
    where length(token) >= 4
      and token not in (
        'what','when','where','which','while','with','from','that','this','your','youre',
        'have','been','being','were','does','into','about','supposed','remember','using',
        'should','would','could','there','their','they','them','then','than','time'
      )
    limit 20
  ), base as (
    select row_number() over () as base_rank, r.*
    from public.zorg_recall_context(v_query, greatest(v_limit * 6, 30)) r
  ), enriched as (
    select b.*,
      meta.event_ts,
      meta.category,
      tok.token_hits,
      tok.strong_token_hits
    from base b
    left join lateral (
      select
        coalesce(z.event_ts, zm.logged_at, h.created_at, hzm.logged_at) as event_ts,
        coalesce(z.category, zm.memory_category, hzm.memory_category, h.hint_kind) as category
      from (select 1) seed
      left join public.zorg_memory_search_fast_mv z
        on z.source_id = b.source_id
        and (
          z.source_table = b.source_type
          or (b.source_type='memory' and z.source_table in ('memory','directive','project','project_fact','host','service','operational_fact'))
          or (b.source_type='logic_rule' and z.source_table='logic_rule')
          or (b.source_type='recall_hint' and z.source_table='recall_hint')
        )
      left join public.zorg_memory zm
        on zm.id::text = b.source_id
      left join public.memory_recall_hints h
        on b.source_type='recall_hint' and h.id::text = b.source_id
      left join public.zorg_memory hzm
        on hzm.id::text = h.source_key
      limit 1
    ) meta on true
    left join lateral (
      select
        count(*)::integer as token_hits,
        count(*) filter (
          where lower(coalesce(b.content,'')) like '%' || qt.token || '%'
             or (length(qt.token_root) >= 4 and lower(coalesce(b.content,'')) like '%' || qt.token_root || '%')
        )::integer as strong_token_hits
      from q_tokens qt
      where lower(coalesce(b.content,'')) like '%' || qt.token || '%'
         or (length(qt.token_root) >= 4 and lower(coalesce(b.content,'')) like '%' || qt.token_root || '%')
    ) tok on true
  ), scored as (
    select e.*,
      (case lower(coalesce(e.priority,'')) when 'critical' then 45 when 'high' then 30 when 'medium' then 15 else 5 end)::numeric as priority_score,
      (case e.source_type when 'logic_rule' then 25 when 'recall_hint' then 22 when 'contact' then 18 when 'relationship' then 15 when 'directive' then 22 else 10 end)::numeric as type_score,
      greatest(0, 24 - least(e.base_rank, 24))::numeric as rank_score,
      (case when lower(coalesce(e.content,'')) like '%' || lower(v_query) || '%' and length(v_query) >= 3 then 20 else 0 end)::numeric as exact_score,
      least(40, coalesce(e.strong_token_hits,0) * 12)::numeric as token_score,
      (case
        when e.event_ts is null then 0
        when e.event_ts >= now() - interval '1 day' then 10
        when e.event_ts >= now() - interval '7 days' then 7
        when e.event_ts >= now() - interval '30 days' then 4
        else 0
      end)::numeric as recency_score,
      (case
        when lower(coalesce(e.category,'')) = 'user_preference'
         and coalesce(e.strong_token_hits,0) >= 2
         and e.event_ts = (
           select max(zm.logged_at)
           from public.zorg_memory zm
           where lower(coalesce(zm.memory_category,'')) = 'user_preference'
             and (
               select count(*)
               from q_tokens qt
               where lower(coalesce(zm.memory_value, zm.chat_session_log, '')) like '%' || qt.token || '%'
                  or (length(qt.token_root) >= 4 and lower(coalesce(zm.memory_value, zm.chat_session_log, '')) like '%' || qt.token_root || '%')
             ) >= 2
         )
        then 35 else 0
      end)::numeric as supersession_score,
      (case when coalesce(e.strong_token_hits,0) > 0 then coalesce(obs.obs_score,0) else 0 end)::numeric as observation_score,
      (case when coalesce(e.strong_token_hits,0) > 0 then coalesce(edge.edge_score,0) else 0 end)::numeric as edge_score,
      (case when coalesce(e.strong_token_hits,0) > 0 then coalesce(hint.hint_score,0) else 0 end)::numeric as hint_score,
      array_remove(array[
        case when lower(coalesce(e.priority,'')) in ('critical','high') then 'priority='||coalesce(e.priority,'') end,
        case when coalesce(e.strong_token_hits,0) > 0 then 'query token overlap='||coalesce(e.strong_token_hits,0)::text end,
        case when e.event_ts is not null then 'timestamp='||to_char(e.event_ts, 'YYYY-MM-DD HH24:MI:SS TZ') end,
        case when lower(coalesce(e.category,'')) = 'user_preference' then 'category=user_preference' end,
        case when coalesce(obs.obs_score,0) > 0 and coalesce(e.strong_token_hits,0) > 0 then 'prior useful query observations' end,
        case when coalesce(edge.edge_score,0) > 0 and coalesce(e.strong_token_hits,0) > 0 then 'semantic graph edge match' end,
        case when coalesce(hint.hint_score,0) > 0 and coalesce(e.strong_token_hits,0) > 0 then 'recall hint match' end,
        case when lower(coalesce(e.content,'')) like '%' || lower(v_query) || '%' and length(v_query) >= 3 then 'exact phrase match' end,
        case when lower(coalesce(e.category,'')) = 'user_preference' and coalesce(e.strong_token_hits,0) >= 2 then 'newer matching preference can supersede older preference' end
      ], null) as reasons
    from enriched e
    left join lateral (
      select least(20, sum(coalesce(q.usefulness_score, case when q.was_useful then 1 else 0 end)) * 4) as obs_score
      from public.memory_query_observations q
      where q.source_type = e.source_type
        and q.source_key = e.source_id
        and (q.was_useful is true or coalesce(q.usefulness_score,0) > 0)
        and (q.query_text % v_query or v_query % q.query_text or lower(q.query_text) like '%'||lower(v_query)||'%')
    ) obs on true
    left join lateral (
      select least(24, sum(me.weight)) as edge_score
      from public.memory_semantic_edges me
      left join public.memory_semantic_nodes ns on ns.node_key=me.subject_key and me.subject_type='node'
      left join public.memory_semantic_nodes no on no.node_key=me.object_key and me.object_type='node'
      where me.active
        and ((me.subject_type=e.source_type and me.subject_key=e.source_id) or (me.object_type=e.source_type and me.object_key=e.source_id))
        and (
          lower(coalesce(me.llm_reason,'')) like '%'||lower(v_query)||'%'
          or lower(coalesce(me.weight_basis,'')) like '%'||lower(v_query)||'%'
          or lower(coalesce(ns.canonical_label,'')) like '%'||lower(v_query)||'%'
          or lower(coalesce(no.canonical_label,'')) like '%'||lower(v_query)||'%'
          or exists (select 1 from unnest(coalesce(ns.aliases,'{}'::text[]) || coalesce(no.aliases,'{}'::text[])) a where lower(a) like '%'||lower(v_query)||'%' or lower(v_query) like '%'||lower(a)||'%')
        )
    ) edge on true
    left join lateral (
      select least(22, sum(mh.weight)) as hint_score
      from public.memory_recall_hints mh
      where mh.active
        and mh.source_type=e.source_type and mh.source_key=e.source_id
        and (mh.hint_text % v_query or lower(mh.hint_text) like '%'||lower(v_query)||'%' or exists (select 1 from unnest(mh.related_keys) rk where lower(v_query) like '%'||lower(rk)||'%'))
    ) hint on true
  ), totalled as (
    select s.*, (priority_score + type_score + rank_score + exact_score + token_score + recency_score + supersession_score + observation_score + edge_score + hint_score) as total_score
    from scored s
  ), normalized as (
    select t.*, max(total_score) over () as max_score
    from totalled t
  ), limited as (
    select * from normalized
    order by total_score desc, coalesce(event_ts, 'epoch'::timestamptz) desc, base_rank asc
    limit v_limit
  ), logged as (
    insert into public.memory_recall_weight_runs(query_text, result_count, max_score, metadata)
    select v_query, count(*), max(total_score), jsonb_build_object('function','zorg_weighted_recall_context','version','recency-token-supersession-2026-05-25') from limited
    returning id
  )
  select
    l.source_type, l.source_id, l.path, l.line_start, l.line_end, l.priority, l.content,
    round(l.total_score, 3) as relevance_score,
    greatest(1, least(100, round((l.total_score / nullif(l.max_score,0)) * 100)::integer)) as relevance_percent,
    coalesce(array_to_string(l.reasons, '; '), 'base recall + rank weighting') as score_reason,
    jsonb_build_object(
      'priority', l.priority_score,
      'source_type', l.type_score,
      'rank', l.rank_score,
      'exact', l.exact_score,
      'token_overlap', l.token_score,
      'recency', l.recency_score,
      'supersession', l.supersession_score,
      'observations', l.observation_score,
      'semantic_edges', l.edge_score,
      'recall_hints', l.hint_score,
      'event_ts', l.event_ts,
      'category', l.category
    ) as weight_breakdown
  from limited l;

  perform public.memory_record_runtime_timing('weighted_recall_query', v_query_key, extract(epoch from (clock_timestamp() - transaction_timestamp()))*1000, null, null, null, jsonb_build_object('limit', v_limit, 'version', 'recency-token-supersession-2026-05-25'));
end;
$function$;


-- Required after applying when materialized recall surfaces exist:
-- select public.refresh_zorg_memory_search_mv();
-- select public.refresh_zorg_memory_search_fast_mv();
