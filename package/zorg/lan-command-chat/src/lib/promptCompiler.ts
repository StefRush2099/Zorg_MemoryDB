export async function compileSystemPrompt(inputText: string, metadata: Record<string, unknown> = {}) {
  const base = process.env.NEURAL_RECALL_ACTIVITY_URL?.trim() || "http://127.0.0.1:8097";
  const response = await fetch(new URL("/api/compile", base), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ input: inputText, metadata }),
    cache: "no-store",
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error(`Zorg MemoryDB MCP compile failed: ${response.status}`);
  return response.json();
}
