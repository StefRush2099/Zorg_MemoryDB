import { NextResponse } from "next/server";

import { appConfig } from "@/lib/env";
import { callGateway } from "@/lib/gatewayWs";

export const runtime = "nodejs";

type RawBlock = {
  type?: string;
  text?: string;
  name?: string;
  toolName?: string;
  id?: string;
  arguments?: unknown;
  thinking?: string;
};

type RawMessage = {
  role?: string;
  content?: unknown;
  text?: string;
  timestamp?: number;
  stopReason?: string;
  model?: string;
  usage?: { input?: number; output?: number; totalTokens?: number };
};

type ChatHistoryResponse = {
  messages?: RawMessage[];
};

type ActivityEntry = {
  kind: "thinking" | "tool" | "result" | "assistant" | "user" | "status";
  label: string;
  detail?: string;
  timestamp?: number;
};

function compact(value: unknown, max = 180) {
  if (value == null) return "";
  const text = typeof value === "string" ? value : JSON.stringify(value);
  return text.replace(/\s+/g, " ").trim().slice(0, max);
}

function contentBlocks(message: RawMessage): RawBlock[] {
  if (Array.isArray(message.content)) return message.content.filter((block): block is RawBlock => Boolean(block && typeof block === "object"));
  if (typeof message.text === "string" && message.text.trim()) return [{ type: "text", text: message.text }];
  return [];
}

function messageText(message: RawMessage) {
  if (typeof message.text === "string") return message.text;
  return contentBlocks(message)
    .map((block) => (block.type === "text" && typeof block.text === "string" ? block.text : ""))
    .filter(Boolean)
    .join("\n");
}

function entryFromMessage(message: RawMessage): ActivityEntry[] {
  const ts = message.timestamp;
  if (message.role === "user") return [{ kind: "user", label: "Received command", detail: compact(messageText(message), 120), timestamp: ts }];
  if (message.role === "toolResult") return [{ kind: "result", label: "Tool result received", detail: compact(messageText(message), 120), timestamp: ts }];
  if (message.role !== "assistant") return [];

  const entries: ActivityEntry[] = [];
  for (const block of contentBlocks(message)) {
    if (block.type === "thinking") entries.push({ kind: "thinking", label: "Thinking", detail: compact(block.thinking || block.text || "Reasoning step"), timestamp: ts });
    else if (block.type === "toolCall") entries.push({ kind: "tool", label: `Using ${block.name || block.toolName || "tool"}`, detail: compact(block.arguments, 140), timestamp: ts });
    else if (block.type === "text" && block.text?.trim()) entries.push({ kind: "assistant", label: "Reply ready", detail: compact(block.text, 140), timestamp: ts });
  }
  if (entries.length === 0 && messageText(message).trim()) entries.push({ kind: "assistant", label: "Reply ready", detail: compact(messageText(message), 140), timestamp: ts });
  if (message.stopReason === "toolUse" && entries.length === 0) entries.push({ kind: "tool", label: "Using tools", timestamp: ts });
  return entries;
}

function resolvePhase(messages: RawMessage[], events: ActivityEntry[]) {
  const last = messages[messages.length - 1];
  if (!last) return { active: false, phase: "idle", label: "Idle" };
  if (last.role === "user") return { active: true, phase: "queued", label: "Command received — waiting for model" };
  if (last.role === "toolResult") return { active: true, phase: "thinking", label: "Tool result in — thinking" };
  if (last.role === "assistant" && last.stopReason === "toolUse") return { active: true, phase: "tool", label: "Using tools" };
  const latest = events[events.length - 1];
  if (latest?.kind === "assistant") return { active: false, phase: "final", label: "Reply ready" };
  return { active: false, phase: "idle", label: "Idle" };
}

export async function GET() {
  try {
    const raw = await callGateway<ChatHistoryResponse>({
      method: "chat.history",
      params: { sessionKey: appConfig.sessionKey, limit: 20 },
      timeoutMs: appConfig.gatewayTimeoutMs,
    });
    const messages = Array.isArray(raw?.messages) ? raw.messages : [];
    const events = messages.flatMap(entryFromMessage).slice(-8);
    const phase = resolvePhase(messages, events);
    return NextResponse.json({
      sampledAt: new Date().toISOString(),
      sessionKey: appConfig.sessionKey,
      ...phase,
      events,
    });
  } catch (error) {
    console.error("chat activity failed", error);
    return NextResponse.json({
      sampledAt: new Date().toISOString(),
      sessionKey: appConfig.sessionKey,
      active: false,
      phase: "degraded",
      label: "Activity feed unavailable",
      events: [],
      degraded: true,
    });
  }
}
