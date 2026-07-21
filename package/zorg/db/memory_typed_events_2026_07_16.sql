-- Additive typed operational memory. Source occurrences are immutable in spirit:
-- exact repeats remain rows here; only derived ANN representations may collapse.

CREATE TABLE IF NOT EXISTS public.memory_model_outputs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), turn_id text, transaction_id uuid,
  output_kind text NOT NULL DEFAULT 'model_output', sequence_no integer,
  content text, content_hash text NOT NULL, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.memory_tool_calls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), turn_id text, transaction_id uuid,
  tool_name text NOT NULL, arguments jsonb NOT NULL DEFAULT '{}'::jsonb,
  arguments_hash text NOT NULL, status text, started_at timestamptz, finished_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.memory_tool_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tool_call_id uuid, turn_id text,
  result_kind text NOT NULL DEFAULT 'tool_result', result_text text, result_json jsonb,
  result_hash text NOT NULL, status text, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.memory_code_operations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), turn_id text, transaction_id uuid,
  operation_kind text NOT NULL, target_path text, patch_hash text, detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.memory_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), turn_id text, transaction_id uuid,
  decision_kind text NOT NULL, decision_text text NOT NULL, basis jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.memory_errors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), turn_id text, transaction_id uuid,
  error_kind text NOT NULL, error_text text NOT NULL, resolved boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.memory_corrections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), turn_id text, transaction_id uuid,
  correction_kind text NOT NULL, before_text text, after_text text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.memory_external_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), turn_id text, transaction_id uuid,
  action_kind text NOT NULL, target text, request jsonb NOT NULL DEFAULT '{}'::jsonb,
  outcome jsonb, status text, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.memory_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), turn_id text, transaction_id uuid,
  verification_kind text NOT NULL, subject_type text NOT NULL, subject_id uuid,
  passed boolean NOT NULL, evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.memory_event_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), transaction_id uuid,
  from_table text NOT NULL, from_id uuid NOT NULL, to_table text NOT NULL, to_id uuid NOT NULL,
  relation text NOT NULL, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(from_table,from_id,to_table,to_id,relation)
);
CREATE TABLE IF NOT EXISTS public.memory_ann_occurrence_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), source_table text NOT NULL, content_hash text NOT NULL,
  representative_id uuid NOT NULL, occurrence_count bigint NOT NULL DEFAULT 1,
  occurrence_ids uuid[] NOT NULL DEFAULT '{}', derived_weight double precision NOT NULL DEFAULT 1,
  first_seen_at timestamptz NOT NULL DEFAULT now(), last_seen_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(source_table, content_hash)
);
CREATE TABLE IF NOT EXISTS public.memory_ingestion_ledger (
  source_name text NOT NULL, source_event_hash text NOT NULL, event_kind text NOT NULL,
  typed_id uuid NOT NULL, ingested_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(source_name, source_event_hash)
);

CREATE TABLE IF NOT EXISTS public.memory_completion_checkpoints (
  job_key text PRIMARY KEY, root_path text NOT NULL, next_path text,
  files_total bigint NOT NULL DEFAULT 0, files_done bigint NOT NULL DEFAULT 0,
  events_seen bigint NOT NULL DEFAULT 0, events_inserted bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'running', last_error text, updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.memory_completion_checkpoint(
  p_job_key text,p_root text,p_next_path text,p_files_total bigint,p_files_done bigint,
  p_events_seen bigint,p_events_inserted bigint,p_status text,p_error text DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO public.memory_completion_checkpoints(job_key,root_path,next_path,files_total,files_done,events_seen,events_inserted,status,last_error,updated_at)
  VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,now())
  ON CONFLICT(job_key) DO UPDATE SET root_path=excluded.root_path,next_path=excluded.next_path,
    files_total=excluded.files_total,files_done=excluded.files_done,events_seen=excluded.events_seen,
    events_inserted=excluded.events_inserted,status=excluded.status,last_error=excluded.last_error,updated_at=now();
$$;

CREATE INDEX IF NOT EXISTS idx_memory_model_outputs_hash ON public.memory_model_outputs(content_hash);
CREATE INDEX IF NOT EXISTS idx_memory_tool_calls_hash ON public.memory_tool_calls(arguments_hash);
CREATE INDEX IF NOT EXISTS idx_memory_tool_results_hash ON public.memory_tool_results(result_hash);
CREATE INDEX IF NOT EXISTS idx_memory_event_links_from ON public.memory_event_links(from_table,from_id);
CREATE INDEX IF NOT EXISTS idx_memory_event_links_to ON public.memory_event_links(to_table,to_id);
CREATE INDEX IF NOT EXISTS idx_memory_ann_occurrence_groups_hash ON public.memory_ann_occurrence_groups(source_table,content_hash);

CREATE OR REPLACE FUNCTION public.memory_ann_occurrence_weight(p_count bigint, p_last_seen timestamptz)
RETURNS double precision LANGUAGE sql IMMUTABLE AS $$
  SELECT greatest(1.0, ln(greatest(1,p_count)::double precision + 1.0))
         * (1.0 / greatest(1.0, extract(epoch from (now() - p_last_seen))/86400.0 + 1.0));
$$;

COMMENT ON TABLE public.memory_ann_occurrence_groups IS 'Derived ANN-only exact-repeat groups; source rows and occurrence IDs are never discarded.';

DO $$ BEGIN
  IF to_regprocedure('public.memory_search_table_v1(text,text,integer)') IS NOT NULL
     AND to_regprocedure('public.memory_search_table_v1_legacy(text,text,integer)') IS NULL THEN
    ALTER FUNCTION public.memory_search_table_v1(text,text,integer) RENAME TO memory_search_table_v1_legacy;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.memory_tables_v1()
RETURNS TABLE(table_name text) LANGUAGE sql STABLE AS $$
  values ('md_agents'::text),('md_heartbeat'::text),('md_identity'::text),
    ('md_soul'::text),('md_tools'::text),('md_user'::text),('zorg_memory'::text),
    ('memory_model_outputs'::text),('memory_tool_calls'::text),('memory_tool_results'::text),
    ('memory_code_operations'::text),('memory_decisions'::text),('memory_errors'::text),
    ('memory_corrections'::text),('memory_external_actions'::text),('memory_verifications'::text),
    ('memory_event_links'::text),('memory_ann_occurrence_groups'::text),
    ('all'::text),('ann'::text),('project'::text),('host'::text),('runbook'::text)
$$;

CREATE OR REPLACE FUNCTION public.memory_search_table_v1(p_table text, p_query text, p_limit integer DEFAULT 10)
RETURNS TABLE(row_data jsonb) LANGUAGE plpgsql AS $$
DECLARE v_table text := lower(coalesce(p_table,'')); v_limit integer := greatest(coalesce(p_limit,10),1);
BEGIN
  IF v_table IN ('all','ann','project','host','runbook','zorg_memory','md_agents','md_heartbeat','md_identity','md_soul','md_tools','md_user') THEN
    RETURN QUERY SELECT to_jsonb(r) FROM public.memory_search_table_v1_legacy(v_table,p_query,v_limit) r; RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name=v_table) AND v_table LIKE 'memory_%' THEN
    RETURN QUERY EXECUTE format('SELECT to_jsonb(x) FROM public.%I x WHERE x::text ILIKE %L LIMIT %s', v_table, '%'||coalesce(p_query,'')||'%', v_limit);
    RETURN;
  END IF;
  RAISE EXCEPTION 'Unsupported MemoryDB search table: %', p_table;
END $$;

CREATE OR REPLACE FUNCTION public.memory_record_typed_event(
  p_kind text, p_turn_id text, p_transaction_id uuid, p_payload jsonb)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid := gen_random_uuid(); v_kind text := lower(p_kind);
BEGIN
  IF v_kind='model_output' THEN INSERT INTO public.memory_model_outputs(id,turn_id,transaction_id,content,content_hash,metadata) VALUES(v_id,p_turn_id,p_transaction_id,p_payload->>'content',coalesce(p_payload->>'content_hash',md5(coalesce(p_payload->>'content',''))),coalesce(p_payload->'metadata','{}')); 
  ELSIF v_kind='tool_call' THEN INSERT INTO public.memory_tool_calls(id,turn_id,transaction_id,tool_name,arguments,arguments_hash,status,metadata) VALUES(v_id,p_turn_id,p_transaction_id,coalesce(p_payload->>'tool_name','unknown'),coalesce(p_payload->'arguments','{}'),coalesce(p_payload->>'arguments_hash',md5(coalesce(p_payload->'arguments','{}')::text)),p_payload->>'status',coalesce(p_payload->'metadata','{}'));
  ELSIF v_kind='tool_result' THEN INSERT INTO public.memory_tool_results(id,turn_id,result_kind,result_text,result_json,result_hash,status) VALUES(v_id,p_turn_id,coalesce(p_payload->>'result_kind','tool_result'),p_payload->>'result_text',p_payload->'result_json',coalesce(p_payload->>'result_hash',md5(coalesce(p_payload->>'result_text',(p_payload->'result_json')::text,''))),p_payload->>'status');
  ELSIF v_kind='code_operation' THEN INSERT INTO public.memory_code_operations(id,turn_id,transaction_id,operation_kind,target_path,patch_hash,detail) VALUES(v_id,p_turn_id,p_transaction_id,coalesce(p_payload->>'operation_kind','operation'),p_payload->>'target_path',p_payload->>'patch_hash',coalesce(p_payload->'detail','{}'));
  ELSIF v_kind='decision' THEN INSERT INTO public.memory_decisions(id,turn_id,transaction_id,decision_kind,decision_text,basis) VALUES(v_id,p_turn_id,p_transaction_id,coalesce(p_payload->>'decision_kind','decision'),coalesce(p_payload->>'decision_text',''),coalesce(p_payload->'basis','{}'));
  ELSIF v_kind='error' THEN INSERT INTO public.memory_errors(id,turn_id,transaction_id,error_kind,error_text,metadata) VALUES(v_id,p_turn_id,p_transaction_id,coalesce(p_payload->>'error_kind','error'),coalesce(p_payload->>'error_text',''),coalesce(p_payload->'metadata','{}'));
  ELSIF v_kind='correction' THEN INSERT INTO public.memory_corrections(id,turn_id,transaction_id,correction_kind,before_text,after_text,metadata) VALUES(v_id,p_turn_id,p_transaction_id,coalesce(p_payload->>'correction_kind','correction'),p_payload->>'before_text',coalesce(p_payload->>'after_text',''),coalesce(p_payload->'metadata','{}'));
  ELSIF v_kind='external_action' THEN INSERT INTO public.memory_external_actions(id,turn_id,transaction_id,action_kind,target,request,outcome,status) VALUES(v_id,p_turn_id,p_transaction_id,coalesce(p_payload->>'action_kind','action'),p_payload->>'target',coalesce(p_payload->'request','{}'),p_payload->'outcome',p_payload->>'status');
  ELSIF v_kind='verification' THEN INSERT INTO public.memory_verifications(id,turn_id,transaction_id,verification_kind,subject_type,subject_id,passed,evidence) VALUES(v_id,p_turn_id,p_transaction_id,coalesce(p_payload->>'verification_kind','verification'),coalesce(p_payload->>'subject_type','event'),nullif(p_payload->>'subject_id','')::uuid,coalesce((p_payload->>'passed')::boolean,false),coalesce(p_payload->'evidence','{}'));
  ELSE RAISE EXCEPTION 'unsupported typed event kind: %',p_kind;
  END IF; RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.memory_ann_refresh_occurrence_groups()
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE n bigint;
BEGIN
  INSERT INTO public.memory_ann_occurrence_groups(source_table,content_hash,representative_id,occurrence_count,occurrence_ids,derived_weight,first_seen_at,last_seen_at)
  SELECT source_type,content_hash,(array_agg(id order by created_at,id))[1],count(*),array_agg(id),greatest(1.0,ln(count(*)::double precision+1.0)),min(coalesce(event_ts,created_at)),max(coalesce(event_ts,created_at))
  FROM public.memory_ann_model_embeddings WHERE active GROUP BY source_type,content_hash
  ON CONFLICT(source_table,content_hash) DO UPDATE SET representative_id=excluded.representative_id,occurrence_count=excluded.occurrence_count,occurrence_ids=excluded.occurrence_ids,derived_weight=excluded.derived_weight,first_seen_at=excluded.first_seen_at,last_seen_at=excluded.last_seen_at,updated_at=now();
  GET DIAGNOSTICS n = ROW_COUNT; RETURN n;
END $$;
