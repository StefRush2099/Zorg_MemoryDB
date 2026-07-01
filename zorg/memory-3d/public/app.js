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
  "manual-query": "#f59e0b",
  rule: "#fb7185",
  table: "#2dd4bf",
  schema: "#818cf8",
  record: "#c084fc",
  reference: "#34d399",
  activity: "#f97316",
  job: "#eab308",
  timing: "#22c55e",
  project: "#60a5fa",
  host: "#34d399",
  default: "#94a3b8"
};

const lightColors = {
  core: "#102033",
  query: "#0369a1",
  "manual-query": "#b45309",
  rule: "#be123c",
  table: "#0f766e",
  schema: "#4338ca",
  record: "#9333ea",
  reference: "#047857",
  activity: "#c2410c",
  job: "#a16207",
  timing: "#15803d",
  project: "#1d4ed8",
  host: "#047857",
  default: "#475569"
};

const linkColors = {
  catalog: "#f8fafc",
  table: "#2dd4bf",
  column: "#818cf8",
  contains: "#c084fc",
  reference: "#34d399",
  query: "#f59e0b",
  default: "#94a3b8"
};

const lightLinkColors = {
  catalog: "#102033",
  table: "#0f766e",
  column: "#4338ca",
  contains: "#9333ea",
  reference: "#047857",
  query: "#b45309",
  default: "#475569"
};

const structuralRadius = {
  core: 0,
  catalog: 58,
  "manual-query": 145,
  table: 165,
  schema: 300,
  query: 430,
  record: 430,
  reference: 610,
  activity: 475,
  job: 520,
  timing: 560,
  project: 455,
  host: 560,
  default: 440
};

const nodeShapes = {
  core: "sphere",
  catalog: "octahedron",
  table: "box",
  schema: "tetrahedron",
  query: "cone",
  "manual-query": "cone",
  record: "sphere",
  reference: "diamond",
  activity: "cylinder",
  job: "box",
  timing: "torus",
  project: "capsule",
  host: "octahedron",
  default: "sphere"
};

let rawGraph = { nodes: [], links: [] };
let currentFilter = "all";
let fitTimers = [];
let structuralRingGroup = null;
let nodeMaterialCache = new Map();

function palette() {
  return document.documentElement.dataset.theme === "light" ? lightColors : colors;
}

function edgePalette() {
  return document.documentElement.dataset.theme === "light" ? lightLinkColors : linkColors;
}

function hashText(value) {
  let hash = 2166136261;
  const text = String(value || "");
  for (let index = 0; index < text.length; index += 1) {
    hash ^= text.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function nodeId(value) {
  return value?.id || value;
}

function nodeTier(node) {
  if (node.id === "zorg-memorydb") return "core";
  if (node.id === "catalog") return "catalog";
  return node.group || "default";
}

function linkKind(link) {
  if (link.type === "discovers") return "catalog";
  if (link.type === "table") return "table";
  if (link.type === "column") return "column";
  if (link.type === "contains") return "contains";
  if (link.type === "matches" || nodeId(link.source) === "manual-query" || nodeId(link.target) === "manual-query") return "query";
  if (String(link.type || "").includes("_") || nodeId(link.source)?.startsWith("ref:") || nodeId(link.target)?.startsWith("ref:")) {
    return "reference";
  }
  return "default";
}

function tableNameForNode(node) {
  if (node.table) return node.table;
  if (node.id?.startsWith("table:")) return node.id.slice("table:".length);
  if (node.id?.startsWith("column:")) return node.id.split(":")[1];
  if (node.id?.startsWith("row:")) return node.id.split(":")[1];
  return null;
}

function distributePoint(angle, radius, zOffset = 0) {
  return {
    x: Math.cos(angle) * radius,
    y: Math.sin(angle) * radius,
    z: zOffset
  };
}

function activityScore(node, newestSeen, oldestSeen) {
  if (!node?.lastSeen || !Number.isFinite(newestSeen) || !Number.isFinite(oldestSeen) || newestSeen <= oldestSeen) {
    return 0;
  }
  const seen = new Date(node.lastSeen).getTime();
  if (!Number.isFinite(seen)) return 0;
  return Math.max(0, Math.min(1, (seen - oldestSeen) / (newestSeen - oldestSeen)));
}

function activityTone(score) {
  if (score >= 0.72) return "new";
  if (score >= 0.34) return "warm";
  if (score > 0) return "old";
  return "none";
}

function nodeVisualColor(node) {
  const base = palette()[node.group] || palette().default;
  const tone = activityTone(node.activityScore || 0);
  if (tone === "new") return document.documentElement.dataset.theme === "light" ? "#dc2626" : "#f97316";
  if (tone === "warm") return document.documentElement.dataset.theme === "light" ? "#ca8a04" : "#facc15";
  if (tone === "old") return document.documentElement.dataset.theme === "light" ? "#64748b" : "#64748b";
  return base;
}

function nodeShape(node) {
  if ((node.activityScore || 0) >= 0.72 && ["record", "query", "activity", "table"].includes(node.group)) {
    return "capsule";
  }
  return nodeShapes[nodeTier(node)] || nodeShapes.default;
}

function tableActivityStats(nodes) {
  const rowsWithTime = nodes
    .filter((node) => node.lastSeen)
    .map((node) => new Date(node.lastSeen).getTime())
    .filter(Number.isFinite);
  const newestSeen = rowsWithTime.length ? Math.max(...rowsWithTime) : NaN;
  const oldestSeen = rowsWithTime.length ? Math.min(...rowsWithTime) : NaN;
  const byTable = new Map();

  for (const node of nodes) {
    node.activityScore = activityScore(node, newestSeen, oldestSeen);
    const tableName = tableNameForNode(node);
    if (!tableName || node.activityScore <= 0) continue;
    const current = byTable.get(tableName) || { score: 0, count: 0 };
    current.score += node.activityScore;
    current.count += 1;
    byTable.set(tableName, current);
  }

  for (const [tableName, current] of byTable.entries()) {
    current.average = current.score / Math.max(1, current.count);
    byTable.set(tableName, current);
  }

  return byTable;
}

function applyStructuralLayout(graph) {
  const nodes = graph.nodes || [];
  const tables = nodes
    .filter((node) => node.id?.startsWith("table:"))
    .sort((left, right) => left.id.localeCompare(right.id));
  const tableAngles = new Map();
  const tableActivity = tableActivityStats(nodes);
  const tableCount = Math.max(1, tables.length);
  const activeTables = tables
    .filter((node) => (tableActivity.get(tableNameForNode(node))?.average || 0) > 0)
    .sort((left, right) => {
      const leftScore = tableActivity.get(tableNameForNode(left))?.average || 0;
      const rightScore = tableActivity.get(tableNameForNode(right))?.average || 0;
      return rightScore - leftScore || left.id.localeCompare(right.id);
    });
  const activeIndex = new Map(activeTables.map((node, index) => [node.id, index]));

  tables.forEach((node, index) => {
    const activity = tableActivity.get(tableNameForNode(node))?.average || 0;
    const packedActivityAngle =
      -Math.PI / 2 + ((activeIndex.get(node.id) ?? index) - Math.max(0, activeTables.length - 1) / 2) * 0.24;
    const catalogAngle = (Math.PI * 2 * index) / tableCount - Math.PI / 2;
    tableAngles.set(tableNameForNode(node), activity > 0 ? packedActivityAngle * activity + catalogAngle * (1 - activity) : catalogAngle);
  });

  for (const node of nodes) {
    const tier = nodeTier(node);
    const tableName = tableNameForNode(node);
    const baseAngle = tableAngles.get(tableName) ?? ((hashText(node.id) % 360) / 360) * Math.PI * 2;
    const activity = node.activityScore || tableActivity.get(tableName)?.average || 0;
    const activitySpread = 1 - activity * 0.72;
    const jitter = ((hashText(`${node.id}:jitter`) % 81) - 40) * (Math.PI / 720) * activitySpread;
    const tierRadius = structuralRadius[tier] ?? structuralRadius.default;
    const stalePush = node.lastSeen && activity < 0.34 ? 95 * (1 - activity) : 0;
    const recentPull = activity >= 0.34 ? 120 * activity : 0;
    let point;

    if (node.id === "zorg-memorydb") {
      point = { x: 0, y: 0, z: 0 };
    } else if (node.id === "catalog") {
      point = { x: 0, y: 0, z: structuralRadius.catalog };
    } else if (tier === "schema") {
      const columnOffset = ((hashText(node.id) % 7) - 3) * 11;
      point = distributePoint(baseAngle + jitter, tierRadius + columnOffset, 88 + ((hashText(node.id) % 9) - 4) * 12);
    } else if (tier === "record" || tier === "query") {
      point = distributePoint(baseAngle + jitter * 1.7, tierRadius + (hashText(node.id) % 58) + stalePush - recentPull, -54 + ((hashText(node.id) % 11) - 5) * 13 + activity * 70);
    } else if (tier === "reference") {
      point = distributePoint(baseAngle + jitter * 2.2, tierRadius + (hashText(node.id) % 76) + stalePush - recentPull * 0.55, 160 + ((hashText(node.id) % 13) - 6) * 16 + activity * 85);
    } else if (tier === "manual-query") {
      point = { x: -structuralRadius["manual-query"], y: -64, z: 122 };
    } else {
      point = distributePoint(baseAngle + jitter, tierRadius + stalePush * 0.35 - recentPull * 0.35, ((hashText(node.id) % 15) - 7) * 10 + activity * 54);
    }

    node.x = point.x;
    node.y = point.y;
    node.z = point.z;
    node.fx = point.x;
    node.fy = point.y;
    node.fz = point.z;
    node.structuralDistance = Math.round(Math.hypot(point.x, point.y, point.z));
  }
}

function createNodeGeometry(shape, size) {
  if (typeof THREE === "undefined") return null;
  if (shape === "box") return new THREE.BoxGeometry(size * 1.28, size * 1.28, size * 1.28);
  if (shape === "tetrahedron") return new THREE.TetrahedronGeometry(size * 1.45);
  if (shape === "cone") return new THREE.ConeGeometry(size, size * 2.2, 18);
  if (shape === "cylinder") return new THREE.CylinderGeometry(size * 0.9, size * 0.9, size * 1.8, 18);
  if (shape === "torus") return new THREE.TorusGeometry(size * 0.92, size * 0.24, 8, 24);
  if (shape === "octahedron" || shape === "diamond") return new THREE.OctahedronGeometry(size * 1.35);
  if (shape === "capsule" && typeof THREE.CapsuleGeometry === "function") return new THREE.CapsuleGeometry(size * 0.72, size * 1.45, 5, 14);
  if (shape === "capsule") return new THREE.CylinderGeometry(size * 0.75, size * 0.75, size * 2.25, 18);
  return new THREE.SphereGeometry(size, 18, 12);
}

function nodeObject(node) {
  if (typeof THREE === "undefined") return null;
  const shape = nodeShape(node);
  const color = nodeVisualColor(node);
  const size = 3.2 + Math.sqrt(Number(node.val || 1)) * 1.28 + (node.activityScore || 0) * 2.2;
  const materialKey = `${color}:${shape}:${activityTone(node.activityScore || 0)}`;
  let material = nodeMaterialCache.get(materialKey);
  if (!material) {
    material = new THREE.MeshLambertMaterial({
      color,
      emissive: color,
      emissiveIntensity: activityTone(node.activityScore || 0) === "new" ? 0.36 : 0.1,
      transparent: true,
      opacity: activityTone(node.activityScore || 0) === "old" ? 0.68 : 0.94
    });
    nodeMaterialCache.set(materialKey, material);
  }
  const geometry = createNodeGeometry(shape, size);
  if (!geometry) return null;
  const mesh = new THREE.Mesh(geometry, material);
  if (shape === "diamond") mesh.rotation.z = Math.PI / 4;
  return mesh;
}

function structuralRingColor() {
  return document.documentElement.dataset.theme === "light" ? 0x64748b : 0x94a3b8;
}

const Graph = ForceGraph3D()(graphEl)
  .backgroundColor("rgba(0,0,0,0)")
  .nodeLabel((node) => `${node.group}: ${node.label} (${node.structuralDistance || 0} units from database, ${activityTone(node.activityScore || 0)} activity)`)
  .nodeColor((node) => nodeVisualColor(node))
  .nodeThreeObject((node) => nodeObject(node))
  .nodeVal((node) => node.val || 1)
  .linkLabel((link) => link.type || "")
  .linkColor((link) => edgePalette()[linkKind(link)] || edgePalette().default)
  .linkWidth((link) => {
    const kind = linkKind(link);
    const base = { catalog: 3.4, table: 2.6, column: 1.25, contains: 1.8, reference: 1.35, query: 2.8 }[kind] || 0.9;
    return Math.max(0.45, Math.min(5.5, base + Number(link.value || 1) / 7));
  })
  .linkOpacity((link) => ({ catalog: 0.7, table: 0.6, column: 0.44, contains: 0.5, reference: 0.62, query: 0.76 }[linkKind(link)] || 0.34))
  .linkDirectionalArrowLength((link) => ({ catalog: 4.8, table: 4.4, column: 3.1, contains: 3.6, reference: 5.2, query: 5.6 }[linkKind(link)] || 2.8))
  .linkDirectionalArrowRelPos(0.86)
  .linkDirectionalParticles((link) => ({ catalog: 1, table: 2, column: 1, contains: 2, reference: 4, query: 5 }[linkKind(link)] || 1))
  .linkDirectionalParticleWidth((link) => ({ catalog: 2.4, table: 2.2, column: 1.3, contains: 1.8, reference: 2, query: 2.4 }[linkKind(link)] || 1.1))
  .d3VelocityDecay(0.72)
  .cooldownTicks(140)
  .onEngineTick(() => constrainGraphSpread())
  .onNodeClick((node) => {
    detailsEl.textContent = JSON.stringify(node, null, 2);
    const distance = 220;
    const distRatio = 1 + distance / Math.hypot(node.x || 1, node.y || 1, node.z || 1);
    Graph.cameraPosition(
      { x: (node.x || 0) * distRatio, y: (node.y || 0) * distRatio, z: (node.z || 0) * distRatio },
      node,
      900
    );
  });

function installStructuralRings() {
  if (structuralRingGroup || typeof THREE === "undefined" || typeof Graph.scene !== "function") return;
  structuralRingGroup = new THREE.Group();
  const radii = [structuralRadius.table, structuralRadius.schema, structuralRadius.record, structuralRadius.reference];
  for (const radius of radii) {
    const points = [];
    for (let index = 0; index <= 160; index += 1) {
      const angle = (Math.PI * 2 * index) / 160;
      points.push(new THREE.Vector3(Math.cos(angle) * radius, Math.sin(angle) * radius, -3));
    }
    const geometry = new THREE.BufferGeometry().setFromPoints(points);
    const material = new THREE.LineBasicMaterial({
      color: structuralRingColor(),
      transparent: true,
      opacity: radius === structuralRadius.reference ? 0.28 : 0.2,
      depthWrite: false
    });
    structuralRingGroup.add(new THREE.LineLoop(geometry, material));
  }
  Graph.scene().add(structuralRingGroup);
}

function refreshStructuralRings() {
  installStructuralRings();
  if (!structuralRingGroup) return;
  for (const ring of structuralRingGroup.children) ring.material.color.setHex(structuralRingColor());
}

Graph.d3Force("charge").strength(-4).distanceMax(120);
Graph.d3Force("link").distance((link) => {
  const kind = linkKind(link);
  return { catalog: 42, table: 82, column: 58, contains: 120, reference: 150, query: 128 }[kind] || 96;
});
Graph.d3Force("center").strength(0.08);

function constrainGraphSpread() {
  const nodes = rawGraph.nodes || [];
  const maxRadius = graphEl.clientWidth < 900 ? 720 : 820;
  for (const node of nodes) {
    if ([node.fx, node.fy, node.fz].every(Number.isFinite)) continue;
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
      const distance = graphEl.clientWidth < 900 ? 1680 : 1480;
      const tilt = graphEl.clientWidth < 900 ? { x: 320, y: 190 } : { x: 410, y: 260 };
      Graph.cameraPosition({ x: tilt.x, y: tilt.y, z: distance }, { x: 0, y: 0, z: 40 }, 900);
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
  keep.add("catalog");
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
  statusEl.textContent = query ? "Filtering graph..." : "Loading memory graph...";
  const response = await fetch(`/api/graph${query ? `?q=${encodeURIComponent(query)}` : ""}`);
  if (!response.ok) throw new Error(await response.text());
  const data = await response.json();
  rawGraph = { nodes: data.nodes, links: data.links };
  applyStructuralLayout(rawGraph);
  resize();
  Graph.graphData(rawGraph);
  constrainGraphSpread();
  applyFilter();
  fitGraph();
  fitGraph(2600);
  renderMetrics(data.stats, rawGraph);
  statusEl.textContent = data.highlight
    ? `Graph filter matched ${data.highlight.resultCount} visible items.`
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
  nodeMaterialCache = new Map();
  Graph.nodeColor((node) => nodeVisualColor(node));
  Graph.nodeThreeObject((node) => nodeObject(node));
  refreshStructuralRings();
  if (typeof Graph.refresh === "function") Graph.refresh();
}

themeToggle.addEventListener("click", () => {
  setTheme(document.documentElement.dataset.theme === "light" ? "dark" : "light");
});

const requestedTheme = new URLSearchParams(location.search).get("theme");
setTheme(requestedTheme === "light" || localStorage.getItem("zorg-memory-3d-theme") === "light" ? "light" : "dark");
refreshStructuralRings();

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
