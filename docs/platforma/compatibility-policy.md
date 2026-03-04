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

## Sync Gate

Use `./platforma versions sync-check` before release.

The check enforces:
- valid semver in service config metadata
- config and `pyproject.toml` version alignment
- canonical naming invariants required by discovery

## Bump Workflows

- `./platforma versions service <target> <major|minor|patch>`
- `./platforma versions platform <major|minor|patch>`
- `./platforma versions module <major|minor|patch>`

Version bump commands mutate canonical version sources in place.
