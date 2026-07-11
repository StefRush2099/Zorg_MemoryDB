# Why Install Zorg MemoryDB Instead of Plain OpenClaw?

Zorg MemoryDB is for people who like OpenClaw, but want an agent that stops acting like every day is its first day on the job.

Plain OpenClaw gives you the agent runtime, tools, channel integrations, browser control, local files, automation hooks, and a strong foundation for building useful assistants. Zorg MemoryDB keeps that foundation and adds a durable memory and operating-rule layer around it so the agent can remember what worked, recall why decisions were made, reuse proven access paths, apply privacy and communication rules, and continue improving its own retrieval structure over time.

The pitch is simple:

> **OpenClaw gives an agent tools. Zorg MemoryDB gives that agent an operating memory.**

## A clean add-on, not a fork trap

Zorg MemoryDB is designed to preserve the upside of upstream OpenClaw.

It is not meant to trap users on a stale branch or replace OpenClaw's normal update path. The packaged build installs and runs the current OpenClaw package, then layers database-backed memory structure, schema, templates, recall scripts, and operating rules into the normal OpenClaw home/workspace layout.

That means:

- OpenClaw remains OpenClaw.
- Future OpenClaw improvements can still be adopted.
- The memory layer is additive and inspectable.
- The public repository contains structure, scripts, schema, docs, and sanitized templates only.
- Private memory rows, credentials, emails, contacts, chats, account data, and operator context are not shipped.
- The database lives inside the local install/runtime and can be reasoned about like normal infrastructure.

The intended downside profile is low because Zorg MemoryDB does not ask you to abandon OpenClaw. It gives OpenClaw a better memory substrate and stronger operating rules while keeping the base system recognizable, updateable, and local-first.

## The problem: useful agents need continuity

A normal assistant can be impressive in a single exchange and still be weak operationally.

Without durable recall, it may:

- ask the same setup questions again
- forget which credential path already worked
- miss a standing CC/BCC rule
- repeat a failed install method
- overlook a prior decision
- claim something is fixed without checking the real surface
- treat a person like a stranger after prior communication
- lose the difference between public facts and private handling instructions
- describe dynamic agent behavior with old static automation language
- stop at a broken email address instead of finding the correct one
- report cron failures instead of repairing safe, obvious breakage

That is not an intelligence problem alone. It is a memory architecture problem.

Zorg MemoryDB exists because Stefan Rush pushed for an agent that could accumulate operational knowledge like an executive assistant, systems engineer, and project operator: not just remember isolated facts, but preserve decisions, access paths, working methods, communication rules, recovery patterns, and the structure needed to recall them under pressure.

## Stefan's design inspiration

The inspiration behind Zorg MemoryDB was practical: an AI agent should not be a brilliant amnesiac.

Stefan kept pushing the system toward database-backed durable memory because flat text notes alone were not enough for serious day-to-day work. The agent needed to:

- remember what the operator already approved
- reuse known-good technical paths instead of asking again
- preserve rules across restarts and compaction
- separate public-safe content from private context
- build stronger recall around people, systems, cron jobs, websites, credentials paths, and prior fixes
- become more useful as its rules and structures matured
- improve retrieval additively instead of pruning source history

The design goal is not just "more memory." It is operational continuity.

Zorg MemoryDB treats memory as infrastructure: searchable, structured, indexed, refreshable, inspectable, and continuously improvable.

## What the database adds

Zorg MemoryDB uses PostgreSQL-backed memory surfaces instead of relying on flat markdown memory lookup. Current design is DB-only for durable memory: legacy `memory/` files are archived/imported into PostgreSQL and removed from the active filesystem surface. The public repo includes schema, scripts, indexes, materialized views, template rules, structured logic tables, auto-heal helpers, backup helpers, and recall tooling that route memory searches through a structured database path.

Core attributes include:

- **DB-only durable recall** — recall is routed through PostgreSQL-backed structures, not active markdown memory fallback.
- **Durable source preservation** — original memory content is preserved; performance improvements are additive.
- **Materialized search views** — recall surfaces can be refreshed and tuned without deleting source data.
- **Structured table mapping** — markdown sources such as agent rules, soul/persona, tools notes, identity, heartbeat context, and long-term memory can be mapped into database-backed recall surfaces.
- **Structured rule-aware recall** — operating rules become rows in `zorg_logic_rules`, so rules can rank ahead of broad memory text.
- **Operational memory** — decisions, paths, scripts, cron IDs, contact rules, verification requirements, and recovery actions are stored for future reuse.
- **Weighted/associative direction** — the structure is designed to grow toward richer relationships, summaries, concepts, query observations, and weighted associations over time.
- **Public-safe templates** — the repo teaches the structure without leaking private rows or live operator context.
- **Install portability** — Docker, Compose, Dockge, and standard Ubuntu paths make the system easier to try.
- **Verification hooks** — scripts and docs exist to confirm PostgreSQL health, table visibility, recall mode, import behavior, backup behavior, auto-heal behavior, and OpenClaw startup wiring.
- **Automatic DB-only recall repair** — if retired markdown memory files reappear, auto-heal imports/archives them into DB, removes the files, refreshes recall, and stays silent unless blocked.
- **Recovery-first database handling** — production DB/index/schema changes require verified local and private/off-host backups first.
- **Recall-failure tuning gate** — production tuning changes happen after real recall misses, not because a cron blindly mutates the database. Without a recall failure, tuning jobs should benchmark and test additive structures in sandbox/temp contexts.
- **Professional communication defaults** — public-safe templates include rich-text email defaults with plain-text fallback.

## Why this is superior to plain memory notes

Flat files are useful for public templates, docs, and human-readable operating principles. But flat files should not be the active durable memory backend for serious operational recall.

A database layer makes memory more useful because it can:

- query across many files quickly
- preserve source history while adding faster lookup paths
- expose repeat query patterns for tuning
- support indexes and materialized views
- allow structured joins and future relationship tables
- turn operating rules into searchable surfaces
- support repeatable install/migration behavior
- create a foundation for concept maps and weighted associations

The point is not to throw documentation away. The point is to stop treating markdown as the agent's durable brain.

Zorg MemoryDB keeps public markdown for templates and docs while moving durable operational memory into PostgreSQL.

## What it feels like in practice

The practical difference is that the agent can get to work faster and make fewer avoidable mistakes.

Examples of the kind of behavior this structure supports:

### 1. Fewer repeated questions

If a credential path, host, script, browser path, or publishing method already worked before, the agent is expected to recall and try that known path before asking the operator to explain it again.

### 2. Communication that remembers people

The agent can store contact-specific rules: who may be emailed automatically, who must have Stefan CC'd or BCC'd, who needs plain nontechnical language, who is technical but skeptical, who is family, who is a public/professional contact, and what private context must only be used silently as a filter.

### 3. Privacy by default

Operator-provided information is treated as private unless explicitly marked public/shareable or already safe public fact. Private context can shape tone, emphasis, omissions, and follow-up, but outside recipients should not be told they are being filtered through private context.

### 4. Email-address recovery

If an email address fails or appears wrong, the agent should not simply stop. It should search memory, contacts, prior email history, and credible public/official sources, update the contact only when confidence is high, send a confirmation note, resend intended messages, and apologize for any delay caused by the wrong address.

### 5. Cron health and adaptive repair

Cron jobs are not just scheduled and forgotten. The system can audit whether jobs are functioning as designed, detect failures or stale states, and make safe repairs when the intended behavior is clear.

PostgreSQL-owned LLM jobs also keep their model selection portable: each agent
payload stores `$CURRENT_MODEL`, while the dispatcher resolves that variable at
execution time from the active OpenClaw default model. A model change therefore
updates scheduled work without rewriting every durable job or silently retaining
a stale provider/model identifier.

### 6. Disk-space monitoring and remediation

The system can monitor local free space, stay silent while healthy, alert below threshold, and — where authorized — grow the VM disk and in-guest filesystem when space drops below the defined safety mark.

### 7. Website publishing with verification

For site updates, the agent can remember to back up, patch safely, rebuild/redeploy, verify the live page/API, and avoid claiming success without checking the affected surface.

### 8. Public-safe publishing discipline

The same memory system that remembers useful context also remembers what must not be published: credentials, private rows, internal IPs, emails, contact data, transcripts, account data, and operator strategy.

It also helps public explanations sound less mechanical. Before writing outward-facing messages, the assistant can search its own public-safe operational history for a relevant lived example: a backup that prevented risk, a recall miss that became a better rule, a publishing loop that needed verification, or a contact issue that required follow-through. The point is not to announce that it is using an anecdote. The point is to communicate like a person who has actually done the work.

### 9. Better language for agent behavior

Zorg MemoryDB includes a rule to avoid reducing dynamic agent behavior to old static terms like "workflow" unless describing literal fixed automation. The language is intentionally allowed to evolve as the industry finds better words for memory-shaped, context-sensitive agent execution.


### 10. Memory recovery as a first-class feature

The database is treated as valuable operational infrastructure. Production structural changes require a verified temporary local PostgreSQL backup first. Database dumps must not be committed, mirrored, or pushed to GitHub from the public MemoryDB update path. Off-host recovery can be designed as a separately approved encrypted/private operations process.

### 11. Documentation and releases that keep up

Zorg MemoryDB should explain its current design publicly. Meaningful changes to memory, recall, schema, backup, rules, installation, or runtime behavior should update docs and releases so users can understand what changed and why it matters.

## Why people should try this branch first

If you are testing OpenClaw casually, plain OpenClaw is enough.

If you want an agent that can become useful over days, weeks, and months, Zorg MemoryDB is the more practical starting point.

Install it if you want:

- a local-first OpenClaw build with PostgreSQL memory already integrated
- an assistant that can preserve operating rules
- durable recall across restarts and context compaction
- executive-assistant behavior baked into templates
- stronger communication privacy rules
- contact-aware email handling
- cron/job health awareness
- operational follow-through
- additive memory optimization instead of source pruning
- a public-safe structure you can adapt without importing someone else's private data
- a path that still lets OpenClaw keep receiving upstream updates

## What makes it different from a chatbot memory feature

Most chatbot memory features remember preferences. Zorg MemoryDB is aimed at operational memory.

That means it is built to remember things like:

- how a system is accessed
- which script succeeded
- what command failed
- which contact rule applies
- what public facts were verified
- which private context must stay private
- which cron job owns a task
- when a task should stay silent unless a threshold is crossed
- which verification gate proves something is done
- which GitHub repo must receive structural memory updates
- what should happen automatically next time

That is a different level of usefulness.

## The evolving pitch

This pitch should not be frozen.

Zorg MemoryDB is designed to become more useful as its memory rules, schema, indexes, recall paths, operational examples, and public-safe runbooks improve. As the system gets better at recovering failed emails, repairing cron jobs, monitoring resources, publishing safely, researching contacts, respecting privacy filters, and choosing known-good paths, the public explanation should evolve too.

Recent operating-rule hardening adds a clear boundary: dynamic assistant judgment belongs in the LLM plus durable rules, not hidden in scripts. Email checks should trigger live model triage instead of embedding sender exceptions or deletion rules in code. Calendar scheduling should detect existing matching meetings before creating invites. Public publishing should verify exact article anchors before posting short-form links. These are examples of the same design principle: make the system remember and apply rules openly, while keeping helper code narrow, mechanical, and auditable.

The goal is not hype. The goal is evidence.

Every new durable capability should become another public-safe example of why a database-backed, rule-aware OpenClaw build is more useful than an agent that starts over every session.

## The base setup that makes it really useful

Zorg MemoryDB is strongest when the memory layer is connected to the surfaces an executive assistant actually needs:

- instant messaging for fast operator control
- a dedicated assistant email address that becomes the public-facing executive-assistant identity
- optional governed personal-email access for triage/search/drafting
- private/off-host database backups
- Cloudflare Tunnel or an equivalent connector for safe remote web URLs
- Dockerized services visible in Dockge or a similar operations UI

Without those pieces, you still have a better memory substrate. With them, the agent can receive work, communicate professionally, preserve its memory, publish useful web surfaces, and stay operable by a human. See [`base-setup.md`](base-setup.md).

## Bottom line

Plain OpenClaw is the excellent base.

Zorg MemoryDB is the base with a memory spine, operating discipline, and a path toward continuously improving recall.

If you want an AI agent that can actually learn how to help you over time, install the branch that was built around that idea from the beginning.

<!-- SCORCHED_MEMORY_RECALL_RULE -->
## Absolute Priority 0: Exhaustive Memory Before Response

The operator does not ask for work in context unless the needed information, access path, rule, contact, precedent, or working solution likely already exists somewhere in durable memory, project history, live configuration, runbooks, prompts, cron jobs, or related system state. A fast or shallow miss is never evidence of absence.

Before replying, asking a question, claiming uncertainty, or reporting a blocker, the assistant must scour the backend memory system deeply and creatively: use broader queries, alternate names, relationship terms, adjacent projects, prior similar tasks, contact records, operational history, runbooks, cron payloads, and live configuration clues until the relevant context is found or genuinely exhausted. Immediate answers are disallowed when memory could contain the answer.

If deep scouring finds information that the first query missed, treat that as a recall-structure failure and immediately add additive retrieval support: aliases, recall hints, semantic/relationship edges, query observations, indexes, materialized/search support, or rule surfaces so the same phrasing is fast and reliable next time. Preserve all source data; improve recall additively only.

Failure reports must not excuse the miss as “not enough information” when the information existed in memory. The correct diagnosis is inadequate recall behavior or structure, and the corrective action is deeper recall plus indexing/hinting/relationship repair.
<!-- /SCORCHED_MEMORY_RECALL_RULE -->

<!-- LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->
## LLM-Governed Performance Tuning Rule

Database and memory performance tuning must be governed by live LLM judgment, not hidden script policy. Tuning work starts with a natural-language hypothesis formed from current system evidence and internet/authoritative research. If research gives a credible reason to believe a database design, recall-path, materialized-view, vector/neural association, or query-structure change will improve performance, the LLM must run side-by-side before/after measurements on representative queries before claiming success.

If research does not support a design change, move to raw additive performance work: indexes, query-path improvements, materialized/search-support views, relationships, recall hints, semantic edges, weighted connections, token/FTS/trigram support, and other non-destructive logic that brings query times down while preserving all source memory. No original memory data may be pruned, deleted, truncated, compacted away, or aged out for speed.

Every meaningful tuning change must record the research basis, before/after benchmark results, changed structures, rollback path, and follow-up indexing/hinting implications in durable memory and public-safe docs when structural behavior changes.
<!-- /LLM_GOVERNED_PERFORMANCE_TUNING_RULE -->

<!-- GO_ONLY_APPROVAL_RULE -->
## GO-Only Approval Rule

When Stefan gives a command that requires confirmation before execution, ask only for `GO`. Do not invent longer approval phrases, magic words, task-specific confirmations, or exact response strings such as `GO REIP ...`, `GO SCORCHED ...`, or any other expanded form. Stefan decides how to respond; the assistant may request only the simple approval token `GO`.

If the requested action is unsafe, ambiguous, destructive, externally risky, or missing a necessary decision, explain the blocker or the exact intended change briefly, then end with only `GO` as the approval request when approval is the only thing needed. Never require Stefan to repeat the task, include extra words, or match an assistant-authored phrase.
<!-- /GO_ONLY_APPROVAL_RULE -->

<!-- SAME_DAY_NEWS_FRESHNESS_RULE -->
## Same-Day News Freshness Rule

When writing multiple news articles or public reports on the same day, do not repeat the same information from article to article. Adjacent or continuing stories may reference earlier context only briefly when necessary, but each article must add fresh facts, new framing, new implications, new examples, or a clearly advanced continuation that was not already covered in earlier same-day articles.

Before drafting or publishing a new article, review the same-day feed/archive and compare titles, summaries, body claims, examples, and links. If information has already been used that day, either omit it, compress it to a short bridge, or explicitly advance it with new developments. Maintain editorial continuity without recycling paragraphs, talking points, examples, or conclusions.

The assistant owns the full article set and must keep the day’s coverage fresh, non-repetitive, and additive.
<!-- /SAME_DAY_NEWS_FRESHNESS_RULE -->


### Same-day publishing memory

A memory-backed agent can manage a running editorial day instead of treating each article as a blank slate. It should remember what has already been said, avoid repeating the same examples or conclusions, and keep each new report fresh while preserving continuity.
