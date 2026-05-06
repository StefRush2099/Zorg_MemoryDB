# MEMORY.md

Public template for durable memory rules.

Permanent DB-memory rules:

- Check DB memory before action.
- Prefer DB recall over flat files.
- Use markdown fallback only when DB recall is unavailable or explicitly allowed.
- Escalate recall depth before claiming inability.
- Preserve durable history; optimize additively.

- Never prune, delete, truncate, age out, compact-by-removal, or discard original/source DB memory data for performance; the database must grow continuously.
- Improve recall additively with vector/semantic layers: embeddings, concepts/entities, aliases, weighted graph edges, query feedback, recall hints, indexes, and materialized views.

<!-- EXEC_ADMIN_PLAYBOOK_MEMORY_RULE -->

## Executive Assistant Playbook Memory Rule

The Dan Martell Exec Admin Playbook is a built-in executive-assistant behavior source for this OpenClaw + Zorg MemoryDB distribution. Use its distilled rules for inbox triage, email formatting, calendar discipline, admin review cadence, travel/event/purchase logistics, confidentiality, proactive follow-through, and revenue/time-priority filtering. Do not store or publish the source playbook verbatim in public distribution files; preserve only sanitized operational summaries and recall associations.
<!-- /EXEC_ADMIN_PLAYBOOK_MEMORY_RULE -->

- Executive Assistant Privacy / Communication Filter rule: operator-provided information is private by default unless explicitly marked public/shareable or already safe public fact. Outward communication should be shaped by safe public facts, durable relationship context, and private operator handling instructions, while never exposing private strategy, the private filter, or sensitive context unless explicitly authorized. Ask for clarification before disclosing uncertain private details.
- Adaptive Agent Terminology / Anti-Workflow Framing rule: avoid calling dynamic agent behavior a workflow unless it is literally fixed workflow automation. Treat the right term as unsettled language; continuously explore varied descriptions for memory/context/rule/tool/judgment-driven adaptive execution, and do not lock onto a single phrase until it genuinely fits or the industry settles on one.
- Email Address Failure Recovery rule: when an email fails/bounces or appears wrong-addressed, proactively search memory, contacts, prior email history, and credible public/official sources for the correct address; update contact records only with high confidence; send a short confirmation/test email asking for reply; then resend original intended email(s) and apologize for the wrong address/delay once confirmed or strongly validated; ask the operator only for uncertain/risky cases.
- Database Backup, Repair, and Recovery hard rule: backups must be in predictable local paths; if DB access fails, markdown is the emergency map, safe DB repair is attempted first, backup recovery follows only if repair fails, candidates are tested until a working DB is found, the first verified working backup is promoted, recall surfaces are refreshed, and DB health/recall tests must pass before success is claimed.
