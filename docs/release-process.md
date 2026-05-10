# Release, Package, and Version-Control Process

Zorg is responsible for keeping this repository, its package structure, and its published install artifacts coherent.

## Rule: every meaningful update gets a release

Every meaningful structural, install, Docker/Dockge, schema, recall, routing, workflow, documentation, or packaging update must be followed by:

1. commit to `main`
2. push to GitHub
3. semantic version tag
4. GitHub Release
5. GHCR container image build/publish
6. release notes describing changes and verification

Patch-only typo/docs clarifications may be grouped, but any install/runtime/schema/recall/rule/recovery behavior change must receive a new release promptly. Releases should not lag behind meaningful changes; users need to see what changed.

## Versioning

Use semantic versioning:

- `MAJOR` for incompatible install/runtime structure changes
- `MINOR` for new install paths, packaging, schema surfaces, workflows, or additive features
- `PATCH` for compatible fixes and documentation corrections

Tags use `vMAJOR.MINOR.PATCH`, for example:

```bash
git tag -a v1.1.0 -m "v1.1.0"
git push origin v1.1.0
```

Pushing a `v*.*.*` tag triggers `.github/workflows/release.yml`, which:

- validates shell, Python, and Compose config
- builds the single-container Docker image
- publishes `ghcr.io/stefrush2099/zorg-memorydb:<version>`
- publishes/updates `ghcr.io/stefrush2099/zorg-memorydb:latest`
- generates provenance attestation
- creates the GitHub Release

## Release notes

For curated release notes, create:

```text
docs/releases/vMAJOR.MINOR.PATCH.md
```

The release workflow appends container image details and a Docker run one-liner automatically.

Release notes should include:

- what changed
- install paths affected
- verification performed
- compatibility or migration notes
- reminder that the repo is sanitized and contains no private memory data

## Required install paths to preserve

The GitHub version must always preserve these supported paths:

1. standard Ubuntu Linux install
2. Docker Compose install
3. Dockge install
4. Docker run / GHCR package install

Docker and Dockge installs must remain self-contained: OpenClaw and PostgreSQL run inside the same OpenClaw/Zorg container, with embedded PostgreSQL data stored under the OpenClaw volume.

## GitHub production features used

- README with clear quickstarts and relative documentation links
- `LICENSE`
- `SECURITY.md`
- `CONTRIBUTING.md`
- `SUPPORT.md`
- `CHANGELOG.md`
- GitHub Actions CI verification
- GitHub Actions release automation
- GitHub Container Registry package publishing
- OCI image labels linking the package to the repository

## Local pre-release checklist

Before tagging:

```bash
bash -n scripts/*.sh docker/entrypoint.sh
python3 -m py_compile scripts/*.py
docker compose config >/tmp/zorg-memorydb-compose.yml
docker build --build-arg OPENCLAW_VERSION=latest -t zorg-memorydb-openclaw:local .
```

For runtime changes, also verify fresh startup with an alternate port:

```bash
OPENCLAW_GATEWAY_PUBLISHED_PORTS=19892 docker compose -p zorg_release_verify up -d --build
docker compose -p zorg_release_verify exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker compose -p zorg_release_verify exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose -p zorg_release_verify exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
docker compose -p zorg_release_verify down -v
```

## Documentation freshness

Release work includes updating the docs that explain why Zorg MemoryDB exists and how the current design works. In particular, keep `docs/why-zorg-memorydb.md`, recovery docs, rule/recall docs, and release notes aligned with the latest public-safe MemoryDB capabilities.

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

<!-- LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->
## LLM-Governed Performance Tuning Rule

Database and memory performance tuning must be governed by live LLM judgment, not hidden script policy. Tuning work starts with a natural-language hypothesis formed from current system evidence and internet/authoritative research. If research gives a credible reason to believe a database design, recall-path, materialized-view, vector/neural association, or query-structure change will improve performance, the LLM must run side-by-side before/after measurements on representative queries before claiming success.

If research does not support a design change, move to raw additive performance work: indexes, query-path improvements, materialized/search-support views, relationships, recall hints, semantic edges, weighted connections, token/FTS/trigram support, and other non-destructive logic that brings query times down while preserving all source memory. No original memory data may be pruned, deleted, truncated, compacted away, or aged out for speed.

Every meaningful tuning change must record the research basis, before/after benchmark results, changed structures, rollback path, and follow-up indexing/hinting implications in durable memory and public-safe docs when structural behavior changes.
<!-- /LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->

<!-- GO_ONLY_APPROVAL_RULE -->
## GO-Only Approval Rule

When Stefan gives a command that requires confirmation before execution, ask only for `GO`. Do not invent longer approval phrases, magic words, task-specific confirmations, or exact response strings such as `GO REIP ...`, `GO SCORCHED ...`, or any other expanded form. Stefan decides how to respond; the assistant may request only the simple approval token `GO`.

If the requested action is unsafe, ambiguous, destructive, externally risky, or missing a necessary decision, explain the blocker or the exact intended change briefly, then end with only `GO` as the approval request when approval is the only thing needed. Never require Stefan to repeat the task, include extra words, or match an assistant-authored phrase.
<!-- /GO_ONLY_APPROVAL_RULE -->

<!-- SAME_DAY_NEWS_FRESHNESS_RULE -->
## Same-Day News Freshness Rule

When writing multiple news articles or public reports on the same day, do not repeat the same information from article to article. Adjacent or continuing stories may reference earlier context only briefly when necessary, but each article must add fresh facts, new framing, new implications, new examples, or a clearly advanced continuation that was not already covered in earlier same-day articles.

Before drafting or publishing a new article, review the same-day feed/archive and compare titles, summaries, body claims, examples, and links. If information has already been used that day, either omit it, compress it to a short bridge, or explicitly advance it with new developments. Maintain editorial continuity without recycling paragraphs, talking points, examples, or conclusions.

The assistant owns the full article set and must keep the day’s coverage fresh, non-repetitive, and additive.
<!-- /SAME_DAY_NEWS_FRESHNESS_RULE -->

