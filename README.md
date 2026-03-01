# Platforma Demo Repository

Platforma is a script-first platform engineering demo focused on consistent
software delivery through one command contract:

`./platforma`

The repository is intentionally light on business logic and heavy on delivery
architecture, deterministic orchestration, and metadata-driven automation.

## Architecture Overview

### 1. Command Contract Layer
- Stable command surface for local, CI, and release flows
- Thin entrypoint script with modular internals
- Uniform behavior across developer machines and automation runners

### 2. Script Core Layer
- `tools/platforma/core/router.sh`: command routing and dispatch
- `tools/platforma/core/target.sh`: discovery, catalog, graph, invariants
- `tools/platforma/core/platform.sh`: local orchestration lifecycle
- `tools/platforma/tasks/run.sh`: task execution and process launch
- `tools/platforma/lib/common.sh`: shared utility and validation functions

### 3. Config and Discovery Layer
- Targets are discovered from `services/*/config.yaml`
- Metadata is normalized into a runtime catalog with:
  - `target`
  - `service_key`
  - `service`
  - `version`
  - `runtime`
  - `capabilities`
  - `dependencies`
- Canonical naming invariant enforced:
  `service == platforma-svc-<service_key>`

### 4. Orchestration That Mirrors CI
Local startup follows the same deterministic platform contract used by
automation:

- resolve profile targets
- compute dependency order
- start targets in deterministic order
- track process state with PID and log files
- expose status and health visibility through platform commands

Runtime state location:
- `tools/platforma/state/pids`
- `tools/platforma/state/logs`

### 5. Preflight and Guardrails
`./platforma doctor` runs preflight checks before execution:
- discovery validity
- profile resolution
- capability coverage for runnable targets

Guardrails keep delivery behavior predictable and reduce local/CI drift.

## Demo Services

- `users`
- `orders`
- `notifications`
- `gateway`

Services are intentionally small Python HTTP demos with metadata-defined
runtime behavior and dependencies.

## Common Commands

```bash
./platforma help
./platforma doctor --profile core
./platforma targets list
./platforma targets catalog --json
./platforma targets graph --profile core
./platforma targets capabilities
./platforma up --profile core --env local
./platforma status
./platforma health --profile core
./platforma logs
./platforma down
```

## Documentation

- `docs/platforma/cli-reference.md`
- `docs/platforma/target-config-guide.md`
- `docs/platforma/target-contribution-guide.md`
- `docs/platforma/script-system-diagrams.md`

## Author and Maintainer

- Boris Karaoglanov
- boris@mrakbook.com
