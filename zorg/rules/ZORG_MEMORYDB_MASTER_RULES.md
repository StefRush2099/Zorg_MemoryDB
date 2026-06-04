# Zorg MemoryDB Public Install Rules

These are public-safe production rules for the Zorg MemoryDB package.

## PostgreSQL Is The Primary Source

PostgreSQL Zorg MemoryDB is the primary source for durable rules, processes,
and operating memory. Markdown files are bootstrap and recovery pointers only.
They may redirect an agent to DB memory, but they must not become the durable
rule store or a flat-file memory fallback.

## DB-Only Durable Memory

Zorg MemoryDB uses PostgreSQL-backed memory as the durable memory surface. `MEMORY.md` and `memory/` markdown files are not active memory. If retired memory markdown files are discovered, import them into the database with the markdown import tool and stop using the files for active recall.

## Recursive Recall Improvement

Before any response, tool use, file edit, external action, or completion claim,
query DB memory through the configured gateway. If first-pass recall misses and
deeper DB recall finds the rule, improve retrieval additively with aliases,
recall hints, relationships, indexes, materialized/search support, or structured
rule rows so the same phrasing is fast next time.

When the operator gives a system, process, or rule directive that must survive
clean installs, upgrades, migrations, or memory rebuilds, store it in structured
DB recall and publish the public-safe structure, templates, and install seed
changes to the Zorg MemoryDB add-on. Never publish private rows, credentials,
contacts, transcripts, or operator-private context.

## Preserve Structure And Rule Data

Active rules belong in `zorg_logic_rules`. Older compatibility surfaces such as
`zorg_rules` and `zorg_rule_catalog` may remain for upgrade compatibility, but
they must not remain active rule-recall sources after canonical migration.

Rules, markdown-import records, source chunks, recall hints, entity tables,
dynamic rule weights, and association tables are structural memory. Preserve
them during clean installs, upgrades, and migrations.

## Public Baseline

The public package must not contain private live memory rows, transcripts, credentials, contact data, uploads, or operator-only context. The distributable baseline keeps schema and public-safe rules only. Ordinary private/user tables start empty on a clean install.

## Backup Boundary

Before production DB structural, indexing, materialized-view, recall-routing,
vector, weighted-memory, or schema changes, create and verify a temporary local
PostgreSQL backup only. Do not commit, mirror, or push live database dumps,
rows, contacts, transcripts, credentials, or private memory to GitHub from the
public MemoryDB update path.

## LAN Command Chat

LAN command chat is packaged as fallback local communication infrastructure. The default service listens on port 3001 unless `LAN_CHAT_PORT` overrides it.
