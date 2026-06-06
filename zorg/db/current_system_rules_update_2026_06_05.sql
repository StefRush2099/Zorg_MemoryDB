-- Public-safe current system rule update for Zorg MemoryDB installs.
--
-- This seed publishes reusable operating rules only. It does not include
-- private memory rows, transcripts, credentials, contacts, screenshots,
-- live database dumps, or operator-private context.

insert into public.zorg_logic_rules (
  rule_key,
  rule_title,
  rule_type,
  priority,
  privacy,
  source_path,
  rule_text,
  applies_to
)
values
(
  'visible-ui-four-screenshot-proof',
  'Visible UI Four-Screenshot Proof',
  'verification_rule',
  'critical',
  'public_safe',
  'zorg/db/current_system_rules_update_2026_06_05.sql',
  'Visible UI/runtime work is not complete until the real affected browser surface is verified and visual proof is delivered to the operator. For visible UI changes, capture and deliver desktop light, desktop dark, mobile/cellphone light, and mobile/cellphone dark screenshots unless a specific mode is blocked and the blocker is reported.',
  array['ui','visual-proof','screenshots','verification','telegram']
),
(
  'lan-command-chat-browser-proof-required',
  'LAN Command Chat Browser Proof Required',
  'verification_rule',
  'critical',
  'public_safe',
  'zorg/db/current_system_rules_update_2026_06_05.sql',
  'LAN command chat repairs, polling changes, rebuilds, service restarts, and UI/runtime claims require browser-level proof against the live console, not API 200 responses alone. Verification must show the page hydrated with readout panels, DB gauges, PostgreSQL live readout, and conversation/activity surfaces present.',
  array['lan-chat','browser','runtime-proof','readouts','verification']
),
(
  'lan-command-chat-install-build-contract',
  'LAN Command Chat Install and Build Contract',
  'install_process',
  'critical',
  'public_safe',
  'zorg/db/current_system_rules_update_2026_06_05.sql',
  'Zorg MemoryDB clean installs and explicit existing-install upgrades must copy the LAN command chat source, create .env.local from the packaged example when missing, run its dependency install and production build as part of the add-on bootstrap, and create/restart the lan-chat service when the host supports systemd. LAN command chat is base communication infrastructure, not an optional side app.',
  array['lan-chat','install','upgrade','service','communication']
),
(
  'lan-command-chat-polling-backpressure',
  'LAN Command Chat Polling Backpressure',
  'performance_rule',
  'high',
  'public_safe',
  'zorg/db/current_system_rules_update_2026_06_05.sql',
  'LAN command chat browser polling must be configurable and conservative enough to avoid gateway or PostgreSQL pressure. Hidden tabs should stop polling and refresh once when visible again. Read-only history refreshes must not write activity rows or otherwise amplify polling load.',
  array['lan-chat','gateway','postgresql','polling','performance']
),
(
  'restart-after-lan-chat-build',
  'Restart After LAN Chat Build',
  'deployment_rule',
  'high',
  'public_safe',
  'zorg/db/current_system_rules_update_2026_06_05.sql',
  'After rebuilding LAN command chat, restart the live Next service before claiming the console is fixed. A running next start process can serve stale client chunks after .next changes, leaving the page unresponsive even when API endpoints return 200.',
  array['lan-chat','nextjs','build','restart','deployment']
),
(
  'existing-database-preservation-guard',
  'Existing Database Preservation Guard',
  'install_process',
  'critical',
  'public_safe',
  'zorg/db/current_system_rules_update_2026_06_05.sql',
  'Zorg MemoryDB installers and upgrade bootstraps must not overwrite or mutate an existing non-empty PostgreSQL database with a different or incompatible schema. If the configured database already contains non-Zorg tables or incompatible Zorg-named tables, skip DB schema/seed/config mutation, preserve any existing sql_memory_map.json, and require the operator to choose a fresh DB or explicitly authorize non-empty DB bootstrap.',
  array['database','install','upgrade','schema','preservation']
),
(
  'no-live-install-tests-without-authorization',
  'No Live Install Tests Without Authorization',
  'operating_rule',
  'critical',
  'public_safe',
  'zorg/db/current_system_rules_update_2026_06_05.sql',
  'Do not run install or upgrade tests against the current agent host, other operator systems, or live environment hosts unless the operator explicitly authorizes that install-test target in the current task. Repo-only static verification is allowed when the operator has prohibited install tests.',
  array['install','upgrade','testing','live-systems','change-control']
),
(
  'public-safe-github-publication-scope',
  'Public-Safe GitHub Publication Scope',
  'publication_rule',
  'critical',
  'public_safe',
  'zorg/db/current_system_rules_update_2026_06_05.sql',
  'When publishing Zorg MemoryDB changes to GitHub, include public-safe schema, scripts, templates, LAN command chat source, docs, and sanitized rule seeds needed for clean installs and upgrades. Do not publish private memory rows, credentials, transcripts, contacts, live uploads, screenshots with private content, or operator-only context.',
  array['github','publication','privacy','clean-install','upgrade']
)
on conflict (rule_key) do update
set rule_title = excluded.rule_title,
    rule_type = excluded.rule_type,
    priority = excluded.priority,
    privacy = excluded.privacy,
    source_path = excluded.source_path,
    rule_text = excluded.rule_text,
    applies_to = excluded.applies_to,
    updated_at = now();
