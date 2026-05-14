"use client";

import { useCallback, useEffect, useRef, useState } from "react";

interface ChatMessage {
  id: string;
  role: "assistant" | "user" | "system";
  text: string;
  timestamp?: number;
}

interface ChatAttachment {
  name: string;
  type: string;
  size: number;
  url: string;
}

interface DbDialMetric {
  value: number;
  min: number;
  max: number;
  unit: string;
  status: string;
}

interface DbStatusPayload {
  sampledAt: string;
  statsResetAt: string | null;
  metrics: {
    queriesPerSecond: DbDialMetric;
    cacheHitRatio: DbDialMetric;
    writesPerSecond: DbDialMetric;
    dbSize: DbDialMetric;
  };
  details: {
    blockedQueries: number;
    slowQueries: number;
    longestQuerySeconds: number;
    tempBytes: number;
    tempFiles: number;
    readTimeMs: number;
    writeTimeMs: number;
    commits: number;
    rollbacks: number;
    dbSizeBytes?: number;
    storagePath?: string;
    storageFreeBytes?: number;
    storageTotalBytes?: number;
    storageUsedBytes?: number;
    storageFreePercent?: number;
  };
  healthScore: number;
}

interface LiveQueryEntry {
  id: string;
  kind: "activity" | "query";
  title: string;
  query: string;
  result: string;
}

interface DbQueriesPayload {
  sampledAt: string;
  entries: LiveQueryEntry[];
}

interface MenuState {
  x: number;
  y: number;
}

type ThemeMode = "light" | "dark" | "auto";

const POLL_INTERVAL_MS = 4000;
const DB_POLL_INTERVAL_MS = 750;
const TTS_ENABLED_KEY = "lan-chat:tts-enabled";
const TTS_LAST_SPOKEN_KEY = "lan-chat:tts-last-spoken";
const THEME_MODE_KEY = "lan-chat:theme-mode";

export default function Home() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [isSending, setIsSending] = useState(false);
  const [awaitingReply, setAwaitingReply] = useState(false);
  const [attachments, setAttachments] = useState<ChatAttachment[]>([]);
  const [uploading, setUploading] = useState(false);
  const [audioReady, setAudioReady] = useState(false);
  const [showWorking, setShowWorking] = useState(false);
  const [pendingSince, setPendingSince] = useState<number | null>(null);
  const [thinkingUntil, setThinkingUntil] = useState<number | null>(null);
  const [lastSendAt, setLastSendAt] = useState<number | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [contextMenu, setContextMenu] = useState<MenuState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [lastSync, setLastSync] = useState<Date | null>(null);
  const [statusLine, setStatusLine] = useState<string | null>(null);
  const [dbStatus, setDbStatus] = useState<DbStatusPayload | null>(null);
  const [dbQueries, setDbQueries] = useState<DbQueriesPayload | null>(null);
  const [dbError, setDbError] = useState<string | null>(null);
  const [dbQueriesError, setDbQueriesError] = useState<string | null>(null);
  const [assistantName, setAssistantName] = useState("Zorg");
  const [ttsEnabled, setTtsEnabled] = useState(false);
  const [heartbeat, setHeartbeat] = useState(0);
  const [audioStatus, setAudioStatus] = useState<string | null>(null);
  const [ttsStatus, setTtsStatus] = useState<string | null>(null);
  const [ttsTestRunning, setTtsTestRunning] = useState(false);
  const [autoSpeakOn, setAutoSpeakOn] = useState(true);
  const [ttsInFlight, setTtsInFlight] = useState(false);
  const [themeMode, setThemeMode] = useState<ThemeMode>("light");
  const [systemTheme, setSystemTheme] = useState<"light" | "dark">("light");

  const buildTag = process.env.NEXT_PUBLIC_BUILD_TAG ?? "unknown";
  const resolvedTheme = themeMode === "auto" ? systemTheme : themeMode;
  const isDarkTheme = resolvedTheme === "dark";
  const scrollRef = useRef<HTMLDivElement | null>(null);
  const queryStreamRef = useRef<HTMLDivElement | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const textAreaRef = useRef<HTMLTextAreaElement | null>(null);
  const speakQueueRef = useRef<Promise<void>>(Promise.resolve());
  const lastSpokenIdRef = useRef<string | null>(null);
  const currentAudioRef = useRef<HTMLAudioElement | null>(null);
  const ttsRunIdRef = useRef(0);
  const ttsQueueRef = useRef<string[]>([]);
  const ttsPlayingRef = useRef(false);
  const speakingMessageIdRef = useRef<string | null>(null);

  const loadHistory = useCallback(async () => {
    try {
      const res = await fetch("/api/chat/history", { cache: "no-store" });
      if (!res.ok) throw new Error("History request failed");
      const data = await res.json();
      setMessages(Array.isArray(data?.messages) ? data.messages : []);
      setLastSync(new Date());
      setError(null);
    } catch (err) {
      console.error(err);
      setError("Chat stream is disconnected from the local gateway.");
    }
  }, []);

  const loadIdentity = useCallback(async () => {
    try {
      const res = await fetch("/api/chat/identity", { cache: "no-store" });
      if (!res.ok) throw new Error("Identity request failed");
      const data = await res.json();
      const nextName = typeof data?.name === "string" && data.name.trim() ? data.name.trim() : "Zorg";
      setAssistantName(nextName);
    } catch (err) {
      console.error(err);
      setAssistantName("Zorg");
    }
  }, []);

  const loadStatus = useCallback(async () => {
    try {
      const res = await fetch("/api/chat/status", { cache: "no-store" });
      if (!res.ok) throw new Error("Status request failed");
      const data = await res.json();
      if (data?.error) throw new Error(data.error);
      const agentLabel = data.agentId ? `agent ${data.agentId}` : "agent";
      const sessionLabel = data.label ? `session ${data.label}` : "session";
      const model = data.model ?? "unknown model";
      const thinking = data.thinking ?? "think low";
      const tokensUsed = typeof data.tokensUsed === "number" ? Math.round(data.tokensUsed).toLocaleString() : null;
      const tokensLimit = typeof data.tokensLimit === "number" ? Math.round(data.tokensLimit).toLocaleString() : null;
      const tokensPercent = typeof data.tokensPercent === "number" ? `${data.tokensPercent}%` : null;
      const tokens = tokensUsed && tokensLimit ? `tokens ${tokensUsed}/${tokensLimit}` : tokensUsed ? `tokens ${tokensUsed}` : "tokens n/a";
      setStatusLine(`${agentLabel} · ${sessionLabel} · ${model} · ${thinking} · ${tokensPercent ? `${tokens} (${tokensPercent})` : tokens}`);
    } catch (err) {
      console.error(err);
      setStatusLine(null);
    }
  }, []);

  const loadDbStatus = useCallback(async () => {
    try {
      const res = await fetch("/api/db/status", { cache: "no-store" });
      if (!res.ok) throw new Error("Database status request failed");
      const data = (await res.json()) as DbStatusPayload & { error?: string };
      if (data?.error) throw new Error(data.error);
      setDbStatus(data);
      setDbError(null);
    } catch (err) {
      console.error(err);
      setDbError(err instanceof Error ? err.message : "Failed to load database metrics");
    }
  }, []);

  const loadDbQueries = useCallback(async () => {
    try {
      const res = await fetch("/api/db/queries", { cache: "no-store" });
      if (!res.ok) throw new Error("Database query feed request failed");
      const data = (await res.json()) as DbQueriesPayload & { error?: string };
      if (data?.error) throw new Error(data.error);
      setDbQueries((prev) => {
        const prior = prev?.entries ?? [];
        const seen = new Set(prior.map((entry) => entry.id));
        const merged = [...prior, ...data.entries.filter((entry) => !seen.has(entry.id))];
        let charCount = 0;
        const entries = [...merged]
          .reverse()
          .filter((entry) => {
            const size = entry.title.length + entry.query.length + entry.result.length + 8;
            if (charCount + size > 1000) return false;
            charCount += size;
            return true;
          })
          .reverse();
        return { sampledAt: data.sampledAt, entries };
      });
      setDbQueriesError(null);
    } catch (err) {
      console.error(err);
      setDbQueriesError(err instanceof Error ? err.message : "Failed to load live queries");
    }
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const stored = window.localStorage.getItem(TTS_ENABLED_KEY);
    const enabled = stored === null ? true : stored === "true";
    setTtsEnabled(enabled);
    window.localStorage.setItem(TTS_ENABLED_KEY, String(enabled));
    const lastSpoken = window.localStorage.getItem(TTS_LAST_SPOKEN_KEY);
    if (lastSpoken) lastSpokenIdRef.current = lastSpoken;
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const savedTheme = window.localStorage.getItem(THEME_MODE_KEY);
    if (savedTheme === "light" || savedTheme === "dark" || savedTheme === "auto") {
      setThemeMode(savedTheme);
    } else {
      setThemeMode("light");
      window.localStorage.setItem(THEME_MODE_KEY, "light");
    }

    const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
    const syncSystemTheme = () => setSystemTheme(mediaQuery.matches ? "dark" : "light");
    syncSystemTheme();
    mediaQuery.addEventListener("change", syncSystemTheme);
    return () => mediaQuery.removeEventListener("change", syncSystemTheme);
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return;
    window.localStorage.setItem(THEME_MODE_KEY, themeMode);
  }, [themeMode]);

  useEffect(() => {
    const interval = setInterval(() => setHeartbeat((value) => value + 1), 1000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    loadHistory();
    loadStatus();
    loadIdentity();
    const interval = setInterval(() => {
      loadHistory();
      loadStatus();
      loadIdentity();
    }, POLL_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [loadHistory, loadStatus, loadIdentity]);

  useEffect(() => {
    loadDbStatus();
    loadDbQueries();
    const interval = setInterval(() => {
      loadDbStatus();
      loadDbQueries();
    }, DB_POLL_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [loadDbStatus, loadDbQueries]);

  useEffect(() => {
    if (!queryStreamRef.current) return;
    queryStreamRef.current.scrollTop = queryStreamRef.current.scrollHeight;
  }, [dbQueries]);

  useEffect(() => {
    scrollRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [messages, awaitingReply]);

  useEffect(() => {
    if (!contextMenu) return;
    const close = () => setContextMenu(null);
    window.addEventListener("click", close);
    window.addEventListener("keydown", close);
    return () => {
      window.removeEventListener("click", close);
      window.removeEventListener("keydown", close);
    };
  }, [contextMenu]);

  useEffect(() => {
    if (!awaitingReply || !pendingSince) return;
    const hasNewAssistant = messages.some((message) => {
      if (message.role !== "assistant" || !message.timestamp) return false;
      const ts = message.timestamp > 1_000_000_000_000 ? message.timestamp : message.timestamp * 1000;
      return ts >= pendingSince;
    });
    if (hasNewAssistant) {
      setAwaitingReply(false);
      setShowWorking(false);
      setPendingSince(null);
      setThinkingUntil(null);
      setLastSendAt(null);
    }
  }, [messages, awaitingReply, pendingSince]);

  const formatTimestamp = useCallback((timestamp?: number) => {
    if (!timestamp) return "";
    const raw = timestamp > 1_000_000_000_000 ? timestamp : timestamp * 1000;
    return new Date(raw).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", timeZone: "America/Los_Angeles" });
  }, []);

  const formatCompactNumber = useCallback((value: number) => {
    return new Intl.NumberFormat("en-US", {
      notation: value >= 1000 ? "compact" : "standard",
      maximumFractionDigits: value >= 100 ? 0 : 1,
    }).format(value);
  }, []);

  const formatBytes = useCallback((bytes: number) => {
    const units = ["B", "KB", "MB", "GB", "TB"];
    let value = bytes;
    let unit = units[0];
    for (let index = 0; index < units.length; index += 1) {
      unit = units[index];
      if (Math.abs(value) < 1024 || index === units.length - 1) break;
      value /= 1024;
    }
    return `${value >= 100 ? value.toFixed(0) : value >= 10 ? value.toFixed(1) : value.toFixed(2)} ${unit}`;
  }, []);

  const uploadFiles = useCallback(async (incoming: FileList | File[]) => {
    const files = Array.from(incoming || []);
    if (!files.length) return;
    setUploading(true);
    try {
      const form = new FormData();
      for (const file of files) form.append("files", file);
      const res = await fetch("/api/chat/upload", { method: "POST", body: form });
      if (!res.ok) throw new Error((await res.text().catch(() => "")) || "Upload failed");
      const data = await res.json();
      const next = Array.isArray(data?.files) ? (data.files as ChatAttachment[]) : [];
      if (next.length) setAttachments((prev) => [...prev, ...next]);
      setError(null);
    } catch (err) {
      console.error(err);
      setError(err instanceof Error ? err.message : "Upload failed");
    } finally {
      setUploading(false);
      setIsDragging(false);
    }
  }, []);

  const playTts = useCallback(async (text: string, runId?: number) => {
    if (!audioReady) throw new Error("Audio not enabled");
    const activeRunId = runId ?? ++ttsRunIdRef.current;
    if (currentAudioRef.current) {
      currentAudioRef.current.pause();
      currentAudioRef.current.currentTime = 0;
      currentAudioRef.current = null;
    }
    setTtsInFlight(true);
    const res = await fetch("/api/tts", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text }),
    });
    const contentType = res.headers.get("content-type") || "unknown";
    setTtsStatus(`TTS ${res.status} ${res.statusText} (${contentType})`);
    if (!res.ok) throw new Error(`TTS request failed: ${res.status} ${await res.text().catch(() => "")}`.trim());
    const blob = await res.blob();
    if (activeRunId !== ttsRunIdRef.current) return;
    const url = URL.createObjectURL(blob);
    try {
      const audio = new Audio(url);
      currentAudioRef.current = audio;
      await audio.play();
      await new Promise<void>((resolve, reject) => {
        audio.addEventListener("ended", () => resolve(), { once: true });
        audio.addEventListener("error", () => reject(new Error("Audio playback error")), { once: true });
      });
      setTtsStatus(`TTS playback ok (${contentType})`);
    } finally {
      URL.revokeObjectURL(url);
      setTtsInFlight(false);
    }
  }, [audioReady]);

  const chunkForSpeech = useCallback((text: string) => {
    const normalized = text.replace(/\s+/g, " ").trim();
    if (!normalized) return [] as string[];
    const chunks: string[] = [];
    for (const sentence of normalized.split(/(?<=[.!?])\s+/g).filter(Boolean)) {
      const words = sentence.split(" ").filter(Boolean);
      if (words.length <= 12) chunks.push(sentence);
      else for (let i = 0; i < words.length; i += 12) chunks.push(words.slice(i, i + 12).join(" "));
    }
    return chunks;
  }, []);

  const processTtsQueue = useCallback(async (runId: number) => {
    if (ttsPlayingRef.current) return;
    ttsPlayingRef.current = true;
    try {
      while (ttsQueueRef.current.length) {
        if (runId !== ttsRunIdRef.current) return;
        const next = ttsQueueRef.current.shift();
        if (next) await playTts(next, runId);
      }
    } finally {
      ttsPlayingRef.current = false;
    }
  }, [playTts]);

  const playTtsChunks = useCallback(async (text: string, runId?: number) => {
    const activeRunId = runId ?? ++ttsRunIdRef.current;
    const chunks = chunkForSpeech(text);
    if (!chunks.length) return;
    ttsQueueRef.current = chunks;
    await processTtsQueue(activeRunId);
  }, [chunkForSpeech, processTtsQueue]);

  useEffect(() => {
    if (!audioReady || !autoSpeakOn || !messages.length) return;
    const lastUserIndexFromEnd = [...messages].reverse().findIndex((message) => message.role === "user");
    if (lastUserIndexFromEnd === -1) return;
    const userIndex = messages.length - 1 - lastUserIndexFromEnd;
    const lastUserMessage = messages[userIndex];
    const latestAssistant = [...messages.slice(userIndex + 1)].reverse().find((message) => message.role === "assistant");
    if (!latestAssistant) return;
    if (lastUserMessage?.timestamp && latestAssistant.timestamp && latestAssistant.timestamp <= lastUserMessage.timestamp) return;
    if (lastSpokenIdRef.current === latestAssistant.id || speakingMessageIdRef.current === latestAssistant.id) return;
    ttsRunIdRef.current += 1;
    const runId = ttsRunIdRef.current;
    speakingMessageIdRef.current = latestAssistant.id;
    speakQueueRef.current = Promise.resolve().then(async () => {
      try {
        setShowWorking(true);
        setTtsStatus("Speaking latest reply...");
        await playTtsChunks(latestAssistant.text, runId);
      } catch (err) {
        console.error(err);
        setTtsStatus(err instanceof Error ? err.message : "TTS failed");
        setAutoSpeakOn(false);
      } finally {
        lastSpokenIdRef.current = latestAssistant.id;
        speakingMessageIdRef.current = null;
        window.localStorage.setItem(TTS_LAST_SPOKEN_KEY, latestAssistant.id);
        setShowWorking(false);
      }
    });
  }, [messages, playTtsChunks, audioReady, autoSpeakOn]);

  const enableAudio = useCallback(async () => {
    try {
      const AudioCtx = window.AudioContext || (window as typeof window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!AudioCtx) throw new Error("AudioContext not available");
      const ctx = new AudioCtx();
      if (ctx.state !== "running") await ctx.resume();
      const oscillator = ctx.createOscillator();
      const gain = ctx.createGain();
      gain.gain.value = 0.06;
      oscillator.type = "sine";
      oscillator.frequency.value = 880;
      oscillator.connect(gain);
      gain.connect(ctx.destination);
      oscillator.start();
      oscillator.stop(ctx.currentTime + 0.12);
      setAudioReady(true);
      setAudioStatus("Audio unlocked");
    } catch (err) {
      console.error(err);
      setAudioReady(false);
      setAudioStatus(err instanceof Error ? err.message : "Audio unlock failed");
    }
  }, []);

  const handleTtsToggle = useCallback((enabled: boolean) => {
    setTtsEnabled(enabled);
    window.localStorage.setItem(TTS_ENABLED_KEY, String(enabled));
    if (enabled) {
      const latest = messages[messages.length - 1];
      if (latest) {
        lastSpokenIdRef.current = latest.id;
        window.localStorage.setItem(TTS_LAST_SPOKEN_KEY, latest.id);
      }
    }
  }, [messages]);

  const testTts = useCallback(async () => {
    if (ttsTestRunning) return;
    setTtsTestRunning(true);
    setTtsStatus("TTS test: sending request...");
    try {
      await playTtsChunks("Test sound from Zorg LAN Console.");
    } catch (err) {
      console.error(err);
      setTtsStatus(err instanceof Error ? err.message : "TTS test failed");
    } finally {
      setTtsTestRunning(false);
    }
  }, [playTtsChunks, ttsTestRunning]);

  const speakLatest = useCallback(async () => {
    const latest = [...messages].reverse().find((message) => message.role === "assistant");
    if (!latest) {
      setTtsStatus("No assistant reply to speak yet.");
      return;
    }
    try {
      await playTtsChunks(latest.text);
    } catch (err) {
      console.error(err);
      setTtsStatus(err instanceof Error ? err.message : "TTS failed");
    }
  }, [messages, playTtsChunks]);

  const handleSend = useCallback(async (event?: React.FormEvent) => {
    event?.preventDefault();
    const message = input.trim();
    if (!message && attachments.length === 0) return;
    const now = Date.now();
    const pendingAttachments = [...attachments];
    setIsSending(true);
    setAwaitingReply(true);
    setShowWorking(true);
    setPendingSince(now);
    setThinkingUntil(now + 1800);
    setLastSendAt(now);
    setInput("");
    setAttachments([]);
    setAutoSpeakOn(ttsEnabled);
    lastSpokenIdRef.current = null;
    window.localStorage.removeItem(TTS_LAST_SPOKEN_KEY);
    try {
      const res = await fetch("/api/chat/send", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message, attachments: pendingAttachments }),
      });
      if (!res.ok) throw new Error("Send failed");
      setTimeout(loadHistory, 1200);
    } catch (err) {
      console.error(err);
      setError("Message failed. Check the gateway logs.");
      setInput(message);
      setAttachments(pendingAttachments);
      setAwaitingReply(false);
      setShowWorking(false);
      setPendingSince(null);
      setThinkingUntil(null);
    } finally {
      setIsSending(false);
    }
  }, [attachments, input, loadHistory, ttsEnabled]);

  const pasteFromClipboard = useCallback(async () => {
    try {
      const text = await navigator.clipboard.readText();
      if (text) setInput((value) => `${value}${value && !value.endsWith("\n") ? "\n" : ""}${text}`);
      textAreaRef.current?.focus();
    } catch (err) {
      console.error(err);
      setError("Clipboard paste needs browser permission. Use Ctrl+V or the native browser paste action.");
    }
  }, []);

  const onPaste = useCallback((event: React.ClipboardEvent<HTMLTextAreaElement>) => {
    const files = event.clipboardData?.files;
    if (files && files.length > 0) {
      event.preventDefault();
      void uploadFiles(files);
    }
  }, [uploadFiles]);

  const onDrop = useCallback((event: React.DragEvent<HTMLDivElement>) => {
    event.preventDefault();
    event.stopPropagation();
    const files = event.dataTransfer?.files;
    if (files && files.length > 0) void uploadFiles(files);
    const text = event.dataTransfer?.getData("text/plain");
    if (text && (!files || files.length === 0)) setInput((value) => `${value}${value ? "\n" : ""}${text}`);
    setIsDragging(false);
  }, [uploadFiles]);

  const handleComposerKeyDown = useCallback((event: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault();
      void handleSend();
    }
  }, [handleSend]);

  const thinkingNow = isSending || awaitingReply || showWorking || (thinkingUntil !== null && Date.now() < thinkingUntil) || (lastSendAt ? Date.now() - lastSendAt < 10000 : false);

  const cycleThemeMode = useCallback(() => {
    setThemeMode((mode) => (mode === "light" ? "dark" : mode === "dark" ? "auto" : "light"));
  }, []);

  const themeLabel = themeMode === "auto" ? `Auto · ${resolvedTheme}` : themeMode === "light" ? "Light" : "Dark";

  const dialTone = useCallback((status: string) => {
    if (["blocked", "warn", "hot", "slow"].includes(status)) return { ring: "stroke-rose-400", text: "text-rose-200", glow: "shadow-rose-500/20" };
    if (["busy", "ok"].includes(status)) return { ring: "stroke-amber-300", text: "text-amber-100", glow: "shadow-amber-400/20" };
    return { ring: "stroke-emerald-300", text: "text-emerald-100", glow: "shadow-emerald-500/20" };
  }, []);

  const renderDial = useCallback((label: string, metric: DbDialMetric, centerText?: string, centerUnit?: string) => {
    const percent = Math.max(0, Math.min(100, ((metric.value - metric.min) / Math.max(metric.max - metric.min, 1)) * 100));
    const radius = 44;
    const circumference = 2 * Math.PI * radius;
    const offset = circumference * (1 - percent / 100);
    const tone = dialTone(metric.status);
    return (
      <div className={`theme-surface rounded-2xl border border-white/10 bg-slate-950/60 p-2.5 shadow-lg ${tone.glow}`} key={label}>
        <div className="mb-1.5 text-[9px] font-semibold uppercase tracking-[0.14em] text-white/60">{label}</div>
        <div className="flex items-center justify-center">
          <div className="relative h-20 w-20">
            <svg viewBox="0 0 120 120" className="h-20 w-20 -rotate-90">
              <circle cx="60" cy="60" r={radius} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="8" />
              <circle cx="60" cy="60" r={radius} fill="none" strokeWidth="8" strokeLinecap="round" className={`${tone.ring} transition-all duration-700 ease-out`} strokeDasharray={circumference} strokeDashoffset={offset} />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
              <div className={`text-base font-semibold ${tone.text}`}>{centerText ?? formatCompactNumber(metric.value)}</div>
              <div className="text-[8px] uppercase tracking-[0.12em] text-white/45">{centerUnit ?? metric.unit}</div>
              {centerText && <div className="mt-0.5 text-[8px] uppercase tracking-[0.1em] text-white/40">{formatCompactNumber(metric.value)} {metric.unit}</div>}
            </div>
          </div>
        </div>
      </div>
    );
  }, [dialTone, formatCompactNumber]);

  return (
    <div
      data-theme={resolvedTheme}
      className={`theme-root ${isDarkTheme ? "theme-dark" : "theme-light"} relative min-h-screen overflow-hidden bg-[radial-gradient(circle_at_top_left,#12362d_0%,#020617_32%,#020617_100%)] text-slate-50`}
      onDragOver={(event) => {
        event.preventDefault();
        setIsDragging(true);
      }}
      onDragLeave={(event) => {
        if (event.currentTarget === event.target) setIsDragging(false);
      }}
      onDrop={onDrop}
    >
      <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(rgba(16,185,129,0.045)_1px,transparent_1px),linear-gradient(90deg,rgba(16,185,129,0.045)_1px,transparent_1px)] bg-[size:42px_42px]" />
      {isDragging && (
        <div className="pointer-events-none fixed inset-4 z-50 flex items-center justify-center rounded-[2rem] border-2 border-dashed border-emerald-300 bg-emerald-400/15 text-2xl font-semibold text-emerald-100 backdrop-blur-sm">
          Drop files, images, or text into Zorg Land
        </div>
      )}

      <div className="relative z-10 mx-auto flex h-screen max-w-7xl flex-col gap-3 px-4 py-4 md:px-6">
        <header className="theme-surface flex items-center justify-between gap-4 rounded-3xl border border-white/10 bg-slate-950/55 px-4 py-3 shadow-2xl shadow-black/30 backdrop-blur-xl">
          <div>
            <p className="text-[10px] font-semibold uppercase tracking-[0.34em] text-emerald-300">{assistantName} · Zorg Land Console</p>
            <h1 className="text-2xl font-semibold text-white md:text-3xl">Local Command Chat</h1>
            <p className="mt-1 text-xs text-white/55">Build {buildTag} · sync {lastSync ? lastSync.toLocaleTimeString() : "waiting"} · heartbeat {heartbeat}s</p>
          </div>
          <div className="flex flex-col items-end gap-2 text-right text-xs text-white/75">
            <div className="inline-flex items-center gap-2 rounded-full border border-emerald-400/30 bg-emerald-400/10 px-3 py-1">
              <span className={`h-2 w-2 rounded-full ${thinkingNow ? "bg-emerald-300 status-pulse" : "bg-emerald-500/60"}`} />
              {thinkingNow ? "Zorg is working" : statusLine ?? "gateway status loading"}
            </div>
            <div className="flex flex-wrap justify-end gap-2">
              <button type="button" onClick={cycleThemeMode} className="theme-toggle rounded-full border border-white/15 bg-white/5 px-3 py-1 font-semibold hover:bg-white/10" aria-label={`Theme mode: ${themeLabel}. Click to change theme.`}>Theme: {themeLabel}</button>
              <button type="button" onClick={enableAudio} className="rounded-full border border-white/15 bg-white/5 px-3 py-1 hover:bg-white/10">{audioReady ? "Audio on" : "Enable audio"}</button>
              <button type="button" onClick={testTts} disabled={!audioReady || ttsTestRunning} className="rounded-full border border-white/15 bg-white/5 px-3 py-1 hover:bg-white/10 disabled:opacity-40">{ttsTestRunning ? "Testing…" : "Test TTS"}</button>
              <button type="button" onClick={speakLatest} disabled={!audioReady || ttsInFlight} className="rounded-full border border-white/15 bg-white/5 px-3 py-1 hover:bg-white/10 disabled:opacity-40">Speak latest</button>
            </div>
          </div>
        </header>

        {(error || ttsStatus || audioStatus) && (
          <div className="flex flex-wrap gap-2 text-xs">
            {error && <div className="rounded-full border border-rose-400/40 bg-rose-500/10 px-3 py-1 text-rose-100">{error}</div>}
            {ttsStatus && <div className="rounded-full border border-emerald-400/35 bg-emerald-500/10 px-3 py-1 text-emerald-100">{ttsStatus}</div>}
            {audioStatus && <div className="rounded-full border border-sky-400/35 bg-sky-500/10 px-3 py-1 text-sky-100">{audioStatus}</div>}
          </div>
        )}

        <section className="grid min-h-0 flex-1 grid-cols-1 gap-3 lg:grid-cols-[minmax(0,1fr)_17rem]">
          <main className="theme-surface flex min-h-0 flex-col overflow-hidden rounded-[2rem] border border-white/10 bg-slate-950/60 shadow-2xl shadow-black/35 backdrop-blur-xl">
            <div className="flex items-center justify-between border-b border-white/10 px-4 py-3">
              <div>
                <p className="text-sm font-semibold text-white">Conversation</p>
                <p className="text-xs text-white/45">Drag/drop anywhere · paste files or images · right-click composer for tools</p>
              </div>
              <button type="button" onClick={loadHistory} className="rounded-full border border-white/15 bg-white/5 px-3 py-1 text-xs text-white/75 hover:bg-white/10">Refresh</button>
            </div>

            <div className="min-h-0 flex-1 overflow-y-auto px-4 py-4">
              <div className="flex flex-col gap-4">
                {messages.length === 0 && (
                  <div className="mx-auto max-w-lg rounded-3xl border border-emerald-400/20 bg-emerald-400/10 p-6 text-center text-sm text-emerald-50/85">
                    Chat history is empty or still syncing. The LAN gateway, gauges, and query feed keep polling independently.
                  </div>
                )}
                {messages.map((message) => {
                  const user = message.role === "user";
                  const system = message.role === "system";
                  return (
                    <article key={message.id} className={`group flex ${user ? "justify-end" : system ? "justify-center" : "justify-start"}`}>
                      <div className={`max-w-[88%] rounded-[1.35rem] px-4 py-3 text-sm leading-relaxed shadow-lg md:max-w-[72%] ${user ? "bg-emerald-400 text-slate-950" : system ? "border border-white/10 bg-slate-800/80 text-white/80" : "border border-white/10 bg-slate-900/90 text-slate-50"}`}>
                        <div className={`mb-2 flex items-center gap-2 text-[10px] font-semibold uppercase tracking-[0.18em] ${user ? "text-slate-900/65" : "text-white/45"}`}>
                          <span>{user ? "Stefan" : system ? "System" : assistantName}</span>
                          {message.timestamp && <span className="normal-case tracking-normal">{formatTimestamp(message.timestamp)}</span>}
                        </div>
                        <p className="whitespace-pre-wrap break-words">{message.text}</p>
                      </div>
                    </article>
                  );
                })}
                {thinkingNow && (
                  <article className="flex justify-start">
                    <div className="rounded-[1.35rem] border border-emerald-400/25 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-100 shadow-lg">
                      <div className="mb-2 text-[10px] font-semibold uppercase tracking-[0.18em] text-emerald-200/55">{assistantName}</div>
                      <span className="inline-flex items-center gap-2">Working <span className="thinking-dots" aria-hidden="true"><span /><span /><span /></span></span>
                    </div>
                  </article>
                )}
                <div ref={scrollRef} />
              </div>
            </div>
          </main>

          <aside className="theme-surface min-h-0 overflow-hidden rounded-[2rem] border border-emerald-400/15 bg-slate-950/70 p-3 shadow-2xl shadow-black/30 backdrop-blur-xl">
            <div className="mb-3 flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-white">Database Core</p>
                <p className="text-[10px] uppercase tracking-[0.18em] text-emerald-300/70">gauges + quarry readout</p>
              </div>
              {dbStatus && <span className="rounded-full bg-emerald-400/10 px-2 py-0.5 text-[10px] text-emerald-200">{dbStatus.healthScore}%</span>}
            </div>
            {dbError && <div className="mb-3 rounded-2xl border border-rose-400/40 bg-rose-500/10 px-3 py-2 text-xs text-rose-100">{dbError}</div>}
            {dbStatus && (
              <>
                <div className="grid grid-cols-2 gap-2">
                  {renderDial("Queries / Sec", dbStatus.metrics.queriesPerSecond)}
                  {renderDial("Cache Hit", dbStatus.metrics.cacheHitRatio)}
                  {renderDial("Table Writes / Sec", dbStatus.metrics.writesPerSecond)}
                  {renderDial("Storage Used", dbStatus.metrics.dbSize, dbStatus.details.dbSizeBytes ? formatBytes(dbStatus.details.dbSizeBytes) : "DB n/a", "DB size")}
                </div>
                {typeof dbStatus.details.storageFreePercent === "number" && (
                  <div className="mt-2 rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-[11px] text-white/55">
                    Storage free: {dbStatus.details.storageFreePercent}% · DB size: {dbStatus.details.dbSizeBytes ? formatBytes(dbStatus.details.dbSizeBytes) : "n/a"}
                  </div>
                )}
                <div className="mt-3 rounded-2xl border border-white/10 bg-black/35 p-2">
                  {dbQueriesError ? (
                    <div className="text-[11px] text-rose-200">{dbQueriesError}</div>
                  ) : (
                    <div ref={queryStreamRef} className="h-40 overflow-x-auto overflow-y-auto rounded-xl bg-black/20 p-2 font-mono text-[12px] leading-tight text-emerald-100/90 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
                      {dbQueries && dbQueries.entries.length > 0 ? (
                        <div className="space-y-1 whitespace-nowrap">
                          {dbQueries.entries.map((entry) => (
                            <div key={entry.id} className="border-b border-white/5 pb-1 last:border-b-0">
                              <div className="mb-0.5 text-[12px] uppercase tracking-[0.08em] text-emerald-300/80">{entry.title}</div>
                              <div className="text-emerald-50/90">{entry.query}</div>
                              <div className="mt-0.5 text-[12px] text-emerald-200/70">{entry.result}</div>
                            </div>
                          ))}
                        </div>
                      ) : (
                        <div className="text-[11px] text-white/45">No active queries.</div>
                      )}
                    </div>
                  )}
                </div>
              </>
            )}
          </aside>
        </section>

        <form onSubmit={handleSend} className="theme-surface relative rounded-[2rem] border border-white/10 bg-slate-950/80 p-3 shadow-2xl shadow-black/35 backdrop-blur-xl">
          <div className="mb-2 flex flex-wrap items-center justify-between gap-2 text-xs text-white/55">
            <div className="flex flex-wrap items-center gap-2">
              <span className="rounded-full bg-white/5 px-2 py-1">Ctrl/⌘+Enter sends</span>
              <span className="rounded-full bg-white/5 px-2 py-1">Right-click tools</span>
              <span className="rounded-full bg-white/5 px-2 py-1">Paste or drop files</span>
            </div>
            <label className="inline-flex select-none items-center gap-2">
              <input type="checkbox" checked={ttsEnabled} onChange={(event) => handleTtsToggle(event.target.checked)} className="h-4 w-4 rounded border-white/40 bg-slate-900 text-emerald-400" />
              auto voice
            </label>
          </div>
          <div className="flex gap-3">
            <textarea
              ref={textAreaRef}
              id="message"
              rows={3}
              className="min-h-24 flex-1 resize-none rounded-3xl border border-white/10 bg-slate-900/70 px-4 py-3 text-base text-white outline-none transition placeholder:text-white/30 focus:border-emerald-300 focus:ring-2 focus:ring-emerald-400/30"
              placeholder="Message Zorg Land…"
              value={input}
              onChange={(event) => setInput(event.target.value)}
              onPaste={onPaste}
              onContextMenu={(event) => {
                event.preventDefault();
                setContextMenu({ x: event.clientX, y: event.clientY });
              }}
              onKeyDown={handleComposerKeyDown}
              disabled={isSending || uploading}
            />
            <div className="flex flex-col gap-2">
              <button type="submit" disabled={isSending || uploading || (!input.trim() && attachments.length === 0)} className="h-full rounded-3xl bg-emerald-300 px-6 font-semibold text-slate-950 transition hover:bg-emerald-200 disabled:cursor-not-allowed disabled:bg-emerald-900/40 disabled:text-white/35">{isSending ? "Sending…" : "Send"}</button>
            </div>
          </div>
          <input ref={fileInputRef} type="file" multiple className="hidden" onChange={(event) => { if (event.target.files?.length) void uploadFiles(event.target.files); event.currentTarget.value = ""; }} />
          <div className="mt-2 flex flex-wrap items-center gap-2 text-xs text-white/60">
            <button type="button" onClick={() => fileInputRef.current?.click()} disabled={isSending || uploading} className="rounded-full border border-white/15 bg-white/5 px-3 py-1 text-white/75 hover:bg-white/10 disabled:opacity-40">{uploading ? "Uploading…" : "Attach"}</button>
            {attachments.map((file, index) => (
              <span key={`${file.url}-${index}`} className="inline-flex items-center gap-2 rounded-full border border-emerald-400/25 bg-emerald-400/10 px-3 py-1 text-emerald-100">
                {file.name} · {formatBytes(file.size)}
                <button type="button" onClick={() => setAttachments((prev) => prev.filter((_, i) => i !== index))} className="text-emerald-100/70 hover:text-white">×</button>
              </span>
            ))}
            {attachments.length > 0 && <button type="button" onClick={() => setAttachments([])} className="rounded-full border border-white/15 bg-white/5 px-3 py-1 hover:bg-white/10">Clear all</button>}
          </div>

          {contextMenu && (
            <div className="fixed z-50 min-w-48 overflow-hidden rounded-2xl border border-white/10 bg-slate-950/95 p-1 text-sm text-white shadow-2xl shadow-black/50 backdrop-blur" style={{ left: contextMenu.x, top: contextMenu.y }} onClick={(event) => event.stopPropagation()}>
              <button type="button" onClick={() => { void pasteFromClipboard(); setContextMenu(null); }} className="block w-full rounded-xl px-3 py-2 text-left hover:bg-white/10">Paste from clipboard</button>
              <button type="button" onClick={() => { fileInputRef.current?.click(); setContextMenu(null); }} className="block w-full rounded-xl px-3 py-2 text-left hover:bg-white/10">Attach files…</button>
              <button type="button" onClick={() => { void navigator.clipboard.writeText(input); setContextMenu(null); }} className="block w-full rounded-xl px-3 py-2 text-left hover:bg-white/10">Copy draft</button>
              <button type="button" onClick={() => { setInput(""); setAttachments([]); setContextMenu(null); }} className="block w-full rounded-xl px-3 py-2 text-left text-rose-100 hover:bg-rose-500/15">Clear composer</button>
            </div>
          )}
        </form>
      </div>
    </div>
  );
}
