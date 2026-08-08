begin;

insert into public.zorg_logic_rules
(rule_key,rule_title,rule_text,rule_type,priority,privacy,source_path,applies_to,active)
values
('zorg-memorydb-proactive-complete-self-repair',
 'Zorg MemoryDB Proactive Complete Self-Repair Rule',
 'When any Zorg MemoryDB component is missing, disabled, stale, inconsistent, unhealthy, or below verified full health, the active large language model must diagnose and repair every affected in-scope layer live with direct tools before declaring success. This includes PostgreSQL schema/functions, natural-language systemPrompt schedule rows, plugin/MCP routing, semantic/ANN/vector derived layers, connected LAN Chat and Neural Recall Activity verification, installer/package durability, privacy, and focused live proof. Task-execution scripts, autonomous workers, task timers, dispatchers, and delegated workflows are forbidden and must be permanently deleted after literal GO authorization. Preserve source memory and history. Use additive or reversible data repairs where possible. Standard checks: repair all affected in-scope layers live with direct tools; verify live PostgreSQL and MCP paths; preserve source history; delete forbidden task executors after GO; do not bypass approval or destructive-action gates. This rule does not bypass the operator''s approval gates, authorize destructive data loss, expose secrets, or authorize unrelated external actions.',
 'memory_safety_repair','critical','public_safe','package/zorg/db/memory_complete_self_repair_rule_2026_07_21.sql',
 array['zorg_memorydb','postgresql','scheduler','plugin_mcp','ann_vector','semantic_worker','lan_chat','memory_3d'],
 true)
on conflict (rule_key) do update set
 rule_title=excluded.rule_title, rule_text=excluded.rule_text, rule_type=excluded.rule_type,
 priority=excluded.priority, privacy=excluded.privacy, source_path=excluded.source_path,
 applies_to=excluded.applies_to, active=true, updated_at=now();

insert into public.zorg_logic_rule_dynamic_weights(rule_key,seed_weight,dynamic_weight,feedback_basis,metadata)
values('zorg-memorydb-proactive-complete-self-repair',180,220,'operator_instruction_2026_07_21',jsonb_build_object('owner','zorg-memorydb','scope','complete safe in-scope repair'))
on conflict(rule_key) do update set
 seed_weight=greatest(zorg_logic_rule_dynamic_weights.seed_weight,180),
 dynamic_weight=greatest(zorg_logic_rule_dynamic_weights.dynamic_weight,220),
 feedback_basis=excluded.feedback_basis,
 metadata=zorg_logic_rule_dynamic_weights.metadata||excluded.metadata,
 updated_at=now();

commit;
