# platforma CLI Reference

## Dispatch Model

`./platforma -> router -> target/platform/workflows -> task handlers`

`./platforma` is a thin bootstrapper. Command behavior is implemented in modular
shell components under `tools/platforma/`.

## Module Map

- `tools/platforma/core/router.sh`: top-level command parsing and dispatch
- `tools/platforma/core/target.sh`: discovery, catalog, graph, capabilities, invariants
- `tools/platforma/core/platform.sh`: orchestration lifecycle operations
- `tools/platforma/tasks/run.sh`: task command resolution and execution
- `tools/platforma/lib/common.sh`: shared utility and validation functions

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
- unique `target`, `service_key`, `service`
- dependency targets must exist
- no self-dependencies
- capability values restricted to `run`, `lint`, `test`, `build-image`

## Core Commands

- `./platforma help`
- `./platforma targets list`
- `./platforma targets catalog --json`
- `./platforma targets graph --profile core`
- `./platforma targets capabilities [target]`

## Runtime Commands

- `./platforma run <target>`
- `./platforma lint <target|--all>`
- `./platforma test <target|--all>`
- `./platforma build-image <target>`
- `./platforma up --profile core`
- `./platforma down`
- `./platforma restart --profile core`
- `./platforma status`
- `./platforma health --profile core`
- `./platforma logs [target] [--follow]`

## Workflow Commands

- `./platforma versions sync-check`
- `./platforma versions service <target> <major|minor|patch>`
- `./platforma versions platform <major|minor|patch>`
- `./platforma versions module <major|minor|patch>`
- `./platforma migrations verify`
- `./platforma ci contract-check`
- `./platforma ci release-gate`
- `./platforma quality hardening`
- `./platforma quality compat`
- `./platforma quality all`

## Author and Maintainer

- Boris Karaoglanov
- boris@mrakbook.com
