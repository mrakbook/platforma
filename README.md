# Platforma Demo Repository

Platforma is a script-first platform engineering demo focused on delivery
consistency, not tool sprawl.

The core contract is one command surface for local, CI, and release:

`./platforma`

## Architecture Foundation (Day 01)

Delivery variance was the problem to solve. Local scripts drifted from CI
behavior and release confidence depended on tribal knowledge.

### 1. Command Contract Layer
- Single entrypoint: `./platforma`
- Same command surface across local and CI

### 2. Config and Discovery Layer
- Target metadata discovered from `services/*/config.yaml`
- Runtime catalog normalized in-memory
- Hard invariant: `service == platforma-svc-<service_key>`

### 3. Orchestration and Runtime Control
- Profile-driven target ordering via dependency graph
- PID and log tracking in `tools/platforma/state`
- Health checks per target endpoint

### 4. Service Layer
- Four demo microservices: `users`, `orders`, `notifications`, `gateway`
- Minimal hello-world business behavior by design

### 5. Governance and Delivery Guardrails
- Version sync checks and naming invariants
- Contract and quality checks in release gate workflows

## Script Platform Core (Day 02)

The Day 02 change extracts `./platforma` internals into focused modules while
keeping the command contract identical.

Flow:

`./platforma -> router -> target/platform/workflows -> task handlers`

### Module Split
- `platforma`: thin entrypoint loader and bootstrap
- `tools/platforma/core/router.sh`: command-group dispatch
- `tools/platforma/core/target.sh`: discovery, catalog, graph, capabilities
- `tools/platforma/core/platform.sh`: lifecycle operations (`up/down/restart/status/health/logs`)
- `tools/platforma/tasks/run.sh`: task execution and command resolution
- `tools/platforma/lib/common.sh`: shared utilities and validation helpers

### Why This Matters
- Local and CI execute the same command contract
- Behavior is metadata-driven, not per-service script drift
- Reliability controls stay centralized and deterministic

## Day 02 Validation Commands

```bash
./platforma help
./platforma targets list
./platforma targets capabilities
```

## Repository Scope

- `platforma`: command contract entrypoint
- `tools/platforma/config.yaml`: defaults and profiles
- `services/*/config.yaml`: target metadata and dependency model
- `docs/platforma/cli-reference.md`: CLI and dispatch reference

## Author and Maintainer

- Boris Karaoglanov
- boris@mrakbook.com
