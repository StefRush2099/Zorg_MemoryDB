"use client";

import { useEffect, useMemo, useRef, useState } from "react";

type Role = "assistant" | "user" | "system";

type ChatAttachment = {
  name: string;
  type: string;
  size: number;
  url: string;
  path?: string;
  containerPath?: string;
};

type ChatMessage = {
  id: string;
  role: Role;
  text: string;
  timestamp?: number;
  attachments?: ChatAttachment[];
};

type FrameEntry = ChatMessage & { source: "history" | "local" };
type HistorySoundStep = [frequency: number, delaySeconds: number, durationSeconds: number];
type LiveFrameWindow = Window & { __lanChatUnlockHistoryAlert?: () => boolean };

const HISTORY_ALERT_STEPS: HistorySoundStep[] = [[660, 0, 0.08], [990, 0.09, 0.08], [1320, 0.18, 0.14]];

let historyAudioContext: AudioContext | null = null;

function ensureHistoryAudioContext() {
  if (typeof window === "undefined") return null;
  const AudioContextCtor = window.AudioContext || (window as Window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!AudioContextCtor) return null;
  historyAudioContext ??= new AudioContextCtor();
  return historyAudioContext;
}

function unlockHistoryAlert() {
  try {
    const context = ensureHistoryAudioContext();
    if (!context) return false;
    if (context.state === "suspended") void context.resume();
    return true;
  } catch {
    return false;
  }
}

function playHistoryAlert() {
  try {
    const context = ensureHistoryAudioContext();
    if (!context) return;
    if (context.state === "suspended") void context.resume();
    const now = context.currentTime;
    for (const [frequency, delaySeconds, durationSeconds] of HISTORY_ALERT_STEPS) {
      const oscillator = context.createOscillator();
      const gain = context.createGain();
      const start = now + delaySeconds;
      const end = start + durationSeconds;
      oscillator.type = "sine";
      oscillator.frequency.setValueAtTime(frequency, start);
      gain.gain.setValueAtTime(0.0001, start);
      gain.gain.exponentialRampToValueAtTime(0.165, start + 0.012);
      gain.gain.exponentialRampToValueAtTime(0.0001, end);
      oscillator.connect(gain);
      gain.connect(context.destination);
      oscillator.start(start);
      oscillator.stop(end + 0.02);
    }
  } catch {
    // History alerts are optional; browser audio policy must not block updates.
  }
}

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function formatTime(value?: number | string) {
  if (!value) return "now";
  const date = typeof value === "number" ? new Date(value) : new Date(value);
  if (Number.isNaN(date.getTime())) return "now";
  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}

function formatBytes(value?: number) {
  if (!value || value <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const index = Math.min(Math.floor(Math.log(value) / Math.log(1024)), units.length - 1);
  return `${(value / 1024 ** index).toFixed(index ? 1 : 0)} ${units[index]}`;
}

function redactSensitiveText(text: string) {
  return text
    .replace(/sk-[A-Za-z0-9_-]{12,}/g, "sk-REDACTED")
    .replace(/(?:api[_-]?key|access[_-]?token|secret|password)\s*[:=]\s*[^\s`'\"]+/gi, (match) => {
      const separator = match.includes("=") ? "=" : ":";
      return `${match.split(separator)[0]}${separator}REDACTED`;
    });
}

function safeAttachmentUrl(url: string) {
  if (!url) return "";
  if (url.startsWith("/uploads/")) return url;
  try {
    const parsed = new URL(url, window.location.origin);
    return parsed.origin === window.location.origin ? parsed.pathname + parsed.search : "";
  } catch {
    return "";
  }
}

function isImageAttachment(file: Pick<ChatAttachment, "type" | "url" | "name">) {
  return file.type?.startsWith("image/") || /\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(file.name || file.url || "");
}

function isAudioAttachment(file: Pick<ChatAttachment, "type" | "url" | "name">) {
  return file.type?.startsWith("audio/") || /\.(mp3|wav|m4a|aac|ogg|opus|webm)$/i.test(file.name || file.url || "");
}

function isVideoAttachment(file: Pick<ChatAttachment, "type" | "url" | "name">) {
  return file.type?.startsWith("video/") || /\.(mp4|mov|m4v|webm|ogv)$/i.test(file.name || file.url || "");
}

function entryKey(entry: FrameEntry) {
  return `${entry.role}:${entry.timestamp ?? ""}:${entry.text}:${entry.source}`;
}

function messageDeliveryKey(message: ChatMessage) {
  const attachmentKey = (message.attachments ?? [])
    .map((file) => `${file.name}:${file.size}:${file.url || file.path || file.containerPath || ""}`)
    .join(",");
  return `${message.role}:${message.timestamp ?? ""}:${message.text}:${attachmentKey}`;
}

function mergeEntries(history: ChatMessage[], local: ChatMessage[]) {
  const seen = new Set<string>();
  return [
    ...history.map((message) => ({ ...message, source: "history" as const })),
    ...local.map((message) => ({ ...message, source: "local" as const })),
  ]
    .filter((entry) => {
      const key = entryKey(entry);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .sort((a, b) => (a.timestamp ?? 0) - (b.timestamp ?? 0))
    .slice(-80);
}

function roleLabel(entry: FrameEntry) {
  if (entry.role === "assistant") return "Zorg";
  if (entry.role === "system") return "System";
  return "You";
}

function AttachmentPreview({ file }: { file: ChatAttachment }) {
  const href = safeAttachmentUrl(file.url);
  const label = `${file.name} - ${formatBytes(file.size)}`;
  return (
    <a className={cx("live-attachment", isImageAttachment(file) && "image")} href={href || undefined} target="_blank" rel="noreferrer">
      {href && isImageAttachment(file) ? (
        <img src={href} alt={file.name} />
      ) : href && isAudioAttachment(file) ? (
        <audio controls src={href} preload="metadata" />
      ) : href && isVideoAttachment(file) ? (
        <video controls src={href} preload="metadata" />
      ) : (
        <span className="live-file-icon">file</span>
      )}
      <span>{label}</span>
    </a>
  );
}

function LiveBubble({ entry }: { entry: FrameEntry }) {
  const text = redactSensitiveText(entry.text || "");
  const lines = text.split("\n");
  const attachments = "attachments" in entry ? entry.attachments ?? [] : [];
  const kindClass = "kind" in entry && entry.kind ? `kind-${entry.kind}` : false;
  return (
    <article className={cx("live-message", `role-${entry.role}`, `source-${entry.source}`, kindClass)}>
      <header>
        <span>{roleLabel(entry)}</span>
        <time>{formatTime(entry.timestamp)}</time>
      </header>
      <div className="live-message-body">
        {lines.map((line, index) => <p key={`${entry.id}-${index}`}>{line || "\u00a0"}</p>)}
      </div>
      {attachments.length ? (
        <div className="live-attachments">
          {attachments.map((file, index) => <AttachmentPreview file={file} key={`${file.url || file.name}-${index}`} />)}
        </div>
      ) : null}
    </article>
  );
}

export default function LiveFrame() {
  const [history, setHistory] = useState<ChatMessage[]>([]);
  const [local, setLocal] = useState<ChatMessage[]>([]);
  const [theme, setTheme] = useState<"light" | "dark">(() => {
    if (typeof window === "undefined") return "dark";
    return new URLSearchParams(window.location.search).get("theme") === "light" ? "light" : "dark";
  });
  const [sampledAt, setSampledAt] = useState<string | null>(null);
  const [streamState, setStreamState] = useState<"connecting" | "live" | "reconnecting">("connecting");
  const bottomRef = useRef<HTMLDivElement | null>(null);
  const lastChatMessageKeyRef = useRef("");

  useEffect(() => {
    (window as LiveFrameWindow).__lanChatUnlockHistoryAlert = unlockHistoryAlert;
    const initialLoad = window.setTimeout(() => {
      const nextTheme = new URLSearchParams(window.location.search).get("theme") === "light" ? "light" : "dark";
      setTheme(nextTheme);
    }, 0);
    const controller = new AbortController();
    const loadInitialHistory = async () => {
      try {
        const res = await fetch("/api/chat/history", { cache: "no-store", signal: controller.signal });
        const payload = await res.json() as { messages?: ChatMessage[]; sampledAt?: string };
        const nextMessages = Array.isArray(payload.messages) ? payload.messages : [];
        if (nextMessages.length) setHistory(nextMessages.slice(-80));
        setSampledAt(payload.sampledAt || new Date().toISOString());
      } catch {
        if (!controller.signal.aborted) setStreamState("reconnecting");
      }
    };
    void loadInitialHistory();
    const events = new EventSource("/api/chat/history/stream");
    events.addEventListener("open", () => setStreamState("live"));
    events.addEventListener("ready", (event) => {
      try {
        const payload = JSON.parse((event as MessageEvent).data) as { sampledAt?: string };
        setSampledAt(payload.sampledAt || new Date().toISOString());
        setStreamState("live");
      } catch {
        setStreamState("live");
      }
    });
    events.addEventListener("messages", (event) => {
      try {
        const payload = JSON.parse((event as MessageEvent).data) as { messages?: ChatMessage[]; sampledAt?: string };
        setHistory((current) => {
          const nextMessages = Array.isArray(payload.messages) ? payload.messages : [];
          if (!nextMessages.length) return current;
          const seen = new Set(current.map(messageDeliveryKey));
          const additions = nextMessages.filter((message) => {
            const key = messageDeliveryKey(message);
            if (seen.has(key)) return false;
            seen.add(key);
            return true;
          });
          return additions.length ? [...current, ...additions].slice(-80) : current;
        });
        setSampledAt(payload.sampledAt || new Date().toISOString());
        setStreamState("live");
      } catch {
        setStreamState("reconnecting");
      }
    });
    events.addEventListener("error", () => setStreamState("reconnecting"));
    const onMessage = (event: MessageEvent) => {
      if (event.origin !== window.location.origin) return;
      const data = event.data as { type?: string; message?: ChatMessage; theme?: "light" | "dark" };
      if (data?.type === "lan-chat-theme" && (data.theme === "light" || data.theme === "dark")) {
        setTheme(data.theme);
        return;
      }
      if (data?.type === "lan-chat-unlock-alert") {
        unlockHistoryAlert();
        return;
      }
      if (data?.type !== "lan-chat-local-message" || !data.message) return;
      setLocal((current) => [...current, data.message as ChatMessage].slice(-20));
    };
    window.addEventListener("message", onMessage);
    return () => {
      controller.abort();
      window.clearTimeout(initialLoad);
      events.close();
      window.removeEventListener("message", onMessage);
      delete (window as LiveFrameWindow).__lanChatUnlockHistoryAlert;
    };
  }, []);

  const entries = useMemo(() => mergeEntries(history, local), [history, local]);
  const chatMessageKey = useMemo(() => {
    return [...history, ...local]
      .map(messageDeliveryKey)
      .join("|");
  }, [history, local]);

  useEffect(() => {
    if (!chatMessageKey) return;
    const previousKey = lastChatMessageKeyRef.current;
    lastChatMessageKeyRef.current = chatMessageKey;
    if (!previousKey || previousKey === chatMessageKey) return;
    playHistoryAlert();
    bottomRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [chatMessageKey]);

  return (
    <main className={cx("live-frame-shell", `theme-${theme}`)} data-live-frame="openclaw-lan-command-history">
      <header className="live-frame-head">
        <span>{streamState}</span>
        <strong>OpenClaw history</strong>
        <time>{sampledAt ? formatTime(sampledAt) : "warming"}</time>
      </header>
      <section className="live-frame-feed" aria-label="live OpenClaw chat history">
        {entries.length ? entries.map((entry) => <LiveBubble entry={entry} key={entry.id} />) : (
          <article className="live-message role-system source-history">
            <header><span>OpenClaw history</span><time>now</time></header>
            <div className="live-message-body"><p>Waiting for new chat messages…</p></div>
          </article>
        )}
        <div ref={bottomRef} />
      </section>
    </main>
  );
}
