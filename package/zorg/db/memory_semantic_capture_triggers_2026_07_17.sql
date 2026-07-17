-- Public-safe trigger wiring for the additive semantic/ANN capture path.
-- Source rows remain complete; only derived queue work is coalesced.

CREATE OR REPLACE FUNCTION public.memory_queue_semantic_capture_v1()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_source_key text;
  v_payload jsonb := '{}'::jsonb;
BEGIN
  v_source_key := COALESCE(to_jsonb(NEW)->>'id', md5(to_jsonb(NEW)::text));
  v_payload := jsonb_build_object(
    'table', TG_TABLE_NAME,
    'operation', TG_OP,
    'source_key', v_source_key,
    'row', to_jsonb(NEW)
  );

  IF to_regprocedure('public.memory_ann_enqueue_source_v1(text,text,jsonb)') IS NOT NULL THEN
    PERFORM public.memory_ann_enqueue_source_v1(
      'capture:' || TG_TABLE_NAME,
      v_source_key,
      v_payload
    );
  END IF;

  IF to_regprocedure('public.memory_enqueue_semantic_job(text,text,jsonb)') IS NOT NULL THEN
    PERFORM public.memory_enqueue_semantic_job(
      'capture:' || TG_TABLE_NAME,
      v_source_key,
      v_payload
    );
  END IF;

  RETURN NEW;
END;
$$;

DO $$
DECLARE
  v_table text;
  v_trigger text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'memory_event_occurrences', 'memory_model_outputs', 'memory_tool_calls',
    'memory_tool_results', 'memory_code_operations', 'memory_decisions',
    'memory_errors', 'memory_corrections', 'memory_external_actions',
    'memory_verifications', 'memory_event_links'
  ] LOOP
    IF to_regclass('public.' || v_table) IS NOT NULL THEN
      v_trigger := 'zorg_semantic_capture_' || v_table;
      EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', v_trigger, v_table);
      EXECUTE format(
        'CREATE TRIGGER %I AFTER INSERT OR UPDATE ON public.%I '
        'FOR EACH ROW EXECUTE FUNCTION public.memory_queue_semantic_capture_v1()',
        v_trigger, v_table
      );
    END IF;
  END LOOP;
END
$$;

COMMENT ON FUNCTION public.memory_queue_semantic_capture_v1() IS
  'Lightweight trigger bridge from complete captured source rows to additive semantic/ANN queue work.';

CREATE OR REPLACE VIEW public.memory_semantic_capture_trigger_status_v1 AS
SELECT
  c.relname AS table_name,
  EXISTS (
    SELECT 1 FROM pg_trigger t
    WHERE t.tgrelid = c.oid
      AND NOT t.tgisinternal
      AND t.tgname = 'zorg_semantic_capture_' || c.relname
  ) AS trigger_enabled
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = ANY (ARRAY[
    'memory_event_occurrences', 'memory_model_outputs', 'memory_tool_calls',
    'memory_tool_results', 'memory_code_operations', 'memory_decisions',
    'memory_errors', 'memory_corrections', 'memory_external_actions',
    'memory_verifications', 'memory_event_links'
  ]);
