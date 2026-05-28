# X Posting Live Access Gate

Scheduled X posting jobs must be live LLM tasks. They must not assume X access exists.

Before drafting, shortening, anchoring, or posting anything to X, the live LLM should:

- check backend DB memory for the current verified X posting path;
- inspect current run history and recent quota/access observations;
- perform the smallest live X access/credits preflight that is available;
- continue to post only if access, credentials, credits, quota, payment state, and API availability are usable.

If X access is missing or unavailable, return `NO_POST: X access unavailable` before drafting or anchor-link posting.

If X credits or quota are exhausted, return `NO_POST: X credits exhausted` before drafting or anchor-link posting.

Do not treat either case as a system failure report. Record the observation in DB memory and reduce future scheduled posting frequency instead of retrying repeatedly.

Hyperdine article publishing may continue independently when otherwise safe, but X anchor-link posting must not be attempted without live X access.
