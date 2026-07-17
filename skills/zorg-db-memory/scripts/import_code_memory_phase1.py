#!/usr/bin/env python3
"""Phase 1 importer for local DB-backed memory structure.

Imports:
- file-level code units from selected workspace code/docs files
- section-level context notes from core markdown/docs
- project/service/system links for code units using existing memory_* tables
- action logs and code-change logs from daily/project markdown memory
- structured directives/runbooks from markdown memory heuristics

This script is idempotent via stable keys + UPSERTs.
It does not alter existing runtime code paths.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator, Optional

import psycopg2
from psycopg2.extras import Json

BASE = Path(os.environ.get("OPENCLAW_WORKSPACE", "/home/openclaw/.openclaw/workspace"))
SKILL_ROOT = Path(__file__).resolve().parents[1]
MAP_CANDIDATES = [
    Path(os.environ.get("SQL_MEMORY_MAP", SKILL_ROOT / "config" / "sql_memory_map.json")),
]

DEFAULT_INCLUDE_EXTS = {
    ".py", ".sh", ".sql", ".js", ".jsx", ".ts", ".tsx", ".json", ".md", ".yml", ".yaml"
}
DEFAULT_EXCLUDE_DIRS = {
    ".git", "node_modules", ".next", "dist", "build", "coverage", "__pycache__",
    ".venv", ".venv-sqlmem", ".venv_skillpack", ".venv-skill", ".venv_smb", ".venv_skill",
    "backups", "tmp", "tmp_verify", "uploads", "Zorg_Hive_corrupt_20260226_113103"
}
DEFAULT_MARKDOWN_FILES = [
    "AGENTS.md", "SOUL.md", "USER.md", "TOOLS.md", "IDENTITY.md", "HEARTBEAT.md"
]
PROJECT_HINTS = ["Zorg_spawn", "lan-chat", "HLS-OAUTH", "APM-TERM", "scripts", "db", "skills", "memory", "file-sys-2-db"]
DATE_FILE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}\.md$")
TIMESTAMP_PREFIX_RE = re.compile(r"^\s*[-*]?\s*(\d{4}-\d{2}-\d{2}\s+)?\d{1,2}:\d{2}(?:-\d{1,2}:\d{2})?\s*[A-Z]{2,4}\s*[-–—]\s*(.+)$")
DIRECTIVE_RE = re.compile(r"\b(always|must|never|do not|don't|required|rule|policy|critical|permanent|ask first|wait for go)\b", re.I)
RUNBOOK_RE = re.compile(r"\b(step|steps|procedure|workflow|runbook|playbook|checklist|safe next step|how to|first\b|then\b)\b", re.I)
CODE_CHANGE_RE = re.compile(r"\b(changed|change|modified|patched|updated|built|added|fixed|refactored|renamed|migrated|deployed|redeployed|implemented)\b", re.I)
ACTION_RE = re.compile(r"\b(reviewed|verified|checked|ran|applied|tested|created|loaded|populated|seeded|recorded|documented|built|deployed|modified|updated|patched|imported)\b", re.I)
PROJECT_NAME_RE = re.compile(r"^#\s+(.+?)\s*$")
HOST_CANDIDATE_RE = re.compile(r"\b(?:openclaw|vorg|jumpbox|tank|docker|postgres|kokoro|fleetbase)\b|\b\d{1,3}(?:\.\d{1,3}){3}\b", re.I)
PATH_RE = re.compile(r"(/home/openclaw/[^\s`]+)")


@dataclass
class CodeUnit:
    unit_key: str
    unit_kind: str
    lang: Optional[str]
    workspace_path: str
    repo_root: Optional[str]
    title: Optional[str]
    symbol_name: Optional[str]
    start_line: int
    end_line: int
    content_hash: str
    body_text: str
    metadata: dict


@dataclass
class ContextNote:
    note_key: str
    note_type: str
    title: Optional[str]
    note_text: str
    source_kind: str
    source_path: str
    source_line_start: int
    source_line_end: int
    content_hash: str
    metadata: dict


@dataclass
class CodeLink:
    code_unit_key: str
    link_type: str
    target_type: str
    target_key: str
    source_path: Optional[str]
    source_line_start: Optional[int]
    source_line_end: Optional[int]
    metadata: dict


@dataclass
class ActionLog:
    action_key: str
    action_kind: str
    summary: str
    detail_text: str
    source_path: str
    source_line_start: int
    source_line_end: int
    project_key: Optional[str]
    project_name: Optional[str]
    host_key: Optional[str]
    host_name: Optional[str]
    descriptor_text: Optional[str]
    content_hash: str
    metadata: dict


@dataclass
class CodeChangeLog:
    change_key: str
    change_kind: str
    summary: str
    detail_text: str
    source_path: str
    source_line_start: int
    source_line_end: int
    project_key: Optional[str]
    project_name: Optional[str]
    host_key: Optional[str]
    host_name: Optional[str]
    descriptor_text: Optional[str]
    file_paths: list[str]
    content_hash: str
    metadata: dict


@dataclass
class DirectiveRecord:
    directive_key: str
    directive_text: str
    category: Optional[str]
    priority: Optional[str]
    effective_date: Optional[str]
    source_path: str
    source_line_start: int
    source_line_end: int
    tags: list[str]


@dataclass
class RunbookRecord:
    runbook_key: str
    title: str
    scope: Optional[str]
    trigger_text: Optional[str]
    procedure_text: str
    source_path: str
    source_line_start: int
    source_line_end: int
    tags: list[str]


def resolve_map_path() -> Path:
    for candidate in MAP_CANDIDATES:
        if candidate.exists():
            return candidate
    raise FileNotFoundError(f"No sql_memory_map.json found in: {', '.join(str(p) for p in MAP_CANDIDATES)}")


def load_cfg() -> dict:
    return json.loads(resolve_map_path().read_text(encoding="utf-8"))


def connect():
    p = load_cfg()["postgres"]
    return psycopg2.connect(
        host=p["host"],
        port=p["port"],
        dbname=p["database"],
        user=p["user"],
        password=p["password"],
    )


def sha1_text(text: str) -> str:
    return hashlib.sha1(text.encode("utf-8", errors="ignore")).hexdigest()


def relpath(path: Path) -> str:
    return str(path.resolve().relative_to(BASE.resolve()))


def guess_lang(path: Path) -> Optional[str]:
    return {
        ".py": "python",
        ".sh": "shell",
        ".sql": "sql",
        ".js": "javascript",
        ".jsx": "javascript",
        ".ts": "typescript",
        ".tsx": "typescript",
        ".json": "json",
        ".md": "markdown",
        ".yml": "yaml",
        ".yaml": "yaml",
    }.get(path.suffix.lower())


def iter_files(roots: Iterable[Path], include_exts: set[str]) -> Iterator[Path]:
    for root in roots:
        if not root.exists():
            continue
        if root.is_file():
            if root.suffix.lower() in include_exts:
                yield root
            continue
        for cur_root, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in DEFAULT_EXCLUDE_DIRS]
            cur = Path(cur_root)
            for name in filenames:
                p = cur / name
                if p.suffix.lower() in include_exts:
                    yield p


def normalize_workspace_path(raw: str) -> Path:
    p = Path(raw)
    return p if p.is_absolute() else (BASE / p)


def normalize_key(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def discover_roots(conn) -> list[Path]:
    roots: list[Path] = []
    with conn.cursor() as cur:
        cur.execute("""
            select distinct unnest(array_remove(array[install_path, deployment_path, source_path], null)) as p
            from memory_projects
            where active = true
        """)
        for (p,) in cur.fetchall():
            if not p:
                continue
            path = normalize_workspace_path(p)
            if path.exists():
                roots.append(path)
    for hint in PROJECT_HINTS:
        p = BASE / hint
        if p.exists():
            roots.append(p)
    seen = set()
    out = []
    for p in roots:
        rp = str(p.resolve())
        if rp not in seen and rp.startswith(str(BASE.resolve())):
            seen.add(rp)
            out.append(p)
    return out


def make_code_unit(path: Path) -> CodeUnit:
    text = path.read_text(encoding="utf-8", errors="ignore")
    rp = relpath(path)
    lines = text.splitlines()
    title = lines[0][:240] if path.suffix.lower() == ".md" and lines else path.name
    return CodeUnit(
        unit_key=f"file:{rp}",
        unit_kind="markdown" if path.suffix.lower() == ".md" else "file",
        lang=guess_lang(path),
        workspace_path=rp,
        repo_root=rp.split("/", 1)[0] if "/" in rp else ".",
        title=title,
        symbol_name=None,
        start_line=1,
        end_line=max(len(lines), 1),
        content_hash=sha1_text(text),
        body_text=text,
        metadata={"import_phase": "phase1-expanded", "basename": path.name},
    )


def split_markdown_sections(text: str) -> list[tuple[str, int, int, str]]:
    lines = text.splitlines()
    sections: list[tuple[str, int, int, str]] = []
    current_title = "document"
    current_start = 1
    buf: list[str] = []

    def flush(end_line: int):
        nonlocal buf, current_title, current_start
        body = "\n".join(buf).strip()
        if body:
            sections.append((current_title, current_start, end_line, body))
        buf = []

    for idx, line in enumerate(lines, start=1):
        if re.match(r"^#{1,6}\s+", line):
            flush(idx - 1)
            current_title = re.sub(r"^#{1,6}\s+", "", line).strip() or "section"
            current_start = idx
            buf = [line]
        else:
            buf.append(line)
    flush(len(lines))
    if not sections and text.strip():
        sections.append(("document", 1, max(len(lines), 1), text.strip()))
    return sections


def make_context_notes(path: Path) -> list[ContextNote]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    rp = relpath(path)
    notes: list[ContextNote] = []
    for idx, (title, start, end, body) in enumerate(split_markdown_sections(text), start=1):
        note_type = "markdown_section"
        if path.parent.name == "projects":
            note_type = "project_markdown_section"
        elif path.parent.name == "memory" and DATE_FILE_RE.match(path.name):
            note_type = "daily_memory_section"
        notes.append(ContextNote(
            note_key=f"note:{rp}:{idx}",
            note_type=note_type,
            title=title[:240],
            note_text=body,
            source_kind="markdown",
            source_path=rp,
            source_line_start=start,
            source_line_end=end,
            content_hash=sha1_text(body),
            metadata={"import_phase": "phase1-expanded", "ordinal": idx},
        ))
    return notes


def path_matches(path_text: str, candidate: Optional[str]) -> bool:
    if not candidate:
        return False
    candidate_path = str(normalize_workspace_path(candidate).resolve())
    return path_text == candidate_path or path_text.startswith(candidate_path.rstrip("/") + "/")


def build_links(conn, code_unit: CodeUnit) -> list[CodeLink]:
    links: list[CodeLink] = []
    abs_path = str((BASE / code_unit.workspace_path).resolve())
    with conn.cursor() as cur:
        cur.execute("""
            select project_key, install_path, deployment_path, source_path
            from memory_projects
            where active = true
        """)
        for project_key, install_path, deployment_path, source_path in cur.fetchall():
            if any(path_matches(abs_path, x) for x in (install_path, deployment_path, source_path)):
                links.append(CodeLink(code_unit.unit_key, "belongs_to", "project", project_key, code_unit.workspace_path, 1, code_unit.end_line, {"matched_on": "project_path"}))

        cur.execute("""
            select service_key, service_path, project_key, host_key
            from memory_services
            where active = true
        """)
        for service_key, service_path, project_key, host_key in cur.fetchall():
            if path_matches(abs_path, service_path):
                links.append(CodeLink(code_unit.unit_key, "supports", "service", service_key, code_unit.workspace_path, 1, code_unit.end_line, {"matched_on": "service_path"}))
                if project_key:
                    links.append(CodeLink(code_unit.unit_key, "belongs_to", "project", project_key, code_unit.workspace_path, 1, code_unit.end_line, {"matched_on": "service_project"}))
                if host_key:
                    links.append(CodeLink(code_unit.unit_key, "runs_on", "system", host_key, code_unit.workspace_path, 1, code_unit.end_line, {"matched_on": "service_host"}))
    uniq = {(l.code_unit_key, l.link_type, l.target_type, l.target_key): l for l in links}
    return list(uniq.values())


def markdown_targets() -> list[Path]:
    files = [BASE / name for name in DEFAULT_MARKDOWN_FILES if (BASE / name).exists()]
    seen = set()
    out = []
    for p in files:
        rp = str(p.resolve())
        if rp not in seen:
            seen.add(rp)
            out.append(p)
    return out


def is_memory_markdown_path(path: Path) -> bool:
    return False


def load_project_aliases(conn) -> list[tuple[str, str, str]]:
    with conn.cursor() as cur:
        cur.execute("""
            select a.project_key, coalesce(p.name, a.alias), a.alias
            from memory_project_aliases a
            left join memory_projects p on p.project_key = a.project_key
            order by length(a.alias) desc, a.alias asc
        """)
        return [(r[0], r[1], r[2]) for r in cur.fetchall() if r[2]]


def load_hosts(conn) -> list[tuple[str, str, Optional[str]]]:
    with conn.cursor() as cur:
        cur.execute("""
            select host_key, coalesce(host_name, host_key), ip_address
            from memory_hosts
            where active = true
            order by coalesce(host_name, host_key)
        """)
        return [(r[0], r[1], r[2]) for r in cur.fetchall()]


def infer_project_from_text(text: str, source_path: str, aliases: list[tuple[str, str, str]]) -> tuple[Optional[str], Optional[str], Optional[str]]:
    lowered = text.lower()
    source_lower = source_path.lower()
    for project_key, project_name, alias in aliases:
        alias_l = alias.lower().strip()
        if alias_l and alias_l in lowered:
            return project_key, project_name, alias
    for project_key, project_name, alias in aliases:
        alias_l = alias.lower().strip()
        if alias_l and alias_l in source_lower:
            return project_key, project_name, alias
    return None, None, None


def infer_host_from_text(text: str, hosts: list[tuple[str, str, Optional[str]]]) -> tuple[Optional[str], Optional[str], Optional[str]]:
    lowered = text.lower()
    for host_key, host_name, ip_addr in hosts:
        if host_key and host_key.lower() in lowered:
            return host_key, host_name, host_key
        if host_name and host_name.lower() in lowered:
            return host_key, host_name, host_name
        if ip_addr and ip_addr in text:
            return host_key, host_name, ip_addr
    hit = HOST_CANDIDATE_RE.search(text)
    if hit:
        token = hit.group(0)
        return None, None, token
    return None, None, None


def build_descriptor(project_key, project_name, host_key, host_name, project_hint=None, host_hint=None) -> Optional[str]:
    bits = []
    if project_key or project_name or project_hint:
        bits.append(f"project={project_key or project_name or project_hint}")
    if host_key or host_name or host_hint:
        bits.append(f"host={host_key or host_name or host_hint}")
    return "; ".join(bits) if bits else None


def detect_priority(text: str) -> Optional[str]:
    lowered = text.lower()
    if any(x in lowered for x in ["critical", "never", "must", "required", "permanent"]):
        return "high"
    if any(x in lowered for x in ["should", "prefer", "recommended"]):
        return "medium"
    return None


def detect_category(text: str, source_path: str) -> Optional[str]:
    lowered = text.lower()
    if "memory" in source_path or any(x in lowered for x in ["recall", "search memory", "memory gate"]):
        return "memory_ops"
    if any(x in lowered for x in ["report", "include exact", "rollback", "redeploy"]):
        return "reporting"
    if any(x in lowered for x in ["service", "docker", "deploy", "host", "ssh"]):
        return "ops"
    return "directive"


def make_directive_records(path: Path) -> list[DirectiveRecord]:
    rp = relpath(path)
    out: list[DirectiveRecord] = []
    for idx, (title, start, end, body) in enumerate(split_markdown_sections(path.read_text(encoding="utf-8", errors="ignore")), start=1):
        if not DIRECTIVE_RE.search(body):
            continue
        directive_text = body.strip()
        out.append(DirectiveRecord(
            directive_key=f"directive:{rp}:{idx}:{sha1_text(directive_text)[:12]}",
            directive_text=directive_text,
            category=detect_category(directive_text, rp),
            priority=detect_priority(directive_text),
            effective_date=path.stem if DATE_FILE_RE.match(path.name) else None,
            source_path=rp,
            source_line_start=start,
            source_line_end=end,
            tags=["markdown", "imported", "phase1-expanded"],
        ))
    return out


def make_runbook_records(path: Path) -> list[RunbookRecord]:
    rp = relpath(path)
    out: list[RunbookRecord] = []
    for idx, (title, start, end, body) in enumerate(split_markdown_sections(path.read_text(encoding="utf-8", errors="ignore")), start=1):
        if not RUNBOOK_RE.search(body):
            continue
        if len(body.splitlines()) < 2 and len(body) < 80:
            continue
        out.append(RunbookRecord(
            runbook_key=f"runbook:{rp}:{idx}",
            title=(title or "runbook")[:240],
            scope="markdown_memory",
            trigger_text=title[:240] if title else None,
            procedure_text=body.strip(),
            source_path=rp,
            source_line_start=start,
            source_line_end=end,
            tags=["markdown", "imported", "phase1-expanded"],
        ))
    return out


def iter_log_candidates(path: Path) -> Iterator[tuple[int, int, str]]:
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    for line_no, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            continue
        m = TIMESTAMP_PREFIX_RE.match(stripped)
        if m:
            yield line_no, line_no, m.group(2).strip()
        elif ACTION_RE.search(stripped) or CODE_CHANGE_RE.search(stripped):
            yield line_no, line_no, stripped.lstrip("-* ")


def make_action_and_change_logs(path: Path, aliases, hosts) -> tuple[list[ActionLog], list[CodeChangeLog]]:
    rp = relpath(path)
    actions: list[ActionLog] = []
    changes: list[CodeChangeLog] = []
    for line_start, line_end, body in iter_log_candidates(path):
        project_key, project_name, project_hint = infer_project_from_text(body, rp, aliases)
        host_key, host_name, host_hint = infer_host_from_text(body, hosts)
        descriptor = build_descriptor(project_key, project_name, host_key, host_name, project_hint, host_hint)
        summary = body[:240]
        file_paths = PATH_RE.findall(body)
        normalized_files = []
        for item in file_paths:
            try:
                p = Path(item)
                if p.exists() and str(p.resolve()).startswith(str(BASE.resolve())):
                    normalized_files.append(relpath(p))
                else:
                    normalized_files.append(item)
            except Exception:
                normalized_files.append(item)
        if ACTION_RE.search(body):
            action_kind = "memory_daily_entry" if DATE_FILE_RE.match(path.name) else "memory_project_note"
            actions.append(ActionLog(
                action_key=f"action:{rp}:{line_start}:{sha1_text(body)[:12]}",
                action_kind=action_kind,
                summary=summary,
                detail_text=body,
                source_path=rp,
                source_line_start=line_start,
                source_line_end=line_end,
                project_key=project_key,
                project_name=project_name,
                host_key=host_key,
                host_name=host_name,
                descriptor_text=descriptor,
                content_hash=sha1_text(body),
                metadata={"import_phase": "phase1-expanded", "source_file": path.name},
            ))
        if CODE_CHANGE_RE.search(body):
            changes.append(CodeChangeLog(
                change_key=f"codechange:{rp}:{line_start}:{sha1_text(body)[:12]}",
                change_kind="memory_code_change",
                summary=summary,
                detail_text=body,
                source_path=rp,
                source_line_start=line_start,
                source_line_end=line_end,
                project_key=project_key,
                project_name=project_name,
                host_key=host_key,
                host_name=host_name,
                descriptor_text=descriptor,
                file_paths=normalized_files,
                content_hash=sha1_text(body),
                metadata={"import_phase": "phase1-expanded", "source_file": path.name},
            ))
    return actions, changes


def execute_many(conn, sql: str, rows: list[tuple]):
    if not rows:
        return
    with conn.cursor() as cur:
        cur.executemany(sql, rows)


def upsert_code_units(conn, units: list[CodeUnit]):
    rows = [(
        u.unit_key, u.unit_kind, u.lang, u.workspace_path, u.repo_root, u.title, u.symbol_name,
        u.start_line, u.end_line, u.content_hash, u.body_text, Json(u.metadata)
    ) for u in units]
    execute_many(conn, """
        insert into memory_code_units (
            unit_key, unit_kind, lang, workspace_path, repo_root, title, symbol_name,
            start_line, end_line, content_hash, body_text, metadata
        ) values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        on conflict (unit_key) do update set
            unit_kind = excluded.unit_kind,
            lang = excluded.lang,
            workspace_path = excluded.workspace_path,
            repo_root = excluded.repo_root,
            title = excluded.title,
            symbol_name = excluded.symbol_name,
            start_line = excluded.start_line,
            end_line = excluded.end_line,
            content_hash = excluded.content_hash,
            body_text = excluded.body_text,
            metadata = excluded.metadata,
            updated_at = now(),
            active = true
    """, rows)


def upsert_context_notes(conn, notes: list[ContextNote]):
    rows = [(
        n.note_key, n.note_type, n.title, n.note_text, n.source_kind, n.source_path,
        n.source_line_start, n.source_line_end, n.content_hash, Json(n.metadata)
    ) for n in notes]
    execute_many(conn, """
        insert into memory_context_notes (
            note_key, note_type, title, note_text, source_kind, source_path,
            source_line_start, source_line_end, content_hash, metadata
        ) values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        on conflict (note_key) do update set
            note_type = excluded.note_type,
            title = excluded.title,
            note_text = excluded.note_text,
            source_kind = excluded.source_kind,
            source_path = excluded.source_path,
            source_line_start = excluded.source_line_start,
            source_line_end = excluded.source_line_end,
            content_hash = excluded.content_hash,
            metadata = excluded.metadata,
            updated_at = now(),
            active = true
    """, rows)


def upsert_code_links(conn, links: list[CodeLink]):
    rows = [(
        l.code_unit_key, l.link_type, l.target_type, l.target_key, l.source_path,
        l.source_line_start, l.source_line_end, Json(l.metadata)
    ) for l in links]
    execute_many(conn, """
        insert into memory_code_links (
            code_unit_key, link_type, target_type, target_key, source_path,
            source_line_start, source_line_end, metadata
        ) values (%s,%s,%s,%s,%s,%s,%s,%s)
        on conflict (code_unit_key, link_type, target_type, target_key) do update set
            source_path = excluded.source_path,
            source_line_start = excluded.source_line_start,
            source_line_end = excluded.source_line_end,
            metadata = excluded.metadata
    """, rows)


def upsert_action_logs(conn, logs: list[ActionLog]):
    rows = [(
        x.action_key, x.action_kind, x.summary, x.detail_text, x.source_path, x.source_line_start,
        x.source_line_end, x.project_key, x.project_name, x.host_key, x.host_name,
        x.descriptor_text, x.content_hash, Json(x.metadata)
    ) for x in logs]
    execute_many(conn, """
        insert into memory_action_logs (
            action_key, action_kind, summary, detail_text, source_path, source_line_start,
            source_line_end, project_key, project_name, host_key, host_name,
            descriptor_text, content_hash, metadata
        ) values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        on conflict (action_key) do update set
            action_kind = excluded.action_kind,
            summary = excluded.summary,
            detail_text = excluded.detail_text,
            source_path = excluded.source_path,
            source_line_start = excluded.source_line_start,
            source_line_end = excluded.source_line_end,
            project_key = excluded.project_key,
            project_name = excluded.project_name,
            host_key = excluded.host_key,
            host_name = excluded.host_name,
            descriptor_text = excluded.descriptor_text,
            content_hash = excluded.content_hash,
            metadata = excluded.metadata,
            updated_at = now(),
            active = true
    """, rows)


def upsert_code_change_logs(conn, logs: list[CodeChangeLog]):
    rows = [(
        x.change_key, x.change_kind, x.summary, x.detail_text, x.source_path, x.source_line_start,
        x.source_line_end, x.project_key, x.project_name, x.host_key, x.host_name,
        x.descriptor_text, x.file_paths, x.content_hash, Json(x.metadata)
    ) for x in logs]
    execute_many(conn, """
        insert into memory_code_change_logs (
            change_key, change_kind, summary, detail_text, source_path, source_line_start,
            source_line_end, project_key, project_name, host_key, host_name,
            descriptor_text, file_paths, content_hash, metadata
        ) values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        on conflict (change_key) do update set
            change_kind = excluded.change_kind,
            summary = excluded.summary,
            detail_text = excluded.detail_text,
            source_path = excluded.source_path,
            source_line_start = excluded.source_line_start,
            source_line_end = excluded.source_line_end,
            project_key = excluded.project_key,
            project_name = excluded.project_name,
            host_key = excluded.host_key,
            host_name = excluded.host_name,
            descriptor_text = excluded.descriptor_text,
            file_paths = excluded.file_paths,
            content_hash = excluded.content_hash,
            metadata = excluded.metadata,
            updated_at = now(),
            active = true
    """, rows)


def upsert_directives(conn, directives: list[DirectiveRecord]):
    if not directives:
        return
    with conn.cursor() as cur:
        for d in directives:
            cur.execute(
                "delete from memory_directives where source_path = %s and source_line_start = %s and source_line_end = %s",
                (d.source_path, d.source_line_start, d.source_line_end),
            )
            cur.execute(
                """
                insert into memory_directives (
                    id, source_path, source_line_start, source_line_end, directive_text,
                    category, priority, effective_date, tags, active, created_at, updated_at
                ) values (gen_random_uuid(),%s,%s,%s,%s,%s,%s,%s,%s,true,now(),now())
                """,
                (d.source_path, d.source_line_start, d.source_line_end, d.directive_text,
                 d.category, d.priority, d.effective_date, d.tags),
            )


def upsert_runbooks(conn, runbooks: list[RunbookRecord]):
    rows = [(
        r.runbook_key, r.title, r.scope, r.trigger_text, r.procedure_text,
        r.source_path, r.source_line_start, r.source_line_end, r.tags
    ) for r in runbooks]
    execute_many(conn, """
        insert into memory_runbooks (
            id, runbook_key, title, scope, trigger_text, procedure_text,
            source_path, source_line_start, source_line_end, tags, active, created_at, updated_at
        ) values (gen_random_uuid(),%s,%s,%s,%s,%s,%s,%s,%s,%s,true,now(),now())
        on conflict (runbook_key) do update set
            title = excluded.title,
            scope = excluded.scope,
            trigger_text = excluded.trigger_text,
            procedure_text = excluded.procedure_text,
            source_path = excluded.source_path,
            source_line_start = excluded.source_line_start,
            source_line_end = excluded.source_line_end,
            tags = excluded.tags,
            updated_at = now(),
            active = true
    """, rows)


def main():
    ap = argparse.ArgumentParser(description="Import expanded phase-1 code/memory structure into Postgres")
    ap.add_argument("--dry-run", action="store_true", help="inspect counts only")
    ap.add_argument("--limit", type=int, default=0, help="cap number of scanned code files for testing")
    args = ap.parse_args()

    with connect() as conn:
        roots = discover_roots(conn)
        code_paths = list(iter_files(roots, DEFAULT_INCLUDE_EXTS))
        if args.limit and args.limit > 0:
            code_paths = code_paths[:args.limit]
        md_paths = markdown_targets()
        aliases = load_project_aliases(conn)
        hosts = load_hosts(conn)

        units = [make_code_unit(p) for p in code_paths]
        notes: list[ContextNote] = []
        directives: list[DirectiveRecord] = []
        runbooks: list[RunbookRecord] = []
        action_logs: list[ActionLog] = []
        code_change_logs: list[CodeChangeLog] = []

        for p in md_paths:
            notes.extend(make_context_notes(p))
            if is_memory_markdown_path(p):
                directives.extend(make_directive_records(p))
                runbooks.extend(make_runbook_records(p))
                actions, changes = make_action_and_change_logs(p, aliases, hosts)
                action_logs.extend(actions)
                code_change_logs.extend(changes)

        links: list[CodeLink] = []
        for unit in units:
            links.extend(build_links(conn, unit))

        summary = {
            "roots": [str(p) for p in roots],
            "code_files": len(code_paths),
            "markdown_files": len(md_paths),
            "code_units": len(units),
            "context_notes": len(notes),
            "code_links": len(links),
            "action_logs": len(action_logs),
            "code_change_logs": len(code_change_logs),
            "directives": len(directives),
            "runbooks": len(runbooks),
        }
        print(json.dumps(summary, indent=2))

        if args.dry_run:
            conn.rollback()
            return

        upsert_code_units(conn, units)
        upsert_context_notes(conn, notes)
        upsert_code_links(conn, links)
        upsert_action_logs(conn, action_logs)
        upsert_code_change_logs(conn, code_change_logs)
        upsert_directives(conn, directives)
        upsert_runbooks(conn, runbooks)
        conn.commit()


if __name__ == "__main__":
    main()
