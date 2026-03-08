# platforma CLI Reference

## Dispatch Model

`./platforma -> router -> target/platform/workflows -> task handlers`

`./platforma` is intentionally thin. Execution logic is organized under
`tools/platforma/` modules.

## Module Map

- `tools/platforma/core/router.sh`: top-level command parsing and dispatch
- `tools/platforma/core/target.sh`: discovery, catalog, graph, capabilities, invariants
- `tools/platforma/core/platform.sh`: orchestration lifecycle and preflight checks
- `tools/platforma/workflows/versions.sh`: versioning workflows and sync checks
- `tools/platforma/tasks/run.sh`: task command resolution and execution
- `tools/platforma/workflows/migrations.sh`: migration verification workflow
- `tools/platforma/tasks/migrate.sh`: migration task execution
- `tools/platforma/lib/common.sh`: shared utilities and validations

## Discovery and Catalog

Discovery source:
- `services/*/config.yaml`

Catalog fields:
- `target`
- `service_key`
- `service`
- `version`
- `runtime`
- `path`
- `port`
- `dependencies`
- `capabilities`
- `health_path`

Catalog invariants:
- `target == service_key`
- `service == platforma-svc-<service_key>`
- unique `target`, `service_key`, and `service`
- dependencies must refer to existing targets
- no self-dependencies
- capability values restricted to: `run`, `lint`, `test`, `build-image`

## Runtime and Orchestration Commands

- `./platforma up --profile <name> --env <name>`
- `./platforma down`
- `./platforma restart --profile <name> --env <name>`
- `./platforma status`
- `./platforma health --profile <name>`
- `./platforma logs [target] [--follow]`
- `./platforma doctor --profile <name>`

`doctor` preflight checks:
- discovery integrity
- profile resolution
- dependency-order resolution
- required `run` capability on profile targets

## Task Commands

- `./platforma run <target>`
- `./platforma lint <target|--all>`
- `./platforma test <target|--all>`
- `./platforma build-image <target>`

## Target Commands

- `./platforma targets list`
- `./platforma targets catalog --json`
- `./platforma targets graph --profile core`
- `./platforma targets capabilities [target]`

## Workflow Commands

- `./platforma versions sync-check`
- `./platforma versions service <target> <major|minor|patch>`
- `./platforma versions platform <major|minor|patch>`
- `./platforma versions module <major|minor|patch>`
- `./platforma migrations verify [target]`
- `./platforma migrate <target> [--dry-run]`
- `./platforma ci contract-check`
- `./platforma ci release-gate`
- `./platforma quality hardening`
- `./platforma quality compat`
- `./platforma quality all`

Versioning sync-check validates:
- service config semver format
- service config and `pyproject.toml` version alignment
- canonical service naming invariants

Migration verification validates:
- migration filename format (`NNN_name.sql`)
- deterministic, sequential migration ordering
- non-empty migration files
- baseline destructive statement policy checks

## Author and Maintainer

- Boris Karaoglanov
- boris@mrakbook.com
