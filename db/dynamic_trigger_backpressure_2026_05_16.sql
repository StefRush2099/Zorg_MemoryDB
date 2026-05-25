-- Dynamic trigger backpressure for Zorg MemoryDB semantic/recall work.
-- Purpose: triggers enqueue bounded deferred work instead of causing immediate CPU-heavy work.
-- Delay and batch limits are derived from observed queue/task timing, backlog, and recall/query latency.

create table if not exists public.memory_runtime_timing_observations (
  id uuid primary key default gen_random_uuid(),
  observation_kind text not null,
  source_key text,
  duration_ms numeric,
  queue_wait_ms numeric,
  processed_count integer,
  backlog_count integer,
  metadata jsonb not null default '{}'::jsonb,
  observed_at timestamptz not null default now()
);

create index if not exists idx_memory_runtime_timing_observations_kind_time
  on public.memory_runtime_timing_observations(observation_kind, observed_at desc);

create table if not exists public.memory_deferred_work_control (
  control_key text primary key,
  min_delay_ms integer not null default 15000,
  max_delay_ms integer not null default 900000,
  min_batch_size integer not null default 1,
  max_batch_size integer not null default 12,
  max_trigger_enqueue_per_statement integer not null default 1,
  notes text,
  updated_at timestamptz not null default now()
);

insert into public.memory_deferred_work_control(control_key, notes)
values ('semantic_work', 'Triggers must enqueue tiny bounded work only. Heavy semantic/recall refresh work is deferred by dynamic delay derived from observed queue/task timings, backlog, and recall/query latency.')
on conflict (control_key) do update set notes=excluded.notes, updated_at=now();

create or replace function public.memory_record_runtime_timing(
  p_observation_kind text,
  p_source_key text default null,
  p_duration_ms numeric default null,
  p_queue_wait_ms numeric default null,
  p_processed_count integer default null,
  p_backlog_count integer default null,
  p_metadata jsonb default '{}'::jsonb
) returns void
language plpgsql
as $function$
begin
  insert into public.memory_runtime_timing_observations(observation_kind, source_key, duration_ms, queue_wait_ms, processed_count, backlog_count, metadata)
  values (coalesce(p_observation_kind,'unknown'), p_source_key, p_duration_ms, p_queue_wait_ms, p_processed_count, p_backlog_count, coalesce(p_metadata,'{}'::jsonb));
end;
$function$;

create or replace function public.memory_dynamic_defer_interval(p_priority integer default 50)
returns interval
language plpgsql
stable
as $function$
declare
  v_ctl public.memory_deferred_work_control%rowtype;
  v_backlog integer := 0;
  v_queue_p95_ms numeric;
  v_run_p95_ms numeric;
  v_recall_p95_ms numeric;
  v_task_p95_ms numeric;
  v_delay_ms numeric;
  v_priority_factor numeric;
begin
  select * into v_ctl from public.memory_deferred_work_control where control_key='semantic_work';
  if not found then
    v_ctl.min_delay_ms := 15000;
    v_ctl.max_delay_ms := 900000;
  end if;

  select count(*) into v_backlog
  from public.memory_semantic_work_queue
  where status in ('queued','running');

  select percentile_cont(0.95) within group (order by extract(epoch from (coalesce(locked_at, completed_at, updated_at, now()) - created_at)) * 1000)
    into v_queue_p95_ms
  from public.memory_semantic_work_queue
  where created_at > now() - interval '24 hours'
    and status in ('queued','running','done','error');

  select percentile_cont(0.95) within group (order by extract(epoch from (completed_at - locked_at)) * 1000)
    into v_run_p95_ms
  from public.memory_semantic_work_queue
  where completed_at is not null and locked_at is not null
    and completed_at > now() - interval '24 hours';

  select percentile_cont(0.95) within group (order by duration_ms)
    into v_recall_p95_ms
  from public.memory_runtime_timing_observations
  where observed_at > now() - interval '24 hours'
    and observation_kind in ('recall_query','weighted_recall_query','semantic_worker_batch')
    and duration_ms is not null;

  v_task_p95_ms := greatest(coalesce(v_queue_p95_ms,0), coalesce(v_run_p95_ms,0), coalesce(v_recall_p95_ms,0), v_ctl.min_delay_ms);
  v_priority_factor := greatest(0.35, least(2.5, (100 - greatest(1, least(99, coalesce(p_priority,50)))) / 50.0));
  v_delay_ms := v_task_p95_ms * v_priority_factor * (1 + ln(greatest(v_backlog,0) + 1));
  v_delay_ms := greatest(v_ctl.min_delay_ms, least(v_ctl.max_delay_ms, v_delay_ms));

  return make_interval(secs => v_delay_ms / 1000.0);
end;
$function$;

create or replace function public.memory_dynamic_worker_batch_limit(p_requested integer default 25)
returns integer
language plpgsql
stable
as $function$
declare
  v_ctl public.memory_deferred_work_control%rowtype;
  v_backlog integer := 0;
  v_run_p95_ms numeric;
  v_recall_p95_ms numeric;
  v_limit integer;
begin
  select * into v_ctl from public.memory_deferred_work_control where control_key='semantic_work';
  if not found then
    v_ctl.min_batch_size := 1;
    v_ctl.max_batch_size := 12;
  end if;

  select count(*) into v_backlog
  from public.memory_semantic_work_queue
  where status='queued' and due_at <= now();

  select percentile_cont(0.95) within group (order by extract(epoch from (completed_at - locked_at)) * 1000)
    into v_run_p95_ms
  from public.memory_semantic_work_queue
  where completed_at is not null and locked_at is not null
    and completed_at > now() - interval '6 hours';

  select percentile_cont(0.95) within group (order by duration_ms)
    into v_recall_p95_ms
  from public.memory_runtime_timing_observations
  where observed_at > now() - interval '6 hours'
    and observation_kind in ('recall_query','weighted_recall_query','semantic_worker_batch')
    and duration_ms is not null;

  if greatest(coalesce(v_run_p95_ms,0), coalesce(v_recall_p95_ms,0)) > 60000 then
    v_limit := v_ctl.min_batch_size;
  elsif greatest(coalesce(v_run_p95_ms,0), coalesce(v_recall_p95_ms,0)) > 15000 then
    v_limit := greatest(v_ctl.min_batch_size, least(3, v_ctl.max_batch_size));
  else
    v_limit := greatest(v_ctl.min_batch_size, least(v_ctl.max_batch_size, greatest(1, ceil(sqrt(greatest(v_backlog,1)))::int)));
  end if;

  return greatest(v_ctl.min_batch_size, least(v_limit, v_ctl.max_batch_size, greatest(1, coalesce(p_requested,25))));
end;
$function$;

create or replace function public.memory_enqueue_semantic_job(
  p_job_kind text,
  p_source_type text,
  p_source_key text,
  p_payload jsonb default '{}'::jsonb,
  p_priority integer default 50,
  p_due_at timestamp with time zone default null
) returns uuid
language plpgsql
as $function$
declare
  v_id uuid;
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_hash text := public.memory_semantic_payload_hash(v_payload);
  v_due_at timestamptz;
begin
  v_due_at := coalesce(p_due_at, now() + public.memory_dynamic_defer_interval(p_priority));

  insert into public.memory_semantic_work_queue(job_kind, source_type, source_key, payload, payload_hash, priority, due_at)
  values (p_job_kind, p_source_type, p_source_key, v_payload, v_hash, coalesce(p_priority, 50), v_due_at)
  on conflict (job_kind, source_type, source_key, payload_hash) where status in ('queued','running')
  do update set
    priority = greatest(public.memory_semantic_work_queue.priority, excluded.priority),
    due_at = greatest(public.memory_semantic_work_queue.due_at, excluded.due_at),
    payload = public.memory_semantic_work_queue.payload || excluded.payload || jsonb_build_object('deferred_again_at', now()),
    updated_at = now()
  returning id into v_id;

  perform public.memory_record_runtime_timing(
    'trigger_enqueue_deferred',
    p_job_kind || ':' || p_source_type,
    null,
    extract(epoch from (v_due_at - now())) * 1000,
    1,
    (select count(*)::int from public.memory_semantic_work_queue where status in ('queued','running')),
    jsonb_build_object('priority', p_priority, 'due_at', v_due_at)
  );

  return v_id;
end;
$function$;

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

  perform public.memory_record_runtime_timing('weighted_recall_query', v_query_key, extract(epoch from (clock_timestamp() - transaction_timestamp()))*1000, null, null, null, jsonb_build_object('limit', v_limit));
end;
$$;insert into public.zorg_logic_rules(rule_key,title,rule_text,rule_type,priority,privacy_scope,source_basis,applies_to,standard_checks,active,created_at,updated_at)
values (
  'dynamic-trigger-backpressure-2026-05-16',
  'Dynamic Trigger Backpressure / Deferred Work Rule',
  'Database triggers and recall-adjacent hooks must not perform heavy immediate work. They should enqueue at most tiny bounded work, assign due_at using statistically derived delay from at least a 90-day rolling activity window when available, observed request timestamps/durations, idle gaps, queue wait, worker runtime, backlog, CPU/load, and recall/query timing, and let workers process bounded batches. Deeper indexing, trigger, and recall tuning should be delayed into statistically idle/off-hours windows; during historically active periods, only short bounded tuning bursts may run when latency/load permits. Dynamic delay and batch limits must protect immediate operator function under high CPU load while preserving the higher-priority rule that correctness/rule-following outranks speed. Source memory may not be pruned for performance.',
  'operating_rule',
  'critical',
  'public_safe',
  'operator_instruction_2026_05_16',
  array['database','triggers','recall','semantic_worker','performance','cpu_load','rules_first','request_activity','idle_windows'],
  array['Triggers enqueue/defer instead of doing heavy work','Due times derive from at least a 90-day rolling activity window when available, observed request timing, idle gaps, queue/task/recall timing, CPU/load, and backlog, not a fixed sleep','Workers use bounded dynamic batch limits','Deep tuning/indexing is postponed into statistically idle/off-hours windows','Historically active periods allow only short bounded tuning bursts when latency/load permits','High CPU/latency increases delay and reduces batch size','Rule-following and recall correctness outrank performance','Never prune source memory for speed'],
  true,
  now(),
  now()
)
on conflict (rule_key) do update set
  title=excluded.title,
  rule_text=excluded.rule_text,
  priority=excluded.priority,
  privacy_scope=excluded.privacy_scope,
  source_basis=excluded.source_basis,
  applies_to=excluded.applies_to,
  standard_checks=excluded.standard_checks,
  active=true,
  updated_at=now();
