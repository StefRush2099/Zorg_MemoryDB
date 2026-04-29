# Schema Summary

The schema is exported structure-only from a working OpenClaw DB-memory installation.

Main recall objects:

- `zorg_memory` - durable memory and remembered context
- `md_agents`, `md_soul`, `md_user`, `md_tools`, `md_identity`, `md_heartbeat` - line-imported markdown context
- `memory_projects`, `memory_hosts`, `memory_services`, `memory_runbooks`, `memory_relationships` - structured operational context
- `zorg_operational_facts` - promoted operational facts
- `zorg_memory_search_mv` - unified search surface
- `zorg_master_context_mv` - prioritized master context
- `zorg_recall_context(query, limit)` - broad recall entry point
- `zorg_get_project_context`, `zorg_get_host_context`, `zorg_get_runbook_context` - targeted recall entry points

Fresh installs contain no data. The structure is intended to be repopulated locally.
