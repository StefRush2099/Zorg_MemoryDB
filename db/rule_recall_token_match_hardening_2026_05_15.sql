-- Rule recall token-match hardening, 2026-05-15
-- Purpose: prevent broad natural-language rule queries from missing critical logic rules
-- merely because PostgreSQL plainto_tsquery requires too many terms to match at once.
-- This is additive recall hardening: it changes ranking/matching logic only and does not
-- delete, prune, compact, or discard any source memory data.

CREATE OR REPLACE FUNCTION public.zorg_get_logic_context(p_query text, p_limit integer DEFAULT 5)
RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
LANGUAGE sql
AS $function$
  WITH q AS (
    SELECT
      coalesce(p_query, '') AS raw_query,
      lower(coalesce(p_query, '')) AS query_lc,
      plainto_tsquery('english', coalesce(p_query, '')) AS ts_en,
      plainto_tsquery('simple', coalesce(p_query, '')) AS ts_simple
  ), tokens AS (
    SELECT DISTINCT token
    FROM q, regexp_split_to_table(q.query_lc, '[^a-z0-9]+') AS token
    WHERE length(token) >= 3
    LIMIT 16
  ), token_count AS (
    SELECT count(*)::integer AS n FROM tokens
  ), scored AS (
    SELECT
      r.*,
      (r.title || E'\n' || r.rule_text || E'\n' || coalesce(array_to_string(r.applies_to,' '),'')) AS haystack,
      lower(r.title || E'\n' || r.rule_text || E'\n' || coalesce(array_to_string(r.applies_to,' '),'')) AS haystack_lc
    FROM public.zorg_logic_rules r
    WHERE coalesce(r.active,true) = true
  ), matched AS (
    SELECT
      s.*,
      tc.n AS query_token_count,
      (
        SELECT count(*)::integer
        FROM tokens t
        WHERE s.haystack_lc LIKE '%' || t.token || '%'
      ) AS token_hits,
      CASE WHEN s.haystack_lc LIKE '%' || q.query_lc || '%' AND length(q.query_lc) >= 3 THEN 1 ELSE 0 END AS exact_phrase_hit,
      CASE WHEN to_tsvector('english', s.haystack) @@ q.ts_en OR to_tsvector('simple', s.haystack) @@ q.ts_simple THEN 1 ELSE 0 END AS fts_all_hit
    FROM scored s CROSS JOIN q CROSS JOIN token_count tc
  )
  SELECT
    'logic_rule'::text,
    m.id::text,
    null::text,
    null::integer,
    null::integer,
    m.priority,
    concat_ws(E'\n',
      'Logic rule: ' || coalesce(m.title,''),
      'Key: ' || coalesce(m.rule_key,''),
      'Type: ' || coalesce(m.rule_type,''),
      'Priority: ' || coalesce(m.priority,''),
      'Privacy: ' || coalesce(m.privacy_scope,''),
      'Source basis: ' || coalesce(m.source_basis,''),
      'Rule: ' || coalesce(m.rule_text,''),
      'Applies to: ' || coalesce(array_to_string(m.applies_to, ', '),''),
      'Standard checks: ' || coalesce(array_to_string(m.standard_checks, '; '),''),
      'Performance tuning: ' || coalesce(m.performance_tuning_notes,'')
    )
  FROM matched m
  WHERE
    m.exact_phrase_hit = 1
    OR m.fts_all_hit = 1
    OR (
      m.query_token_count > 0
      AND m.token_hits >= CASE
        WHEN m.query_token_count <= 2 THEN m.query_token_count
        WHEN m.query_token_count <= 5 THEN 2
        ELSE 3
      END
    )
  ORDER BY
    m.exact_phrase_hit DESC,
    m.fts_all_hit DESC,
    m.token_hits DESC,
    CASE WHEN lower(m.priority)='critical' THEN 1 WHEN lower(m.priority)='high' THEN 2 WHEN lower(m.priority)='medium' THEN 3 ELSE 4 END,
    m.updated_at DESC
  LIMIT greatest(coalesce(p_limit,5),1);
$function$;
