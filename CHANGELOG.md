# Changelog

## 4.1.2 - 2026-08-08

- Publish the working fail-closed OpenClaw turn gate with exact-request PostgreSQL recall receipts.
- Hold requests during database failure, permit only bounded recovery operations, and suppress duplicate outage/restoration alerts.
- Add connector installation, recovery, rollback, and 13-gate acceptance runbooks based on official PostgreSQL 18, pgvector, OpenClaw, and GitHub guidance.
- Replace stale skill routing that could recreate delegated executors or parallel memory fallbacks.
- Add turn-gate regression tests and strengthen version, gauge, privacy, archive, and release verification.
- Align the root package, plugin/MCP, packaged/live LAN Command Chat, release archive, tag, and visible gauge at `v4.1.2`.

## 4.1.1

- Supply the complete PostgreSQL core scheduler migration and canonical seeds.
- Reconcile pg_cron firing jobs without duplicates.
- Include the production dispatcher prompt-contract and portable workspace fixes.
- Harden install defaults and release verification.

## v4.1.0 - 2026-07-23

- Adds the complete public-safe MemoryDB self-repair contract, runtime
  compatibility helpers, canonical preflight ordering, bounded/exact recall
  improvements, and rule-scope deduplication.
- Strengthens ANN/semantic processing with provider defaults, automatic vector
  repair, Ollama synchronization, semantic-worker telemetry compatibility, and
  additive source preservation.
- Extends the OpenClaw-native plugin/MCP tools and aligns source, distribution,
  manifest, package, LAN Command Chat, and release metadata at `4.1.0`.
- Packages the PostgreSQL-owned LLM dispatcher systemd unit and makes installer
  failures explicit instead of silently accepting incomplete database,
  plugin, trigger, or service activation.
- Updates LAN Command Chat routing, prompt compilation, Compose/nginx defaults,
  and package locks while keeping it separate from Neural Recall Activity.
- Preserves the public Neural Recall Activity browser assets and explicitly
  excludes the retired `package/zorg/memory-3d/` server package.
- Adds release gates for version consistency, public/private separation,
  retired-package exclusion, archive integrity, and source/distribution parity.
- Installation and upgrade testing is intentionally delegated to a different
  OpenClaw agent on a genuine target system; the source system is not used as
  an installation target.

## v4.0.1 - 2026-07-21

- Removes the retired Memory 3D package.
- Adds production Neural Recall Activity assets and install guidance for port
  8097.
- Aligns package metadata to 4.0.1.

## v4.0.0 - 2026-07-20

- Major release: makes the OpenClaw-native `zorg-memorydb` plugin/MCP the sole
  initialized and highest-priority durable-memory path.
- Aligns package, plugin, MCP, LAN Command Chat, lockfile, and gauge metadata at
  `4.0.0`.
- Publishes an explicit command-line GitHub installation path and upgrade/removal
  boundaries; PostgreSQL source data is preserved while prior Zorg package files
  are removed before installation.
- Removes remaining installer and package behavior that creates, copies, imports,
  or activates Markdown memory/rule files. Markdown is not a fallback store.


## v3.0.6 - 2026-07-19

- Completes the OpenClaw-native Zorg MemoryDB plugin/MCP package path.
- Adds read-only ANN/semantic status and canonical recall-preflight tools.
- Aligns package, plugin, MCP, and LAN Command Chat versions at 3.0.6.
- Makes the plugin resolve the SQL map through portable workspace environment
  variables and verifies the sanitized public archive.
- Removes installer creation/copying of Markdown rule and memory files,
  removes the legacy Markdown-rule importer and packaged rule files, and makes
  the native plugin/MCP the only initialized memory path.

## v3.0.5 - 2026-07-19

- Publishes the OpenClaw-native Zorg MemoryDB plugin and standalone MCP server
  as part of the canonical skill package.
- Aligns the root package, LAN Command Chat package/lockfile, plugin manifest,
  and gauges to 3.0.5.
- Documents complete previous-package removal, backend-database preservation,
  required PostgreSQL/ANN/vector dependencies, runtime inspection, and the
  mandatory post-update version announcement.
- Keeps all source memory in PostgreSQL and requires additive ANN/vector repair
  and verification rather than a legacy fallback.

## v3.0.4 - 2026-07-18

- Aligns the packaged Memory Brain 3D runtime label with the documented
  Neural Recall Activity surface across server defaults, HTML, and client
  fallback configuration.
- Removes the stale user-facing Memory Brain Status label from the shipped
  runtime while preserving the PostgreSQL-backed recall and ANN wiring.

## v3.0.2 - 2026-07-17

- Corrects the LAN Command Chat gauge release readout and live product package
  metadata to v3.0.2 before publication, superseding v3.0.1.
- Keeps the packaged LAN Command Chat source and lockfile aligned with the
  product currently used by the runtime.

## v3.0.1 - 2026-07-17

- Publishes the live rule-feedback repair as a patch release, preserving the
  existing `zorg_record_logic_rule_feedback` procedure and its canonical UUID
  queue payload.
- Adds public-safe trigger wiring that queues additive semantic/ANN work from
  captured operational rows without pruning or replacing source records.
- Adds a database view for verifying which captured tables have semantic queue
  triggers, and keeps the LAN Command Chat package version aligned.

## v3.0.0 - 2026-07-17

- Publishes the complete work-capture structure: turn manifests, immutable
  event occurrences, complete content blobs, explicit capture gaps, code
  artifact and before/after/patch records, tool/model payload evidence, and
  provenance links.
- Connects captured occurrences to the queued semantic worker, embeddings,
  ANN provenance, exact-repeat derived groups, weighted semantic relationships,
  recall hints, and ANN autoheal without replacing source records.
- Packages the LAN Command Chat PostgreSQL integration and its shared
  `SQL_MEMORY_MAP`/`ZORG_SQL_MEMORY_MAP` runtime contract with the same release.
- Aligns the LAN Command Chat package version, skill documentation, migration
  catalog, install procedures, and verification gates at 3.0.0.
- Adds public-package sanitization and structural release verification so
  secrets, private values, and generated artifacts are excluded without
  pruning public-safe schema or procedure definitions.

## v2.0.18 - 2026-07-15

- Deactivates stale ANN embeddings when an active rule's content changes, so
  semantic recall cannot return superseded rule text.
- Keeps the LAN Command Chat gauge version aligned with the root package.

## v2.0.17 - 2026-07-15

- Canonicalizes current-install backup/recovery variables using
  `OPENCLAW_WORKSPACE`/`WORKSPACE_DIR` and `OPENCLAW_HOME`.
- Adds the skill-owned public/private rule-scope and safe dedup migration;
  repeated markdown fragments remain as inactive provenance rather than active
  duplicate behaviors.
- Adds canonical DB recall/timing, credential-source, and rule-failure-lockout
  structures with bounded weights, recall hints, and semantic refresh queueing.
- Preserves the release gate that the LAN Command Chat gauge version exactly
  matches the root package version.

## v2.0.16 - 2026-07-15

- Adds the core-rule preflight pipeline so the summary/uppercase-GO mutation gate is rank 1 before normal rule, weighted, lexical, or ANN recall.
- Adds bounded dynamic weighting, a semantic `precedes -> all_core_rules` edge, a dedicated PostgreSQL preflight function, and rank-order regression verification.

## v2.0.14 - 2026-07-15

- Documents the verified native PostgreSQL 18.4 deployment path and clean-cluster logical-restore cutover.
- Records the acceptance checks for structured, weighted, semantic, and ANN/vector recall plus LAN Command Chat and Memory Brain 3D.
- Explicitly excludes the retired PostgreSQL container, rollback volume, database data, dumps, logs, credentials, and generated build artifacts from the public package.
- Carries the latest public-safe LAN Command Chat CSS correction and keeps generated workspace output ignored.
- Adds a release gate requiring the LAN Command Chat gauge version to match the GitHub package version, with automated mismatch verification.

## v2.0.15 - 2026-07-15

- Promotes the fact-based summary and uppercase GO-before-mutation gate to a core system rule for every system change.
- Repairs ANN recall for the gate using canonical logic-rule UUID queueing, six high-weight aliases, cached regression queries, and durable query observations.
- Classifies the 11 requested MemoryDB schedules as `core_llm`, removes personal routing/attribution, and keeps ANN executors inside the canonical skill.

## v2.0.13 - 2026-07-12

- Completes the ANN/vector bootstrap with canonical `zorg_memory` queueing, savepoint-safe worker retries, legacy queue isolation, configurable provider/model settings, and a working query-embedding cache.


## v2.0.12 - 2026-07-12

- Publishes the idempotent ANN/vector recall bootstrap, supported `nomic-embed-text:latest` defaults, embedding worker, query-cache helper, scheduled jobs, and upgrade migration so clean installs and existing installs share the same recall path.


## v2.0.11 - 2026-07-12

- Corrects the browser Context window gauge to display live tokens in use
  against the live token limit instead of a percentage-only readout.
- Makes the visible gauge-tile release stamp derive from the browser package
  version and align it with the published release.

## v2.0.10 - 2026-07-12

- Publishes the browser LAN Command Chat `Context window` gauge with the
  release version stamp shown immediately before `DB size` in the gauge tile.
- Aligns the public package and browser application metadata at version
  `2.0.10` so agents with `2.0.9` can identify the update.

## v2.0.9 - 2026-07-12

- Replaces the Android WebView/pass-through shell with a native Android chat,
  history, composer, theme selector, live gauge, and Memory 3D surface.
- Adds a native authenticated login dialog with persisted signed-cookie state;
  SSH credentials and LAN Chat credentials remain separate.
- Removes the Android dependency on the OpenClaw TUI and web `/chat` route.
- Reads chat, history, database metrics, and Memory 3D graph data through live
  authenticated JSON contracts and reports degraded data instead of faking it.
- Adds native System/Light/Dark selection and aligns the Android build metadata.
- Repairs the Memory 3D installer path by installing service dependencies,
  creating/enabling `zorg-memory-3d`, adding bounded PostgreSQL query timeouts,
  and documenting `/api/health` and `/api/graph` verification.
- Clarifies that browser LAN Chat and native Android are separate surfaces; the
  browser owns the APK download link and browser theme controls.

## v2.0.8 - 2026-07-12

- Rebuilds the Android client around the real responsive LAN Command Chat
  `/chat` surface instead of a separate native imitation.
- Uses the variable-driven LAN route and phone system theme so light and dark
  mode follow the connected Android device.
- Keeps the mobile page scrollable so the live gauges and Memory 3D/Gauges
  toggle remain reachable below the conversation surface.
- Aligns the Android package metadata with the verified install and preserves
  the connected Memory Brain 3D surface.
- Retains the mandatory Zorg MemoryDB recall, timing-summary, screenshot-review,
  and full-surface publication gates.

## v2.0.4 - 2026-07-11

- Replaces the LAN Command Chat Compact control with a stable Android app
  download link backed by the latest verified GitHub release APK.
- Bumps the Android client to version 2.0.4 for the installable release.

## v2.0.3 - 2026-07-11

- Completes the Android client telemetry surface with native Queries/sec, Cache
  hit, Writes/sec, DB size, and Context window readouts.
- Corrects the Android release to include all four LAN Command Chat gauges
  before publication.

## v2.0.2 - 2026-07-11

- Adds a native Android LAN Command Chat client with a real chat window,
  internet/local route selection, status/context telemetry, and Memory Brain
  3D access.
- Adds the Android client to the public package without private credentials,
  scheduler settings, or machine-local SDK artifacts.
- Makes ComfyUI image generation part of the canonical `zorg-db-memory` skill
  with a single fixed seed file and configurable server/output paths.
- Includes the operator-correction migration in clean installs.

## v2.0.1 - 2026-07-11

- Removes superseded release notes and archives from the active package tree.
- Makes release archives contain only the current release note instead of the
  entire historical `release/` directory.
- Makes legacy `memory/**/*.md` migration opt-in so clean installs do not ingest
  historical markdown by default.

## v1.2.72 - 2026-07-11

- Publishes the current LAN Command Chat PostgreSQL gauges and Memory 3D
  toggle that were previously left on an unreleased branch.
- Adds the connected Memory Brain 3D source bundle to the public install
  package and installs it through the configurable `MEMORY_3D_DIR` path.
- Advances the package release number so checkout and update checks detect the
  gauge update.

## v1.2.71 - 2026-07-11

- Makes MemoryDB worker, installer, backup, recovery, dispatcher, and recall-tool paths resolve from `OPENCLAW_WORKSPACE`, `WORKSPACE_DIR`, `SQL_MEMORY_MAP`, and related variables instead of an operator-specific `/home/openclaw` path.
- Updates LAN Command Chat to resolve its workspace, sessions, OpenClaw binary, and PostgreSQL map from environment-driven paths.
- Updates Memory Brain 3D to use the same `SQL_MEMORY_MAP`/PostgreSQL configuration contract and records the shared-surface verification requirement in the skill.
- Verifies the Vorg path contract with `/home/vorg/.openclaw/workspace`.

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
## 3.0.3 - 2026-07-17

- Apply and verify the semantic-capture trigger migration during installation.
- Document the ANN query-embedding cache prerequisite for uncached queries.
