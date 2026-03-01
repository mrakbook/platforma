# Script System Diagrams

This document captures local orchestration and preflight behavior for
`./platforma`.

## Local Orchestration Lifecycle

```mermaid
flowchart TD
  A[Engineer] --> B[./platforma up --profile core --env local]
  B --> C[Resolve profile targets]
  C --> D[Compute dependency order]
  D --> E[Launch target processes in order]
  E --> F[Write PID files]
  E --> G[Write target logs]
  F --> H[./platforma status]
  G --> I[./platforma logs]
  E --> J[./platforma health]
  J --> K[HTTP health checks per target]
  H --> L[./platforma down]
  I --> L
  K --> L
  L --> M[Stop processes and cleanup PID files]
```

## Doctor Preflight Flow

```mermaid
flowchart TD
  A[Engineer] --> B[./platforma doctor --profile core]
  B --> C[Discovery check]
  C --> D[Profile resolution check]
  D --> E[Dependency order check]
  E --> F[Capabilities check]
  F --> G{All checks passed?}
  G -->|Yes| H[Ready for up/run commands]
  G -->|No| I[Exit non-zero with failure details]
```

## Runtime State Layout

```mermaid
flowchart LR
  A[./platforma up] --> B[tools/platforma/state/pids/*.pid]
  A --> C[tools/platforma/state/logs/*.log]
  D[./platforma status] --> B
  E[./platforma logs] --> C
  F[./platforma down] --> B
```
