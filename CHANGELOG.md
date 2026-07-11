# Changelog

## v1.2.70 - 2026-07-11

- Removes generated PostgreSQL passwords from the default local installer path.
- Adds passwordless loopback-only authentication for the local `zorg` role.
- Rejects unauthenticated remote database configuration and documents the boundary.

## v1.2.69 - 2026-07-11

- Syncs the canonical `zorg-db-memory` skill with DB-first fact-summary, GO-gate, and additive ANN/vector recall tuning rules.
- Updates the bundled and installer-copied MemoryDB Python tools to use DB-owned stored-procedure recall APIs and due-job enqueue behavior.
- Adds public-safe stored-procedure migration files for the recall API, bounded recall paths, semantic source lookup, search/table helpers, and generic due-job enqueue support.
- Preserves the v1.2.68 GitHub repository metadata/fork verification safeguards.

## v1.2.68 - 2026-07-10

- Corrects GitHub repository metadata so the project is no longer positioned as an OpenClaw fork.
- Clarifies current documentation wording: Zorg MemoryDB is an add-on package for OpenClaw, not a GitHub fork or vendored source copy.
- Extends the GitHub posting/release rule to require repository metadata and fork-network verification as part of full-surface release checks.

## v1.2.67 - 2026-07-10

- Corrects the packaged `zorg-db-memory` skill metadata description after the GitHub posting gate restore.
- Keeps the canonical DB-first, Rule Zero, markdown lockout, supporting-services, and GitHub posting/release rules together in the exported skill.
- Rebuilds and republishes the package so the live skill and GitHub package metadata match.

## v1.2.66 - 2026-07-10

- Adds the hard GitHub posting/release rule to the packaged `zorg-db-memory` skill.
- Requires full-surface updates across README, docs, changelog, release notes, package metadata, tarball, tag, GitHub Release, and release asset.
- Requires visual review of screenshots before commit/report and browser verification of rendered GitHub pages before claiming success.

## v1.2.65 - 2026-07-10

- Replaced LAN Command Chat Memory 3D toggle screenshots with reviewed captures from the local `Zorg Rush` system.
- Corrected the dark-mode toggle screenshots so dark mode is actually active.
- Reordered README and screenshot docs so original LAN Command Chat screenshots come first and newer Memory Brain 3D screenshots follow.

## v1.2.64 - 2026-07-10

- Restored screenshots directly on the GitHub main README page.
- Kept original LAN Command Chat screenshots visible from `docs/assets/`.
- Kept Memory Brain 3D and LAN Command Chat Memory 3D toggle screenshots visible from `docs/screenshots/`.

## v1.2.63 - 2026-07-10

- Synchronized the packaged `zorg-db-memory` skill metadata with the corrected live canonical skill description.
- Rebuilt the package archive with the screenshot preservation and supporting-services corrections intact.

## v1.2.62 - 2026-07-10

- Preserved and documented the original LAN Command Chat screenshots as additive release assets.
- Added the supporting-services reference to the packaged `zorg-db-memory` skill.
- Documented expected discovery/install-request behavior for cloudflared, ComfyUI, Kokoro FastAPI, MediaMTX, Ollama, SearXNG, and faster-whisper.
- Tightened package verification to reject Python cache artifacts.
- Rebuilt the release package without generated Python cache files.

## v1.2.61 - 2026-07-10

- Restructured the public repository around `zorg-db-memory`.
- Removed the vendored OpenClaw implementation from the current tree.
- Added OpenClaw base-install documentation.
- Added the full live `zorg-db-memory` skill package.
- Kept public-safe Zorg MemoryDB support code under `package/zorg`.
- Added public screenshot documentation and release notes.
- Added Memory Brain 3D desktop/mobile screenshots in light and dark modes.
- Added LAN Command Chat Memory 3D toggle-panel screenshots.
- Removed public-package scheduled publishing instructions so installed agents do not inherit maintainer-only release behavior.
