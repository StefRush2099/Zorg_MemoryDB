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

Patch-only typo/docs clarifications may be grouped, but any install/runtime behavior change must receive a new release.

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
OPENCLAW_GATEWAY_PORT=19892 docker compose -p zorg_release_verify up -d --build
docker compose -p zorg_release_verify exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker compose -p zorg_release_verify exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose -p zorg_release_verify exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
docker compose -p zorg_release_verify down -v
```
