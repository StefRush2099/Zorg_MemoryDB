import { NextResponse } from "next/server";

import { appConfig } from "@/lib/env";

export const runtime = "nodejs";

const MAX_AUDIO_BYTES = 25 * 1024 * 1024;
const TRANSCRIBE_TIMEOUT_MS = 120_000;
const OPENAI_WHISPER_MODELS = ["whisper-1", "Systran/faster-whisper-base", "Systran/faster-whisper-small"];

type TranscriptAttempt = {
  base: string;
  route: string;
  model?: string;
};

function endpointBases() {
  return [appConfig.whisperPrimaryBase, appConfig.whisperFallbackBase]
    .map((base) => base.replace(/\/+$/, ""))
    .filter((base, index, all) => base && all.indexOf(base) === index);
}

function appendOptionalFields(form: FormData, language: FormDataEntryValue | null, prompt: FormDataEntryValue | null) {
  if (typeof language === "string" && language.trim()) form.append("language", language.trim());
  if (typeof prompt === "string" && prompt.trim()) form.append("prompt", prompt.trim());
}

function parseTranscript(data: unknown) {
  if (typeof data === "string") return data.trim();
  if (!data || typeof data !== "object") return "";
  const record = data as Record<string, unknown>;
  for (const key of ["text", "transcript", "transcription"]) {
    const value = record[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return "";
}

async function postWithTimeout(url: string, form: FormData) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TRANSCRIBE_TIMEOUT_MS);
  try {
    return await fetch(url, { method: "POST", body: form, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

async function transcribeViaAsr(base: string, audio: File, language: FormDataEntryValue | null, prompt: FormDataEntryValue | null) {
  const form = new FormData();
  form.append("audio", audio, audio.name || "lan-chat-voice.webm");
  form.append("file", audio, audio.name || "lan-chat-voice.webm");
  appendOptionalFields(form, language, prompt);
  const response = await postWithTimeout(`${base}/asr`, form);
  if (!response.ok) throw new Error(`/asr returned ${response.status}`);
  const contentType = response.headers.get("content-type") || "";
  const data = contentType.includes("application/json") ? await response.json() : await response.text();
  const text = parseTranscript(data);
  if (!text) throw new Error("/asr returned an empty transcript");
  return text;
}

async function transcribeViaOpenAi(
  base: string,
  audio: File,
  model: string,
  language: FormDataEntryValue | null,
  prompt: FormDataEntryValue | null,
) {
  const form = new FormData();
  form.append("file", audio, audio.name || "lan-chat-voice.webm");
  form.append("model", model);
  appendOptionalFields(form, language, prompt);
  const response = await postWithTimeout(`${base}/v1/audio/transcriptions`, form);
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(`/v1/audio/transcriptions ${model} returned ${response.status}`);
  const text = parseTranscript(data);
  if (!text) throw new Error(`/v1/audio/transcriptions ${model} returned an empty transcript`);
  return text;
}

export async function POST(request: Request) {
  const failures: string[] = [];
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

    for (const base of endpointBases()) {
      const attempts: TranscriptAttempt[] = [
        { base, route: "/asr" },
        ...OPENAI_WHISPER_MODELS.map((model) => ({ base, route: "/v1/audio/transcriptions", model })),
      ];
      for (const attempt of attempts) {
        try {
          const text = attempt.route === "/asr"
            ? await transcribeViaAsr(base, audio, language, prompt)
            : await transcribeViaOpenAi(base, audio, attempt.model || OPENAI_WHISPER_MODELS[0], language, prompt);
          return NextResponse.json({ text, endpoint: base, route: attempt.route, model: attempt.model || "asr" });
        } catch (error) {
          failures.push(`${base}${attempt.route}${attempt.model ? ` ${attempt.model}` : ""}: ${error instanceof Error ? error.message : "failed"}`);
        }
      }
    }

    console.error("Whisper transcription failed", failures.join(" | "));
    return NextResponse.json({ error: "Whisper transcription failed", failures }, { status: 502 });
  } catch (error) {
    console.error("transcription failed", error);
    return NextResponse.json({ error: "Failed to transcribe audio" }, { status: 500 });
  }
}
