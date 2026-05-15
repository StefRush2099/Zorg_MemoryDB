import { NextRequest, NextResponse } from "next/server";

const AUTH_COOKIE = "lan_chat_auth";
const AUTH_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;
const LAN_CHAT_PUBLIC_PATHS = new Set(["/", "/api/auth/login", "/api/chat/identity", "/api/chat/status", "/favicon.ico"]);


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

function base64UrlDecode(value: string): string | null {
  try {
    const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    return atob(padded);
  } catch {
    return null;
  }
}

function bytesToBase64Url(bytes: ArrayBuffer): string {
  let binary = "";
  for (const byte of new Uint8Array(bytes)) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function hasValidLogin(req: NextRequest): Promise<boolean> {
  const secret = process.env.LAN_CHAT_AUTH_SECRET?.trim();
  if (!secret) return false;
  const token = req.cookies.get(AUTH_COOKIE)?.value || "";
  const [version, issuedEncoded, signature] = token.split(".");
  if (version !== "v1" || !issuedEncoded || !signature) return false;
  const issued = base64UrlDecode(issuedEncoded);
  if (!issued || !/^\d+$/.test(issued)) return false;
  const age = Date.now() - Number.parseInt(issued, 10);
  if (age < 0 || age > AUTH_MAX_AGE_MS) return false;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const expected = bytesToBase64Url(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(issued)));
  return expected === signature;
}

function isAssetPath(pathname: string): boolean {
  return pathname.startsWith("/_next/") || pathname.startsWith("/assets/");
}

export async function middleware(req: NextRequest) {
  const ip = getClientIp(req);
  if (!isAllowed(ip)) {
    return new NextResponse("Forbidden", { status: 403 });
  }

  const { pathname } = req.nextUrl;
  if (LAN_CHAT_PUBLIC_PATHS.has(pathname) || isAssetPath(pathname)) {
    return NextResponse.next();
  }

  if (await hasValidLogin(req)) {
    return NextResponse.next();
  }

  if (pathname.startsWith("/api/")) {
    return NextResponse.json({ ok: false, error: "Login required" }, { status: 401 });
  }

  const loginUrl = req.nextUrl.clone();
  loginUrl.pathname = "/";
  loginUrl.searchParams.set("next", pathname);
  return NextResponse.redirect(loginUrl);
}

export const config = {
  matcher: ["/:path*"],
};
