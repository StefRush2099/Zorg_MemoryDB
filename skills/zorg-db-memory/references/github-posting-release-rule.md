# GitHub Posting / Release Rule

This reference is a hard gate for Zorg_MemoryDB GitHub publishing.

A GitHub update is not complete when only a file exists, an API tree lists it, or a package archive contains it. A GitHub update is complete only when all affected surfaces are updated and the rendered GitHub pages are visually verified.

## Required full-surface checklist

- Backend Zorg MemoryDB recall first.
- Load `zorg-db-memory` and GitHub guidance before GitHub work.
- Inspect local branch, dirty status, remote state, latest release, tags, and GitHub repository metadata.
- Verify GitHub `isFork`, parent, repository description, homepage URL, topics, default branch, and public visibility. If the repository should not be a fork, `isFork` must be false before claiming completion.
- Preserve existing public screenshots/assets additively unless exact removal was requested.
- Review screenshot pixels before commit or report.
- Use the correct source system for screenshots; local personal screenshots
  must show the installation's configured agent identity and host rather than a
  hard-coded public-package identity or address.
- Correct dark/light mode content, not only filenames.
- Update every affected surface: GitHub repository metadata, README, docs, screenshots, changelog, release notes, package metadata, package scripts, verification scripts, skill package files, support code, tarball, tag, GitHub Release body, and Release asset.
- Include the complete PostgreSQL scheduler source for every core MemoryDB maintenance job: schedule-table seed/upsert definitions, PostgreSQL function definitions, job-to-function catalog, and verification/count checks. Compare it with live `public.memory_db_scheduled_jobs`; a core job that exists only in the live database or only in a runtime deployment output is a release failure.
- Before every GitHub update or release, run the canonical LAN Chat version synchronizer. Root package, LAN package, and LAN lock versions must match. The gauge must derive its label from package metadata and emit the dedicated `data-lan-chat-gauge-version` marker.
- Build both packaged and live LAN Chat, restart only LAN Chat, and verify the exact canonical version in the gauge-specific compiled chunk and the authenticated rendered gauge. Unrelated version strings, redirects, source maps, framework dependencies, and lockfiles are not rendered proof. A mismatch blocks packaging, push, tag, release creation, and asset publication.
- Rebuild package archive after content changes.
- Run public-package verification, secret scan, generated-artifact scan, archive-content check, and DB health checks.
- Push exact commit and tag.
- Verify remote commit/tag/release/asset and repository metadata with `gh` or GitHub API.
- Use browser verification of the rendered GitHub main page and related docs/release pages before claiming success.
- Send or save proof screenshots when the operator is checking visual output.

## Failure behavior

If any surface is missing, stale, incorrectly ordered, visually wrong, or sourced from the wrong system, the release is not done. Stop claiming success, correct the affected surface, rebuild and republish the release, then verify rendered GitHub output again.
