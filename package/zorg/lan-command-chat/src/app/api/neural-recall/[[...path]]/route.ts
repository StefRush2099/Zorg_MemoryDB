import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";

const UPSTREAM = process.env.NEURAL_RECALL_ACTIVITY_URL || "http://127.0.0.1:8097";

function upstreamUrl(request: NextRequest, parts: string[] = []) {
  const url = new URL(request.url);
  const target = new URL(parts.length ? `/${parts.join("/")}` : "/", UPSTREAM);
  for (const [key, value] of url.searchParams.entries()) target.searchParams.set(key, value);
  return target;
}

function proxyPath(path: string) {
  return `/api/neural-recall${path}`;
}

function rewriteHtml(html: string, request: NextRequest) {
  const url = new URL(request.url);
  const embed = url.searchParams.get("embed") === "graph";
  const theme = url.searchParams.get("theme") === "dark" ? "dark" : "light";
  const embedStyle = embed
    ? `<style>
      .shell{grid-template-columns:1fr!important}
      #graph{width:100vw!important;min-height:100vh!important}
      aside.panel{display:none!important}
      .webgl-fallback{position:absolute;inset:0;display:grid;place-items:center;padding:18px;color:var(--ink);background:var(--bg);font-family:Inter,ui-sans-serif,system-ui,sans-serif}
      .webgl-fallback svg{width:100%;height:100%;max-height:100vh}
      .webgl-fallback text{font-size:12px;fill:var(--ink)}
      .webgl-fallback .muted{fill:var(--muted)}
    </style>`
    : "";
  const fallbackScript = embed
    ? `<script>
      window.addEventListener("error", async (event) => {
        if (!String(event.message || "").includes("WebGL")) return;
        const graph = document.getElementById("graph");
        if (!graph || graph.dataset.fallbackRendered) return;
        graph.dataset.fallbackRendered = "true";
        try {
          const response = await fetch("/api/neural-recall/api/graph");
          const data = await response.json();
          const nodes = (data.nodes || []).slice(0, 42);
          const links = (data.links || []).slice(0, 90);
          const width = Math.max(720, graph.clientWidth || window.innerWidth || 720);
          const height = Math.max(420, graph.clientHeight || window.innerHeight || 420);
          const cx = width / 2;
          const cy = height / 2;
          const radius = Math.min(width, height) * 0.34;
          const position = new Map(nodes.map((node, index) => {
            const angle = (index / Math.max(1, nodes.length)) * Math.PI * 2;
            const ring = radius * (0.45 + (index % 4) * 0.15);
            return [node.id, { x: cx + Math.cos(angle) * ring, y: cy + Math.sin(angle) * ring, node }];
          }));
          const lineMarkup = links.map((link) => {
            const source = position.get(link.source);
            const target = position.get(link.target);
            if (!source || !target) return "";
            return \`<line x1="\${source.x}" y1="\${source.y}" x2="\${target.x}" y2="\${target.y}" stroke="var(--accent)" stroke-opacity=".22" stroke-width="1"/>\`;
          }).join("");
          const nodeMarkup = [...position.values()].map(({ x, y, node }) => {
            const color = node.group === "rule" ? "var(--danger)" : node.group === "activity" ? "var(--warm)" : "var(--accent)";
            return \`<g><circle cx="\${x}" cy="\${y}" r="\${Math.max(4, Math.min(14, Number(node.val || 1) * 2))}" fill="\${color}" opacity=".9"/><text x="\${x + 10}" y="\${y + 4}">\${String(node.label || node.id || "").slice(0, 24).replace(/[&<>"]/g, "")}</text></g>\`;
          }).join("");
          graph.innerHTML = \`<div class="webgl-fallback"><svg viewBox="0 0 \${width} \${height}" role="img" aria-label="Neural Recall Activity fallback graph"><text x="24" y="34" class="muted">WebGL unavailable in this browser - live Neural Recall graph fallback</text>\${lineMarkup}\${nodeMarkup}</svg></div>\`;
        } catch (error) {
          graph.innerHTML = \`<div class="webgl-fallback">WebGL unavailable and graph fallback failed.</div>\`;
        }
      });
    </script>`
    : "";

  return html
    .replace(/<html([^>]*)>/i, `<html$1 data-theme="${theme}">`)
    .replace(/href="\/styles\.css"/g, `href="${proxyPath("/styles.css")}"`)
    .replace(/src="\/vendor\//g, `src="${proxyPath("/vendor/")}`)
    .replace(/src="\/app\.js"/g, `src="${proxyPath("/app.js")}"`)
    .replace("</head>", `${embedStyle}</head>`)
    .replace("</body>", `${fallbackScript}</body>`);
}

function rewriteJavaScript(script: string) {
  return script
    .replaceAll('fetch(`/api/graph${query ? `?q=${encodeURIComponent(query)}` : ""}`)', 'fetch(`/api/neural-recall/api/graph${query ? `?q=${encodeURIComponent(query)}` : ""}`)')
    .replaceAll('fetch("/api/activity")', 'fetch("/api/neural-recall/api/activity")')
    .replace(
      'setTheme(requestedTheme === "light" || localStorage.getItem("zorg-memory-3d-theme") === "light" ? "light" : "dark");',
      'setTheme(requestedTheme === "light" ? "light" : requestedTheme === "dark" ? "dark" : localStorage.getItem("zorg-memory-3d-theme") === "light" ? "light" : "dark");'
    );
}

export async function GET(request: NextRequest, context: { params: Promise<{ path?: string[] }> }) {
  const { path = [] } = await context.params;
  const target = upstreamUrl(request, path);
  const upstream = await fetch(target, {
    headers: { Accept: request.headers.get("accept") || "*/*" },
    cache: "no-store",
  });

  const contentType = upstream.headers.get("content-type") || "application/octet-stream";
  const headers = new Headers();
  headers.set("Cache-Control", "no-store, max-age=0");
  headers.set("Content-Type", contentType);

  if (contentType.includes("text/html")) {
    return new NextResponse(rewriteHtml(await upstream.text(), request), { status: upstream.status, headers });
  }

  if (contentType.includes("javascript")) {
    return new NextResponse(rewriteJavaScript(await upstream.text()), { status: upstream.status, headers });
  }

  return new NextResponse(upstream.body, { status: upstream.status, headers });
}
