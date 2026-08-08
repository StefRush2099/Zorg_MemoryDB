# Connector recovery

## Safety invariant

Recovery must restore the direct PostgreSQL gate; it must not invent a parallel memory path. Keep the request held until a fresh matching receipt exists.

## Triage

Capture, without exposing secrets:

- exact failure timestamp and request/session/run identifiers;
- database reachability and identity;
- plugin runtime registration and memory-slot ownership;
- preparation function existence/signature and EXECUTE privilege;
- latest receipt status/hash;
- queue counts and oldest age;
- invalid indexes;
- database locks and recent errors;
- last known good package/config/backup checksum.

Classify the fault before changing anything:

1. Connection/authentication.
2. Missing or mismatched schema/function.
3. Ownership/privilege.
4. Stale or mismatched receipt.
5. ANN/embedding/queue degradation.
6. Plugin registration/configuration.
7. Interrupted upgrade or service restart.
8. Connected-surface-only failure.

## Recovery sequence

1. Freeze delivery for the affected request; avoid repeated retries.
2. Verify PostgreSQL directly with a bounded diagnostic connection and explicit database identity.
3. If connectivity fails, repair route/credentials/service outside the model, then repeat identity checks. Never fall back.
4. If the preparation function is missing or incompatible, compare the installed migration ledger and pinned release; apply only the required idempotent migration as an authorized owner.
5. If privileges fail, compare object owners and grants. Grant the least required right or use the owning role for DDL; do not promote the runtime role to superuser.
6. If a receipt is stale/mismatched, do not reuse or edit it. Create a new preparation call for the exact current request identity.
7. If ANN is unavailable but exact recall is healthy, follow the defined degraded contract only if it still satisfies rank and safety gates. Queue additive ANN repair; never replace source data.
8. If plugin runtime registration fails, verify provenance, allow/deny, enabled entry, memory slot, manifest, compiled entry point, and host compatibility. Restart only the Gateway after correcting plugin code/config.
9. If an upgrade was interrupted, restore the last known good package/config and, if necessary, the verified logical backup. Re-run schema identity and source-row preservation checks before opening delivery.
10. Run the acceptance matrix. Release the held request only after a new receipt matches its request hash and all mandatory safety gates pass.

## Rollback

Rollback artifacts must include package/config backups, logical database dump, checksum, release/tag, migration ledger, and source-row counts. Test that the dump is listable before work. A rollback is complete only when the previous plugin is runtime-registered, the database gate returns a fresh receipt, critical recall ranks correctly, queues are safe, and connected surfaces respond.

Never publish dumps, credentials, internal endpoints, receipts containing private content, or operator-specific recovery evidence.
