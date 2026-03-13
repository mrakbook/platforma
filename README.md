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
- `tools/platforma/tasks/migrate.sh`: migration task execution
- `tools/platforma/workflows/migrations.sh`: migration verification workflow
- `tools/platforma/workflows/quality.sh`: hardening and compatibility checks
- `tools/platforma/workflows/ci.sh`: CI contract-check and release gate chain
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

### 6. Versioning Workflow
Versioning is treated as platform workflow, not a manual step. Three version
domains are tracked:

- service version (`services/*/config.yaml` and `services/*/pyproject.toml`)
- platform version (`config.yaml`)
- module version (`tools/platforma/config.yaml`)

The sync gate is:

- `./platforma versions sync-check`

Version bumps are exposed through one command surface:

- `./platforma versions service <target> <major|minor|patch>`
- `./platforma versions platform <major|minor|patch>`
- `./platforma versions module <major|minor|patch>`

### 7. Migration Safety Workflow
Migration execution is guarded by a verify-before-run workflow:

- deterministic ordering by numbered SQL files
- explicit target ownership under `services/<target>/database/schemas`
- safety checks before execution (naming, sequence, and destructive statement policy)

Primary commands:

- `./platforma migrations verify`
- `./platforma migrate <target> --dry-run`

### 8. CI Contract and Quality Gates
Automation follows the same command contract as local execution:

- CI workflows must run `./platforma` commands
- legacy command paths are blocked
- release gate is chained under one command

Gate chain:

- `./platforma migrations verify`
- `./platforma versions sync-check`
- `./platforma ci contract-check`
- `./platforma quality all`

Single entrypoint:

- `./platforma ci release-gate`

### 9. Change-Aware Dev CD
Development deployment scope is derived from platform metadata instead of
hardcoded per-service workflow logic.

- matrix source comes from `./platforma targets catalog --json`
- release gate runs before deployment work starts
- changed service paths deploy only their matching targets
- platform-level changes fan out to all targets
- manual runs can choose `changed`, `all`, or `selected` scope

Workflow entrypoint:

- `.github/workflows/dev-cd.yml`

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
./platforma versions sync-check
./platforma migrations verify
./platforma migrate users --dry-run
./platforma ci contract-check
./platforma quality all
./platforma ci release-gate
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
- `docs/platforma/compatibility-policy.md`
- `docs/platforma/architecture-and-workflows.md`
- `docs/platforma/migration-guide.md`
- `docs/platforma/dev-cd-workflow.md`

## Author and Maintainer

- Boris Karaoglanov
- boris@mrakbook.com
