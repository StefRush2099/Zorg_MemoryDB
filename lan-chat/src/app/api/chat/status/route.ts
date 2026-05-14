import { NextResponse } from "next/server";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

import { appConfig } from "@/lib/env";

export const runtime = "nodejs";

const execFileAsync = promisify(execFile);
const OPENCLAW_BIN = process.env.OPENCLAW_BIN || "/home/openclaw/.npm-global/bin/openclaw";

type SessionSummary = {
  agentId?: string;
  key?: string;
  kind?: string;
  model?: string;
  inputTokens?: number;
  outputTokens?: number;
  totalTokens?: number;
  remainingTokens?: number;
  percentUsed?: number;
  contextTokens?: number;
  updatedAt?: number;
};

function asNumber(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function fallbackStatus() {
  return {
    sessionKey: appConfig.sessionKey,
    label: "main",
    model: process.env.OPENCLAW_MODEL || process.env.MODEL || "loading",
    thinking: process.env.OPENCLAW_THINKING || process.env.THINKING || "default",
    tokensUsed: 0,
    tokensLimit: 0,
    tokensPercent: 0,
    agentId: "main",
    degraded: true,
  };
}

export async function GET() {
  try {
    const { stdout } = await execFileAsync(OPENCLAW_BIN, ["status", "--json"], { timeout: 15000, maxBuffer: 1024 * 1024 });
    const payload = JSON.parse(stdout);
    const sessions = Array.isArray(payload?.sessions?.recent) ? (payload.sessions.recent as SessionSummary[]) : [];
    const target = sessions.find((s) => s.key === appConfig.sessionKey) || sessions.find((s) => s.key === "agent:main:main") || sessions[0];
    const defaults = payload?.sessions?.defaults || {};
    const tokensUsed = asNumber(target?.totalTokens) || asNumber(target?.inputTokens) + asNumber(target?.outputTokens);
    const tokensLimit = asNumber(target?.contextTokens) || asNumber(defaults?.contextTokens);
    const tokensPercent = typeof target?.percentUsed === "number" ? target.percentUsed : tokensLimit ? Math.round((tokensUsed / tokensLimit) * 100) : 0;

    return NextResponse.json({
      sessionKey: appConfig.sessionKey,
      label: target?.key === appConfig.sessionKey ? "lan-chat" : target?.kind || "main",
      model: target?.model || defaults?.model || "unknown",
      thinking: process.env.OPENCLAW_THINKING || process.env.THINKING || "default",
      tokensUsed,
      tokensLimit,
      tokensPercent,
      agentId: target?.agentId || "main",
      updatedAt: target?.updatedAt || null,
      degraded: !target,
    });
  } catch (error) {
    console.error("chat status failed", error);
    return NextResponse.json(fallbackStatus());
  }
}
