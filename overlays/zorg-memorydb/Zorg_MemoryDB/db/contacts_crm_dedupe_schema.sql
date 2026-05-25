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
