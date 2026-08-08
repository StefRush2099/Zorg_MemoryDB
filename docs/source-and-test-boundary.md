# Source and test boundary

Connector releases are prepared and published from the source system without
installing or activating the candidate on that system.

## Allowed on the source system

- Edit and inspect repository source.
- Compile and run unit, static, syntax, package, archive, privacy, and secret
  checks that do not install or activate the connector.
- Synchronize, build, restart, and verify LAN Command Chat and its gauge.
- Commit, tag, push, publish a GitHub Release, and verify its public asset.

## Forbidden on the source system

- Install, update, uninstall, link, or activate the candidate connector.
- Copy candidate code into the active OpenClaw plugin root.
- Change the active OpenClaw plugin slot or connector configuration.
- Reload or restart OpenClaw or its Gateway for connector testing.
- Claim installation, upgrade, recovery, rollback, restart, or runtime
  acceptance from source-only checks or from an older installed build.

## Separate target required

The operator supplies the installation target. Before mutation, record source
and target identity and abort when their host, OpenClaw home, workspace,
Gateway, or plugin root matches. Run installation, upgrade, failure injection,
recovery, rollback, restart, runtime registration, and the complete 13-gate
connector acceptance matrix only on that separate target.

Until a target exists, every release must state:

> External OpenClaw installation, upgrade, recovery, rollback, restart, and
> runtime-registration acceptance: pending a separately supplied test host.

Official guidance confirms that installing or updating plugin code changes the
OpenClaw runtime and requires Gateway restart/runtime inspection. Those steps
belong exclusively to the separate target:

- https://docs.openclaw.ai/tools/plugin
- https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository
