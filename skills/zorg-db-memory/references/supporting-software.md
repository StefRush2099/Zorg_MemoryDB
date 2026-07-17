# Supporting software source map

LAN Command Chat and Memory Brain 3D depend on Zorg MemoryDB and must be known by zorg-db-memory.

## LAN Command Chat

Source paths:
- /home/openclaw/.openclaw/workspace/lan-chat
- /home/openclaw/.openclaw/workspace/Zorg_MemoryDB/lan-chat
- /home/openclaw/.openclaw/workspace/Zorg_Hive/apps/lan-chat
- /home/openclaw/.openclaw/workspace/Zorg_Hive/apps/by-host/openclaw/lan-chat
- /home/openclaw/.openclaw/workspace/Zorg_Hive/apps/by-host/vorg/lan-chat

Runtime:
- port 3001
- /chat route
- /memory-3d-proxy/ when Memory Brain 3D is connected
- Internal gateway/database/health targets use `127.0.0.1` or install variables;
  do not embed a host LAN IP. Nginx remains the LAN-facing front door.

## Memory Brain 3D

Source paths:
- /home/openclaw/.openclaw/workspace/Zorg_MemoryDB/zorg-memory-3d
- /home/openclaw/.openclaw/workspace/Zorg_Hive/apps/by-host/openclaw/zorg-memory-3d
- /home/openclaw/.openclaw/workspace/zorg-memorydb-memory-3d-standard-install/zorg/memory-3d

Runtime:
- service zorg-memory-3d.service
- command /usr/bin/node server.js
- port 8097
- Bind host: `BIND_HOST`, default `127.0.0.1`; PostgreSQL target: `PGHOST`,
  default/current value `127.0.0.1`. Reach it from LAN users through the LAN
  Command Chat front door, not a hard-coded host IP.
- /admin/
- proxy through /memory-3d-proxy/

## Packaging rule

Do not include generated dependencies, build output, temp folders, screenshots, browser profiles, or secrets. If the skill package gains source-archive support, include app source snapshots excluding those files.
