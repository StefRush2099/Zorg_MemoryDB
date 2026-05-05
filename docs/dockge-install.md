# Dockge Install: Integrated OpenClaw + Zorg MemoryDB

Dockge should manage **one OpenClaw/Zorg stack**. The stack starts one OpenClaw/Zorg container. Zorg MemoryDB runs internally inside that same container and stores its data inside the normal OpenClaw home volume.

## Important: use the lowercase Dockge folder

Dockge and Docker Compose normalize stack/project names to lowercase. If the repo is cloned as `/opt/stacks/Zorg_MemoryDB` and imported as `Zorg_MemoryDB`, Dockge may create a second lowercase folder such as `/opt/stacks/zorg_memorydb`.

To keep the install confined to the same subfolder it starts in, use this lowercase folder and stack name from the beginning:

```text
/opt/stacks/zorg_memorydb
```

## Recommended Dockge start path

On the Ubuntu Dockge host:

```bash
sudo apt-get update
sudo apt-get install -y git docker.io docker-compose-plugin
sudo systemctl enable --now docker

cd /opt/stacks
sudo git clone https://github.com/StefRush2099/Zorg_MemoryDB.git zorg_memorydb
sudo chown -R "$USER:$USER" /opt/stacks/zorg_memorydb
cd /opt/stacks/zorg_memorydb
cp .env.example .env
```

Then in Dockge:

1. Create/import one stack named `zorg_memorydb`.
2. Use `/opt/stacks/zorg_memorydb/docker-compose.yml` as the stack Compose file.
3. Start/stop/update it only from Dockge.

Open OpenClaw on port `18789`.

## If you already have duplicate folders

If Dockge created both uppercase and lowercase folders, keep the lowercase Dockge-managed folder and move any edited `.env` values into it:

```bash
sudo mkdir -p /opt/stacks/zorg_memorydb
sudo rsync -a --exclude .git /opt/stacks/Zorg_MemoryDB/ /opt/stacks/zorg_memorydb/
sudo chown -R "$USER:$USER" /opt/stacks/zorg_memorydb
```

Then point Dockge to `/opt/stacks/zorg_memorydb/docker-compose.yml` and use stack name `zorg_memorydb`.

After confirming Dockge is using `/opt/stacks/zorg_memorydb`, the old uppercase folder is only a stale source checkout. Do not remove it until you confirm there is no unique `.env` or local edit you still need.

## Paste-only Dockge stack

If you prefer to paste a stack directly into Dockge, name the stack `zorg_memorydb` and use this Compose file:

```yaml
name: zorg_memorydb

services:
  openclaw:
    image: ghcr.io/stefrush2099/zorg-memorydb:latest
    restart: unless-stopped
    environment:
      OPENCLAW_HOME: /home/openclaw/.openclaw
      OPENCLAW_WORKSPACE: /home/openclaw/.openclaw/workspace
      PGDATA: /home/openclaw/.openclaw/postgresql/data
      DB_HOST: 127.0.0.1
      DB_PORT: 5432
      DB_NAME: openclaw_memory
      DB_USER: openclaw_memory
      OPENCLAW_GATEWAY_PORT: 18789
      OPENCLAW_GATEWAY_BIND: lan
      OPENCLAW_GATEWAY_AUTH: trusted-proxy
    ports:
      - "18789:18789"
    volumes:
      - zorg_openclaw_home:/home/openclaw/.openclaw

volumes:
  zorg_openclaw_home:
```

## Verify from Dockge

Use the Dockge terminal/console or SSH into the Ubuntu host:

```bash
cd /opt/stacks/zorg_memorydb
docker compose ps
docker compose exec openclaw bash -lc 'pg_isready -h 127.0.0.1 -p 5432'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_sql_tool.py tables'
docker compose exec openclaw bash -lc 'cd /home/openclaw/.openclaw/workspace && .venv-sqlmem/bin/python scripts/memory_recall_router.py "database memory" --limit 5'
```

Expected recall mode: `database-direct-structured`.

## Cleanup for older duplicate installs

If an earlier Dockge attempt created duplicate unmanaged containers, stop the Dockge stack first, then inspect Docker for leftovers:

```bash
docker ps -a --filter name=zorg --filter name=openclaw
```

Remove only old duplicate/unmanaged containers after confirming Dockge is stopped and the container is not the active Dockge-managed one:

```bash
docker rm <old-container-name-or-id>
```

Do not delete volumes unless you intentionally want to discard that install's local OpenClaw state and memory data.

## Notes

- Use lowercase `zorg_memorydb` for the Dockge folder, Dockge stack name, and Compose project name.
- Do not paste private memory rows or private operator context into the public repo.
- The repo remains a sanitized OpenClaw build template.
