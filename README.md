# Platforma Demo Repository

Platforma is a script-first platform engineering demo focused on delivery
consistency, not tool sprawl.

The core rule is simple: all local, CI, and release execution flows through one
contract:

`./platforma`

## Day 01 Architecture Foundation

Delivery variance was the problem to solve. Local scripts drifted from CI
behavior and release confidence depended on tribal knowledge. This repo starts
with the architectural contract that removes that drift.

### 1. Command Contract Layer
- Single entrypoint: `./platforma`
- Router dispatches command groups for targets, task execution, platform ops,
  and workflows
- Same surface and behavior locally and in CI

### 2. Config and Discovery Layer
- Metadata is discovered from `services/*/config.yaml`
- Catalog fields include target name, version, runtime, dependencies, and
  capabilities
- Hard invariant: `service == platforma-svc-<service_key>`

### 3. Orchestration and Runtime Control
- Profile-based startup and dependency ordering
- Process state tracked through PID and log files
- Health checks executed against each service endpoint

### 4. Service Layer
- Four demo microservices with intentionally simple behavior:
  `users`, `orders`, `notifications`, `gateway`
- Each service carries config metadata for runtime and command capabilities
- Architecture pattern is the point, not business logic

### 5. Governance and Delivery Guardrails
- Version sync and contract checks are first-class workflows
- Quality hardening blocks legacy command paths
- Release gating is designed as one trusted command path

## Repository Scope

- `platforma`: command contract and orchestration entrypoint
- `tools/platforma/config.yaml`: module defaults and profiles
- `services/*/config.yaml`: target metadata and dependency model
- `docs/platforma/cli-reference.md`: CLI contract reference
- `docs/platforma/architecture-diagram.md`: architecture and Mermaid diagrams

## Day 01 Validation Commands

```bash
./platforma targets catalog --json
./platforma targets graph --profile core
./platforma targets capabilities
```

## Author and Maintainer

- Boris Karaoglanov
- boris@mrakbook.com
