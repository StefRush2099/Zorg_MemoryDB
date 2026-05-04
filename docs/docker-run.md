# Docker Run One-Liner

Use this path when you want the packaged GitHub Container Registry image without cloning the repo first.

The image is published to:

```text
ghcr.io/stefrush2099/zorg-memorydb
```

## One-line install/start

```bash
docker run -d --name zorg-memorydb --restart unless-stopped -p 18789:18789 -e OPENCLAW_GATEWAY_TOKEN=change-this-token -e DB_PASSWORD=change-this-password -v zorg_openclaw_home:/home/openclaw/.openclaw ghcr.io/stefrush2099/zorg-memorydb:latest
```

Then open the OpenClaw Gateway on port `18789` and use the token you set.

## Version-pinned example

Prefer a version tag for repeatable production installs:

```bash
docker run -d --name zorg-memorydb --restart unless-stopped -p 18789:18789 -e OPENCLAW_GATEWAY_TOKEN=change-this-token -e DB_PASSWORD=change-this-password -v zorg_openclaw_home:/home/openclaw/.openclaw ghcr.io/stefrush2099/zorg-memorydb:1.1.0
```

## Verify

```bash
docker exec zorg-memorydb bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker exec zorg-memorydb bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker exec zorg-memorydb bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

Expected recall mode: `database-direct-structured`.

## Upgrade

```bash
docker pull ghcr.io/stefrush2099/zorg-memorydb:latest
docker stop zorg-memorydb
docker rm zorg-memorydb
docker run -d --name zorg-memorydb --restart unless-stopped -p 18789:18789 -e OPENCLAW_GATEWAY_TOKEN=change-this-token -e DB_PASSWORD=change-this-password -v zorg_openclaw_home:/home/openclaw/.openclaw ghcr.io/stefrush2099/zorg-memorydb:latest
```

Do not remove the `zorg_openclaw_home` volume unless you intentionally want to discard the local install state and embedded PostgreSQL data.
