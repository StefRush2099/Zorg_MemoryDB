# Zorg Memory 3D

Zorg Memory 3D is the standard local visualizer for a Zorg MemoryDB install.
It renders PostgreSQL-backed memory relationships, recall traces, rule weights,
scheduled-job activity, and runtime timing observations as an interactive 3D
graph with light and dark modes.

The service builds every graph response from PostgreSQL at request time. On
Vorg it connects directly to the local `openclaw_behavior` database over the
PostgreSQL socket and does not read map/export data files.

Default URL on a Standard Ubuntu install:

```bash
http://127.0.0.1:8097/
```

Default URL on Docker Compose or Dockge installs:

```bash
docker compose port zorg-memory-3d 8097
```

Use `?theme=light` to open directly in light view.
