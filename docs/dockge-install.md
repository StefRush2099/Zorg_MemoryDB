# Dockge Install: OpenClaw + Zorg MemoryDB

Target OS: the latest Ubuntu release, currently **Ubuntu 26.04 LTS**.

Dockge manages Docker Compose stacks. Use this path when the Ubuntu host already runs Dockge or you want a web-managed stack.

## Recommended Dockge stack from cloned repo

On the Ubuntu Dockge host:

```bash
sudo apt-get update
sudo apt-get install -y git docker.io docker-compose-plugin
sudo systemctl enable --now docker

cd /opt/stacks
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git
sudo chown -R "$USER:$USER" /opt/stacks/Zorg_MemoryDB
cd /opt/stacks/Zorg_MemoryDB
cp .env.example .env
```

Edit `/opt/stacks/Zorg_MemoryDB/.env` and change at least:

```env
DB_PASSWORD=change-this-password
OPENCLAW_GATEWAY_TOKEN=change-this-token
```

Then in Dockge:

1. Create/import stack named `Zorg_MemoryDB`.
2. Use `/opt/stacks/Zorg_MemoryDB/docker-compose.yml` as the stack Compose file.
3. Start the stack.

Dockge will build the OpenClaw image from this repo and start both services.

## Paste-only Dockge stack

If you prefer to paste a stack directly into Dockge, use this Compose file. It builds the image from the GitHub repo and keeps all runtime data in Docker volumes:

```yaml
services:
  openclaw:
    build:
      context: https://github.com/StefRush2099/Zorg_MemoryDB.git#main
      dockerfile: Dockerfile
      args:
        OPENCLAW_VERSION: latest
    image: zorg-memorydb-openclaw:latest
    container_name: zorg-openclaw
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      OPENCLAW_HOME: /home/openclaw/.openclaw
      OPENCLAW_WORKSPACE: /home/openclaw/.openclaw/workspace
      DB_HOST: postgres
      DB_PORT: 5432
      DB_NAME: openclaw_memory
      DB_USER: openclaw_memory
      DB_PASSWORD: change-this-password
      OPENCLAW_GATEWAY_PORT: 18789
      OPENCLAW_GATEWAY_BIND: lan
      OPENCLAW_GATEWAY_AUTH: token
      OPENCLAW_GATEWAY_TOKEN: change-this-token
    ports:
      - "18789:18789"
    volumes:
      - zorg_openclaw_home:/home/openclaw/.openclaw

  postgres:
    image: postgres:16
    container_name: zorg-memorydb-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: openclaw_memory
      POSTGRES_USER: openclaw_memory
      POSTGRES_PASSWORD: change-this-password
    expose:
      - "5432"
    volumes:
      - zorg_memorydb_pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U openclaw_memory -d openclaw_memory"]
      interval: 5s
      timeout: 5s
      retries: 20

volumes:
  zorg_openclaw_home:
  zorg_memorydb_pgdata:
```

## Verify from Dockge

Use the Dockge terminal/console or SSH into the Ubuntu host:

```bash
docker exec zorg-openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker exec zorg-openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

Expected recall mode: `database-direct-structured`.

## Notes

- Do not paste real private memory rows or credentials into the GitHub repo.
- Runtime database data stays in the `zorg_memorydb_pgdata` Docker volume.
- The repo remains a sanitized template; Dockge only starts it.
