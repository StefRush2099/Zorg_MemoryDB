-- Public clean-install compatibility objects required by bundled recall code.
--
-- Pre-v4 queue variants can contain duplicate *derived* query jobs.  Reconcile
-- them before restoring the unique conflict target used by the runtime helper.
with ranked as (
  select id,
         row_number() over (
           partition by source_type, source_key
           order by (status = 'running') desc, priority desc, updated_at desc, created_at desc, id desc
         ) as rn,
         max(priority) over (partition by source_type, source_key) as max_priority
  from public.memory_semantic_work_queue
), updated as (
  update public.memory_semantic_work_queue q
  set priority = greatest(q.priority, r.max_priority), updated_at = now()
  from ranked r
  where q.id = r.id and r.rn = 1
  returning q.id
)
delete from public.memory_semantic_work_queue q
using ranked r
where q.id = r.id and r.rn > 1;

alter table public.memory_semantic_work_queue
  drop constraint if exists memory_semantic_work_queue_source_type_source_key_key;
alter table public.memory_semantic_work_queue
  add constraint memory_semantic_work_queue_source_type_source_key_key unique (source_type, source_key);

create or replace function public.memory_enqueue_semantic_job(
  p_job_kind text,
  p_source_type text,
  p_source_key text,
  p_payload jsonb default '{}'::jsonb,
  p_priority integer default 50
)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  insert into public.memory_semantic_work_queue(
    job_kind, source_type, source_key, payload, payload_hash, priority,
    status, due_at, updated_at
  ) values (
    coalesce(nullif(p_job_kind, ''), 'semantic_embedding'),
    p_source_type,
    p_source_key,
    coalesce(p_payload, '{}'::jsonb),
    md5(coalesce(p_payload, '{}'::jsonb)::text),
    coalesce(p_priority, 50),
    'queued',
    now(),
    now()
  )
  on conflict (source_type, source_key) do update set
    job_kind = excluded.job_kind,
    payload = excluded.payload,
    payload_hash = excluded.payload_hash,
    priority = greatest(memory_semantic_work_queue.priority, excluded.priority),
    status = case
      when memory_semantic_work_queue.status = 'running' then 'running'
      else 'queued'
    end,
    due_at = case
      when memory_semantic_work_queue.status = 'running'
        then memory_semantic_work_queue.due_at
      else now()
    end,
    updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.memory_enqueue_semantic_job(
  p_source_type text,
  p_source_key text,
  p_payload jsonb default '{}'::jsonb
)
returns uuid
language sql
as $$
  select public.memory_enqueue_semantic_job(
    'semantic_embedding', $1, $2, $3, 50
  )
$$;

create or replace function public.zorg_get_logic_context(
  p_query text,
  p_limit integer default 10
)
returns table(
  source_type text,
  source_id text,
  path text,
  line_start integer,
  line_end integer,
  priority text,
  content text
)
language sql
stable
as $$
  select
    'logic_rule'::text,
    r.id::text,
    r.source_path,
    null::integer,
    null::integer,
    r.priority,
    left(concat_ws(E'\n', r.rule_title, r.rule_text), 4000)
  from public.zorg_logic_rules r
  where r.active
    and (
      to_tsvector(
        'simple',
        concat_ws(' ', r.rule_title, r.rule_text, array_to_string(r.applies_to, ' '))
      ) @@ plainto_tsquery('simple', coalesce(p_query, ''))
      or concat_ws(' ', r.rule_title, r.rule_text, array_to_string(r.applies_to, ' '))
        ilike '%' || coalesce(p_query, '') || '%'
    )
  order by
    case lower(r.priority)
      when 'critical' then 1
      when 'high' then 2
      when 'medium' then 3
      else 4
    end,
    r.updated_at desc
  limit greatest(coalesce(p_limit, 10), 1)
$$;

create or replace function public.zorg_weighted_recall_context(
  p_query text,
  p_limit integer default 10
)
returns table(
  source_type text,
  source_id text,
  path text,
  line_start integer,
  line_end integer,
  priority text,
  content text,
  relevance_score numeric,
  score_reason text,
  weight_breakdown jsonb
)
language sql
stable
as $$
  select
    public.memory_recall_source_type(z.source_table),
    z.source_id,
    null::text,
    null::integer,
    null::integer,
    z.priority,
    left(z.content, 4000),
    (
      case
        when z.content_fts_simple @@ plainto_tsquery('simple', coalesce(p_query, ''))
          then 10
        else 1
      end * greatest(1, 10 - z.priority_rank)
    )::numeric,
    'weighted full-text recall'::text,
    jsonb_build_object(
      'priority_rank', z.priority_rank,
      'source_rank', z.source_rank
    )
  from public.zorg_memory_search_fast_mv z
  where z.content_fts_simple @@ plainto_tsquery('simple', coalesce(p_query, ''))
     or z.content_lc like '%' || lower(coalesce(p_query, '')) || '%'
  order by
    case
      when z.content_fts_simple @@ plainto_tsquery('simple', coalesce(p_query, ''))
        then 0
      else 1
    end,
    z.priority_rank,
    z.source_rank,
    z.event_ts desc nulls last
  limit greatest(coalesce(p_limit, 10), 1)
$$;
