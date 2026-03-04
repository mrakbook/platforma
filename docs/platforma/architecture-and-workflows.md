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
