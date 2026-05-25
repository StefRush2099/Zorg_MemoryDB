-- Zorg MemoryDB base-install permanent engineering rules
-- Public-safe structural migration: inserts/updates the rule that system changes,
-- code writing, and software changes are permanent base-install rules.

insert into public.zorg_logic_rules (
  rule_key,
  title,
  rule_type,
  rule_text,
  priority,
  privacy_scope,
  source_basis,
  applies_to,
  standard_checks,
  active,
  created_at,
  updated_at
) values (
  'base-install-permanent-engineering-rules-2026-05-16',
  'Base Install Permanent Engineering Rules',
  'operating_rule',
  'System changes, code writing, code edits, software changes, service/routing/auth/browser/UI/database/cron/recall/indexing/documentation/deployment changes, and changes to skills/templates/runbooks/installers/project overlays are hard-coded Zorg MemoryDB/OpenClaw overlay rules, not personal operator preferences. They must survive clean install, clone, restore, upgrade, memory rebuild, and migration. Required behavior: state exact intended changes before mutation; keep exact requested scope; use real implementation only; verify real runtime before claiming success; publish system/project/rule/recall/docs changes to the correct GitHub repo with docs/runbooks/templates/skills; deliver desktop light, desktop dark, mobile light, and mobile dark screenshots for visible UI changes; sync rule/process changes into structured DB recall and verify natural-language recall; package Zorg MemoryDB as an additive OpenClaw overlay that preserves existing OpenClaw behavior/user data unless explicit migration says otherwise; promote every system/code/software rule into clean-install templates, public-safe docs, installer/upgrade paths, and DB structured rules.',
  'critical',
  'public_safe',
  'operator_instruction_2026_05_16',
  array['system_changes','code_writing','software_changes','services','routing','auth','browser','ui','database','cron','recall','indexing','documentation','deployment','skills','templates','installers','overlays','clean_install'],
  array['Before mutation state exact intended changes and affected surfaces','Change only exact requested scope','No fake/mock/display-only/disconnected implementation','Verify affected runtime before claiming done','Publish changes to correct GitHub repo with docs/templates/skills/runbooks','For visible UI deliver desktop light, desktop dark, mobile light, and mobile dark screenshots','Sync rules into structured DB recall and verify natural-language recall','Install/upgrade Zorg MemoryDB as an additive OpenClaw overlay preserving existing behavior/user data'],
  true,
  now(),
  now()
)
on conflict (rule_key) do update set
  title=excluded.title,
  rule_type=excluded.rule_type,
  rule_text=excluded.rule_text,
  priority=excluded.priority,
  privacy_scope=excluded.privacy_scope,
  source_basis=excluded.source_basis,
  applies_to=excluded.applies_to,
  standard_checks=excluded.standard_checks,
  active=true,
  updated_at=now();
