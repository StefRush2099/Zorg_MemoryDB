import fs from "node:fs";

import { loadUnifiedHistory } from "@/app/api/chat/history/route";
import { getOpenClawSessionsDir } from "@/lib/paths";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const encoder = new TextEncoder();

function historySignature(messages: Awaited<ReturnType<typeof loadUnifiedHistory>>["messages"]) {
  return messages.map((message) => `${message.id}:${message.timestamp ?? ""}:${message.role}:${message.text.length}`).join("|");
}

function messageKey(message: Awaited<ReturnType<typeof loadUnifiedHistory>>["messages"][number]) {
  return `${message.id}:${message.timestamp ?? ""}:${message.role}:${message.text}`;
}

function isDisplayableChatMessage(message: Awaited<ReturnType<typeof loadUnifiedHistory>>["messages"][number]) {
  const text = (message.text || "").trim();
  if (!text && !message.attachments?.length) return false;
  if (text === "[OpenClaw heartbeat poll]") return false;
  if (/^\[cron:/i.test(text)) return false;
  if (/^System \(untrusted\): \[\d{4}-\d{2}-\d{2} .*?\] A scheduled cron job delivered this message/i.test(text)) return false;
  return true;
}

export async function GET(request: Request) {
  let watcher: fs.FSWatcher | null = null;
  let heartbeat: ReturnType<typeof setInterval> | null = null;
  let debounce: ReturnType<typeof setTimeout> | null = null;
  let lastSignature = "";
  const knownMessages = new Set<string>();

  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      const send = (event: string, payload: unknown) => {
        controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(payload)}\n\n`));
      };

      const emitHistory = async (force = false) => {
        try {
          const payload = await loadUnifiedHistory();
          const messages = payload.messages.filter(isDisplayableChatMessage);
          const signature = historySignature(messages);
          if (!force && signature === lastSignature) return;
          lastSignature = signature;
          if (force) {
            messages.forEach((message) => knownMessages.add(messageKey(message)));
            send("ready", { sampledAt: new Date().toISOString() });
            if (messages.length) {
              send("messages", { messages, sampledAt: new Date().toISOString() });
            }
            return;
          }
          const nextMessages = messages.filter((message) => {
            const key = messageKey(message);
            if (knownMessages.has(key)) return false;
            knownMessages.add(key);
            return true;
          });
          if (nextMessages.length) {
            send("messages", { messages: nextMessages, sampledAt: new Date().toISOString() });
          }
        } catch (error) {
          console.error("chat.history stream update failed", error);
          send("stream-error", { sampledAt: new Date().toISOString() });
        }
      };

      const scheduleEmit = () => {
        if (debounce) clearTimeout(debounce);
        debounce = setTimeout(() => void emitHistory(), 250);
      };

      void emitHistory(true);

      try {
        watcher = fs.watch(getOpenClawSessionsDir(), { persistent: false }, scheduleEmit);
      } catch (error) {
        console.error("chat.history stream watcher failed", error);
      }

      heartbeat = setInterval(() => {
        controller.enqueue(encoder.encode(`: keepalive ${Date.now()}\n\n`));
      }, 25000);

      request.signal.addEventListener("abort", () => {
        if (debounce) clearTimeout(debounce);
        if (heartbeat) clearInterval(heartbeat);
        watcher?.close();
        controller.close();
      });
    },
    cancel() {
      if (debounce) clearTimeout(debounce);
      if (heartbeat) clearInterval(heartbeat);
      watcher?.close();
    },
  });

  return new Response(stream, {
    headers: {
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
      "Content-Type": "text/event-stream; charset=utf-8",
      "X-Accel-Buffering": "no",
    },
  });
}
