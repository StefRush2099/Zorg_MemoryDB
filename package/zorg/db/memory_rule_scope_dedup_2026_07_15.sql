-- Public-safe clean-install migration for v2.0.17.
-- Private operator overlays are intentionally not exported here.

update public.zorg_logic_rules
set rule_text = 'Use current-install variables for predictable database backup and recovery paths: OPENCLAW_WORKSPACE (or WORKSPACE_DIR) for workspace-relative backups and OPENCLAW_HOME for OpenClaw home backups. If DB access fails, try safe repair first; if repair fails, test configured backups until a working DB is found, promote it, refresh recall surfaces, and verify with DB health/recall tests. Never embed an installation-specific absolute path in this rule or its public deployment package.',
    privacy_scope = 'system_hard_mandatory',
    updated_at = now()
where rule_key = 'canonical-ea-email-calendar-contact-33-database-backup-and-recovery-paths';

-- Preserve old embeddings for audit, but exclude inactive source rules from
-- the filtered ANN/HNSW retrieval surface.
update public.memory_ann_model_embeddings m
set active = false, updated_at = now()
where m.source_type = 'logic_rule'
  and exists (
    select 1 from public.zorg_logic_rules r
    where r.id::text = m.source_key and not r.active
  );

insert into public.zorg_logic_rules
  (rule_key,title,rule_text,rule_type,priority,privacy_scope,source_basis,applies_to,standard_checks,active)
values
  ('db-before-visible-response-proof-2026-07-15',
   'Backend DB recall and visible-response proof',
   'Before every visible response, perform current-turn PostgreSQL/Zorg MemoryDB recall for the request, relevant rules, and related history. Preserve the trusted inbound timestamp and, immediately before the visible send attempt, calculate the real wall-clock elapsed duration. Fail closed if recall or either trusted timestamp is missing. End the visible response with the runtime-generated Time summary line.',
   'memory_recall_enforcement','critical','system_hard_mandatory',
   'zorg-db-memory_rule-normalization_2026-07-15',
   array['memory_recall','visible_response','timing','fail_closed'],
   array['Run DB recall before response composition','Use trusted current-turn timestamps','Fail closed on missing recall or timing'],true)
on conflict (rule_key) do update set active=true, updated_at=now();

insert into public.zorg_logic_rule_dynamic_weights
  (rule_key,seed_weight,dynamic_weight,feedback_basis,metadata)
values ('db-before-visible-response-proof-2026-07-15',90000,90000,
        'rule-normalization-2026-07-15','{"canonical":true,"preflight_aware":true}'::jsonb)
on conflict (rule_key) do update set dynamic_weight=greatest(zorg_logic_rule_dynamic_weights.dynamic_weight, excluded.dynamic_weight), updated_at=now();
