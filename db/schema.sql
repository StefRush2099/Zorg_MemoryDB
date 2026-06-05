-- Zorg MemoryDB schema for OpenClaw database memory.
-- Structure-first database layer for durable recall, indexed search, and operational context.

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;

-- Sequences used by integer id columns.
CREATE SEQUENCE IF NOT EXISTS public.t1_id_seq;
CREATE SEQUENCE IF NOT EXISTS public.zorg_rules_id_seq;
CREATE SEQUENCE IF NOT EXISTS public.app_write_events_id_seq;
CREATE SEQUENCE IF NOT EXISTS public.app_activity_events_id_seq;
CREATE SEQUENCE IF NOT EXISTS public.app_query_log_id_seq;
CREATE SEQUENCE IF NOT EXISTS public.app_query_rate_events_id_seq;


CREATE TABLE IF NOT EXISTS public."app_activity_events" (
  "id" bigint DEFAULT nextval('app_activity_events_id_seq'::regclass) NOT NULL,
  "activity_key" text NOT NULL,
  "activity_type" text NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."app_query_log" (
  "id" bigint DEFAULT nextval('app_query_log_id_seq'::regclass) NOT NULL,
  "logged_at" timestamptz DEFAULT now() NOT NULL,
  "query_label" text,
  "query_text" text NOT NULL,
  "params_json" jsonb,
  "row_count" integer,
  "result_preview" jsonb
);

CREATE TABLE IF NOT EXISTS public."app_query_rate_events" (
  "id" bigint DEFAULT nextval('app_query_rate_events_id_seq'::regclass) NOT NULL,
  "logged_at" timestamptz DEFAULT now() NOT NULL,
  "query_label" text,
  "source" text,
  "query_text" text
);

CREATE TABLE IF NOT EXISTS public."app_write_counters" (
  "counter_key" text NOT NULL,
  "counter_value" bigint DEFAULT 0 NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."app_write_events" (
  "id" bigint DEFAULT nextval('app_write_events_id_seq'::regclass) NOT NULL,
  "event_key" text NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."md_agents" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "line_no" integer NOT NULL,
  "line_text" text,
  "imported_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."md_heartbeat" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "line_no" integer NOT NULL,
  "line_text" text,
  "imported_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."md_identity" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "line_no" integer NOT NULL,
  "line_text" text,
  "imported_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."md_soul" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "line_no" integer NOT NULL,
  "line_text" text,
  "imported_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."md_tools" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "line_no" integer NOT NULL,
  "line_text" text,
  "imported_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."md_user" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "line_no" integer NOT NULL,
  "line_text" text,
  "imported_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."mem_log" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "chat_session_log" text NOT NULL,
  "logged_at" timestamptz DEFAULT now() NOT NULL,
  "system_prompt" text,
  "ai_response" text,
  "ai_response_updated_at" timestamptz,
  "memory_key" text,
  "memory_value" text,
  "memory_effective_date" date,
  "memory_category" text,
  "memory_priority" text,
  "memory_active" boolean DEFAULT true
);

CREATE TABLE IF NOT EXISTS public."memory_action_logs" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "action_key" text NOT NULL,
  "action_kind" text NOT NULL,
  "summary" text NOT NULL,
  "detail_text" text NOT NULL,
  "source_path" text NOT NULL,
  "source_line_start" integer,
  "source_line_end" integer,
  "project_key" text,
  "project_name" text,
  "host_key" text,
  "host_name" text,
  "descriptor_text" text,
  "content_hash" text NOT NULL,
  "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "active" boolean DEFAULT true NOT NULL,
  "imported_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_categories" (
  "id" uuid NOT NULL,
  "category_key" text NOT NULL,
  "name" text NOT NULL,
  "description" text,
  "aliases" text[] DEFAULT '{}'::text[],
  "active" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_code_change_logs" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "change_key" text NOT NULL,
  "change_kind" text NOT NULL,
  "summary" text NOT NULL,
  "detail_text" text NOT NULL,
  "source_path" text NOT NULL,
  "source_line_start" integer,
  "source_line_end" integer,
  "project_key" text,
  "project_name" text,
  "host_key" text,
  "host_name" text,
  "descriptor_text" text,
  "file_paths" text[] DEFAULT '{}'::text[] NOT NULL,
  "content_hash" text NOT NULL,
  "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "active" boolean DEFAULT true NOT NULL,
  "imported_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_code_links" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "code_unit_key" text NOT NULL,
  "link_type" text NOT NULL,
  "target_type" text NOT NULL,
  "target_key" text NOT NULL,
  "source_path" text,
  "source_line_start" integer,
  "source_line_end" integer,
  "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_code_units" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "unit_key" text NOT NULL,
  "unit_kind" text NOT NULL,
  "lang" text,
  "workspace_path" text NOT NULL,
  "repo_root" text,
  "title" text,
  "symbol_name" text,
  "start_line" integer,
  "end_line" integer,
  "content_hash" text NOT NULL,
  "body_text" text,
  "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "active" boolean DEFAULT true NOT NULL,
  "imported_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_context_notes" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "note_key" text NOT NULL,
  "note_type" text NOT NULL,
  "title" text,
  "note_text" text NOT NULL,
  "source_kind" text NOT NULL,
  "source_path" text NOT NULL,
  "source_line_start" integer,
  "source_line_end" integer,
  "content_hash" text NOT NULL,
  "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "active" boolean DEFAULT true NOT NULL,
  "imported_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_directives" (
  "id" uuid NOT NULL,
  "source_path" text NOT NULL,
  "source_line_start" integer,
  "source_line_end" integer,
  "directive_text" text NOT NULL,
  "category" text,
  "priority" text,
  "effective_date" text,
  "tags" text[] DEFAULT '{}'::text[],
  "active" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_hosts" (
  "id" uuid NOT NULL,
  "host_key" text NOT NULL,
  "host_name" text,
  "ip_address" text,
  "purpose" text,
  "source_path" text NOT NULL,
  "source_line_start" integer,
  "source_line_end" integer,
  "tags" text[] DEFAULT '{}'::text[],
  "active" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_project_aliases" (
  "id" uuid NOT NULL,
  "project_key" text NOT NULL,
  "alias" text NOT NULL,
  "alias_norm" text NOT NULL,
  "alias_type" text,
  "source_path" text NOT NULL,
  "source_line_start" integer,
  "source_line_end" integer,
  "created_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_project_facts" (
  "id" uuid NOT NULL,
  "project_key" text NOT NULL,
  "fact_type" text,
  "fact_text" text NOT NULL,
  "source_path" text NOT NULL,
  "source_line_start" integer,
  "source_line_end" integer,
  "tags" text[] DEFAULT '{}'::text[],
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_projects" (
  "id" uuid NOT NULL,
  "project_key" text NOT NULL,
  "name" text NOT NULL,
  "install_path" text,
  "purpose" text,
  "install_type" text,
  "deployment_path" text,
  "service_names" text[] DEFAULT '{}'::text[],
  "host_names" text[] DEFAULT '{}'::text[],
  "source_path" text NOT NULL,
  "source_line_start" integer,
  "source_line_end" integer,
  "tags" text[] DEFAULT '{}'::text[],
  "active" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_relationships" (
  "id" uuid NOT NULL,
  "subject_type" text NOT NULL,
  "subject_key" text NOT NULL,
  "relation" text NOT NULL,
  "object_type" text NOT NULL,
  "object_key" text NOT NULL,
  "source_path" text NOT NULL,
  "source_line_start" integer,
  "source_line_end" integer,
  "tags" text[] DEFAULT '{}'::text[],
  "created_at" timestamptz DEFAULT now() NOT NULL
);


-- Additive vector/neural-style semantic recall layer.
-- These derived structures improve recall without pruning or deleting source history.
CREATE TABLE IF NOT EXISTS public."memory_semantic_nodes" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "node_key" text NOT NULL,
  "node_type" text NOT NULL,
  "canonical_label" text NOT NULL,
  "aliases" text[] DEFAULT '{}'::text[] NOT NULL,
  "description" text,
  "llm_hint" text,
  "source_model" text,
  "confidence" numeric(6,4),
  "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "active" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_semantic_edges" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "subject_type" text NOT NULL,
  "subject_key" text NOT NULL,
  "relation" text NOT NULL,
  "object_type" text NOT NULL,
  "object_key" text NOT NULL,
  "weight" numeric(8,5) DEFAULT 1.0 NOT NULL,
  "weight_basis" text,
  "llm_reason" text,
  "source_model" text,
  "evidence_source" text,
  "evidence_hash" text,
  "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "active" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_embedding_slots" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "source_type" text NOT NULL,
  "source_key" text NOT NULL,
  "embedding_model" text NOT NULL,
  "embedding_dim" integer,
  "embedding_vector" double precision[],
  "embedding_hash" text,
  "content_hash" text,
  "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_recall_hints" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "source_type" text NOT NULL,
  "source_key" text NOT NULL,
  "hint_kind" text NOT NULL,
  "hint_text" text NOT NULL,
  "related_keys" text[] DEFAULT '{}'::text[] NOT NULL,
  "weight" numeric(8,5) DEFAULT 1.0 NOT NULL,
  "source_model" text,
  "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "active" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_query_observations" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "observed_at" timestamptz DEFAULT now() NOT NULL,
  "query_text" text NOT NULL,
  "query_intent" text,
  "source_type" text NOT NULL,
  "source_key" text NOT NULL,
  "rank_seen" integer,
  "was_useful" boolean,
  "usefulness_score" numeric(8,5),
  "feedback_basis" text,
  "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_request_category_map" (
  "id" uuid NOT NULL,
  "request_id" uuid NOT NULL,
  "category_key" text NOT NULL,
  "confidence" numeric,
  "reason" text,
  "created_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_request_intake" (
  "id" uuid NOT NULL,
  "request_text" text NOT NULL,
  "normalized_text" text NOT NULL,
  "source" text DEFAULT 'chat'::text,
  "session_hint" text,
  "created_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_runbooks" (
  "id" uuid NOT NULL,
  "runbook_key" text NOT NULL,
  "title" text NOT NULL,
  "scope" text,
  "trigger_text" text,
  "procedure_text" text NOT NULL,
  "source_path" text NOT NULL,
  "source_line_start" integer,
  "source_line_end" integer,
  "tags" text[] DEFAULT '{}'::text[],
  "active" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."memory_services" (
  "id" uuid NOT NULL,
  "service_key" text NOT NULL,
  "service_name" text NOT NULL,
  "host_key" text,
  "project_key" text,
  "runtime_type" text,
  "service_path" text,
  "source_path" text NOT NULL,
  "source_line_start" integer,
  "source_line_end" integer,
  "tags" text[] DEFAULT '{}'::text[],
  "active" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."t1" (
  "id" integer DEFAULT nextval('t1_id_seq'::regclass) NOT NULL,
  "v" text
);

CREATE TABLE IF NOT EXISTS public."zorg_intent_category_map" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "intent_key" text NOT NULL,
  "categories" text[] DEFAULT '{}'::text[] NOT NULL,
  "default_tools" text[] DEFAULT '{}'::text[] NOT NULL,
  "confidence_hint" text,
  "enabled" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."zorg_memory" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "chat_session_log" text NOT NULL,
  "logged_at" timestamptz DEFAULT now() NOT NULL,
  "system_prompt" text,
  "ai_response" text,
  "ai_response_updated_at" timestamptz,
  "memory_key" text,
  "memory_value" text,
  "memory_effective_date" date,
  "memory_category" text,
  "memory_priority" text,
  "memory_active" boolean DEFAULT true
);


CREATE TABLE IF NOT EXISTS public.zorg_memory_file_archive (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  source_path text NOT NULL,
  content_sha256 text NOT NULL,
  byte_size integer NOT NULL,
  line_count integer NOT NULL,
  content text NOT NULL,
  content_json jsonb,
  migrated_at timestamptz DEFAULT now() NOT NULL,
  deleted_from_filesystem boolean DEFAULT false NOT NULL,
  deleted_at timestamptz,
  notes text,
  CONSTRAINT zorg_memory_file_archive_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."zorg_operational_facts" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "fact_key" text NOT NULL,
  "fact_value" text NOT NULL,
  "fact_category" text,
  "fact_priority" text DEFAULT 'high'::text,
  "active" boolean DEFAULT true,
  "updated_at" timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."zorg_progress_heartbeat_log" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "run_at" timestamptz DEFAULT now() NOT NULL,
  "active_goals" integer NOT NULL,
  "done_goals" integer NOT NULL,
  "blocked_goals" integer NOT NULL,
  "weighted_completion_pct" numeric(6,2) NOT NULL,
  "weighted_score" numeric(6,2) NOT NULL,
  "notes" text
);

CREATE TABLE IF NOT EXISTS public."zorg_progress_tracker" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "goal_key" text NOT NULL,
  "goal_name" text NOT NULL,
  "horizon" text NOT NULL,
  "status" text DEFAULT 'active'::text NOT NULL,
  "priority" integer DEFAULT 3 NOT NULL,
  "weight" numeric(6,2) DEFAULT 1.00 NOT NULL,
  "percent_complete" numeric(5,2) DEFAULT 0.00 NOT NULL,
  "score_override" numeric(6,2),
  "owner" text DEFAULT 'Zorg'::text NOT NULL,
  "notes" text,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL,
  "last_reviewed_at" timestamptz
);

CREATE TABLE IF NOT EXISTS public."zorg_prompt_blueprint" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "blueprint_key" text NOT NULL,
  "section_order" integer NOT NULL,
  "section_title" text NOT NULL,
  "template_text" text NOT NULL,
  "enabled" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."zorg_prompt_compiler_runs" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "input_text" text NOT NULL,
  "input_hash" text NOT NULL,
  "detected_intent" text NOT NULL,
  "matched_rule_keys" text[] DEFAULT '{}'::text[] NOT NULL,
  "matched_tool_keys" text[] DEFAULT '{}'::text[] NOT NULL,
  "matched_categories" text[] DEFAULT '{}'::text[] NOT NULL,
  "compiled_prompt" text NOT NULL,
  "latency_ms" integer,
  "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS public."zorg_rule_catalog" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "rule_key" text NOT NULL,
  "category" text NOT NULL,
  "applies_to_intents" text[] DEFAULT '{}'::text[] NOT NULL,
  "trigger_keywords" text[] DEFAULT '{}'::text[] NOT NULL,
  "priority" integer DEFAULT 100 NOT NULL,
  "tool_tags" text[] DEFAULT '{}'::text[] NOT NULL,
  "rule_text" text NOT NULL,
  "enabled" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."zorg_rules" (
  "id" bigint DEFAULT nextval('zorg_rules_id_seq'::regclass) NOT NULL,
  "rule_key" text NOT NULL,
  "rule_text" text NOT NULL,
  "scope" text DEFAULT 'global'::text NOT NULL,
  "priority" integer DEFAULT 100 NOT NULL,
  "enabled" boolean DEFAULT true NOT NULL,
  "source" text DEFAULT 'community_directive'::text NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."zorg_success_query_index" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "query_text" text NOT NULL,
  "intent" text,
  "outcome_summary" text,
  "source_session" text,
  "completed_ok" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public."zorg_tool_catalog" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "tool_key" text NOT NULL,
  "category" text NOT NULL,
  "capability" text NOT NULL,
  "use_when" text NOT NULL,
  "avoid_when" text,
  "enabled" boolean DEFAULT true NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL
);

CREATE OR REPLACE FUNCTION public.armor(bytea)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_armor$function$;

CREATE OR REPLACE FUNCTION public.armor(bytea, text[], text[])
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_armor$function$;

CREATE OR REPLACE FUNCTION public.crypt(text, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_crypt$function$;

CREATE OR REPLACE FUNCTION public.dearmor(text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_dearmor$function$;

CREATE OR REPLACE FUNCTION public.decrypt(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_decrypt$function$;

CREATE OR REPLACE FUNCTION public.decrypt_iv(bytea, bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_decrypt_iv$function$;

CREATE OR REPLACE FUNCTION public.digest(text, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_digest$function$;

CREATE OR REPLACE FUNCTION public.digest(bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_digest$function$;

CREATE OR REPLACE FUNCTION public.encrypt(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_encrypt$function$;

CREATE OR REPLACE FUNCTION public.encrypt_iv(bytea, bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_encrypt_iv$function$;

CREATE OR REPLACE FUNCTION public.gen_random_bytes(integer)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_random_bytes$function$;

CREATE OR REPLACE FUNCTION public.gen_random_uuid()
 RETURNS uuid
 LANGUAGE c
 PARALLEL SAFE
AS '$libdir/pgcrypto', $function$pg_random_uuid$function$;

CREATE OR REPLACE FUNCTION public.gen_salt(text)
 RETURNS text
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_gen_salt$function$;

CREATE OR REPLACE FUNCTION public.gen_salt(text, integer)
 RETURNS text
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_gen_salt_rounds$function$;

CREATE OR REPLACE FUNCTION public.gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_query_trgm$function$;

CREATE OR REPLACE FUNCTION public.gin_extract_value_trgm(text, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_value_trgm$function$;

CREATE OR REPLACE FUNCTION public.gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_consistent$function$;

CREATE OR REPLACE FUNCTION public.gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal)
 RETURNS "char"
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_triconsistent$function$;

CREATE OR REPLACE FUNCTION public.gtrgm_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_compress$function$;

CREATE OR REPLACE FUNCTION public.gtrgm_consistent(internal, text, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_consistent$function$;

CREATE OR REPLACE FUNCTION public.gtrgm_decompress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_decompress$function$;

CREATE OR REPLACE FUNCTION public.gtrgm_distance(internal, text, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_distance$function$;

CREATE OR REPLACE FUNCTION public.gtrgm_in(cstring)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_in$function$;

CREATE OR REPLACE FUNCTION public.gtrgm_options(internal)
 RETURNS void
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE
AS '$libdir/pg_trgm', $function$gtrgm_options$function$;

CREATE OR REPLACE FUNCTION public.gtrgm_out(gtrgm)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_out$function$;

CREATE OR REPLACE FUNCTION public.gtrgm_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_penalty$function$;

CREATE OR REPLACE FUNCTION public.gtrgm_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_picksplit$function$;

CREATE OR REPLACE FUNCTION public.gtrgm_same(gtrgm, gtrgm, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_same$function$;

CREATE OR REPLACE FUNCTION public.gtrgm_union(internal, internal)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_union$function$;

CREATE OR REPLACE FUNCTION public.hmac(text, text, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_hmac$function$;

CREATE OR REPLACE FUNCTION public.hmac(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_hmac$function$;

CREATE OR REPLACE FUNCTION public.mem_log_ai_response_ts()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$ begin if new.ai_response is distinct from old.ai_response then new.ai_response_updated_at = now(); end if; return new; end $function$;

CREATE OR REPLACE FUNCTION public.pg_stat_statements(showtext boolean, OUT userid oid, OUT dbid oid, OUT toplevel boolean, OUT queryid bigint, OUT query text, OUT plans bigint, OUT total_plan_time double precision, OUT min_plan_time double precision, OUT max_plan_time double precision, OUT mean_plan_time double precision, OUT stddev_plan_time double precision, OUT calls bigint, OUT total_exec_time double precision, OUT min_exec_time double precision, OUT max_exec_time double precision, OUT mean_exec_time double precision, OUT stddev_exec_time double precision, OUT rows bigint, OUT shared_blks_hit bigint, OUT shared_blks_read bigint, OUT shared_blks_dirtied bigint, OUT shared_blks_written bigint, OUT local_blks_hit bigint, OUT local_blks_read bigint, OUT local_blks_dirtied bigint, OUT local_blks_written bigint, OUT temp_blks_read bigint, OUT temp_blks_written bigint, OUT blk_read_time double precision, OUT blk_write_time double precision, OUT temp_blk_read_time double precision, OUT temp_blk_write_time double precision, OUT wal_records bigint, OUT wal_fpi bigint, OUT wal_bytes numeric, OUT jit_functions bigint, OUT jit_generation_time double precision, OUT jit_inlining_count bigint, OUT jit_inlining_time double precision, OUT jit_optimization_count bigint, OUT jit_optimization_time double precision, OUT jit_emission_count bigint, OUT jit_emission_time double precision)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pg_stat_statements', $function$pg_stat_statements_1_10$function$;

CREATE OR REPLACE FUNCTION public.pg_stat_statements_info(OUT dealloc bigint, OUT stats_reset timestamp with time zone)
 RETURNS record
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pg_stat_statements', $function$pg_stat_statements_info$function$;

CREATE OR REPLACE FUNCTION public.pg_stat_statements_reset(userid oid DEFAULT 0, dbid oid DEFAULT 0, queryid bigint DEFAULT 0)
 RETURNS void
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pg_stat_statements', $function$pg_stat_statements_reset_1_7$function$;

CREATE OR REPLACE FUNCTION public.pgp_armor_headers(text, OUT key text, OUT value text)
 RETURNS SETOF record
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_armor_headers$function$;

CREATE OR REPLACE FUNCTION public.pgp_key_id(bytea)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_key_id_w$function$;

CREATE OR REPLACE FUNCTION public.pgp_pub_decrypt(bytea, bytea)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_text$function$;

CREATE OR REPLACE FUNCTION public.pgp_pub_decrypt(bytea, bytea, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_text$function$;

CREATE OR REPLACE FUNCTION public.pgp_pub_decrypt(bytea, bytea, text, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_text$function$;

CREATE OR REPLACE FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_bytea$function$;

CREATE OR REPLACE FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_bytea$function$;

CREATE OR REPLACE FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_bytea$function$;

CREATE OR REPLACE FUNCTION public.pgp_pub_encrypt(text, bytea)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_encrypt_text$function$;

CREATE OR REPLACE FUNCTION public.pgp_pub_encrypt(text, bytea, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_encrypt_text$function$;

CREATE OR REPLACE FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_encrypt_bytea$function$;

CREATE OR REPLACE FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_encrypt_bytea$function$;

CREATE OR REPLACE FUNCTION public.pgp_sym_decrypt(bytea, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_decrypt_text$function$;

CREATE OR REPLACE FUNCTION public.pgp_sym_decrypt(bytea, text, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_decrypt_text$function$;

CREATE OR REPLACE FUNCTION public.pgp_sym_decrypt_bytea(bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_decrypt_bytea$function$;

CREATE OR REPLACE FUNCTION public.pgp_sym_decrypt_bytea(bytea, text, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_decrypt_bytea$function$;

CREATE OR REPLACE FUNCTION public.pgp_sym_encrypt(text, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_encrypt_text$function$;

CREATE OR REPLACE FUNCTION public.pgp_sym_encrypt(text, text, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_encrypt_text$function$;

CREATE OR REPLACE FUNCTION public.pgp_sym_encrypt_bytea(bytea, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_encrypt_bytea$function$;

CREATE OR REPLACE FUNCTION public.pgp_sym_encrypt_bytea(bytea, text, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_encrypt_bytea$function$;

CREATE OR REPLACE FUNCTION public.refresh_zorg_memory_search_fast_mv()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
begin
  refresh materialized view public.zorg_memory_search_fast_mv;
  analyze public.zorg_memory_search_fast_mv;
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_zorg_master_context()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
begin
  refresh materialized view zorg_master_context_mv;
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_zorg_memory_search_mv()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
begin
  refresh materialized view zorg_memory_search_mv;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_limit(real)
 RETURNS real
 LANGUAGE c
 STRICT
AS '$libdir/pg_trgm', $function$set_limit$function$;

CREATE OR REPLACE FUNCTION public.show_limit()
 RETURNS real
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_limit$function$;

CREATE OR REPLACE FUNCTION public.show_trgm(text)
 RETURNS text[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_trgm$function$;

CREATE OR REPLACE FUNCTION public.similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity$function$;

CREATE OR REPLACE FUNCTION public.similarity_dist(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_dist$function$;

CREATE OR REPLACE FUNCTION public.similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_op$function$;

CREATE OR REPLACE FUNCTION public.strict_word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity$function$;

CREATE OR REPLACE FUNCTION public.strict_word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_commutator_op$function$;

CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_commutator_op$function$;

CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_op$function$;

CREATE OR REPLACE FUNCTION public.strict_word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_op$function$;

CREATE OR REPLACE FUNCTION public.t1_audit()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$ begin return new; end $function$;

CREATE OR REPLACE FUNCTION public.upsert_zorg_success_query(p_query_text text, p_intent text, p_outcome_summary text, p_source_session text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$ begin insert into zorg_success_query_index(query_text,intent,outcome_summary,source_session,completed_ok,created_at,updated_at) values (p_query_text,p_intent,p_outcome_summary,p_source_session,true,now(),now()) on conflict (query_text, coalesce(intent,'')) do update set outcome_summary = excluded.outcome_summary, source_session = coalesce(excluded.source_session, zorg_success_query_index.source_session), completed_ok = true, updated_at = now(); end; $function$;

CREATE OR REPLACE FUNCTION public.word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity$function$;

CREATE OR REPLACE FUNCTION public.word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_commutator_op$function$;

CREATE OR REPLACE FUNCTION public.word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_commutator_op$function$;

CREATE OR REPLACE FUNCTION public.word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_op$function$;

CREATE OR REPLACE FUNCTION public.word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_op$function$;

CREATE OR REPLACE FUNCTION public.zorg_compile_system_prompt(p_input text, p_context jsonb DEFAULT '{}'::jsonb)
 RETURNS TABLE(compiled_prompt text, detected_intent text, matched_rule_keys text[], matched_tool_keys text[], matched_categories text[])
 LANGUAGE plpgsql
AS $function$
declare
  v_start timestamptz := clock_timestamp();
  v_intent text;
  v_tokens text[];
  v_categories text[] := '{}';
  v_rule_keys text[] := '{}';
  v_tool_keys text[] := '{}';
  v_rules_block text := '';
  v_tools_block text := '';
  v_blueprint_block text := '';
  v_compiled text := '';
  v_input_hash text;
  v_meta jsonb := coalesce(p_context, '{}'::jsonb);
begin
  v_intent := zorg_detect_intent(coalesce(p_input, ''));

  select array_agg(distinct lower(tok))
    into v_tokens
  from regexp_split_to_table(lower(coalesce(p_input, '')), '[^a-z0-9_]+') tok
  where length(tok) > 2;

  select coalesce(categories, '{}')
    into v_categories
  from zorg_intent_category_map
  where enabled = true
    and intent_key = v_intent
  limit 1;

  with matched as (
    select r.rule_key, r.rule_text, r.priority, r.tool_tags
    from zorg_rule_catalog r
    where r.enabled = true
      and (
        v_intent = any(r.applies_to_intents)
        or exists (
          select 1
          from unnest(coalesce(r.trigger_keywords, '{}')) kw
          where kw = any(coalesce(v_tokens, '{}'))
        )
        or (
          coalesce(array_length(v_categories, 1), 0) > 0
          and r.category = any(v_categories)
        )
      )
  ), ranked as (
    select *
    from matched
    order by priority desc, rule_key asc
    limit 24
  )
  select
    coalesce(array_agg(distinct rule_key), '{}'),
    coalesce(string_agg(distinct format('- [%s] %s', rule_key, rule_text), E'\n'), ''),
    coalesce(array_agg(distinct tool_tag) filter (where tool_tag is not null), '{}')
  into v_rule_keys, v_rules_block, v_tool_keys
  from (
    select r.rule_key, r.rule_text, t.tool_tag
    from ranked r
    left join lateral unnest(coalesce(r.tool_tags, '{}')) as t(tool_tag) on true
  ) x;

  with toolset as (
    select distinct t.tool_key, t.capability, t.use_when
    from zorg_tool_catalog t
    where t.enabled = true
      and (
        t.tool_key = any(v_tool_keys)
        or (
          coalesce(array_length(v_categories, 1), 0) > 0
          and t.category = any(v_categories)
        )
      )
    order by t.tool_key
  )
  select coalesce(string_agg(format('- %s: %s (use when: %s)', tool_key, capability, use_when), E'\n'), '')
    into v_tools_block
  from toolset;

  select coalesce(string_agg(format('[%s] %s', section_title, template_text), E'\n\n' order by section_order), '')
    into v_blueprint_block
  from zorg_prompt_blueprint
  where enabled = true;

  v_compiled := trim(both from concat_ws(E'\n\n',
    'SYSTEM PROMPT (DYNAMICALLY COMPILED)',
    format('Intent: %s', v_intent),
    case when coalesce(array_length(v_categories,1),0) > 0 then format('Categories: %s', array_to_string(v_categories, ', ')) else null end,
    case when v_blueprint_block <> '' then v_blueprint_block else null end,
    case when v_rules_block <> '' then 'Applicable Rules:' || E'\n' || v_rules_block else null end,
    case when v_tools_block <> '' then 'Applicable Tools:' || E'\n' || v_tools_block else null end,
    'User Input:' || E'\n' || coalesce(p_input, '')
  ));

  v_input_hash := md5(coalesce(p_input, ''));

  insert into zorg_prompt_compiler_runs(
    input_text, input_hash, detected_intent, matched_rule_keys,
    matched_tool_keys, matched_categories, compiled_prompt, latency_ms, metadata
  )
  values (
    coalesce(p_input, ''), v_input_hash, v_intent, coalesce(v_rule_keys, '{}'),
    coalesce(v_tool_keys, '{}'), coalesce(v_categories, '{}'), v_compiled,
    (extract(epoch from clock_timestamp() - v_start) * 1000)::int,
    v_meta
  );

  compiled_prompt := v_compiled;
  detected_intent := v_intent;
  matched_rule_keys := coalesce(v_rule_keys, '{}');
  matched_tool_keys := coalesce(v_tool_keys, '{}');
  matched_categories := coalesce(v_categories, '{}');

  return next;
end;
$function$;

CREATE OR REPLACE FUNCTION public.zorg_compute_progress_score(p_note text DEFAULT NULL::text)
 RETURNS TABLE(run_at timestamp with time zone, active_goals integer, done_goals integer, blocked_goals integer, weighted_completion_pct numeric, weighted_score numeric)
 LANGUAGE plpgsql
AS $function$
declare
  v_active int;
  v_done int;
  v_blocked int;
  v_weight_total numeric;
  v_completion numeric;
  v_score numeric;
begin
  select count(*) into v_active from zorg_progress_tracker where status in ('active','blocked');
  select count(*) into v_done from zorg_progress_tracker where status='done';
  select count(*) into v_blocked from zorg_progress_tracker where status='blocked';

  select coalesce(sum(weight),0),
         coalesce(sum(weight * percent_complete),0)
    into v_weight_total, v_completion
  from zorg_progress_tracker
  where status in ('active','blocked','done');

  if v_weight_total > 0 then
    v_completion := round((v_completion / v_weight_total)::numeric, 2);
  else
    v_completion := 0;
  end if;

  -- score penalizes blocked work slightly, rewards completion
  v_score := round(greatest(0, least(100, v_completion - (v_blocked * 2)))::numeric, 2);

  insert into zorg_progress_heartbeat_log(
    active_goals, done_goals, blocked_goals, weighted_completion_pct, weighted_score, notes
  ) values (
    v_active, v_done, v_blocked, v_completion, v_score, p_note
  );

  return query
  select now(), v_active, v_done, v_blocked, v_completion, v_score;
end;
$function$;

CREATE OR REPLACE FUNCTION public.zorg_detect_intent(p_input text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case
    when p_input ~* '(upload|attach|file|document|image|pdf)' then 'file_handling'
    when p_input ~* '(docker|container|compose|k8s|kubernetes)' then 'container_ops'
    when p_input ~* '(postgres|sql|database|query|index|migration)' then 'database_ops'
    when p_input ~* '(code|bug|fix|typescript|python|javascript|build)' then 'code_change'
    when p_input ~* '(weather|forecast|temperature)' then 'weather'
    when p_input ~* '(search|research|look up|find online)' then 'research'
    else 'general'
  end;
$function$;

CREATE OR REPLACE FUNCTION public.zorg_get_host_context(p_query text, p_limit integer DEFAULT 5)
 RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
 LANGUAGE sql
AS $function$
  with matched_hosts as (
    select distinct h.host_key
    from public.memory_hosts h
    where coalesce(h.active, true) = true
      and (
        coalesce(h.host_name, '') ilike '%' || p_query || '%'
        or coalesce(h.host_key, '') ilike '%' || p_query || '%'
        or coalesce(h.ip_address, '') ilike '%' || p_query || '%'
        or coalesce(h.purpose, '') ilike '%' || p_query || '%'
      )
    limit greatest(coalesce(p_limit, 5), 1)
  )
  select * from (
    select
      'host'::text,
      h.id::text,
      h.source_path,
      h.source_line_start,
      h.source_line_end,
      'high'::text,
      concat_ws(E'\n',
        case when h.host_name is not null then 'Host: ' || h.host_name end,
        case when h.host_key is not null then 'Host key: ' || h.host_key end,
        case when h.ip_address is not null then 'IP: ' || h.ip_address end,
        case when h.purpose is not null then 'Purpose: ' || h.purpose end
      )
    from public.memory_hosts h
    where h.host_key in (select host_key from matched_hosts)

    union all

    select
      'service'::text,
      s.id::text,
      s.source_path,
      s.source_line_start,
      s.source_line_end,
      'medium'::text,
      concat_ws(E'\n',
        'Service: ' || s.service_name,
        case when s.project_key is not null then 'Project: ' || s.project_key end,
        case when s.host_key is not null then 'Host: ' || s.host_key end,
        case when s.service_path is not null then 'Path: ' || s.service_path end
      )
    from public.memory_services s
    where s.host_key in (select host_key from matched_hosts)
      and coalesce(s.active, true) = true
  ) q
  limit greatest(coalesce(p_limit, 5), 1) * 3;
$function$;

CREATE OR REPLACE FUNCTION public.zorg_get_project_context(p_query text, p_limit integer DEFAULT 5)
 RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
 LANGUAGE sql
AS $function$
  with matched_projects as (
    select distinct p.project_key, p.id, p.source_path, p.source_line_start, p.source_line_end,
           p.name, p.install_path, p.purpose, p.deployment_path
    from public.memory_projects p
    left join public.memory_project_aliases a on a.project_key = p.project_key
    where coalesce(p.active, true) = true
      and (
        p.project_key ilike '%' || p_query || '%'
        or p.name ilike '%' || p_query || '%'
        or coalesce(p.install_path, '') ilike '%' || p_query || '%'
        or coalesce(p.purpose, '') ilike '%' || p_query || '%'
        or a.alias ilike '%' || p_query || '%'
        or a.alias_norm = regexp_replace(lower(p_query), '[^a-z0-9]+', '', 'g')
      )
    limit greatest(coalesce(p_limit, 5), 1)
  )
  select * from (
    select
      'project'::text,
      mp.id::text,
      mp.source_path,
      mp.source_line_start,
      mp.source_line_end,
      'high'::text,
      concat_ws(E'\n',
        'Project: ' || coalesce(mp.name, mp.project_key),
        'Key: ' || mp.project_key,
        case when mp.install_path is not null then 'Install path: ' || mp.install_path end,
        case when mp.purpose is not null then 'Purpose: ' || mp.purpose end,
        case when mp.deployment_path is not null then 'Deployment path: ' || mp.deployment_path end,
        case when aliases.aliases is not null then 'Aliases: ' || aliases.aliases end,
        case when services.services is not null then 'Services: ' || services.services end,
        case when hosts.hosts is not null then 'Hosts: ' || hosts.hosts end
      )
    from matched_projects mp
    left join lateral (
      select string_agg(distinct alias, ', ' order by alias) as aliases
      from public.memory_project_aliases a
      where a.project_key = mp.project_key
    ) aliases on true
    left join lateral (
      select string_agg(distinct service_name, ', ' order by service_name) as services
      from public.memory_services s
      where s.project_key = mp.project_key and coalesce(s.active, true) = true
    ) services on true
    left join lateral (
      select string_agg(distinct coalesce(h.host_name, h.host_key, h.ip_address), ', ' order by coalesce(h.host_name, h.host_key, h.ip_address)) as hosts
      from public.memory_services s
      join public.memory_hosts h on h.host_key = s.host_key
      where s.project_key = mp.project_key
        and coalesce(s.active, true) = true
        and coalesce(h.active, true) = true
    ) hosts on true

    union all

    select
      'project_fact'::text,
      f.id::text,
      f.source_path,
      f.source_line_start,
      f.source_line_end,
      'high'::text,
      f.fact_text
    from public.memory_project_facts f
    join matched_projects mp on mp.project_key = f.project_key

    union all

    select
      'service'::text,
      s.id::text,
      s.source_path,
      s.source_line_start,
      s.source_line_end,
      'medium'::text,
      concat_ws(E'\n',
        'Service: ' || s.service_name,
        case when s.project_key is not null then 'Project: ' || s.project_key end,
        case when s.host_key is not null then 'Host: ' || s.host_key end,
        case when s.service_path is not null then 'Path: ' || s.service_path end
      )
    from public.memory_services s
    join matched_projects mp on mp.project_key = s.project_key
    where coalesce(s.active, true) = true
  ) q
  limit greatest(coalesce(p_limit, 5), 1) * 4;
$function$;

CREATE OR REPLACE FUNCTION public.zorg_get_runbook_context(p_query text, p_limit integer DEFAULT 5)
 RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
 LANGUAGE sql
AS $function$
  select
    'runbook'::text,
    r.id::text,
    r.source_path,
    r.source_line_start,
    r.source_line_end,
    'high'::text,
    concat_ws(E'\n',
      coalesce(r.title, r.runbook_key),
      case when r.trigger_text is not null then 'Trigger: ' || r.trigger_text end,
      r.procedure_text
    )
  from public.memory_runbooks r
  where coalesce(r.active, true) = true
    and (
      coalesce(r.title, '') ilike '%' || p_query || '%'
      or coalesce(r.runbook_key, '') ilike '%' || p_query || '%'
      or coalesce(r.trigger_text, '') ilike '%' || p_query || '%'
      or coalesce(r.procedure_text, '') ilike '%' || p_query || '%'
    )
  order by r.updated_at desc
  limit greatest(coalesce(p_limit, 5), 1);
$function$;



CREATE OR REPLACE FUNCTION public.zorg_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;
CREATE OR REPLACE FUNCTION public.zorg_search_memory(p_query text, p_limit integer DEFAULT 10)
 RETURNS TABLE(source_table text, source_id text, event_ts timestamp with time zone, category text, priority text, snippet text)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_limit integer := greatest(coalesce(p_limit, 10), 1);
  v_query_lc text := lower(coalesce(p_query, ''));
  v_ts_en tsquery := plainto_tsquery('english', coalesce(p_query, ''));
  v_ts_simple tsquery := plainto_tsquery('simple', coalesce(p_query, ''));
  v_ts_any_en tsquery;
  v_ts_any_simple tsquery;
BEGIN
  WITH raw_tokens AS (
    SELECT DISTINCT t.token
    FROM regexp_split_to_table(v_query_lc, '[^a-z0-9]+') AS t(token)
    WHERE length(t.token) >= 3
    LIMIT 12
  ), token_queries AS (
    SELECT
      NULLIF((plainto_tsquery('english', token))::text, '') AS q_en,
      NULLIF((plainto_tsquery('simple', token))::text, '') AS q_simple
    FROM raw_tokens
  )
  SELECT
    NULLIF(string_agg(q_en, ' | ') FILTER (WHERE q_en IS NOT NULL), '')::tsquery,
    NULLIF(string_agg(q_simple, ' | ') FILTER (WHERE q_simple IS NOT NULL), '')::tsquery
  INTO v_ts_any_en, v_ts_any_simple
  FROM token_queries;

  RETURN QUERY
  WITH fts_matches AS (
    SELECT z.source_table, z.source_id, z.event_ts, z.category, z.priority,
           left(z.content, 240) AS snippet, 0 AS match_rank, NULL::integer AS token_hits
    FROM public.zorg_memory_search_fast_mv z
    WHERE (z.content_fts_en @@ v_ts_en OR z.content_fts_simple @@ v_ts_simple)
    ORDER BY z.source_rank, z.event_ts DESC
    LIMIT v_limit
  ), exact_matches AS (
    SELECT z.source_table, z.source_id, z.event_ts, z.category, z.priority,
           left(z.content, 240) AS snippet, 1 AS match_rank, NULL::integer AS token_hits
    FROM public.zorg_memory_search_fast_mv z
    WHERE z.content_lc LIKE '%' || v_query_lc || '%'
      AND NOT EXISTS (SELECT 1 FROM fts_matches f WHERE f.source_table=z.source_table AND f.source_id=z.source_id)
    ORDER BY z.source_rank, z.event_ts DESC
    LIMIT v_limit
  ), token_matches AS (
    SELECT z.source_table, z.source_id, z.event_ts, z.category, z.priority,
           left(z.content, 240) AS snippet, 2 AS match_rank,
           greatest(
             CASE WHEN v_ts_any_en IS NULL THEN 0 ELSE ts_rank_cd(z.content_fts_en, v_ts_any_en)::numeric END,
             CASE WHEN v_ts_any_simple IS NULL THEN 0 ELSE ts_rank_cd(z.content_fts_simple, v_ts_any_simple)::numeric END
           ) AS token_hits,
           z.source_rank
    FROM public.zorg_memory_search_fast_mv z
    WHERE (v_ts_any_en IS NOT NULL OR v_ts_any_simple IS NOT NULL)
      AND ((v_ts_any_en IS NOT NULL AND z.content_fts_en @@ v_ts_any_en)
        OR (v_ts_any_simple IS NOT NULL AND z.content_fts_simple @@ v_ts_any_simple))
      AND NOT EXISTS (SELECT 1 FROM fts_matches f WHERE f.source_table=z.source_table AND f.source_id=z.source_id)
      AND NOT EXISTS (SELECT 1 FROM exact_matches e WHERE e.source_table=z.source_table AND e.source_id=z.source_id)
    ORDER BY token_hits DESC, z.source_rank, z.event_ts DESC
    LIMIT v_limit
  ), ranked AS (
    SELECT f.source_table, f.source_id, f.event_ts, f.category, f.priority, f.snippet, f.match_rank, f.token_hits::numeric FROM fts_matches f
    UNION ALL
    SELECT e.source_table, e.source_id, e.event_ts, e.category, e.priority, e.snippet, e.match_rank, e.token_hits::numeric FROM exact_matches e
    UNION ALL
    SELECT t.source_table, t.source_id, t.event_ts, t.category, t.priority, t.snippet, t.match_rank, t.token_hits FROM token_matches t
    WHERE (SELECT count(*) FROM fts_matches) + (SELECT count(*) FROM exact_matches) < v_limit
  )
  SELECT r.source_table, r.source_id, r.event_ts, r.category, r.priority, r.snippet
  FROM ranked r
  ORDER BY CASE WHEN r.source_table = 'logic_rule' THEN 0 WHEN r.priority = 'critical' THEN 1 ELSE 2 END, r.match_rank, coalesce(r.token_hits, 0) DESC, r.event_ts DESC
  LIMIT v_limit;
END;
$function$;

CREATE OR REPLACE FUNCTION public.zorg_recall_context(p_query text, p_limit integer DEFAULT 10)
 RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
 LANGUAGE sql
AS $function$
  with combined as (
    select * from public.zorg_get_runbook_context(p_query, greatest(1, coalesce(p_limit, 10) / 2))
    union all
    select * from public.zorg_get_project_context(p_query, greatest(1, coalesce(p_limit, 10) / 2))
    union all
    select * from public.zorg_get_host_context(p_query, greatest(1, coalesce(p_limit, 10) / 3))
    union all
    select
      case z.source_table
        when 'directive' then 'directive'
        when 'runbook' then 'runbook'
        when 'project' then 'project'
        when 'project_fact' then 'project_fact'
        when 'host' then 'host'
        when 'service' then 'service'
        when 'relationship' then 'relationship'
        when 'operational_fact' then 'operational_fact'
        else 'memory'
      end as source_type,
      z.source_id,
      null::text as path,
      null::integer as line_start,
      null::integer as line_end,
      coalesce(z.priority, 'medium') as priority,
      z.snippet as content
    from public.zorg_search_memory(p_query, greatest(coalesce(p_limit, 10), 1)) z
  )
  select distinct on (source_type, source_id, content)
    source_type,
    source_id,
    path,
    line_start,
    line_end,
    priority,
    content
  from combined
  order by source_type, source_id, content,
    case when lower(priority) = 'critical' then 1
         when lower(priority) = 'high' then 2
         when lower(priority) = 'medium' then 3
         else 4 end
  limit greatest(coalesce(p_limit, 10), 1);
$function$;


CREATE MATERIALIZED VIEW IF NOT EXISTS public."zorg_master_context_mv" AS
 SELECT 'directive'::text AS source_type,
    d.id::text AS source_id,
    COALESCE(d.priority, 'high'::text) AS priority,
    d.updated_at AS sort_ts,
    COALESCE(d.category, 'directive'::text) AS title,
    d.directive_text AS content
   FROM memory_directives d
  WHERE COALESCE(d.active, true) = true
UNION ALL
 SELECT 'runbook'::text AS source_type,
    r.id::text AS source_id,
    'high'::text AS priority,
    r.updated_at AS sort_ts,
    COALESCE(r.title, r.runbook_key, 'runbook'::text) AS title,
    concat_ws('
'::text,
        CASE
            WHEN r.trigger_text IS NOT NULL THEN 'Trigger: '::text || r.trigger_text
            ELSE NULL::text
        END, r.procedure_text) AS content
   FROM memory_runbooks r
  WHERE COALESCE(r.active, true) = true
UNION ALL
 SELECT 'project'::text AS source_type,
    p.id::text AS source_id,
    'high'::text AS priority,
    p.updated_at AS sort_ts,
    COALESCE(p.name, p.project_key) AS title,
    concat_ws('
'::text, 'Project: '::text || COALESCE(p.name, p.project_key), 'Key: '::text || p.project_key,
        CASE
            WHEN p.install_path IS NOT NULL THEN 'Install path: '::text || p.install_path
            ELSE NULL::text
        END,
        CASE
            WHEN p.purpose IS NOT NULL THEN 'Purpose: '::text || p.purpose
            ELSE NULL::text
        END,
        CASE
            WHEN p.deployment_path IS NOT NULL THEN 'Deployment path: '::text || p.deployment_path
            ELSE NULL::text
        END,
        CASE
            WHEN aliases.aliases IS NOT NULL THEN 'Aliases: '::text || aliases.aliases
            ELSE NULL::text
        END,
        CASE
            WHEN services.services IS NOT NULL THEN 'Services: '::text || services.services
            ELSE NULL::text
        END,
        CASE
            WHEN hosts.hosts IS NOT NULL THEN 'Hosts: '::text || hosts.hosts
            ELSE NULL::text
        END,
        CASE
            WHEN facts.facts IS NOT NULL THEN 'Facts: '::text || facts.facts
            ELSE NULL::text
        END) AS content
   FROM memory_projects p
     LEFT JOIN ( SELECT memory_project_aliases.project_key,
            string_agg(DISTINCT memory_project_aliases.alias, ', '::text ORDER BY memory_project_aliases.alias) AS aliases
           FROM memory_project_aliases
          GROUP BY memory_project_aliases.project_key) aliases ON aliases.project_key = p.project_key
     LEFT JOIN ( SELECT memory_services.project_key,
            string_agg(DISTINCT memory_services.service_name, ', '::text ORDER BY memory_services.service_name) AS services
           FROM memory_services
          WHERE COALESCE(memory_services.active, true) = true
          GROUP BY memory_services.project_key) services ON services.project_key = p.project_key
     LEFT JOIN ( SELECT s.project_key,
            string_agg(DISTINCT COALESCE(h.host_name, h.host_key, h.ip_address), ', '::text ORDER BY (COALESCE(h.host_name, h.host_key, h.ip_address))) AS hosts
           FROM memory_services s
             JOIN memory_hosts h ON h.host_key = s.host_key
          WHERE COALESCE(s.active, true) = true AND COALESCE(h.active, true) = true
          GROUP BY s.project_key) hosts ON hosts.project_key = p.project_key
     LEFT JOIN ( SELECT memory_project_facts.project_key,
            string_agg(DISTINCT memory_project_facts.fact_text, ' || '::text ORDER BY memory_project_facts.fact_text) AS facts
           FROM memory_project_facts
          GROUP BY memory_project_facts.project_key) facts ON facts.project_key = p.project_key
  WHERE COALESCE(p.active, true) = true
UNION ALL
 SELECT 'host'::text AS source_type,
    h.id::text AS source_id,
    'high'::text AS priority,
    h.updated_at AS sort_ts,
    COALESCE(h.host_name, h.host_key, h.ip_address, 'host'::text) AS title,
    concat_ws('
'::text,
        CASE
            WHEN h.host_name IS NOT NULL THEN 'Host: '::text || h.host_name
            ELSE NULL::text
        END,
        CASE
            WHEN h.host_key IS NOT NULL THEN 'Host key: '::text || h.host_key
            ELSE NULL::text
        END,
        CASE
            WHEN h.ip_address IS NOT NULL THEN 'IP: '::text || h.ip_address
            ELSE NULL::text
        END,
        CASE
            WHEN h.purpose IS NOT NULL THEN 'Purpose: '::text || h.purpose
            ELSE NULL::text
        END,
        CASE
            WHEN host_projects.projects IS NOT NULL THEN 'Projects: '::text || host_projects.projects
            ELSE NULL::text
        END,
        CASE
            WHEN host_services.services IS NOT NULL THEN 'Services: '::text || host_services.services
            ELSE NULL::text
        END) AS content
   FROM memory_hosts h
     LEFT JOIN ( SELECT s.host_key,
            string_agg(DISTINCT COALESCE(p.name, p.project_key, s.project_key), ', '::text ORDER BY (COALESCE(p.name, p.project_key, s.project_key))) AS projects
           FROM memory_services s
             LEFT JOIN memory_projects p ON p.project_key = s.project_key
          WHERE COALESCE(s.active, true) = true
          GROUP BY s.host_key) host_projects ON host_projects.host_key = h.host_key
     LEFT JOIN ( SELECT memory_services.host_key,
            string_agg(DISTINCT memory_services.service_name, ', '::text ORDER BY memory_services.service_name) AS services
           FROM memory_services
          WHERE COALESCE(memory_services.active, true) = true
          GROUP BY memory_services.host_key) host_services ON host_services.host_key = h.host_key
  WHERE COALESCE(h.active, true) = true
UNION ALL
 SELECT 'operational_fact'::text AS source_type,
    z.id::text AS source_id,
    COALESCE(z.fact_priority, 'high'::text) AS priority,
    z.updated_at AS sort_ts,
    z.fact_key AS title,
    z.fact_value AS content
   FROM zorg_operational_facts z
  WHERE COALESCE(z.active, true) = true
WITH NO DATA;

CREATE TABLE IF NOT EXISTS public.zorg_logic_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key text NOT NULL UNIQUE,
  title text NOT NULL,
  rule_text text NOT NULL,
  rule_type text NOT NULL DEFAULT 'deduced_operating_logic',
  priority text NOT NULL DEFAULT 'high',
  privacy_scope text NOT NULL DEFAULT 'private',
  source_basis text NOT NULL DEFAULT 'operator_instruction',
  applies_to text[] NOT NULL DEFAULT ARRAY[]::text[],
  standard_checks text[] NOT NULL DEFAULT ARRAY[]::text[],
  performance_tuning_notes text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.zorg_logic_rule_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key text NOT NULL REFERENCES public.zorg_logic_rules(rule_key) ON DELETE CASCADE,
  source_type text NOT NULL,
  source_ref text,
  source_summary text NOT NULL,
  private_context boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.zorg_logic_rule_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key text NOT NULL REFERENCES public.zorg_logic_rules(rule_key) ON DELETE CASCADE,
  applied_at timestamptz NOT NULL DEFAULT now(),
  task_category text,
  object_type text,
  object_ref text,
  check_performed text NOT NULL,
  result_summary text,
  followup_needed boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_type_priority ON public.zorg_logic_rules(rule_type, priority);
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_applies_gin ON public.zorg_logic_rules USING gin(applies_to);
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_text_trgm ON public.zorg_logic_rules USING gin ((title || E'\n' || rule_text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_text_fts_en ON public.zorg_logic_rules USING gin (to_tsvector('english', title || E'\n' || rule_text));
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rule_apps_key_time ON public.zorg_logic_rule_applications(rule_key, applied_at DESC);



CREATE MATERIALIZED VIEW IF NOT EXISTS public."zorg_memory_search_mv" AS
 SELECT 'directive'::text AS source_table,
    d.id::text AS source_id,
    d.updated_at AS event_ts,
    d.category,
    d.priority,
    d.directive_text AS content
   FROM memory_directives d
  WHERE COALESCE(d.active, true) = true
UNION ALL
 SELECT 'runbook'::text AS source_table,
    r.id::text AS source_id,
    r.updated_at AS event_ts,
    'runbook'::text AS category,
    'high'::text AS priority,
    concat_ws('
'::text, COALESCE(r.title, r.runbook_key), COALESCE(r.trigger_text, ''::text), r.procedure_text) AS content
   FROM memory_runbooks r
  WHERE COALESCE(r.active, true) = true
UNION ALL
 SELECT 'project'::text AS source_table,
    p.id::text AS source_id,
    p.updated_at AS event_ts,
    'project'::text AS category,
    'high'::text AS priority,
    concat_ws('
'::text, COALESCE(p.name, p.project_key), p.project_key, COALESCE(p.install_path, ''::text), COALESCE(p.purpose, ''::text), COALESCE(p.deployment_path, ''::text)) AS content
   FROM memory_projects p
  WHERE COALESCE(p.active, true) = true
UNION ALL
 SELECT 'project_alias'::text AS source_table,
    a.id::text AS source_id,
    a.created_at AS event_ts,
    'project_alias'::text AS category,
    'high'::text AS priority,
    concat_ws('
'::text, a.project_key, a.alias, COALESCE(a.alias_type, ''::text)) AS content
   FROM memory_project_aliases a
UNION ALL
 SELECT 'project_fact'::text AS source_table,
    f.id::text AS source_id,
    f.updated_at AS event_ts,
    f.fact_type AS category,
    'high'::text AS priority,
    concat_ws('
'::text, f.project_key, COALESCE(f.fact_type, ''::text), f.fact_text) AS content
   FROM memory_project_facts f
UNION ALL
 SELECT 'host'::text AS source_table,
    h.id::text AS source_id,
    h.updated_at AS event_ts,
    'host'::text AS category,
    'high'::text AS priority,
    concat_ws('
'::text, COALESCE(h.host_name, ''::text), COALESCE(h.host_key, ''::text), COALESCE(h.ip_address, ''::text), COALESCE(h.purpose, ''::text)) AS content
   FROM memory_hosts h
  WHERE COALESCE(h.active, true) = true
UNION ALL
 SELECT 'service'::text AS source_table,
    s.id::text AS source_id,
    s.updated_at AS event_ts,
    'service'::text AS category,
    'high'::text AS priority,
    concat_ws('
'::text, s.service_name, COALESCE(s.project_key, ''::text), COALESCE(s.host_key, ''::text), COALESCE(s.service_path, ''::text)) AS content
   FROM memory_services s
  WHERE COALESCE(s.active, true) = true
UNION ALL
 SELECT 'relationship'::text AS source_table,
    rel.id::text AS source_id,
    COALESCE(rel.created_at, now()) AS event_ts,
    'relationship'::text AS category,
    'medium'::text AS priority,
    concat_ws(' '::text, (rel.subject_type || ':'::text) || rel.subject_key, rel.relation, (rel.object_type || ':'::text) || rel.object_key) AS content
   FROM memory_relationships rel
UNION ALL
 SELECT 'logic_rule'::text AS source_table,
    (lr.id)::text AS source_id,
    COALESCE(lr.updated_at, lr.created_at, now()) AS event_ts,
    COALESCE(lr.rule_type, 'logic_rule'::text) AS category,
    COALESCE(lr.priority, 'high'::text) AS priority,
    concat_ws(E'\n', lr.rule_key, lr.title, lr.rule_text, COALESCE(array_to_string(lr.applies_to, ' '::text), ''::text), COALESCE(array_to_string(lr.standard_checks, ' '::text), ''::text)) AS content
   FROM zorg_logic_rules lr
  WHERE (COALESCE(lr.active, true) = true)
UNION ALL
 SELECT 'zorg_memory'::text AS source_table,
    z.id::text AS source_id,
    z.logged_at AS event_ts,
    z.memory_category AS category,
    z.memory_priority AS priority,
    COALESCE(z.memory_value, z.chat_session_log, ''::text) AS content
   FROM zorg_memory z
UNION ALL
 SELECT 'operational_fact'::text AS source_table,
    zf.id::text AS source_id,
    zf.updated_at AS event_ts,
    zf.fact_category AS category,
    zf.fact_priority AS priority,
    zf.fact_value AS content
   FROM zorg_operational_facts zf
  WHERE COALESCE(zf.active, true) = true
WITH NO DATA;

CREATE MATERIALIZED VIEW IF NOT EXISTS public."zorg_memory_search_fast_mv" AS
 SELECT source_table,
    source_id,
    event_ts,
    category,
    priority,
    content,
    lower(content) AS content_lc,
    to_tsvector('english'::regconfig, content) AS content_fts_en,
    to_tsvector('simple'::regconfig, content) AS content_fts_simple,
    CASE
        WHEN (source_table = 'zorg_memory'::text) THEN 1
        ELSE 0
    END AS source_rank,
    length(content) AS content_len
   FROM zorg_memory_search_mv
WITH NO DATA;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'app_activity_events_pkey') THEN
    ALTER TABLE public."app_activity_events" ADD CONSTRAINT "app_activity_events_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'app_query_log_pkey') THEN
    ALTER TABLE public."app_query_log" ADD CONSTRAINT "app_query_log_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'app_query_rate_events_pkey') THEN
    ALTER TABLE public."app_query_rate_events" ADD CONSTRAINT "app_query_rate_events_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'app_write_counters_pkey') THEN
    ALTER TABLE public."app_write_counters" ADD CONSTRAINT "app_write_counters_pkey" PRIMARY KEY (counter_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'app_write_events_pkey') THEN
    ALTER TABLE public."app_write_events" ADD CONSTRAINT "app_write_events_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'md_agents_pkey') THEN
    ALTER TABLE public."md_agents" ADD CONSTRAINT "md_agents_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'md_heartbeat_pkey') THEN
    ALTER TABLE public."md_heartbeat" ADD CONSTRAINT "md_heartbeat_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'md_identity_pkey') THEN
    ALTER TABLE public."md_identity" ADD CONSTRAINT "md_identity_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'md_soul_pkey') THEN
    ALTER TABLE public."md_soul" ADD CONSTRAINT "md_soul_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'md_tools_pkey') THEN
    ALTER TABLE public."md_tools" ADD CONSTRAINT "md_tools_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'md_user_pkey') THEN
    ALTER TABLE public."md_user" ADD CONSTRAINT "md_user_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mem_log_pkey') THEN
    ALTER TABLE public."mem_log" ADD CONSTRAINT "mem_log_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_action_logs_pkey') THEN
    ALTER TABLE public."memory_action_logs" ADD CONSTRAINT "memory_action_logs_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_categories_pkey') THEN
    ALTER TABLE public."memory_categories" ADD CONSTRAINT "memory_categories_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_code_change_logs_pkey') THEN
    ALTER TABLE public."memory_code_change_logs" ADD CONSTRAINT "memory_code_change_logs_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_code_links_pkey') THEN
    ALTER TABLE public."memory_code_links" ADD CONSTRAINT "memory_code_links_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_code_units_pkey') THEN
    ALTER TABLE public."memory_code_units" ADD CONSTRAINT "memory_code_units_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_context_notes_pkey') THEN
    ALTER TABLE public."memory_context_notes" ADD CONSTRAINT "memory_context_notes_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_directives_pkey') THEN
    ALTER TABLE public."memory_directives" ADD CONSTRAINT "memory_directives_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_hosts_pkey') THEN
    ALTER TABLE public."memory_hosts" ADD CONSTRAINT "memory_hosts_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_project_aliases_pkey') THEN
    ALTER TABLE public."memory_project_aliases" ADD CONSTRAINT "memory_project_aliases_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_project_facts_pkey') THEN
    ALTER TABLE public."memory_project_facts" ADD CONSTRAINT "memory_project_facts_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_projects_pkey') THEN
    ALTER TABLE public."memory_projects" ADD CONSTRAINT "memory_projects_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_relationships_pkey') THEN
    ALTER TABLE public."memory_relationships" ADD CONSTRAINT "memory_relationships_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_request_category_map_pkey') THEN
    ALTER TABLE public."memory_request_category_map" ADD CONSTRAINT "memory_request_category_map_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_request_intake_pkey') THEN
    ALTER TABLE public."memory_request_intake" ADD CONSTRAINT "memory_request_intake_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_runbooks_pkey') THEN
    ALTER TABLE public."memory_runbooks" ADD CONSTRAINT "memory_runbooks_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_services_pkey') THEN
    ALTER TABLE public."memory_services" ADD CONSTRAINT "memory_services_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 't1_pkey') THEN
    ALTER TABLE public."t1" ADD CONSTRAINT "t1_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_intent_category_map_pkey') THEN
    ALTER TABLE public."zorg_intent_category_map" ADD CONSTRAINT "zorg_intent_category_map_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_memory_pkey') THEN
    ALTER TABLE public."zorg_memory" ADD CONSTRAINT "zorg_memory_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_operational_facts_pkey') THEN
    ALTER TABLE public."zorg_operational_facts" ADD CONSTRAINT "zorg_operational_facts_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_progress_heartbeat_log_pkey') THEN
    ALTER TABLE public."zorg_progress_heartbeat_log" ADD CONSTRAINT "zorg_progress_heartbeat_log_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_progress_tracker_pkey') THEN
    ALTER TABLE public."zorg_progress_tracker" ADD CONSTRAINT "zorg_progress_tracker_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_prompt_blueprint_pkey') THEN
    ALTER TABLE public."zorg_prompt_blueprint" ADD CONSTRAINT "zorg_prompt_blueprint_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_prompt_compiler_runs_pkey') THEN
    ALTER TABLE public."zorg_prompt_compiler_runs" ADD CONSTRAINT "zorg_prompt_compiler_runs_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_rule_catalog_pkey') THEN
    ALTER TABLE public."zorg_rule_catalog" ADD CONSTRAINT "zorg_rule_catalog_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_rules_pkey') THEN
    ALTER TABLE public."zorg_rules" ADD CONSTRAINT "zorg_rules_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_success_query_index_pkey') THEN
    ALTER TABLE public."zorg_success_query_index" ADD CONSTRAINT "zorg_success_query_index_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_tool_catalog_pkey') THEN
    ALTER TABLE public."zorg_tool_catalog" ADD CONSTRAINT "zorg_tool_catalog_pkey" PRIMARY KEY (id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_action_logs_action_key_key') THEN
    ALTER TABLE public."memory_action_logs" ADD CONSTRAINT "memory_action_logs_action_key_key" UNIQUE (action_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_categories_category_key_key') THEN
    ALTER TABLE public."memory_categories" ADD CONSTRAINT "memory_categories_category_key_key" UNIQUE (category_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_code_change_logs_change_key_key') THEN
    ALTER TABLE public."memory_code_change_logs" ADD CONSTRAINT "memory_code_change_logs_change_key_key" UNIQUE (change_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_code_links_unique') THEN
    ALTER TABLE public."memory_code_links" ADD CONSTRAINT "memory_code_links_unique" UNIQUE (code_unit_key, link_type, target_type, target_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_code_units_unit_key_key') THEN
    ALTER TABLE public."memory_code_units" ADD CONSTRAINT "memory_code_units_unit_key_key" UNIQUE (unit_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_context_notes_note_key_key') THEN
    ALTER TABLE public."memory_context_notes" ADD CONSTRAINT "memory_context_notes_note_key_key" UNIQUE (note_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_hosts_host_key_key') THEN
    ALTER TABLE public."memory_hosts" ADD CONSTRAINT "memory_hosts_host_key_key" UNIQUE (host_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_projects_project_key_key') THEN
    ALTER TABLE public."memory_projects" ADD CONSTRAINT "memory_projects_project_key_key" UNIQUE (project_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_runbooks_runbook_key_key') THEN
    ALTER TABLE public."memory_runbooks" ADD CONSTRAINT "memory_runbooks_runbook_key_key" UNIQUE (runbook_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'memory_services_service_key_key') THEN
    ALTER TABLE public."memory_services" ADD CONSTRAINT "memory_services_service_key_key" UNIQUE (service_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_intent_category_map_intent_key_key') THEN
    ALTER TABLE public."zorg_intent_category_map" ADD CONSTRAINT "zorg_intent_category_map_intent_key_key" UNIQUE (intent_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_operational_facts_fact_key_key') THEN
    ALTER TABLE public."zorg_operational_facts" ADD CONSTRAINT "zorg_operational_facts_fact_key_key" UNIQUE (fact_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_progress_tracker_goal_key_key') THEN
    ALTER TABLE public."zorg_progress_tracker" ADD CONSTRAINT "zorg_progress_tracker_goal_key_key" UNIQUE (goal_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_prompt_blueprint_blueprint_key_key') THEN
    ALTER TABLE public."zorg_prompt_blueprint" ADD CONSTRAINT "zorg_prompt_blueprint_blueprint_key_key" UNIQUE (blueprint_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_rule_catalog_rule_key_key') THEN
    ALTER TABLE public."zorg_rule_catalog" ADD CONSTRAINT "zorg_rule_catalog_rule_key_key" UNIQUE (rule_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_rules_rule_key_key') THEN
    ALTER TABLE public."zorg_rules" ADD CONSTRAINT "zorg_rules_rule_key_key" UNIQUE (rule_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_tool_catalog_tool_key_key') THEN
    ALTER TABLE public."zorg_tool_catalog" ADD CONSTRAINT "zorg_tool_catalog_tool_key_key" UNIQUE (tool_key);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_progress_tracker_horizon_check') THEN
    ALTER TABLE public."zorg_progress_tracker" ADD CONSTRAINT "zorg_progress_tracker_horizon_check" CHECK ((horizon = ANY (ARRAY['short'::text, 'long'::text])));
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_progress_tracker_percent_complete_check') THEN
    ALTER TABLE public."zorg_progress_tracker" ADD CONSTRAINT "zorg_progress_tracker_percent_complete_check" CHECK (((percent_complete >= (0)::numeric) AND (percent_complete <= (100)::numeric)));
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_progress_tracker_priority_check') THEN
    ALTER TABLE public."zorg_progress_tracker" ADD CONSTRAINT "zorg_progress_tracker_priority_check" CHECK (((priority >= 1) AND (priority <= 5)));
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'zorg_progress_tracker_status_check') THEN
    ALTER TABLE public."zorg_progress_tracker" ADD CONSTRAINT "zorg_progress_tracker_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'blocked'::text, 'done'::text, 'archived'::text])));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_app_activity_events_created_at ON public.app_activity_events USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_query_log_logged_at ON public.app_query_log USING btree (logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_query_rate_events_logged_at ON public.app_query_rate_events USING btree (logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_write_events_created_at ON public.app_write_events USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_md_agents_line_no ON public.md_agents USING btree (line_no);
CREATE INDEX IF NOT EXISTS idx_md_agents_line_text_expr_trgm ON public.md_agents USING gin (COALESCE(line_text, ''::text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_md_heartbeat_line_no ON public.md_heartbeat USING btree (line_no);
CREATE INDEX IF NOT EXISTS idx_md_heartbeat_line_text_expr_trgm ON public.md_heartbeat USING gin (COALESCE(line_text, ''::text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_md_identity_line_no ON public.md_identity USING btree (line_no);
CREATE INDEX IF NOT EXISTS idx_md_identity_line_text_expr_trgm ON public.md_identity USING gin (COALESCE(line_text, ''::text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_md_soul_line_no ON public.md_soul USING btree (line_no);
CREATE INDEX IF NOT EXISTS idx_md_soul_line_text_expr_trgm ON public.md_soul USING gin (COALESCE(line_text, ''::text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_md_tools_line_no ON public.md_tools USING btree (line_no);
CREATE INDEX IF NOT EXISTS idx_md_tools_line_text_expr_trgm ON public.md_tools USING gin (COALESCE(line_text, ''::text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_md_user_line_no ON public.md_user USING btree (line_no);
CREATE INDEX IF NOT EXISTS idx_md_user_line_text_expr_trgm ON public.md_user USING gin (COALESCE(line_text, ''::text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_memory_action_logs_detail_text_trgm ON public.memory_action_logs USING gin (detail_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_memory_action_logs_host_key ON public.memory_action_logs USING btree (host_key);
CREATE INDEX IF NOT EXISTS idx_memory_action_logs_project_key ON public.memory_action_logs USING btree (project_key);
CREATE INDEX IF NOT EXISTS idx_memory_action_logs_source_path ON public.memory_action_logs USING btree (source_path);
CREATE INDEX IF NOT EXISTS idx_memory_categories_key ON public.memory_categories USING btree (category_key);
CREATE INDEX IF NOT EXISTS idx_memory_code_change_logs_detail_text_trgm ON public.memory_code_change_logs USING gin (detail_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_memory_code_change_logs_file_paths ON public.memory_code_change_logs USING gin (file_paths);
CREATE INDEX IF NOT EXISTS idx_memory_code_change_logs_host_key ON public.memory_code_change_logs USING btree (host_key);
CREATE INDEX IF NOT EXISTS idx_memory_code_change_logs_project_key ON public.memory_code_change_logs USING btree (project_key);
CREATE INDEX IF NOT EXISTS idx_memory_code_change_logs_source_path ON public.memory_code_change_logs USING btree (source_path);
CREATE INDEX IF NOT EXISTS idx_memory_code_links_code_unit_key ON public.memory_code_links USING btree (code_unit_key);
CREATE INDEX IF NOT EXISTS idx_memory_code_links_link_type ON public.memory_code_links USING btree (link_type);
CREATE INDEX IF NOT EXISTS idx_memory_code_links_target ON public.memory_code_links USING btree (target_type, target_key);
CREATE INDEX IF NOT EXISTS idx_memory_code_units_body_text_trgm ON public.memory_code_units USING gin (COALESCE(body_text, ''::text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_memory_code_units_lang ON public.memory_code_units USING btree (lang);
CREATE INDEX IF NOT EXISTS idx_memory_code_units_repo_root ON public.memory_code_units USING btree (repo_root);
CREATE INDEX IF NOT EXISTS idx_memory_code_units_unit_kind ON public.memory_code_units USING btree (unit_kind);
CREATE INDEX IF NOT EXISTS idx_memory_code_units_workspace_path ON public.memory_code_units USING btree (workspace_path);
CREATE INDEX IF NOT EXISTS idx_memory_context_notes_note_text_trgm ON public.memory_context_notes USING gin (note_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_memory_context_notes_note_type ON public.memory_context_notes USING btree (note_type);
CREATE INDEX IF NOT EXISTS idx_memory_context_notes_source_kind ON public.memory_context_notes USING btree (source_kind);
CREATE INDEX IF NOT EXISTS idx_memory_context_notes_source_path ON public.memory_context_notes USING btree (source_path);
CREATE INDEX IF NOT EXISTS idx_memory_project_aliases_alias_norm ON public.memory_project_aliases USING btree (alias_norm);
CREATE UNIQUE INDEX IF NOT EXISTS idx_memory_project_aliases_unique ON public.memory_project_aliases USING btree (project_key, alias_norm);
CREATE INDEX IF NOT EXISTS idx_memory_project_facts_project_key ON public.memory_project_facts USING btree (project_key);

CREATE UNIQUE INDEX IF NOT EXISTS idx_memory_semantic_nodes_key ON public.memory_semantic_nodes USING btree (node_key);
CREATE INDEX IF NOT EXISTS idx_memory_semantic_nodes_type ON public.memory_semantic_nodes USING btree (node_type);
CREATE INDEX IF NOT EXISTS idx_memory_semantic_nodes_aliases ON public.memory_semantic_nodes USING gin (aliases);
CREATE INDEX IF NOT EXISTS idx_memory_semantic_nodes_label_trgm ON public.memory_semantic_nodes USING gin (canonical_label gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_memory_semantic_edges_subject ON public.memory_semantic_edges USING btree (subject_type, subject_key);
CREATE INDEX IF NOT EXISTS idx_memory_semantic_edges_object ON public.memory_semantic_edges USING btree (object_type, object_key);
CREATE INDEX IF NOT EXISTS idx_memory_semantic_edges_relation_weight ON public.memory_semantic_edges USING btree (relation, weight DESC);
CREATE INDEX IF NOT EXISTS idx_memory_embedding_slots_source ON public.memory_embedding_slots USING btree (source_type, source_key);
CREATE INDEX IF NOT EXISTS idx_memory_embedding_slots_model_hash ON public.memory_embedding_slots USING btree (embedding_model, embedding_hash);
CREATE INDEX IF NOT EXISTS idx_memory_recall_hints_source ON public.memory_recall_hints USING btree (source_type, source_key);
CREATE INDEX IF NOT EXISTS idx_memory_recall_hints_text_trgm ON public.memory_recall_hints USING gin (hint_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_memory_query_observations_query_trgm ON public.memory_query_observations USING gin (query_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_memory_query_observations_source ON public.memory_query_observations USING btree (source_type, source_key);
CREATE INDEX IF NOT EXISTS idx_memory_query_observations_observed_at ON public.memory_query_observations USING btree (observed_at DESC);

CREATE INDEX IF NOT EXISTS idx_memory_request_category_map_category_key ON public.memory_request_category_map USING btree (category_key);
CREATE INDEX IF NOT EXISTS idx_memory_request_category_map_request_id ON public.memory_request_category_map USING btree (request_id);
CREATE INDEX IF NOT EXISTS idx_memory_request_intake_created_at ON public.memory_request_intake USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_memory_services_host_active ON public.memory_services USING btree (host_key) WHERE (COALESCE(active, true) = true);
CREATE INDEX IF NOT EXISTS idx_memory_services_project_active ON public.memory_services USING btree (project_key) WHERE (COALESCE(active, true) = true);
CREATE INDEX IF NOT EXISTS idx_zicm_enabled_intent ON public.zorg_intent_category_map USING btree (enabled, intent_key);
CREATE INDEX IF NOT EXISTS idx_zmcmv_content_trgm ON public.zorg_master_context_mv USING gin (content gin_trgm_ops);
CREATE UNIQUE INDEX IF NOT EXISTS idx_zmcmv_pk ON public.zorg_master_context_mv USING btree (source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_zmcmv_priority_rank_sort_ts ON public.zorg_master_context_mv USING btree ((
CASE
    WHEN (lower(priority) = 'critical'::text) THEN 1
    WHEN (lower(priority) = 'high'::text) THEN 2
    WHEN (lower(priority) = 'medium'::text) THEN 3
    ELSE 4
END), sort_ts DESC);
CREATE INDEX IF NOT EXISTS idx_zmcmv_priority_ts ON public.zorg_master_context_mv USING btree (priority, sort_ts DESC);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_ai_response_coalesce_trgm ON public.zorg_memory USING gin (COALESCE(ai_response, ''::text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_chat_session_log_coalesce_trgm ON public.zorg_memory USING gin (COALESCE(chat_session_log, ''::text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_logged_at_desc ON public.zorg_memory USING btree (logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_memory_active ON public.zorg_memory USING btree (memory_active);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_memory_category ON public.zorg_memory USING btree (memory_category);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_memory_effective_date ON public.zorg_memory USING btree (memory_effective_date);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_memory_key_coalesce_trgm ON public.zorg_memory USING gin (COALESCE(memory_key, ''::text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_memory_priority ON public.zorg_memory USING btree (memory_priority);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_memory_value_coalesce_trgm ON public.zorg_memory USING gin (COALESCE(memory_value, ''::text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_search_blob_trgm ON public.zorg_memory USING gin ((((((((((COALESCE(memory_value, ''::text) || ' '::text) || COALESCE(chat_session_log, ''::text)) || ' '::text) || COALESCE(memory_key, ''::text)) || ' '::text) || COALESCE(system_prompt, ''::text)) || ' '::text) || COALESCE(ai_response, ''::text))) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_system_prompt_coalesce_trgm ON public.zorg_memory USING gin (COALESCE(system_prompt, ''::text) gin_trgm_ops);

CREATE UNIQUE INDEX IF NOT EXISTS idx_zorg_memory_migrated_file_line_key ON public.zorg_memory USING btree (memory_key) WHERE (memory_key ~~ 'migrated-memory-file::%'::text);
CREATE UNIQUE INDEX IF NOT EXISTS idx_zorg_memory_core_markdown_key ON public.zorg_memory USING btree (memory_key) WHERE (memory_key ~~ 'core-markdown::%'::text);
CREATE UNIQUE INDEX IF NOT EXISTS idx_zorg_memory_file_archive_source_sha ON public.zorg_memory_file_archive USING btree (source_path, content_sha256);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_file_archive_source_path ON public.zorg_memory_file_archive USING btree (source_path);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_file_archive_deleted ON public.zorg_memory_file_archive USING btree (deleted_from_filesystem);
CREATE INDEX IF NOT EXISTS idx_zorg_memory_file_archive_content_trgm ON public.zorg_memory_file_archive USING gin (content gin_trgm_ops);
CREATE UNIQUE INDEX IF NOT EXISTS idx_zms_fast_mv_pk ON public.zorg_memory_search_fast_mv USING btree (source_table, source_id);
CREATE INDEX IF NOT EXISTS idx_zms_fast_mv_content_lc_trgm ON public.zorg_memory_search_fast_mv USING gin (content_lc gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zms_fast_mv_fts_en ON public.zorg_memory_search_fast_mv USING gin (content_fts_en);
CREATE INDEX IF NOT EXISTS idx_zms_fast_mv_fts_simple ON public.zorg_memory_search_fast_mv USING gin (content_fts_simple);
CREATE INDEX IF NOT EXISTS idx_zms_fast_mv_rank_ts ON public.zorg_memory_search_fast_mv USING btree (source_rank, event_ts DESC);
CREATE INDEX IF NOT EXISTS idx_zms_fast_mv_priority_rank_ts ON public.zorg_memory_search_fast_mv USING btree (priority, source_rank, event_ts DESC);
CREATE INDEX IF NOT EXISTS idx_zms_mv_content_fts ON public.zorg_memory_search_mv USING gin (to_tsvector('english'::regconfig, content));
CREATE INDEX IF NOT EXISTS idx_zms_mv_content_fts_simple ON public.zorg_memory_search_mv USING gin (to_tsvector('simple'::regconfig, content));
CREATE INDEX IF NOT EXISTS idx_zms_mv_content_trgm ON public.zorg_memory_search_mv USING gin (content gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zms_mv_event_ts_desc ON public.zorg_memory_search_mv USING btree (event_ts DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_zms_mv_pk ON public.zorg_memory_search_mv USING btree (source_table, source_id);
CREATE INDEX IF NOT EXISTS idx_zms_mv_source_rank_event_ts ON public.zorg_memory_search_mv USING btree ((
CASE
    WHEN (source_table = 'zorg_memory'::text) THEN 1
    ELSE 0
END), event_ts DESC);
CREATE INDEX IF NOT EXISTS idx_zpb_enabled_order ON public.zorg_prompt_blueprint USING btree (enabled, section_order);
CREATE INDEX IF NOT EXISTS idx_zpcr_created ON public.zorg_prompt_compiler_runs USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_zpcr_intent ON public.zorg_prompt_compiler_runs USING btree (detected_intent);
CREATE INDEX IF NOT EXISTS idx_zrc_enabled_priority ON public.zorg_rule_catalog USING btree (enabled, priority DESC);
CREATE INDEX IF NOT EXISTS idx_zrc_intents ON public.zorg_rule_catalog USING gin (applies_to_intents);
CREATE INDEX IF NOT EXISTS idx_zrc_keywords ON public.zorg_rule_catalog USING gin (trigger_keywords);
CREATE INDEX IF NOT EXISTS idx_zorg_rules_enabled_priority ON public.zorg_rules USING btree (enabled, priority);
CREATE INDEX IF NOT EXISTS idx_zsqi_created_at_desc ON public.zorg_success_query_index USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_zsqi_outcome_trgm ON public.zorg_success_query_index USING gin (outcome_summary gin_trgm_ops);
CREATE UNIQUE INDEX IF NOT EXISTS idx_zsqi_query_intent_unique ON public.zorg_success_query_index USING btree (query_text, COALESCE(intent, ''::text));
CREATE INDEX IF NOT EXISTS idx_zsqi_query_trgm ON public.zorg_success_query_index USING gin (query_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_ztc_enabled_category ON public.zorg_tool_catalog USING btree (enabled, category);

DROP TRIGGER IF EXISTS "trg_mem_log_ai_response_ts" ON public."mem_log";
CREATE TRIGGER "trg_mem_log_ai_response_ts" BEFORE UPDATE ON public."mem_log" FOR EACH ROW EXECUTE FUNCTION mem_log_ai_response_ts();
DROP TRIGGER IF EXISTS "trg_t1" ON public."t1";
CREATE TRIGGER "trg_t1" BEFORE INSERT ON public."t1" FOR EACH ROW EXECUTE FUNCTION t1_audit();
DROP TRIGGER IF EXISTS "trg_zorg_progress_tracker_updated_at" ON public."zorg_progress_tracker";
CREATE TRIGGER "trg_zorg_progress_tracker_updated_at" BEFORE UPDATE ON public."zorg_progress_tracker" FOR EACH ROW EXECUTE FUNCTION zorg_set_updated_at();

-- Fresh installs start empty. Populate with scripts/import_markdown_memory.py or your own ingestion pipeline, then run:
-- SELECT refresh_zorg_memory_search_mv();
-- SELECT refresh_zorg_memory_search_fast_mv();
-- SELECT refresh_zorg_master_context();

-- CONTACTS_CRM_SCHEMA_START
-- Additive Google Contacts / CRM memory schema for Zorg MemoryDB.
-- Private live data belongs only in the local DB. This file contains structure only.

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.zorg_contact_sync_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL DEFAULT 'google_people_api',
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  status text NOT NULL DEFAULT 'running',
  contacts_seen integer NOT NULL DEFAULT 0,
  contacts_upserted integer NOT NULL DEFAULT 0,
  contact_points_upserted integer NOT NULL DEFAULT 0,
  error_text text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.zorg_contacts_crm (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL DEFAULT 'google_people_api',
  source_resource_name text NOT NULL,
  source_etag text,
  display_name text,
  given_name text,
  family_name text,
  middle_name text,
  nickname text,
  company text,
  job_title text,
  department text,
  email_primary text,
  phone_primary text,
  timezone text,
  notes text,
  names jsonb NOT NULL DEFAULT '[]'::jsonb,
  email_addresses jsonb NOT NULL DEFAULT '[]'::jsonb,
  phone_numbers jsonb NOT NULL DEFAULT '[]'::jsonb,
  addresses jsonb NOT NULL DEFAULT '[]'::jsonb,
  organizations jsonb NOT NULL DEFAULT '[]'::jsonb,
  urls jsonb NOT NULL DEFAULT '[]'::jsonb,
  birthdays jsonb NOT NULL DEFAULT '[]'::jsonb,
  events jsonb NOT NULL DEFAULT '[]'::jsonb,
  relations jsonb NOT NULL DEFAULT '[]'::jsonb,
  memberships jsonb NOT NULL DEFAULT '[]'::jsonb,
  user_defined jsonb NOT NULL DEFAULT '[]'::jsonb,
  photos jsonb NOT NULL DEFAULT '[]'::jsonb,
  raw_person jsonb NOT NULL DEFAULT '{}'::jsonb,
  search_text text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_synced_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (source, source_resource_name)
);

CREATE TABLE IF NOT EXISTS public.zorg_contact_points_crm (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES public.zorg_contacts_crm(id) ON DELETE CASCADE,
  point_type text NOT NULL,
  label text,
  value text NOT NULL,
  value_norm text NOT NULL,
  primary_flag boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (contact_id, point_type, value_norm)
);

CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_display_name ON public.zorg_contacts_crm (display_name);
CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_email_primary ON public.zorg_contacts_crm (email_primary);
CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_company ON public.zorg_contacts_crm (company);
CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_updated_at ON public.zorg_contacts_crm (updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_search_trgm ON public.zorg_contacts_crm USING gin (search_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_search_fts_en ON public.zorg_contacts_crm USING gin (to_tsvector('english', search_text));
CREATE INDEX IF NOT EXISTS idx_zorg_contacts_crm_search_fts_simple ON public.zorg_contacts_crm USING gin (to_tsvector('simple', search_text));
CREATE INDEX IF NOT EXISTS idx_zorg_contact_points_crm_type_value ON public.zorg_contact_points_crm (point_type, value_norm);
CREATE INDEX IF NOT EXISTS idx_zorg_contact_points_crm_value_trgm ON public.zorg_contact_points_crm USING gin (value_norm gin_trgm_ops);

CREATE OR REPLACE FUNCTION public.zorg_contact_search_text(c public.zorg_contacts_crm)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT concat_ws(E'\n',
    'Contact: ' || coalesce(c.display_name, ''),
    'Given: ' || coalesce(c.given_name, ''),
    'Family: ' || coalesce(c.family_name, ''),
    'Nickname: ' || coalesce(c.nickname, ''),
    'Company: ' || coalesce(c.company, ''),
    'Title: ' || coalesce(c.job_title, ''),
    'Department: ' || coalesce(c.department, ''),
    'Primary email: ' || coalesce(c.email_primary, ''),
    'Primary phone: ' || coalesce(c.phone_primary, ''),
    'Timezone: ' || coalesce(c.timezone, ''),
    'Notes: ' || coalesce(c.notes, ''),
    'Emails: ' || coalesce(c.email_addresses::text, ''),
    'Phones: ' || coalesce(c.phone_numbers::text, ''),
    'Addresses: ' || coalesce(c.addresses::text, ''),
    'Organizations: ' || coalesce(c.organizations::text, ''),
    'URLs: ' || coalesce(c.urls::text, ''),
    'Relations: ' || coalesce(c.relations::text, ''),
    'User defined: ' || coalesce(c.user_defined::text, '')
  )
$$;

CREATE OR REPLACE VIEW public.zorg_contacts_crm_recall_v AS
SELECT
  'contact'::text AS source_table,
  c.id::text AS source_id,
  c.updated_at AS event_ts,
  'contact_crm'::text AS category,
  'high'::text AS priority,
  public.zorg_contact_search_text(c) AS content
FROM public.zorg_contacts_crm c
WHERE coalesce(c.active, true) = true;

DROP MATERIALIZED VIEW IF EXISTS public.zorg_memory_search_fast_mv;
DROP MATERIALIZED VIEW IF EXISTS public.zorg_memory_search_mv;

CREATE TABLE IF NOT EXISTS public.zorg_logic_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key text NOT NULL UNIQUE,
  title text NOT NULL,
  rule_text text NOT NULL,
  rule_type text NOT NULL DEFAULT 'deduced_operating_logic',
  priority text NOT NULL DEFAULT 'high',
  privacy_scope text NOT NULL DEFAULT 'private',
  source_basis text NOT NULL DEFAULT 'operator_instruction',
  applies_to text[] NOT NULL DEFAULT ARRAY[]::text[],
  standard_checks text[] NOT NULL DEFAULT ARRAY[]::text[],
  performance_tuning_notes text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.zorg_logic_rule_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key text NOT NULL REFERENCES public.zorg_logic_rules(rule_key) ON DELETE CASCADE,
  source_type text NOT NULL,
  source_ref text,
  source_summary text NOT NULL,
  private_context boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.zorg_logic_rule_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key text NOT NULL REFERENCES public.zorg_logic_rules(rule_key) ON DELETE CASCADE,
  applied_at timestamptz NOT NULL DEFAULT now(),
  task_category text,
  object_type text,
  object_ref text,
  check_performed text NOT NULL,
  result_summary text,
  followup_needed boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_type_priority ON public.zorg_logic_rules(rule_type, priority);
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_applies_gin ON public.zorg_logic_rules USING gin(applies_to);
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_text_trgm ON public.zorg_logic_rules USING gin ((title || E'\n' || rule_text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_text_fts_en ON public.zorg_logic_rules USING gin (to_tsvector('english', title || E'\n' || rule_text));
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rule_apps_key_time ON public.zorg_logic_rule_applications(rule_key, applied_at DESC);


CREATE MATERIALIZED VIEW public.zorg_memory_search_mv AS
 SELECT 'directive'::text AS source_table,
    (d.id)::text AS source_id,
    d.updated_at AS event_ts,
    d.category,
    d.priority,
    d.directive_text AS content
   FROM memory_directives d
  WHERE (COALESCE(d.active, true) = true)
UNION ALL
 SELECT 'runbook'::text AS source_table,
    (r.id)::text AS source_id,
    r.updated_at AS event_ts,
    'runbook'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', COALESCE(r.title, r.runbook_key), COALESCE(r.trigger_text, ''::text), r.procedure_text) AS content
   FROM memory_runbooks r
  WHERE (COALESCE(r.active, true) = true)
UNION ALL
 SELECT 'project'::text AS source_table,
    (p.id)::text AS source_id,
    p.updated_at AS event_ts,
    'project'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', COALESCE(p.name, p.project_key), p.project_key, COALESCE(p.install_path, ''::text), COALESCE(p.purpose, ''::text), COALESCE(p.deployment_path, ''::text)) AS content
   FROM memory_projects p
  WHERE (COALESCE(p.active, true) = true)
UNION ALL
 SELECT 'project_alias'::text AS source_table,
    (a.id)::text AS source_id,
    a.created_at AS event_ts,
    'project_alias'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', a.project_key, a.alias, COALESCE(a.alias_type, ''::text)) AS content
   FROM memory_project_aliases a
UNION ALL
 SELECT 'project_fact'::text AS source_table,
    (f.id)::text AS source_id,
    f.updated_at AS event_ts,
    f.fact_type AS category,
    'high'::text AS priority,
    concat_ws(E'\n', f.project_key, COALESCE(f.fact_type, ''::text), f.fact_text) AS content
   FROM memory_project_facts f
UNION ALL
 SELECT 'host'::text AS source_table,
    (h.id)::text AS source_id,
    h.updated_at AS event_ts,
    'host'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', COALESCE(h.host_name, ''::text), COALESCE(h.host_key, ''::text), COALESCE(h.ip_address, ''::text), COALESCE(h.purpose, ''::text)) AS content
   FROM memory_hosts h
  WHERE (COALESCE(h.active, true) = true)
UNION ALL
 SELECT 'service'::text AS source_table,
    (s.id)::text AS source_id,
    s.updated_at AS event_ts,
    'service'::text AS category,
    'high'::text AS priority,
    concat_ws(E'\n', s.service_name, COALESCE(s.project_key, ''::text), COALESCE(s.host_key, ''::text), COALESCE(s.service_path, ''::text)) AS content
   FROM memory_services s
  WHERE (COALESCE(s.active, true) = true)
UNION ALL
 SELECT 'relationship'::text AS source_table,
    (rel.id)::text AS source_id,
    COALESCE(rel.created_at, now()) AS event_ts,
    'relationship'::text AS category,
    'medium'::text AS priority,
    concat_ws(' '::text, ((rel.subject_type || ':'::text) || rel.subject_key), rel.relation, ((rel.object_type || ':'::text) || rel.object_key)) AS content
   FROM memory_relationships rel
UNION ALL
 SELECT 'logic_rule'::text AS source_table,
    (lr.id)::text AS source_id,
    COALESCE(lr.updated_at, lr.created_at, now()) AS event_ts,
    COALESCE(lr.rule_type, 'logic_rule'::text) AS category,
    COALESCE(lr.priority, 'high'::text) AS priority,
    concat_ws(E'\n', lr.rule_key, lr.title, lr.rule_text, COALESCE(array_to_string(lr.applies_to, ' '::text), ''::text), COALESCE(array_to_string(lr.standard_checks, ' '::text), ''::text)) AS content
   FROM zorg_logic_rules lr
  WHERE (COALESCE(lr.active, true) = true)
UNION ALL
 SELECT 'zorg_memory'::text AS source_table,
    (z.id)::text AS source_id,
    z.logged_at AS event_ts,
    z.memory_category AS category,
    z.memory_priority AS priority,
    COALESCE(z.memory_value, z.chat_session_log, ''::text) AS content
   FROM zorg_memory z
UNION ALL
 SELECT 'operational_fact'::text AS source_table,
    (zf.id)::text AS source_id,
    zf.updated_at AS event_ts,
    zf.fact_category AS category,
    zf.fact_priority AS priority,
    zf.fact_value AS content
   FROM zorg_operational_facts zf
  WHERE (COALESCE(zf.active, true) = true)
UNION ALL
 SELECT source_table, source_id, event_ts, category, priority, content
   FROM public.zorg_contacts_crm_recall_v;

CREATE UNIQUE INDEX idx_zms_mv_pk ON public.zorg_memory_search_mv (source_table, source_id);
CREATE INDEX idx_zms_mv_event_ts_desc ON public.zorg_memory_search_mv (event_ts DESC);
CREATE INDEX idx_zms_mv_source_rank_event_ts ON public.zorg_memory_search_mv (((CASE WHEN source_table = 'logic_rule' THEN 0 WHEN source_table = 'zorg_memory' THEN 1 ELSE 2 END)), event_ts DESC);
CREATE INDEX idx_zms_mv_content_trgm ON public.zorg_memory_search_mv USING gin (content gin_trgm_ops);
CREATE INDEX idx_zms_mv_content_fts ON public.zorg_memory_search_mv USING gin (to_tsvector('english', content));
CREATE INDEX idx_zms_mv_content_fts_simple ON public.zorg_memory_search_mv USING gin (to_tsvector('simple', content));

CREATE MATERIALIZED VIEW public.zorg_memory_search_fast_mv AS
 SELECT source_table,
    source_id,
    event_ts,
    category,
    priority,
    content,
    lower(content) AS content_lc,
    to_tsvector('english'::regconfig, content) AS content_fts_en,
    to_tsvector('simple'::regconfig, content) AS content_fts_simple,
    CASE WHEN (source_table = 'logic_rule'::text) THEN 0 WHEN (source_table = 'zorg_memory'::text) THEN 1 WHEN (source_table = 'contact'::text) THEN 2 ELSE 3 END AS source_rank,
    length(content) AS content_len
   FROM public.zorg_memory_search_mv;

CREATE UNIQUE INDEX idx_zms_fast_mv_pk ON public.zorg_memory_search_fast_mv (source_table, source_id);
CREATE INDEX idx_zms_fast_mv_rank_ts ON public.zorg_memory_search_fast_mv (source_rank, event_ts DESC);
CREATE INDEX idx_zms_fast_mv_priority_rank_ts ON public.zorg_memory_search_fast_mv (priority, source_rank, event_ts DESC);
CREATE INDEX idx_zms_fast_mv_content_lc_trgm ON public.zorg_memory_search_fast_mv USING gin (content_lc gin_trgm_ops);
CREATE INDEX idx_zms_fast_mv_fts_en ON public.zorg_memory_search_fast_mv USING gin (content_fts_en);
CREATE INDEX idx_zms_fast_mv_fts_simple ON public.zorg_memory_search_fast_mv USING gin (content_fts_simple);

CREATE OR REPLACE FUNCTION public.zorg_refresh_memory_search()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW public.zorg_memory_search_mv;
  REFRESH MATERIALIZED VIEW public.zorg_memory_search_fast_mv;
END;
$$;

CREATE OR REPLACE FUNCTION public.zorg_recall_context(p_query text, p_limit integer DEFAULT 10)
 RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
 LANGUAGE sql
AS $$
  with combined as (
    select * from public.zorg_get_runbook_context(p_query, greatest(1, coalesce(p_limit, 10) / 2))
    union all
    select * from public.zorg_get_project_context(p_query, greatest(1, coalesce(p_limit, 10) / 2))
    union all
    select * from public.zorg_get_host_context(p_query, greatest(1, coalesce(p_limit, 10) / 3))
    union all
    select
      case z.source_table
        when 'directive' then 'directive'
        when 'runbook' then 'runbook'
        when 'project' then 'project'
        when 'project_fact' then 'project_fact'
        when 'host' then 'host'
        when 'service' then 'service'
        when 'relationship' then 'relationship'
        when 'operational_fact' then 'operational_fact'
        when 'contact' then 'contact'
        else 'memory'
      end as source_type,
      z.source_id,
      null::text as path,
      null::integer as line_start,
      null::integer as line_end,
      coalesce(z.priority, 'medium') as priority,
      z.snippet as content
    from public.zorg_search_memory(p_query, greatest(coalesce(p_limit, 10), 1)) z
  )
  select distinct on (source_type, source_id, content)
    source_type, source_id, path, line_start, line_end, priority, content
  from combined
  order by source_type, source_id, content,
    case when lower(priority) = 'critical' then 1
         when lower(priority) = 'high' then 2
         when lower(priority) = 'medium' then 3
         else 4 end
  limit greatest(coalesce(p_limit, 10), 1);
$$;

-- CONTACTS_CRM_SCHEMA_END

-- CONTACTS_CRM_DEDUPE_SCHEMA_START
-- Additive non-destructive dedupe/distillation layer for CRM contacts.
-- Keeps all raw/provider contact rows; creates canonical groups and review flags.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS public.zorg_contact_canonical_crm (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  canonical_key text NOT NULL UNIQUE,
  display_name text,
  company text,
  job_title text,
  email_primary text,
  phone_primary text,
  source_contact_ids uuid[] NOT NULL DEFAULT ARRAY[]::uuid[],
  source_count integer NOT NULL DEFAULT 0,
  confidence numeric NOT NULL DEFAULT 1.0,
  dedupe_basis text NOT NULL,
  review_needed boolean NOT NULL DEFAULT false,
  review_reason text,
  distilled_notes text,
  search_text text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.zorg_contact_dedupe_flags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flag_key text NOT NULL UNIQUE,
  flag_type text NOT NULL,
  contact_ids uuid[] NOT NULL,
  display_name text,
  evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
  review_status text NOT NULL DEFAULT 'open',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.zorg_contact_canonical_members (
  canonical_id uuid NOT NULL REFERENCES public.zorg_contact_canonical_crm(id) ON DELETE CASCADE,
  contact_id uuid NOT NULL REFERENCES public.zorg_contacts_crm(id) ON DELETE CASCADE,
  match_basis text NOT NULL,
  confidence numeric NOT NULL DEFAULT 1.0,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (canonical_id, contact_id)
);

CREATE INDEX IF NOT EXISTS idx_zorg_contact_canonical_search_trgm ON public.zorg_contact_canonical_crm USING gin (search_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zorg_contact_canonical_search_fts_en ON public.zorg_contact_canonical_crm USING gin (to_tsvector('english', search_text));
CREATE INDEX IF NOT EXISTS idx_zorg_contact_canonical_email ON public.zorg_contact_canonical_crm (email_primary);
CREATE INDEX IF NOT EXISTS idx_zorg_contact_canonical_name ON public.zorg_contact_canonical_crm (display_name);
CREATE INDEX IF NOT EXISTS idx_zorg_contact_dedupe_flags_type_status ON public.zorg_contact_dedupe_flags (flag_type, review_status);

CREATE OR REPLACE FUNCTION public.zorg_contact_norm_name(v text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT nullif(regexp_replace(lower(coalesce(v,'')), '[^a-z0-9]+', '', 'g'), '')
$$;

CREATE OR REPLACE FUNCTION public.zorg_distill_contacts_crm()
RETURNS TABLE(canonical_count integer, member_count integer, open_flag_count integer)
LANGUAGE plpgsql
AS $$
BEGIN
  -- Rebuild derived/canonical state only. Raw provider rows remain untouched.
  DELETE FROM public.zorg_contact_canonical_members;
  DELETE FROM public.zorg_contact_canonical_crm;
  DELETE FROM public.zorg_contact_dedupe_flags;

  WITH base AS (
    SELECT c.*,
      nullif(lower(c.email_primary), '') AS email_key,
      nullif(regexp_replace(coalesce(c.phone_primary,''), '[^0-9+]+', '', 'g'), '') AS phone_key,
      public.zorg_contact_norm_name(c.display_name) AS name_key
    FROM public.zorg_contacts_crm c
    WHERE coalesce(c.active, true) = true
  ), grouped AS (
    SELECT
      COALESCE('email:' || email_key, 'phone:' || phone_key, 'source:' || source || ':' || source_resource_name) AS canonical_key,
      CASE WHEN email_key IS NOT NULL THEN 'email' WHEN phone_key IS NOT NULL THEN 'phone' ELSE 'provider_resource' END AS dedupe_basis,
      array_agg(id ORDER BY updated_at DESC) AS ids,
      count(*) AS source_count,
      (array_agg(display_name ORDER BY (display_name IS NULL), updated_at DESC))[1] AS display_name,
      (array_agg(company ORDER BY (company IS NULL), updated_at DESC))[1] AS company,
      (array_agg(job_title ORDER BY (job_title IS NULL), updated_at DESC))[1] AS job_title,
      (array_agg(email_primary ORDER BY (email_primary IS NULL), updated_at DESC))[1] AS email_primary,
      (array_agg(phone_primary ORDER BY (phone_primary IS NULL), updated_at DESC))[1] AS phone_primary,
      string_agg(search_text, E'\n---\n' ORDER BY updated_at DESC) AS search_text,
      max(updated_at) AS updated_at
    FROM base
    GROUP BY COALESCE('email:' || email_key, 'phone:' || phone_key, 'source:' || source || ':' || source_resource_name),
             CASE WHEN email_key IS NOT NULL THEN 'email' WHEN phone_key IS NOT NULL THEN 'phone' ELSE 'provider_resource' END
  ), inserted AS (
    INSERT INTO public.zorg_contact_canonical_crm(
      canonical_key, display_name, company, job_title, email_primary, phone_primary,
      source_contact_ids, source_count, confidence, dedupe_basis, review_needed, review_reason,
      distilled_notes, search_text, updated_at
    )
    SELECT canonical_key, display_name, company, job_title, email_primary, phone_primary,
      ids, source_count,
      CASE WHEN dedupe_basis IN ('email','phone') THEN 0.98 ELSE 1.0 END,
      dedupe_basis,
      false,
      null,
      CASE WHEN source_count > 1 THEN 'Multiple provider contacts distilled by ' || dedupe_basis ELSE null END,
      search_text,
      updated_at
    FROM grouped
    RETURNING id, canonical_key, source_contact_ids, dedupe_basis
  )
  INSERT INTO public.zorg_contact_canonical_members(canonical_id, contact_id, match_basis, confidence)
  SELECT i.id, unnest(i.source_contact_ids), i.dedupe_basis,
    CASE WHEN i.dedupe_basis IN ('email','phone') THEN 0.98 ELSE 1.0 END
  FROM inserted i;

  -- Flag name-only collisions for review, without merging.
  WITH name_groups AS (
    SELECT public.zorg_contact_norm_name(display_name) AS name_key,
           min(display_name) AS display_name,
           array_agg(id ORDER BY updated_at DESC) AS ids,
           count(*) AS c,
           count(distinct nullif(lower(email_primary), '')) AS email_count,
           count(distinct nullif(regexp_replace(coalesce(phone_primary,''), '[^0-9+]+', '', 'g'), '')) AS phone_count
    FROM public.zorg_contacts_crm
    WHERE coalesce(active,true) = true
      AND public.zorg_contact_norm_name(display_name) IS NOT NULL
    GROUP BY public.zorg_contact_norm_name(display_name)
    HAVING count(*) > 1
  )
  INSERT INTO public.zorg_contact_dedupe_flags(flag_key, flag_type, contact_ids, display_name, evidence)
  SELECT 'name_collision:' || name_key,
         'name_collision_review',
         ids,
         display_name,
         jsonb_build_object('count', c, 'distinct_email_count', email_count, 'distinct_phone_count', phone_count, 'reason', 'same normalized display name; not auto-merged without stronger email/phone evidence')
  FROM name_groups;

  -- Mark canonical groups with multiple source rows as not needing review when strong evidence exists.
  UPDATE public.zorg_contact_canonical_crm
     SET search_text = concat_ws(E'\n',
       'Canonical contact: ' || coalesce(display_name,''),
       'Company: ' || coalesce(company,''),
       'Title: ' || coalesce(job_title,''),
       'Primary email: ' || coalesce(email_primary,''),
       'Primary phone: ' || coalesce(phone_primary,''),
       'Dedupe basis: ' || coalesce(dedupe_basis,''),
       'Source count: ' || source_count::text,
       search_text
     ),
     updated_at = now();

  PERFORM public.zorg_refresh_memory_search();

  RETURN QUERY
  SELECT
    (SELECT count(*)::integer FROM public.zorg_contact_canonical_crm WHERE active),
    (SELECT count(*)::integer FROM public.zorg_contact_canonical_members),
    (SELECT count(*)::integer FROM public.zorg_contact_dedupe_flags WHERE review_status='open');
END;
$$;

CREATE OR REPLACE VIEW public.zorg_contact_duplicates_review_v AS
SELECT
  f.id,
  f.flag_type,
  f.display_name,
  array_length(f.contact_ids, 1) AS contact_count,
  f.evidence,
  f.review_status,
  f.created_at,
  f.updated_at
FROM public.zorg_contact_dedupe_flags f
WHERE f.review_status = 'open';

CREATE OR REPLACE VIEW public.zorg_contacts_crm_recall_v AS
SELECT
  'contact'::text AS source_table,
  c.id::text AS source_id,
  c.updated_at AS event_ts,
  CASE WHEN c.review_needed THEN 'contact_crm_review' ELSE 'contact_crm' END AS category,
  CASE WHEN c.review_needed THEN 'medium' ELSE 'high' END AS priority,
  c.search_text AS content
FROM public.zorg_contact_canonical_crm c
WHERE coalesce(c.active, true) = true;

-- CONTACTS_CRM_DEDUPE_SCHEMA_END

-- RECURSIVE_LOGIC_RULES_SCHEMA_START
-- Additive recursive logic / proactive quality-control layer for Zorg MemoryDB.
-- Stores deduced operating logic, source basis, and standard precaution checks.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS public.zorg_logic_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key text NOT NULL UNIQUE,
  title text NOT NULL,
  rule_text text NOT NULL,
  rule_type text NOT NULL DEFAULT 'deduced_operating_logic',
  priority text NOT NULL DEFAULT 'high',
  privacy_scope text NOT NULL DEFAULT 'private',
  source_basis text NOT NULL DEFAULT 'operator_instruction',
  applies_to text[] NOT NULL DEFAULT ARRAY[]::text[],
  standard_checks text[] NOT NULL DEFAULT ARRAY[]::text[],
  performance_tuning_notes text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.zorg_logic_rule_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key text NOT NULL REFERENCES public.zorg_logic_rules(rule_key) ON DELETE CASCADE,
  source_type text NOT NULL,
  source_ref text,
  source_summary text NOT NULL,
  private_context boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.zorg_logic_rule_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key text NOT NULL REFERENCES public.zorg_logic_rules(rule_key) ON DELETE CASCADE,
  applied_at timestamptz NOT NULL DEFAULT now(),
  task_category text,
  object_type text,
  object_ref text,
  check_performed text NOT NULL,
  result_summary text,
  followup_needed boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_type_priority ON public.zorg_logic_rules(rule_type, priority);
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_applies_gin ON public.zorg_logic_rules USING gin(applies_to);
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_text_trgm ON public.zorg_logic_rules USING gin ((title || E'\n' || rule_text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rules_text_fts_en ON public.zorg_logic_rules USING gin (to_tsvector('english', title || E'\n' || rule_text));
CREATE INDEX IF NOT EXISTS idx_zorg_logic_rule_apps_key_time ON public.zorg_logic_rule_applications(rule_key, applied_at DESC);

CREATE OR REPLACE FUNCTION public.zorg_logic_rule_content(r public.zorg_logic_rules)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT concat_ws(E'\n',
    'Logic rule: ' || coalesce(r.title,''),
    'Key: ' || coalesce(r.rule_key,''),
    'Type: ' || coalesce(r.rule_type,''),
    'Priority: ' || coalesce(r.priority,''),
    'Privacy: ' || coalesce(r.privacy_scope,''),
    'Source basis: ' || coalesce(r.source_basis,''),
    'Rule: ' || coalesce(r.rule_text,''),
    'Applies to: ' || coalesce(array_to_string(r.applies_to, ', '),''),
    'Standard checks: ' || coalesce(array_to_string(r.standard_checks, '; '),''),
    'Performance tuning: ' || coalesce(r.performance_tuning_notes,'')
  )
$$;

CREATE OR REPLACE VIEW public.zorg_logic_rules_recall_v AS
SELECT
  'logic_rule'::text AS source_table,
  r.id::text AS source_id,
  r.updated_at AS event_ts,
  r.rule_type AS category,
  r.priority,
  public.zorg_logic_rule_content(r) AS content
FROM public.zorg_logic_rules r
WHERE coalesce(r.active,true) = true;

CREATE OR REPLACE FUNCTION public.zorg_get_logic_context(p_query text, p_limit integer DEFAULT 5)
RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
LANGUAGE sql
AS $$
  SELECT
    'logic_rule'::text,
    r.id::text,
    null::text,
    null::integer,
    null::integer,
    r.priority,
    public.zorg_logic_rule_content(r)
  FROM public.zorg_logic_rules r
  WHERE coalesce(r.active,true) = true
    AND (
      lower(r.title || E'\n' || r.rule_text || E'\n' || coalesce(array_to_string(r.applies_to,' '),'')) LIKE '%' || lower(coalesce(p_query,'')) || '%'
      OR to_tsvector('english', r.title || E'\n' || r.rule_text || E'\n' || coalesce(array_to_string(r.applies_to,' '),'')) @@ plainto_tsquery('english', coalesce(p_query,''))
      OR to_tsvector('simple', r.title || E'\n' || r.rule_text || E'\n' || coalesce(array_to_string(r.applies_to,' '),'')) @@ plainto_tsquery('simple', coalesce(p_query,''))
    )
  ORDER BY
    CASE WHEN lower(r.priority)='critical' THEN 1 WHEN lower(r.priority)='high' THEN 2 WHEN lower(r.priority)='medium' THEN 3 ELSE 4 END,
    r.updated_at DESC
  LIMIT greatest(coalesce(p_limit,5),1);
$$;

CREATE OR REPLACE FUNCTION public.zorg_recall_context(p_query text, p_limit integer DEFAULT 10)
 RETURNS TABLE(source_type text, source_id text, path text, line_start integer, line_end integer, priority text, content text)
 LANGUAGE sql
AS $$
  with combined as (
    select * from public.zorg_get_logic_context(p_query, greatest(1, coalesce(p_limit, 10) / 3))
    union all
    select * from public.zorg_get_runbook_context(p_query, greatest(1, coalesce(p_limit, 10) / 2))
    union all
    select * from public.zorg_get_project_context(p_query, greatest(1, coalesce(p_limit, 10) / 2))
    union all
    select * from public.zorg_get_host_context(p_query, greatest(1, coalesce(p_limit, 10) / 3))
    union all
    select
      case z.source_table
        when 'directive' then 'directive'
        when 'runbook' then 'runbook'
        when 'project' then 'project'
        when 'project_fact' then 'project_fact'
        when 'host' then 'host'
        when 'service' then 'service'
        when 'relationship' then 'relationship'
        when 'operational_fact' then 'operational_fact'
        when 'contact' then 'contact'
        when 'logic_rule' then 'logic_rule'
        else 'memory'
      end as source_type,
      z.source_id,
      null::text as path,
      null::integer as line_start,
      null::integer as line_end,
      coalesce(z.priority, 'medium') as priority,
      z.snippet as content
    from public.zorg_search_memory(p_query, greatest(coalesce(p_limit, 10), 1)) z
  )
  select distinct on (source_type, source_id, content)
    source_type, source_id, path, line_start, line_end, priority, content
  from combined
  order by source_type, source_id, content,
    case when lower(priority) = 'critical' then 1
         when lower(priority) = 'high' then 2
         when lower(priority) = 'medium' then 3
         else 4 end
  limit greatest(coalesce(p_limit, 10), 1);
$$;

INSERT INTO public.zorg_logic_rules(rule_key,title,rule_text,rule_type,priority,privacy_scope,source_basis,applies_to,standard_checks,performance_tuning_notes)
VALUES
('standard-precautions-for-new-memory-features','Standard precautions for new memory/database features','When creating a new memory, CRM, recall, schema, automation, or data-ingestion feature, proactively check the obvious integrity and usability risks before claiming success. The CRM example is the lesson: after first building contact import, duplicate/distilled contact checks should have been an automatic quality gate. Future features need recursive self-checks such as duplicate detection, count reconciliation, source preservation, recall integration, index/performance checks, privacy boundary checks, sync/recovery verification, and representative query tests.','proactive_quality_control','critical','private','operator_instruction_plus_crm_dedupe_lesson',ARRAY['memory_db','crm','contacts','schema','data_import','recall','automation'],ARRAY['Check for duplicates or ambiguous canonicalization','Verify raw/source data preservation','Verify derived/canonical view is used for recall','Run representative recall/search queries','Check indexes/materialized views/performance impact','Check privacy/publication boundary','Record follow-up review flags instead of deleting uncertain data'], 'Additive structures only; use indexes/materialized views/observations to preserve speed while adding richer logic.'),
('recursive-logic-extraction-and-application','Recursive logic extraction and application','Treat operator rules, explicit examples, private relationship context, public-safe executive-assistant playbook principles, and observed mistakes as source material for deduced operating logic. Convert them into reusable decision structures that shape future behavior before escalation: protect the operator time, design the play, close loops, prioritize revenue/time/reputation, answer clearly and kindly, and anticipate problems. Use private person context silently for better decisions and communications, never as outward disclosure unless explicitly authorized.','recursive_decision_logic','critical','private','operator_instruction_plus_executive_assistant_playbook',ARRAY['email','calendar','contacts','crm','public_private_filter','task_prioritization','quality_control','decision_making'],ARRAY['Before acting, identify applicable explicit and deduced rules','Use private context as a silent decision filter','Infer adjacent safeguards from the task type','Close the loop or create a durable waiting item','Escalate with concise options only after self-service paths are exhausted'], 'Store rules as structured rows; tune recall queries/indexes so logic rules surface quickly for related tasks.'),
('executive-assistant-proactive-final-checks','Executive assistant proactive final checks','For executive-assistant work, perform final checks proactively: verify the affected surface, confirm counts/status, inspect likely edge cases, reduce repeat noise, preserve follow-up state, and prepare concise options only when a decision is actually needed. This distills the playbook pattern of protecting time, being preemptive, and coming prepared.','executive_assistant_logic','high','private','dan_martell_playbook_distillation',ARRAY['email','calendar','travel','contacts','crm','website','publishing','monitoring'],ARRAY['Confirm the intended recipient/time/context','Check for duplicate or stale records when building lists/databases','Verify the live result or affected endpoint','Mark reported items read / prevent repeat reporting where applicable','Create reminders/waiting states for unresolved loops'], 'Track which final checks prevent errors and promote recurring checks into indexes/rules/runbooks when useful.'),
('db-backup-before-tuning-and-recall-failure-gate','DB backup before tuning and recall-failure production-change gate','Before any production database structural, indexing, materialized-view, recall-routing, vector/embedding, weighted-association, neural-memory, or schema change, create and verify a temporary local PostgreSQL backup only. Do not commit, mirror, or push database dumps to GitHub. Database tuning/redesign cron jobs must be LLM instruction jobs, not blind mutator scripts. Production DB/index/schema changes are allowed only when a real recall failure occurred: data existed in DB but was not returned immediately and surfaced only after deep/alternate/manual search or operator correction. If no recall failure exists, tuning jobs may only benchmark, research, design, and test additive structures in sandbox/temp contexts without altering production DB. Preserve all original DB data forever. Never publish private DB dumps/rows to public Zorg_MemoryDB. Off-host or encrypted recovery may be recommended only as a separately approved private operations setup, not as part of the public MemoryDB update path.','memory_recall_enforcement','critical','private','operator_instruction_2026_05_07',ARRAY['database','memory','backup','tuning','recovery','cron','recall_failure'],ARRAY['Run the configured PostgreSQL backup script before DB structural changes','Verify the temporary local PostgreSQL backup before changing production DB','Allow production DB tuning only after a real recall miss/deep-query recovery','If no recall failure exists, sandbox experiments only','Never copy private DB dumps to GitHub from the public MemoryDB update path'], 'Treat temporary local memory database backups as mandatory from scratch on fresh installs; tune only from observed recall misses or sandbox research.')
ON CONFLICT (rule_key) DO UPDATE SET
  title=excluded.title,
  rule_text=excluded.rule_text,
  rule_type=excluded.rule_type,
  priority=excluded.priority,
  privacy_scope=excluded.privacy_scope,
  source_basis=excluded.source_basis,
  applies_to=excluded.applies_to,
  standard_checks=excluded.standard_checks,
  performance_tuning_notes=excluded.performance_tuning_notes,
  updated_at=now(),
  active=true;

INSERT INTO public.zorg_logic_rule_sources(rule_key,source_type,source_ref,source_summary,private_context)
VALUES
('standard-precautions-for-new-memory-features','operator_example','CRM contact import duplicate miss','After building the CRM contact import, duplicate-name/canonicalization checks were not automatic; Stefan identified this as a standard logical precaution that should have happened proactively.',true),
('recursive-logic-extraction-and-application','operator_instruction','2026-05-05 recursive logic instruction','Stefan instructed Zorg to build recursive logic rules from explicit rules, deduced implications, private person context, and executive-assistant playbook logic, continuously tuning MemoryDB association structures.',true),
('executive-assistant-proactive-final-checks','public_safe_playbook_distillation','Dan Martell Exec Admin Playbook','Distilled public-safe principles: protect CEO time, be preemptive/design the play, prioritize revenue, answer clearly/kindly, solve problems before CEO escalation, and perform final checks.',false)
ON CONFLICT DO NOTHING;

-- RECURSIVE_LOGIC_RULES_SCHEMA_END
