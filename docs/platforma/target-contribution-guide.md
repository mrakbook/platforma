# Target Contribution Guide

This guide describes how to add a new target to Platforma with metadata-only
changes.

## Steps

1. Create a new directory under `services/<target>/`.
2. Add `services/<target>/config.yaml` using the target config contract.
3. Ensure canonical naming:
   - `service_key: <target>`
   - `service: platforma-svc-<target>`
4. Add runtime entrypoint and tests for your service runtime.
5. Add the target to a profile in `tools/platforma/config.yaml` if needed.

## Validation Commands

Run these commands after adding or changing target metadata:

```bash
./platforma targets list
./platforma targets catalog --json
./platforma targets graph --profile core
./platforma targets capabilities
```

## Invariant Checklist

- [ ] Target directory matches `service_key`
- [ ] `service` uses canonical `platforma-svc-<service_key>` format
- [ ] `version` is valid semver
- [ ] dependencies refer to existing targets
- [ ] no self-dependencies
- [ ] capabilities use supported values only

## Why This Flow

Platforma is discovery-first. New target onboarding should be metadata work,
not pipeline rewrites. If metadata is valid, the command contract automatically
includes the service in listing, catalog, graph, and capability output.
