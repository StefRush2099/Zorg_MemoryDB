#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const repoRoot = path.resolve(__dirname, "..", "..");
const rootPackage = JSON.parse(
  fs.readFileSync(path.join(repoRoot, "package.json"), "utf8"),
);
const pluginRoot = path.join(repoRoot, "skills", "zorg-db-memory", "plugin-src");
const pluginPackage = JSON.parse(
  fs.readFileSync(path.join(pluginRoot, "package.json"), "utf8"),
);
const pluginManifest = JSON.parse(
  fs.readFileSync(path.join(pluginRoot, "openclaw.plugin.json"), "utf8"),
);
const lanChatPackage = JSON.parse(
  fs.readFileSync(
    path.join(repoRoot, "package", "zorg", "lan-command-chat", "package.json"),
    "utf8",
  ),
);

const failures = [];
const fail = (message) => failures.push(message);
const requireFile = (relativePath) => {
  if (!fs.existsSync(path.join(repoRoot, relativePath))) {
    fail(`missing required file: ${relativePath}`);
  }
};

for (const [name, version] of [
  ["plugin package", pluginPackage.version],
  ["plugin manifest", pluginManifest.version],
  ["LAN Command Chat", lanChatPackage.version],
]) {
  if (version !== rootPackage.version) {
    fail(`${name} version ${version} does not match ${rootPackage.version}`);
  }
}

for (const relativePath of [
  "package/zorg/install-zorg-memorydb.sh",
  "package/zorg/db/schema.sql",
  "package/zorg/db/memory_runtime_compat_2026_07_21.sql",
  "package/zorg/db/memory_semantic_capture_triggers_2026_07_17.sql",
  "package/zorg/db/memory_complete_self_repair_rule_2026_07_21.sql",
  "skills/zorg-db-memory/plugin-src/dist/index.js",
  "skills/zorg-db-memory/plugin-src/dist/mcp-server.js",
  "package/zorg/systemd/zorg-memorydb-llm-dispatcher.service",
]) {
  requireFile(relativePath);
}

const installer = fs.readFileSync(
  path.join(repoRoot, "package", "zorg", "install-zorg-memorydb.sh"),
  "utf8",
);
for (const requiredText of [
  "CREATE EXTENSION IF NOT EXISTS vector",
  "memory_runtime_compat_2026_07_21.sql",
  "memory_typed_events_2026_07_16.sql",
  "memory_rule_scope_dedup_2026_07_15.sql",
  "skills/zorg-db-memory/config/sql_memory_map.json",
  "semantic-capture-triggers-ok",
  "zorg-memorydb-core-runner",
  "zorg-memorydb-llm-enqueuer",
  'defaults["memorySearch"] = {"enabled": False}',
  'compaction["memoryFlush"] = {"enabled": False}',
  'session_memory["enabled"] = False',
  'zorg_plugin["enabled"] = True',
]) {
  if (!installer.includes(requiredText)) {
    fail(`installer is missing required runtime step: ${requiredText}`);
  }
}

const mcpSource = fs.readFileSync(path.join(pluginRoot, "src", "mcp-server.ts"), "utf8");
for (const requiredText of [
  "skills/zorg-db-memory/config/sql_memory_map.json",
  "sql_memory_map.json",
  "memory_graph",
  `version: "${rootPackage.version}"`,
]) {
  if (!mcpSource.includes(requiredText)) {
    fail(`MCP source is missing: ${requiredText}`);
  }
}

if (process.env.ZORG_VERIFY_LIVE === "1") {
  const workspace =
    process.env.OPENCLAW_WORKSPACE ||
    process.env.WORKSPACE_DIR ||
    path.join(process.env.HOME || ".", ".openclaw", "workspace");
  const mapPath =
    process.env.SQL_MEMORY_MAP ||
    process.env.ZORG_SQL_MEMORY_MAP ||
    path.join(workspace, "sql_memory_map.json");
  const map = JSON.parse(fs.readFileSync(mapPath, "utf8"));
  const pg = map.postgres;
  const query = [
    "select case when count(*) = 11 and bool_and(trigger_enabled)",
    "then 'ok' else 'incomplete' end",
    "from public.memory_semantic_capture_trigger_status_v1;",
    "select count(*) from public.memory_search_table_v1('all','database memory',5);",
  ].join(" ");
  const result = spawnSync(
    "psql",
    [
      "-v", "ON_ERROR_STOP=1",
      "-h", String(pg.host),
      "-p", String(pg.port),
      "-U", String(pg.user),
      "-d", String(pg.database),
      "-Atqc", query,
    ],
    { encoding: "utf8", env: { ...process.env, PGPASSWORD: pg.password || "" } },
  );
  if (result.status !== 0) {
    fail(`live database verification failed: ${result.stderr.trim()}`);
  } else if (!result.stdout.split(/\r?\n/).includes("ok")) {
    fail("live database verification did not report 11 enabled triggers");
  }
}

if (failures.length > 0) {
  for (const message of failures) {
    console.error(`[zorg-verify-package-runtime] ${message}`);
  }
  process.exit(1);
}

console.log(
  `[zorg-verify-package-runtime] OK version=${rootPackage.version}` +
    (process.env.ZORG_VERIFY_LIVE === "1" ? " live=verified" : ""),
);
