import { createHash, randomUUID } from "node:crypto";
const MANDATORY_RULE_KEYS = [
    "universal-visible-response-time-enforcement-2026-08-08",
    "unified-change-repair-summary-go-authorization-rule-v2-2026-08-09",
    "zorg-memorydb-automatic-complete-self-repair-2026-08-09",
    "self-created-blocker-repair-before-reporting-rule-2026-05-20",
];
const ruleKey = (row) => {
    const content = String(row.content || row.row_data?.content || "");
    return content.match(/^Key:\s*([^\n]+)$/m)?.[1]?.trim();
};
const validateVisibleText = (text, startedAt) => {
    const lines = text.replace(/\r\n/g, "\n").split("\n");
    const timeLines = lines.filter(line => line.startsWith("Time:"));
    const last = lines.at(-1) || "";
    const zone = new Intl.DateTimeFormat("en-US", { timeZone: "America/Los_Angeles", timeZoneName: "short" })
        .formatToParts(new Date()).find(p => p.type === "timeZoneName")?.value;
    const errors = [];
    if (timeLines.length !== 1)
        errors.push(`expected exactly one Time line; found ${timeLines.length}`);
    if (!last.startsWith("Time:"))
        errors.push("Time line must be the absolute final line");
    if (last.includes("Pacific time"))
        errors.push("Time line must not contain the words Pacific time");
    if (zone && !last.includes(zone))
        errors.push(`Time line must use ${zone}`);
    if (!/\((?:\d+s|\d+m \d{2}s|\d+h \d{2}m \d{2}s)\)$/.test(last))
        errors.push("Time line must end with measured elapsed duration");
    if (Date.now() < startedAt)
        errors.push("turn start time is invalid");
    return errors;
};
const runs = new Map();
const sessions = new Map();
const recovery = new Map();
const pendingRuns = new Map();
const pendingSessions = new Map();
const hash = (v) => createHash("sha256").update(v).digest("hex");
const ids = (ctx, prompt) => ({
    runId: ctx.runId || hash((ctx.sessionKey || "unknown") + "\0" + prompt),
    sessionKey: ctx.sessionKey || "unknown",
});
const category = (error) => {
    const e = error instanceof Error ? error : new Error(String(error));
    const code = String(e.code || "");
    const message = e.message.toLowerCase();
    if (code === "28P01")
        return "authentication_failed";
    if (code === "3D000")
        return "database_missing";
    if (code === "42501")
        return "permission_denied";
    if (code.startsWith("08") || /connect|econnrefused|socket|network/.test(message))
        return "connection_failed";
    if (/schema|relation .* does not exist|function .* does not exist/.test(message))
        return "memory_schema_unavailable";
    return "postgresql_error";
};
const elapsed = (start) => {
    const total = Math.max(0, Math.floor((Date.now() - start) / 1000));
    return `${Math.floor(total / 60)}m ${String(total % 60).padStart(2, "0")}s`;
};
async function ensureTables(query) {
    await query(`create table if not exists public.memory_turn_recall_receipts(
    receipt_id uuid primary key, run_id text not null, session_key text not null,
    request_hash text not null, status text not null check(status in ('complete','recovered')),
    recall_layers jsonb not null default '{}'::jsonb, result_count integer not null default 0,
    broadening jsonb not null default '{}'::jsonb, incident_id uuid,
    started_at timestamptz not null, completed_at timestamptz not null default now(),
    unique(run_id,session_key,request_hash))`);
    await query(`alter table public.memory_turn_recall_receipts
    add column if not exists mandatory_rule_keys jsonb not null default '[]'::jsonb,
    add column if not exists returned_rule_keys jsonb not null default '[]'::jsonb`);
    await query(`create table if not exists public.memory_recovery_events(
    incident_id uuid primary key, session_key text not null, failure_category text not null,
    detected_at timestamptz not null, restored_at timestamptz,
    verification jsonb not null default '{}'::jsonb)`);
}
async function receipt(query, state, rows, recovered) {
    const id = randomUUID();
    const layers = { critical_preflight: true, exact_aliases: true, structured_weighted: true,
        project_session_prior_success: true, cached_ann_additive: true };
    await query(`insert into public.memory_turn_recall_receipts
    (receipt_id,run_id,session_key,request_hash,status,recall_layers,result_count,broadening,
     incident_id,started_at,completed_at,mandatory_rule_keys,returned_rule_keys)
    values($1::uuid,$2,$3,$4,$5,$6::jsonb,$7,$8::jsonb,$9::uuid,to_timestamp($10/1000.0),now(),$11::jsonb,$12::jsonb)
    on conflict(run_id,session_key,request_hash) do update set
    receipt_id=excluded.receipt_id,status=excluded.status,recall_layers=excluded.recall_layers,
    result_count=excluded.result_count,broadening=excluded.broadening,incident_id=excluded.incident_id,
    started_at=excluded.started_at,completed_at=excluded.completed_at,
    mandatory_rule_keys=excluded.mandatory_rule_keys,returned_rule_keys=excluded.returned_rule_keys`, [id, state.runId, state.sessionKey, state.requestHash, recovered ? "recovered" : "complete",
        JSON.stringify(layers), rows.length, JSON.stringify({ broadened: rows.length < 8 }),
        state.incidentId || null, state.startedAt, JSON.stringify(state.mandatoryRuleKeys || []),
        JSON.stringify(state.returnedRuleKeys || [])]);
    state.receiptId = id;
}
const normalContext = (s, rows) => `[ZORG MEMORYDB RECEIPT ${s.receiptId}] Authoritative PostgreSQL recall completed for this exact turn.\n${JSON.stringify(rows)}`;
const downContext = (s) => `[ZORG MEMORYDB RECOVERY MODE]
The PostgreSQL turn preflight failed with sanitized category: ${s.failure}.
The original request is held. Do not execute or answer it from stale context.
Immediately send this one allowed alert:
"Zorg MemoryDB is unavailable. Database recovery mode is active. The current request is safely held and normal execution is paused."
Add failure category ${s.failure} and end with "Time summary: ${elapsed(s.startedAt)} elapsed."
Then use only direct PostgreSQL/network/service/configuration/plugin diagnostic and safe repair tools.
Never expose secrets, perform the held task, publish, mutate unrelated systems, or use flat-file/model memory.
Retry PostgreSQL until it completes or returns a real error; no elapsed deadline may skip recall.`;
const restoredContext = (s, rows) => `[ZORG MEMORYDB RESTORED]
PostgreSQL identity and complete recall were verified for the held request.
Send this one restoration alert:
"Zorg MemoryDB has been restored and verified. Complete PostgreSQL recall passed, and the held request is resuming."
Include verification facts and end with "Time summary: ${elapsed(s.startedAt)} elapsed."
Then restart the held request from the beginning using this recovered context:\n${JSON.stringify(rows)}`;
const recoveryTool = (name) => ["exec", "memory", "postgres", "gateway", "service", "process", "system", "network", "message", "telegram", "session_status"]
    .some(part => name.toLowerCase().includes(part));
export function registerZorgMemoryHooks(api, deps) {
    const prepareTurn = async (event, ctx) => {
        const k = ids(ctx, event.prompt);
        const existing = runs.get(k.runId);
        if (existing?.requestHash === hash(event.prompt) && existing.status !== "recovery")
            return;
        const old = recovery.get(k.sessionKey);
        const state = old
            ? { ...old, runId: k.runId }
            : { ...k, prompt: event.prompt, requestHash: hash(event.prompt), startedAt: Date.now(), status: "preparing" };
        runs.set(k.runId, state);
        sessions.set(k.sessionKey, state);
        try {
            await ensureTables(deps.query);
            const rows = await deps.recall(state.prompt, 20);
            if (!rows.length)
                throw new Error("memory recall returned no authoritative rows");
            if (rows.length < 8) {
                rows.push(...await deps.query("select row_data from public.memory_search_table_v1('all',$1,$2)", [state.prompt, 30]));
            }
            const mandatory = await deps.query(`select id::text source_id, 'logic_rule'::text source_type,
        concat_ws(E'\\n','Logic rule: '||title,'Key: '||rule_key,'Type: '||rule_type,
        'Priority: '||priority,'Privacy: '||privacy_scope,'Source basis: '||coalesce(source_basis,''),
        'Rule: '||rule_text,'Applies to: '||coalesce(array_to_string(applies_to,', '),''),
        'Standard checks: '||coalesce(array_to_string(standard_checks,'; '),''),
        'Performance tuning: '||coalesce(performance_tuning_notes,'')) content
        from public.zorg_logic_rules where active and rule_key=any($1::text[])
        order by array_position($1::text[],rule_key)`, [MANDATORY_RULE_KEYS]);
            const mandatoryKeys = mandatory.map(ruleKey).filter(Boolean);
            const missing = MANDATORY_RULE_KEYS.filter(key => !mandatoryKeys.includes(key));
            if (missing.length)
                throw new Error(`mandatory memory rules missing: ${missing.join(",")}`);
            const deduped = [...mandatory, ...rows.filter(row => !mandatoryKeys.includes(ruleKey(row) || ""))];
            rows.splice(0, rows.length, ...deduped);
            state.mandatoryRuleKeys = [...MANDATORY_RULE_KEYS];
            state.returnedRuleKeys = rows.map(ruleKey).filter(Boolean);
            const recovered = Boolean(old);
            state.status = recovered ? "restored" : "complete";
            await receipt(deps.query, state, rows, recovered);
            runs.set(k.runId, state);
            sessions.set(k.sessionKey, state);
            if (!recovered)
                return { prependContext: normalContext(state, rows) };
            state.alert = "restored";
            await deps.query(`update public.memory_recovery_events set restored_at=now(),verification=$2::jsonb
        where incident_id=$1::uuid`, [state.incidentId, JSON.stringify({ identity: true, rows: rows.length, receipt: state.receiptId })]);
            recovery.delete(k.sessionKey);
            return { prependContext: restoredContext(state, rows) };
        }
        catch (error) {
            const incidentId = old?.incidentId || randomUUID();
            state.status = "recovery";
            state.incidentId = incidentId;
            state.failure = category(error);
            state.alert = old ? undefined : "down";
            recovery.set(k.sessionKey, state);
            runs.set(k.runId, state);
            sessions.set(k.sessionKey, state);
            api.logger.error(`Zorg MemoryDB recovery mode: ${state.failure}; incident=${incidentId}`);
            return { prependContext: downContext(state) };
        }
    };
    api.on("agent_turn_prepare", prepareTurn, { priority: 1000 });
    api.on("llm_input", async (event, ctx) => {
        const runId = event.runId || ctx.runId || "";
        const sessionKey = ctx.sessionKey || "";
        const pending = prepareTurn({ prompt: event.prompt }, ctx).then(() => undefined);
        if (runId)
            pendingRuns.set(runId, pending);
        if (sessionKey)
            pendingSessions.set(sessionKey, pending);
        try {
            await pending;
        }
        finally {
            if (runId)
                pendingRuns.delete(runId);
            if (sessionKey)
                pendingSessions.delete(sessionKey);
        }
    }, { priority: 1000 });
    api.on("before_tool_call", async (event, ctx) => {
        await (pendingRuns.get(event.runId || ctx.runId || "") || pendingSessions.get(ctx.sessionKey || "") || Promise.resolve());
        const state = runs.get(event.runId || ctx.runId || "") || sessions.get(ctx.sessionKey || "");
        if (!state)
            return { block: true, blockReason: "Zorg MemoryDB receipt is missing for this turn." };
        if (state.status === "preparing")
            return { block: true, blockReason: "Zorg MemoryDB recall is still preparing the receipt for this turn." };
        if (state.status === "complete") {
            if (/message|telegram/i.test(event.toolName)) {
                const params = event.params || event.input || {};
                const visible = String(params.message || params.text || params.caption || "");
                const errors = validateVisibleText(visible, state.startedAt);
                if (errors.length)
                    return { block: true, blockReason: `MemoryDB response validation failed. Revise the same response and retry: ${errors.join("; ")}` };
            }
            return;
        }
        if (state.status === "restored") {
            if (state.alert === "restored" && /message|telegram/i.test(event.toolName)) {
                state.alert = undefined;
                state.status = "complete";
                return;
            }
            return { block: true, blockReason: "The MemoryDB restoration alert must be sent before normal execution resumes." };
        }
        if (!recoveryTool(event.toolName))
            return { block: true, blockReason: "Zorg MemoryDB recovery mode permits database repair tools only." };
        if (/message|telegram/i.test(event.toolName)) {
            if (state.alert === "down") {
                state.alert = undefined;
                return;
            }
            return { block: true, blockReason: "The database-down alert was already sent for this incident." };
        }
    }, { priority: 1000 });
    api.on("before_agent_finalize", async (event, ctx) => {
        const state = runs.get(event.runId || ctx.runId || "") || sessions.get(event.sessionKey || ctx.sessionKey || "");
        if (!state || state.status !== "complete")
            return { action: "revise", reason: "MemoryDB exact-turn receipt is not complete",
                retry: { instruction: "Run exact-turn MemoryDB recall, then produce the response again.", idempotencyKey: `memory-receipt-${event.runId || "unknown"}`, maxAttempts: 8 } };
        const errors = validateVisibleText(String(event.lastAssistantMessage || ""), state.startedAt);
        if (!errors.length)
            return { action: "continue" };
        return { action: "revise", reason: errors.join("; "), retry: { instruction: `Revise the response to satisfy these MemoryDB rules: ${errors.join("; ")}. Preserve the original request and recalled rules.`, idempotencyKey: `memory-response-${event.runId || "unknown"}`, maxAttempts: 8 } };
    }, { priority: 1000 });
    api.on("reply_payload_sending", async (event) => {
        await (pendingRuns.get(event.runId || "") || pendingSessions.get(event.sessionKey || "") || Promise.resolve());
        const state = runs.get(event.runId || "") || sessions.get(event.sessionKey || "");
        if (!state)
            return { cancel: true, reason: "Zorg MemoryDB receipt is missing." };
        if (state.status === "complete")
            return;
        return { cancel: true, reason: "Recovery notices must use the explicitly gated message path." };
    }, { priority: 1000 });
}
