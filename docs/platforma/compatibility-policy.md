# Compatibility Policy

This repository uses semantic versioning to control compatibility across
service, platform, and module surfaces.

## Version Domains

- Service version: `services/<target>/config.yaml` and `services/<target>/pyproject.toml`
- Platform version: `config.yaml`
- Module version: `tools/platforma/config.yaml`

## Semver Rules

- `MAJOR`: incompatible change to public behavior or contract
- `MINOR`: backward-compatible feature additions
- `PATCH`: backward-compatible fixes and internal improvements

## Command Contract Compatibility

The `./platforma` command surface is a public contract.

- Removing or renaming commands is a breaking change
- Changing required arguments is a breaking change
- Adding optional flags or non-breaking subcommands is backward compatible

## CI Contract Enforcement

Automation must execute platform command paths instead of service-specific
commands.

Required:
- workflow commands call `./platforma`
- release safety checks run through `./platforma ci release-gate`

Forbidden:
- legacy command paths (`./v??`, `v??::`, `tools/v??`, `docs/v??`)
- direct service execution from workflow files

## Sync Gate

Use `./platforma versions sync-check` before release.

The check enforces:
- valid semver in service config metadata
- config and `pyproject.toml` version alignment
- canonical naming invariants required by discovery

## Release Gate Chain

Use `./platforma ci release-gate` as the single pre-release gate.

Execution order:
1. `./platforma migrations verify`
2. `./platforma versions sync-check`
3. `./platforma ci contract-check`
4. `./platforma quality all`

## Bump Workflows

- `./platforma versions service <target> <major|minor|patch>`
- `./platforma versions platform <major|minor|patch>`
- `./platforma versions module <major|minor|patch>`

Version bump commands mutate canonical version sources in place.

## Migration Compatibility

Migration workflow is part of delivery safety policy:

- `./platforma migrations verify` runs before release gate completion
- migration files must remain deterministic and ordered by filename sequence
- migration ownership stays within `services/<target>/database/schemas`

Destructive migration operations require explicit review and should be guarded
by additional controls in production systems (checksums, drift detection,
rollback procedures).
