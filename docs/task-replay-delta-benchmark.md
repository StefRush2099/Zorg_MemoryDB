# Task Replay Delta Benchmark

Task replay delta benchmarking periodically re-runs old completed tasks and known failure cases as simulations against the current Zorg MemoryDB recall layer. The goal is to measure whether memory, recall hints, semantic edges, and rules are making the assistant better or worse at recovering prior solution paths.

The benchmark is additive. It stores replay cases, replay runs, per-query results, recall hints, retrieval feedback, and semantic edges. It must not delete, prune, truncate, compact, or rewrite source memory.

## What a replay case stores

Each case records the original task intent, the original date, the source memory row or rule, the expected solution path, expected verification evidence, safety rules that should be recalled, and a set of replay queries.

Success cases ask: can the current system find the prior working path quickly enough to simulate solving the task again?

Failure cases ask: can the current system recall the rule, blocker, or recovery path early enough to avoid repeating the original failure?

## Delta scoring

Replay runs should compare old and current behavior with these signals:

Retrieval rank: whether the expected source appears in the top results.

Latency: how long recall takes.

Specificity: whether the result includes concrete files, tools, commands, blockers, verification, and backup/commit references.

Safety recall: whether required rules and failure-prevention gates appear before simulated mutation.

Drift detection: whether stored memory points at stale files, services, credentials, hosts, or procedures.

Repair output: whether the benchmark added recall hints, aliases, semantic edges, query observations, or retrieval feedback after a miss.

## Initial seeded case

The first seeded case is lan-chat-whisper-mic-feature-2026-05-13.

It benchmarks recovery of the LAN command chat Whisper microphone feature, including the MediaRecorder UI, /api/transcribe route, OpenAI/Whisper environment variables, service environment loading, verification checks, and the known invalid_api_key blocker. The initial replay showed strong direct technical recall but weaker time-relative human phrasing such as "restore the LAN chat microphone feature from last week."

## Tables

memory_task_replay_cases stores benchmark cases.

memory_task_replay_runs stores aggregate results for one simulated replay.

memory_task_replay_query_results stores each replay query result, rank, latency, specificity, missing signals, and stale signals.

## Recurring operation

A recurring LLM-governed cron job should periodically sample both success and failure cases, run replay queries, record results, add non-destructive recall improvements for misses, and report only meaningful regressions, repairs, or ambiguous risks.

The job should stay silent when replay is healthy. It should notify the operator when a previously working solution no longer surfaces, when a failure replay would repeat the old mistake, or when a structural recall fix was made.
