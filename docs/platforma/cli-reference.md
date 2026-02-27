# platforma CLI Reference

## Dispatch Model

The command contract is intentionally stable:

`./platforma -> router -> target/platform/workflows -> task handlers`

`./platforma` stays thin. Dispatch and implementation are split into modules.

## Module Map

- `tools/platforma/core/router.sh`: top-level command parsing and command-group dispatch
- `tools/platforma/core/target.sh`: target discovery, catalog, graph, capability matrix
- `tools/platforma/core/platform.sh`: runtime lifecycle orchestration
- `tools/platforma/tasks/run.sh`: target task execution
- `tools/platforma/lib/common.sh`: shared logging, validation, and utility helpers

## Core Commands

- `./platforma help`
- `./platforma targets list`
- `./platforma targets catalog --json`
- `./platforma targets graph --profile core`
- `./platforma targets capabilities`

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
