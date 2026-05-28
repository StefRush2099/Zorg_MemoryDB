# Public Technical News Reporting

Public-facing technical news reports should help a broad audience understand why an engineering improvement matters.

When reporting on system optimization, memory improvements, recall tuning, agent reliability, or similar work, write with enough detail to show the substance of the change and enough energy to make the result understandable and interesting to non-operators.

Good reports explain:

What changed.

Why the change matters.

What capability or reliability improvement it unlocks.

What evidence or measurement supports the claim.

What operational outcome readers should understand.

Do not turn public reports into raw changelogs. Use concrete outcomes and plain language.

Operator-provided additions about tone, emphasis, or content for public news reporting should be incorporated into the applicable reporting rule or private customization directly. Do not ask for a separate approval step merely to apply that guidance, and do not create redundant meta-rules. Public safety, privacy, and verification remain owned by the existing publication-safety rules.

Site-specific or account-specific publishing preferences belong in private customization rows, not in public seed rules.

## Append-Only Site Publishing Guard

Publishing jobs that add public technical reports to a website should treat the normal operation as append-only content publication plus live verification. Updating a feed item, backlink, or public status URL is content work; it must not restart or recreate a production container as a routine step.

If a site is served from a container, restart/recreate that container only as a recovery action after posting or verification fails and live evidence points to a service/container fault rather than a content, JSON, link, duplicate, or validation issue. Capture the failure evidence first, use the smallest recovery action, then verify the API/page that was affected.

Cron or scheduled publishing prompts should express this as live LLM judgment, not as hidden code policy: append the post, preserve old content, update any pairing URL, verify the live API/page, and escalate or recover only when the observed runtime failure requires it.
