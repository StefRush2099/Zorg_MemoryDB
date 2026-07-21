# Neural Recall Activity

This directory is the public production asset capture for the live Zorg Memory
3D / Neural Recall Activity service at `http://0.0.0.0:8097/`.

It is separate from LAN Command Chat and is backed by the Zorg PostgreSQL
MemoryDB. The captured browser assets are `index.html`, `app.js`, `styles.css`,
and the 3D force-graph vendor bundle. The production server/API source and
database credentials remain on the production host and are never committed.

## OpenClaw install guidance

- Install the root Zorg package and `package/zorg/lan-command-chat/` for LAN
  Command Chat.
- Deploy the production 8097 service from its production-host source and keep
  its PostgreSQL environment on that host.
- Do not install or restore the retired `package/zorg/memory-3d/` package; it
  was removed from this release.
- Verify production with:

```bash
curl -fsS http://127.0.0.1:8097/api/health
curl -fsS http://127.0.0.1:8097/api/activity
```
