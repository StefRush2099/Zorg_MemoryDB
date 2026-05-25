# Hyperdine Posting Container Restart Guard

Public-site publishing jobs should treat normal posting as append-only content work plus live verification.

For Hyperdine-style feeds, the live LLM should:

- read the current feed state;
- append or update only the intended post or public status URL;
- preserve old posts;
- verify the live API and landing page after the content change.

Normal posting must not restart, rebuild, recreate, or redeploy a production Docker container. Container recovery is allowed only after posting or verification fails and live evidence points to a service/container fault rather than a content, JSON, duplicate, link, or validation issue.

When recovery is needed, capture the failure evidence first, use the smallest recovery action, then verify the affected live surface again.

Cron prompts should express this as natural-language LLM judgment. They should say append/update/verify, not make container restart a routine publishing step.
