-- Public-safe ANN/vector bootstrap. Idempotent and source-data preserving.

create table if not exists public.memory_embedding_model_slots (
  slot_key text primary key,
  embedding_provider text not null,
  embedding_model text not null,
  embedding_dim integer not null,
  endpoint text,
  enabled boolean not null default true,
  is_default boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (embedding_provider, embedding_model)
);

create table if not exists public.memory_semantic_work_queue (
  id uuid primary key default gen_random_uuid(),
  job_kind text not null default 'semantic_embedding',
  source_type text not null,
  source_key text not null,
  payload jsonb not null default '{}'::jsonb,
  payload_hash text not null default '',
  priority integer not null default 50,
  status text not null default 'queued' check (status in ('queued','running','done','failed','error')),
  due_at timestamptz not null default now(),
  attempts integer not null default 0,
  max_attempts integer not null default 3,
  locked_at timestamptz,
  locked_by text,
  last_error text,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_type, source_key)
);

do $$ declare c record; begin
  for c in select conname from pg_constraint where conrelid = 'public.memory_semantic_work_queue'::regclass and contype = 'c' loop
    execute format('alter table public.memory_semantic_work_queue drop constraint %I', c.conname);
  end loop;
end $$;
alter table public.memory_semantic_work_queue add constraint memory_semantic_work_queue_status_check check (status in ('queued','running','done','failed','error','skipped'));
alter table public.memory_semantic_work_queue add column if not exists priority integer not null default 50;
alter table public.memory_semantic_work_queue add column if not exists job_kind text not null default 'semantic_embedding';
alter table public.memory_semantic_work_queue add column if not exists payload_hash text not null default '';
update public.memory_semantic_work_queue set payload_hash=md5(payload::text) where payload_hash='';

create index if not exists idx_memory_semantic_work_queue_claim
  on public.memory_semantic_work_queue(status, priority desc, due_at, created_at)
  where status = 'queued';

insert into public.memory_embedding_model_slots
  (slot_key, embedding_provider, embedding_model, embedding_dim, endpoint, enabled, is_default, metadata)
values
  ('local-nomic-embed-text:latest', 'local', 'nomic-embed-text:latest', 768,
   'http://127.0.0.1:11434/api/embed', true, true,
   jsonb_build_object('setup', 'Install Ollama and pull the model before enabling workers', 'source', 'zorg-memorydb'))
on conflict (slot_key) do update set
  embedding_dim = excluded.embedding_dim,
  endpoint = coalesce(public.memory_embedding_model_slots.endpoint, excluded.endpoint),
  updated_at = now();

insert into public.memory_semantic_work_queue (job_kind, source_type, source_key, payload, payload_hash)
select 'semantic_embedding', 'zorg_memory', m.id::text, jsonb_build_object('table', 'zorg_memory'), md5(jsonb_build_object('table', 'zorg_memory')::text)
from public.zorg_memory m
where not exists (select 1 from public.memory_semantic_work_queue q where q.source_type='zorg_memory' and q.source_key=m.id::text);

insert into public.memory_semantic_work_queue (job_kind, source_type, source_key, payload, payload_hash)
select 'semantic_embedding', 'logic_rule', r.id::text, jsonb_build_object('table', 'zorg_logic_rules'), md5(jsonb_build_object('table', 'zorg_logic_rules')::text)
from public.zorg_logic_rules r
where r.active and not exists (select 1 from public.memory_semantic_work_queue q where q.source_type='logic_rule' and q.source_key=r.id::text);

insert into public.memory_semantic_work_queue (job_kind, source_type, source_key, payload, payload_hash)
select 'semantic_embedding', 'source_chunk', s.id::text, jsonb_build_object('table', 'memory_source_chunks'), md5(jsonb_build_object('table', 'memory_source_chunks')::text)
from public.memory_source_chunks s
where not exists (select 1 from public.memory_semantic_work_queue q where q.source_type='source_chunk' and q.source_key=s.id::text);

create or replace function public.memory_ann_enqueue_source_v1(
  p_source_type text, p_source_key text, p_payload jsonb default '{}'::jsonb
) returns uuid language plpgsql as $$
declare v_id uuid;
begin
  update public.memory_semantic_work_queue set payload=coalesce(p_payload,'{}'::jsonb), status=case when status='done' then 'queued' else status end, due_at=now(), updated_at=now()
  where job_kind='semantic_embedding' and source_type=p_source_type and source_key=p_source_key;
  if found then select id into v_id from public.memory_semantic_work_queue where job_kind='semantic_embedding' and source_type=p_source_type and source_key=p_source_key order by created_at desc limit 1; return v_id; end if;
  insert into public.memory_semantic_work_queue(job_kind, source_type, source_key, payload, payload_hash, status, due_at, updated_at)
  values ('semantic_embedding', p_source_type, p_source_key, coalesce(p_payload, '{}'::jsonb), md5(coalesce(p_payload, '{}'::jsonb)::text), 'queued', now(), now())
  returning id into v_id;
  return v_id;
end;
$$;

insert into public.memory_llm_scheduled_jobs
  (job_key, name, agent_id, schedule, cron_expr, timezone, enabled, session_target, wake_mode, payload, metadata)
values
  ('zorg-memory-ann-prefill', 'Zorg Memory ANN embedding prefill', 'main',
   jsonb_build_object('kind','interval','minutes',15), '*/15 * * * *', 'America/Los_Angeles', true, 'isolated', 'now',
   jsonb_build_object('kind','command','argv',jsonb_build_array('/home/openclaw/.openclaw/workspace/.venv-sqlmem/bin/python','/home/openclaw/.openclaw/workspace/skills/zorg-db-memory/scripts/memory_semantic_worker.py','--once','--limit','100'),'timeoutSeconds',900),
   jsonb_build_object('purpose','enqueue and embed new or changed source memory','job_class','core_llm','owner','core_llm')),
  ('zorg-memory-ann-maintenance', 'Zorg Memory ANN maintenance', 'main',
   jsonb_build_object('kind','daily','hour','03:20'), '20 3 * * *', 'America/Los_Angeles', true, 'isolated', 'now',
   jsonb_build_object('kind','command','argv',jsonb_build_array('/home/openclaw/.openclaw/workspace/.venv-sqlmem/bin/python','/home/openclaw/.openclaw/workspace/skills/zorg-db-memory/scripts/ann_vector_autoheal.py'),'timeoutSeconds',1800),
   jsonb_build_object('purpose','retry failed work and report embedding slot health','job_class','core_llm','owner','core_llm'))
on conflict (job_key) do update set
  name = excluded.name,
  schedule = excluded.schedule,
  cron_expr = excluded.cron_expr,
  payload = excluded.payload,
  enabled = true,
  source_scheduler = 'core-llm',
  metadata = excluded.metadata,
  updated_at = now();

create or replace view public.memory_ann_bootstrap_status_v1 as
select
  (select count(*) from public.memory_embedding_model_slots where enabled) as enabled_model_slots,
  (select count(*) from public.memory_ann_model_embeddings where active) as embedding_rows,
  (select count(*) from public.memory_query_embedding_cache where active) as query_cache_rows,
  (select count(*) from public.memory_semantic_work_queue where status = 'queued' and source_type in ('memory','zorg_memory','logic_rule','source_chunk')) as queued_source_rows,
  (select count(*) from public.memory_semantic_work_queue where status = 'failed' and source_type in ('memory','zorg_memory','logic_rule','source_chunk')) as failed_source_rows,
  (select count(*) from public.memory_llm_scheduled_jobs where enabled and job_key like 'zorg-memory-ann-%') as enabled_ann_jobs;

create or replace function public.memory_dynamic_worker_batch_limit(p_requested integer default 50)
returns integer language sql stable as $$
  select greatest(1, least(coalesce(p_requested, 50), 250));
$$;

create or replace function public.memory_dynamic_defer_interval(p_priority integer default 50)
returns interval language sql stable as $$
  select case when coalesce(p_priority, 50) >= 80 then interval '30 seconds' else interval '5 minutes' end;
$$;

create or replace function public.memory_ann_enqueue_due_sources_v1()
returns integer language plpgsql as $$
  declare v_count integer := 0; v_added integer;
begin
  insert into public.memory_semantic_work_queue(job_kind, source_type, source_key, payload, payload_hash)
  select 'semantic_embedding', 'zorg_memory', m.id::text, jsonb_build_object('table','zorg_memory'), md5(jsonb_build_object('table','zorg_memory')::text) from public.zorg_memory m
  where not exists (select 1 from public.memory_semantic_work_queue q where q.source_type='zorg_memory' and q.source_key=m.id::text);
  get diagnostics v_added = row_count;
  v_count := v_count + v_added;
  insert into public.memory_semantic_work_queue(job_kind, source_type, source_key, payload, payload_hash)
  select 'semantic_embedding', 'logic_rule', r.id::text, jsonb_build_object('table','zorg_logic_rules'), md5(jsonb_build_object('table','zorg_logic_rules')::text) from public.zorg_logic_rules r where r.active and not exists (select 1 from public.memory_semantic_work_queue q where q.source_type='logic_rule' and q.source_key=r.id::text);
  get diagnostics v_added = row_count;
  v_count := v_count + v_added;
  insert into public.memory_semantic_work_queue(job_kind, source_type, source_key, payload, payload_hash)
  select 'semantic_embedding', 'source_chunk', s.id::text, jsonb_build_object('table','memory_source_chunks'), md5(jsonb_build_object('table','memory_source_chunks')::text) from public.memory_source_chunks s where not exists (select 1 from public.memory_semantic_work_queue q where q.source_type='source_chunk' and q.source_key=s.id::text);
  get diagnostics v_added = row_count;
  v_count := v_count + v_added;
  return v_count;
end;
$$;
