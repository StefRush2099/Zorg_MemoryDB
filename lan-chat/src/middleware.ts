import { NextRequest, NextResponse } from "next/server";

const ALLOWED_CIDRS = [
  ["10.2.69.0", 24],
  ["10.6.69.0", 24],
  ["10.7.69.0", 24],
  ["10.8.69.0", 24],
] as const;

function ipToInt(ip: string): number | null {
  const parts = ip.split(".").map((p) => Number.parseInt(p, 10));
  if (parts.length !== 4 || parts.some((p) => !Number.isFinite(p) || p < 0 || p > 255)) return null;
  return ((parts[0] << 24) >>> 0) + (parts[1] << 16) + (parts[2] << 8) + parts[3];
}

function inCidr(ip: string, cidrIp: string, prefix: number): boolean {
  const ipInt = ipToInt(ip);
  const cidrInt = ipToInt(cidrIp);
  if (ipInt === null || cidrInt === null) return false;
  const mask = prefix === 0 ? 0 : ((0xffffffff << (32 - prefix)) >>> 0);
  return (ipInt & mask) === (cidrInt & mask);
}

function getClientIp(req: NextRequest): string | null {
  const xff = req.headers.get("x-forwarded-for");
  if (xff) return xff.split(",")[0]?.trim() || null;
  const realIp = req.headers.get("x-real-ip");
  if (realIp) return realIp.trim();
  const directIp = (req as NextRequest & { ip?: string }).ip;
  if (directIp) return directIp;
  return null;
}

function isAllowed(ip: string | null): boolean {
  if (!ip) return false;
  if (ip === "127.0.0.1" || ip === "::1") return true;
  if (ip.startsWith("::ffff:")) ip = ip.replace("::ffff:", "");
  return ALLOWED_CIDRS.some(([base, prefix]) => inCidr(ip, base, prefix));
}

export function middleware(req: NextRequest) {
  const ip = getClientIp(req);
  if (!isAllowed(ip)) {
    return new NextResponse("Forbidden", { status: 403 });
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/:path*"],
};
