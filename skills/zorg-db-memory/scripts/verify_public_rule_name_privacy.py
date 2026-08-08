#!/usr/bin/env python3
"""Fail closed when public rule/export material contains private operator identifiers."""

from __future__ import annotations

import argparse
import io
import re
import sys
import tarfile
import tempfile
import zipfile
from pathlib import Path

# Keep forbidden identifiers out of authored public source while still testing them.
_FIRST = "Ste" + "fan"
_FULL = _FIRST + " " + "Rush"
_USERNAME = "Stef" + "Rush"
_PATTERNS = (
    re.compile(r"(?i)(?<![A-Za-z0-9_])" + re.escape(_FULL) + r"(?![A-Za-z0-9_])"),
    re.compile(r"(?i)(?<![A-Za-z0-9_])" + re.escape(_FIRST) + r"(?![A-Za-z0-9_])"),
    re.compile(r"(?i)(?<![A-Za-z0-9_])" + re.escape(_USERNAME) + r"(?![A-Za-z0-9_])"),
)
_SKIP_DIRS = {".git", "node_modules", "__pycache__", ".pytest_cache", ".mypy_cache"}
_ARCHIVE_SUFFIXES = (".tar", ".tar.gz", ".tgz", ".zip")
_MAX_MEMBER_BYTES = 32 * 1024 * 1024


def _matches(data: bytes) -> bool:
    text = data.decode("utf-8", errors="ignore")
    return any(pattern.search(text) for pattern in _PATTERNS)


def _archive_findings(path: Path) -> list[str]:
    findings: list[str] = []
    lower = path.name.lower()
    try:
        if lower.endswith(".zip"):
            with zipfile.ZipFile(path) as archive:
                for info in archive.infolist():
                    if info.is_dir() or info.file_size > _MAX_MEMBER_BYTES:
                        continue
                    if _matches(archive.read(info)):
                        findings.append(f"{path}!{info.filename}")
        elif lower.endswith((".tar", ".tar.gz", ".tgz")):
            with tarfile.open(path, "r:*") as archive:
                for member in archive.getmembers():
                    if not member.isfile() or member.size > _MAX_MEMBER_BYTES:
                        continue
                    handle = archive.extractfile(member)
                    if handle is not None and _matches(handle.read()):
                        findings.append(f"{path}!{member.name}")
    except (OSError, tarfile.TarError, zipfile.BadZipFile) as exc:
        findings.append(f"{path}!UNREADABLE_ARCHIVE:{exc}")
    return findings


def scan(paths: list[Path]) -> list[str]:
    findings: list[str] = []
    files: list[Path] = []
    for path in paths:
        if path.is_file():
            files.append(path)
        elif path.is_dir():
            files.extend(p for p in path.rglob("*") if p.is_file() and not (_SKIP_DIRS & set(p.parts)))
        else:
            findings.append(f"{path}!MISSING")
    for path in sorted(set(files)):
        if path.name.lower().endswith(_ARCHIVE_SUFFIXES):
            findings.extend(_archive_findings(path))
            continue
        try:
            data = path.read_bytes()
        except OSError as exc:
            findings.append(f"{path}!UNREADABLE:{exc}")
            continue
        if _matches(data):
            findings.append(str(path))
    return findings


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="public-rule-privacy-") as temp:
        root = Path(temp)
        clean = root / "clean.txt"
        dirty = root / "dirty.txt"
        dirty_zip = root / "dirty.zip"
        clean.write_text("The operator approves public-safe rules.\n", encoding="utf-8")
        dirty.write_text("Rule owner: " + _FULL + "\n", encoding="utf-8")
        with zipfile.ZipFile(dirty_zip, "w") as archive:
            archive.writestr("rules.txt", "Operator: " + _USERNAME)
        if scan([clean]):
            raise RuntimeError("clean fixture was rejected")
        if str(dirty) not in scan([dirty]):
            raise RuntimeError("plain-text contamination was not rejected")
        if not any("rules.txt" in item for item in scan([dirty_zip])):
            raise RuntimeError("archive contamination was not rejected")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="*", type=Path, default=[Path.cwd()])
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    findings = scan(args.paths)
    if findings:
        for item in findings:
            print(item)
        return 1
    print("public rule personal-name privacy scan: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
