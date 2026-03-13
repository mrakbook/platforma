# Architecture and Workflows

This document describes how command routing, discovery, orchestration, and
workflow modules compose into one delivery contract.

## System Layers

1. Command Contract:
   - `./platforma`
   - central command entrypoint for local and CI paths
2. Router and Core:
   - `tools/platforma/core/router.sh`
   - dispatches command groups and subcommands
3. Discovery and Catalog:
   - `tools/platforma/core/target.sh`
   - builds normalized target metadata catalog from service config files
4. Runtime Orchestration:
   - `tools/platforma/core/platform.sh`
   - deterministic start/stop, status, health, logs, and preflight checks
5. Task and Workflows:
   - `tools/platforma/tasks/run.sh`
   - `tools/platforma/workflows/versions.sh`
   - `tools/platforma/tasks/migrate.sh`
   - `tools/platforma/workflows/migrations.sh`
   - `tools/platforma/workflows/quality.sh`
   - `tools/platforma/workflows/ci.sh`
6. Delivery Automation:
   - `.github/workflows/dev-cd.yml`
   - `.github/scripts/resolve_dev_cd_scope.py`

## Versioning Workflow

Versioning commands are implemented in `tools/platforma/workflows/versions.sh`
and routed through `./platforma versions ...`.

Supported commands:
- `./platforma versions sync-check`
- `./platforma versions service <target> <major|minor|patch>`
- `./platforma versions platform <major|minor|patch>`
- `./platforma versions module <major|minor|patch>`

## Version Sources of Truth

- Service:
  - `services/<target>/config.yaml`
  - `services/<target>/pyproject.toml`
- Platform:
  - `config.yaml`
- Module:
  - `tools/platforma/config.yaml`

## Release-Safety Behavior

`versions sync-check` is designed as a release-safety gate. It fails on:
- invalid semver
- config and projected version drift
- naming invariant violations that break discovery contracts

## Migration Workflow

Migration files are owned by service:
- `services/<target>/database/schemas/*.sql`

Migration templates are stored in:
- `tools/platforma/templates/migration-presync.yaml`
- `tools/platforma/templates/migration-runner.py`

Supported migration commands:
- `./platforma migrations verify [target]`
- `./platforma migrate <target> [--dry-run]`

Migration verify checks:
- deterministic ordering from migration filename sequence
- strict filename convention
- non-empty SQL files
- baseline destructive-statement safety checks

Execution model:
- `--dry-run` reports ordered migrations and checksums without applying
- non-dry-run records applied migration state in `tools/platforma/state/migrations`

## CI Contract Workflow

CI command workflow logic is implemented in `tools/platforma/workflows/ci.sh`
and routed through `./platforma ci ...`.

Supported commands:
- `./platforma ci contract-check`
- `./platforma ci release-gate`

Contract-check behavior:
- verifies hardening checks and legacy command rejection
- validates workflow files use `./platforma` command paths
- blocks direct service command bypass from workflow definitions

Release gate order:
1. `./platforma migrations verify`
2. `./platforma versions sync-check`
3. `./platforma ci contract-check`
4. `./platforma quality all`

## Quality Workflow

Quality workflow logic is implemented in `tools/platforma/workflows/quality.sh`
and routed through `./platforma quality ...`.

Supported commands:
- `./platforma quality hardening`
- `./platforma quality compat`
- `./platforma quality all`

Quality checks enforce:
- legacy command path hardening
- canonical service naming invariants for compatibility

## Dev CD Workflow

Development deployment automation is defined in `.github/workflows/dev-cd.yml`.

Workflow behavior:
- resolves the target catalog from `./platforma targets catalog --json`
- computes deployment scope as `changed`, `all`, or `selected`
- runs `./platforma ci release-gate` before target deployment jobs
- builds and deploys only the resolved targets

Scope resolution rules:
- service-path changes select the matching target only
- changes to `platforma`, `config.yaml`, `tools/platforma/`, or workflow files fan out to all targets
- manual dispatch can force all targets or a selected target subset

The workflow helper `.github/scripts/resolve_dev_cd_scope.py` keeps the YAML
generic while preserving metadata-driven target selection.
