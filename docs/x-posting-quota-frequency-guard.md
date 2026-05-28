# X Posting Quota And Frequency Guard

Scheduled public X posting should be bounded and summary-oriented.

Default behavior:

- keep scheduled X posting to a few summary-style jobs per day;
- avoid duplicate teaser, blog, countdown, reminder, or one-off promotional jobs unless the operator explicitly asks;
- prefer one post that points to a verified long-form Hyperdine article over multiple small posts about the same work;
- keep public reply monitoring bounded so read attempts do not burn credits unnecessarily.

Quota handling:

- if X reports quota, credits, rate-limit, usage-cap, payment, or exhausted-credit conditions, classify the result as credits exhausted;
- return `NO_POST: X credits exhausted` or `NO_REPLY: X credits exhausted` as appropriate;
- do not send the operator a system failure report just because X credits are exhausted;
- record the observation in DB memory and reduce future scheduled posting frequency instead of retrying repeatedly.

Cron prompts should express this as natural-language LLM judgment. They should ask the live LLM to check recent run history, current rules, quota evidence, and post frequency before making any quota-consuming X attempt.
