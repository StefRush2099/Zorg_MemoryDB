const controlsEl = document.getElementById("adminControls");
const statusEl = document.getElementById("adminStatus");
const dbNameEl = document.getElementById("adminDbName");

const proxyPrefix = location.pathname.startsWith("/zorg-memory-3d") ? "/zorg-memory-3d" : "";

function proxiedPath(path) {
  return `${proxyPrefix}${path}`;
}

const controlGroups = [
  {
    key: "historyWindow",
    title: "History",
    controls: [
      { key: "days", label: "Days of history", type: "number", min: 0.01, max: 3650, step: 0.25 },
    ],
  },
  {
    key: "nodeSizing",
    title: "Nodes",
    controls: [
      { key: "minimumNodeRenderedSize", label: "Minimum size", min: 0.5, max: 80, step: 0.5 },
      { key: "vectorNodeSizeScale", label: "Vector growth", min: 0, max: 1, step: 0.001 },
      { key: "scaledVectorStartIndex", label: "Growth starts at vector", min: 1, max: 10, step: 1 },
      { key: "nodeCollisionRadiusScale", label: "Collision radius", min: 0.1, max: 10, step: 0.1 },
    ],
  },
  {
    key: "renderSettings",
    title: "Vectors",
    controls: [
      { key: "vectorDiameterVisualScale", label: "Vector diameter", min: 0.1, max: 10, step: 0.1 },
      { key: "packetDataNodeVisualScale", label: "Packet size", min: 0.1, max: 10, step: 0.1 },
      { key: "maxLiveVectorBullets", label: "Max live packets", min: 0, max: 1200, step: 10 },
      { key: "packetBurstMin", label: "Burst minimum", min: 1, max: 30, step: 1 },
      { key: "packetBurstMax", label: "Burst maximum", min: 1, max: 40, step: 1 },
      { key: "packetBurstShotSpacingMin", label: "Shot spacing", min: 10, max: 800, step: 10 },
      { key: "packetBurstShapeCycleMs", label: "Receipt cycle", min: 100, max: 5000, step: 100 },
    ],
  },
  {
    key: "renderSettings",
    title: "Transparency",
    controls: [
      { key: "nodeOpacity", label: "Node opacity", min: 0.02, max: 1, step: 0.01 },
      { key: "vectorOpacity", label: "Vector opacity", min: 0.02, max: 1, step: 0.01 },
      { key: "packetOpacity", label: "Packet opacity", min: 0.02, max: 1, step: 0.01 },
    ],
  },
];

let currentConfig = {};
let saveTimer = null;
let historyEstimateTimer = null;
let historyEstimateEl = null;

function setStatus(text, state = "neutral") {
  statusEl.textContent = text;
  statusEl.dataset.state = state;
}

function valueText(value) {
  if (typeof value === "boolean") return value ? "On" : "Off";
  const number = Number(value);
  if (!Number.isFinite(number)) return String(value ?? "");
  return Math.abs(number) < 1
    ? number.toFixed(4).replace(/0+$/, "").replace(/\.$/, "")
    : number.toFixed(2).replace(/0+$/, "").replace(/\.$/, "");
}

function compactInteger(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return "--";
  return new Intl.NumberFormat(undefined, { maximumFractionDigits: 0 }).format(number);
}

function megabyteText(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return "--";
  return `${number.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} MB`;
}

function renderHistoryEstimate(data) {
  if (!historyEstimateEl) return;
  const estimate = data?.estimate;
  if (!estimate) {
    historyEstimateEl.textContent = "History load estimate unavailable.";
    historyEstimateEl.dataset.state = "danger";
    return;
  }
  historyEstimateEl.dataset.state = estimate.cappedAtMaxPages ? "warning" : "success";
  historyEstimateEl.replaceChildren();
  const items = [
    ["Nodes", compactInteger(estimate.nodes)],
    ["Vectors", compactInteger(estimate.vectors)],
    ["Data", megabyteText(estimate.dataMegabytes)],
  ];
  for (const [label, value] of items) {
    const item = document.createElement("span");
    item.className = "history-estimate-item";
    const itemLabel = document.createElement("span");
    itemLabel.textContent = label;
    const itemValue = document.createElement("strong");
    itemValue.textContent = value;
    item.append(itemLabel, itemValue);
    historyEstimateEl.append(item);
  }
}

function scheduleHistoryEstimate(days) {
  if (!historyEstimateEl) return;
  if (historyEstimateTimer) clearTimeout(historyEstimateTimer);
  historyEstimateEl.textContent = "Calculating history load...";
  historyEstimateEl.dataset.state = "neutral";
  historyEstimateTimer = setTimeout(() => {
    loadHistoryEstimate(days).catch((error) => {
      if (!historyEstimateEl) return;
      historyEstimateEl.textContent = `History load estimate unavailable: ${error.message}`;
      historyEstimateEl.dataset.state = "danger";
    });
  }, 220);
}

async function loadHistoryEstimate(days) {
  const response = await fetch(
    proxiedPath(`/api/game/history-estimate?days=${encodeURIComponent(days)}`),
  );
  if (!response.ok) throw new Error(await response.text());
  renderHistoryEstimate(await response.json());
}

function buildControl(group, spec, value) {
  const row = document.createElement("label");
  row.className = "admin-control";
  row.dataset.key = `${group.key}.${spec.key}`;

  const label = document.createElement("span");
  label.className = "admin-control-label";
  label.textContent = spec.label;

  const output = document.createElement("output");
  output.textContent = valueText(value);

  let input;
  if (spec.type === "checkbox") {
    input = document.createElement("input");
    input.type = "checkbox";
    input.checked = Boolean(value);
  } else if (spec.type === "number") {
    input = document.createElement("input");
    input.type = "number";
    input.min = String(spec.min);
    input.max = String(spec.max);
    input.step = String(spec.step);
    input.value = String(Number(value ?? spec.min));
  } else {
    input = document.createElement("input");
    input.type = "range";
    input.min = String(spec.min);
    input.max = String(spec.max);
    input.step = String(spec.step);
    input.value = String(Number(value ?? spec.min));
  }

  input.addEventListener("input", () => {
    const nextValue = spec.type === "checkbox" ? input.checked : Number(input.value);
    if (spec.type === "number" && !Number.isFinite(nextValue)) return;
    output.textContent = valueText(nextValue);
    if (!currentConfig[group.key]) currentConfig[group.key] = {};
    currentConfig[group.key][spec.key] = nextValue;
    if (group.key === "historyWindow" && spec.key === "days") scheduleHistoryEstimate(nextValue);
    scheduleSave({ [group.key]: { [spec.key]: nextValue } });
  });

  row.append(label, input, output);
  return row;
}

function renderControls(config) {
  controlsEl.replaceChildren();
  historyEstimateEl = null;
  const columns = {
    left: document.createElement("div"),
    right: document.createElement("div"),
  };
  columns.left.className = "admin-column";
  columns.left.dataset.column = "history-vectors";
  columns.right.className = "admin-column";
  columns.right.dataset.column = "nodes-transparency";

  for (const group of controlGroups) {
    const section = document.createElement("section");
    section.className = "admin-group";
    section.dataset.group = group.title.toLowerCase();
    const title = document.createElement("h2");
    title.textContent = group.title;
    section.append(title);
    for (const spec of group.controls) {
      section.append(buildControl(group, spec, config[group.key]?.[spec.key]));
    }
    if (group.key === "historyWindow") {
      historyEstimateEl = document.createElement("div");
      historyEstimateEl.className = "history-estimate";
      historyEstimateEl.textContent = "Calculating history load...";
      historyEstimateEl.dataset.state = "neutral";
      section.append(historyEstimateEl);
      scheduleHistoryEstimate(config.historyWindow?.days);
    }
    const targetColumn =
      group.title === "History" || group.title === "Vectors" ? columns.left : columns.right;
    targetColumn.append(section);
  }
  controlsEl.append(columns.left, columns.right);
}

function scheduleSave(partialConfig) {
  if (saveTimer) clearTimeout(saveTimer);
  setStatus("Applying live config...", "neutral");
  saveTimer = setTimeout(() => saveConfig(partialConfig), 180);
}

async function saveConfig(partialConfig) {
  const response = await fetch(proxiedPath("/api/game/config"), {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ config: partialConfig }),
  });
  if (!response.ok) throw new Error(await response.text());
  const data = await response.json();
  currentConfig = data.config;
  setStatus("Live config applied and persisted.", "success");
}

async function loadConfig() {
  const response = await fetch(proxiedPath("/api/game/config"));
  if (!response.ok) throw new Error(await response.text());
  const data = await response.json();
  currentConfig = data.config;
  if (data.identity?.databaseLabel && dbNameEl) dbNameEl.textContent = data.identity.databaseLabel;
  renderControls(currentConfig);
  setStatus("Live engine config loaded.", "success");
}

loadConfig().catch((error) => {
  setStatus(`Config unavailable: ${error.message}`, "danger");
});
