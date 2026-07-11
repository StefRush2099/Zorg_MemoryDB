-- Canonical rule for real request-to-response timing without weakening DB recall.
INSERT INTO public.zorg_logic_rules (
  rule_key, title, rule_text, rule_type, priority, privacy_scope,
  source_basis, applies_to, standard_checks, active, updated_at
)
VALUES (
  'real-request-response-time-summary-2026-07-11',
  'Real Request-to-Response Time Summary',
  'After current-turn PostgreSQL/Zorg MemoryDB recall succeeds, the final visible reply must end with a Time summary line containing the real elapsed duration from the trusted inbound request timestamp through outbound reply preparation. Runtime code calculates it; model text, caller-supplied values, backend scan duration, cached context, and timing proof text are invalid sources. The timing line is reporting only and cannot satisfy, replace, reorder, or bypass the mandatory DB recall and repair gate. If DB recall is unavailable, repair it first; if repair fails, perform no unrelated work and report the memory failure.',
  'memory_recall_enforcement', 'critical', 'system_hard_mandatory',
  'operator_correction_2026_07_11',
  ARRAY['visible_replies','request_to_response_elapsed','inbound_timestamp','outbound_message','telegram','memory_recall']::text[],
  ARRAY['Capture trusted inbound request timestamp','Complete current-turn PostgreSQL/Zorg MemoryDB recall first','Calculate duration in runtime code immediately before final send','Place the real Time summary line last','Never use backend scan duration or caller text','Repair MemoryDB before unrelated work; fail closed if repair fails']::text[],
  true, now()
)
ON CONFLICT (rule_key) DO UPDATE SET
  title = excluded.title,
  rule_text = excluded.rule_text,
  rule_type = excluded.rule_type,
  priority = excluded.priority,
  privacy_scope = excluded.privacy_scope,
  source_basis = excluded.source_basis,
  applies_to = excluded.applies_to,
  standard_checks = excluded.standard_checks,
  active = true,
  updated_at = now();

UPDATE public.zorg_logic_rules
SET active = false, updated_at = now()
WHERE rule_key = 'visible-time-summary-elapsed-request-to-response-2026-06-26'
  AND rule_text ILIKE '%Retired by Stefan%';
