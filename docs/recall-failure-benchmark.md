# Recall Failure Benchmark

Zorg MemoryDB treats recall failures as measurable system feedback. A recall failure is counted when a user correction or later verified evidence shows that the needed fact, access path, rule, or prior working process already existed in durable memory or available system state, but the assistant did not retrieve it before asking for more information, giving the wrong answer, or taking the wrong path.

This benchmark is intentionally conservative: it reports **minimum confirmed incidents**, not a claim that every historical failure was found. It avoids publishing private transcripts, credentials, contact data, live database rows, or sensitive infrastructure details.

![Recall failure benchmark chart](assets/recall-failure-benchmark-2026-05-14.svg)

## 2026-05-14 Snapshot

Public-safe aggregate scan results from one OpenClaw/Zorg deployment:

| Metric | Value |
|---|---:|
| Durable memory rows scanned | 5,731 |
| Session files scanned | 362 |
| Session messages scanned | 6,299 |
| User-role messages in session store | 498 |
| Confirmed memory/recall correction incidents | 6 minimum |
| Confirmed recall-correction rate vs stored user messages | 1.2% |
| Non-confirmed-failure rate vs stored user messages | 98.8% |

## Period Trend

| Period | Confirmed incidents | Public-safe interpretation |
|---|---:|---|
| Feb-Mar 2026 | 2 | Early recall leaned too much on logs and unstructured memory; important system facts were not always promoted into durable structured recall. |
| Apr 2026 | 1 | A shallow-miss pattern was identified and deeper backend recall rules were reinforced. |
| May 1-9 2026 | 2 | DB-only migration, contact/CRM recall, publication-rule enforcement, and recall hints improved coverage but exposed more measurable edge cases. |
| May 10-14 2026 | 1 | Rule capture became faster: corrections were stored as structured DB rules/facts soon after clarification. |

## Methodology

1. Search durable DB memory for correction phrases, recall-failure notes, explicit operator clarifications, and documented shallow misses.
2. Search session stores for assistant acknowledgments such as “you’re right,” “memory shows,” or equivalent correction language.
3. Count only incidents where the missing fact/process/rule was later verified in memory or durable state.
4. Treat the count as a lower bound if older transcripts were compacted, migrated, or unavailable.
5. Convert each confirmed miss into additive recall support: structured rules, aliases, project facts, relationship edges, recall hints, or benchmark queries.

## Why this matters

A memory-backed assistant should not merely apologize after forgetting. It should make forgetting harder next time. Zorg MemoryDB uses these incidents as training signals for the surrounding operating system: failures become structured recall tests and documentation updates instead of disappearing into chat history.

## 2026-05-15 Rule-Enforcement Failure Class

A confirmed failure class was added after an assistant had the relevant rule in DB memory but still mutated files/services without summarizing the intended change, widened scope during corrective work, and treated a corrective-loop exception too broadly. The database connection was healthy; the failure was agent-side rule enforcement plus recall-ranking noise.

Required remediation for this class:

- promote the violated rule into top-level system markdown and structured logic-rule recall;
- audit configured database connections and recall functions before claiming memory was broken;
- create a failure report with cause, evidence, DB health, and corrective actions;
- harden recall so broad natural-language phrasing surfaces the critical rule;
- verify `memory_search` returns the corrected rule before completion claims.

## 2026-05-16 Process-Following Regression Class

A second failure class was identified when the operator reported that system/process follow-through had regressed compared with two days earlier. Baseline queries for GitHub publication, documentation updates, screenshots, light/dark/mobile verification, and reindexing did not all return the intended process rule at the top; some were outranked by unrelated critical rules. This indicates recall-ranking and rule-surface specificity problems rather than source-data loss.

Representative baseline queries for this class:

- `push all system changes to GitHub update documentation screenshots light dark mobile`
- `verification screenshots light mode dark mode cell phone screenshots sent to Stefan`
- `process rule update docs push GitHub whenever changes made`
- `reindex broken process following compare before after recall ranking`

Required remediation:

- add/update a top-level system-change publication and visual-verification rule;
- sync that rule into structured DB recall;
- refresh materialized/search views and analyze/reindex affected recall tables where appropriate;
- add public-safe recall hints/observations so the representative queries surface the rule;
- push the documentation and structural changes to GitHub;
- rerun the representative queries and record before/after evidence.

## Privacy Boundary

This public benchmark intentionally excludes private content. The repo receives only aggregate counts, public-safe methodology, and sanitized examples of failure categories. Private transcripts, contact records, credentials, operational secrets, and raw database rows remain out of the public repository.
