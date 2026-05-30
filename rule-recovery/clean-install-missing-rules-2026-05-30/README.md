# Clean-install missing-rule recovery - 2026-05-30

Purpose: give an LLM-readable, portable recovery packet for the generic rules that were present in markdown but did not reliably survive into zorg_logic_rules after clean installs.

This directory is intentionally documentation plus DB seed data only. It does not change installer behavior, package metadata, runtime scripts, services, auth, routing, or live host configuration.

## Scope

Generic rules to restore:

1. Backend memory repair supremacy
2. Clean-install DB-only memory hard stop
3. Base install permanent engineering rules

Excluded from this recovery packet:

- Local host identity/IP rules
- Operator-specific wording
- Placeholder profile text
- Private context, credentials, live rows, transcripts, or contact data

## How an LLM should apply this packet

1. Read generic-rule-manifest.json.
2. For each markdown_targets entry, inspect the target file.
3. If the rule block is missing, insert the canonical markdown from the matching rule object at the requested location.
4. Apply upsert-generic-clean-install-rules.sql to the target PostgreSQL database after normal DB backup policy is satisfied.
5. Refresh recall/search/materialized surfaces if the install provides refresh functions.
6. Verify at least these natural-language searches return the rules near the top:
   - backend memory repair is above approval
   - clean install must not use memory markdown files
   - base install rules survive clean install

## Expected result

After application, a clean install should have these three generic rules in both markdown and structured DB recall. These rules are intended to supplement the broader markdown-rule sync process; they are not a replacement for importing all qualifying core markdown rules.

