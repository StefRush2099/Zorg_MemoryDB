import { NextResponse } from "next/server";

import { appConfig } from "@/lib/env";
import { getDbPool } from "@/lib/db";
import { callGateway } from "@/lib/gatewayWs";
import { normalizeMessages } from "@/lib/chat";
import { logAppActivity } from "@/lib/chatIngest";

export const runtime = "nodejs";

type ChatHistoryResponse = {
  messages?: unknown[];
};

async function loadGatewayHistory() {
  const raw = await callGateway<ChatHistoryResponse>({
    method: "chat.history",
    params: {
      sessionKey: appConfig.sessionKey,
      limit: appConfig.historyLimit,
    },
    timeoutMs: appConfig.gatewayTimeoutMs,
  });

  return normalizeMessages(raw?.messages ?? []);
}

async function loadDbHistory() {
  const pool = getDbPool();
  if (!pool) return null;

  const { rows } = await pool.query<{
    memory_key: string | null;
    memory_value: string | null;
    logged_at: Date | string | null;
  }>(
    `
      SELECT memory_key, memory_value, logged_at
      FROM zorg_memory
      WHERE memory_category IN ('chat_ingest_user', 'chat_ingest_assistant', 'chat_project_user', 'chat_project_assistant')
      ORDER BY logged_at DESC
      LIMIT $1
    `,
    [appConfig.historyLimit],
  );

  return rows
    .map((row, index) => {
      if (!row.memory_value) return null;
      try {
        const parsed = JSON.parse(row.memory_value) as {
          role?: "user" | "assistant" | "system";
          message?: string;
          timestamp?: number | null;
        };
        if (!parsed?.message || (parsed.role !== "user" && parsed.role !== "assistant" && parsed.role !== "system")) return null;
        return {
          id: row.memory_key || `db-${index}`,
          role: parsed.role,
          text: parsed.message,
          timestamp: parsed.timestamp ?? (row.logged_at ? new Date(row.logged_at).getTime() : undefined),
        };
      } catch {
        return null;
      }
    })
    .filter((message): message is NonNullable<typeof message> => Boolean(message))
    .reverse();
}

export async function GET() {
  try {
    const dbMessages = await loadDbHistory();
    if (dbMessages) {
      await logAppActivity({
        activityKey: `history:${Date.now()}`,
        activityType: "chat_history",
      });
      return NextResponse.json({ messages: dbMessages, source: "db" });
    }

    const gatewayMessages = await loadGatewayHistory();
    return NextResponse.json({ messages: gatewayMessages, source: "gateway", degraded: true });
  } catch (error) {
    console.error("chat.history failed", error);

    try {
      const gatewayMessages = await loadGatewayHistory();
      return NextResponse.json({ messages: gatewayMessages, source: "gateway", degraded: true });
    } catch (fallbackError) {
      console.error("chat.history gateway fallback failed", fallbackError);
      return NextResponse.json({ error: "Failed to load chat history" }, { status: 500 });
    }
  }
}
