# Support

Start with the docs:

- [Quickstart](docs/quickstart.md)
- [Standard Ubuntu install](docs/standard-ubuntu-install.md)
- [Docker install](docs/docker-install.md)
- [Dockge install](docs/dockge-install.md)
- [Docker run one-liner](docs/docker-run.md)
- [Verification](docs/verification.md)

## Verification commands

Docker/Dockge/Docker run:

```bash
docker exec zorg-memorydb bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker exec zorg-memorydb bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker exec zorg-memorydb bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

Docker Compose/Dockge service name may be `openclaw`; in that case use:

```bash
docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
```

Expected recall mode: `database-direct-structured`.

## Issues

When opening an issue, include:

- install path used: standard Ubuntu, Docker Compose, Dockge, or Docker run
- host OS/version
- Docker/Dockge version if relevant
- command run
- exact error text
- verification command output

Do not include secrets, private memory data, email content, chat logs, cookies, or private database rows.
