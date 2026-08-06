\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.memory_db_scheduled_jobs (
  job_key text PRIMARY KEY,
  job_kind text NOT NULL,
  schedule_kind text NOT NULL DEFAULT 'interval',
  interval_seconds integer,
  daily_time time,
  timezone text NOT NULL DEFAULT 'America/Los_Angeles',
  enabled boolean NOT NULL DEFAULT true,
  next_due_at timestamptz NOT NULL,
  last_started_at timestamptz,
  last_finished_at timestamptz,
  last_status text,
  last_error text,
  run_count bigint NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((schedule_kind='interval' AND interval_seconds IS NOT NULL)
      OR (schedule_kind='daily' AND daily_time IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_memory_db_scheduled_jobs_due
  ON public.memory_db_scheduled_jobs(enabled, next_due_at) WHERE enabled;

CREATE TABLE IF NOT EXISTS public.memory_db_scheduled_job_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_key text NOT NULL REFERENCES public.memory_db_scheduled_jobs(job_key) ON DELETE CASCADE,
  claimed_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  status text NOT NULL DEFAULT 'claimed',
  worker_id text,
  result jsonb NOT NULL DEFAULT '{}'::jsonb,
  error text
);

CREATE INDEX IF NOT EXISTS idx_memory_db_scheduled_job_runs_job_time
  ON public.memory_db_scheduled_job_runs(job_key, claimed_at DESC);

CREATE OR REPLACE FUNCTION public.memory_db_schedule_next_due(
  p_schedule_kind text, p_interval_seconds integer, p_daily_time time,
  p_timezone text, p_from timestamptz DEFAULT now()
) RETURNS timestamptz LANGUAGE plpgsql STABLE AS $$
DECLARE v_local_now timestamp; v_candidate_local timestamp;
BEGIN
  IF p_schedule_kind='interval' THEN
    RETURN p_from + make_interval(secs => greatest(coalesce(p_interval_seconds,900),1));
  ELSIF p_schedule_kind='daily' THEN
    v_local_now := p_from AT TIME ZONE coalesce(p_timezone,'America/Los_Angeles');
    v_candidate_local := date_trunc('day',v_local_now)+coalesce(p_daily_time,time '03:20');
    IF v_candidate_local <= v_local_now THEN v_candidate_local := v_candidate_local+interval '1 day'; END IF;
    RETURN v_candidate_local AT TIME ZONE coalesce(p_timezone,'America/Los_Angeles');
  END IF;
  RAISE EXCEPTION 'unknown schedule_kind %',p_schedule_kind;
END $$;

CREATE OR REPLACE FUNCTION public.memory_db_claim_due_jobs(p_worker_id text,p_limit integer DEFAULT 10)
RETURNS TABLE(job_key text,job_kind text,run_id uuid,metadata jsonb) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY WITH picked AS (
    SELECT j.job_key FROM public.memory_db_scheduled_jobs j
    WHERE j.enabled AND j.next_due_at<=now() ORDER BY j.next_due_at,j.job_key
    FOR UPDATE SKIP LOCKED LIMIT greatest(1,coalesce(p_limit,10))
  ), ins AS (
    INSERT INTO public.memory_db_scheduled_job_runs(job_key,worker_id,status)
    SELECT p.job_key,p_worker_id,'claimed' FROM picked p RETURNING id,memory_db_scheduled_job_runs.job_key
  ), upd AS (
    UPDATE public.memory_db_scheduled_jobs j SET last_started_at=now(),
      next_due_at=public.memory_db_schedule_next_due(j.schedule_kind,j.interval_seconds,j.daily_time,j.timezone,now()),updated_at=now()
    FROM ins WHERE j.job_key=ins.job_key RETURNING j.job_key,j.job_kind,ins.id,j.metadata
  ) SELECT upd.job_key,upd.job_kind,upd.id,upd.metadata FROM upd;
END $$;

CREATE OR REPLACE FUNCTION public.memory_db_semantic_worker_batch_sql(p_limit integer DEFAULT 25)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v_started timestamptz:=clock_timestamp(); v_limit integer; v_claimed integer:=0; v_inserted integer:=0; v_completed integer:=0; v_backlog integer:=0;
BEGIN
  SELECT public.memory_dynamic_worker_batch_limit(coalesce(p_limit,25)) INTO v_limit;
  CREATE TEMP TABLE IF NOT EXISTS pg_temp.memory_db_semantic_claimed_jobs(id uuid PRIMARY KEY,source_type text,source_key text,priority integer,payload jsonb) ON COMMIT DROP;
  TRUNCATE pg_temp.memory_db_semantic_claimed_jobs;
  INSERT INTO pg_temp.memory_db_semantic_claimed_jobs SELECT q.id,q.source_type,q.source_key,q.priority,q.payload
    FROM public.memory_semantic_work_queue q WHERE q.status='queued' AND q.due_at<=now() AND q.attempts<q.max_attempts
    ORDER BY q.priority DESC,q.due_at,q.created_at FOR UPDATE SKIP LOCKED LIMIT greatest(1,coalesce(v_limit,1));
  GET DIAGNOSTICS v_claimed=ROW_COUNT;
  UPDATE public.memory_semantic_work_queue q SET status='running',locked_at=now(),locked_by='db-plpgsql-semantic-worker',attempts=attempts+1,updated_at=now()
    FROM pg_temp.memory_db_semantic_claimed_jobs c WHERE q.id=c.id;
  WITH source_text AS MATERIALIZED (
    SELECT c.*,coalesce(nullif(c.payload->>'query_text',''),nullif(c.payload->>'intent',''),nullif(c.payload->>'memory_key',''),nullif(c.payload->>'category',''),z.content,c.payload::text) cue_text
    FROM pg_temp.memory_db_semantic_claimed_jobs c LEFT JOIN public.zorg_memory_search_mv z ON z.source_table=c.source_type AND z.source_id=c.source_key
  ), ins AS (
    INSERT INTO public.memory_recall_hints(source_type,source_key,hint_kind,hint_text,related_keys,weight,source_model,metadata)
    SELECT s.source_type,s.source_key,'db_plpgsql_semantic_worker_v1','DB semantic recall cue: '||left(regexp_replace(coalesce(s.cue_text,''),E'\\s+',' ','g'),400),array[]::text[],greatest(1.0,least(9.0,coalesce(s.priority,1)::numeric/10.0)),'db-plpgsql-semantic-worker-v1',jsonb_build_object('queue_job_id',s.id,'original_priority',s.priority,'executor','postgresql-function','function','public.memory_db_semantic_worker_batch_sql')
    FROM source_text s WHERE NOT EXISTS (SELECT 1 FROM public.memory_recall_hints h WHERE h.source_type=s.source_type AND h.source_key=s.source_key AND h.hint_kind='db_plpgsql_semantic_worker_v1' AND h.active) RETURNING 1
  ) SELECT count(*) INTO v_inserted FROM ins;
  UPDATE public.memory_semantic_work_queue q SET status='done',completed_at=now(),locked_at=null,locked_by=null,updated_at=now(),payload=q.payload||jsonb_build_object('worker_stats',jsonb_build_object('db_executed',true,'function','public.memory_db_semantic_worker_batch_sql','hint_kind','db_plpgsql_semantic_worker_v1')) FROM pg_temp.memory_db_semantic_claimed_jobs c WHERE q.id=c.id;
  GET DIAGNOSTICS v_completed=ROW_COUNT;
  SELECT count(*)::int INTO v_backlog FROM public.memory_semantic_work_queue WHERE status IN ('queued','running');
  PERFORM public.memory_record_runtime_timing('semantic_worker_batch_db_sql','public.memory_db_semantic_worker_batch_sql',extract(epoch FROM(clock_timestamp()-v_started))*1000,null,v_completed,v_backlog,jsonb_build_object('claimed',v_claimed,'hints_inserted',v_inserted,'limit',v_limit));
  RETURN jsonb_build_object('function','public.memory_db_semantic_worker_batch_sql','claimed',v_claimed,'hints_inserted',v_inserted,'processed',v_completed,'backlog',v_backlog,'duration_ms',round((extract(epoch FROM(clock_timestamp()-v_started))*1000)::numeric,3));
END $$;

CREATE OR REPLACE FUNCTION public.memory_db_health_check_sql() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v_started timestamptz:=clock_timestamp(); v_requeued integer:=0; v_enqueued integer:=0; v_bulk jsonb:='{}';
BEGIN
  UPDATE public.memory_semantic_work_queue SET status='queued',attempts=0,due_at=now(),locked_at=null,locked_by=null,last_error=null,updated_at=now() WHERE status IN ('failed','error');
  GET DIAGNOSTICS v_requeued=ROW_COUNT;
  IF to_regprocedure('public.memory_ann_enqueue_due_sources_v1()') IS NOT NULL THEN SELECT public.memory_ann_enqueue_due_sources_v1() INTO v_enqueued; END IF;
  IF EXISTS(SELECT 1 FROM public.memory_semantic_work_queue WHERE status='queued' AND due_at<=now()) THEN v_bulk:=public.memory_db_semantic_worker_batch_sql(25); END IF;
  RETURN jsonb_build_object('function','public.memory_db_health_check_sql','failed_jobs_requeued',v_requeued,'ann_sources_enqueued',v_enqueued,'semantic_worker_batch',v_bulk,'duration_ms',round((extract(epoch FROM(clock_timestamp()-v_started))*1000)::numeric,3));
END $$;

CREATE OR REPLACE FUNCTION public.memory_db_execute_job_sql(p_job_kind text) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
  IF p_job_kind='memory_semantic_worker' THEN RETURN public.memory_db_semantic_worker_batch_sql(25);
  ELSIF p_job_kind='memory_nightly_health_check' THEN RETURN public.memory_db_health_check_sql(); END IF;
  RAISE EXCEPTION 'unknown DB job kind %',p_job_kind;
END $$;

CREATE OR REPLACE FUNCTION public.memory_db_finish_job(p_run_id uuid,p_status text,p_result jsonb DEFAULT '{}',p_error text DEFAULT null) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_job_key text;
BEGIN
  UPDATE public.memory_db_scheduled_job_runs SET finished_at=now(),status=p_status,result=coalesce(p_result,'{}'),error=p_error WHERE id=p_run_id RETURNING job_key INTO v_job_key;
  IF v_job_key IS NOT NULL THEN UPDATE public.memory_db_scheduled_jobs SET last_finished_at=now(),last_status=p_status,last_error=p_error,run_count=run_count+1,updated_at=now() WHERE job_key=v_job_key; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.memory_db_run_due_jobs_sql(p_limit integer DEFAULT 5) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v_job record; v_result jsonb; v_jobs jsonb:='[]'; v_claimed integer:=0;
BEGIN
  FOR v_job IN SELECT * FROM public.memory_db_claim_due_jobs('postgresql-internal-runner',p_limit) LOOP
    v_claimed:=v_claimed+1;
    BEGIN v_result:=public.memory_db_execute_job_sql(v_job.job_kind); PERFORM public.memory_db_finish_job(v_job.run_id,'ok',v_result,null); v_jobs:=v_jobs||jsonb_build_array(jsonb_build_object('job_key',v_job.job_key,'job_kind',v_job.job_kind,'status','ok','result',v_result));
    EXCEPTION WHEN OTHERS THEN PERFORM public.memory_db_finish_job(v_job.run_id,'error','{}',SQLERRM); v_jobs:=v_jobs||jsonb_build_array(jsonb_build_object('job_key',v_job.job_key,'job_kind',v_job.job_kind,'status','error','error',SQLERRM)); END;
  END LOOP;
  RETURN jsonb_build_object('function','public.memory_db_run_due_jobs_sql','claimed',v_claimed,'jobs',v_jobs);
END $$;

CREATE OR REPLACE FUNCTION public.memory_db_wake_semantic_job_trigger() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('lock_timeout','50ms',true);
  UPDATE public.memory_db_scheduled_jobs SET next_due_at=least(next_due_at,now()),updated_at=now()
  WHERE job_key='memory-semantic-worker-15m' AND enabled
    AND EXISTS(SELECT 1 FROM public.memory_semantic_work_queue WHERE status='queued' AND due_at<=now() LIMIT 1);
  RETURN coalesce(new,old);
EXCEPTION WHEN lock_not_available OR query_canceled THEN RETURN coalesce(new,old);
END $$;

INSERT INTO public.memory_db_scheduled_jobs(job_key,job_kind,schedule_kind,interval_seconds,timezone,next_due_at,metadata)
VALUES ('memory-semantic-worker-15m','memory_semantic_worker','interval',900,'America/Los_Angeles',now(),jsonb_build_object('owner','database','executor','postgresql-function','db_function','public.memory_db_semantic_worker_batch_sql(integer)'))
ON CONFLICT(job_key) DO UPDATE SET job_kind=excluded.job_kind,schedule_kind=excluded.schedule_kind,interval_seconds=excluded.interval_seconds,timezone=excluded.timezone,enabled=true,metadata=memory_db_scheduled_jobs.metadata||excluded.metadata,updated_at=now();

INSERT INTO public.memory_db_scheduled_jobs(job_key,job_kind,schedule_kind,daily_time,timezone,next_due_at,metadata)
VALUES ('memory-nightly-health-0320','memory_nightly_health_check','daily',time '03:20','America/Los_Angeles',public.memory_db_schedule_next_due('daily',null,time '03:20','America/Los_Angeles',now()),jsonb_build_object('owner','database','executor','postgresql-function','db_function','public.memory_db_health_check_sql()'))
ON CONFLICT(job_key) DO UPDATE SET job_kind=excluded.job_kind,schedule_kind=excluded.schedule_kind,daily_time=excluded.daily_time,timezone=excluded.timezone,enabled=true,metadata=memory_db_scheduled_jobs.metadata||excluded.metadata,updated_at=now();

DO $$ BEGIN
  IF to_regclass('public.memory_semantic_work_queue') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_memory_db_wake_semantic_job ON public.memory_semantic_work_queue;
    CREATE TRIGGER trg_memory_db_wake_semantic_job AFTER INSERT OR UPDATE OF status,due_at ON public.memory_semantic_work_queue FOR EACH STATEMENT EXECUTE FUNCTION public.memory_db_wake_semantic_job_trigger();
  END IF;
END $$;
