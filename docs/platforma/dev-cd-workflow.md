# Dev CD Workflow

This repository uses a change-aware development deployment workflow defined in
`.github/workflows/dev-cd.yml`.

## Design Goals

- derive target scope from platform metadata
- keep workflow behavior behind the `./platforma` contract
- avoid rebuilding and redeploying unchanged services
- preserve one release gate before deployment work starts

## Scope Modes

- `changed`: deploy only targets whose service paths changed
- `all`: deploy every target in the catalog
- `selected`: deploy only explicitly requested targets

`push` events default to `changed`.

`workflow_dispatch` supports all three scope modes.

## Metadata-Driven Matrix

The workflow resolves its matrix from:

```bash
./platforma targets catalog --json
```

Catalog entries provide the target name, canonical service name, version, path,
runtime, dependencies, and capabilities used by deployment jobs.

## Scope Resolution Rules

Target-specific changes:
- `services/<target>/...` selects only `<target>`

Global fan-out changes:
- `platforma`
- `config.yaml`
- `tools/platforma/**`
- `.github/workflows/**`

When a global fan-out path changes, all targets in the catalog are processed.

## Workflow Stages

1. Resolve catalog and deployment scope
2. Run `./platforma ci release-gate`
3. Execute target matrix jobs for the resolved scope
4. Run `./platforma test <target>`
5. Run `./platforma build-image <target>`
6. Execute deployment step for the target

## Manual Dispatch Inputs

- `scope`: `changed`, `all`, or `selected`
- `selected_targets`: comma-separated target list used when `scope=selected`

## Demo Deployment Step

This public repository keeps the deploy action lightweight and prints the
resolved target metadata. In a real environment, this step would publish the
artifact and update the target deployment environment using the same resolved
scope.
