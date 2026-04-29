# Public Sanitization Policy

This repository must remain safe for public use.

Allowed:

- schema-only SQL
- empty templates
- generic tooling
- generic rules and docs
- synthetic examples clearly marked as examples

Forbidden:

- production table rows
- chat/session logs
- personal profile data
- credentials, tokens, cookies, OAuth material, SSH keys
- private IPs, hostnames, service URLs, account names, or internal infrastructure details
- private project data unless deliberately sanitized and approved

Before publishing, run the scan commands in `docs/verification.md`.
