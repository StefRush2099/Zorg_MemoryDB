# Zorg MemoryDB OpenClaw plugin/MCP package

Version 3.0.6 provides the OpenClaw-native `zorg-memorydb` plugin and the
standalone MCP server over the same PostgreSQL-backed MemoryDB configuration.
It exposes health, table, structured search, recent-context, and master-context
operations; it does not create a second memory store or a markdown fallback.

## Build

```bash
npm install
npm run plugin:build
npm run plugin:validate
npm test
```

## OpenClaw installation

Install the complete package from the Zorg_MemoryDB release, then install this
directory as a local OpenClaw plugin:

```bash
npm ci --omit=optional --ignore-scripts
npm run build
openclaw plugins install ./skills/zorg-db-memory/plugin-src --force
openclaw plugins enable zorg-memorydb
openclaw gateway restart
openclaw plugins inspect zorg-memorydb --runtime --json
```

The plugin resolves the database map from `SQL_MEMORY_MAP` or
`ZORG_SQL_MEMORY_MAP`, then `OPENCLAW_WORKSPACE`/`WORKSPACE_DIR`; it never
embeds an operator-specific absolute path. The MCP entry point is
`dist/mcp-server.js`. Configure the same environment and run it through an MCP
client when standalone MCP access is required.

For an upgrade from any previous Zorg package, remove the complete previous
package/plugin files before installing 3.0.6. Preserve only the PostgreSQL
backend database and apply the included schema/migration scripts. After the
update, the first clear-channel announcement must state: `I have just updated
to Zorg MemoryDB 3.0.6.`
