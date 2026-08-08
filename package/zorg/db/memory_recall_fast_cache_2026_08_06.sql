-- Additive, derived-only 30-second cache for the expensive fast-MV recall layer.
-- Rollback:
--   replace memory_recall_v2 with its prior definition;
--   drop function if exists public.memory_recall_fast_cached_v1(text,integer,interval);
--   drop table if exists public.memory_recall_fast_cache_rows;
--   drop table if exists public.memory_recall_fast_cache_batches;

create table if not exists public.memory_recall_fast_cache_batches (
  query_hash text not null,
  requested_limit integer not null,
  query_text text not null,
  result_count integer not null,
  cached_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  primary key (query_hash, requested_limit)
);

create table if not exists public.memory_recall_fast_cache_rows (
  query_hash text not null,
  requested_limit integer not null,
  result_rank integer not null,
  source_type text,
  source_id text,
  path text,
  line_start integer,
  line_end integer,
  priority text,
  content text,
  score numeric,
  score_reason text,
  metadata jsonb,
  primary key (query_hash, requested_limit, result_rank),
  foreign key (query_hash, requested_limit)
    references public.memory_recall_fast_cache_batches(query_hash, requested_limit)
    on delete cascade
);

create index if not exists idx_memory_recall_fast_cache_expiry
  on public.memory_recall_fast_cache_batches (expires_at);

create or replace function public.memory_recall_fast_cached_v1(
  p_query text,
  p_limit integer default 10,
  p_ttl interval default interval '30 seconds'
)
returns table(
  source_type text, source_id text, path text, line_start integer,
  line_end integer, priority text, content text, score numeric,
  score_reason text, metadata jsonb
)
language plpgsql
volatile
as $function$
declare
  v_query text := coalesce(p_query, '');
  v_limit integer := greatest(coalesce(p_limit, 10), 1);
  v_hash text := md5(lower(btrim(v_query)));
  v_hit boolean := false;
begin
  select exists (
    select 1 from public.memory_recall_fast_cache_batches b
    where b.query_hash = v_hash
      and b.requested_limit = v_limit
      and b.expires_at > clock_timestamp()
  ) into v_hit;

  if not v_hit then
    perform pg_advisory_xact_lock(hashtext('memory-recall-fast-cache:' || v_hash || ':' || v_limit::text));
    select exists (
      select 1 from public.memory_recall_fast_cache_batches b
      where b.query_hash = v_hash
        and b.requested_limit = v_limit
        and b.expires_at > clock_timestamp()
    ) into v_hit;
  end if;

  if not v_hit then
    delete from public.memory_recall_fast_cache_batches
    where (query_hash = v_hash and requested_limit = v_limit)
       or expires_at < clock_timestamp() - interval '1 hour';

    insert into public.memory_recall_fast_cache_batches(
      query_hash, requested_limit, query_text, result_count, cached_at, expires_at
    ) values (
      v_hash, v_limit, v_query, 0, clock_timestamp(), clock_timestamp() + p_ttl
    );

    insert into public.memory_recall_fast_cache_rows(
      query_hash, requested_limit, result_rank, source_type, source_id, path,
      line_start, line_end, priority, content, score, score_reason, metadata
    )
    select v_hash, v_limit, row_number() over ()::integer,
           r.source_type, r.source_id, r.path, r.line_start, r.line_end,
           r.priority, r.content, r.score, r.score_reason, r.metadata
    from public.memory_recall_fast_mv_v1(v_query, v_limit) r;

    update public.memory_recall_fast_cache_batches b
    set result_count = (
      select count(*) from public.memory_recall_fast_cache_rows r
      where r.query_hash = v_hash and r.requested_limit = v_limit
    )
    where b.query_hash = v_hash and b.requested_limit = v_limit;
  end if;

  return query
  select r.source_type, r.source_id, r.path, r.line_start, r.line_end,
         r.priority, r.content, r.score,
         (case when v_hit then 'fast_mv_cache_hit:' else 'fast_mv_cache_miss:' end)
           || coalesce(r.score_reason, ''),
         coalesce(r.metadata, '{}'::jsonb)
           || jsonb_build_object('fast_cache_hit', v_hit, 'fast_cache_ttl_seconds', extract(epoch from p_ttl)::integer)
  from public.memory_recall_fast_cache_rows r
  where r.query_hash = v_hash and r.requested_limit = v_limit
  order by r.result_rank;
end;
$function$;

comment on function public.memory_recall_fast_cached_v1(text,integer,interval) is
  'Caches only derived fast-MV recall rows briefly; exact aliases and logic-rule preflight remain live.';

create or replace function public.memory_provider_ann_recall_fast_v1(
  p_query text,
  p_limit integer default 20,
  p_provider text default 'local',
  p_model text default 'embeddinggemma-300m-qat-q8_0'
)
returns table(
  source_type text, source_id text, path text, line_start integer,
  line_end integer, priority text, content text,
  vector_distance double precision, vector_score numeric
)
language plpgsql
volatile
as $function$
declare
  v_embedding vector(768);
begin
  perform set_config('hnsw.ef_search', '400', true);

  select q.embedding into v_embedding
  from public.memory_query_embedding_cache q
  where q.active
    and q.query_hash = md5(lower(btrim(coalesce(p_query, ''))))
    and q.embedding_provider = coalesce(p_provider, 'local')
    and q.embedding_model = coalesce(p_model, 'embeddinggemma-300m-qat-q8_0')
  order by q.updated_at desc
  limit 1;

  if v_embedding is null then
    return;
  end if;

  return query
  select e.source_type, e.source_key, null::text, null::integer, null::integer,
    coalesce(e.priority, 'medium'), e.content_text,
    (e.embedding <=> v_embedding)::double precision,
    greatest(0, 1 - (e.embedding <=> v_embedding))::numeric * 60
  from public.memory_ann_model_embeddings e
  where e.active
    and e.embedding_provider = coalesce(p_provider, 'local')
    and e.embedding_model = coalesce(p_model, 'embeddinggemma-300m-qat-q8_0')
    and (e.source_type <> 'logic_rule' or exists (
      select 1 from public.zorg_logic_rules r
      where r.id::text = e.source_key and r.active
    ))
  order by e.embedding <=> v_embedding
  limit greatest(coalesce(p_limit, 20), 1);
end;
$function$;

comment on function public.memory_provider_ann_recall_fast_v1(text,integer,text,text) is
  'Typed-query-vector ANN wrapper that allows the existing filtered HNSW index to serve provider recall.';

-- Keep all authoritative layers live; cache only the expensive derived fast-MV layer.
create or replace function public.memory_recall_v2(
  p_query text,
  p_limit integer default 10,
  p_context jsonb default '{}'::jsonb
)
returns table(
  source_type text, source_id text, path text, line_start integer, line_end integer,
  priority text, content text, recall_mode text, rank integer, score numeric,
  score_reason text, metadata jsonb
)
language plpgsql
as $function$
declare
  v_limit integer := greatest(coalesce(p_limit, 10), 1);
  v_query text := coalesce(p_query, '');
  v_ann_limit integer := least(greatest(v_limit, 5), 8);
  v_has_ann boolean := false;
  v_deep boolean := lower(coalesce(p_context->>'mode', 'normal')) in ('deep', 'weighted', 'full');
begin
  perform public.memory_enqueue_semantic_job(
    'recall_query', 'query', md5(lower(v_query)),
    jsonb_build_object('query_text', v_query, 'context', coalesce(p_context, '{}'::jsonb)), 40
  );

  select exists (
    select 1 from public.memory_query_embedding_cache
    where active and query_hash = md5(lower(btrim(v_query)))
      and embedding_provider = coalesce(p_context->>'embedding_provider', 'local')
      and embedding_model = coalesce(p_context->>'embedding_model', 'nomic-embed-text:latest')
  ) into v_has_ann;

  return query
  with exact_rows as (
    select *, 1000::numeric as layer_boost, 'exact_alias'::text as layer
    from public.memory_recall_exact_alias_v1(v_query, v_limit)
  ), rule_rows as (
    select r.source_type, r.source_id, r.path, r.line_start, r.line_end,
      coalesce(r.priority, 'critical') as priority, left(r.content, 4000) as content,
      (850 + coalesce((select least(500, public.zorg_logic_rule_effective_weight(lr.rule_key,lr.priority,lr.updated_at)) from public.zorg_logic_rules lr where lr.id::text=r.source_id),0) + greatest(0, 100-r.context_rank) + public.memory_email_rule_scope_boost(v_query,r.source_id))::numeric as score,
      'logic rule preflight procedure'::text as score_reason,
      jsonb_build_object('procedure','zorg_get_logic_context') as metadata,
      850::numeric as layer_boost, 'logic_preflight'::text as layer
    from (select x.*,row_number() over()::integer as context_rank from public.zorg_get_logic_context(v_query,greatest(6,least(v_limit,16))) x) r
  ), fast_rows as (
    select *,500::numeric as layer_boost,'fast_mv'::text as layer
    from public.memory_recall_fast_cached_v1(v_query,greatest(v_limit,12),interval '30 seconds')
  ), weighted_rows as (
    select w.source_type,w.source_id,w.path,w.line_start,w.line_end,
      coalesce(w.priority,'medium'),left(w.content,4000),coalesce(w.relevance_score,0)::numeric,
      coalesce(w.score_reason,'weighted recall procedure'),
      coalesce(w.weight_breakdown,'{}'::jsonb)||jsonb_build_object('procedure','zorg_weighted_recall_context'),
      550::numeric,'weighted_deep'::text
    from public.zorg_weighted_recall_context(v_query,v_limit) w where v_deep
  ), ann_rows as (
    select a.source_type,a.source_id,a.path,a.line_start,a.line_end,coalesce(a.priority,'medium'),left(a.content,4000),
      coalesce(a.vector_score,0)::numeric,'pgvector ANN provider recall'::text,
      jsonb_build_object('procedure','memory_provider_ann_recall','vector_distance',a.vector_distance,
        'embedding_provider',coalesce(p_context->>'embedding_provider','local'),
        'embedding_model',coalesce(p_context->>'embedding_model','nomic-embed-text:latest')),
      425::numeric,'pgvector_ann'::text
    from public.memory_provider_ann_recall_fast_v1(v_query,v_ann_limit,
      coalesce(p_context->>'embedding_provider','local'),coalesce(p_context->>'embedding_model','nomic-embed-text:latest')) a
    where v_has_ann
  ), combined as (
    select * from exact_rows union all select * from rule_rows union all select * from fast_rows
    union all select * from weighted_rows union all select * from ann_rows
  ), deduped as (
    select c.*,row_number() over(partition by c.source_type,c.source_id order by c.layer_boost desc,c.score desc,length(c.content) desc) dupe_rank
    from combined c where nullif(c.content,'') is not null
  ), ranked as (
    select d.*,row_number() over(order by d.layer_boost desc,d.score desc,
      case lower(coalesce(d.priority,'medium')) when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end,
      d.source_type,d.source_id)::integer out_rank
    from deduped d where d.dupe_rank=1
  )
  select r.source_type,r.source_id,r.path,r.line_start,r.line_end,r.priority,r.content,
    concat_ws('-','database-stored-procedure-hybrid',case when exists(select 1 from ranked x where x.layer='pgvector_ann') then 'pgvector-ann' end,case when v_deep then 'deep-weighted' end),
    r.out_rank,(r.layer_boost+r.score),concat_ws(':',r.layer,r.score_reason),
    r.metadata||jsonb_build_object('layer',r.layer,'procedure_api','memory_recall_v2')
  from ranked r order by r.out_rank limit v_limit;
end;
$function$;
