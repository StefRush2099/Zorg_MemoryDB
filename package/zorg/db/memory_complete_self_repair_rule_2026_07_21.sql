begin;

insert into public.zorg_logic_rules
(rule_key,title,rule_text,rule_type,priority,privacy_scope,source_basis,applies_to,standard_checks,performance_tuning_notes,active)
values
('zorg-memorydb-proactive-complete-self-repair',
 'Zorg MemoryDB Proactive Complete Self-Repair Rule',
 'When any Zorg MemoryDB component is missing, disabled, stale, inconsistent, unhealthy, or below verified full health, diagnose and repair every affected in-scope layer before declaring success. This includes PostgreSQL schema/functions, scheduler rows and firing layer, dispatcher/worker services, plugin/MCP routing, semantic/ANN/vector derived layers, connected LAN Chat and Neural Recall Activity verification, installer/package durability, and focused live proof. Preserve source memory and history. Use additive or reversible repairs where possible. This rule does not bypass the operator''s approval gates, authorize destructive data loss, expose secrets, or authorize unrelated external actions.',
 'memory_safety_repair','critical','private','operator_instruction_2026_07_21',
 array['zorg_memorydb','postgresql','scheduler','plugin_mcp','ann_vector','semantic_worker','lan_chat','memory_3d'],
 array['Repair all affected in-scope layers','Verify live PostgreSQL and MCP paths','Preserve source history','Do not bypass approval or destructive-action gates'],
 'Operator required Zorg to always completely repair detected MemoryDB faults and reach verified full health.',true)
on conflict (rule_key) do update set
 title=excluded.title, rule_text=excluded.rule_text, rule_type=excluded.rule_type,
 priority=excluded.priority, privacy_scope=excluded.privacy_scope, source_basis=excluded.source_basis,
 applies_to=excluded.applies_to, standard_checks=excluded.standard_checks,
 performance_tuning_notes=excluded.performance_tuning_notes, active=true, updated_at=now();

insert into public.zorg_logic_rule_dynamic_weights(rule_key,seed_weight,dynamic_weight,feedback_basis,metadata)
values('zorg-memorydb-proactive-complete-self-repair',180,220,'operator_instruction_2026_07_21',jsonb_build_object('owner','zorg-memorydb','scope','complete safe in-scope repair'))
on conflict(rule_key) do update set
 seed_weight=greatest(zorg_logic_rule_dynamic_weights.seed_weight,180),
 dynamic_weight=greatest(zorg_logic_rule_dynamic_weights.dynamic_weight,220),
 feedback_basis=excluded.feedback_basis,
 metadata=zorg_logic_rule_dynamic_weights.metadata||excluded.metadata,
 updated_at=now();

commit;
