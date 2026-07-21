import { NextResponse } from "next/server";
import { promises as fs } from "node:fs";
import { basename, join } from "node:path";
import { tmpdir } from "node:os";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

import { appConfig } from "@/lib/env";

export const runtime = "nodejs";

const MAX_AUDIO_BYTES = 25 * 1024 * 1024;

const execFileAsync = promisify(execFile);

export async function POST(request: Request) {
  let workDir = "";
  try {
    const contentType = request.headers.get("content-type") || "";
    if (!contentType.includes("multipart/form-data") && !contentType.includes("application/x-www-form-urlencoded")) {
      return NextResponse.json({ error: "Multipart audio upload is required" }, { status: 400 });
    }

    const incoming = await request.formData();
    const audio = incoming.get("audio");
    const language = incoming.get("language");
    const prompt = incoming.get("prompt");

    if (!(audio instanceof File)) {
      return NextResponse.json({ error: "Audio file is required" }, { status: 400 });
    }

    if (audio.size <= 0) {
      return NextResponse.json({ error: "Audio file is empty" }, { status: 400 });
    }

    if (audio.size > MAX_AUDIO_BYTES) {
      return NextResponse.json({ error: "Audio file is too large for transcription" }, { status: 413 });
    }

    workDir = await fs.mkdtemp(join(tmpdir(), "lan-chat-whisper-"));
    const inputPath = join(workDir, "audio.webm");
    const outputPath = join(workDir, "audio.txt");
    await fs.writeFile(inputPath, Buffer.from(await audio.arrayBuffer()));
    try {
      const args = [inputPath, "--model", appConfig.whisperModel, "--output_format", "txt", "--output_dir", workDir];
      if (typeof language === "string" && language.trim()) args.push("--language", language.trim());
      if (typeof prompt === "string" && prompt.trim()) args.push("--initial_prompt", prompt.trim());
      await execFileAsync(appConfig.whisperBinary, args, { timeout: 120000, maxBuffer: 1024 * 1024 });
    } catch (error) {
      console.error("Local Whisper transcription failed", error instanceof Error ? error.message : "unknown error");
      return NextResponse.json({ error: "Local Whisper transcription failed" }, { status: 502 });
    }
    const text = (await fs.readFile(outputPath, "utf8")).trim();
    if (!text) {
      return NextResponse.json({ error: "Local Whisper returned an empty transcript" }, { status: 502 });
    }
    return NextResponse.json({ text, model: appConfig.whisperModel });
  } catch (error) {
    console.error("transcription failed", error);
    return NextResponse.json({ error: "Failed to transcribe audio" }, { status: 500 });
  } finally {
    if (workDir) await fs.rm(workDir, { recursive: true, force: true }).catch(() => undefined);
  }
}
