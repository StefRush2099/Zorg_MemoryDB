const graphEl = document.getElementById("graph");
const statusEl = document.getElementById("status");
const metricsEl = document.getElementById("metrics");
const detailsEl = document.getElementById("details");
const activityEl = document.getElementById("activity");
const queryInput = document.getElementById("queryInput");
const searchForm = document.getElementById("searchForm");
const themeToggle = document.getElementById("themeToggle");

window.addEventListener("error", (event) => {
  statusEl.textContent = event.message;
});

const colors = {
  core: "#f8fafc",
  query: "#38bdf8",
  neural: "#a78bfa",
  "manual-query": "#f59e0b",
  rule: "#fb7185",
  hint: "#2dd4bf",
  activity: "#f97316",
  job: "#eab308",
  timing: "#22c55e",
  project: "#60a5fa",
  host: "#34d399",
  memory: "#c084fc",
  default: "#94a3b8"
};

const lightColors = {
  core: "#102033",
  query: "#0369a1",
  neural: "#7c3aed",
  "manual-query": "#b45309",
  rule: "#be123c",
  hint: "#0f766e",
  activity: "#c2410c",
  job: "#a16207",
  timing: "#15803d",
  project: "#1d4ed8",
  host: "#047857",
  memory: "#9333ea",
  default: "#475569"
};

let rawGraph = { nodes: [], links: [] };
let currentFilter = "all";
let fitTimers = [];

function palette() {
  return document.documentElement.dataset.theme === "light" ? lightColors : colors;
}

const Graph = ForceGraph3D()(graphEl)
  .backgroundColor("rgba(0,0,0,0)")
  .nodeLabel((node) => `${node.group}: ${node.label}`)
  .nodeColor((node) => palette()[node.group] || palette().default)
  .nodeVal((node) => node.val || 1)
  .linkLabel((link) => link.type || "")
  .linkWidth((link) => Math.max(0.25, Math.min(5, Number(link.value || 1) / 2)))
  .linkOpacity(0.38)
  .linkDirectionalParticles((link) => Math.min(5, Math.max(1, Math.round(Number(link.value || 1) / 3))))
  .linkDirectionalParticleWidth(1.8)
  .d3VelocityDecay(0.58)
  .cooldownTicks(140)
  .onEngineTick(() => constrainGraphSpread())
  .onNodeClick((node) => {
    detailsEl.textContent = JSON.stringify(node, null, 2);
    const distance = 120;
    const distRatio = 1 + distance / Math.hypot(node.x || 1, node.y || 1, node.z || 1);
    Graph.cameraPosition(
      { x: (node.x || 0) * distRatio, y: (node.y || 0) * distRatio, z: (node.z || 0) * distRatio },
      node,
      900
    );
  });

Graph.d3Force("charge").strength(-14).distanceMax(95);
Graph.d3Force("link").distance((link) => {
  const source = link.source.id || link.source;
  const target = link.target.id || link.target;
  const anchored = source === "zorg-memorydb" || target === "zorg-memorydb" || source === "recall-engine" || target === "recall-engine";
  return anchored ? 18 : 26;
});
Graph.d3Force("center").strength(0.22);

function constrainGraphSpread() {
  const nodes = rawGraph.nodes || [];
  const maxRadius = graphEl.clientWidth < 900 ? 115 : 215;
  for (const node of nodes) {
    if (![node.x, node.y, node.z].every(Number.isFinite)) continue;
    const radius = Math.hypot(node.x, node.y, node.z);
    if (radius <= maxRadius) continue;
    const scale = maxRadius / radius;
    node.x *= scale;
    node.y *= scale;
    node.z *= scale;
    node.vx = (node.vx || 0) * 0.45;
    node.vy = (node.vy || 0) * 0.45;
    node.vz = (node.vz || 0) * 0.45;
  }
}

function fitGraph(delay = 450) {
  const timer = setTimeout(() => {
    try {
      const distance = graphEl.clientWidth < 900 ? 860 : 690;
      Graph.cameraPosition({ x: 0, y: 0, z: distance }, { x: 0, y: 0, z: 0 }, 900);
    } catch {
      // The graph may still be initializing; the next refresh will fit it.
    }
  }, delay);
  fitTimers.push(timer);
  while (fitTimers.length > 5) clearTimeout(fitTimers.shift());
}

function resize() {
  Graph.width(graphEl.clientWidth).height(graphEl.clientHeight);
  fitGraph(250);
}

window.addEventListener("resize", resize);
resize();

function applyFilter() {
  if (currentFilter === "all") {
    Graph.graphData(rawGraph);
    return;
  }
  const keep = new Set(
    rawGraph.nodes
      .filter((node) => node.group === currentFilter || (currentFilter === "activity" && ["activity", "job", "timing"].includes(node.group)))
      .map((node) => node.id)
  );
  keep.add("zorg-memorydb");
  keep.add("recall-engine");
  keep.add("live-activity");
  const links = rawGraph.links.filter((link) => keep.has(link.source.id || link.source) && keep.has(link.target.id || link.target));
  const linked = new Set(links.flatMap((link) => [link.source.id || link.source, link.target.id || link.target]));
  Graph.graphData({ nodes: rawGraph.nodes.filter((node) => linked.has(node.id)), links });
}

function renderMetrics(stats = {}, graph = rawGraph) {
  const entries = [
    ["nodes", graph.nodes.length],
    ["links", graph.links.length],
    ...Object.entries(stats)
  ];
  metricsEl.innerHTML = entries
    .slice(0, 8)
    .map(([label, count]) => `<div class="metric"><strong>${Number(count).toLocaleString()}</strong><span>${label}</span></div>`)
    .join("");
}

function renderActivity(items) {
  activityEl.innerHTML = items
    .slice(0, 18)
    .map((item) => {
      const at = item.at ? new Date(item.at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" }) : "";
      return `<li><strong>${item.title}</strong>${at} · ${item.kind}<br>${item.detail || ""}</li>`;
    })
    .join("");
}

async function loadGraph(query = "") {
  statusEl.textContent = query ? "Tracing recall path..." : "Loading memory graph...";
  const response = await fetch(`/api/graph${query ? `?q=${encodeURIComponent(query)}` : ""}`);
  if (!response.ok) throw new Error(await response.text());
  const data = await response.json();
  rawGraph = { nodes: data.nodes, links: data.links };
  resize();
  Graph.graphData(rawGraph);
  constrainGraphSpread();
  applyFilter();
  fitGraph();
  fitGraph(2600);
  renderMetrics(data.stats, rawGraph);
  statusEl.textContent = data.highlight
    ? `Recall trace returned ${data.highlight.resultCount} ranked results.`
    : `Live graph generated ${new Date(data.generatedAt).toLocaleTimeString()}.`;
}

async function loadActivity() {
  const response = await fetch("/api/activity");
  if (response.ok) renderActivity(await response.json());
}

searchForm.addEventListener("submit", (event) => {
  event.preventDefault();
  loadGraph(queryInput.value.trim()).catch((error) => {
    statusEl.textContent = error.message;
  });
});

document.querySelectorAll("[data-filter]").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll("[data-filter]").forEach((item) => item.classList.remove("active"));
    button.classList.add("active");
    currentFilter = button.dataset.filter;
    applyFilter();
  });
});

function setTheme(theme) {
  document.documentElement.dataset.theme = theme;
  themeToggle.textContent = theme === "light" ? "Dark View" : "Light View";
  themeToggle.setAttribute("aria-pressed", theme === "light" ? "true" : "false");
  localStorage.setItem("zorg-memory-3d-theme", theme);
  Graph.nodeColor((node) => palette()[node.group] || palette().default);
  if (typeof Graph.refresh === "function") Graph.refresh();
}

themeToggle.addEventListener("click", () => {
  setTheme(document.documentElement.dataset.theme === "light" ? "dark" : "light");
});

const requestedTheme = new URLSearchParams(location.search).get("theme");
setTheme(requestedTheme === "light" || localStorage.getItem("zorg-memory-3d-theme") === "light" ? "light" : "dark");

loadGraph().catch((error) => {
  statusEl.textContent = error.message;
});
loadActivity();
setInterval(() => loadGraph(queryInput.value.trim()).catch(() => {}), 30000);
setInterval(loadActivity, 7000);
setTimeout(resize, 500);
setTimeout(resize, 2000);

try {
  const socket = new WebSocket(`${location.protocol === "https:" ? "wss" : "ws"}://${location.host}/ws`);
  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.type === "activity") renderActivity(message.data);
  });
} catch {
  // Periodic fetch remains active when websockets are unavailable.
}
