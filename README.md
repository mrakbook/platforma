# Platforma Demo Repository

Platforma is a script-first platform engineering demo focused on consistent
software delivery through one contract:

`./platforma`

The project is intentionally minimal in business logic and heavy on delivery
architecture, orchestration discipline, and metadata-driven automation.

## Architecture Overview

### Command Contract Layer
- One stable command surface for local and CI execution
- Thin entrypoint script that delegates to modular internals
- Consistent command behavior for `targets`, `runtime`, and `workflow` groups

### Script Core Layer
- `tools/platforma/core/router.sh`: command routing and dispatch
- `tools/platforma/core/target.sh`: discovery, catalog, graph, invariants
- `tools/platforma/core/platform.sh`: lifecycle orchestration
- `tools/platforma/tasks/run.sh`: task execution
- `tools/platforma/lib/common.sh`: shared utilities

### Config and Discovery Layer
- All targets are discovered from `services/*/config.yaml`
- Metadata is normalized into a runtime catalog with:
  - `target`
  - `service_key`
  - `service`
  - `version`
  - `runtime`
  - `capabilities`
  - `dependencies`
- Hard invariant enforced: `service == platforma-svc-<service_key>`

### Runtime and Orchestration Layer
- Profile-based target resolution from `tools/platforma/config.yaml`
- Dependency-ordered startup via topological traversal
- PID/log state tracking in `tools/platforma/state`
- Health checks resolved from target metadata

### Governance and Quality Layer
- Catalog invariants enforced before command execution
- Naming and version consistency checks for reliable release flow
- Contract and quality checks centralized in platform workflows

## Demo Services

- `users`
- `orders`
- `notifications`
- `gateway`

Each service is a small Python HTTP demo with metadata-defined commands and
runtime settings.

## Common Commands

```bash
./platforma help
./platforma targets list
./platforma targets catalog --json
./platforma targets graph --profile core
./platforma targets capabilities
./platforma up --profile core
./platforma status
./platforma health
./platforma down
```

## Documentation

- `docs/platforma/cli-reference.md`
- `docs/platforma/target-config-guide.md`
- `docs/platforma/target-contribution-guide.md`

## Author and Maintainer

- Boris Karaoglanov
- boris@mrakbook.com
