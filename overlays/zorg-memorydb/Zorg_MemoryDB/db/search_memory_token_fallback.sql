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
    SELECT DISTINCT t.token
    FROM regexp_split_to_table(v_query_lc, '[^a-z0-9]+') AS t(token)
    WHERE length(t.token) >= 3
    LIMIT 12
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
  WITH fts_matches AS (
    SELECT z.source_table, z.source_id, z.event_ts, z.category, z.priority,
           left(z.content, 240) AS snippet, 0 AS match_rank, NULL::integer AS token_hits
    FROM public.zorg_memory_search_fast_mv z
    WHERE (z.content_fts_en @@ v_ts_en OR z.content_fts_simple @@ v_ts_simple)
    ORDER BY z.source_rank, z.event_ts DESC
    LIMIT v_limit
  ), exact_matches AS (
    SELECT z.source_table, z.source_id, z.event_ts, z.category, z.priority,
           left(z.content, 240) AS snippet, 1 AS match_rank, NULL::integer AS token_hits
    FROM public.zorg_memory_search_fast_mv z
    WHERE z.content_lc LIKE '%' || v_query_lc || '%'
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
      AND NOT EXISTS (SELECT 1 FROM fts_matches f WHERE f.source_table=z.source_table AND f.source_id=z.source_id)
      AND NOT EXISTS (SELECT 1 FROM exact_matches e WHERE e.source_table=z.source_table AND e.source_id=z.source_id)
    ORDER BY token_hits DESC, z.source_rank, z.event_ts DESC
    LIMIT v_limit
  ), ranked AS (
    SELECT f.source_table, f.source_id, f.event_ts, f.category, f.priority, f.snippet, f.match_rank, f.token_hits::numeric FROM fts_matches f
    UNION ALL
    SELECT e.source_table, e.source_id, e.event_ts, e.category, e.priority, e.snippet, e.match_rank, e.token_hits::numeric FROM exact_matches e
    UNION ALL
    SELECT t.source_table, t.source_id, t.event_ts, t.category, t.priority, t.snippet, t.match_rank, t.token_hits FROM token_matches t
    WHERE (SELECT count(*) FROM fts_matches) + (SELECT count(*) FROM exact_matches) < v_limit
  )
  SELECT r.source_table, r.source_id, r.event_ts, r.category, r.priority, r.snippet
  FROM ranked r
  ORDER BY CASE WHEN r.source_table = 'logic_rule' THEN 0 WHEN r.priority = 'critical' THEN 1 ELSE 2 END, r.match_rank, coalesce(r.token_hits, 0) DESC, r.event_ts DESC
  LIMIT v_limit;
END;
$function$;
