# LLM application checklist

Use this checklist when applying generic-rule-manifest.json to an install.

1. Confirm the target repository is Zorg_MemoryDB or a clean install derived from it.
2. Confirm DB backup policy is satisfied before applying SQL to a production database.
3. Read each rule object in generic-rule-manifest.json.
4. Reject any rule text that contains local host/IP identity, operator-only names, private memory, credentials, transcripts, contacts, or live state.
5. Insert missing markdown blocks in the listed markdown_targets; do not duplicate blocks already present.
6. Apply upsert-generic-clean-install-rules.sql.
7. Refresh recall/materialized/search surfaces when available.
8. Verify DB recall can find:
   - backend memory repair without approval
   - clean install DB-only memory
   - base install permanent engineering rules
9. Report counts:
   - rules present in markdown
   - rules present in zorg_logic_rules
   - rules present as recall hints
   - rules excluded as non-generic

