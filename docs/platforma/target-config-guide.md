# Target Config Guide

This guide defines the metadata contract for `services/*/config.yaml` files.

## Required Keys

Each service config must include:
- `service_key`
- `service`
- `version`
- `runtime`
- `local.config_env`
- `platforma.dependencies`
- `platforma.capabilities`
- `platforma.commands`
- `platforma.health.path`

## Canonical Naming Invariant

Use this exact rule:

- `service == platforma-svc-<service_key>`

Examples:
- `service_key: users` -> `service: platforma-svc-users`
- `service_key: gateway` -> `service: platforma-svc-gateway`

## Path and Target Mapping

The directory name is the target name.

For `services/orders/config.yaml`:
- `target` is `orders`
- `service_key` must be `orders`

## Version Format

`version` must be semantic version (`MAJOR.MINOR.PATCH`), for example:
- `0.1.0`
- `1.3.7`

## Capabilities

Allowed capability values:
- `run`
- `lint`
- `test`
- `build-image`

Unknown capability names are rejected by discovery invariants.

## Dependencies

Dependencies are target names:

```yaml
platforma:
  dependencies: [users, orders]
```

Rules:
- dependency targets must exist
- target cannot depend on itself

## Minimal Example

```yaml
service_key: users
service: platforma-svc-users
version: 0.1.0
runtime: python
local:
  config_env:
    APP_HOST: 0.0.0.0
    APP_PORT: 50302
    SERVICE_NAME: platforma-svc-users
    APP_MESSAGE: "Hello from users service"
platforma:
  dependencies: []
  capabilities: [run, lint, test, build-image]
  commands:
    run: python3 src/main.py
    lint: python3 -c "import ast,pathlib; ast.parse(pathlib.Path(\"src/main.py\").read_text())"
    test: python3 -m unittest discover -s tests -p 'test_*.py'
  health:
    path: /health
```
