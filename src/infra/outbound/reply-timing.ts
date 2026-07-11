const TIME_SUMMARY_PREFIX = "Time summary:";

export function appendRealReplyElapsedTime(
  text: string,
  requestStartedAtMs: number | undefined,
  nowMs: number = Date.now(),
): string {
  if (!Number.isFinite(requestStartedAtMs)) {
    return text;
  }
  const elapsedMs = Math.max(0, nowMs - Number(requestStartedAtMs));
  const elapsedSeconds = (elapsedMs / 1000).toFixed(3);
  const withoutExistingSummary = text
    .split("\n")
    .filter((line) => !line.trimStart().startsWith(TIME_SUMMARY_PREFIX))
    .join("\n")
    .replace(/\s+$/u, "");
  return `${withoutExistingSummary}\n\n${TIME_SUMMARY_PREFIX} request-to-response elapsed ${elapsedSeconds}s.`;
}
