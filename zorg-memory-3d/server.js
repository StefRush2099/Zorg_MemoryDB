import crypto from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import express from "express";
import pg from "pg";
import { WebSocketServer } from "ws";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const port = Number(process.env.PORT || 8097);
const { Pool } = pg;

function loadDbConfig() {
  if (process.env.DATABASE_URL) return { connectionString: process.env.DATABASE_URL };

  return {
    host: process.env.PGHOST || "/run/postgresql",
    port: Number(process.env.PGPORT || 5433),
    database: process.env.PGDATABASE || "openclaw_behavior",
    user: process.env.PGUSER || process.env.USER || "vorg",
    password: process.env.PGPASSWORD || process.env.ZORG_DB_PASSWORD,
  };
}

const pool = new Pool({
  ...loadDbConfig(),
  max: 8,
  idleTimeoutMillis: 30000,
});

app.use(express.json({ limit: "1mb" }));
app.use(express.static(path.join(__dirname, "public")));
app.use("/zorg-memory-3d", express.static(path.join(__dirname, "public")));
app.use(
  "/vendor/3d-force-graph",
  express.static(path.join(__dirname, "node_modules/3d-force-graph/dist")),
);
app.use("/vendor/three", express.static(path.join(__dirname, "node_modules/three/build")));

function textLabel(value) {
  if (value === null || value === undefined || value === "") return "";
  const text = String(value).replace(/\s+/g, " ").trim();
  return text.length > 92 ? `${text.slice(0, 89)}...` : text;
}

function addNode(map, id, group, label, extra = {}) {
  if (!id) return;
  if (!map.has(id)) {
    map.set(id, { id, group, label: textLabel(label || id), val: 1, ...extra });
    return;
  }
  const current = map.get(id);
  current.val = Math.min(14, (current.val || 1) + 0.4);
  if (extra.lastSeen && (!current.lastSeen || extra.lastSeen > current.lastSeen))
    current.lastSeen = extra.lastSeen;
  if (Number.isFinite(Number(extra.dataRows)))
    current.dataRows = Number(current.dataRows || 0) + Number(extra.dataRows);
  if (Number.isFinite(Number(extra.dataByteSize)))
    current.dataByteSize = Math.max(Number(current.dataByteSize || 0), Number(extra.dataByteSize));
  if (extra.sourceTable && !current.sourceTable) current.sourceTable = extra.sourceTable;
  if (extra.sourceKey && !current.sourceKey) current.sourceKey = extra.sourceKey;
}

function addLink(links, source, target, type, value = 1, extra = {}) {
  if (!source || !target) return;
  links.push({ source, target, type, value: Number(value || 1), ...extra });
}

function endpointId(endpoint) {
  return endpoint?.id || endpoint;
}

function ensureLinkEndpointNodes(nodes, links) {
  for (const link of links) {
    for (const endpoint of [endpointId(link.source), endpointId(link.target)]) {
      if (!endpoint || nodes.has(endpoint)) continue;
      const [group, ...labelParts] = String(endpoint).split(":");
      addNode(nodes, endpoint, group || "dynamic", labelParts.join(":") || endpoint, {
        val: 1,
        sourceTable: link.sourceTable,
        inferredEndpoint: true,
        lastSeen: link.lastSeen,
      });
    }
  }
}

function quoteIdent(value) {
  return `"${String(value).replaceAll('"', '""')}"`;
}

function stableHash(value) {
  return crypto.createHash("sha256").update(value).digest("hex").slice(0, 24);
}

function hashUnit(value, offset = 0) {
  const hash = stableHash(value);
  const slice = hash.slice(offset, offset + 6).padEnd(6, "0");
  return parseInt(slice, 16) / 0xffffff;
}

function parseTimestampMs(value) {
  if (!value) return null;
  const parsed = new Date(value).getTime();
  return Number.isFinite(parsed) ? parsed : null;
}

function propertySignature(node) {
  const signature = {};
  for (const [key, value] of Object.entries(node)) {
    if (
      [
        "x",
        "y",
        "z",
        "vx",
        "vy",
        "vz",
        "visualColor",
        "visualShape",
        "visualSignature",
        "activeCutoff",
        "activeWindowHours",
        "hasVisibleVector",
      ].includes(key)
    ) {
      continue;
    }
    if (typeof value === "function" || value === undefined) continue;
    signature[key] = value;
  }
  return sortedStableStringify(signature);
}

function propertyColor(node) {
  const signature = propertySignature(node);
  const hue = Math.round(hashUnit(signature, 0) * 360);
  const saturation = 54 + Math.round(hashUnit(signature, 6) * 24);
  const lightness = 44 + Math.round(hashUnit(signature, 12) * 22);
  return `hsl(${hue}, ${saturation}%, ${lightness}%)`;
}

function propertyShape(node) {
  const signature = propertySignature(node);
  const shapes = [
    "facetedIcosahedron",
    "facetedDodecahedron",
    "facetedOctahedron",
    "triakisIcosahedron",
    "stellatedDodecahedron",
    "rhombicTriacontahedron",
  ];
  return shapes[Math.floor(hashUnit(signature, 18) * shapes.length) % shapes.length];
}

function estimateNodeDataBytes(node) {
  const payload = {};
  for (const [key, value] of Object.entries(node || {})) {
    if (
      [
        "x",
        "y",
        "z",
        "vx",
        "vy",
        "vz",
        "visualColor",
        "visualShape",
        "visualSignature",
        "renderedRadius",
        "collisionRadius",
        "pulseAt",
        "engineState",
        "shapeCycleStartedAt",
        "shapeCycleUntil",
      ].includes(key)
    )
      continue;
    if (typeof value === "function" || value === undefined) continue;
    payload[key] = value;
  }
  return Buffer.byteLength(sortedStableStringify(payload), "utf8");
}

function linkSignature(link) {
  return sortedStableStringify({
    source: endpointId(link.source),
    target: endpointId(link.target),
    type: link.type || null,
    value: Number.isFinite(Number(link.value)) ? Number(link.value) : null,
    sourceTable: link.sourceTable || null,
    lastSeen: link.lastSeen || null,
  });
}

function linkPacketByteSize(link) {
  const explicitSize = Number(link?.dataByteSize || link?.payloadBytes || link?.packetBytes);
  if (Number.isFinite(explicitSize) && explicitSize > 0) return Math.round(explicitSize);
  return Buffer.byteLength(linkSignature(link), "utf8");
}

function linkPacketCount(link) {
  const bytes = linkPacketByteSize(link);
  return Math.max(1, Math.min(9, Math.ceil(Math.log2(bytes + 1) / 2)));
}

function createVectorDataPacketEvent(link, trigger = {}) {
  const key = graphLinkKey(link);
  const targetId = endpointId(link.target);
  return {
    type: "vector_data_packet",
    nodeId: targetId,
    linkKey: key,
    rule: "database-event-sends-packet-down-vector",
    packetEventDriven: true,
    packetCount: linkPacketCount(link),
    dataByteSize: linkPacketByteSize(link),
    sourceId: endpointId(link.source),
    targetId,
    sourceTable: link.sourceTable || null,
    triggerType: trigger.type || "database_change",
    triggerNodeId: trigger.nodeId || null,
    triggerLinkKey: trigger.linkKey || key,
    link,
  };
}

function createNodeVectorDataPacketEvents(links, nodeId, trigger = {}, limit = 72) {
  if (!nodeId) return [];
  const events = [];
  const seen = new Set();
  for (const link of links) {
    if (events.length >= limit) break;
    const source = endpointId(link.source);
    const target = endpointId(link.target);
    if (source !== nodeId && target !== nodeId) continue;
    const key = graphLinkKey(link);
    if (seen.has(key)) continue;
    seen.add(key);
    events.push(
      createVectorDataPacketEvent(link, {
        ...trigger,
        nodeId,
        linkKey: key,
      }),
    );
  }
  return events;
}

function hslColor(hue, saturation, lightness, alpha = 1) {
  return `hsla(${Math.round(hue)}, ${Math.round(saturation)}%, ${Math.round(lightness)}%, ${Number(alpha).toFixed(3)})`;
}

function contrastingHue(hue, signature) {
  return (hue + 170 + hashUnit(signature, 46) * 28) % 360;
}

const engineId = `zorg-memory-3d-${process.pid}-${Date.now().toString(36)}`;
const enginePollMs = Number(process.env.ZORG_MEMORY_3D_ENGINE_POLL_MS || 4500);
const engineEventLimit = Number(process.env.ZORG_MEMORY_3D_EVENT_LIMIT || 180);
const snapshotPacketEventLimit = Math.max(
  12,
  Math.min(120, Number(process.env.ZORG_MEMORY_3D_SNAPSHOT_PACKET_EVENT_LIMIT || 72)),
);
const enginePhysicsTickMs = Math.max(
  33,
  Math.min(250, Number(process.env.ZORG_MEMORY_3D_PHYSICS_TICK_MS || 80)),
);
const engineSnapshotBroadcastMs = Math.max(
  120,
  Math.min(2000, Number(process.env.ZORG_MEMORY_3D_SNAPSHOT_BROADCAST_MS || 500)),
);
const defaultActiveWindowMs = Math.max(
  60_000,
  Number(process.env.ZORG_MEMORY_3D_ACTIVE_WINDOW_MS || 24 * 60 * 60 * 1000),
);
const defaultHistoryWindowDays = Number((defaultActiveWindowMs / 86_400_000).toFixed(4));
const stagedBuildNodeBatch = Math.max(
  2,
  Number(process.env.ZORG_MEMORY_3D_STAGED_BUILD_NODE_BATCH || 2),
);
const databaseScanBatchRows = Math.max(
  25,
  Number(process.env.ZORG_MEMORY_3D_DB_SCAN_BATCH_ROWS || 240),
);
const databaseScanMaxPages = Math.max(
  1,
  Number(process.env.ZORG_MEMORY_3D_DB_SCAN_MAX_PAGES || 240),
);
const historyEstimateIndexLimit = Math.max(
  8,
  Number(process.env.ZORG_MEMORY_3D_HISTORY_ESTIMATE_INDEX_LIMIT || 96),
);
const noTouchEpsilon = Number(process.env.ZORG_MEMORY_3D_NO_TOUCH_EPSILON || 0.12);
const physicsLayoutVersion = 40;
const nodeShapeCycleMs = Math.max(
  600,
  Number(process.env.ZORG_MEMORY_3D_NODE_SHAPE_CYCLE_MS || 3200),
);
const spawnOriginClearance = Math.max(
  18,
  Number(process.env.ZORG_MEMORY_3D_SPAWN_ORIGIN_CLEARANCE || 90),
);
const spawnCandidateAttempts = Math.max(
  8,
  Math.min(96, Number(process.env.ZORG_MEMORY_3D_SPAWN_CANDIDATE_ATTEMPTS || 36)),
);
const defaultMinimumNodeRenderedSize = Math.max(
  0.5,
  Number(process.env.ZORG_MEMORY_3D_MINIMUM_NODE_RENDERED_SIZE || 10),
);

function envNumber(name, defaultValue, min = -Infinity, max = Infinity) {
  const parsed = Number(process.env[name]);
  const value = Number.isFinite(parsed) ? parsed : defaultValue;
  return Math.max(min, Math.min(max, value));
}

function envFlag(name, defaultValue) {
  const value = process.env[name];
  if (value === undefined) return defaultValue;
  return !["0", "false", "off", "no"].includes(String(value).trim().toLowerCase());
}

const defaultNodeSizingConfig = Object.freeze({
  minimumNodeRenderedSize: envNumber(
    "ZORG_MEMORY_3D_MINIMUM_NODE_RENDERED_SIZE",
    defaultMinimumNodeRenderedSize,
    0.5,
    200,
  ),
  vectorNodeSizeScale: envNumber("ZORG_MEMORY_3D_VECTOR_NODE_SIZE_SCALE", 0.0625, 0, 5),
  scaledVectorStartIndex: Math.round(
    envNumber("ZORG_MEMORY_3D_SCALED_VECTOR_START_INDEX", 2, 1, 25),
  ),
  nodeCollisionRadiusScale: envNumber("ZORG_MEMORY_3D_NODE_COLLISION_RADIUS_SCALE", 2.4, 0.1, 20),
});

const defaultHistoryWindowConfig = Object.freeze({
  days: envNumber("ZORG_MEMORY_3D_HISTORY_WINDOW_DAYS", defaultHistoryWindowDays, 0.01, 3650),
});

const historyTimestampColumns = Object.freeze([
  "updated_at",
  "created_at",
  "logged_at",
  "observed_at",
  "message_timestamp",
  "last_seen_at",
  "last_recalled_at",
  "available_at",
  "started_at",
  "completed_at",
  "finished_at",
]);

const defaultDataBackedNodeSizingConfig = Object.freeze({
  enabled: envFlag("ZORG_MEMORY_3D_DATA_BACKED_NODE_SIZING", true),
  minRenderedSize: envNumber(
    "ZORG_MEMORY_3D_DATA_BACKED_NODE_MIN_SIZE",
    defaultNodeSizingConfig.minimumNodeRenderedSize,
    0.5,
    200,
  ),
  maxRenderedSize: envNumber(
    "ZORG_MEMORY_3D_DATA_BACKED_NODE_MAX_SIZE",
    44,
    defaultNodeSizingConfig.minimumNodeRenderedSize,
    500,
  ),
  byteLogScale: envNumber("ZORG_MEMORY_3D_DATA_BACKED_NODE_BYTE_LOG_SCALE", 1.65, 0, 25),
  rowLogScale: envNumber("ZORG_MEMORY_3D_DATA_BACKED_NODE_ROW_LOG_SCALE", 0.85, 0, 25),
});

const defaultRenderSettingsConfig = Object.freeze({
  vectorDiameterVisualScale: envNumber("ZORG_MEMORY_3D_VECTOR_DIAMETER_VISUAL_SCALE", 2, 0.1, 20),
  packetDataNodeVisualScale: envNumber("ZORG_MEMORY_3D_PACKET_DATA_NODE_VISUAL_SCALE", 2, 0.1, 20),
  nodeOpacity: envNumber("ZORG_MEMORY_3D_NODE_OPACITY", 0.95, 0.02, 1),
  vectorOpacity: envNumber("ZORG_MEMORY_3D_VECTOR_OPACITY", 0.9, 0.02, 1),
  packetOpacity: envNumber("ZORG_MEMORY_3D_PACKET_OPACITY", 1, 0.02, 1),
  maxLiveVectorBullets: Math.round(
    envNumber("ZORG_MEMORY_3D_MAX_LIVE_VECTOR_BULLETS", 420, 0, 2000),
  ),
  packetBurstMin: Math.round(envNumber("ZORG_MEMORY_3D_PACKET_BURST_MIN", 3, 1, 40)),
  packetBurstMax: Math.round(envNumber("ZORG_MEMORY_3D_PACKET_BURST_MAX", 7, 1, 60)),
  packetBurstShotSpacingMin: envNumber(
    "ZORG_MEMORY_3D_PACKET_BURST_SHOT_SPACING_MIN",
    70,
    10,
    2000,
  ),
  packetBurstShapeCycleMs: envNumber(
    "ZORG_MEMORY_3D_PACKET_BURST_SHAPE_CYCLE_MS",
    1200,
    100,
    10000,
  ),
});

const engineRuleDefinitions = Object.freeze({
  positionSanity: {
    env: "ZORG_MEMORY_3D_RULE_POSITION_SANITY",
    defaultEnabled: true,
    section: "spawn-invalid-position",
    owns: "Repairs missing live coordinates only; does not create fixed or persisted homes.",
  },
  damping: {
    env: "ZORG_MEMORY_3D_RULE_DAMPING",
    defaultEnabled: true,
    section: "velocity-damping",
    owns: "Smooths velocity by applying friction to vx/vy/vz.",
  },
  attraction: {
    env: "ZORG_MEMORY_3D_RULE_ATTRACTION",
    defaultEnabled: true,
    section: "object-attraction",
    owns: "Applies object attraction; vectors are not consulted for distance.",
  },
  dynamicAssociationOrbit: {
    env: "ZORG_MEMORY_3D_RULE_DYNAMIC_ASSOCIATION_ORBIT",
    defaultEnabled: true,
    section: "direct-association-orbit",
    owns: "Calculates designated association coordinates from timestamps and applies spring force toward them; it does not force positions.",
  },
  connectedCollisionSpring: {
    env: "ZORG_MEMORY_3D_RULE_CONNECTED_COLLISION_SPRING",
    defaultEnabled: true,
    section: "collision-radius-connected-spring",
    owns: "Keeps connected nodes springing toward collision-radius distance without separate distance gauges or hard coordinate forcing.",
  },
  velocityIntegration: {
    env: "ZORG_MEMORY_3D_RULE_VELOCITY_INTEGRATION",
    defaultEnabled: true,
    section: "velocity-integration",
    owns: "Commits vx/vy/vz into live x/y/z.",
  },
  collisionBoundary: {
    env: "ZORG_MEMORY_3D_RULE_COLLISION_BOUNDARY",
    defaultEnabled: true,
    section: "no-touch-collision-boundary",
    owns: "Prevents touching with collisionRadius = renderedRadius * nodeCollisionRadiusScale.",
  },
  vectorCollisionBoundary: {
    env: "ZORG_MEMORY_3D_RULE_VECTOR_COLLISION_BOUNDARY",
    defaultEnabled: true,
    section: "straight-vector-collision-boundary",
    owns: "Keeps straight vectors from passing through unrelated nodes by gently moving intersecting nodes out of the vector tube.",
  },
  activeVectorFilter: {
    env: "ZORG_MEMORY_3D_RULE_ACTIVE_VECTOR_FILTER",
    defaultEnabled: true,
    section: "active-window-visible-vector-filter",
    owns: "Keeps the visible graph limited to active nodes and active vectors inside the configured history window.",
  },
  vectorRendering: {
    env: "ZORG_MEMORY_3D_RULE_VECTOR_RENDERING",
    defaultEnabled: true,
    section: "visual-vector-rendering",
    owns: "Keeps vectors as visual followers only; no rest length, force, or spacing.",
  },
});

function createEngineRuleState() {
  return Object.fromEntries(
    Object.entries(engineRuleDefinitions).map(([name, definition]) => [
      name,
      envFlag(definition.env, definition.defaultEnabled),
    ]),
  );
}

function engineRuleSummary(rules) {
  return Object.fromEntries(
    Object.entries(engineRuleDefinitions).map(([name, definition]) => [
      name,
      {
        enabled: Boolean(rules[name]),
        section: definition.section,
        owns: definition.owns,
        env: definition.env,
      },
    ]),
  );
}

function normalizeNodeSizingConfig(input = {}) {
  const numberValue = (key, fallback) => {
    const parsed = Number(input[key]);
    return Number.isFinite(parsed) ? parsed : fallback;
  };
  return {
    minimumNodeRenderedSize: Math.max(
      0.5,
      Math.min(
        200,
        numberValue("minimumNodeRenderedSize", defaultNodeSizingConfig.minimumNodeRenderedSize),
      ),
    ),
    vectorNodeSizeScale: Math.max(
      0,
      Math.min(5, numberValue("vectorNodeSizeScale", defaultNodeSizingConfig.vectorNodeSizeScale)),
    ),
    scaledVectorStartIndex: Math.round(
      Math.max(
        1,
        Math.min(
          25,
          numberValue("scaledVectorStartIndex", defaultNodeSizingConfig.scaledVectorStartIndex),
        ),
      ),
    ),
    nodeCollisionRadiusScale: Math.max(
      0.1,
      Math.min(
        20,
        numberValue("nodeCollisionRadiusScale", defaultNodeSizingConfig.nodeCollisionRadiusScale),
      ),
    ),
  };
}

function normalizeHistoryWindowConfig(input = {}) {
  const parsed = Number(input.days);
  const days = Number.isFinite(parsed) ? parsed : defaultHistoryWindowConfig.days;
  return {
    days: Number(Math.max(0.01, Math.min(3650, days)).toFixed(4)),
  };
}

function normalizeDataBackedNodeSizingConfig(input = {}) {
  const numberValue = (key, fallback) => {
    const parsed = Number(input[key]);
    return Number.isFinite(parsed) ? parsed : fallback;
  };
  const minRenderedSize = Math.max(
    0.5,
    Math.min(
      200,
      numberValue("minRenderedSize", defaultDataBackedNodeSizingConfig.minRenderedSize),
    ),
  );
  return {
    enabled:
      input.enabled === undefined
        ? defaultDataBackedNodeSizingConfig.enabled
        : Boolean(input.enabled),
    minRenderedSize,
    maxRenderedSize: Math.max(
      minRenderedSize,
      Math.min(
        500,
        numberValue("maxRenderedSize", defaultDataBackedNodeSizingConfig.maxRenderedSize),
      ),
    ),
    byteLogScale: Math.max(
      0,
      Math.min(25, numberValue("byteLogScale", defaultDataBackedNodeSizingConfig.byteLogScale)),
    ),
    rowLogScale: Math.max(
      0,
      Math.min(25, numberValue("rowLogScale", defaultDataBackedNodeSizingConfig.rowLogScale)),
    ),
  };
}

function deriveDataBackedNodeSizingConfig(historyInput = {}, nodeSizingInput = {}) {
  const history = normalizeHistoryWindowConfig(historyInput);
  const nodeSizing = normalizeNodeSizingConfig(nodeSizingInput);
  const days = Math.max(0.01, history.days);
  const dayRoot = Math.sqrt(days);
  const longWindowCompression = Math.max(
    0.45,
    Math.min(1, 1 / Math.sqrt(Math.max(1, Math.log2(days + 1)))),
  );
  return normalizeDataBackedNodeSizingConfig({
    enabled: true,
    minRenderedSize: nodeSizing.minimumNodeRenderedSize,
    maxRenderedSize: nodeSizing.minimumNodeRenderedSize + 34 * Math.min(8, Math.max(1, dayRoot)),
    byteLogScale: 1.65 * longWindowCompression,
    rowLogScale: 0.85 * longWindowCompression,
  });
}

function normalizeRenderSettingsConfig(input = {}) {
  const numberValue = (key, fallback) => {
    const parsed = Number(input[key]);
    return Number.isFinite(parsed) ? parsed : fallback;
  };
  const packetBurstMin = Math.round(
    Math.max(
      1,
      Math.min(40, numberValue("packetBurstMin", defaultRenderSettingsConfig.packetBurstMin)),
    ),
  );
  return {
    vectorDiameterVisualScale: Math.max(
      0.1,
      Math.min(
        20,
        numberValue(
          "vectorDiameterVisualScale",
          defaultRenderSettingsConfig.vectorDiameterVisualScale,
        ),
      ),
    ),
    packetDataNodeVisualScale: Math.max(
      0.1,
      Math.min(
        20,
        numberValue(
          "packetDataNodeVisualScale",
          defaultRenderSettingsConfig.packetDataNodeVisualScale,
        ),
      ),
    ),
    nodeOpacity: Math.max(
      0.02,
      Math.min(1, numberValue("nodeOpacity", defaultRenderSettingsConfig.nodeOpacity)),
    ),
    vectorOpacity: Math.max(
      0.02,
      Math.min(1, numberValue("vectorOpacity", defaultRenderSettingsConfig.vectorOpacity)),
    ),
    packetOpacity: Math.max(
      0.02,
      Math.min(1, numberValue("packetOpacity", defaultRenderSettingsConfig.packetOpacity)),
    ),
    maxLiveVectorBullets: Math.round(
      Math.max(
        0,
        Math.min(
          2000,
          numberValue("maxLiveVectorBullets", defaultRenderSettingsConfig.maxLiveVectorBullets),
        ),
      ),
    ),
    packetBurstMin,
    packetBurstMax: Math.round(
      Math.max(
        packetBurstMin,
        Math.min(60, numberValue("packetBurstMax", defaultRenderSettingsConfig.packetBurstMax)),
      ),
    ),
    packetBurstShotSpacingMin: Math.max(
      10,
      Math.min(
        2000,
        numberValue(
          "packetBurstShotSpacingMin",
          defaultRenderSettingsConfig.packetBurstShotSpacingMin,
        ),
      ),
    ),
    packetBurstShapeCycleMs: Math.max(
      100,
      Math.min(
        10000,
        numberValue("packetBurstShapeCycleMs", defaultRenderSettingsConfig.packetBurstShapeCycleMs),
      ),
    ),
  };
}

function createEngineConfigState() {
  const nodeSizing = normalizeNodeSizingConfig(defaultNodeSizingConfig);
  const historyWindow = normalizeHistoryWindowConfig(defaultHistoryWindowConfig);
  return {
    historyWindow,
    nodeSizing,
    dataBackedNodeSizing: deriveDataBackedNodeSizingConfig(historyWindow, nodeSizing),
    renderSettings: normalizeRenderSettingsConfig(defaultRenderSettingsConfig),
  };
}

function engineConfigSummary(config) {
  const nodeSizing = normalizeNodeSizingConfig(config?.nodeSizing);
  const historyWindow = normalizeHistoryWindowConfig(config?.historyWindow);
  return {
    historyWindow: {
      ...historyWindow,
      section: "database-history-window",
      owns: "Controls how many days of real DB history are pulled into the brain map; dependent data-backed sizing is calculated from this value.",
      dynamic: true,
    },
    nodeSizing: {
      ...nodeSizing,
      section: "node-size-and-collision-radius",
      owns: "Controls baseline node size, vector-count growth, and no-touch collision radius at runtime.",
      dynamic: true,
    },
    dataBackedNodeSizing: {
      ...deriveDataBackedNodeSizingConfig(historyWindow, nodeSizing),
      section: "auto-data-backed-node-size-baseline",
      owns: "Automatically derived from the configured history-window days; no separate manual data-size tuning is required.",
      dynamic: true,
    },
    renderSettings: {
      ...normalizeRenderSettingsConfig(config?.renderSettings),
      section: "server-authored-render-materials",
      owns: "Controls server-authored material descriptors, vector diameter, packet data-node size, and event-driven packet burst visuals consumed by thin browser renderers.",
      dynamic: true,
    },
  };
}

function sortedStableStringify(value) {
  if (Array.isArray(value))
    return `[${value.map((item) => sortedStableStringify(item)).join(",")}]`;
  if (value instanceof Date) return JSON.stringify(value.toISOString());
  if (value && typeof value === "object") {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${sortedStableStringify(value[key])}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

function yieldToGameLoop() {
  return new Promise((resolve) => setImmediate(resolve));
}

function graphNodeFingerprint(node) {
  const copy = { ...node };
  for (const key of [
    "x",
    "y",
    "z",
    "vx",
    "vy",
    "vz",
    "pulseAt",
    "engineVersion",
    "engineState",
    "activeCutoff",
    "shapeCycleStartedAt",
    "shapeCycleUntil",
    "settledVisualShape",
  ]) {
    delete copy[key];
  }
  return stableHash(sortedStableStringify(copy));
}

function graphLinkKey(link) {
  return `${endpointId(link.source)}->${endpointId(link.target)}:${link.type || "link"}`;
}

function deterministicUnitVector(signature) {
  const theta = hashUnit(`${signature}:theta`, 0) * Math.PI * 2;
  const z = hashUnit(`${signature}:z`, 6) * 2 - 1;
  const scale = Math.sqrt(Math.max(0, 1 - z * z));
  return {
    x: Math.cos(theta) * scale,
    y: Math.sin(theta) * scale,
    z,
  };
}

function randomUnitVector(signature = "spawn") {
  const buffer = crypto.randomBytes(12);
  const raw = [
    buffer.readUInt32BE(0) / 0xffffffff - 0.5,
    buffer.readUInt32BE(4) / 0xffffffff - 0.5,
    buffer.readUInt32BE(8) / 0xffffffff - 0.5,
  ];
  const distance = Math.hypot(raw[0], raw[1], raw[2]);
  if (Number.isFinite(distance) && distance > 0.000001) {
    return { x: raw[0] / distance, y: raw[1] / distance, z: raw[2] / distance };
  }
  return deterministicUnitVector(signature);
}

function randomBetween(min, max) {
  const lower = Number(min);
  const upper = Number(max);
  if (!Number.isFinite(lower) || !Number.isFinite(upper) || upper <= lower) return lower;
  const value = crypto.randomBytes(4).readUInt32BE(0) / 0xffffffff;
  return lower + (upper - lower) * value;
}

function usableRuntimePosition(node) {
  if (!positionedNode(node)) return false;
  return Math.hypot(Number(node.x), Number(node.y), Number(node.z)) > 0.001;
}

function spawnClearance(candidate, node, existingNodes) {
  let clearance =
    Math.hypot(Number(candidate.x), Number(candidate.y), Number(candidate.z)) -
    spawnOriginClearance;
  for (const existing of existingNodes) {
    if (!usableRuntimePosition(existing) || existing.id === node.id) continue;
    const distance = Math.hypot(
      Number(candidate.x) - Number(existing.x),
      Number(candidate.y) - Number(existing.y),
      Number(candidate.z) - Number(existing.z),
    );
    const desired = nodeCollisionRadius(existing) + nodeCollisionRadius(node) + noTouchEpsilon;
    clearance = Math.min(clearance, distance - desired);
  }
  return clearance;
}

function graphLinksByNode(links) {
  const byNode = new Map();
  for (const link of links) {
    const source = endpointId(link.source);
    const target = endpointId(link.target);
    if (!source || !target) continue;
    if (!byNode.has(source)) byNode.set(source, []);
    if (!byNode.has(target)) byNode.set(target, []);
    byNode.get(source).push(link);
    byNode.get(target).push(link);
  }
  return byNode;
}

function linkTimestampMs(link) {
  return parseTimestampMs(link?.lastSeen) ?? 0;
}

function orderedGraphLinks(links) {
  return [...links].sort((left, right) => {
    const timeDelta = linkTimestampMs(left) - linkTimestampMs(right);
    if (timeDelta !== 0) return timeDelta;
    return graphLinkKey(left).localeCompare(graphLinkKey(right));
  });
}

function dedupeGraphLinks(links) {
  const deduped = new Map();
  for (const link of links) {
    const key = graphLinkKey(link);
    const existing = deduped.get(key);
    if (!existing) {
      deduped.set(key, { ...link });
      continue;
    }
    existing.value = Math.max(Number(existing.value || 1), Number(link.value || 1));
    const existingTime = linkTimestampMs(existing);
    const nextTime = linkTimestampMs(link);
    if (nextTime > existingTime) existing.lastSeen = link.lastSeen;
  }
  return [...deduped.values()];
}

function pairedNodeBuildOrder(nodes, links) {
  const ordered = [];
  const seen = new Set();
  const add = (id) => {
    if (!id || seen.has(id) || !nodes.has(id)) return;
    seen.add(id);
    ordered.push(nodes.get(id));
  };
  for (const link of orderedGraphLinks(links)) {
    add(endpointId(link.source));
    add(endpointId(link.target));
  }
  for (const node of nodes.values()) add(node.id);
  return ordered;
}

function positionedNode(node) {
  return node && [node.x, node.y, node.z].every(Number.isFinite) ? node : null;
}

function linkedSpawnAnchor(nodeId, linksByNode, nextNodes, currentNodes) {
  const links = linksByNode.get(nodeId) || [];
  for (const link of links) {
    const source = endpointId(link.source);
    const target = endpointId(link.target);
    const otherId = source === nodeId ? target : source;
    const anchor =
      positionedNode(nextNodes.get(otherId)) || positionedNode(currentNodes.get(otherId));
    if (anchor) return { anchor, link };
  }
  return null;
}

function spawnPositionNearAnchor(node, anchor, link) {
  const direction = randomUnitVector(
    `${endpointId(link.source)}:${endpointId(link.target)}:${node.id}:${anchor.id}`,
  );
  const radius = nodeCollisionRadius(anchor) + nodeCollisionRadius(node) + noTouchEpsilon;
  return {
    x: Number(anchor.x) + direction.x * radius,
    y: Number(anchor.y) + direction.y * radius,
    z: Number(anchor.z) + direction.z * radius,
  };
}

function runtimeSpawnPosition(
  node = {},
  existingNodes = [],
  linksByNode = new Map(),
  nextNodes = new Map(),
  currentNodes = new Map(),
) {
  const linked = linkedSpawnAnchor(node.id, linksByNode, nextNodes, currentNodes);
  const positioned = existingNodes.filter((candidate) => usableRuntimePosition(candidate));
  const anchor =
    linked?.anchor || positioned[Math.floor(randomBetween(0, positioned.length))] || null;
  let best = null;
  let bestClearance = -Infinity;

  for (let attempt = 0; attempt < spawnCandidateAttempts; attempt += 1) {
    const direction = randomUnitVector(`spawn:${node.id || positioned.length}:${attempt}`);
    const anchorRadius = anchor ? nodeCollisionRadius(anchor) : spawnOriginClearance;
    const baseRadius = anchor
      ? anchorRadius + nodeCollisionRadius(node) + noTouchEpsilon
      : randomBetween(spawnOriginClearance, spawnOriginClearance + 220);
    const candidate = anchor
      ? {
          x: Number(anchor.x) + direction.x * baseRadius,
          y: Number(anchor.y) + direction.y * baseRadius,
          z: Number(anchor.z) + direction.z * baseRadius,
        }
      : {
          x: direction.x * baseRadius,
          y: direction.y * baseRadius,
          z: direction.z * baseRadius,
        };
    const clearance = spawnClearance(candidate, node, positioned);
    if (clearance > bestClearance) {
      best = candidate;
      bestClearance = clearance;
    }
    if (clearance >= noTouchEpsilon) break;
  }

  if (best) return best;
  if (linked) return spawnPositionNearAnchor(node, linked.anchor, linked.link);
  const direction = randomUnitVector(`fallback:${node.id || positioned.length}`);
  const radius = randomBetween(spawnOriginClearance, spawnOriginClearance + 180);
  return {
    x: direction.x * radius,
    y: direction.y * radius,
    z: direction.z * radius,
  };
}

function stagedGraphFromEnteredIds(graph, enteredIds) {
  const nodeById = new Map(graph.nodes.map((node) => [node.id, node]));
  const stagedNodes = [...enteredIds].map((id) => nodeById.get(id)).filter(Boolean);
  const stagedLinks = graph.links.filter(
    (link) => enteredIds.has(endpointId(link.source)) && enteredIds.has(endpointId(link.target)),
  );
  return {
    ...graph,
    nodes: stagedNodes,
    links: stagedLinks,
  };
}

function createEmptyBuildState() {
  return {
    graphVersion: null,
    enteredNodeIds: new Set(),
    pairedEntryCount: 0,
    rootPairCount: 0,
    stagedLinkKeys: new Set(),
    complete: false,
    lastAddedNodes: 0,
    lastAddedLinks: 0,
  };
}

function resolveZeroDistanceDirection(seed = "zero-distance") {
  const direction = deterministicUnitVector(seed);
  return {
    dx: direction.x || 0.01,
    dy: direction.y || 0.01,
    dz: direction.z || 0.01,
    distance: 1,
  };
}

function renderedNodeRadius(node) {
  const size = Math.max(0.5, Number(node.val || 1));
  const radius = Math.max(1.8, size * 0.88);
  const shape = node.visualShape || propertyShape(node);
  if (shape === "facetedIcosahedron") return radius * 1.1;
  if (shape === "facetedDodecahedron") return radius * 1.08;
  if (shape === "facetedOctahedron") return radius * 1.12;
  if (shape === "triakisIcosahedron") return radius * 1.2;
  if (shape === "stellatedDodecahedron") return radius * 1.18;
  if (shape === "rhombicTriacontahedron") return radius * 1.14;
  return radius * 1.1;
}

function currentNodeSizingConfig(config = null) {
  return normalizeNodeSizingConfig(config || gameEngine?.config?.nodeSizing);
}

function nodeCollisionRadius(node, config = null) {
  return renderedNodeRadius(node) * currentNodeSizingConfig(config).nodeCollisionRadiusScale;
}

function normalizeNodeDataMeasurements(node) {
  node.dataRows = Math.max(
    1,
    Math.round(Number(node.dataRows || node.dataRowCount || (node.sourceTable ? 1 : 1))),
  );
  node.dataByteSize = Math.max(
    0,
    Math.round(Number(node.dataByteSize || estimateNodeDataBytes(node))),
  );
  return node;
}

function dataBackedNodeBaseRenderedSize(node, config = null) {
  const sizing = normalizeDataBackedNodeSizingConfig(
    config || gameEngine?.config?.dataBackedNodeSizing,
  );
  if (!sizing.enabled) return currentNodeSizingConfig().minimumNodeRenderedSize;
  const dataByteSize = Math.max(0, Number(node?.dataByteSize || estimateNodeDataBytes(node)));
  const dataRows = Math.max(1, Number(node?.dataRows || node?.dataRowCount || 1));
  const byteBoost = Math.log2(dataByteSize + 1) * sizing.byteLogScale;
  const rowBoost = Math.log2(dataRows + 1) * sizing.rowLogScale;
  return Number(
    Math.max(
      sizing.minRenderedSize,
      Math.min(sizing.maxRenderedSize, sizing.minRenderedSize + byteBoost + rowBoost),
    ).toFixed(4),
  );
}

function applyRuntimeNodeGrowth(
  node,
  visibleVectorCount = 0,
  sizingConfig = null,
  nodeSizingConfig = null,
) {
  const finalVectorCount = Math.max(0, Number(node.degree || 0));
  const runtimeVectorCount = Math.max(
    0,
    Math.min(finalVectorCount, Number(visibleVectorCount || 0)),
  );
  const nodeSizing = currentNodeSizingConfig(nodeSizingConfig);
  normalizeNodeDataMeasurements(node);
  node.baseRenderedSize = dataBackedNodeBaseRenderedSize(node, sizingConfig);
  node.sizeBaselineSource = "database-data-byte-size";
  node.visibleVectorCount = runtimeVectorCount;
  node.targetVisibleVectorCount = finalVectorCount;
  node.connectionSizeMultiplier = connectionSizeMultiplierForVectorCount(
    runtimeVectorCount,
    nodeSizing,
  );
  node.targetConnectionSizeMultiplier = connectionSizeMultiplierForVectorCount(
    finalVectorCount,
    nodeSizing,
  );
  node.scaledVectorStartIndex = nodeSizing.scaledVectorStartIndex;
  node.vectorNodeSizeScale = nodeSizing.vectorNodeSizeScale;
  node.targetVal = node.baseRenderedSize * node.targetConnectionSizeMultiplier;
  node.val = node.baseRenderedSize * node.connectionSizeMultiplier;
  node.sizeRule = "data-backed-baseline-grows-from-second-visible-vector";
  node.renderedRadius = renderedNodeRadius(node);
  node.collisionRadius = nodeCollisionRadius(node, nodeSizing);
  applyServerNodeMaterial(node);
  return node;
}

function graphDegreeMap(links) {
  const degrees = new Map();
  for (const link of links) {
    for (const id of [endpointId(link.source), endpointId(link.target)]) {
      if (!id) continue;
      degrees.set(id, (degrees.get(id) || 0) + 1);
    }
  }
  return degrees;
}

function connectionSizeMultiplierForVectorCount(vectorCount = 0, config = null) {
  const nodeSizing = currentNodeSizingConfig(config);
  const additionalVectors = Math.max(
    0,
    Number(vectorCount || 0) - Number(nodeSizing.scaledVectorStartIndex || 2) + 1,
  );
  return Math.max(1, 1 + additionalVectors * nodeSizing.vectorNodeSizeScale);
}

function activeCutoffMs(config = null) {
  return Date.now() - currentActiveWindowMs(config);
}

function activeCutoffSql(config = null) {
  return `to_timestamp(${Math.floor(activeCutoffMs(config) / 1000)})`;
}

function currentHistoryWindowConfig(config = null) {
  return normalizeHistoryWindowConfig(config || gameEngine?.config?.historyWindow);
}

function currentActiveWindowMs(config = null) {
  return Math.max(60_000, currentHistoryWindowConfig(config).days * 86_400_000);
}

function timestampInsideActiveWindow(timestamp, cutoff = activeCutoffMs()) {
  const time = Number(timestamp);
  return Number.isFinite(time) && time >= cutoff;
}

function filterGraphToActiveWindow(nodes, links, historyConfig = null) {
  const cutoff = activeCutoffMs(historyConfig);
  const activeIds = new Set();
  for (const node of nodes.values()) {
    if (timestampInsideActiveWindow(node.timestampMs, cutoff)) activeIds.add(node.id);
  }
  const filteredLinks = links.filter((link) => {
    const linkTime = parseTimestampMs(link.lastSeen);
    return (
      timestampInsideActiveWindow(linkTime, cutoff) &&
      activeIds.has(endpointId(link.source)) &&
      activeIds.has(endpointId(link.target))
    );
  });
  const linkedIds = new Set();
  for (const link of filteredLinks) {
    linkedIds.add(endpointId(link.source));
    linkedIds.add(endpointId(link.target));
  }
  for (const [id, node] of [...nodes.entries()]) {
    if (!activeIds.has(id) || !linkedIds.has(id)) {
      nodes.delete(id);
      continue;
    }
    node.activeWindowHours = Number((currentActiveWindowMs(historyConfig) / 3_600_000).toFixed(3));
    node.activeCutoff = new Date(cutoff).toISOString();
    node.hasVisibleVector = true;
  }
  return filteredLinks;
}

function enrichGraphNodeProperties(nodes, links) {
  const degrees = graphDegreeMap(links);
  const directTimestamps = new Map();
  const linkedTimestamps = new Map();
  for (const node of nodes.values()) {
    const timestamp = parseTimestampMs(node.lastSeen);
    if (Number.isFinite(timestamp)) directTimestamps.set(node.id, timestamp);
  }
  for (const link of links) {
    const linkTimestamp = parseTimestampMs(link.lastSeen);
    const endpoints = [endpointId(link.source), endpointId(link.target)].filter(Boolean);
    for (const id of endpoints) {
      if (Number.isFinite(linkTimestamp)) {
        const existing = linkedTimestamps.get(id);
        linkedTimestamps.set(
          id,
          Number.isFinite(existing) ? Math.max(existing, linkTimestamp) : linkTimestamp,
        );
      }
      for (const otherId of endpoints) {
        if (otherId === id) continue;
        const neighborTimestamp = directTimestamps.get(otherId);
        if (!Number.isFinite(neighborTimestamp)) continue;
        const existing = linkedTimestamps.get(id);
        linkedTimestamps.set(
          id,
          Number.isFinite(existing) ? Math.max(existing, neighborTimestamp) : neighborTimestamp,
        );
      }
    }
  }

  let minTime = null;
  let maxTime = null;
  for (const node of nodes.values()) {
    const timestamp = directTimestamps.get(node.id) ?? linkedTimestamps.get(node.id);
    if (!Number.isFinite(timestamp)) continue;
    minTime = minTime === null ? timestamp : Math.min(minTime, timestamp);
    maxTime = maxTime === null ? timestamp : Math.max(maxTime, timestamp);
  }
  const timeSpan = minTime !== null && maxTime !== null ? Math.max(1, maxTime - minTime) : 1;
  for (const node of nodes.values()) {
    const degree = degrees.get(node.id) || 0;
    const directTimestamp = directTimestamps.get(node.id);
    const linkedTimestamp = linkedTimestamps.get(node.id);
    const timestampMs = Number.isFinite(directTimestamp)
      ? directTimestamp
      : Number.isFinite(linkedTimestamp)
        ? linkedTimestamp
        : null;
    const ageRatio =
      timestampMs === null || minTime === null || maxTime === null
        ? null
        : Math.max(0, Math.min(1, (maxTime - timestampMs) / timeSpan));
    normalizeNodeDataMeasurements(node);
    const baseRenderedSize = dataBackedNodeBaseRenderedSize(node);
    const connectionSizeMultiplier = connectionSizeMultiplierForVectorCount(degree);
    node.degree = degree;
    node.connectionSizeMultiplier = connectionSizeMultiplier;
    node.targetConnectionSizeMultiplier = connectionSizeMultiplier;
    node.visibleVectorCount = 0;
    node.targetVisibleVectorCount = degree;
    node.timestampMs = timestampMs;
    node.timestampSource = Number.isFinite(directTimestamp)
      ? "direct"
      : Number.isFinite(linkedTimestamp)
        ? "linked-facts"
        : "unavailable";
    node.ageRatio = ageRatio;
    node.baseRenderedSize = baseRenderedSize;
    node.sizeBaselineSource = "database-data-byte-size";
    node.targetVal = baseRenderedSize * connectionSizeMultiplier;
    node.val = baseRenderedSize;
    node.sizeRule = "data-backed-baseline-grows-from-second-visible-vector";
    node.visualColor = propertyColor(node);
    node.visualShape = propertyShape(node);
    node.settledVisualShape = node.visualShape;
    node.visualSignature = propertySignature(node);
    node.renderedRadius = renderedNodeRadius(node);
    node.collisionRadius = nodeCollisionRadius(node);
    applyServerNodeMaterial(node);
  }
}

function linkThickness(link, degrees = new Map()) {
  const value = Math.max(0.05, Number(link.value || 1));
  const sourceDegree = degrees.get(endpointId(link.source)) || 0;
  const targetDegree = degrees.get(endpointId(link.target)) || 0;
  const endpointDegree = Math.max(sourceDegree, targetDegree);
  const signature = linkSignature(link);
  const sourceFactSpan = Math.log2(String(endpointId(link.source) || "").length + 2);
  const targetFactSpan = Math.log2(String(endpointId(link.target) || "").length + 2);
  const relationSpan = Math.log2(String(link.type || link.sourceTable || "").length + 2);
  const factualBase = 1.12 + Math.min(1.08, (sourceFactSpan + targetFactSpan + relationSpan) / 34);
  const valueBoost = Math.min(1.65, Math.log2(value + 1) * 0.42);
  const degreeBoost = Math.min(1.18, Math.log2(endpointDegree + 1) * 0.23);
  const signatureJitter = (hashUnit(signature, 8) - 0.5) * 0.22;
  return Math.max(1.35, Math.min(6.2, factualBase + valueBoost + degreeBoost + signatureJitter));
}

function linkVisualMetadata(link, degrees = new Map()) {
  const value = Math.max(0.05, Number(link.value || 1));
  const sourceDegree = degrees.get(endpointId(link.source)) || 0;
  const targetDegree = degrees.get(endpointId(link.target)) || 0;
  const endpointDegree = Math.max(sourceDegree, targetDegree);
  const signature = linkSignature(link);
  const hue = hashUnit(signature, 4) * 360;
  const saturation = 48 + hashUnit(signature, 10) * 30;
  const valuePulse = Math.min(1, Math.log2(value + 1) / 7);
  const degreePulse = Math.min(1, Math.log2(endpointDegree + 1) / 8);
  const factualPulse = (valuePulse + degreePulse + hashUnit(signature, 22)) / 3;
  const particleWidth = Math.max(
    5.2,
    Math.min(14.8, linkThickness(link, degrees) * (1.72 + factualPulse * 1.08)),
  );
  const particleCount = Math.max(
    1,
    Math.min(
      6,
      Math.round(1 + valuePulse * 2.2 + degreePulse * 1.7 + hashUnit(signature, 30) * 1.2),
    ),
  );
  const flashRate = Number((0.92 + factualPulse * 1.85).toFixed(3));
  const flashPhase = Number(hashUnit(signature, 38).toFixed(3));
  const particleHue = contrastingHue(hue, signature);
  return {
    dark: {
      color: hslColor(hue, saturation, 66 + hashUnit(signature, 16) * 18, 0.9 + factualPulse * 0.1),
      opacity: Number((0.9 + factualPulse * 0.1).toFixed(3)),
      particleColor: hslColor(
        particleHue,
        Math.min(96, saturation + 18),
        80 + factualPulse * 16,
        0.98,
      ),
      particleWidth,
      particleCount,
      flashRate,
      flashPhase,
      flashMin: 0.64,
      flashMax: 1.42,
    },
    light: {
      color: hslColor(
        hue,
        saturation,
        30 + hashUnit(signature, 16) * 14,
        0.58 + factualPulse * 0.16,
      ),
      opacity: Number((0.58 + factualPulse * 0.16).toFixed(3)),
      particleColor: hslColor(
        particleHue,
        Math.min(94, saturation + 16),
        22 + factualPulse * 14,
        0.96,
      ),
      particleWidth,
      particleCount,
      flashRate,
      flashPhase,
      flashMin: 0.72,
      flashMax: 1.34,
    },
  };
}

function materialDepthDescriptor(opacity) {
  const finalOpacity = Number(Math.max(0.02, Math.min(1, Number(opacity))).toFixed(4));
  const isOpaque = finalOpacity >= 0.98;
  return {
    opacity: finalOpacity,
    transparent: !isOpaque,
    depthTest: true,
    depthWrite: isOpaque,
    renderOrder: 0,
  };
}

function applyServerNodeMaterial(node, renderConfig = null) {
  if (!node) return node;
  const render = normalizeRenderSettingsConfig(renderConfig || gameEngine?.config?.renderSettings);
  const color = node.visualColor || propertyColor(node);
  const active = node.engineState === "node_changed" || node.engineState === "node_spawned";
  node.material = {
    owner: "server-game-engine",
    kind: "MeshStandardMaterial",
    color,
    ...materialDepthDescriptor(render.nodeOpacity),
    roughness: 0.48,
    metalness: 0.16,
    emissive: color,
    emissiveIntensity: active ? 0.22 : 0.045,
    flatShading: true,
  };
  return node;
}

function linkMaterialModes(link, renderConfig = null) {
  const render = normalizeRenderSettingsConfig(renderConfig || gameEngine?.config?.renderSettings);
  const modes = link.visualModes || linkVisualMetadata(link);
  const buildMode = (mode) => {
    const vectorOpacity = Math.max(
      0.02,
      Math.min(render.vectorOpacity, Number(mode?.opacity || render.vectorOpacity)),
    );
    const packetOpacity = render.packetOpacity;
    return {
      vector: {
        owner: "server-game-engine",
        kind: "link-material",
        color: mode?.color || "#7dd3fc",
        diameter: Number(
          (
            Math.max(0.08, Number(link.visualWidth ?? link.thickness ?? link.width ?? 0.68)) *
            render.vectorDiameterVisualScale
          ).toFixed(4),
        ),
        ...materialDepthDescriptor(vectorOpacity),
      },
      packet: {
        owner: "server-game-engine",
        kind: "MeshBasicMaterial",
        color: mode?.particleColor || mode?.color || "#fef08a",
        width: Number(
          (
            Math.max(1, Number(mode?.particleWidth || 2.4)) * render.packetDataNodeVisualScale
          ).toFixed(4),
        ),
        ...materialDepthDescriptor(packetOpacity),
      },
    };
  };
  return {
    dark: buildMode(modes.dark || modes.light || {}),
    light: buildMode(modes.light || modes.dark || {}),
  };
}

function applyServerLinkMaterials(link, renderConfig = null) {
  if (!link) return link;
  link.materialModes = linkMaterialModes(link, renderConfig);
  link.renderedVectorDiameter = Number(link.materialModes.dark.vector.diameter);
  link.renderedPacketWidth = Number(link.materialModes.dark.packet.width);
  return link;
}

function applyServerMaterialDescriptors(nodes = [], links = [], renderConfig = null) {
  for (const node of nodes) applyServerNodeMaterial(node, renderConfig);
  for (const link of links) applyServerLinkMaterials(link, renderConfig);
}

function enrichGraphLinkProperties(links, nodes = new Map()) {
  const degrees = graphDegreeMap(links);
  for (const link of links) {
    delete link.restLength;
    link.thickness = linkThickness(link, degrees);
    link.visualWidth = link.thickness;
    link.visualModes = linkVisualMetadata(link, degrees);
    applyServerLinkMaterials(link);
  }
}

function attractionAffinity(left, right) {
  const sameVisualType = left.visualShape && left.visualShape === right.visualShape;
  const sameGroupType = (left.group || "") === (right.group || "");
  if (sameVisualType && sameGroupType) return 4.6;
  if (sameGroupType) return 3.8;
  return 0.012;
}

function applyRuntimeCollisionBoundary(nodeList) {
  let collisions = 0;
  for (let pass = 0; pass < 32; pass += 1) {
    let passCollisions = 0;
    for (let leftIndex = 0; leftIndex < nodeList.length; leftIndex += 1) {
      const left = nodeList[leftIndex];
      for (let rightIndex = leftIndex + 1; rightIndex < nodeList.length; rightIndex += 1) {
        const right = nodeList[rightIndex];
        let dx = Number(right.x) - Number(left.x);
        let dy = Number(right.y) - Number(left.y);
        let dz = Number(right.z) - Number(left.z);
        let distance = Math.hypot(dx, dy, dz);
        if (!Number.isFinite(distance) || distance < 0.01) {
          ({ dx, dy, dz, distance } = resolveZeroDistanceDirection(
            `collision:${left.id}:${right.id}`,
          ));
        }
        const desired = nodeCollisionRadius(left) + nodeCollisionRadius(right) + noTouchEpsilon;
        if (distance >= desired) continue;
        const nx = dx / distance;
        const ny = dy / distance;
        const nz = dz / distance;
        const overlap = desired - distance + 0.02;
        const leftRadius = renderedNodeRadius(left);
        const rightRadius = renderedNodeRadius(right);
        const totalRadius = Math.max(0.01, leftRadius + rightRadius);
        const leftShare = Math.min(0.85, Math.max(0.15, rightRadius / totalRadius));
        const rightShare = Math.min(0.85, Math.max(0.15, leftRadius / totalRadius));
        left.x -= nx * overlap * leftShare;
        left.y -= ny * overlap * leftShare;
        left.z -= nz * overlap * leftShare;
        right.x += nx * overlap * rightShare;
        right.y += ny * overlap * rightShare;
        right.z += nz * overlap * rightShare;
        collisions += 1;
        passCollisions += 1;
      }
    }
    if (passCollisions === 0) break;
  }
  return collisions;
}

function closestSegmentParameter3d(start, end, point) {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const dz = end.z - start.z;
  const lengthSq = dx * dx + dy * dy + dz * dz;
  if (!Number.isFinite(lengthSq) || lengthSq < 1e-8) return 0;
  const t =
    ((point.x - start.x) * dx + (point.y - start.y) * dy + (point.z - start.z) * dz) / lengthSq;
  return Math.max(0, Math.min(1, t));
}

function runtimeVectorRadius(link, renderConfig = null) {
  const render = normalizeRenderSettingsConfig(renderConfig || gameEngine?.config?.renderSettings);
  const width = Number(link.visualWidth ?? link.thickness ?? link.width);
  const baseWidth = Number.isFinite(width) ? Math.max(0.08, width) : 0.68;
  return Math.max(0.04, (baseWidth * render.vectorDiameterVisualScale) / 2);
}

function applyRuntimeVectorCollisionBoundary(nodeList, linkList, renderConfig = null) {
  const nodes = new Map(nodeList.map((node) => [node.id, node]));
  const adjustedNodeIds = new Set();
  let collisions = 0;
  let maxOverlapBefore = 0;
  let maxOverlapAfter = 0;

  for (let pass = 0; pass < 18; pass += 1) {
    let passCollisions = 0;
    for (const link of linkList) {
      const sourceId = endpointId(link.source);
      const targetId = endpointId(link.target);
      const source = nodes.get(sourceId);
      const target = nodes.get(targetId);
      if (!source || !target) continue;
      const start = { x: Number(source.x), y: Number(source.y), z: Number(source.z) };
      const end = { x: Number(target.x), y: Number(target.y), z: Number(target.z) };
      if (![start.x, start.y, start.z, end.x, end.y, end.z].every(Number.isFinite)) continue;
      const vectorRadius = runtimeVectorRadius(link, renderConfig);

      for (const node of nodeList) {
        if (!node?.id || node.id === sourceId || node.id === targetId) continue;
        const point = { x: Number(node.x), y: Number(node.y), z: Number(node.z) };
        if (![point.x, point.y, point.z].every(Number.isFinite)) continue;
        const t = closestSegmentParameter3d(start, end, point);
        if (t <= 0.015 || t >= 0.985) continue;
        const closest = {
          x: start.x + (end.x - start.x) * t,
          y: start.y + (end.y - start.y) * t,
          z: start.z + (end.z - start.z) * t,
        };
        let dx = point.x - closest.x;
        let dy = point.y - closest.y;
        let dz = point.z - closest.z;
        let distance = Math.hypot(dx, dy, dz);
        if (!Number.isFinite(distance) || distance < 0.01) {
          const resolved = resolveZeroDistanceDirection(
            `vector-collision:${graphLinkKey(link)}:${node.id}:${pass}`,
          );
          dx = resolved.dx;
          dy = resolved.dy;
          dz = resolved.dz;
          distance = resolved.distance;
        }
        const desired = nodeCollisionRadius(node) + vectorRadius + noTouchEpsilon;
        const overlap = desired - distance;
        if (overlap <= 0) continue;
        const nx = dx / distance;
        const ny = dy / distance;
        const nz = dz / distance;
        const step = overlap + noTouchEpsilon;
        node.x += nx * step;
        node.y += ny * step;
        node.z += nz * step;
        node.vx = (Number(node.vx) || 0) + nx * Math.min(0.65, step * 0.012);
        node.vy = (Number(node.vy) || 0) + ny * Math.min(0.65, step * 0.012);
        node.vz = (Number(node.vz) || 0) + nz * Math.min(0.65, step * 0.012);
        collisions += 1;
        passCollisions += 1;
        adjustedNodeIds.add(node.id);
        maxOverlapBefore = Math.max(maxOverlapBefore, overlap);
        maxOverlapAfter = Math.max(maxOverlapAfter, Math.max(0, overlap - step));
      }
    }
    if (passCollisions === 0) break;
  }

  return {
    collisions,
    adjustedNodes: adjustedNodeIds.size,
    maxOverlapBefore: Number(maxOverlapBefore.toFixed(6)),
    maxOverlapAfter: Number(maxOverlapAfter.toFixed(6)),
  };
}

function settleRuntimeCollisionBoundaries(nodeList, linkList, renderConfig = null, options = {}) {
  const maxPasses = Math.max(1, Math.min(80, Math.round(Number(options.maxPasses) || 36)));
  let moved = 0;
  let collisionBoundary = 0;
  let vectorCollisionBoundary = {
    collisions: 0,
    adjustedNodes: 0,
    maxOverlapBefore: 0,
    maxOverlapAfter: 0,
  };

  for (let pass = 0; pass < maxPasses; pass += 1) {
    const vectorStats = applyRuntimeVectorCollisionBoundary(nodeList, linkList, renderConfig);
    const nodeCollisions = applyRuntimeCollisionBoundary(nodeList);
    moved += vectorStats.collisions + nodeCollisions;
    collisionBoundary = nodeCollisions;
    vectorCollisionBoundary = vectorStats;
    if (vectorStats.collisions === 0 && nodeCollisions === 0) break;
  }

  return { moved, collisionBoundary, vectorCollisionBoundary };
}

function applyPositionSanityRule(nodeList) {
  let repaired = 0;
  for (const node of nodeList) {
    if (usableRuntimePosition(node)) continue;
    Object.assign(node, runtimeSpawnPosition(node, nodeList));
    repaired += 1;
  }
  return repaired;
}

function applyVelocityDampingRule(nodeList) {
  for (const node of nodeList) {
    node.vx = (Number(node.vx) || 0) * 0.9;
    node.vy = (Number(node.vy) || 0) * 0.9;
    node.vz = (Number(node.vz) || 0) * 0.9;
  }
  return nodeList.length;
}

function applyAttractionRule(nodeList) {
  let interactions = 0;
  for (let leftIndex = 0; leftIndex < nodeList.length; leftIndex += 1) {
    const left = nodeList[leftIndex];
    for (let rightIndex = leftIndex + 1; rightIndex < nodeList.length; rightIndex += 1) {
      const right = nodeList[rightIndex];
      let dx = Number(right.x) - Number(left.x);
      let dy = Number(right.y) - Number(left.y);
      let dz = Number(right.z) - Number(left.z);
      let distance = Math.hypot(dx, dy, dz);
      if (!Number.isFinite(distance) || distance < 0.01) continue;
      const affinity = attractionAffinity(left, right);
      const largerRadius = Math.max(renderedNodeRadius(left), renderedNodeRadius(right));
      const amount = Math.min(
        0.28,
        distance * affinity * Math.min(0.00045, 0.00012 + largerRadius / 1800000),
      );
      const nx = dx / distance;
      const ny = dy / distance;
      const nz = dz / distance;
      const leftRadius = renderedNodeRadius(left);
      const rightRadius = renderedNodeRadius(right);
      const totalRadius = Math.max(0.01, leftRadius + rightRadius);
      const leftShare = rightRadius / totalRadius;
      const rightShare = leftRadius / totalRadius;
      left.vx += nx * amount * leftShare;
      left.vy += ny * amount * leftShare;
      left.vz += nz * amount * leftShare;
      right.vx -= nx * amount * rightShare;
      right.vy -= ny * amount * rightShare;
      right.vz -= nz * amount * rightShare;
      interactions += 1;
    }
  }
  return interactions;
}

function applyVelocityIntegrationRule(nodeList) {
  for (const node of nodeList) {
    node.x += Number(node.vx) || 0;
    node.y += Number(node.vy) || 0;
    node.z += Number(node.vz) || 0;
  }
  return nodeList.length;
}

function clearDynamicOrbitMetadata(node) {
  for (const key of [
    "orbitAnchorId",
    "orbitAssociationLinkKey",
    "orbitAssociationType",
    "orbitAssociationValue",
    "orbitRule",
    "orbitPhase",
    "orbitAngularSpeed",
    "orbitLongitude",
    "orbitLatitude",
    "orbitCurrentLongitude",
    "orbitCurrentLatitude",
    "orbitMinute",
    "orbitSecond",
    "orbitTimestampIso",
    "orbitTimestampSource",
    "orbitAgeRank",
    "orbitAnchorSlot",
    "orbitAnchorSiblingCount",
    "orbitLongitudeSlot",
    "orbitLatitudeSlot",
    "orbitShell",
    "orbitCoordinateRule",
    "orbitBaseX",
    "orbitBaseY",
    "orbitBaseZ",
    "orbitRadius",
  ]) {
    delete node[key];
  }
}

function linkAssociationScore(link, larger, smaller) {
  const value = Math.max(0.05, Number(link.value || 1));
  const largerRadius = renderedNodeRadius(larger);
  const smallerRadius = renderedNodeRadius(smaller);
  const sizeRatio = largerRadius / Math.max(0.01, smallerRadius);
  const largerDegree = Math.max(0, Number(larger.degree || 0));
  return value * sizeRatio * (1 + Math.log2(largerDegree + 1) * 0.14);
}

function timestampOrbitPhase(node) {
  const timestamp = Number(node.timestampMs);
  if (Number.isFinite(timestamp)) {
    const date = new Date(timestamp);
    const minuteOfDay = date.getUTCHours() * 60 + date.getUTCMinutes();
    return (
      ((minuteOfDay / 1440) * Math.PI * 2 + (date.getUTCSeconds() / 60) * 0.18) % (Math.PI * 2)
    );
  }
  return null;
}

function timestampOrbitCoordinates(node) {
  const timestamp = Number(node.timestampMs);
  if (!Number.isFinite(timestamp)) return null;
  const date = new Date(timestamp);
  if (Number.isNaN(date.getTime())) return null;
  const minuteOfDay = date.getUTCHours() * 60 + date.getUTCMinutes();
  const second = date.getUTCSeconds() + date.getUTCMilliseconds() / 1000;
  const longitude = (minuteOfDay / 1440) * 360 - 180;
  const latitude = (second / 60) * 180 - 90;
  return {
    longitude,
    latitude,
    minuteOfDay,
    second,
    timestampIso: date.toISOString(),
    vector: sphericalOrbitVector(longitude, latitude),
  };
}

function timestampAgeSlotOffsets(slot = 0) {
  const safeSlot = Math.max(0, Number.isFinite(Number(slot)) ? Number(slot) : 0);
  if (safeSlot === 0) return { longitudeOffset: 0, latitudeOffset: 0, shell: 0 };
  const angle = safeSlot * 2.399963229728653;
  const spread = Math.min(18, 1.8 + Math.sqrt(safeSlot) * 0.9);
  return {
    longitudeOffset: Math.cos(angle) * spread,
    latitudeOffset: Math.sin(angle) * Math.min(12, spread * 0.68),
    shell: Math.floor(safeSlot / 48),
  };
}

function timestampOrbitVectorForSatellite(satellite) {
  const baseLongitude = Number.isFinite(Number(satellite.orbitLongitude))
    ? Number(satellite.orbitLongitude)
    : 0;
  const baseLatitude = Number.isFinite(Number(satellite.orbitLatitude))
    ? Number(satellite.orbitLatitude)
    : 0;
  const offsets = timestampAgeSlotOffsets(satellite.orbitAnchorSlot);
  const longitude = ((baseLongitude + offsets.longitudeOffset + 540) % 360) - 180;
  const latitude = Math.max(-89.8, Math.min(89.8, baseLatitude + offsets.latitudeOffset));
  return {
    longitude,
    latitude,
    shell: offsets.shell,
    vector: sphericalOrbitVector(longitude, latitude),
  };
}

function updateTimestampOrbitMetadata(
  satellite,
  coordinates,
  ageRank = satellite.orbitAgeRank,
  anchorSlot = satellite.orbitAnchorSlot,
  siblingCount = satellite.orbitAnchorSiblingCount,
) {
  satellite.orbitLongitude = Number(coordinates.longitude.toFixed(6));
  satellite.orbitLatitude = Number(coordinates.latitude.toFixed(6));
  satellite.orbitMinute = coordinates.minuteOfDay;
  satellite.orbitSecond = Number(coordinates.second.toFixed(3));
  satellite.orbitTimestampIso = coordinates.timestampIso;
  satellite.orbitTimestampSource = satellite.timestampSource || "timestampMs";
  satellite.orbitAgeRank = Number.isFinite(Number(ageRank))
    ? Number(ageRank)
    : satellite.orbitAgeRank;
  satellite.orbitAnchorSlot = Number.isFinite(Number(anchorSlot)) ? Number(anchorSlot) : 0;
  satellite.orbitAnchorSiblingCount = Number.isFinite(Number(siblingCount))
    ? Number(siblingCount)
    : satellite.orbitAnchorSiblingCount;
  const slotVector = timestampOrbitVectorForSatellite(satellite);
  satellite.orbitCurrentLongitude = Number(slotVector.longitude.toFixed(6));
  satellite.orbitCurrentLatitude = Number(slotVector.latitude.toFixed(6));
  satellite.orbitLongitudeSlot = Number(
    (slotVector.longitude - satellite.orbitLongitude).toFixed(6),
  );
  satellite.orbitLatitudeSlot = Number((slotVector.latitude - satellite.orbitLatitude).toFixed(6));
  satellite.orbitShell = slotVector.shell;
  satellite.orbitCoordinateRule = "timestamp-minute-longitude-second-latitude-age-slot";
  satellite.orbitBaseX = Number(coordinates.vector.x.toFixed(6));
  satellite.orbitBaseY = Number(coordinates.vector.y.toFixed(6));
  satellite.orbitBaseZ = Number(coordinates.vector.z.toFixed(6));
}

function sphericalOrbitVector(longitudeDeg, latitudeDeg) {
  const longitude = (Number(longitudeDeg) * Math.PI) / 180;
  const latitude = (Number(latitudeDeg) * Math.PI) / 180;
  const cosLatitude = Math.cos(latitude);
  return {
    x: Math.cos(latitude) * Math.cos(longitude),
    y: Math.sin(latitude),
    z: cosLatitude * Math.sin(longitude),
  };
}

function assignDynamicAssociationOrbits(nodes, links) {
  const candidates = new Map();
  for (const node of nodes.values()) clearDynamicOrbitMetadata(node);

  for (const link of links.values()) {
    const source = nodes.get(endpointId(link.source));
    const target = nodes.get(endpointId(link.target));
    if (!source || !target) continue;

    const sourceRadius = renderedNodeRadius(source);
    const targetRadius = renderedNodeRadius(target);
    const sourceDegree = Number(source.degree || 0);
    const targetDegree = Number(target.degree || 0);
    if (
      Math.abs(sourceRadius - targetRadius) <
      Math.max(2, Math.min(sourceRadius, targetRadius) * 0.12)
    )
      continue;

    const larger = sourceRadius > targetRadius ? source : target;
    const smaller = sourceRadius > targetRadius ? target : source;
    if (Number(larger.degree || 0) <= Number(smaller.degree || 0) && sourceDegree === targetDegree)
      continue;

    const score = linkAssociationScore(link, larger, smaller);
    const existing = candidates.get(smaller.id);
    if (existing && existing.score >= score) continue;
    candidates.set(smaller.id, { anchor: larger, satellite: smaller, link, score });
  }

  const assignments = [...candidates.values()]
    .map((candidate) => ({
      ...candidate,
      coordinates: timestampOrbitCoordinates(candidate.satellite),
    }))
    .filter((candidate) => candidate.coordinates)
    .sort(
      (left, right) =>
        Number(left.satellite.timestampMs || 0) - Number(right.satellite.timestampMs || 0),
    );

  let count = 0;
  const anchorSlotCounts = new Map();
  const anchorSiblingCounts = assignments.reduce((acc, assignment) => {
    acc.set(assignment.anchor.id, (acc.get(assignment.anchor.id) || 0) + 1);
    return acc;
  }, new Map());
  for (const { anchor, satellite, link, coordinates } of assignments) {
    const anchorRadius = nodeCollisionRadius(anchor);
    const satelliteRadius = nodeCollisionRadius(satellite);
    const anchorSlot = anchorSlotCounts.get(anchor.id) || 0;
    anchorSlotCounts.set(anchor.id, anchorSlot + 1);
    satellite.orbitAnchorId = anchor.id;
    satellite.orbitAssociationLinkKey = link.key || graphLinkKey(link);
    satellite.orbitAssociationType = link.type || "direct-neural-association";
    satellite.orbitAssociationValue = Number(link.value || 1);
    satellite.orbitRule = "dynamic-direct-association-orbit";
    satellite.orbitPhase = Number(timestampOrbitPhase(satellite).toFixed(6));
    satellite.orbitAngularSpeed = 0;
    updateTimestampOrbitMetadata(
      satellite,
      coordinates,
      count,
      anchorSlot,
      anchorSiblingCounts.get(anchor.id) || 1,
    );
    satellite.orbitRadius = Number(
      (
        anchorRadius +
        satelliteRadius +
        noTouchEpsilon +
        (satellite.orbitShell || 0) * (satelliteRadius * 2.4 + noTouchEpsilon)
      ).toFixed(6),
    );
    count += 1;
  }
  return count;
}

function applyDynamicAssociationOrbitSprings(nodes) {
  const nodeMap = new Map(nodes.map((node) => [node.id, node]));
  const orbitingSatellites = nodes
    .filter((node) => node.orbitAnchorId)
    .sort((left, right) => nodeCollisionRadius(right) - nodeCollisionRadius(left));
  let springForces = 0;
  for (const satellite of orbitingSatellites) {
    const anchor = nodeMap.get(satellite.orbitAnchorId);
    if (!anchor) continue;

    const desired = nodeCollisionRadius(anchor) + nodeCollisionRadius(satellite) + noTouchEpsilon;
    const coordinates = timestampOrbitCoordinates(satellite);
    if (coordinates) updateTimestampOrbitMetadata(satellite, coordinates);
    const slotVector = timestampOrbitVectorForSatellite(satellite);
    const currentLongitude = slotVector.longitude;
    const currentLatitude = slotVector.latitude;
    const direction = slotVector.vector;
    satellite.orbitCurrentLongitude = Number(currentLongitude.toFixed(6));
    satellite.orbitCurrentLatitude = Number(currentLatitude.toFixed(6));
    satellite.orbitShell = slotVector.shell;

    const shellDistance =
      slotVector.shell * (nodeCollisionRadius(satellite) * 2.4 + noTouchEpsilon);
    const orbitDistance = desired + shellDistance;
    satellite.orbitRadius = Number(orbitDistance.toFixed(6));
    const targetX = Number(anchor.x) + direction.x * orbitDistance;
    const targetY = Number(anchor.y) + direction.y * orbitDistance;
    const targetZ = Number(anchor.z) + direction.z * orbitDistance;
    satellite.designatedX = Number(targetX.toFixed(6));
    satellite.designatedY = Number(targetY.toFixed(6));
    satellite.designatedZ = Number(targetZ.toFixed(6));

    const dx = targetX - Number(satellite.x);
    const dy = targetY - Number(satellite.y);
    const dz = targetZ - Number(satellite.z);
    const distance = Math.hypot(dx, dy, dz);
    if (!Number.isFinite(distance) || distance < 0.001) continue;

    const radiusScale = Math.max(1, nodeCollisionRadius(satellite) + nodeCollisionRadius(anchor));
    const spring = Math.min(1.8, Math.max(0.025, distance / radiusScale) * 0.22);
    satellite.vx = (Number(satellite.vx) || 0) + (dx / distance) * spring;
    satellite.vy = (Number(satellite.vy) || 0) + (dy / distance) * spring;
    satellite.vz = (Number(satellite.vz) || 0) + (dz / distance) * spring;
    springForces += 1;
  }
  return springForces;
}

function applyConnectedCollisionRadiusSpring(nodeList, linkList, renderConfig = null) {
  const nodes = new Map(nodeList.map((node) => [node.id, node]));
  const stats = {
    links: 0,
    springForces: 0,
    compressed: 0,
    stretched: 0,
    maxStretchBefore: 0,
    maxCompressionBefore: 0,
  };

  for (const link of linkList) {
    const source = nodes.get(endpointId(link.source));
    const target = nodes.get(endpointId(link.target));
    if (!source || !target) continue;
    let dx = Number(target.x) - Number(source.x);
    let dy = Number(target.y) - Number(source.y);
    let dz = Number(target.z) - Number(source.z);
    let distance = Math.hypot(dx, dy, dz);
    if (!Number.isFinite(distance) || distance < 0.01) {
      const resolved = resolveZeroDistanceDirection(`connected-spring:${source.id}:${target.id}`);
      dx = resolved.dx;
      dy = resolved.dy;
      dz = resolved.dz;
      distance = resolved.distance;
    }

    const vectorRadius = runtimeVectorRadius(link, renderConfig);
    const desired =
      nodeCollisionRadius(source) + nodeCollisionRadius(target) + vectorRadius + noTouchEpsilon;
    const delta = distance - desired;
    if (Math.abs(delta) < Math.max(0.25, desired * 0.015)) continue;
    const nx = dx / distance;
    const ny = dy / distance;
    const nz = dz / distance;
    const amount = Math.min(2.8, Math.abs(delta) * 0.035);
    const direction = delta > 0 ? 1 : -1;
    const sourceRadius = nodeCollisionRadius(source);
    const targetRadius = nodeCollisionRadius(target);
    const totalRadius = Math.max(0.01, sourceRadius + targetRadius);
    const sourceShare = Math.min(0.85, Math.max(0.15, targetRadius / totalRadius));
    const targetShare = Math.min(0.85, Math.max(0.15, sourceRadius / totalRadius));
    source.vx = (Number(source.vx) || 0) + nx * amount * direction * sourceShare;
    source.vy = (Number(source.vy) || 0) + ny * amount * direction * sourceShare;
    source.vz = (Number(source.vz) || 0) + nz * amount * direction * sourceShare;
    target.vx = (Number(target.vx) || 0) - nx * amount * direction * targetShare;
    target.vy = (Number(target.vy) || 0) - ny * amount * direction * targetShare;
    target.vz = (Number(target.vz) || 0) - nz * amount * direction * targetShare;
    stats.links += 1;
    stats.springForces += 1;
    if (delta > 0) {
      stats.stretched += 1;
      stats.maxStretchBefore = Math.max(stats.maxStretchBefore, delta);
    } else {
      stats.compressed += 1;
      stats.maxCompressionBefore = Math.max(stats.maxCompressionBefore, Math.abs(delta));
    }
  }

  stats.maxStretchBefore = Number(stats.maxStretchBefore.toFixed(6));
  stats.maxCompressionBefore = Number(stats.maxCompressionBefore.toFixed(6));
  return stats;
}

function eventSummary(events) {
  return events.reduce((acc, event) => {
    acc[event.type] = (acc[event.type] || 0) + 1;
    return acc;
  }, {});
}

class MemoryGameEngine {
  constructor() {
    this.nodes = new Map();
    this.links = new Map();
    this.nodeFingerprints = new Map();
    this.events = [];
    this.tick = 0;
    this.lastSnapshotAt = null;
    this.lastGraphVersion = null;
    this.lastError = null;
    this.timer = null;
    this.physicsTimer = null;
    this.snapshotTimer = null;
    this.running = false;
    this.syncInFlight = false;
    this.graphRefreshInFlight = false;
    this.stats = {};
    this.dataSource = null;
    this.frame = 0;
    this.startedAt = Date.now();
    this.lastRuntimeCollisions = 0;
    this.lastRuntimeVectorCollisions = {
      collisions: 0,
      adjustedNodes: 0,
      maxOverlapBefore: 0,
      maxOverlapAfter: 0,
    };
    this.rules = createEngineRuleState();
    this.config = createEngineConfigState();
    this.ruleStats = {};
    this.identity = null;
    this.buildState = createEmptyBuildState();
    this.scanPage = 0;
    this.accumulatedNodes = new Map();
    this.accumulatedLinks = new Map();
  }

  async start() {
    await this.ensureTables();
    await this.loadPersistentConfig();
    this.running = true;
    this.timer = setInterval(() => {
      this.sync("db-poll").catch((error) => {
        this.lastError = error.message;
        console.error("Zorg Memory 3D game engine sync failed", error);
      });
    }, enginePollMs);
    this.physicsTimer = setInterval(() => {
      try {
        this.advanceGameFrame();
      } catch (error) {
        this.lastError = error.message;
        console.error("Zorg Memory 3D game engine frame failed", error);
      }
    }, enginePhysicsTickMs);
    this.snapshotTimer = setInterval(() => {
      broadcastGameSnapshot();
    }, engineSnapshotBroadcastMs);
    setImmediate(() => {
      this.sync("startup").catch((error) => {
        this.lastError = error.message;
        console.error("Zorg Memory 3D game engine startup sync failed", error);
      });
    });
  }

  async ensureTables() {
    await pool.query(`
      create table if not exists zorg_memory_3d_engine_events (
        event_id bigserial primary key,
        event_type text not null,
        node_id text,
        link_key text,
        payload jsonb not null,
        created_at timestamptz not null default now()
      )
    `);
    await pool.query(
      "create index if not exists zorg_memory_3d_engine_events_created_idx on zorg_memory_3d_engine_events (created_at desc)",
    );
    await pool.query(`
      create table if not exists zorg_memory_3d_engine_config (
        config_key text primary key,
        payload jsonb not null,
        updated_at timestamptz not null default now()
      )
    `);
    const indexStats = await ensureHistoryEstimateIndexes();
    this.ruleStats.historyEstimateIndexes = indexStats;
  }

  async loadPersistentConfig() {
    const result = await pool.query(
      "select payload from zorg_memory_3d_engine_config where config_key = $1",
      ["runtime-config"],
    );
    if (!result.rows[0]?.payload || typeof result.rows[0].payload !== "object") return;
    const changed = this.applyEngineConfigValues(result.rows[0].payload);
    if (Object.keys(changed).length) await this.persistConfig();
  }

  async persistConfig() {
    await pool.query(
      `
        insert into zorg_memory_3d_engine_config (config_key, payload, updated_at)
        values ($1, $2::jsonb, now())
        on conflict (config_key)
        do update set payload = excluded.payload, updated_at = now()
      `,
      ["runtime-config", JSON.stringify(engineConfigSummary(this.config))],
    );
  }

  refreshRuntimeNodeSizing() {
    for (const node of this.nodes.values()) {
      applyRuntimeNodeGrowth(
        node,
        Number(node.visibleVectorCount || 0),
        this.config.dataBackedNodeSizing,
        this.config.nodeSizing,
      );
    }
  }

  applyRuntimeNodeSizingToLiveGraph() {
    this.refreshRuntimeNodeSizing();
    const nodeList = [...this.nodes.values()];
    let moved = 0;
    if (this.rules.dynamicAssociationOrbit) {
      moved += applyDynamicAssociationOrbitSprings(nodeList);
    }
    if (this.rules.connectedCollisionSpring) {
      const springStats = applyConnectedCollisionRadiusSpring(
        nodeList,
        [...this.links.values()],
        this.config.renderSettings,
      );
      moved += springStats.springForces;
      this.ruleStats.connectedCollisionSpring = springStats;
    }
    if (this.rules.vectorCollisionBoundary || this.rules.collisionBoundary) {
      const settlement = settleRuntimeCollisionBoundaries(
        nodeList,
        [...this.links.values()],
        this.config.renderSettings,
      );
      this.lastRuntimeCollisions = this.rules.collisionBoundary ? settlement.collisionBoundary : 0;
      this.lastRuntimeVectorCollisions = this.rules.vectorCollisionBoundary
        ? settlement.vectorCollisionBoundary
        : { collisions: 0, adjustedNodes: 0, maxOverlapBefore: 0, maxOverlapAfter: 0 };
      this.ruleStats.collisionBoundary = this.lastRuntimeCollisions;
      this.ruleStats.vectorCollisionBoundary = this.lastRuntimeVectorCollisions;
      moved += settlement.moved;
    }
    if (moved > 0) {
      this.frame += 1;
      this.tick += 1;
    }
    return moved;
  }

  async sync(reason = "db-poll") {
    if (this.graphRefreshInFlight) return [];
    this.graphRefreshInFlight = true;
    try {
      return await this.syncUnlocked(reason);
    } finally {
      this.graphRefreshInFlight = false;
      this.syncInFlight = false;
    }
  }

  async syncUnlocked(reason = "db-poll") {
    const scanOffset = this.scanPage * databaseScanBatchRows;
    this.scanPage = (this.scanPage + 1) % databaseScanMaxPages;
    const graphBatch = await loadGraph("", scanOffset);
    this.identity = await loadMemoryBrainIdentity();
    const fullGraph = this.accumulateGraphBatch(graphBatch, scanOffset);
    const graph = this.stageGraphBuild(fullGraph, reason);
    const events = [];
    const nextNodes = new Map();
    const seenLinks = new Map();
    const graphNodes = new Map(graph.nodes.map((node) => [node.id, node]));
    const linksByNode = graphLinksByNode(graph.links);
    const orderedNodes = pairedNodeBuildOrder(graphNodes, graph.links);
    const priorVisibleDegrees = graphDegreeMap([...this.links.values()]);
    const coldStartBuild = this.nodes.size === 0;
    const changedNodeIds = new Set();
    const dataChangedNodeIds = new Set();
    let spawnedNodeCount = 0;
    let pairedSpawnCount = 0;

    for (let index = 0; index < orderedNodes.length; index += 1) {
      if (index > 0 && index % 500 === 0) await yieldToGameLoop();
      const node = orderedNodes[index];
      const prior = this.nodes.get(node.id);
      const fingerprint = graphNodeFingerprint(node);
      const previousFingerprint = this.nodeFingerprints.get(node.id);
      const position =
        prior && usableRuntimePosition(prior)
          ? prior
          : runtimeSpawnPosition(
              node,
              [...nextNodes.values(), ...this.nodes.values()],
              linksByNode,
              nextNodes,
              this.nodes,
            );
      const eventType = !prior
        ? "node_spawned"
        : previousFingerprint && previousFingerprint !== fingerprint
          ? "node_changed"
          : null;
      const engineVersion = eventType
        ? Number(prior?.engineVersion || 0) + 1
        : Number(prior?.engineVersion || 1);
      const linkedSpawn = !prior
        ? linkedSpawnAnchor(node.id, linksByNode, nextNodes, this.nodes)
        : null;
      const eventAt = eventType ? new Date() : null;
      const priorCycleUntil = parseTimestampMs(prior?.shapeCycleUntil);
      const shapeCycleActive = Number.isFinite(priorCycleUntil) && priorCycleUntil > Date.now();
      if (!prior) {
        spawnedNodeCount += 1;
        if (linkedSpawn) pairedSpawnCount += 1;
        dataChangedNodeIds.add(node.id);
      } else if (eventType === "node_changed") {
        changedNodeIds.add(node.id);
        dataChangedNodeIds.add(node.id);
      }
      const merged = {
        ...prior,
        ...node,
        x: Number(position.x),
        y: Number(position.y),
        z: Number(position.z),
        engineVersion,
        engineState: eventType || (shapeCycleActive ? "updating" : "stable"),
        pulseAt: eventAt ? eventAt.toISOString() : prior?.pulseAt,
        settledVisualShape: node.visualShape,
        shapeCycleStartedAt: eventAt ? eventAt.toISOString() : prior?.shapeCycleStartedAt,
        shapeCycleUntil: eventAt
          ? new Date(eventAt.getTime() + nodeShapeCycleMs).toISOString()
          : prior?.shapeCycleUntil,
      };
      applyRuntimeNodeGrowth(
        merged,
        priorVisibleDegrees.get(node.id) || 0,
        this.config.dataBackedNodeSizing,
        this.config.nodeSizing,
      );
      nextNodes.set(node.id, merged);
      this.nodeFingerprints.set(node.id, fingerprint);

      if (eventType) {
        events.push({
          type: eventType,
          nodeId: node.id,
          rule:
            eventType === "node_spawned"
              ? "spawn-paired-near-visible-vector"
              : "pulse-live-attraction-state",
          initialBuild: coldStartBuild,
          pairedVector: linkedSpawn
            ? {
                source: endpointId(linkedSpawn.link.source),
                target: endpointId(linkedSpawn.link.target),
                type: linkedSpawn.link.type || "vector",
                anchorId: linkedSpawn.anchor.id,
              }
            : null,
          node: merged,
        });
      }
    }

    let priorIndex = 0;
    for (const [nodeId, prior] of this.nodes.entries()) {
      priorIndex += 1;
      if (priorIndex % 1000 === 0) await yieldToGameLoop();
      if (nextNodes.has(nodeId)) continue;
      events.push({
        type: "node_dormant",
        nodeId,
        rule: "fade-missing-node",
        node: { ...prior, engineState: "dormant", pulseAt: new Date().toISOString() },
      });
      this.nodeFingerprints.delete(nodeId);
    }

    const degrees = graphDegreeMap(graph.links);
    for (let index = 0; index < graph.links.length; index += 1) {
      if (index > 0 && index % 500 === 0) await yieldToGameLoop();
      const link = graph.links[index];
      const key = graphLinkKey(link);
      const engineLink = {
        ...link,
        key,
        thickness: Number.isFinite(Number(link.thickness))
          ? Number(link.thickness)
          : linkThickness(link, degrees),
        visualWidth: Number.isFinite(Number(link.visualWidth))
          ? Number(link.visualWidth)
          : linkThickness(link, degrees),
        visualModes: link.visualModes || linkVisualMetadata(link, degrees),
      };
      applyServerLinkMaterials(engineLink, this.config.renderSettings);
      seenLinks.set(key, engineLink);
      if (!this.links.has(key)) {
        events.push({
          type: "link_spawned",
          linkKey: key,
          rule: "visual-vector-follows-server-node-positions",
          link: engineLink,
        });
        events.push(
          createVectorDataPacketEvent(engineLink, { type: "link_spawned", linkKey: key }),
        );
      }
    }

    let changedNodePacketEvents = 0;
    if (dataChangedNodeIds.size) {
      for (const nodeId of dataChangedNodeIds) {
        if (changedNodePacketEvents >= 96) break;
        const triggerType = changedNodeIds.has(nodeId) ? "node_changed" : "node_spawned";
        const packetEvents = createNodeVectorDataPacketEvents(
          seenLinks.values(),
          nodeId,
          { type: triggerType, nodeId },
          Math.max(1, 96 - changedNodePacketEvents),
        );
        events.push(...packetEvents);
        changedNodePacketEvents += packetEvents.length;
      }
    }

    let linkIndex = 0;
    for (const [key, link] of this.links.entries()) {
      linkIndex += 1;
      if (linkIndex % 1000 === 0) await yieldToGameLoop();
      if (!seenLinks.has(key)) {
        events.push({ type: "link_dormant", linkKey: key, rule: "detach-link", link });
      }
    }

    const orbitCount = this.rules.dynamicAssociationOrbit
      ? assignDynamicAssociationOrbits(nextNodes, seenLinks)
      : 0;
    if (!this.rules.dynamicAssociationOrbit) {
      for (const node of nextNodes.values()) clearDynamicOrbitMetadata(node);
    }
    const syncSpringStats = this.rules.connectedCollisionSpring
      ? applyConnectedCollisionRadiusSpring(
          [...nextNodes.values()],
          [...seenLinks.values()],
          this.config.renderSettings,
        )
      : {
          links: 0,
          springForces: 0,
          compressed: 0,
          stretched: 0,
          maxStretchBefore: 0,
          maxCompressionBefore: 0,
        };
    if (this.rules.dynamicAssociationOrbit)
      applyDynamicAssociationOrbitSprings([...nextNodes.values()]);
    const syncCollisionSettlement =
      this.rules.vectorCollisionBoundary || this.rules.collisionBoundary
        ? settleRuntimeCollisionBoundaries(
            [...nextNodes.values()],
            [...seenLinks.values()],
            this.config.renderSettings,
          )
        : {
            moved: 0,
            collisionBoundary: 0,
            vectorCollisionBoundary: {
              collisions: 0,
              adjustedNodes: 0,
              maxOverlapBefore: 0,
              maxOverlapAfter: 0,
            },
          };
    for (const node of nextNodes.values()) node.layoutVersion = physicsLayoutVersion;

    this.syncInFlight = true;
    this.nodes = nextNodes;
    this.links = seenLinks;
    this.tick += 1;
    this.lastSnapshotAt = graph.generatedAt;
    this.lastGraphVersion = graph.graphVersion;
    this.stats = graph.stats;
    this.stats.initialBuild = {
      coldStart: coldStartBuild,
      orderedByVectors: true,
      spawnedNodes: spawnedNodeCount,
      pairedSpawnedNodes: pairedSpawnCount,
      rootSpawnedNodes: Math.max(0, spawnedNodeCount - pairedSpawnCount),
      visibleVectors: seenLinks.size,
      syncSpawnCollisions: syncCollisionSettlement.collisionBoundary,
      syncVectorCollisions: syncCollisionSettlement.vectorCollisionBoundary,
      syncSpringStats,
      eventDrivenPacketEvents: events.filter((event) => event.type === "vector_data_packet").length,
      rule: "node endpoints are ordered by visible vectors; new nodes spawn at minimum size and randomized separated coordinates; connected nodes spring toward collision-radius distance while collision keeps nodes/vectors from intersecting",
    };
    this.stats.dynamicAssociationOrbits = orbitCount;
    this.dataSource = graph.dataSource;
    this.lastError = null;

    if (events.length) {
      this.recordEvents(events, reason).catch((error) => {
        this.lastError = error.message;
        console.error("Zorg Memory 3D event recording failed", error);
      });
      broadcastGameEvents(events);
    }
    broadcastGameSnapshot();
    this.syncInFlight = false;
    return events;
  }

  accumulateGraphBatch(graph, scanOffset = 0) {
    const cutoff = activeCutoffMs();
    for (const node of graph.nodes) {
      const timestamp = Number(node.timestampMs);
      if (!timestampInsideActiveWindow(timestamp, cutoff)) continue;
      this.accumulatedNodes.set(node.id, { ...this.accumulatedNodes.get(node.id), ...node });
    }
    for (const link of graph.links) {
      const source = endpointId(link.source);
      const target = endpointId(link.target);
      const linkTime = parseTimestampMs(link.lastSeen);
      if (!timestampInsideActiveWindow(linkTime, cutoff)) continue;
      if (!this.accumulatedNodes.has(source) || !this.accumulatedNodes.has(target)) continue;
      this.accumulatedLinks.set(graphLinkKey(link), {
        ...this.accumulatedLinks.get(graphLinkKey(link)),
        ...link,
      });
    }
    for (const [id, node] of [...this.accumulatedNodes.entries()]) {
      const timestamp = Number(node.timestampMs);
      if (!timestampInsideActiveWindow(timestamp, cutoff)) this.accumulatedNodes.delete(id);
    }
    for (const [key, link] of [...this.accumulatedLinks.entries()]) {
      const linkTime = parseTimestampMs(link.lastSeen);
      if (
        !timestampInsideActiveWindow(linkTime, cutoff) ||
        !this.accumulatedNodes.has(endpointId(link.source)) ||
        !this.accumulatedNodes.has(endpointId(link.target))
      ) {
        this.accumulatedLinks.delete(key);
      }
    }
    const nodes = [...this.accumulatedNodes.values()];
    const links = dedupeGraphLinks([...this.accumulatedLinks.values()]);
    const graphVersion = stableHash(
      JSON.stringify({
        generatedFrom: "db-only-active-window-incremental-scan",
        activeWindowMs: currentActiveWindowMs(),
        nodes: nodes
          .map(
            (node) =>
              `${node.id}:${node.degree || 0}:${node.lastSeen || ""}:${Number(node.val || 0).toFixed(3)}`,
          )
          .sort(),
        links: links.map((link) => graphLinkKey(link)).sort(),
      }),
    );
    return {
      ...graph,
      graphVersion,
      nodes,
      links,
      stats: {
        ...graph.stats,
        incrementalDatabaseScan: {
          enabled: true,
          windowDays: currentHistoryWindowConfig().days,
          scanBatchRows: databaseScanBatchRows,
          scanPage: Math.floor(scanOffset / databaseScanBatchRows),
          scanOffset,
          accumulatedNodes: nodes.length,
          accumulatedLinks: links.length,
        },
      },
      dataSource: {
        ...graph.dataSource,
        incrementalDatabaseScan: true,
        scanBatchRows: databaseScanBatchRows,
        scanOffset,
        accumulatedNodes: nodes.length,
        accumulatedLinks: links.length,
      },
    };
  }

  stageGraphBuild(graph, reason = "db-poll") {
    const targetNodeIds = new Set(graph.nodes.map((node) => node.id));
    if (!this.buildState || this.buildState.graphVersion === null)
      this.buildState = createEmptyBuildState();
    if (this.buildState.graphVersion !== graph.graphVersion) {
      this.buildState.graphVersion = graph.graphVersion;
      this.buildState.enteredNodeIds = new Set(
        [...this.buildState.enteredNodeIds].filter((id) => targetNodeIds.has(id)),
      );
      this.buildState.stagedLinkKeys = new Set();
      this.buildState.complete = false;
      this.buildState.lastAddedNodes = 0;
      this.buildState.lastAddedLinks = 0;
    }

    const beforeNodeCount = this.buildState.enteredNodeIds.size;
    const orderedLinks = orderedGraphLinks(graph.links);
    const nodeById = new Map(graph.nodes.map((node) => [node.id, node]));
    let budget = stagedBuildNodeBatch;

    const enterNode = (id) => {
      if (!id || !nodeById.has(id) || this.buildState.enteredNodeIds.has(id) || budget <= 0)
        return false;
      this.buildState.enteredNodeIds.add(id);
      budget -= 1;
      return true;
    };

    if (this.buildState.enteredNodeIds.size === 0 && orderedLinks.length) {
      const firstLink = orderedLinks[0];
      const source = endpointId(firstLink.source);
      const target = endpointId(firstLink.target);
      if (enterNode(source)) this.buildState.rootPairCount += 1;
      if (enterNode(target)) this.buildState.pairedEntryCount += 1;
    }

    let progressed = true;
    while (budget > 0 && progressed) {
      progressed = false;
      for (const link of orderedLinks) {
        if (budget <= 0) break;
        const source = endpointId(link.source);
        const target = endpointId(link.target);
        const sourceEntered = this.buildState.enteredNodeIds.has(source);
        const targetEntered = this.buildState.enteredNodeIds.has(target);
        if (sourceEntered && !targetEntered && enterNode(target)) {
          this.buildState.pairedEntryCount += 1;
          progressed = true;
        } else if (targetEntered && !sourceEntered && enterNode(source)) {
          this.buildState.pairedEntryCount += 1;
          progressed = true;
        }
      }
    }

    if (budget > 1 && this.buildState.enteredNodeIds.size < targetNodeIds.size) {
      for (const link of orderedLinks) {
        if (budget <= 1) break;
        const source = endpointId(link.source);
        const target = endpointId(link.target);
        if (
          this.buildState.enteredNodeIds.has(source) ||
          this.buildState.enteredNodeIds.has(target)
        )
          continue;
        const addedSource = enterNode(source);
        const addedTarget = enterNode(target);
        if (addedSource) this.buildState.rootPairCount += 1;
        if (addedTarget) this.buildState.pairedEntryCount += 1;
        if (addedSource || addedTarget) break;
      }
    }

    const staged = stagedGraphFromEnteredIds(graph, this.buildState.enteredNodeIds);
    const stagedNodeMap = new Map(staged.nodes.map((node) => [node.id, node]));
    enrichGraphNodeProperties(stagedNodeMap, staged.links);
    enrichGraphLinkProperties(staged.links, stagedNodeMap);
    staged.nodes = [...stagedNodeMap.values()];
    const stagedLinkKeys = new Set(staged.links.map((link) => graphLinkKey(link)));
    const previousLinkCount = this.buildState.stagedLinkKeys.size;
    this.buildState.stagedLinkKeys = stagedLinkKeys;
    this.buildState.lastAddedNodes = Math.max(
      0,
      this.buildState.enteredNodeIds.size - beforeNodeCount,
    );
    this.buildState.lastAddedLinks = Math.max(0, stagedLinkKeys.size - previousLinkCount);
    this.buildState.complete =
      staged.nodes.length === graph.nodes.length && staged.links.length === graph.links.length;
    staged.stats = {
      ...staged.stats,
      stagedBuild: {
        enabled: true,
        reason,
        rule: "active-window database scan stages visible vector endpoint pairs into the running game before free movement",
        batchNodeLimit: stagedBuildNodeBatch,
        enteredNodes: staged.nodes.length,
        targetNodes: graph.nodes.length,
        enteredLinks: staged.links.length,
        targetLinks: graph.links.length,
        lastAddedNodes: this.buildState.lastAddedNodes,
        lastAddedLinks: this.buildState.lastAddedLinks,
        pairedEntries: this.buildState.pairedEntryCount,
        rootPairs: this.buildState.rootPairCount,
        complete: this.buildState.complete,
      },
    };
    staged.dataSource = {
      ...staged.dataSource,
      stagedBuild: true,
      stagedBuildComplete: this.buildState.complete,
      stagedBuildNodeBatch,
    };
    return staged;
  }

  setPhysicsRules(nextRules = {}) {
    const changed = {};
    for (const [name, enabled] of Object.entries(nextRules)) {
      if (!Object.prototype.hasOwnProperty.call(engineRuleDefinitions, name)) continue;
      const next = Boolean(enabled);
      if (this.rules[name] === next) continue;
      this.rules[name] = next;
      changed[name] = next;
    }
    if (
      Object.prototype.hasOwnProperty.call(changed, "dynamicAssociationOrbit") &&
      !this.rules.dynamicAssociationOrbit
    ) {
      for (const node of this.nodes.values()) clearDynamicOrbitMetadata(node);
      this.stats.dynamicAssociationOrbits = 0;
    }
    if (Object.keys(changed).length) {
      const event = {
        type: "physics_rules_changed",
        rule: "runtime-independent-physics-switches",
        changed,
        rules: engineRuleSummary(this.rules),
      };
      this.recordEvents([event], "physics-rule-switch").catch((error) => {
        this.lastError = error.message;
        console.error("Zorg Memory 3D physics rule change recording failed", error);
      });
      broadcastGameEvents([event]);
      broadcastGameSnapshot();
      if (
        Object.prototype.hasOwnProperty.call(changed, "activeVectorFilter") ||
        Object.prototype.hasOwnProperty.call(changed, "vectorRendering") ||
        Object.prototype.hasOwnProperty.call(changed, "dynamicAssociationOrbit")
      ) {
        this.sync("physics-rule-switch").catch((error) => {
          this.lastError = error.message;
          console.error("Zorg Memory 3D physics rule resync failed", error);
        });
      }
    }
    return changed;
  }

  applyEngineConfigValues(nextConfig = {}) {
    const changed = {};
    if (nextConfig.nodeSizing && typeof nextConfig.nodeSizing === "object") {
      const current = normalizeNodeSizingConfig(this.config.nodeSizing);
      const next = normalizeNodeSizingConfig({ ...current, ...nextConfig.nodeSizing });
      for (const [key, value] of Object.entries(next)) {
        if (current[key] === value) continue;
        this.config.nodeSizing[key] = value;
        changed[`nodeSizing.${key}`] = value;
      }
    }
    if (nextConfig.historyWindow && typeof nextConfig.historyWindow === "object") {
      const current = normalizeHistoryWindowConfig(this.config.historyWindow);
      const next = normalizeHistoryWindowConfig({ ...current, ...nextConfig.historyWindow });
      for (const [key, value] of Object.entries(next)) {
        if (current[key] === value) continue;
        this.config.historyWindow[key] = value;
        changed[`historyWindow.${key}`] = value;
      }
    }
    if (nextConfig.dataBackedNodeSizing && typeof nextConfig.dataBackedNodeSizing === "object") {
      const current = normalizeDataBackedNodeSizingConfig(this.config.dataBackedNodeSizing);
      const next = normalizeDataBackedNodeSizingConfig({
        ...current,
        ...nextConfig.dataBackedNodeSizing,
      });
      for (const [key, value] of Object.entries(next)) {
        if (current[key] === value) continue;
        this.config.dataBackedNodeSizing[key] = value;
        changed[`dataBackedNodeSizing.${key}`] = value;
      }
    }
    if (nextConfig.renderSettings && typeof nextConfig.renderSettings === "object") {
      const current = normalizeRenderSettingsConfig(this.config.renderSettings);
      const next = normalizeRenderSettingsConfig({ ...current, ...nextConfig.renderSettings });
      for (const [key, value] of Object.entries(next)) {
        if (current[key] === value) continue;
        this.config.renderSettings[key] = value;
        changed[`renderSettings.${key}`] = value;
      }
    }
    if (
      Object.keys(changed).some(
        (key) => key.startsWith("historyWindow.") || key.startsWith("nodeSizing."),
      ) ||
      nextConfig.dataBackedNodeSizing
    ) {
      const current = normalizeDataBackedNodeSizingConfig(this.config.dataBackedNodeSizing);
      const next = deriveDataBackedNodeSizingConfig(
        this.config.historyWindow,
        this.config.nodeSizing,
      );
      for (const [key, value] of Object.entries(next)) {
        if (current[key] === value) continue;
        this.config.dataBackedNodeSizing[key] = value;
        changed[`dataBackedNodeSizing.${key}`] = value;
      }
    }
    return changed;
  }

  setEngineConfig(nextConfig = {}) {
    const changed = this.applyEngineConfigValues(nextConfig);
    if (Object.keys(changed).length) {
      if (
        Object.keys(changed).some(
          (key) => key.startsWith("nodeSizing.") || key.startsWith("dataBackedNodeSizing."),
        )
      ) {
        this.applyRuntimeNodeSizingToLiveGraph();
      }
      if (Object.keys(changed).some((key) => key.startsWith("renderSettings."))) {
        applyServerMaterialDescriptors(
          [...this.nodes.values()],
          [...this.links.values()],
          this.config.renderSettings,
        );
        if (this.rules.vectorCollisionBoundary || this.rules.collisionBoundary) {
          const nodeList = [...this.nodes.values()];
          const settlement = settleRuntimeCollisionBoundaries(
            nodeList,
            [...this.links.values()],
            this.config.renderSettings,
          );
          this.lastRuntimeCollisions = settlement.collisionBoundary;
          this.lastRuntimeVectorCollisions = settlement.vectorCollisionBoundary;
        }
      }
      const event = {
        type: "engine_config_changed",
        rule: "runtime-dynamic-engine-config",
        changed,
        config: engineConfigSummary(this.config),
      };
      this.recordEvents([event], "engine-config-change").catch((error) => {
        this.lastError = error.message;
        console.error("Zorg Memory 3D engine config change recording failed", error);
      });
      this.persistConfig().catch((error) => {
        this.lastError = error.message;
        console.error("Zorg Memory 3D engine config persistence failed", error);
      });
      broadcastGameEvents([event]);
      broadcastGameSnapshot();
      if (Object.keys(changed).some((key) => key.startsWith("historyWindow."))) {
        this.accumulatedNodes.clear();
        this.accumulatedLinks.clear();
        this.buildState = createEmptyBuildState();
        this.scanPage = 0;
        this.sync("history-window-change").catch((error) => {
          this.lastError = error.message;
          console.error("Zorg Memory 3D history-window resync failed", error);
        });
      }
    }
    return changed;
  }

  advanceGameFrame() {
    if (!this.running || this.nodes.size === 0) return 0;
    const nodeList = [...this.nodes.values()];
    let moved = 0;
    const ruleStats = {
      positionSanity: 0,
      damping: 0,
      attraction: 0,
      dynamicAssociationOrbit: 0,
      connectedCollisionSpring: {
        links: 0,
        springForces: 0,
        compressed: 0,
        stretched: 0,
        maxStretchBefore: 0,
        maxCompressionBefore: 0,
      },
      velocityIntegration: 0,
      vectorCollisionBoundary: {
        collisions: 0,
        adjustedNodes: 0,
        maxOverlapBefore: 0,
        maxOverlapAfter: 0,
      },
      collisionBoundary: 0,
    };

    if (this.rules.positionSanity) {
      ruleStats.positionSanity = applyPositionSanityRule(nodeList);
      moved += ruleStats.positionSanity;
    }
    if (this.rules.damping) {
      ruleStats.damping = applyVelocityDampingRule(nodeList);
    }
    if (this.rules.attraction) {
      ruleStats.attraction = applyAttractionRule(nodeList);
      moved += ruleStats.attraction;
    }
    if (this.rules.velocityIntegration) {
      ruleStats.velocityIntegration = applyVelocityIntegrationRule(nodeList);
      moved += ruleStats.velocityIntegration;
    }
    if (this.rules.dynamicAssociationOrbit) {
      ruleStats.dynamicAssociationOrbit = applyDynamicAssociationOrbitSprings(nodeList);
      moved += ruleStats.dynamicAssociationOrbit;
    }
    if (this.rules.connectedCollisionSpring) {
      ruleStats.connectedCollisionSpring = applyConnectedCollisionRadiusSpring(
        nodeList,
        [...this.links.values()],
        this.config.renderSettings,
      );
      moved += ruleStats.connectedCollisionSpring.springForces;
    }
    if (this.rules.vectorCollisionBoundary || this.rules.collisionBoundary) {
      const settlement = settleRuntimeCollisionBoundaries(
        nodeList,
        [...this.links.values()],
        this.config.renderSettings,
      );
      this.lastRuntimeCollisions = this.rules.collisionBoundary ? settlement.collisionBoundary : 0;
      this.lastRuntimeVectorCollisions = this.rules.vectorCollisionBoundary
        ? settlement.vectorCollisionBoundary
        : { collisions: 0, adjustedNodes: 0, maxOverlapBefore: 0, maxOverlapAfter: 0 };
      ruleStats.collisionBoundary = this.lastRuntimeCollisions;
      ruleStats.vectorCollisionBoundary = this.lastRuntimeVectorCollisions;
      moved += settlement.moved;
    }
    this.ruleStats = ruleStats;
    if (moved > 0) {
      this.frame += 1;
      this.tick += 1;
    }
    return moved;
  }

  async recordEvents(events, reason) {
    const limited = events.slice(0, engineEventLimit);
    this.events.push(
      ...limited.map((event) => ({
        ...event,
        reason,
        engineId,
        tick: this.tick,
        at: new Date().toISOString(),
      })),
    );
    this.events = this.events.slice(-engineEventLimit);
    for (const event of limited) {
      await pool.query(
        "insert into zorg_memory_3d_engine_events (event_type, node_id, link_key, payload) values ($1, $2, $3, $4::jsonb)",
        [
          event.type,
          event.nodeId || null,
          event.linkKey || null,
          JSON.stringify({ ...event, reason, engineId, tick: this.tick }),
        ],
      );
    }
  }

  snapshot() {
    const nodes = [...this.nodes.values()];
    const links = [...this.links.values()];
    const recentPacketEvents = this.events
      .filter((event) => event.type === "vector_data_packet")
      .slice(-snapshotPacketEventLimit);
    return {
      engine: {
        id: engineId,
        mode: "persistent-game-engine",
        running: this.running,
        syncInFlight: this.syncInFlight,
        graphRefreshInFlight: this.graphRefreshInFlight,
        tick: this.tick,
        frame: this.frame,
        pollMs: enginePollMs,
        physicsTickMs: enginePhysicsTickMs,
        lastSnapshotAt: this.lastSnapshotAt,
        lastGraphVersion: this.lastGraphVersion,
        lastError: this.lastError,
        browserRole: "thin-render-client",
        identity: this.identity,
        physicsRules: engineRuleSummary(this.rules),
        engineConfig: engineConfigSummary(this.config),
        physicsRuleStats: this.ruleStats,
        physicsSectionsIndependent: true,
        serverOwns: {
          physics: true,
          attraction: Boolean(this.rules.attraction),
          collision: Boolean(this.rules.collisionBoundary),
          vectorCollision: Boolean(this.rules.vectorCollisionBoundary),
          fixedPositions: false,
          substituteRendering: false,
          nodePositionUpdates: true,
          vectorDistance: false,
          dynamicAssociationOrbits: Boolean(this.rules.dynamicAssociationOrbit),
          connectedCollisionSpring: Boolean(this.rules.connectedCollisionSpring),
        },
        runtimeCollisions: this.lastRuntimeCollisions,
        runtimeVectorCollisions: this.lastRuntimeVectorCollisions,
        eventSummary: eventSummary(this.events),
      },
      recentPacketEvents,
      generatedAt: new Date().toISOString(),
      dataSource: {
        ...(this.dataSource || {}),
        gameEngine: true,
        reloadRequired: false,
        missedEventsAcceptable: true,
      },
      stats: this.stats,
      nodes,
      links,
    };
  }
}

function hasColumn(columns, columnName) {
  return columns.some((column) => column.column_name === columnName);
}

function firstColumn(columns, names) {
  return names.find((name) => hasColumn(columns, name));
}

function keyColumns(columns) {
  const keys = columns
    .map((column) => column.column_name)
    .filter((name) => name === "id" || name.endsWith("_key") || name.endsWith("_id"));
  return [...new Set(keys)];
}

function activeClause(columns) {
  return hasColumn(columns, "active") ? " where active is distinct from false" : "";
}

function activeRecentClause(columns, historyConfig = null) {
  const predicates = [];
  if (hasColumn(columns, "active")) predicates.push("active is distinct from false");
  const timestampColumn = firstColumn(columns, historyTimestampColumns);
  if (timestampColumn)
    predicates.push(`${quoteIdent(timestampColumn)} >= ${activeCutoffSql(historyConfig)}`);
  return predicates.length ? ` where ${predicates.join(" and ")}` : "";
}

function orderClause(columns) {
  const orderedBy = firstColumn(columns, historyTimestampColumns);
  return orderedBy ? ` order by ${quoteIdent(orderedBy)} desc nulls last` : "";
}

function scanBatchClause(scanOffset = 0) {
  return ` limit ${databaseScanBatchRows} offset ${Math.max(0, Number(scanOffset) || 0)}`;
}

async function memoryGraphSchema() {
  const result = await pool.query(`
    select c.table_name,
           t.table_type,
           c.column_name,
           c.data_type,
           c.ordinal_position
    from information_schema.columns c
    join information_schema.tables t
      on t.table_schema = c.table_schema
     and t.table_name = c.table_name
    where c.table_schema = 'public'
      and t.table_type in ('BASE TABLE', 'VIEW')
      and (c.table_name like 'memory\\_%' escape '\\' or c.table_name like 'zorg\\_%' escape '\\')
      and c.table_name not like 'zorg\\_memory\\_3d\\_%' escape '\\'
    order by c.table_name, c.ordinal_position
  `);
  const tables = new Map();
  for (const row of result.rows) {
    if (!tables.has(row.table_name))
      tables.set(row.table_name, {
        tableName: row.table_name,
        tableType: row.table_type,
        columns: [],
      });
    tables.get(row.table_name).columns.push(row);
  }
  return [...tables.values()];
}

function inferNodeTable(table) {
  const keys = keyColumns(table.columns);
  if (keys.length === 0) return null;

  const labelColumn = firstColumn(table.columns, [
    "display_name",
    "canonical_name",
    "name",
    "title",
    "rule_title",
    "description",
    "fact_text",
    "directive_text",
    "memory_key",
    "memory_value",
    "query_text",
    "note_text",
    "content_text",
    "candidate_text",
    "summary",
    "detail_text",
    "procedure_text",
    "instruction",
    "result_text",
    "error_text",
  ]);
  const typeColumn = firstColumn(table.columns, [
    "node_type",
    "entity_type",
    "fact_type",
    "rule_type",
    "note_type",
    "memory_category",
    "category_key",
    "status",
    "action_kind",
    "unit_kind",
    "candidate_type",
    "source_type",
  ]);
  const scoreColumn = firstColumn(table.columns, [
    "salience",
    "activation_score",
    "confidence",
    "weight",
    "priority",
  ]);
  const timestampColumn = firstColumn(table.columns, [
    "updated_at",
    "created_at",
    "logged_at",
    "observed_at",
    "message_timestamp",
    "last_seen_at",
    "last_recalled_at",
    "available_at",
    "started_at",
    "completed_at",
    "finished_at",
  ]);

  return {
    tableName: table.tableName,
    keyColumn: keys[0],
    labelColumn,
    typeColumn,
    scoreColumn,
    timestampColumn,
  };
}

function inferRelationshipTable(table) {
  const c = table.columns;
  const semantic = ["subject_type", "subject_key", "object_type", "object_key"].every((column) =>
    hasColumn(c, column),
  );
  if (semantic) {
    return {
      tableName: table.tableName,
      sourceTypeColumn: "subject_type",
      sourceKeyColumn: "subject_key",
      targetTypeColumn: "object_type",
      targetKeyColumn: "object_key",
      relationColumn: firstColumn(c, ["relation", "relation_type", "link_type"]) || null,
      weightColumn: firstColumn(c, ["weight", "activation_score", "confidence"]) || null,
      timestampColumn:
        firstColumn(c, [
          "updated_at",
          "created_at",
          "last_recalled_at",
          "observed_at",
          "last_seen_at",
        ]) || null,
    };
  }

  const sourceKeyColumn = firstColumn(c, [
    "source_entity_key",
    "source_key",
    "source_id",
    "source_memory_key",
    "code_unit_key",
  ]);
  const targetKeyColumn = firstColumn(c, [
    "target_entity_key",
    "target_key",
    "target_id",
    "target_memory_key",
  ]);
  if (sourceKeyColumn && targetKeyColumn) {
    return {
      tableName: table.tableName,
      sourceTypeColumn: null,
      sourceKeyColumn,
      targetTypeColumn: null,
      targetKeyColumn,
      relationColumn: firstColumn(c, ["relation_type", "relation", "link_type"]) || null,
      weightColumn: firstColumn(c, ["weight", "confidence", "activation_score"]) || null,
      timestampColumn:
        firstColumn(c, [
          "updated_at",
          "created_at",
          "observed_at",
          "last_seen_at",
          "last_recalled_at",
        ]) || null,
    };
  }

  return null;
}

function inferForeignKeyLinks(table) {
  const links = [];
  const columns = table.columns.map((column) => column.column_name);
  const localKey = firstColumn(table.columns, [
    "entity_key",
    "project_key",
    "host_key",
    "service_key",
    "task_key",
    "rule_key",
    "memory_key",
    "node_key",
    "unit_key",
    "id",
  ]);
  if (!localKey) return links;

  for (const target of [
    ["project_key", "project"],
    ["host_key", "host"],
    ["service_key", "service"],
    ["entity_key", "entity"],
    ["source_key", "source"],
    ["target_key", "target"],
    ["category_key", "category"],
    ["request_id", "request"],
    ["task_key", "task"],
    ["rule_key", "rule"],
    ["memory_key", "memory"],
  ]) {
    const [columnName, targetType] = target;
    if (columnName === localKey || !columns.includes(columnName)) continue;
    links.push({
      tableName: table.tableName,
      localKeyColumn: localKey,
      targetKeyColumn: columnName,
      targetType,
    });
  }
  return links;
}

async function tableFactualTimestamp(table, historyConfig = null) {
  const timestampColumn = firstColumn(table.columns, historyTimestampColumns);
  if (!timestampColumn) return null;
  try {
    const result = await pool.query(
      `select max(${quoteIdent(timestampColumn)})::text as last_seen from ${quoteIdent(table.tableName)} ${activeRecentClause(table.columns, historyConfig)}`,
    );
    return result.rows[0]?.last_seen || null;
  } catch (error) {
    console.warn(
      `Could not derive table timestamp for ${table.tableName}.${timestampColumn}: ${error.message}`,
    );
    return null;
  }
}

async function tableActiveRowCount(table, historyConfig = null) {
  try {
    const result = await pool.query(
      `select count(*)::int as row_count from ${quoteIdent(table.tableName)} ${activeRecentClause(table.columns, historyConfig)}`,
    );
    return Number(result.rows[0]?.row_count || 0);
  } catch (error) {
    console.warn(`Could not count active rows for ${table.tableName}: ${error.message}`);
    return 0;
  }
}

function historyTimestampColumn(columns) {
  return firstColumn(columns, historyTimestampColumns);
}

function hasBooleanActiveColumn(columns) {
  return columns.some(
    (column) => column.column_name === "active" && column.data_type === "boolean",
  );
}

function estimatedAverageRowBytes(tableName, tableType) {
  if (tableType !== "BASE TABLE") return Promise.resolve(512);
  return pool
    .query(
      `
      select greatest(
               96,
               least(
                 16384,
                 coalesce((pg_total_relation_size($1::regclass)::numeric / nullif(c.reltuples, 0)), 512)
               )
             )::numeric as avg_bytes
      from pg_class c
      where c.oid = $1::regclass
    `,
      [`public.${tableName}`],
    )
    .then((result) => Number(result.rows[0]?.avg_bytes || 512))
    .catch(() => 512);
}

async function countedRows(table, historyConfig = null) {
  try {
    const result = await pool.query(
      `select count(*)::bigint as row_count from ${quoteIdent(table.tableName)} ${activeRecentClause(table.columns, historyConfig)}`,
    );
    return Number(result.rows[0]?.row_count || 0);
  } catch (error) {
    console.warn(`Could not estimate history rows for ${table.tableName}: ${error.message}`);
    return 0;
  }
}

async function countedRowsWithBytes(table, historyConfig = null) {
  const [rows, averageBytes] = await Promise.all([
    countedRows(table, historyConfig),
    estimatedAverageRowBytes(table.tableName, table.tableType),
  ]);
  return {
    rows,
    bytes: Math.round(rows * averageBytes),
    averageBytes,
  };
}

async function ensureHistoryEstimateIndexes() {
  let created = 0;
  let skipped = 0;
  try {
    const schema = await memoryGraphSchema();
    for (const table of schema) {
      if (created >= historyEstimateIndexLimit) break;
      if (table.tableType !== "BASE TABLE") {
        skipped += 1;
        continue;
      }
      const timestampColumn = historyTimestampColumn(table.columns);
      if (!timestampColumn) {
        skipped += 1;
        continue;
      }
      const indexName = `z3d_hist_${stableHash(`${table.tableName}:${timestampColumn}`)}`;
      const activeWhere = hasBooleanActiveColumn(table.columns)
        ? " where active is distinct from false"
        : "";
      try {
        await pool.query(
          `create index if not exists ${quoteIdent(indexName)} on ${quoteIdent(table.tableName)} (${quoteIdent(timestampColumn)} desc)${activeWhere}`,
        );
        created += 1;
      } catch (error) {
        skipped += 1;
        console.warn(
          `Could not create history estimate index for ${table.tableName}.${timestampColumn}: ${error.message}`,
        );
      }
    }
    return { created, skipped };
  } catch (error) {
    console.warn(`Could not prepare history estimate indexes: ${error.message}`);
    return { created, skipped, error: error.message };
  }
}

async function loadDynamicDiscoveredGraph(scanOffset = 0, historyConfig = null) {
  const schema = await memoryGraphSchema();
  const nodes = [];
  const links = [];
  const discovered = {
    tables: schema.length,
    nodeTables: 0,
    relationshipTables: 0,
    inferredLinkTables: 0,
  };
  const graphFingerprintParts = [];

  for (const table of schema) {
    const columnNames = table.columns.map((column) => column.column_name).join(",");
    const lastSeen = await tableFactualTimestamp(table, historyConfig);
    const dataRows = await tableActiveRowCount(table, historyConfig);
    const tablePayload = {
      tableName: table.tableName,
      tableType: table.tableType,
      columns: table.columns.map((column) => column.column_name),
      dataRows,
    };
    graphFingerprintParts.push(`${table.tableName}:${columnNames}`);
    nodes.push({
      id: `table:${table.tableName}`,
      group: "schema",
      label: table.tableName,
      val: Math.min(10, Math.max(2, table.columns.length / 2)),
      tableType: table.tableType,
      columns: table.columns.map((column) => column.column_name),
      dataRows,
      dataByteSize: Buffer.byteLength(sortedStableStringify(tablePayload), "utf8"),
      lastSeen,
    });
    links.push({
      source: "zorg-memorydb",
      target: `table:${table.tableName}`,
      type: "DB table",
      value: 0.75,
      lastSeen,
    });
  }

  for (const table of schema) {
    const nodeConfig = inferNodeTable(table);
    if (!nodeConfig) continue;
    discovered.nodeTables += 1;
    const selectParts = [
      `${quoteIdent(nodeConfig.keyColumn)}::text as key_value`,
      nodeConfig.labelColumn
        ? `${quoteIdent(nodeConfig.labelColumn)}::text as label_value`
        : "null::text as label_value",
      nodeConfig.typeColumn
        ? `${quoteIdent(nodeConfig.typeColumn)}::text as type_value`
        : "null::text as type_value",
      nodeConfig.scoreColumn
        ? `${quoteIdent(nodeConfig.scoreColumn)}::text as score_value`
        : "null::text as score_value",
      nodeConfig.timestampColumn
        ? `${quoteIdent(nodeConfig.timestampColumn)}::text as last_seen`
        : "null::text as last_seen",
    ];
    const result = await pool.query(`
      select ${selectParts.join(", ")}
      from ${quoteIdent(table.tableName)}
      ${activeRecentClause(table.columns, historyConfig)}
      ${orderClause(table.columns)}
      ${scanBatchClause(scanOffset)}
    `);
    for (const row of result.rows) {
      const id = `${table.tableName}:${row.key_value}`;
      const score = Number(row.score_value);
      nodes.push({
        id,
        group: row.type_value || table.tableName.replace(/^(memory_|zorg_)/, ""),
        label: row.label_value || row.key_value,
        val: Number.isFinite(score) ? Math.max(1, Math.min(9, score * 4)) : 2,
        sourceTable: table.tableName,
        sourceKey: row.key_value,
        dataRows: 1,
        dataByteSize: Buffer.byteLength(sortedStableStringify(row), "utf8"),
        lastSeen: row.last_seen,
      });
      links.push({
        source: `table:${table.tableName}`,
        target: id,
        type: "row",
        value: 0.9,
        lastSeen: row.last_seen,
      });
    }
  }

  for (const table of schema) {
    const relConfig = inferRelationshipTable(table);
    if (!relConfig) continue;
    discovered.relationshipTables += 1;
    const selectParts = [
      relConfig.sourceTypeColumn
        ? `${quoteIdent(relConfig.sourceTypeColumn)}::text as source_type`
        : `'${table.tableName.replace(/^(memory_|zorg_)/, "")}'::text as source_type`,
      `${quoteIdent(relConfig.sourceKeyColumn)}::text as source_key`,
      relConfig.targetTypeColumn
        ? `${quoteIdent(relConfig.targetTypeColumn)}::text as target_type`
        : `'${table.tableName.replace(/^(memory_|zorg_)/, "")}'::text as target_type`,
      `${quoteIdent(relConfig.targetKeyColumn)}::text as target_key`,
      relConfig.relationColumn
        ? `${quoteIdent(relConfig.relationColumn)}::text as relation_value`
        : "'related'::text as relation_value",
      relConfig.weightColumn
        ? `${quoteIdent(relConfig.weightColumn)}::text as weight_value`
        : "null::text as weight_value",
      relConfig.timestampColumn
        ? `${quoteIdent(relConfig.timestampColumn)}::text as last_seen`
        : "null::text as last_seen",
    ];
    const result = await pool.query(`
      select ${selectParts.join(", ")}
      from ${quoteIdent(table.tableName)}
      ${activeRecentClause(table.columns, historyConfig)}
      ${orderClause(table.columns)}
      ${scanBatchClause(scanOffset)}
    `);
    for (const row of result.rows) {
      const source = `${row.source_type || "source"}:${row.source_key}`;
      const target = `${row.target_type || "target"}:${row.target_key}`;
      nodes.push({
        id: source,
        group: row.source_type || "dynamic",
        label: row.source_key,
        val: 1.5,
        sourceTable: table.tableName,
        dataRows: 1,
        dataByteSize: Buffer.byteLength(sortedStableStringify(row), "utf8"),
        lastSeen: row.last_seen,
      });
      nodes.push({
        id: target,
        group: row.target_type || "dynamic",
        label: row.target_key,
        val: 1.5,
        sourceTable: table.tableName,
        dataRows: 1,
        dataByteSize: Buffer.byteLength(sortedStableStringify(row), "utf8"),
        lastSeen: row.last_seen,
      });
      links.push({
        source,
        target,
        type: row.relation_value || table.tableName,
        value: Number(row.weight_value) || 1.1,
        sourceTable: table.tableName,
        lastSeen: row.last_seen,
      });
    }
  }

  for (const table of schema) {
    const inferredLinks = inferForeignKeyLinks(table);
    discovered.inferredLinkTables += inferredLinks.length;
    for (const config of inferredLinks) {
      const result = await pool.query(`
        select ${quoteIdent(config.localKeyColumn)}::text as local_key,
               ${quoteIdent(config.targetKeyColumn)}::text as target_key
        from ${quoteIdent(table.tableName)}
        ${activeRecentClause(table.columns, historyConfig)}
        ${orderClause(table.columns)}
        ${scanBatchClause(scanOffset)}
      `);
      for (const row of result.rows) {
        if (!row.local_key || !row.target_key) continue;
        links.push({
          source: `${table.tableName}:${row.local_key}`,
          target: `${config.targetType}:${row.target_key}`,
          type: config.targetKeyColumn,
          value: 0.8,
          sourceTable: table.tableName,
        });
      }
    }
  }

  return {
    nodes,
    links,
    discovered,
    schemaFingerprint: stableHash(graphFingerprintParts.join("|")),
  };
}

async function tableExists(tableName) {
  const result = await pool.query("select to_regclass($1) as table_name", [`public.${tableName}`]);
  return Boolean(result.rows[0]?.table_name);
}

async function tableColumns(tableName) {
  if (!(await tableExists(tableName))) return new Set();
  const result = await pool.query(
    `
      select column_name
      from information_schema.columns
      where table_schema = 'public' and table_name = $1
    `,
    [tableName],
  );
  return new Set(result.rows.map((row) => row.column_name));
}

async function optionalQuery(tableName, sql, params = []) {
  if (!(await tableExists(tableName))) return { rows: [], rowCount: 0 };
  return pool.query(sql, params);
}

async function loadMemoryBrainIdentity() {
  const configuredName = textLabel(process.env.ZORG_MEMORY_3D_IDENTITY_NAME);
  if (configuredName) {
    return {
      name: configuredName,
      sourceTable: "environment",
      statusLabel: "Memory Brain Status",
      databaseLabel: `${configuredName} Memory DB`,
      browserTitle: `${configuredName} Memory Brain 3D`,
    };
  }

  const fallback = {
    name: "Memory",
    sourceTable: null,
    statusLabel: "Memory Brain Status",
    databaseLabel: "Memory DB",
    browserTitle: "Memory Brain 3D",
  };
  try {
    const mdIdentity = await optionalQuery(
      "md_identity",
      `
      select regexp_replace(line_text, '^[-*]?[[:space:]]*\\*\\*Name:\\*\\*[[:space:]]*', '') as identity_name
      from md_identity
      where line_text ilike '%Name:%'
      order by line_no
      limit 1
    `,
    );
    const mdName = textLabel(mdIdentity.rows[0]?.identity_name);
    if (mdName) {
      return {
        name: mdName,
        sourceTable: "md_identity",
        statusLabel: "Memory Brain Status",
        databaseLabel: `${mdName} Memory DB`,
        browserTitle: `${mdName} Memory Brain 3D`,
      };
    }

    const project = await optionalQuery(
      "memory_projects",
      `
      select name
      from memory_projects
      where project_key in ('vorg-system', 'vorg-memory-backend')
      order by case project_key when 'vorg-system' then 0 else 1 end
      limit 1
    `,
    );
    const projectName = textLabel(project.rows[0]?.name);
    if (projectName) {
      return {
        name: projectName,
        sourceTable: "memory_projects",
        statusLabel: "Memory Brain Status",
        databaseLabel: `${projectName} Memory DB`,
        browserTitle: `${projectName} Memory Brain 3D`,
      };
    }

    const entity = await optionalQuery(
      "memory_entities",
      `
      select canonical_name
      from memory_entities
      where entity_key in ('project:vorg-system', 'host:host-10-7-69-44')
      order by case entity_key when 'project:vorg-system' then 0 else 1 end
      limit 1
    `,
    );
    const entityName = textLabel(entity.rows[0]?.canonical_name);
    if (entityName) {
      return {
        name: entityName,
        sourceTable: "memory_entities",
        statusLabel: "Memory Brain Status",
        databaseLabel: `${entityName} Memory DB`,
        browserTitle: `${entityName} Memory Brain 3D`,
      };
    }
  } catch (error) {
    return { ...fallback, error: error.message };
  }
  return fallback;
}

async function loadSemanticNodes(scanOffset = 0, historyConfig = null) {
  return optionalQuery(
    "memory_semantic_nodes",
    `
    select node_key, node_type, canonical_label, confidence, updated_at
    from memory_semantic_nodes
    where active is distinct from false
      and updated_at >= ${activeCutoffSql(historyConfig)}
    order by updated_at desc nulls last, created_at desc nulls last
    ${scanBatchClause(scanOffset)}
  `,
  );
}

async function loadRecallHints(scanOffset = 0, historyConfig = null) {
  return optionalQuery(
    "memory_recall_hints",
    `
    select source_type,
           source_key,
           hint_kind,
           hint_text,
           weight,
           coalesce(updated_at, created_at) as updated_at
    from memory_recall_hints
    where active is distinct from false
      and coalesce(updated_at, created_at) >= ${activeCutoffSql(historyConfig)}
    order by coalesce(updated_at, created_at) desc
    ${scanBatchClause(scanOffset)}
  `,
  );
}

async function loadQueryObservations(scanOffset = 0, historyConfig = null) {
  return optionalQuery(
    "memory_query_observations",
    `
    select query_text,
           coalesce(query_intent, 'recall') as query_intent,
           source_type,
           coalesce(source_key, query_text) as source_key,
           rank_seen,
           greatest(1, coalesce(usefulness_score, 1))::numeric as usefulness_score,
           observed_at
    from memory_query_observations
    where observed_at >= ${activeCutoffSql(historyConfig)}
    order by observed_at desc
    ${scanBatchClause(scanOffset)}
  `,
  );
}

async function loadLogicRules(scanOffset = 0, historyConfig = null) {
  return optionalQuery(
    "memory_directives",
    `
    select id::text as rule_key,
           directive_text as title,
           coalesce(category, 'directive') as rule_type,
           priority,
           updated_at
    from memory_directives
    where active is distinct from false
      and updated_at >= ${activeCutoffSql(historyConfig)}
    order by case priority when 'critical' then 0 when 'high' then 1 else 2 end,
             updated_at desc nulls last,
             created_at desc nulls last
    ${scanBatchClause(scanOffset)}
  `,
  );
}

async function countTable(tableName, whereClause = "") {
  if (!(await tableExists(tableName))) return 0;
  const result = await pool.query(`select count(*)::int as count from ${tableName}${whereClause}`);
  return result.rows[0]?.count || 0;
}

async function loadTableCounts() {
  return {
    rows: [
      { label: "memories", count: await countTable("zorg_memory") },
      {
        label: "semantic edges",
        count: await countTable("memory_semantic_edges", " where active is distinct from false"),
      },
      { label: "recall hints", count: await countTable("memory_recall_hints") },
      {
        label: "query observations",
        count: await countTable("memory_query_observations"),
      },
      {
        label: "directives",
        count: await countTable("memory_directives", " where active is distinct from false"),
      },
      {
        label: "scheduled jobs",
        count: await countTable("memorydb_llm_jobs", " where enabled is distinct from false"),
      },
    ],
  };
}

async function loadGraph(queryText = "", scanOffset = 0, historyConfig = null) {
  const memoryIdentity = gameEngine?.identity || (await loadMemoryBrainIdentity());
  const historyWindow = currentHistoryWindowConfig(historyConfig);
  const [
    semanticEdges,
    semanticNodes,
    recallHints,
    queryObservations,
    neuralResults,
    logicRules,
    dynamicWeights,
    relationships,
    jobs,
    timings,
    tableCounts,
  ] = await Promise.all([
    optionalQuery(
      "memory_semantic_edges",
      `
        select subject_type, subject_key, relation, object_type, object_key, weight, weight_basis, updated_at
        from memory_semantic_edges
        where active is distinct from false
          and updated_at >= ${activeCutoffSql(historyWindow)}
        order by updated_at desc nulls last, created_at desc nulls last
      `,
    ),
    loadSemanticNodes(scanOffset, historyWindow),
    loadRecallHints(scanOffset, historyWindow),
    loadQueryObservations(scanOffset, historyWindow),
    optionalQuery(
      "memory_neural_query_results",
      `
        select query_hash, query_text, source_type, source_key, result_rank, total_score, last_seen_at
        from memory_neural_query_results
        where active_for_latest is distinct from false
          and last_seen_at >= ${activeCutoffSql(historyWindow)}
        order by last_seen_at desc nulls last, observed_at desc nulls last
        ${scanBatchClause(scanOffset)}
    `,
    ),
    loadLogicRules(scanOffset, historyWindow),
    { rows: [], rowCount: 0 },
    optionalQuery(
      "memory_relationships",
      `
        select subject_type, subject_key, relation, object_type, object_key, created_at
        from memory_relationships
        where created_at >= ${activeCutoffSql(historyWindow)}
        order by created_at desc
        ${scanBatchClause(scanOffset)}
      `,
    ),
    optionalQuery(
      "memorydb_llm_outbox",
      `
        select job_key, status, available_at as due_at, started_at, completed_at as finished_at, attempts, updated_at
        from memorydb_llm_outbox
        where updated_at >= ${activeCutoffSql(historyWindow)}
        order by updated_at desc nulls last, created_at desc
        ${scanBatchClause(scanOffset)}
      `,
    ),
    optionalQuery(
      "memory_recall_log",
      `
        select 'recall' as observation_kind,
               coalesce(category_key, session_key, normalized_query, 'memory_recall_log') as source_key,
               latency_ms as duration_ms,
               null::integer as queue_wait_ms,
               cardinality(selected_keys) as processed_count,
               cardinality(retrieved_keys) as backlog_count,
               created_at as observed_at
        from memory_recall_log
        where latency_ms is not null
          and created_at >= ${activeCutoffSql(historyWindow)}
        order by created_at desc
        ${scanBatchClause(scanOffset)}
      `,
    ),
    loadTableCounts(),
  ]);
  const dynamicGraph = await loadDynamicDiscoveredGraph(scanOffset, historyWindow);

  const nodes = new Map();
  const links = [];
  addNode(
    nodes,
    "zorg-memorydb",
    "core",
    memoryIdentity.databaseLabel || `${memoryIdentity.name || "Memory"} Memory DB`,
    { val: 10 },
  );
  addNode(nodes, "live-activity", "activity", "Live activity", { val: 7 });
  addNode(nodes, "recall-engine", "query", "Recall engine", { val: 8 });
  addLink(links, "zorg-memorydb", "live-activity", "memory activity subsystem", 3.5, {
    sourceTable: "zorg_memory_3d_engine",
  });
  addLink(links, "zorg-memorydb", "recall-engine", "neural recall subsystem", 4.5, {
    sourceTable: "zorg_memory_3d_engine",
  });

  for (const row of semanticNodes.rows) {
    addNode(
      nodes,
      `node:${row.node_key}`,
      row.node_type || "semantic",
      row.canonical_label || row.node_key,
      {
        confidence: row.confidence,
        lastSeen: row.updated_at,
      },
    );
    addLink(links, "zorg-memorydb", `node:${row.node_key}`, "semantic node", row.confidence || 1);
  }

  for (const row of semanticEdges.rows) {
    const source = `${row.subject_type || "source"}:${row.subject_key}`;
    const target = `${row.object_type || "target"}:${row.object_key}`;
    addNode(nodes, source, row.subject_type || "semantic", row.subject_key, {
      lastSeen: row.updated_at,
    });
    addNode(nodes, target, row.object_type || "semantic", row.object_key, {
      lastSeen: row.updated_at,
    });
    addLink(links, source, target, row.relation || "semantic edge", row.weight || 1, {
      reason: row.weight_basis,
      lastSeen: row.updated_at,
    });
  }

  for (const row of relationships.rows) {
    const source = `${row.subject_type || "subject"}:${row.subject_key}`;
    const target = `${row.object_type || "object"}:${row.object_key}`;
    addNode(nodes, source, row.subject_type || "relationship", row.subject_key, {
      lastSeen: row.created_at,
    });
    addNode(nodes, target, row.object_type || "relationship", row.object_key, {
      lastSeen: row.created_at,
    });
    addLink(links, source, target, row.relation || "relationship", 1.2, {
      lastSeen: row.created_at,
    });
  }

  for (const row of recallHints.rows) {
    const source = `${row.source_type || "hint-source"}:${row.source_key}`;
    const hintId = `hint:${row.source_key}:${row.hint_kind || "hint"}`;
    addNode(nodes, source, row.source_type || "memory", row.source_key, {
      lastSeen: row.updated_at,
    });
    addNode(nodes, hintId, "hint", row.hint_text || row.hint_kind, {
      val: 2,
      lastSeen: row.updated_at,
    });
    addLink(links, "recall-engine", hintId, "recall hint", row.weight || 1);
    addLink(links, hintId, source, row.hint_kind || "points to", row.weight || 1, {
      lastSeen: row.updated_at,
    });
  }

  for (const row of queryObservations.rows) {
    const queryId = `query:${Buffer.from(row.query_text || "")
      .toString("base64")
      .slice(0, 36)}`;
    const source = `${row.source_type || "result"}:${row.source_key}`;
    addNode(nodes, queryId, "query", row.query_text, {
      val: 3,
      intent: row.query_intent,
      lastSeen: row.observed_at,
    });
    addNode(nodes, source, row.source_type || "result", row.source_key, {
      lastSeen: row.observed_at,
    });
    addLink(links, "recall-engine", queryId, "observed query", 2, { lastSeen: row.observed_at });
    addLink(links, queryId, source, `rank ${row.rank_seen ?? "?"}`, row.usefulness_score || 1, {
      lastSeen: row.observed_at,
    });
  }

  for (const row of neuralResults.rows) {
    const queryId = `neural:${row.query_hash}`;
    const source = `${row.source_type || "result"}:${row.source_key}`;
    addNode(nodes, queryId, "neural", row.query_text, { val: 4, lastSeen: row.last_seen_at });
    addNode(nodes, source, row.source_type || "result", row.source_key, {
      lastSeen: row.last_seen_at,
    });
    addLink(links, queryId, source, `ANN rank ${row.result_rank ?? "?"}`, row.total_score || 1, {
      lastSeen: row.last_seen_at,
    });
    addLink(links, "recall-engine", queryId, "neural result", 2.5);
  }

  for (const row of logicRules.rows) {
    const id = `rule:${row.rule_key}`;
    addNode(nodes, id, "rule", row.title || row.rule_key, {
      val: row.priority === "critical" ? 7 : 4,
      priority: row.priority,
      ruleType: row.rule_type,
      lastSeen: row.updated_at,
    });
    addLink(links, "zorg-memorydb", id, "governs", row.priority === "critical" ? 4 : 2);
  }

  for (const row of dynamicWeights.rows) {
    const id = `rule:${row.rule_key}`;
    addNode(nodes, id, "rule", row.rule_key, { lastSeen: row.last_recalled_at });
    addLink(links, "recall-engine", id, "dynamic weight", row.dynamic_weight || 1, {
      useCount: row.use_count,
      lastSeen: row.last_recalled_at,
    });
  }

  for (const row of jobs.rows) {
    const id = `job:${row.job_key}:${row.status}`;
    addNode(nodes, id, "job", `${row.job_key} (${row.status})`, {
      val: 3,
      status: row.status,
      lastSeen: row.updated_at,
    });
    addLink(links, "live-activity", id, "queued work", row.status === "failed" ? 4 : 1.5, {
      lastSeen: row.updated_at,
    });
  }

  for (const row of timings.rows) {
    const id = `timing:${row.observation_kind}:${row.source_key}`;
    addNode(nodes, id, "timing", `${row.observation_kind}: ${row.source_key}`, {
      val: Math.max(1, Math.min(8, Number(row.duration_ms || 0) / 200)),
      durationMs: row.duration_ms,
      queueWaitMs: row.queue_wait_ms,
      backlog: row.backlog_count,
      lastSeen: row.observed_at,
    });
    addLink(links, "live-activity", id, "timing", Math.max(1, Number(row.duration_ms || 1) / 100), {
      lastSeen: row.observed_at,
    });
  }

  for (const row of dynamicGraph.nodes) {
    addNode(nodes, row.id, row.group || "dynamic", row.label || row.id, row);
  }
  for (const row of dynamicGraph.links) {
    addLink(links, row.source, row.target, row.type || "dynamic", row.value || 1, row);
  }

  const latestLinkSeenForEndpoint = (endpointIdToMatch) => {
    let best = null;
    for (const link of links) {
      if (
        endpointId(link.source) !== endpointIdToMatch &&
        endpointId(link.target) !== endpointIdToMatch
      )
        continue;
      const timestamp = parseTimestampMs(link.lastSeen);
      if (!Number.isFinite(timestamp)) continue;
      best = best === null ? timestamp : Math.max(best, timestamp);
    }
    return best === null ? null : new Date(best).toISOString();
  };
  const liveActivitySeen = latestLinkSeenForEndpoint("live-activity");
  if (liveActivitySeen) {
    addLink(links, "zorg-memorydb", "live-activity", "memory activity subsystem", 3.5, {
      sourceTable: "zorg_memory_3d_engine",
      lastSeen: liveActivitySeen,
    });
  }
  const recallEngineSeen = latestLinkSeenForEndpoint("recall-engine");
  if (recallEngineSeen) {
    addLink(links, "zorg-memorydb", "recall-engine", "neural recall subsystem", 4.5, {
      sourceTable: "zorg_memory_3d_engine",
      lastSeen: recallEngineSeen,
    });
  }

  let highlight = null;
  if (queryText.trim()) {
    const recallFunction = await pool.query(
      "select to_regprocedure('public.zorg_recall_context(text, integer)') as recall_function",
    );
    const recall = recallFunction.rows[0]?.recall_function
      ? await pool.query("select * from zorg_recall_context($1, 18)", [queryText.trim()])
      : { rows: [], rowCount: 0 };
    const queryId = `manual:${Date.now()}`;
    addNode(nodes, queryId, "manual-query", queryText.trim(), {
      val: 8,
      lastSeen: new Date().toISOString(),
    });
    addLink(links, "recall-engine", queryId, "manual recall", 5);
    recall.rows.forEach((row, index) => {
      const key =
        row.source_id || row.id || row.key || row.path || JSON.stringify(row).slice(0, 40);
      const type = row.source_type || row.table_name || "recall-result";
      const id = `${type}:${key}`;
      addNode(nodes, id, type, row.content || row.memory_key || key, {
        val: Math.max(2, 8 - index * 0.25),
      });
      addLink(links, queryId, id, `recall #${index + 1}`, Math.max(1, 10 - index));
    });
    highlight = { query: queryText.trim(), resultCount: recall.rowCount };
  }

  const rules = gameEngine?.rules || createEngineRuleState();
  ensureLinkEndpointNodes(nodes, links);
  enrichGraphNodeProperties(nodes, links);
  const activeLinks = rules.activeVectorFilter
    ? filterGraphToActiveWindow(nodes, links, historyWindow)
    : links;
  const visibleLinks = rules.vectorRendering ? dedupeGraphLinks(activeLinks) : [];
  enrichGraphNodeProperties(nodes, visibleLinks);
  enrichGraphLinkProperties(visibleLinks, nodes);

  const graphVersion = stableHash(
    JSON.stringify({
      generatedFrom: "db-only",
      schemaFingerprint: dynamicGraph.schemaFingerprint,
      nodes: nodes.size,
      links: visibleLinks.length,
      activeWindowMs: currentActiveWindowMs(historyWindow),
      activeVectorFilter: Boolean(rules.activeVectorFilter),
      vectorRendering: Boolean(rules.vectorRendering),
      nodeState: [...nodes.values()]
        .map(
          (node) =>
            `${node.id}:${node.degree || 0}:${node.lastSeen || ""}:${node.visualSignature || ""}:${Number(node.val || 0).toFixed(3)}`,
        )
        .sort(),
      linkIds: visibleLinks
        .map(
          (link) =>
            `${link.source}->${link.target}:${link.type}:${link.value}:${Number(link.thickness || 0).toFixed(3)}`,
        )
        .sort(),
    }),
  );

  return {
    generatedAt: new Date().toISOString(),
    graphVersion,
    dataSource: {
      mode: "db-only",
      database: loadDbConfig().database || "connectionString",
      host: loadDbConfig().host || "DATABASE_URL",
      mappingSoftwareDataUsed: false,
      dynamicSchemaDiscovery: true,
      schemaFingerprint: dynamicGraph.schemaFingerprint,
      activeWindowHours: Number((currentActiveWindowMs(historyWindow) / 3_600_000).toFixed(3)),
      activeWindowDays: historyWindow.days,
      activeCutoff: new Date(activeCutoffMs(historyWindow)).toISOString(),
      activeVectorFilter: Boolean(rules.activeVectorFilter),
      vectorRendering: Boolean(rules.vectorRendering),
    },
    stats: {
      ...Object.fromEntries(tableCounts.rows.map((row) => [row.label, row.count])),
      "auto tables": dynamicGraph.discovered.tables,
      "auto node tables": dynamicGraph.discovered.nodeTables,
      "auto relationship tables": dynamicGraph.discovered.relationshipTables,
    },
    highlight,
    nodes: [...nodes.values()],
    links: visibleLinks,
  };
}

const historyEstimateCache = new Map();
const historyEstimateCacheMs = 12_000;

function graphDataByteTotal(nodes = [], links = []) {
  const nodeBytes = nodes.reduce(
    (total, node) => total + Math.max(0, Number(node.dataByteSize || estimateNodeDataBytes(node))),
    0,
  );
  const vectorBytes = links.reduce(
    (total, link) => total + Math.max(0, Number(link.dataByteSize || linkPacketByteSize(link))),
    0,
  );
  return {
    nodeBytes,
    vectorBytes,
    totalBytes: nodeBytes + vectorBytes,
  };
}

async function estimateHistoryWindowLoad(daysInput) {
  const historyWindow = normalizeHistoryWindowConfig({ days: daysInput });
  const cacheKey = String(historyWindow.days);
  const cached = historyEstimateCache.get(cacheKey);
  if (cached && Date.now() - cached.createdAt < historyEstimateCacheMs) return cached.value;

  const schema = await memoryGraphSchema();
  const tableByName = new Map(schema.map((table) => [table.tableName, table]));
  const sourceDetails = [];
  let estimatedNodes = 3; // core database, live activity, recall engine
  let estimatedVectors = 2; // core subsystem vectors
  let estimatedBytes = 0;

  const addEstimate = (source, rows, nodeFactor, vectorFactor, bytes) => {
    const rowCount = Math.max(0, Number(rows) || 0);
    const nodeCount = rowCount * nodeFactor;
    const vectorCount = rowCount * vectorFactor;
    estimatedNodes += nodeCount;
    estimatedVectors += vectorCount;
    estimatedBytes += Math.max(0, Number(bytes) || 0);
    sourceDetails.push({
      source,
      rows: rowCount,
      estimatedNodes: nodeCount,
      estimatedVectors: vectorCount,
      estimatedBytes: Math.max(0, Number(bytes) || 0),
    });
  };

  const countKnown = async (tableName, whereClause, nodeFactor, vectorFactor) => {
    if (!(await tableExists(tableName))) return;
    try {
      const result = await pool.query(
        `select count(*)::bigint as row_count from ${quoteIdent(tableName)} ${whereClause}`,
      );
      const rows = Number(result.rows[0]?.row_count || 0);
      const averageBytes = await estimatedAverageRowBytes(tableName, "BASE TABLE");
      addEstimate(tableName, rows, nodeFactor, vectorFactor, rows * averageBytes);
    } catch (error) {
      sourceDetails.push({ source: tableName, error: error.message });
    }
  };

  await Promise.all([
    countKnown(
      "memory_semantic_nodes",
      `where active is distinct from false and updated_at >= ${activeCutoffSql(historyWindow)}`,
      1,
      1,
    ),
    countKnown(
      "memory_semantic_edges",
      `where active is distinct from false and updated_at >= ${activeCutoffSql(historyWindow)}`,
      2,
      1,
    ),
    countKnown(
      "memory_recall_hints",
      `where created_at >= ${activeCutoffSql(historyWindow)}`,
      2,
      2,
    ),
    countKnown(
      "memory_query_observations",
      `where observed_at >= ${activeCutoffSql(historyWindow)}`,
      2,
      2,
    ),
    countKnown(
      "memory_neural_query_results",
      `where active_for_latest is distinct from false and last_seen_at >= ${activeCutoffSql(historyWindow)}`,
      2,
      2,
    ),
    countKnown(
      "memory_directives",
      `where active is distinct from false and updated_at >= ${activeCutoffSql(historyWindow)}`,
      1,
      1,
    ),
    countKnown(
      "memory_relationships",
      `where created_at >= ${activeCutoffSql(historyWindow)}`,
      2,
      1,
    ),
    countKnown(
      "memorydb_llm_outbox",
      `where updated_at >= ${activeCutoffSql(historyWindow)}`,
      1,
      1,
    ),
    countKnown(
      "memory_recall_log",
      `where latency_ms is not null and created_at >= ${activeCutoffSql(historyWindow)}`,
      1,
      1,
    ),
  ]);

  addEstimate("dynamic-schema-tables", schema.length, 1, 1, schema.length * 512);

  const dynamicTasks = [];
  for (const table of schema) {
    if (table.tableType !== "BASE TABLE") {
      sourceDetails.push({
        source: `${table.tableName}:view`,
        rows: 0,
        estimatedNodes: 0,
        estimatedVectors: 0,
        estimatedBytes: 0,
        skipped: "view-count-skipped-for-fast-history-estimate",
      });
      continue;
    }
    const nodeConfig = inferNodeTable(table);
    if (nodeConfig) {
      dynamicTasks.push(
        (async () => {
          const counted = await countedRowsWithBytes(table, historyWindow);
          addEstimate(`${table.tableName}:rows`, counted.rows, 1, 1, counted.bytes);
        })(),
      );
    }

    const relConfig = inferRelationshipTable(table);
    if (relConfig) {
      dynamicTasks.push(
        (async () => {
          const counted = await countedRowsWithBytes(table, historyWindow);
          addEstimate(`${table.tableName}:relationships`, counted.rows, 2, 1, counted.bytes);
        })(),
      );
    }

    const inferredLinks = inferForeignKeyLinks(table);
    if (inferredLinks.length) {
      dynamicTasks.push(
        (async () => {
          const rows = await countedRows(table, historyWindow);
          addEstimate(
            `${table.tableName}:foreign-key-links`,
            rows * inferredLinks.length,
            0,
            1,
            rows * inferredLinks.length * 96,
          );
        })(),
      );
    }
  }
  await Promise.all(dynamicTasks);

  const value = {
    ok: true,
    generatedAt: new Date().toISOString(),
    historyWindow: {
      days: historyWindow.days,
      activeWindowHours: Number((currentActiveWindowMs(historyWindow) / 3_600_000).toFixed(3)),
      activeCutoff: new Date(activeCutoffMs(historyWindow)).toISOString(),
    },
    estimate: {
      nodes: Math.round(estimatedNodes),
      vectors: Math.round(estimatedVectors),
      dataBytes: Math.round(estimatedBytes),
      nodeBytes: Math.round(
        estimatedBytes * (estimatedNodes / Math.max(1, estimatedNodes + estimatedVectors)),
      ),
      vectorBytes: Math.round(
        estimatedBytes * (estimatedVectors / Math.max(1, estimatedNodes + estimatedVectors)),
      ),
      dataMegabytes: Number((estimatedBytes / 1_048_576).toFixed(3)),
      complete: true,
      cappedAtMaxPages: false,
      source: "server-game-engine-optimized-history-count-estimate",
      queryMode: "indexed-counts",
      sourceCount: sourceDetails.length,
      sources: sourceDetails.slice(0, 12),
    },
    dataSource: {
      mode: "db-only",
      database: loadDbConfig().database || "connectionString",
      host: loadDbConfig().host || "DATABASE_URL",
      dynamicSchemaDiscovery: true,
      activeWindowHours: Number((currentActiveWindowMs(historyWindow) / 3_600_000).toFixed(3)),
      activeWindowDays: historyWindow.days,
      activeCutoff: new Date(activeCutoffMs(historyWindow)).toISOString(),
    },
  };
  historyEstimateCache.set(cacheKey, { createdAt: Date.now(), value });
  return value;
}

async function loadActivity() {
  const sources = [];
  if (await tableExists("app_query_log")) {
    sources.push(`
      select logged_at as at, 'query' as kind, query_label as title,
             coalesce(query_text, row_count::text, 'query') as detail
      from app_query_log
    `);
  }
  if (await tableExists("app_activity_events")) {
    sources.push(`
      select created_at as at, activity_type as kind, activity_key as title, 'activity event' as detail
      from app_activity_events
    `);
  }
  if (await tableExists("memory_llm_job_queue")) {
    sources.push(`
      select updated_at as at, status as kind, job_key as title,
             coalesce(result_summary, error_text, 'queued job') as detail
      from memory_llm_job_queue
    `);
  }
  if (await tableExists("memorydb_llm_outbox")) {
    sources.push(`
      select updated_at as at, status as kind, job_key as title,
             coalesce(left(result_text, 220), left(error_text, 220), reason) as detail
      from memorydb_llm_outbox
    `);
  }
  if (await tableExists("memory_recall_log")) {
    sources.push(`
      select created_at as at,
             'recall' as kind,
             coalesce(category_key, session_key, normalized_query, 'memory recall') as title,
             concat('latency ', coalesce(latency_ms::text, '?'), ' ms, selected ', cardinality(selected_keys)::text) as detail
      from memory_recall_log
    `);
  }
  if (sources.length === 0) return [];
  const result = await pool.query(`
    select *
    from (${sources.join("\nunion all\n")}) events
    where at is not null
    order by at desc
    limit 50
  `);
  return result.rows.map((row) => ({
    at: row.at,
    kind: row.kind,
    title: textLabel(row.title, "event"),
    detail: textLabel(row.detail, ""),
  }));
}

app.get("/api/health", async (_req, res) => {
  try {
    const result = await pool.query("select now() as now");
    res.json({ ok: true, dbTime: result.rows[0].now });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.get("/api/graph", async (req, res) => {
  try {
    res.json(await loadGraph(String(req.query.q || "")));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

let gameEngine = null;

app.get("/api/game/snapshot", async (_req, res) => {
  try {
    if (!gameEngine) return res.status(503).json({ error: "game engine not started" });
    res.json(gameEngine.snapshot());
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/game/identity", async (_req, res) => {
  try {
    const identity = await loadMemoryBrainIdentity();
    if (gameEngine) gameEngine.identity = identity;
    res.json({ ok: true, identity });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.get("/api/game/events", async (req, res) => {
  try {
    const limit = Math.max(1, Math.min(200, Number(req.query.limit || 80)));
    const result = await pool.query(
      `
        select event_id, event_type, node_id, link_key, payload, created_at
        from zorg_memory_3d_engine_events
        order by event_id desc
        limit $1
      `,
      [limit],
    );
    res.json(result.rows.reverse());
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/game/rules", async (_req, res) => {
  try {
    if (!gameEngine) return res.status(503).json({ error: "game engine not started" });
    res.json({
      ok: true,
      rules: engineRuleSummary(gameEngine.rules),
      config: engineConfigSummary(gameEngine.config),
      stats: gameEngine.ruleStats,
      independent: true,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch("/api/game/rules", async (req, res) => {
  try {
    if (!gameEngine) return res.status(503).json({ error: "game engine not started" });
    const input =
      req.body?.rules && typeof req.body.rules === "object" ? req.body.rules : req.body || {};
    const changed = gameEngine.setPhysicsRules(input);
    res.json({
      ok: true,
      changed,
      rules: engineRuleSummary(gameEngine.rules),
      config: engineConfigSummary(gameEngine.config),
      stats: gameEngine.ruleStats,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/game/config", async (_req, res) => {
  try {
    if (!gameEngine) return res.status(503).json({ error: "game engine not started" });
    res.json({
      ok: true,
      config: engineConfigSummary(gameEngine.config),
      rules: engineRuleSummary(gameEngine.rules),
      stats: gameEngine.ruleStats,
      identity: gameEngine.identity,
      independent: true,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/game/history-estimate", async (req, res) => {
  try {
    if (!gameEngine) return res.status(503).json({ error: "game engine not started" });
    const days = req.query.days ?? gameEngine.config?.historyWindow?.days;
    res.json(await estimateHistoryWindowLoad(days));
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.patch("/api/game/config", async (req, res) => {
  try {
    if (!gameEngine) return res.status(503).json({ error: "game engine not started" });
    const input =
      req.body?.config && typeof req.body.config === "object" ? req.body.config : req.body || {};
    const changed = gameEngine.setEngineConfig(input);
    res.json({
      ok: true,
      changed,
      config: engineConfigSummary(gameEngine.config),
      rules: engineRuleSummary(gameEngine.rules),
      identity: gameEngine.identity,
      stats: gameEngine.ruleStats,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/api/game/input", async (req, res) => {
  try {
    if (!gameEngine) return res.status(503).json({ error: "game engine not started" });
    const input = textLabel(req.body?.query || req.body?.input || "client input", "client input");
    const event = {
      type: "client_input",
      rule: "thin-client-input-to-server-engine",
      input,
      nodeId: null,
    };
    await gameEngine.recordEvents([event], "client-input");
    broadcastGameEvents([event]);
    res.json({ ok: true, engine: gameEngine.snapshot().engine });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/activity", async (_req, res) => {
  try {
    res.json(await loadActivity());
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get(["/admin", "/admin/", "/zorg-memory-3d/admin", "/zorg-memory-3d/admin/"], (_req, res) => {
  res.sendFile(path.join(__dirname, "public", "admin.html"));
});

const server = app.listen(port, "0.0.0.0", () => {
  console.log(`Zorg Memory 3D listening on ${port}`);
});

const wss = new WebSocketServer({ server, path: "/ws" });

function broadcastGameEvents(events) {
  if (!wss) return;
  const payload = JSON.stringify({
    type: "engine_events",
    engine: gameEngine?.snapshot().engine,
    events,
  });
  for (const client of wss.clients) {
    if (client.readyState === 1) client.send(payload);
  }
}

function broadcastGameSnapshot() {
  if (!wss || !gameEngine) return;
  const payload = JSON.stringify({ type: "engine_snapshot", data: gameEngine.snapshot() });
  for (const client of wss.clients) {
    if (client.readyState === 1) client.send(payload);
  }
}

wss.on("connection", (socket) => {
  let closed = false;
  let lastEventCount = 0;
  const send = async () => {
    if (closed || socket.readyState !== 1) return;
    try {
      const activity = await loadActivity();
      socket.send(JSON.stringify({ type: "activity", data: activity }));
      if (gameEngine && lastEventCount !== gameEngine.events.length) {
        socket.send(
          JSON.stringify({
            type: "engine_events",
            engine: gameEngine.snapshot().engine,
            events: gameEngine.events.slice(lastEventCount),
          }),
        );
        lastEventCount = gameEngine.events.length;
      }
      if (gameEngine)
        socket.send(JSON.stringify({ type: "engine_snapshot", data: gameEngine.snapshot() }));
    } catch (error) {
      socket.send(JSON.stringify({ type: "error", error: error.message }));
    }
  };
  if (gameEngine)
    socket.send(JSON.stringify({ type: "engine_snapshot", data: gameEngine.snapshot() }));
  const timer = setInterval(send, 5000);
  socket.on("close", () => {
    closed = true;
    clearInterval(timer);
  });
  send();
});

gameEngine = new MemoryGameEngine();
gameEngine.start().catch((error) => {
  console.error("Zorg Memory 3D game engine failed to start", error);
  gameEngine.lastError = error.message;
});
