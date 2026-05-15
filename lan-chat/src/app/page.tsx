"use client";

import { DragEvent, KeyboardEvent, useCallback, useEffect, useMemo, useRef, useState } from "react";

type Role = "assistant" | "user" | "system";

type ChatMessage = {
  id: string;
  role: Role;
  text: string;
  timestamp?: number;
};

type ChatAttachment = {
  name: string;
  type: string;
  size: number;
  url: string;
  path?: string;
  containerPath?: string;
};

type DialMetric = {
  value: number;
  min: number;
  max: number;
  unit: string;
  status: string;
};

type DbStatus = {
  sampledAt?: string;
  metrics?: Record<string, DialMetric>;
  details?: Record<string, number | string | undefined>;
  healthScore?: number;
  degraded?: boolean;
};

type QueryEntry = {
  id: string;
  kind?: string;
  title: string;
  query: string;
  result: string;
};

type DbQueries = {
  sampledAt?: string;
  entries?: QueryEntry[];
};

type ChatStatus = {
  sessionKey?: string;
  label?: string;
  model?: string;
  thinking?: string;
  tokensUsed?: number;
  tokensLimit?: number;
  tokensPercent?: number;
  agentId?: string;
  degraded?: boolean;
};

type ActivityEntry = {
  kind: "thinking" | "tool" | "result" | "assistant" | "user" | "status";
  label: string;
  detail?: string;
  timestamp?: number;
};

type ActivityPayload = {
  sampledAt?: string;
  active?: boolean;
  phase?: string;
  label?: string;
  events?: ActivityEntry[];
  degraded?: boolean;
};

const CHAT_POLL_MS = 3500;
const DB_POLL_MS = 1100;
const MAX_DROP_FILES = 12;
const STORAGE_KEY = "lan-chat:v2:draft";

const emptyStatus: ChatStatus = { label: "local", model: "unknown", thinking: "unknown" };

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function formatBytes(value?: number) {
  if (!value || value <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const index = Math.min(Math.floor(Math.log(value) / Math.log(1024)), units.length - 1);
  return `${(value / 1024 ** index).toFixed(index ? 1 : 0)} ${units[index]}`;
}

function formatTime(value?: number | string) {
  if (!value) return "never";
  const date = typeof value === "number" ? new Date(value) : new Date(value);
  if (Number.isNaN(date.getTime())) return "unknown";
  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}

function formatGHz(value: unknown) {
  const numeric = typeof value === "number" ? value : typeof value === "string" ? Number(value) : 0;
  return Number.isFinite(numeric) && numeric > 0 ? `${numeric.toFixed(2)} GHz` : "GHz n/a";
}

function roleLabel(role: Role, identity: string) {
  if (role === "assistant") return identity || "Assistant";
  if (role === "system") return "System";
  return "You";
}

function redactSensitiveText(text: string) {
  return text
    .replace(/sk-[A-Za-z0-9_-]{12,}/g, "sk-••••REDACTED••••")
    .replace(/(?:api[_-]?key|access[_-]?token|secret|password)\s*[:=]\s*[^\s`'\"]+/gi, (match) => {
      const separator = match.includes("=") ? "=" : ":";
      return `${match.split(separator)[0]}${separator}••••REDACTED••••`;
    });
}

function metricLabel(key: string) {
  const labels: Record<string, string> = {
    queriesPerSecond: "Queries / sec",
    cacheHitRatio: "Cache hit",
    writesPerSecond: "Writes / sec",
    dbSize: "Storage used",
  };
  return labels[key] || key.replace(/[A-Z]/g, (m) => ` ${m}`).trim();
}

function normalizeMetric(metric?: DialMetric): DialMetric {
  if (!metric) return { value: 0, min: 0, max: 100, unit: "", status: "unknown" };
  const min = Number.isFinite(metric.min) ? metric.min : 0;
  const max = Number.isFinite(metric.max) && metric.max !== min ? metric.max : 100;
  const value = Number.isFinite(metric.value) ? metric.value : 0;
  return { ...metric, min, max, value };
}

function Gauge({ label, metric }: { label: string; metric?: DialMetric }) {
  const safe = normalizeMetric(metric);
  const span = safe.max - safe.min || 1;
  const ratio = Math.min(1, Math.max(0, (safe.value - safe.min) / span));
  const angle = -122 + ratio * 244;
  const status = safe.status || "steady";
  return (
    <div className="gauge-card">
      <div className="gauge-meta">
        <span>{label}</span>
        <b className={`pill status-${status}`}>{status}</b>
      </div>
      <div className="gauge-face" style={{ ["--gauge-angle" as string]: `${angle}deg` }}>
        <div className="gauge-arc" />
        <div className="gauge-needle" />
        <div className="gauge-hub" />
        <div className="gauge-value">
          <strong>{Math.round(safe.value * 10) / 10}</strong>
          <span>{safe.unit}</span>
        </div>
      </div>
    </div>
  );
}

function MessageBubble({ message, identity }: { message: ChatMessage; identity: string }) {
  const chunks = redactSensitiveText(message.text).split("\n");
  return (
    <article className={cx("message", `message-${message.role}`)}>
      <header>
        <span>{roleLabel(message.role, identity)}</span>
        <time>{formatTime(message.timestamp)}</time>
      </header>
      <div className="message-body">
        {chunks.map((line, index) => (
          <p key={`${message.id}-${index}`}>{line || "\u00a0"}</p>
        ))}
      </div>
    </article>
  );
}

function QueryReadout({ payload, error }: { payload: DbQueries | null; error: string | null }) {
  const entries = payload?.entries ?? [];
  return (
    <section className="query-panel panel">
      <div className="panel-title-row">
        <div>
          <p className="eyebrow">PostgreSQL live readout</p>
        </div>
        <span className="mini">{payload?.sampledAt ? formatTime(payload.sampledAt) : "warming"}</span>
      </div>
      <div className="query-log">
        {error ? <div className="query-error">{error}</div> : null}
        {!error && entries.length === 0 ? <div className="query-empty">No active query pressure. Listening…</div> : null}
        {entries.map((entry) => (
          <div className="query-entry" key={entry.id}>
            <div className="query-title">{entry.title}</div>
            <code>{entry.query || "—"}</code>
            <span>{entry.result}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

export default function Home() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [status, setStatus] = useState<ChatStatus>(emptyStatus);
  const [activity, setActivity] = useState<ActivityPayload | null>(null);
  const [dbStatus, setDbStatus] = useState<DbStatus | null>(null);
  const [dbQueries, setDbQueries] = useState<DbQueries | null>(null);
  const [dbError, setDbError] = useState<string | null>(null);
  const [queryError, setQueryError] = useState<string | null>(null);
  const [identity, setIdentity] = useState("Assistant");
  const [draft, setDraft] = useState("");
  const [attachments, setAttachments] = useState<ChatAttachment[]>([]);
  const [sending, setSending] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [dragDepth, setDragDepth] = useState(0);
  const [lastSync, setLastSync] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [recording, setRecording] = useState(false);
  const [transcribing, setTranscribing] = useState(false);
  const [theme, setTheme] = useState<"light" | "dark">("light");
  const [compact, setCompact] = useState(false);

  const textRef = useRef<HTMLTextAreaElement | null>(null);
  const fileRef = useRef<HTMLInputElement | null>(null);
  const messagesRef = useRef<HTMLDivElement | null>(null);
  const bottomRef = useRef<HTMLDivElement | null>(null);
  const noticeTimerRef = useRef<number | null>(null);
  const recorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<BlobPart[]>([]);
  const streamRef = useRef<MediaStream | null>(null);

  const metrics = dbStatus?.metrics ?? {};
  const rawCpuGHz = Number(dbStatus?.details?.cpuGHz ?? 0);
  const cpuCapacityGHz = Number(dbStatus?.details?.cpuCapacityGHz ?? 0);
  const cpuGHz = formatGHz(rawCpuGHz);
  const cpuRatio = Math.min(1, Math.max(0, rawCpuGHz / Math.max(cpuCapacityGHz, 1)));
  const dragActive = dragDepth > 0;
  const canSend = (draft.trim().length > 0 || attachments.length > 0) && !sending && !uploading;

  const latestAssistant = useMemo(() => [...messages].reverse().find((m) => m.role === "assistant"), [messages]);

  const showNotice = useCallback((message: string | null, durationMs = 0) => {
    if (noticeTimerRef.current) {
      window.clearTimeout(noticeTimerRef.current);
      noticeTimerRef.current = null;
    }
    setNotice(message);
    if (message && durationMs > 0) {
      noticeTimerRef.current = window.setTimeout(() => {
        setNotice((current) => (current === message ? null : current));
        noticeTimerRef.current = null;
      }, durationMs);
    }
  }, []);

  const loadHistory = useCallback(async () => {
    const res = await fetch("/api/chat/history", { cache: "no-store" });
    if (!res.ok) throw new Error("chat history unavailable");
    const data = await res.json();
    setMessages(Array.isArray(data?.messages) ? data.messages : []);
    setLastSync(new Date().toISOString());
  }, []);

  const loadStatus = useCallback(async () => {
    const [chatRes, identityRes] = await Promise.allSettled([
      fetch("/api/chat/status", { cache: "no-store" }).then((r) => (r.ok ? r.json() : Promise.reject(new Error("status unavailable")))),
      fetch("/api/chat/identity", { cache: "no-store" }).then((r) => (r.ok ? r.json() : Promise.reject(new Error("identity unavailable")))),
    ]);
    if (chatRes.status === "fulfilled") setStatus(chatRes.value || emptyStatus);
    if (identityRes.status === "fulfilled" && typeof identityRes.value?.name === "string") setIdentity(identityRes.value.name);
  }, []);

  const loadActivity = useCallback(async () => {
    const res = await fetch("/api/chat/activity", { cache: "no-store" });
    if (!res.ok) throw new Error("activity unavailable");
    const data = await res.json();
    setActivity(data || null);
  }, []);

  const loadDb = useCallback(async () => {
    const [statusRes, queriesRes] = await Promise.allSettled([
      fetch("/api/db/status", { cache: "no-store" }).then((r) => (r.ok ? r.json() : Promise.reject(new Error("DB gauges unavailable")))),
      fetch("/api/db/queries", { cache: "no-store" }).then((r) => (r.ok ? r.json() : Promise.reject(new Error("Query readout unavailable")))),
    ]);
    if (statusRes.status === "fulfilled") {
      setDbStatus(statusRes.value);
      setDbError(null);
    } else setDbError(statusRes.reason instanceof Error ? statusRes.reason.message : "DB gauges unavailable");
    if (queriesRes.status === "fulfilled") {
      setDbQueries(queriesRes.value);
      setQueryError(null);
    } else setQueryError(queriesRes.reason instanceof Error ? queriesRes.reason.message : "Query readout unavailable");
  }, []);

  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) setDraft(saved);
    const savedTheme = localStorage.getItem("lan-chat:theme");
    setTheme(savedTheme === "dark" ? "dark" : "light");
    loadHistory().catch((err) => setNotice(err.message));
    loadStatus().catch(() => undefined);
    loadActivity().catch(() => undefined);
    loadDb().catch(() => undefined);
    const chatTimer = window.setInterval(() => {
      loadHistory().catch(() => undefined);
      loadStatus().catch(() => undefined);
      loadActivity().catch(() => undefined);
    }, CHAT_POLL_MS);
    const dbTimer = window.setInterval(() => loadDb().catch(() => undefined), DB_POLL_MS);
    return () => {
      window.clearInterval(chatTimer);
      window.clearInterval(dbTimer);
      if (noticeTimerRef.current) window.clearTimeout(noticeTimerRef.current);
      streamRef.current?.getTracks().forEach((track) => track.stop());
    };
  }, [loadActivity, loadDb, loadHistory, loadStatus]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, draft);
  }, [draft]);

  useEffect(() => {
    localStorage.setItem("lan-chat:theme", theme);
  }, [theme]);

  useEffect(() => {
    const el = messagesRef.current;
    if (!el) return;
    el.scrollTo({ top: el.scrollHeight, behavior: "smooth" });
  }, [messages, sending]);

  useEffect(() => {
    if (!textRef.current) return;
    textRef.current.style.height = "0px";
    textRef.current.style.height = `${Math.min(220, Math.max(88, textRef.current.scrollHeight))}px`;
  }, [draft]);

  async function uploadFiles(fileList: FileList | File[]) {
    const files = Array.from(fileList).filter((file) => file.size > 0).slice(0, MAX_DROP_FILES);
    if (!files.length) return;
    setUploading(true);
    setNotice(`Uploading ${files.length} file${files.length === 1 ? "" : "s"}…`);
    try {
      const form = new FormData();
      files.forEach((file) => form.append("files", file));
      const res = await fetch("/api/chat/upload", { method: "POST", body: form });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.error || "upload failed");
      const next = Array.isArray(data?.files) ? data.files : [];
      setAttachments((current) => [...current, ...next]);
      setNotice(`${next.length} file${next.length === 1 ? "" : "s"} attached. Drop more or send.`);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Upload failed");
    } finally {
      setUploading(false);
    }
  }

  async function sendMessage() {
    const message = draft.trim();
    if (!message && attachments.length === 0) return;
    setSending(true);
    showNotice("Dispatching to local OpenClaw session…");
    const optimistic: ChatMessage = {
      id: `local-${Date.now()}`,
      role: "user",
      text: [message, attachments.length ? attachments.map((a) => `📎 ${a.name} (${formatBytes(a.size)})`).join("\n") : ""].filter(Boolean).join("\n\n"),
      timestamp: Date.now(),
    };
    setMessages((current) => [...current, optimistic]);
    setDraft("");
    localStorage.removeItem(STORAGE_KEY);
    const outgoing = attachments;
    setAttachments([]);
    try {
      const res = await fetch("/api/chat/send", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message, attachments: outgoing, mode: "chat" }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.error || "send failed");
      showNotice(`Sent · ${data?.status || "started"}`, 1600);
      loadActivity().catch(() => undefined);
      window.setTimeout(() => {
        loadHistory().catch(() => undefined);
        loadActivity().catch(() => undefined);
      }, 1400);
    } catch (error) {
      showNotice(error instanceof Error ? error.message : "Send failed");
      setAttachments(outgoing);
      setDraft(message);
    } finally {
      setSending(false);
    }
  }

  function onKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
      event.preventDefault();
      void sendMessage();
    }
  }

  function onDragEnter(event: DragEvent<HTMLElement>) {
    event.preventDefault();
    setDragDepth((value) => value + 1);
  }

  function onDragLeave(event: DragEvent<HTMLElement>) {
    event.preventDefault();
    setDragDepth((value) => Math.max(0, value - 1));
  }

  function onDragOver(event: DragEvent<HTMLElement>) {
    event.preventDefault();
    event.dataTransfer.dropEffect = "copy";
  }

  function onDrop(event: DragEvent<HTMLElement>) {
    event.preventDefault();
    setDragDepth(0);
    if (event.dataTransfer.files?.length) void uploadFiles(event.dataTransfer.files);
  }

  async function toggleRecording() {
    if (recording) {
      recorderRef.current?.stop();
      setRecording(false);
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;
      chunksRef.current = [];
      const recorder = new MediaRecorder(stream);
      recorderRef.current = recorder;
      recorder.ondataavailable = (event) => {
        if (event.data.size) chunksRef.current.push(event.data);
      };
      recorder.onstop = async () => {
        stream.getTracks().forEach((track) => track.stop());
        setTranscribing(true);
        try {
          const blob = new Blob(chunksRef.current, { type: recorder.mimeType || "audio/webm" });
          const form = new FormData();
          form.append("audio", blob, "lan-chat-voice.webm");
          const res = await fetch("/api/transcribe", { method: "POST", body: form });
          const data = await res.json().catch(() => ({}));
          if (!res.ok) throw new Error(data?.error || "transcription failed");
          setDraft((current) => `${current}${current ? "\n" : ""}${data.text || ""}`);
          setNotice("Voice transcribed into the composer.");
        } catch (error) {
          setNotice(error instanceof Error ? error.message : "Voice transcription failed");
        } finally {
          setTranscribing(false);
        }
      };
      recorder.start();
      setRecording(true);
      setNotice("Recording voice note… tap again to stop.");
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Microphone unavailable");
    }
  }

  return (
    <main
      className={cx("console-shell", `theme-${theme}`, dragActive && "drag-hot", compact && "compact")}
      onDragEnter={onDragEnter}
      onDragLeave={onDragLeave}
      onDragOver={onDragOver}
      onDrop={onDrop}
    >
      <div className="ambient ambient-one" />
      <div className="ambient ambient-two" />
      {dragActive ? (
        <div className="drop-shield">
          <div>
            <span>DROP FILES</span>
            <strong>Attach directly to chat</strong>
            <p>No upload button required.</p>
          </div>
        </div>
      ) : null}

      <header className="topbar panel">
        <div>
          <p className="eyebrow">LAN Command Chat · port 3001</p>
          <h1>{identity}</h1>
          <p className="subtle">Local-first back channel for the operator, the agent, and authorized LAN agents.</p>
        </div>
        <div className="top-actions">
          <button className="ghost" onClick={() => setTheme((value) => (value === "light" ? "dark" : "light"))}>{theme === "light" ? "Dark" : "Light"} mode</button>
          <button className="ghost" onClick={() => setCompact((value) => !value)}>{compact ? "Roomy" : "Compact"}</button>
          <button className="ghost" onClick={() => void loadHistory()}>Refresh</button>
          <button className="primary" onClick={() => textRef.current?.focus()}>Command</button>
        </div>
      </header>

      <section className="status-strip">
        <div className="chip"><span>Session</span><b>{status.label || "main"}</b></div>
        <div className="chip"><span>Agent</span><b>{status.agentId || "main"}</b></div>
        <div className="chip wide"><span>Model</span><b>{status.model || "unavailable"}</b></div>
        <div className="chip"><span>Thinking</span><b>{status.thinking || "unknown"}</b></div>
        <div className="chip"><span>Sync</span><b>{formatTime(lastSync || undefined)}</b></div>
      </section>

      <div className="workspace-grid">
        <aside className="left-rail">
          <section className="panel gauge-panel">
            <div className="panel-title-row gauge-title-row">
              <span className={cx("health cpu-ghz", dbStatus?.degraded && "warn")}>{dbError || cpuGHz}</span>
              <div className="cpu-spike" aria-label="CPU GHz live level">
                <span style={{ ["--cpu-ratio" as string]: cpuRatio }} />
              </div>
            </div>
            <div className="gauges">
              <Gauge label={metricLabel("queriesPerSecond")} metric={metrics.queriesPerSecond} />
              <Gauge label={metricLabel("cacheHitRatio")} metric={metrics.cacheHitRatio} />
              <Gauge label={metricLabel("writesPerSecond")} metric={metrics.writesPerSecond} />
              <Gauge label={metricLabel("dbSize")} metric={metrics.dbSize} />
            </div>
            <div className="db-detail-grid">
              <span>DB size <b>{formatBytes(Number(dbStatus?.details?.dbSizeBytes ?? 0))}</b></span>
              <span>Free space <b>{formatBytes(Number(dbStatus?.details?.storageFreeBytes ?? 0))}</b></span>
            </div>
          </section>
          <QueryReadout payload={dbQueries} error={queryError} />
        </aside>

        <section className="chat-panel panel">
          <div className="panel-title-row chat-title">
            <div>
              <p className="eyebrow">Conversation</p>
              <h2>Command stream</h2>
            </div>
            {latestAssistant ? <span className="mini">last reply {formatTime(latestAssistant.timestamp)}</span> : <span className="mini">ready</span>}
          </div>
          <section className={cx("activity-card", activity?.active && "active", activity?.degraded && "warn")}>
            <div className="activity-head">
              <span className="activity-dot" />
              <div>
                <strong>{activity?.label || "Idle"}</strong>
                <small>{activity?.sampledAt ? `updated ${formatTime(activity.sampledAt)}` : "watching OpenClaw activity"}</small>
              </div>
            </div>
            <div className="activity-events">
              {(activity?.events ?? []).slice(-4).map((event, index) => (
                <div className={`activity-event kind-${event.kind}`} key={`${event.kind}-${event.timestamp ?? index}-${index}`}>
                  <b>{event.label}</b>
                  {event.detail ? <span>{event.detail}</span> : null}
                </div>
              ))}
              {(!activity?.events || activity.events.length === 0) ? <div className="activity-event"><b>No current run</b><span>Messages will show thinking/tools here while this agent works.</span></div> : null}
            </div>
          </section>
          <div className="messages" ref={messagesRef} aria-live="polite">
            {messages.length === 0 ? (
              <div className="empty-state">
                <strong>Local channel is ready.</strong>
                <p>Type, paste, drag files, or dictate a command.</p>
              </div>
            ) : null}
            {messages.map((message) => <MessageBubble key={message.id} message={message} identity={identity} />)}
            {sending ? <div className="working">Sending<span>.</span><span>.</span><span>.</span></div> : null}
            <div ref={bottomRef} />
          </div>

          <footer className="composer">
            {notice ? <div className="notice" onClick={() => showNotice(null)}>{notice}</div> : null}
            {attachments.length ? (
              <div className="attachment-shelf">
                {attachments.map((file, index) => (
                  <button key={`${file.url}-${index}`} onClick={() => setAttachments((current) => current.filter((_, i) => i !== index))} title="Remove attachment">
                    <span>📎 {file.name}</span>
                    <b>{formatBytes(file.size)}</b>
                  </button>
                ))}
              </div>
            ) : null}
            <div className="mode-row">
              <span className="hint">Everything is chat · Drag files anywhere · Ctrl/⌘ Enter sends</span>
            </div>
            <div className="compose-box">
              <textarea
                ref={textRef}
                value={draft}
                onChange={(event) => setDraft(event.target.value)}
                onKeyDown={onKeyDown}
                placeholder={`Send a command to ${identity}…`}
                spellCheck
              />
              <div className="compose-actions">
                <input ref={fileRef} type="file" multiple hidden onChange={(event) => event.target.files && void uploadFiles(event.target.files)} />
                <button className="ghost" onClick={() => fileRef.current?.click()} disabled={uploading}>{uploading ? "Uploading" : "Attach"}</button>
                <button className={cx("ghost", recording && "danger")} onClick={() => void toggleRecording()} disabled={transcribing}>{recording ? "Stop" : transcribing ? "Transcribing" : "Mic"}</button>
                <button className="primary send" onClick={() => void sendMessage()} disabled={!canSend}>{sending ? "Sending" : "Send"}</button>
              </div>
            </div>
          </footer>
        </section>
      </div>

      <div className="signature">{identity} LAN Console · scratch rebuilt UI</div>
    </main>
  );
}
