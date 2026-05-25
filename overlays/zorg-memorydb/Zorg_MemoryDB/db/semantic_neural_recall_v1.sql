-- Zorg MemoryDB semantic neural recall queue + weighted recall v1
-- Additive only: preserves all source rows and existing recall functions.

create table if not exists public.memory_semantic_work_queue (
  id uuid primary key default gen_random_uuid(),
  job_kind text not null,
  source_type text not null,
  source_key text not null,
  payload jsonb not null default '{}'::jsonb,
  payload_hash text not null,
  priority integer not null default 50,
  status text not null default 'queued',
  attempts integer not null default 0,
  max_attempts integer not null default 5,
  due_at timestamptz not null default now(),
  locked_at timestamptz,
  locked_by text,
  completed_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint memory_semantic_work_queue_status_ck check (status in ('queued','running','done','error','skipped'))
);

create index if not exists idx_memory_semantic_work_queue_due
  on public.memory_semantic_work_queue(status, due_at, priority desc, created_at);
create index if not exists idx_memory_semantic_work_queue_source
  on public.memory_semantic_work_queue(source_type, source_key);
create unique index if not exists idx_memory_semantic_work_queue_active_unique
  on public.memory_semantic_work_queue(job_kind, source_type, source_key, payload_hash)
  where status in ('queued','running');

create table if not exists public.memory_semantic_tuner_versions (
  id uuid primary key default gen_random_uuid(),
  version_key text not null unique,
  description text not null,
  script_path text,
  model_hint text,
  status text not null default 'active',
  safety_notes text,
  benchmark_summary jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.memory_recall_weight_runs (
  id uuid primary key default gen_random_uuid(),
  query_text text not null,
  result_count integer not null default 0,
  max_score numeric,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_memory_recall_weight_runs_query_trgm
  on public.memory_recall_weight_runs using gin (query_text gin_trgm_ops);
create index if not exists idx_memory_recall_weight_runs_created
  on public.memory_recall_weight_runs(created_at desc);

create or replace function public.memory_semantic_payload_hash(p_payload jsonb)
returns text language sql immutable as $$
  select encode(digest(coalesce(p_payload, '{}'::jsonb)::text, 'sha256'), 'hex')
$$;

create or replace function public.memory_enqueue_semantic_job(
  p_job_kind text,
  p_source_type text,
  p_source_key text,
  p_payload jsonb default '{}'::jsonb,
  p_priority integer default 50,
  p_due_at timestamptz default now()
) returns uuid
language plpgsql
as $$
declare
  v_id uuid;
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_hash text := public.memory_semantic_payload_hash(v_payload);
begin
  insert into public.memory_semantic_work_queue(job_kind, source_type, source_key, payload, payload_hash, priority, due_at)
  values (p_job_kind, p_source_type, p_source_key, v_payload, v_hash, coalesce(p_priority, 50), coalesce(p_due_at, now()))
  on conflict (job_kind, source_type, source_key, payload_hash) where status in ('queued','running')
  do update set priority = greatest(public.memory_semantic_work_queue.priority, excluded.priority),
                due_at = least(public.memory_semantic_work_queue.due_at, excluded.due_at),
                updated_at = now()
  returning id into v_id;
  perform pg_notify('memory_semantic_work_queue', json_build_object('id', v_id, 'job_kind', p_job_kind, 'source_type', p_source_type, 'source_key', p_source_key)::text);
  return v_id;
end;
$$;

create or replace function public.memory_enqueue_zorg_memory_semantic_job()
returns trigger language plpgsql as $$
declare
  v_payload jsonb;
begin
  if tg_op = 'UPDATE' and coalesce(new.memory_value,'') = coalesce(old.memory_value,'')
     and coalesce(new.memory_key,'') = coalesce(old.memory_key,'')
     and coalesce(new.chat_session_log,'') = coalesce(old.chat_session_log,'')
     and coalesce(new.ai_response,'') = coalesce(old.ai_response,'') then
    return new;
  end if;
  v_payload := jsonb_build_object(
    'table', 'zorg_memory',
    'memory_key', new.memory_key,
    'category', new.memory_category,
    'priority', new.memory_priority,
    'event', tg_op
  );
  perform public.memory_enqueue_semantic_job('source_changed', 'zorg_memory', new.id::text, v_payload, case when lower(coalesce(new.memory_priority,''))='critical' then 95 when lower(coalesce(new.memory_priority,''))='high' then 80 else 50 end);
  return new;
end;
$$;

drop trigger if exists trg_memory_enqueue_zorg_memory_semantic_job on public.zorg_memory;
create trigger trg_memory_enqueue_zorg_memory_semantic_job
after insert or update on public.zorg_memory
for each row execute function public.memory_enqueue_zorg_memory_semantic_job();

create or replace function public.memory_enqueue_contact_semantic_job()
returns trigger language plpgsql as $$
declare
  v_payload jsonb;
begin
  v_payload := jsonb_build_object('table','zorg_contacts_crm','display_name',new.display_name,'company',new.company,'job_title',new.job_title,'event',tg_op);
  perform public.memory_enqueue_semantic_job('source_changed', 'contact', new.id::text, v_payload, 60);
  return new;
end;
$$;

drop trigger if exists trg_memory_enqueue_contact_semantic_job on public.zorg_contacts_crm;
create trigger trg_memory_enqueue_contact_semantic_job
after insert or update on public.zorg_contacts_crm
for each row execute function public.memory_enqueue_contact_semantic_job();

create or replace function public.memory_enqueue_success_query_semantic_job()
returns trigger language plpgsql as $$
begin
  perform public.memory_enqueue_semantic_job('successful_query', 'success_query', new.id::text,
    jsonb_build_object('query_text',new.query_text,'intent',new.intent,'completed_ok',new.completed_ok), 75);
  return new;
end;
$$;

drop trigger if exists trg_memory_enqueue_success_query_semantic_job on public.zorg_success_query_index;
create trigger trg_memory_enqueue_success_query_semantic_job
after insert or update on public.zorg_success_query_index
for each row execute function public.memory_enqueue_success_query_semantic_job();

create or replace function public.zorg_weighted_recall_context(p_query text, p_limit integer default 10)
returns table(
  source_type text,
  source_id text,
  path text,
  line_start integer,
  line_end integer,
  priority text,
  content text,
  relevance_score numeric,
  relevance_percent integer,
  score_reason text,
  weight_breakdown jsonb
)
language plpgsql
as $$
declare
  v_query text := coalesce(p_query, '');
  v_limit integer := greatest(coalesce(p_limit, 10), 1);
  v_query_key text := md5(lower(coalesce(p_query,'')));
begin
  perform public.memory_enqueue_semantic_job('recall_query', 'query', v_query_key, jsonb_build_object('query_text', v_query), 40);

  return query
  with base as (
    select row_number() over () as base_rank, r.*
    from public.zorg_recall_context(v_query, greatest(v_limit * 4, 20)) r
  ), scored as (
    select b.*,
      (case lower(coalesce(b.priority,'')) when 'critical' then 45 when 'high' then 30 when 'medium' then 15 else 5 end)::numeric as priority_score,
      (case b.source_type when 'logic_rule' then 25 when 'recall_hint' then 22 when 'contact' then 18 when 'relationship' then 15 when 'directive' then 22 else 10 end)::numeric as type_score,
      greatest(0, 24 - least(b.base_rank, 24))::numeric as rank_score,
      (case when lower(coalesce(b.content,'')) like '%' || lower(v_query) || '%' and length(v_query) >= 3 then 20 else 0 end)::numeric as exact_score,
      coalesce(obs.obs_score,0)::numeric as observation_score,
      coalesce(edge.edge_score,0)::numeric as edge_score,
      coalesce(hint.hint_score,0)::numeric as hint_score,
      array_remove(array[
        case when lower(coalesce(b.priority,'')) in ('critical','high') then 'priority='||coalesce(b.priority,'') end,
        case when coalesce(obs.obs_score,0) > 0 then 'prior useful query observations' end,
        case when coalesce(edge.edge_score,0) > 0 then 'semantic graph edge match' end,
        case when coalesce(hint.hint_score,0) > 0 then 'recall hint match' end,
        case when lower(coalesce(b.content,'')) like '%' || lower(v_query) || '%' and length(v_query) >= 3 then 'exact phrase match' end
      ], null) as reasons
    from base b
    left join lateral (
      select least(20, sum(coalesce(q.usefulness_score, case when q.was_useful then 1 else 0 end)) * 4) as obs_score
      from public.memory_query_observations q
      where q.source_type = b.source_type
        and q.source_key = b.source_id
        and (q.was_useful is true or coalesce(q.usefulness_score,0) > 0)
        and (q.query_text % v_query or v_query % q.query_text or lower(q.query_text) like '%'||lower(v_query)||'%')
    ) obs on true
    left join lateral (
      select least(24, sum(e.weight)) as edge_score
      from public.memory_semantic_edges e
      left join public.memory_semantic_nodes ns on ns.node_key=e.subject_key and e.subject_type='node'
      left join public.memory_semantic_nodes no on no.node_key=e.object_key and e.object_type='node'
      where e.active
        and ((e.subject_type=b.source_type and e.subject_key=b.source_id) or (e.object_type=b.source_type and e.object_key=b.source_id))
        and (
          lower(coalesce(e.llm_reason,'')) like '%'||lower(v_query)||'%'
          or lower(coalesce(e.weight_basis,'')) like '%'||lower(v_query)||'%'
          or lower(coalesce(ns.canonical_label,'')) like '%'||lower(v_query)||'%'
          or lower(coalesce(no.canonical_label,'')) like '%'||lower(v_query)||'%'
          or exists (select 1 from unnest(coalesce(ns.aliases,'{}'::text[]) || coalesce(no.aliases,'{}'::text[])) a where lower(a) like '%'||lower(v_query)||'%' or lower(v_query) like '%'||lower(a)||'%')
        )
    ) edge on true
    left join lateral (
      select least(22, sum(h.weight)) as hint_score
      from public.memory_recall_hints h
      where h.active
        and h.source_type=b.source_type and h.source_key=b.source_id
        and (h.hint_text % v_query or lower(h.hint_text) like '%'||lower(v_query)||'%' or exists (select 1 from unnest(h.related_keys) rk where lower(v_query) like '%'||lower(rk)||'%'))
    ) hint on true
  ), totalled as (
    select s.*, (priority_score + type_score + rank_score + exact_score + observation_score + edge_score + hint_score) as total_score
    from scored s
  ), normalized as (
    select t.*, max(total_score) over () as max_score
    from totalled t
  ), limited as (
    select * from normalized
    order by total_score desc, base_rank asc
    limit v_limit
  ), logged as (
    insert into public.memory_recall_weight_runs(query_text, result_count, max_score, metadata)
    select v_query, count(*), max(total_score), jsonb_build_object('function','zorg_weighted_recall_context') from limited
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
      'observations', l.observation_score,
      'semantic_edges', l.edge_score,
      'recall_hints', l.hint_score
    ) as weight_breakdown
  from limited l;
end;
$$;

insert into public.memory_semantic_tuner_versions(version_key, description, script_path, model_hint, safety_notes, benchmark_summary)
values (
  'semantic-neural-recall-v1',
  'Queue-driven additive semantic association layer: DB triggers enqueue source/query events; worker builds semantic nodes, weighted edges, recall hints, and weighted recall scoring without deleting source memory.',
  'scripts/memory_semantic_worker.py',
  'LLM-governed: script logic may be revised by an LLM after recall miss evidence and before/after benchmarks.',
  'Triggers only enqueue jobs and notify. No arbitrary generated code executes inside PostgreSQL hot paths. Derived rows are additive/rebuildable.',
  '{}'::jsonb
)
on conflict (version_key) do update set description=excluded.description, script_path=excluded.script_path, model_hint=excluded.model_hint, safety_notes=excluded.safety_notes, updated_at=now();
