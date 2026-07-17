#!/usr/bin/env python3
"""Enforce DB-backed OpenClaw memory_search routing.

This is structural glue only. It does not export, embed, or publish memory data.

What it enforces:
- agents.defaults.memorySearch is moved away from remote/API-key embedding providers.
- OpenClaw's built-in memory_search tool short-circuits normal memory-file recall
  through memory_recall_router.py, which uses PostgreSQL directly.
- Active Memory passes its real recall start timestamp and elapsed duration into
  the prompt prefix, and disables the cache path that can surface stale timing.
- The patch is applied to both the global OpenClaw install and runtime dependency
  copies so package/runtime refreshes can be repaired by rerunning this script.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

OPENCLAW_HOME = Path(os.environ.get('OPENCLAW_HOME', Path.home() / '.openclaw')).expanduser()
WORKSPACE = Path(os.environ.get('OPENCLAW_WORKSPACE', Path.cwd())).expanduser().resolve()
SKILL_ROOT = Path(__file__).resolve().parents[1]
CONFIG = Path(os.environ.get('OPENCLAW_CONFIG', OPENCLAW_HOME / 'openclaw.json')).expanduser()
BACKUP_ROOT = WORKSPACE / 'backups' / 'db-memory-enforcer'

HELPER = '''
function normalizeZorgDbMemoryRows(payload, maxResults) {
	const rows = Array.isArray(payload?.structured) ? payload.structured : Array.isArray(payload?.all) ? payload.all : Array.isArray(payload?.result?.all) ? payload.result.all : [];
	const limit = Math.max(1, maxResults ?? 10);
	return rows.slice(0, limit).map((row, index) => {
		const content = typeof row?.content === "string" ? row.content : typeof row?.snippet === "string" ? row.snippet : "";
		const pathValue = typeof row?.path === "string" && row.path.trim() ? row.path : "DB:zorg_memory";
		const lineStart = Number.isFinite(row?.line_start) ? Math.max(1, Math.floor(row.line_start)) : void 0;
		const lineEnd = Number.isFinite(row?.line_end) ? Math.max(lineStart ?? 1, Math.floor(row.line_end)) : lineStart;
		return {
			path: pathValue,
			startLine: lineStart,
			endLine: lineEnd,
			score: Math.max(0.001, 1 - index * 0.001),
			snippet: content,
			source: "memory",
			citation: lineStart ? `${pathValue}#L${lineStart}${lineEnd && lineEnd !== lineStart ? `-L${lineEnd}` : ""}` : pathValue,
			corpus: "memory"
		};
	});
}
async function searchZorgDatabaseMemory(query, maxResults) {
	const fs = await import("node:fs/promises");
	const path = await import("node:path");
	const workspaceDir = process.env.OPENCLAW_WORKSPACE || (process.env.HOME ? path.join(process.env.HOME, ".openclaw", "workspace") : process.cwd());
	const pythonPath = process.env.SQLMEM_PYTHON || path.join(workspaceDir, ".venv-sqlmem", "bin", "python");
	let routerPath = process.env.MEMORY_RECALL_ROUTER || path.join(workspaceDir, "memory_recall_router.py");
	const startedAt = Date.now();
	try {
		await fs.access(pythonPath);
		try {
			await fs.access(routerPath);
		} catch {
			routerPath = path.join(workspaceDir, "scripts", "memory_recall_router.py");
			await fs.access(routerPath);
		}
		const { execFile } = await import("node:child_process");
		const output = await new Promise((resolve, reject) => {
			execFile(pythonPath, [routerPath, query, "--limit", String(Math.max(1, maxResults ?? 10))], { cwd: workspaceDir, timeout: 15000, maxBuffer: 1024 * 1024 }, (error, stdout, stderr) => {
				if (error) {
					error.stderr = stderr;
					reject(error);
					return;
				}
				resolve(stdout);
			});
		});
		const payload = JSON.parse(String(output));
		const results = normalizeZorgDbMemoryRows(payload, maxResults);
		return {
			results,
			provider: "zorg-db",
			model: "postgresql-direct",
			fallback: "none",
			citations: "auto",
			mode: payload?.mode ?? "database-direct-structured",
			debug: {
				backend: "database-direct-structured",
				effectiveMode: payload?.mode ?? "database-direct-structured",
				searchMs: Math.max(0, Date.now() - startedAt),
				hits: results.length
			}
		};
	} catch (error) {
		return {
			results: [],
			provider: "zorg-db",
			model: "postgresql-direct",
			fallback: "none",
			citations: "auto",
			mode: "database-unavailable",
			debug: {
				backend: "database-unavailable",
				error: formatErrorMessage(error),
				hits: 0
			}
		};
	}
}
'''

OLD_EXEC_VARIANTS = [
'''execute: ({ cfg, agentId }) => async (_toolCallId, params) => {
			const rawParams = asToolParamsRecord(params);
			const query = readStringParam(rawParams, "query", { required: true });
			const maxResults = readNumberParam(rawParams, "maxResults");
			const minScore = readNumberParam(rawParams, "minScore");
			const requestedCorpus = readStringParam(rawParams, "corpus");
			const { resolveMemoryBackendConfig } = await loadMemoryToolRuntime();''',
'''execute: ({ cfg, agentId }) => async (_toolCallId, params) => {
			const rawParams = asToolParamsRecord(params);
			const query = readStringParam(rawParams, "query", { required: true });
			const maxResults = readPositiveIntegerParam(rawParams, "maxResults");
			const minScore = readFiniteNumberParam(rawParams, "minScore");
			const requestedCorpus = readStringParam(rawParams, "corpus");
			const { resolveMemoryBackendConfig } = await loadMemoryToolRuntime();'''
]

NEW_EXEC_VARIANTS = [old.replace('const { resolveMemoryBackendConfig } = await loadMemoryToolRuntime();', 'if (requestedCorpus !== "wiki" && requestedCorpus !== "sessions") return jsonResult(await searchZorgDatabaseMemory(query, maxResults));\n\t\t\tconst { resolveMemoryBackendConfig } = await loadMemoryToolRuntime();') for old in OLD_EXEC_VARIANTS]


def backup(path: Path) -> None:
    if not path.exists():
        return
    dest = BACKUP_ROOT / datetime.now().strftime('%Y%m%d_%H%M%S')
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, dest / path.name)


def enforce_config() -> bool:
    if CONFIG.exists():
        data = json.loads(CONFIG.read_text(encoding='utf-8'))
    else:
        data = {}
    defaults = data.setdefault('agents', {}).setdefault('defaults', {})
    ms = defaults.setdefault('memorySearch', {})
    changed = False
    desired = {
        'enabled': True,
        'provider': 'local',
        'fallback': 'none',
        'sources': ['memory'],
    }
    for key, value in desired.items():
        if ms.get(key) != value:
            ms[key] = value
            changed = True
    multimodal = ms.setdefault('multimodal', {})
    if multimodal.get('enabled') is not False:
        multimodal['enabled'] = False
        changed = True
    # Clean installs must fail closed into DB-only recall. Remove settings that can
    # re-enable remote embedding or flat-file memory fallback behavior.
    for stale in ('remote', 'model', 'outputDimensionality'):
        if stale in ms:
            del ms[stale]
            changed = True
    # Older v1.2.10 draft builds wrote this non-schema root marker. Remove it so
    # upgraded/failed test installs recover instead of breaking gateway validation.
    if 'zorgMemoryDb' in data:
        del data['zorgMemoryDb']
        changed = True
    if changed or not CONFIG.exists():
        backup(CONFIG)
        CONFIG.parent.mkdir(parents=True, exist_ok=True)
        CONFIG.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    return changed


def memory_core_paths() -> list[Path]:
    candidates: list[Path] = []
    npm_root = subprocess.run(['npm', 'root', '-g'], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    roots: list[Path] = []
    if npm_root.returncode == 0 and npm_root.stdout.strip():
        roots.append(Path(npm_root.stdout.strip()) / 'openclaw' / 'dist')
    roots.append(Path('/home/openclaw/.npm-global/lib/node_modules/openclaw/dist'))
    roots.append(Path('/usr/local/lib/node_modules/openclaw/dist'))
    runtime_root = OPENCLAW_HOME / 'plugin-runtime-deps'
    if runtime_root.exists():
        roots.extend(path.parent.parent.parent for path in runtime_root.glob('openclaw-*/dist/extensions/memory-core/index.js'))
    for root in roots:
        candidates.append(root / 'extensions' / 'memory-core' / 'index.js')
        candidates.extend(root.glob('tools-*.js'))
    found: list[Path] = []
    for candidate in candidates:
        try:
            resolved = candidate.expanduser().resolve()
        except FileNotFoundError:
            resolved = candidate.expanduser()
        if resolved.exists() and resolved not in found:
            found.append(resolved)
    return found


def active_memory_paths() -> list[Path]:
    candidates: list[Path] = []
    npm_root = subprocess.run(['npm', 'root', '-g'], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    roots: list[Path] = []
    if npm_root.returncode == 0 and npm_root.stdout.strip():
        roots.append(Path(npm_root.stdout.strip()) / 'openclaw' / 'dist')
    roots.append(Path('/home/openclaw/.npm-global/lib/node_modules/openclaw/dist'))
    roots.append(Path('/usr/local/lib/node_modules/openclaw/dist'))
    runtime_root = OPENCLAW_HOME / 'plugin-runtime-deps'
    if runtime_root.exists():
        roots.extend(path.parent.parent.parent for path in runtime_root.glob('openclaw-*/dist/extensions/active-memory/index.js'))
    found: list[Path] = []
    for root in roots:
        candidate = (root / 'extensions' / 'active-memory' / 'index.js').expanduser()
        try:
            resolved = candidate.resolve()
        except FileNotFoundError:
            resolved = candidate
        if resolved.exists() and resolved not in found:
            found.append(resolved)
    return found


def enforce_runtime() -> bool:
    any_changed = False
    for runtime_file in memory_core_paths():
        text = runtime_file.read_text(encoding='utf-8')
        changed = False
        marker = 'function createMemorySearchTool(options) {'
        applicable = marker in text or any(old in text for old in OLD_EXEC_VARIANTS) or any(new in text for new in NEW_EXEC_VARIANTS) or 'function searchZorgDatabaseMemory(query, maxResults)' in text
        if not applicable:
            continue
        if 'function searchZorgDatabaseMemory(query, maxResults)' not in text:
            if marker not in text:
                raise RuntimeError(f'createMemorySearchTool marker not found in {runtime_file}')
            text = text.replace(marker, HELPER + '\n' + marker, 1)
            changed = True
        current_corpus_read = 'const requestedCorpus = readStringParam(rawParams, "corpus");'
        current_db_route = 'if (requestedCorpus !== "wiki" && requestedCorpus !== "sessions") return jsonResult(await searchZorgDatabaseMemory(query, maxResults));'
        if not any(new_exec in text for new_exec in NEW_EXEC_VARIANTS) and current_db_route not in text:
            # OpenClaw 2026.7.x moved memory_search behind a deadline wrapper
            # and changed the manager setup block.  Keep the DB-only routing
            # invariant by inserting the same short-circuit immediately after
            # the current corpus parameter read.
            if current_corpus_read in text and current_db_route not in text:
                text = text.replace(current_corpus_read, current_corpus_read + '\n\t\t\t' + current_db_route, 1)
                changed = True
            else:
                for old_exec, new_exec in zip(OLD_EXEC_VARIANTS, NEW_EXEC_VARIANTS):
                    if old_exec in text:
                        text = text.replace(old_exec, new_exec, 1)
                        changed = True
                        break
                else:
                    raise RuntimeError(f'memory_search execute block marker not found in {runtime_file}')
        if changed:
            backup(runtime_file)
            runtime_file.write_text(text, encoding='utf-8')
            subprocess.run(['node', '--check', str(runtime_file)], check=True)
            any_changed = True
    return any_changed


def enforce_active_memory_timing() -> bool:
    any_changed = False
    replacements = [
        (
            'function shouldCacheResult(result) {\n\treturn result.status === "ok";\n}',
            'function shouldCacheResult(result) {\n\treturn false;\n}',
        ),
        (
            'function buildMetadata(summary) {',
            'function buildMetadata(summary, timing) {',
        ),
        (
            'function buildPromptPrefix(summary) {\n\tconst metadata = buildMetadata(summary);',
            'function buildPromptPrefix(summary, timing) {\n\tconst metadata = buildMetadata(summary, timing);',
        ),
        (
            'const promptPrefix = buildPromptPrefix(result.summary);',
            'const promptPrefix = buildPromptPrefix(result.summary, result);',
        ),
        (
            'elapsedMs: params.elapsedMs,\n\t\tsummary: null,',
            'elapsedMs: params.elapsedMs,\n\t\tstartedAtMs: params.startedAtMs,\n\t\tsummary: null,',
        ),
        (
            'elapsedMs: params.elapsedMs,\n\t\tsummary,',
            'elapsedMs: params.elapsedMs,\n\t\tstartedAtMs: params.startedAtMs,\n\t\tsummary,',
        ),
        (
            'status: "timeout",\n\t\t\telapsedMs: 0,\n\t\t\tsummary: null',
            'status: "timeout",\n\t\t\telapsedMs: 0,\n\t\t\tstartedAtMs: startedAt,\n\t\t\tsummary: null',
        ),
        (
            'elapsedMs: Date.now() - startedAt,\n\t\t\t\tmaxSummaryChars:',
            'elapsedMs: Date.now() - startedAt,\n\t\t\t\tstartedAtMs: startedAt,\n\t\t\t\tmaxSummaryChars:',
        ),
        (
            'elapsedMs: Date.now() - startedAt,\n\t\t\t\tsummary: null,',
            'elapsedMs: Date.now() - startedAt,\n\t\t\t\tstartedAtMs: startedAt,\n\t\t\t\tsummary: null,',
        ),
        (
            'status: "ok",\n\t\t\telapsedMs: Date.now() - startedAt,\n\t\t\trawReply,',
            'status: "ok",\n\t\t\telapsedMs: Date.now() - startedAt,\n\t\t\tstartedAtMs: startedAt,\n\t\t\trawReply,',
        ),
        (
            'status: "failed",\n\t\t\telapsedMs: Date.now() - startedAt,\n\t\t\tsummary: null,',
            'status: "failed",\n\t\t\telapsedMs: Date.now() - startedAt,\n\t\t\tstartedAtMs: startedAt,\n\t\t\tsummary: null,',
        ),
        (
            'status: "unavailable",\n\t\t\telapsedMs: Date.now() - startedAt,\n\t\t\tsummary: null,',
            'status: "unavailable",\n\t\t\telapsedMs: Date.now() - startedAt,\n\t\t\tstartedAtMs: startedAt,\n\t\t\tsummary: null,',
        ),
        (
            'status: "no_relevant_memory",\n\t\t\telapsedMs: Date.now() - startedAt,\n\t\t\tsummary: null,',
            'status: "no_relevant_memory",\n\t\t\telapsedMs: Date.now() - startedAt,\n\t\t\tstartedAtMs: startedAt,\n\t\t\tsummary: null,',
        ),
        (
            'status: "failed",\n\t\t\telapsedMs: Date.now() - startedAt,\n\t\t\tsummary: null\n\t\t};',
            'status: "failed",\n\t\t\telapsedMs: Date.now() - startedAt,\n\t\t\tstartedAtMs: startedAt,\n\t\t\tsummary: null\n\t\t};',
        ),
    ]
    metadata_block = '''function formatActiveMemoryLocalTimestamp(ms) {
\tconst date = new Date(ms);
\tconst pad = (value, size = 2) => String(value).padStart(size, "0");
\tconst tz = Intl.DateTimeFormat("en-US", { timeZoneName: "short" }).formatToParts(date).find((part) => part.type === "timeZoneName")?.value ?? "";
\treturn `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())} ${tz}`.trim();
}
'''
    timing_block = '''\tif (timing?.startedAtMs && Number.isFinite(timing.elapsedMs) && timing.elapsedMs > 0) {
\t\tconst elapsedText = formatElapsedMsForStatus(timing.elapsedMs);
\t\tmetadata.push(
\t\t\t`<active_memory_timing>`,
\t\t\t`backend_db_memory_check_started_at="${escapeXml(formatActiveMemoryLocalTimestamp(timing.startedAtMs))}"`,
\t\t\t`backend_db_memory_check_elapsed="${escapeXml(elapsedText)}"`,
\t\t\t`required_visible_reply_time_summary="${escapeXml(`Time summary: backend DB memory scan ${elapsedText}.`)}"`,
\t\t\t`</active_memory_timing>`
\t\t);
\t}
'''
    for runtime_file in active_memory_paths():
        text = runtime_file.read_text(encoding='utf-8')
        if 'id: "active-memory"' not in text:
            continue
        changed = False
        if 'function formatActiveMemoryLocalTimestamp(ms)' not in text:
            marker = 'function escapeXml(str) {'
            if marker not in text:
                raise RuntimeError(f'active-memory escapeXml marker not found in {runtime_file}')
            text = text.replace(marker, metadata_block + marker, 1)
            changed = True
        for old, new in replacements:
            if old in text and new not in text:
                text = text.replace(old, new, 1)
                changed = True
        if '<active_memory_timing>' not in text:
            marker = '\treturn metadata.join("\\n");\n}'
            if marker not in text:
                # Current OpenClaw 2026.7.x uses a compact buildMetadata()
                # implementation instead of the older metadata-array form.
                current_marker = 'function buildMetadata(summary) {'
                current_return = '\treturn [\n\t\t`<${ACTIVE_MEMORY_PLUGIN_TAG}>`,'
                if current_marker in text and current_return in text:
                    text = text.replace(current_marker, 'function buildMetadata(summary, timing) {', 1)
                    current_timing = '''\tif (timing?.elapsedMs > 0) {
\t\tconst elapsedText = formatElapsedMsForStatus(timing.elapsedMs);
\t\tconst startedAtMs = Number.isFinite(timing.startedAtMs) ? timing.startedAtMs : Date.now() - timing.elapsedMs;
\t\treturn [
\t\t\t`<${ACTIVE_MEMORY_PLUGIN_TAG}>`,
\t\t\tescapeXml(summary),
\t\t\t`backend_db_memory_check_started_at="${escapeXml(formatActiveMemoryLocalTimestamp(startedAtMs))}"`,
\t\t\t`backend_db_memory_check_elapsed="${escapeXml(elapsedText)}"`,
\t\t\t`required_visible_reply_time_summary="${escapeXml(`Time summary: backend DB memory scan ${elapsedText}.`)}"`,
\t\t\t`</${ACTIVE_MEMORY_PLUGIN_TAG}>`
\t\t].join("\\n");
\t}
'''
                    text = text.replace(current_return, current_timing + current_return, 1)
                    changed = True
                else:
                    continue
            else:
                text = text.replace(marker, timing_block + marker, 1)
                changed = True
        if 'const promptPrefix = buildPromptPrefix(result.summary);' in text:
            text = text.replace('const promptPrefix = buildPromptPrefix(result.summary);', 'const promptPrefix = buildPromptPrefix(result.summary, result);', 1)
            changed = True
        if changed:
            backup(runtime_file)
            runtime_file.write_text(text, encoding='utf-8')
            subprocess.run(['node', '--check', str(runtime_file)], check=True)
            any_changed = True
    return any_changed


def verify_db() -> None:
    python = Path(os.environ.get('SQLMEM_PYTHON', WORKSPACE / '.venv-sqlmem' / 'bin' / 'python'))
    router = Path(os.environ.get('MEMORY_RECALL_ROUTER', SKILL_ROOT / 'scripts' / 'memory_recall_router.py'))
    if not router.exists():
        router = SKILL_ROOT / 'scripts' / 'memory_recall_router.py'
    if not python.exists() or not router.exists():
        return
    subprocess.run([str(python), str(router), 'database memory enforcement verification', '--limit', '2'], cwd=WORKSPACE, check=True, stdout=subprocess.PIPE)


def main() -> int:
    changed = []
    if enforce_config():
        changed.append('config')
    if enforce_runtime():
        changed.append('runtime')
    if enforce_active_memory_timing():
        changed.append('active-memory-timing')
    verify_db()
    print(json.dumps({
        'ok': True,
        'changed': changed,
        'config': str(CONFIG),
        'runtimeFiles': [str(path) for path in memory_core_paths()],
        'activeMemoryFiles': [str(path) for path in active_memory_paths()],
    }))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
