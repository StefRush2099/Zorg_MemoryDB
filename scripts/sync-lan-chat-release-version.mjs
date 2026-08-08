import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const rootPackage = JSON.parse(await readFile(path.join(root, "package.json"), "utf8"));
const lanRoot = path.join(root, "package", "zorg", "lan-command-chat");
const lanPackagePath = path.join(lanRoot, "package.json");
const lanLockPath = path.join(lanRoot, "package-lock.json");
const gaugePath = path.join(lanRoot, "src", "app", "chat", "page.tsx");
const lanPackage = JSON.parse(await readFile(lanPackagePath, "utf8"));
const lanLock = JSON.parse(await readFile(lanLockPath, "utf8"));
const gaugeSource = await readFile(gaugePath, "utf8");
const version = rootPackage.version;

if (!/^\d+\.\d+\.\d+$/.test(version)) throw new Error(`invalid canonical version: ${version}`);
if (!gaugeSource.includes('import packageMetadata from "../../../package.json"')) {
  throw new Error("LAN Chat gauge must import package metadata");
}
if (!gaugeSource.includes("data-lan-chat-gauge-version={LAN_CHAT_RELEASE_VERSION}")) {
  throw new Error("LAN Chat gauge-specific version marker is missing");
}

lanPackage.version = version;
lanLock.version = version;
lanLock.packages ??= {};
lanLock.packages[""] ??= {};
lanLock.packages[""].version = version;
await writeFile(lanPackagePath, `${JSON.stringify(lanPackage, null, 2)}\n`);
await writeFile(lanLockPath, `${JSON.stringify(lanLock, null, 2)}\n`);
console.log(`synchronized LAN Command Chat package and lock to v${version}`);
