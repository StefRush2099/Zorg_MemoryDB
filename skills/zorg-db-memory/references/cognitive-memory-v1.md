# Cognitive Memory v1

This additive layer coordinates existing PostgreSQL source memory into a practical cognitive lifecycle.

- Working memory is a bounded activation set with TTL, salience, goals, and rehearsal.
- Episodic memory points to immutable source events and records importance/outcome.
- Semantic memory uses existing nodes and edges plus consolidated beliefs.
- Procedural memory records triggers, ordered steps, success/failure evidence, and confidence.
- Prospective memory stores intentions that reactivate by time or JSON context.
- Reconsolidation changes only derived confidence, aliases, activation, and evidence. It never rewrites source history.
- Contradictions are grouped and selected by confidence multiplied by source quality; alternatives remain preserved.
- Spreading activation is cycle-safe, depth-limited to five, and damped on every hop.
- Cognitive recall preserves exact and critical rule ordering before adding activated graph context.

Official design references checked before implementation:

- https://github.com/pgvector/pgvector
- https://www.postgresql.org/docs/current/textsearch-indexes.html
- https://www.postgresql.org/docs/current/pgtrgm.html
- https://www.postgresql.org/docs/current/planner-stats.html
- https://www.postgresql.org/docs/current/routine-vacuuming.html

Rollback removes only the cognitive functions and tables. Existing source memory, events, provenance, embeddings, semantic graph, feedback, and scheduler history remain unchanged.
