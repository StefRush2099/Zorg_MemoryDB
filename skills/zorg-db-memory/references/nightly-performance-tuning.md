# Daily performance verification

Use the single existing MemoryDB `systemPrompt` schedule for daily performance verification. Its payload contains natural-language instructions for the active model. It is a reminder, not an executor and not evidence of completion.

The active model must:

1. Perform direct PostgreSQL recall and inspect current database identity.
2. Check official PostgreSQL, pgvector, OpenClaw, and dependency documentation for applicable changes.
3. Measure cold/warm normal, deep, and cognitive recall; cache freshness; exact-versus-HNSW quality; embedding/queue health; rank-one safety recall; LAN Command Chat; and Memory Brain 3D.
4. Compare results with recent successful private evidence.
5. If repair is warranted, present facts, exact changes, affected surfaces, and rollback and wait for literal `GO`.
6. Invoke direct tools, inspect every result, save private before/after evidence, and advance the schedule only after verified completion.

Do not execute a collector, worker, dispatcher, autonomous script, background agent, cron copy, or systemd timer. Do not publish, delete source history, change privileged host settings, or restart PostgreSQL as part of routine verification. Public copies use neutral operator wording; private run evidence remains in PostgreSQL/private backup.
