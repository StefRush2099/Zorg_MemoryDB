import http from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const host = process.env.HOST || "0.0.0.0";
const port = Number(process.env.PORT || 8097);
const publicDir = new URL("./public/", import.meta.url).pathname;
const workspace = process.env.OPENCLAW_WORKSPACE || "/home/zorg/.openclaw/workspace";
const mcpServer = process.env.ZORG_MEMORYDB_MCP || "/home/zorg/.local/src/Zorg_MemoryDB-v4.0.1/skills/zorg-db-memory/plugin-src/dist/mcp-server.js";

const client = new Client({ name: "neural-recall-activity", version: "4.0.1" });
await client.connect(new StdioClientTransport({
  command: process.execPath,
  args: [mcpServer],
  env: { ...process.env, OPENCLAW_WORKSPACE: workspace },
}));

async function tool(name, args = {}) {
  const result = await client.callTool({ name, arguments: args });
  const text = result.content?.find((item) => item.type === "text")?.text || "[]";
  return JSON.parse(text);
}

function unwrap(rows) {
  return rows.map((row) => row.row_data ?? row).filter(Boolean);
}

function graphFrom(rows, ann, query = "") {
  const records = unwrap(rows);
  const nodes = [
    { id: "zorg-memorydb", label: "Zorg MemoryDB MCP", group: "core", val: 8 },
    { id: "recall-engine", label: "Neural Recall", group: "neural", val: 7 },
    { id: "live-activity", label: `${ann.active_embeddings || 0} vectors`, group: "activity", val: 6 },
  ];
  const links = [
    { source: "zorg-memorydb", target: "recall-engine", type: "MCP recall", value: 8 },
    { source: "recall-engine", target: "live-activity", type: "ANN", value: 7 },
  ];
  const linkedSemantic = new Set(links.flatMap((link) => [link.source, link.target]).filter((id) => String(id).startsWith("semantic-")));
  for (const record of records) {
    const id = `semantic-${record.node_key}`;
    if (!linkedSemantic.has(id)) links.push({ source: "recall-engine", target: id, type: "semantic catalog", value: 0.5 });
  }
  records.slice(0, 60).forEach((record, index) => {
    const id = `memory-${index}`;
    const label = String(record.rule_title || record.memory_key || record.title || record.content || record.memory_value || `Memory ${index + 1}`).replace(/\s+/g, " ").slice(0, 72);
    const group = record.rule_text || record.rule_title ? "rule" : "memory";
    nodes.push({ id, label, group, val: Math.max(2, 6 - Math.floor(index / 12)), record });
    links.push({ source: query ? "recall-engine" : "zorg-memorydb", target: id, type: query ? "ranked recall" : "recent context", value: Math.max(1, 6 - Math.floor(index / 10)) });
  });
  return { generatedAt: new Date().toISOString(), nodes, links, stats: { records: records.length, vectors: Number(ann.active_embeddings || 0), queued: Number(ann.queued_jobs || 0), failed: Number(ann.failed_jobs || 0) }, highlight: query ? { query, resultCount: records.length } : null };
}

function semanticGraphFrom(payload, ann) {
  const graph = payload?.graph || payload || {};
  const records = Array.isArray(graph.nodes) ? graph.nodes : [];
  const semanticIds = new Set(records.map((record) => record.node_key));
  const nodes = [
    { id: "zorg-memorydb", label: "Zorg MemoryDB MCP", group: "core", val: 10 },
    { id: "recall-engine", label: "Neural Recall", group: "neural", val: 9 },
    { id: "live-activity", label: `${ann.active_embeddings || 0} vectors`, group: "activity", val: 8 },
    ...records.map((record) => ({ id: `semantic-${record.node_key}`, label: String(record.canonical_label || record.node_key).replace(/\s+/g, " ").slice(0, 96), group: record.node_type || "memory", val: Math.max(2, Math.min(9, 2 + Number(record.confidence || 0) * 5)), record })),
  ];
  const links = [
    { source: "zorg-memorydb", target: "recall-engine", type: "MCP graph", value: 9 },
    { source: "recall-engine", target: "live-activity", type: "ANN", value: 8 },
    ...((Array.isArray(graph.links) ? graph.links : []).filter((link) => semanticIds.has(link.subject_key) && semanticIds.has(link.object_key)).map((link) => ({ source: `semantic-${link.subject_key}`, target: `semantic-${link.object_key}`, type: link.relation, value: Number(link.weight || 1) }))),
  ];
  return { generatedAt: new Date().toISOString(), nodes, links, stats: { displayedNodes: records.length, totalNodes: Number(graph.totalNodes || records.length), displayedLinks: links.length - 2, totalLinks: Number(graph.totalLinks || 0), vectors: Number(ann.active_embeddings || 0), queued: Number(ann.queued_jobs || 0), failed: Number(ann.failed_jobs || 0), offset: Number(graph.offset || 0), pageSize: Number(graph.limit || records.length) }, highlight: null };
}

function json(res, status, value) {
  res.writeHead(status, { "Content-Type": "application/json", "Cache-Control": "no-store", "Access-Control-Allow-Origin": "*" });
  res.end(JSON.stringify(value));
}

const mime = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8", ".svg": "image/svg+xml" };

http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);
    if (url.pathname === "/api/health") {
      const [health, annRows] = await Promise.all([tool("memory_health"), tool("memory_ann_status")]);
      return json(res, 200, { ok: true, service: "neural-recall-activity", transport: "MCP stdio", memory: health[0], ann: annRows[0] });
    }
    if (url.pathname === "/api/graph") {
      const query = url.searchParams.get("q")?.trim() || "";
      const limit = Math.max(1, Math.min(5000, Number(url.searchParams.get("limit") || 1000)));
      const offset = Math.max(0, Number(url.searchParams.get("offset") || 0));
      const [rows, annRows] = await Promise.all([query ? tool("memory_search", { query, limit: 50 }) : tool("memory_graph", { limit, offset }), tool("memory_ann_status")]);
      return json(res, 200, query ? graphFrom(rows, annRows[0] || {}, query) : semanticGraphFrom(rows[0], annRows[0] || {}));
    }
    if (url.pathname === "/api/activity") {
      const rows = unwrap(await tool("memory_search", { query: "memory", limit: 18 }));
      return json(res, 200, rows.map((row, index) => ({ title: String(row.rule_title || row.memory_key || row.title || `Memory ${index + 1}`).slice(0, 80), kind: row.rule_type || row.memory_category || "memory", detail: String(row.rule_text || row.memory_value || row.content || "").replace(/\s+/g, " ").slice(0, 180), at: row.updated_at || row.logged_at || row.created_at || null })));
    }
    if (url.pathname === "/api/compile" && req.method === "POST") {
      let body = "";
      for await (const chunk of req) body += chunk;
      const input = JSON.parse(body || "{}");
      const inputText = String(input.input || "");
      const rows = unwrap(await tool("memory_recall_preflight", { query: inputText, limit: 10 }));
      const context = rows.map((row) => String(row.rule_text || row.memory_value || row.content || JSON.stringify(row))).join("\n\n");
      return json(res, 200, {
        compiled_prompt: context ? `${context}\n\nCurrent request:\n${inputText}` : inputText,
        detected_intent: "mcp_recall_preflight",
        matched_rule_keys: rows.map((row) => row.rule_key || row.memory_key || row.id).filter(Boolean),
        matched_tool_keys: [],
        matched_categories: [...new Set(rows.map((row) => row.rule_type || row.memory_category).filter(Boolean))],
      });
    }
    const relative = url.pathname === "/" ? "index.html" : normalize(url.pathname).replace(/^\/+/, "");
    const path = join(publicDir, relative);
    if (!path.startsWith(publicDir)) return json(res, 403, { error: "forbidden" });
    const body = await readFile(path);
    res.writeHead(200, { "Content-Type": mime[extname(path)] || "application/octet-stream", "Cache-Control": "no-cache" });
    res.end(body);
  } catch (error) {
    json(res, 500, { error: error instanceof Error ? error.message : String(error) });
  }
}).listen(port, host, () => console.log(`Neural Recall Activity listening on ${host}:${port} via Zorg MemoryDB MCP`));
