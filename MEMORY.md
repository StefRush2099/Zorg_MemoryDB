# MEMORY.md

Public template for durable memory rules.

Permanent DB-memory rules:

- Check DB memory before action.
- Prefer DB recall over flat files.
- Use markdown fallback only when DB recall is unavailable or explicitly allowed.
- Escalate recall depth before claiming inability.
- Preserve durable history; optimize additively.
