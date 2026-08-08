import { createHmac } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";

const root = process.cwd();
const pkg = JSON.parse(await readFile(path.join(root, "package.json"), "utf8"));
const lock = JSON.parse(await readFile(path.join(root, "package-lock.json"), "utf8"));
const expected = pkg.version;
const failures = [];
const buildOnly = process.argv.includes("--build-only");
const marker = "data-lan-chat-gauge-version";

async function localEnvValue(name) {
  try {
    const source = await readFile(path.join(root, ".env.local"), "utf8");
    for (const rawLine of source.split(/\r?\n/)) {
      const line = rawLine.trim();
      if (!line || line.startsWith("#")) continue;
      const equals = line.indexOf("=");
      if (equals < 1 || line.slice(0, equals).trim() !== name) continue;
      const value = line.slice(equals + 1).trim();
      return value.replace(/^(['"])(.*)\1$/, "$2");
    }
  } catch {}
  return "";
}

if (lock.version !== expected || lock.packages?.[""]?.version !== expected) {
  failures.push(
    `package-lock version mismatch: lock=${lock.version}, root=${lock.packages?.[""]?.version}, expected=${expected}`,
  );
}

async function collectFiles(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...(await collectFiles(target)));
    else files.push(target);
  }
  return files;
}

const chunks = (await collectFiles(path.join(root, ".next", "static"))).filter((file) =>
  file.endsWith(".js"),
);
let gaugeMarkerFound = false;
let compiledGaugeVersionFound = false;
for (const file of chunks) {
  const content = await readFile(file, "utf8");
  if (!content.includes(marker)) continue;
  gaugeMarkerFound = true;
  if (content.includes(expected)) compiledGaugeVersionFound = true;
}
if (!gaugeMarkerFound) failures.push(`compiled gauge does not contain ${marker}`);
if (!compiledGaugeVersionFound) {
  failures.push(`compiled gauge marker does not contain LAN Chat version ${expected}`);
}

if (!buildOnly) {
  const authSecret = process.env.LAN_CHAT_AUTH_SECRET?.trim() || await localEnvValue("LAN_CHAT_AUTH_SECRET");
  if (!authSecret) failures.push("LAN_CHAT_AUTH_SECRET is required for rendered gauge verification");
  const issued = String(Date.now());
  const signature = authSecret
    ? createHmac("sha256", authSecret).update(issued).digest("base64url")
    : "";
  const authCookie = `lan_chat_auth=v1.${Buffer.from(issued).toString("base64url")}.${signature}`;
  for (const url of ["http://127.0.0.1:3001/chat", "http://127.0.0.1/chat"]) {
    try {
      const response = await fetch(url, {
        redirect: "manual",
        headers: authSecret ? { cookie: authCookie } : {},
      });
      if (!response.ok) {
        failures.push(`${url} returned HTTP ${response.status}`);
        continue;
      }
      const html = await response.text();
      const renderedMarker = `${marker}="${expected}"`;
      const renderedText = html.includes(`v${expected}`) || html.includes(`v<!-- -->${expected}`);
      if (!html.includes(renderedMarker) || !renderedText) {
        failures.push(`${url} did not render ${renderedMarker} with visible v${expected}`);
      }
    } catch (error) {
      failures.push(`${url} is unreachable: ${error.message}`);
    }
  }
}

if (failures.length) {
  console.error(`LAN Chat live-version verification failed for v${expected}:`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(
  buildOnly
    ? `LAN Chat v${expected} package, lock, and gauge-specific compiled marker verified.`
    : `LAN Chat v${expected} package, lock, compiled gauge marker, and authenticated rendered gauge verified.`,
);
