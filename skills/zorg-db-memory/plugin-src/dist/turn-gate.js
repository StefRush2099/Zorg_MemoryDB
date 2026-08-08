import { createHash, randomUUID } from "node:crypto";
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
     incident_id,started_at,completed_at)
    values($1::uuid,$2,$3,$4,$5,$6::jsonb,$7,$8::jsonb,$9::uuid,to_timestamp($10/1000.0),now())
    on conflict(run_id,session_key,request_hash) do update set
    receipt_id=excluded.receipt_id,status=excluded.status,recall_layers=excluded.recall_layers,
    result_count=excluded.result_count,broadening=excluded.broadening,incident_id=excluded.incident_id,
    started_at=excluded.started_at,completed_at=excluded.completed_at`, [id, state.runId, state.sessionKey, state.requestHash, recovered ? "recovered" : "complete",
        JSON.stringify(layers), rows.length, JSON.stringify({ broadened: rows.length < 8 }),
        state.incidentId || null, state.startedAt]);
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
        if (state.status === "complete")
            return;
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
