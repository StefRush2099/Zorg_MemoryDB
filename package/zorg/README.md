# Zorg MemoryDB Install Package

This directory contains the public-safe Zorg MemoryDB and LAN command chat install package for OpenClaw.

## Contents

- `install-zorg-memorydb.sh` installs prerequisites and copies packaged components into the OpenClaw workspace.
- `requirements.txt` declares the Python DB driver used by the recall tools.
- `db/schema.sql` creates the database structure.
- `db/memory_recall_*_2026_07_10.sql` installs the stored-procedure recall API
- `db/memory_semantic_capture_triggers_2026_07_17.sql` is applied by the installer;
  it wires all eleven typed runtime capture tables to the additive semantic/ANN
  queues. Copying the file without applying it does not activate capture.
  used by the packaged DB-first recall tools.
- `db/public_canonical_rules_update_2026_06_02.sql` is the single packaged
  rule file. It creates/updates `zorg_logic_rules`, inserts every public-safe
  addable rule, checks the expected count, and raises existing chat timing rule
  weights without creating replacement timing rules.
- Markdown rule import is not part of the installer. Existing PostgreSQL MemoryDB
  rows remain the source of truth; the installer does not create or copy Markdown
  rule or memory files.
- `lan-command-chat/` contains the LAN command chat source bundle.
- `neural-recall-activity/` contains the public production browser assets for
  the separate live Neural Recall Activity service on port 8097.
- `memory-3d/` is retired and must not be installed or restored.

## Install Behavior

The OpenClaw installer calls this bootstrap when the package contains `zorg/install-zorg-memorydb.sh`. Set `ZORG_MEMORYDB_SKIP_BOOTSTRAP=1` to skip it for a special-purpose install.

The bootstrap prepares the database and LAN Command Chat for clean installs and
existing installs. It preserves existing user data; the separate
`prepare_public_baseline.sql` file is only for building a distributable public
baseline and must not be run against a live user database.

The 8097 Neural Recall Activity service is a separate production deployment;
its server and database environment remain on the production host. Verify it
with `/api/health` and `/api/activity`. LAN Chat remains a separate web
service; the native Android client is a separate APK.

Clean installs initialize the PostgreSQL schema and native plugin/MCP path. They
do not import, create, or copy Markdown rules or legacy `memory/**/*.md` files.

When the add-on bootstrap is run through `sudo` without an explicit `OPENCLAW_HOME`, it installs into the invoking user's home directory instead of `/root`. This keeps the generated LAN command chat systemd service and its workspace on the same readable path. Set `OPENCLAW_HOME` explicitly only when a root-owned install is intentional.

## Database Authentication

The default clean-install path uses a blank PostgreSQL password and configures passwordless access only to local loopback. Remote PostgreSQL hosts are not configured as unauthenticated.

## Native Plugin/MCP Initialization

The bootstrap installs and verifies the native `zorg-memorydb` OpenClaw
plugin/MCP. It does not write usage blocks into workspace Markdown files or
copy filesystem rule/recovery documents into the workspace.

The installer enables the `zorg-memorydb` OpenClaw memory plugin/MCP, selects it
as the memory slot, and verifies its runtime tools. PostgreSQL/Zorg MemoryDB is
the recovery path for an empty, damaged, or unavailable database; Markdown is
not an alternate memory or rule channel.

The Python recall tools install their dependencies from `zorg/requirements.txt` into `.venv-sqlmem`. They also re-exec through `.venv-sqlmem/bin/python` when launched with plain `python3`, so agent-readable commands do not fail just because the system Python lacks `psycopg2`.

## Coding And Install Rule Discipline

Changes to this package must follow the documented OpenClaw/Zorg install procedures and existing package source patterns before code is written. Check the relevant docs, package metadata, lifecycle scripts, generated runtime artifacts, and clean-install behavior instead of relying on generic coding memory or assumed APIs.

An update is incomplete unless the installer applies the semantic-capture migration
and reports `semantic-capture-triggers-ok`. The ANN recall path also requires the
query-cache helper to create a `nomic-embed-text:latest` query embedding before
`public.memory_recall_v2` runs; a source-table export alone cannot provide that
runtime behavior.

Installer and package fixes are not complete until the actual documented path is verified. For this repository, that means testing the GitHub/package install path or the explicit existing-install overlay path that the documentation tells users to run, not only a local checkout.

## Direct npm prerequisite repair

`zorg/check-node-version.cjs` is intentionally duplicated from the root OpenClaw lifecycle helper into this packaged Zorg tree. Direct git installs can run npm lifecycle scripts from a temporary packed tree before every root development script is present. Keeping the Node prerequisite repair helper under `zorg/` makes the repair path available during `npm install -g --install-links=true git+https://github.com/StefRush2099/Zorg_MemoryDB.git`, including on old hosts that start with Node v12. The same helper also checks for a missing `npm` binary after Node is compatible and attempts OS package-manager repair before the install continues. When it upgrades Node from an old running npm process, it exits with a retry instruction so the repaired Node/npm runtime owns the actual package install.
