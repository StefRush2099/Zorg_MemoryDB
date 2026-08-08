# Connector acceptance and release gates

Use isolated fixtures or transactions for failure injection. Never corrupt the live source tables to prove recovery.

## Connector matrix

1. Healthy database: preparation succeeds and returns a fresh matching receipt.
2. Slow valid call: delivery waits; no competing fallback or premature timeout.
3. Weak/empty recall: fail according to policy, persist evidence, and alert once.
4. Missing ANN: exact safety recall remains correct or the gate fails closed; additive repair queues.
5. Database disconnect: request is held and no answer/mutation is delivered.
6. Duplicate failure: one bounded alert, no alert storm.
7. Restoration: a new direct call succeeds; old receipt is not reused.
8. Missing receipt: delivery blocked.
9. Stale/mismatched receipt: delivery blocked.
10. Restart continuity: plugin runtime registration and request identity remain correct after the required restart.
11. Telegram/source channel: held and released behavior matches the database receipt contract.
12. LAN Command Chat and Memory Brain 3D: both use the same PostgreSQL-backed route and report healthy.
13. Full production suite: all 13 canonical MemoryDB gates pass with saved private evidence.

## Data and quality gates

- Critical safety rule is rank one.
- Normal, deep, cognitive, associative, exact, and HNSW recall return expected bounded results.
- Exact-versus-HNSW ordered top-eight equality (or the documented acceptance threshold) has no regression.
- Semantic/vector queues show zero unexpected queued/failed items at terminal check.
- No invalid indexes.
- Source memory/history/event/provenance row counts are preserved.
- Privacy classifications prevent private/internal content from public export.

## Package and release gates

- Root package version is canonical.
- Packaged LAN package/lock and live LAN package/lock match it.
- Both LAN builds succeed.
- Restart only LAN Command Chat.
- Verify the gauge-specific compiled `data-lan-chat-gauge-version` marker and authenticated rendered label `v<canonical version>`.
- Validate the skill, plugin tests/build, installer syntax, migration catalog, clean-install rehearsal, upgrade/rollback rehearsal, public/private scan, secret scan, generated-artifact scan, contaminated-fixture scan, and archive contents.
- The archive contains exactly the current release note and no nested release archives, backups, dumps, credentials, internal addresses, or retired packages.
- Push the exact tested commit and signed/annotated semantic version tag as project policy requires.
- Publish the matching GitHub Release and asset.
- Verify remote commit, tag, release, asset checksum, metadata, public URL resolution, and rendered repository/release/docs pages.

Any failed gate blocks completion and publication. Save private evidence and report the exact blocker rather than claiming partial success.
