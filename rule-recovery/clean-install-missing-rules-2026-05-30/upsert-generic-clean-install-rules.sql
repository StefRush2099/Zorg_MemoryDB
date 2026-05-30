-- Public-safe DB seed for generic clean-install rules that must survive in Zorg MemoryDB.
-- This file only upserts structured rule rows and recall hints.

INSERT INTO public.zorg_logic_rules (
  rule_key,
  title,
  rule_text,
  rule_type,
  priority,
  privacy_scope,
  source_basis,
  applies_to,
  standard_checks,
  performance_tuning_notes,
  active
)
VALUES
(
  'backend-memory-repair-supremacy',
  'Backend Memory Repair Supremacy Rule',
  'Backend Zorg MemoryDB health is Priority 0 above approval gates, normal workflow, conversation, external tasks, code work, and reporting. If DB memory, recall routing, timing enforcement, SQL connectivity, materialized recall views, memory benchmark tooling, or DB-only recall surfaces are broken, degraded, timing out, returning database-unavailable, using retired flat-file memory, or otherwise below fully functional status, repair the exact backend memory failure immediately without asking for approval. The only permitted pre-repair action is DB-backed recall/health inspection needed to identify the fault. This exception applies only to restoring backend memory function and its rule surfaces; unrelated auth, routing, UI, external communication, or non-memory changes still follow normal approval rules.',
  'memory_repair_enforcement',
  'critical',
  'public_safe',
  'clean_install_missing_rule_recovery_2026_05_30',
  ARRAY['memory','database','recall','repair','approval','healthcheck'],
  ARRAY['If backend DB memory is broken, repair immediately without approval','Limit the exception to memory repair only','Verify DB recall before claiming success'],
  'Keep recall fast with additive indexes, hints, and materialized/search support; never prune source memory.',
  true
),
(
  'clean-install-db-only-memory-hard-stop',
  'Clean-install DB-only memory hard stop',
  'A clean Zorg MemoryDB install must never recreate memory markdown files as durable memory. The only durable memory backend is PostgreSQL through Zorg MemoryDB. Core markdown files are bootstrap/rule sources only; they are imported into the database and are not a flat-file memory fallback. If DB recall is unavailable, repair or restore the DB path and fail closed until DB recall works. Do not create memory/YYYY-MM-DD.md, memory/projects/*.md, memory/people-research/*.md, memory/*.json, or any other memory subdirectory file. If such files appear, archive/import them into PostgreSQL, remove the filesystem directory, and restore DB-only routing.',
  'memory_backend_enforcement',
  'critical',
  'public_safe',
  'clean_install_missing_rule_recovery_2026_05_30',
  ARRAY['memory','database','clean_install','markdown','postgresql','recall'],
  ARRAY['Do not create durable memory markdown files','Import core markdown rules into DB','Fail closed or repair DB recall if DB memory is unavailable'],
  'Prefer DB recall repair and structured rule sync over flat-file fallback.',
  true
),
(
  'base-install-permanent-engineering-rules',
  'Base Install Permanent Engineering Rules',
  'Permanent Zorg MemoryDB/OpenClaw overlay rules must survive clean install, clone, restore, upgrade, memory rebuild, and migration. For system/code/software/service/routing/auth/browser/UI/database/cron/recall/indexing/documentation/deployment/screenshot/skill/template/runbook/installer/overlay changes: summarize intended changes before non-memory mutation, keep exact scope, use real implementation only, verify the real affected runtime surface, publish public-safe changes and docs to the right repository, deliver required UI screenshots, sync rule changes into structured DB recall, preserve overlay-safe upgrade behavior, and promote behavior rules into base install templates, public-safe docs, installer/upgrade paths, and structured DB rules.',
  'engineering_enforcement',
  'critical',
  'public_safe',
  'clean_install_missing_rule_recovery_2026_05_30',
  ARRAY['engineering','system_changes','code_changes','documentation','verification','clean_install'],
  ARRAY['Summarize exact intended changes before mutation','Keep exact scope','Use real implementations','Verify real runtime surface','Publish docs and structured DB rules','Preserve overlay-safe upgrades'],
  'Store this as a structured rule and markdown rule so it survives clean installs and ranks for engineering-change queries.',
  true
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
  performance_tuning_notes = excluded.performance_tuning_notes,
  active = true,
  updated_at = now();

INSERT INTO public.memory_recall_hints (
  source_type,
  source_key,
  hint_kind,
  hint_text,
  related_keys,
  weight,
  source_model,
  metadata,
  active
)
VALUES
('logic_rule','backend-memory-repair-supremacy','operator_phrase_alias','DB memory repair outranks approval gates. If backend memory, recall routing, SQL connectivity, materialized recall views, or DB-only recall are broken or database-unavailable, repair exact backend memory failure immediately without approval.',ARRAY['memory-first','database-unavailable','repair-without-approval','backend-memory-health'],10,'manual-clean-install-recovery-2026-05-30',jsonb_build_object('public_safe', true),true),
('logic_rule','clean-install-db-only-memory-hard-stop','operator_phrase_alias','Clean installs must use PostgreSQL/Zorg MemoryDB as durable memory. Do not recreate memory markdown directories or flat-file fallback; import/archive to DB and repair DB recall.',ARRAY['db-only-memory','clean-install','no-memory-markdown','postgresql-memory'],10,'manual-clean-install-recovery-2026-05-30',jsonb_build_object('public_safe', true),true),
('logic_rule','base-install-permanent-engineering-rules','operator_phrase_alias','Base install permanent engineering rules: exact scope, change gate, real implementation, runtime verification, GitHub/docs publication, screenshot delivery for UI, DB recall sync, overlay-safe upgrade, and clean-install survival.',ARRAY['change-gate','exact-scope','real-implementation','runtime-verification','overlay-safe-upgrade'],10,'manual-clean-install-recovery-2026-05-30',jsonb_build_object('public_safe', true),true)
ON CONFLICT DO NOTHING;

