# Command Migration Guide

This guide describes how to migrate automation and local scripts to the
`./platforma` command contract.

## Goal

Replace ad-hoc and legacy command paths with stable platform commands so local
execution, CI checks, and release gates share one behavior surface.

## Mapping Legacy to Contract Commands

- Legacy target listing -> `./platforma targets list`
- Legacy target metadata checks -> `./platforma targets catalog --json`
- Legacy graph scripting -> `./platforma targets graph --profile core`
- Legacy release checks -> `./platforma ci release-gate`
- Direct service migration command -> `./platforma migrate <target>`

## CI Workflow Migration

1. Replace service-specific shell commands with `./platforma` equivalents.
2. Remove legacy command prefixes from workflow files.
3. Run `./platforma ci contract-check` locally before opening PR.
4. Gate release paths with `./platforma ci release-gate`.

## Migration Checklist

- Workflow files call `./platforma`
- No legacy command references remain
- Naming invariant passes (`platforma-svc-<service_key>`)
- Versions are synchronized
- Migration verification passes

## Validation Commands

```bash
./platforma ci contract-check
./platforma quality all
./platforma ci release-gate
```
