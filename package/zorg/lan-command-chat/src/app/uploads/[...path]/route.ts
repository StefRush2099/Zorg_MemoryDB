import { NextResponse } from "next/server";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";

export const runtime = "nodejs";

const UPLOAD_DIR = path.join(process.cwd(), "public", "uploads");

const CONTENT_TYPES: Record<string, string> = {
  ".aac": "audio/aac",
  ".bmp": "image/bmp",
  ".gif": "image/gif",
  ".jpeg": "image/jpeg",
  ".jpg": "image/jpeg",
  ".m4a": "audio/mp4",
  ".mov": "video/quicktime",
  ".mp3": "audio/mpeg",
  ".mp4": "video/mp4",
  ".ogg": "audio/ogg",
  ".opus": "audio/opus",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".wav": "audio/wav",
  ".webm": "video/webm",
  ".webp": "image/webp",
};

type RouteContext = {
  params: Promise<{ path?: string[] }>;
};

function uploadPath(parts: string[]) {
  const joined = path.join(UPLOAD_DIR, ...parts);
  const relative = path.relative(UPLOAD_DIR, joined);
  if (relative.startsWith("..") || path.isAbsolute(relative)) return null;
  return joined;
}

export async function GET(_request: Request, context: RouteContext) {
  const params = await context.params;
  const parts = params.path ?? [];
  const filePath = uploadPath(parts);
  if (!filePath) return NextResponse.json({ error: "Not found" }, { status: 404 });

  try {
    const info = await stat(/* turbopackIgnore: true */ filePath);
    if (!info.isFile()) return NextResponse.json({ error: "Not found" }, { status: 404 });
    const data = await readFile(/* turbopackIgnore: true */ filePath);
    const type = CONTENT_TYPES[path.extname(filePath).toLowerCase()] ?? "application/octet-stream";
    return new NextResponse(data, {
      headers: {
        "Cache-Control": "private, max-age=3600",
        "Content-Length": String(info.size),
        "Content-Type": type,
      },
    });
  } catch {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }
}
