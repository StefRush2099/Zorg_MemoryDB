import { NextResponse } from "next/server";

import { appConfig } from "@/lib/env";

export const runtime = "nodejs";

export async function GET() {
  return NextResponse.json({
    sessionKey: appConfig.sessionKey,
    label: "main",
    model: "unavailable",
    thinking: "unknown",
    tokensUsed: 0,
    tokensLimit: 0,
    tokensPercent: 0,
    agentId: "main",
    degraded: true,
  });
}
