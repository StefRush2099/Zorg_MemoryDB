begin;

create table if not exists public.memory_cognitive_working_set (
  activation_key text primary key,
  source_type text not null,
  source_key text not null,
  goal_context text,
  activation numeric(12,6) not null default 0 check (activation >= 0),
  salience numeric(12,6) not null default 0 check (salience >= 0),
  rehearsal_count bigint not null default 0,
  first_activated_at timestamptz not null default now(),
  last_activated_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists idx_memory_cognitive_working_expiry
  on public.memory_cognitive_working_set(expires_at);
create index if not exists idx_memory_cognitive_working_goal
  on public.memory_cognitive_working_set using gin (goal_context gin_trgm_ops);

create table if not exists public.memory_cognitive_episodes (
  id uuid primary key default gen_random_uuid(),
  source_table text not null,
  source_id text not null,
  episode_kind text not null,
  summary text not null,
  occurred_at timestamptz not null,
  importance numeric(8,6) not null default 0.5 check (importance between 0 and 1),
  outcome_score numeric(8,6) check (outcome_score between -1 and 1),
  confidence numeric(8,6) not null default 1 check (confidence between 0 and 1),
  consolidated boolean not null default false,
  consolidated_at timestamptz,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(source_table, source_id)
);
create index if not exists idx_memory_cognitive_episodes_time
  on public.memory_cognitive_episodes(occurred_at desc);
create index if not exists idx_memory_cognitive_episodes_pending
  on public.memory_cognitive_episodes(consolidated, occurred_at)
  where not consolidated;

create table if not exists public.memory_cognitive_beliefs (
  id uuid primary key default gen_random_uuid(),
  belief_key text not null,
  proposition text not null,
  belief_status text not null default 'current'
    check (belief_status in ('candidate','current','disputed','superseded','retracted')),
  confidence numeric(8,6) not null default 0.5 check (confidence between 0 and 1),
  source_quality numeric(8,6) not null default 0.5 check (source_quality between 0 and 1),
  evidence_count bigint not null default 1,
  contradiction_group text,
  supersedes_id uuid references public.memory_cognitive_beliefs(id),
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists uq_memory_cognitive_current_belief
  on public.memory_cognitive_beliefs(belief_key)
  where belief_status='current' and valid_to is null;
create index if not exists idx_memory_cognitive_beliefs_text
  on public.memory_cognitive_beliefs using gin (proposition gin_trgm_ops);
create index if not exists idx_memory_cognitive_beliefs_group
  on public.memory_cognitive_beliefs(contradiction_group, belief_status);

create table if not exists public.memory_cognitive_procedures (
  id uuid primary key default gen_random_uuid(),
  procedure_key text not null unique,
  trigger_text text not null,
  steps jsonb not null default '[]'::jsonb,
  success_count bigint not null default 0,
  failure_count bigint not null default 0,
  confidence numeric(8,6) not null default 0.5 check (confidence between 0 and 1),
  last_outcome_at timestamptz,
  provenance jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_memory_cognitive_procedures_trigger
  on public.memory_cognitive_procedures using gin (trigger_text gin_trgm_ops);

create table if not exists public.memory_cognitive_intentions (
  id uuid primary key default gen_random_uuid(),
  intention_key text not null unique,
  goal_text text not null,
  trigger_context jsonb not null default '{}'::jsonb,
  status text not null default 'pending'
    check (status in ('pending','active','completed','cancelled','blocked')),
  priority integer not null default 50 check (priority between 0 and 100),
  due_at timestamptz,
  last_triggered_at timestamptz,
  trigger_count bigint not null default 0,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_memory_cognitive_intentions_due
  on public.memory_cognitive_intentions(status, due_at, priority desc);
create index if not exists idx_memory_cognitive_intentions_context
  on public.memory_cognitive_intentions using gin (trigger_context);

create table if not exists public.memory_cognitive_consolidation_runs (
  id uuid primary key default gen_random_uuid(),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  episode_count integer not null default 0,
  belief_count integer not null default 0,
  procedure_count integer not null default 0,
  intention_count integer not null default 0,
  activation_count integer not null default 0,
  status text not null default 'running',
  evidence jsonb not null default '{}'::jsonb,
  rollback jsonb not null default jsonb_build_object(
    'derived_only', true,
    'instruction', 'drop cognitive views/functions/tables only; preserve all source MemoryDB rows'
  )
);

create or replace function public.memory_cognitive_spreading_activation_v1(
  p_seed_keys text[],
  p_goal text default null,
  p_max_depth integer default 3,
  p_damping numeric default 0.62,
  p_limit integer default 30
) returns table(
  node_key text,
  canonical_label text,
  depth integer,
  activation numeric,
  activation_path text[]
) language sql stable as $$
with recursive walk(node_key, depth, activation, activation_path) as (
  select n.node_key, 0, 1::numeric, array[n.node_key]
  from public.memory_semantic_nodes n
  where n.active and (
    n.node_key = any(coalesce(p_seed_keys,'{}'::text[]))
    or n.canonical_label = any(coalesce(p_seed_keys,'{}'::text[]))
  )
  union all
  select
    case when e.subject_key=w.node_key then e.object_key else e.subject_key end,
    w.depth+1,
    (w.activation * least(greatest(e.weight,0),5) * least(greatest(p_damping,0.05),0.95))::numeric,
    w.activation_path || case when e.subject_key=w.node_key then e.object_key else e.subject_key end
  from walk w
  join public.memory_semantic_edges e on e.active
    and (e.subject_key=w.node_key or e.object_key=w.node_key)
  where w.depth < least(greatest(p_max_depth,1),5)
    and not (case when e.subject_key=w.node_key then e.object_key else e.subject_key end = any(w.activation_path))
), scored as (
  select distinct on (w.node_key)
         w.node_key,w.depth,w.activation,w.activation_path
  from walk w
  order by w.node_key,w.activation desc,w.depth,w.activation_path
)
select s.node_key,n.canonical_label,s.depth,
  (s.activation * case when nullif(btrim(coalesce(p_goal,'')),'') is not null
    and (n.canonical_label % p_goal or coalesce(n.description,'') % p_goal)
    then 1.25 else 1 end)::numeric as activation,
  s.activation_path
from scored s join public.memory_semantic_nodes n on n.node_key=s.node_key and n.active
order by activation desc,depth,node_key
limit greatest(p_limit,1)
$$;

create or replace function public.memory_cognitive_current_beliefs_v1(
  p_query text default '',
  p_limit integer default 20
) returns table(
  belief_key text, proposition text, confidence numeric,
  source_quality numeric, evidence_count bigint, valid_from timestamptz,
  contradiction_group text, provenance jsonb
) language sql stable as $$
select b.belief_key,b.proposition,b.confidence,b.source_quality,b.evidence_count,
       b.valid_from,b.contradiction_group,b.provenance
from public.memory_cognitive_beliefs b
where b.belief_status='current' and b.valid_to is null
  and (nullif(btrim(coalesce(p_query,'')),'') is null
       or b.proposition % p_query
       or to_tsvector('english',b.proposition) @@ websearch_to_tsquery('english',p_query))
order by
  case when nullif(btrim(coalesce(p_query,'')),'') is null then 0
       else similarity(b.proposition,p_query) end desc,
  (b.confidence*b.source_quality) desc,b.valid_from desc
limit greatest(p_limit,1)
$$;

create or replace function public.memory_cognitive_due_intentions_v1(
  p_context jsonb default '{}'::jsonb,
  p_now timestamptz default now(),
  p_limit integer default 20
) returns table(
  id uuid,intention_key text,goal_text text,priority integer,due_at timestamptz,
  trigger_context jsonb,trigger_reason text
) language sql stable as $$
select i.id,i.intention_key,i.goal_text,i.priority,i.due_at,i.trigger_context,
  concat_ws(',',
    case when i.due_at is not null and i.due_at<=p_now then 'due' end,
    case when i.trigger_context='{}'::jsonb or p_context @> i.trigger_context then 'context' end)
from public.memory_cognitive_intentions i
where i.status in ('pending','active')
  and ((i.due_at is not null and i.due_at<=p_now)
       or i.trigger_context='{}'::jsonb
       or p_context @> i.trigger_context)
order by i.priority desc,i.due_at nulls last,i.created_at
limit greatest(p_limit,1)
$$;

create or replace function public.memory_cognitive_recall_v1(
  p_query text,
  p_limit integer default 12,
  p_context jsonb default '{}'::jsonb
) returns table(
  source_type text,source_id text,path text,line_start integer,line_end integer,
  priority text,content text,recall_mode text,rank integer,score numeric,
  score_reason text,metadata jsonb
) language sql as $$
with base as (
  select * from public.memory_recall_v2(
    p_query,
    greatest(p_limit,8),
    coalesce(p_context,'{}'::jsonb)||jsonb_build_object('mode','deep')
  )
), seeds as (
  select n.node_key
  from public.memory_semantic_nodes n
  where n.active and (
    n.canonical_label % p_query
    or p_query = any(n.aliases)
    or coalesce(n.description,'') % p_query
  )
  order by greatest(similarity(n.canonical_label,p_query),similarity(coalesce(n.description,''),p_query)) desc
  limit 5
), activated as (
  select a.*,row_number() over(order by a.activation desc,a.depth,a.node_key) rn
  from public.memory_cognitive_spreading_activation_v1(
    array(select node_key from seeds),
    p_context->>'goal',3,0.62,greatest(p_limit,12)
  ) a
), combined as (
  select b.source_type,b.source_id,b.path,b.line_start,b.line_end,b.priority,
         b.content,b.recall_mode,b.rank,b.score,b.score_reason,b.metadata,0 layer
  from base b
  union all
  select 'semantic_node',n.id::text,null,null,null,'medium',
         concat_ws(E'\n',n.canonical_label,n.description,n.llm_hint),
         'cognitive-spreading-activation',100+a.rn,
         a.activation,'bounded damped semantic graph activation',
         n.metadata||jsonb_build_object('node_key',a.node_key,'depth',a.depth,'activation_path',a.activation_path),1
  from activated a join public.memory_semantic_nodes n on n.node_key=a.node_key
  where not exists(select 1 from base b where b.source_type='semantic_node' and b.source_id=n.id::text)
), ranked as (
  select c.*,row_number() over(order by layer,c.rank,score desc)::integer out_rank
  from combined c
)
select source_type,source_id,path,line_start,line_end,priority,content,recall_mode,
       out_rank,score,score_reason,metadata
from ranked order by out_rank limit greatest(p_limit,1)
$$;

commit;
