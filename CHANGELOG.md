# Changelog

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
