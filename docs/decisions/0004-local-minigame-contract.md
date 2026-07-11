# Decision: Stabilize the local minigame contract before networking

Date: 2026-07-11

Status: Accepted

## Implementation checkpoint

Contract version 1 is implemented in `scripts/shared/minigames/` with a scaffold generator, development harness, `reference-tap` example, and automated conformance checks. It is not yet connected to the main app's local phase proof or ENet placeholder flow; that current boundary is documented in the [minigame integration contract](../architecture/minigame-integration.md#current-implementation-boundary).

## Context

Bean Party wants independently contributed minigames to integrate without changing the board, the shared shell, or another minigame. The design and integration documents already describe ownership and lifecycle goals, but contributors do not yet have a code-level contract, an executable example, or automated conformance checks.

Local play is the project's fastest iteration path. The networking architecture still needs its planned `HOST_SNAPSHOT` and `HOST_ACTION` spikes, so freezing a combined local-and-network API now would either block local contributions or prematurely stabilize unvalidated netcode.

The project also needs an explicit boundary between a minigame outcome and the shared board economy. If each minigame chooses bean or board rewards, balance policy leaks out of the shell and becomes difficult to change consistently.

## Options considered

- **Wait for the networking API** — one eventual API surface, but local contributors remain responsible for inventing integration behavior in the meantime.
- **Allow each minigame to integrate ad hoc** — fast for the first implementation, but loading, input, result, retry, and teardown behavior would diverge immediately.
- **Stabilize a versioned local contract now and add networking later** — creates an immediate contribution path while keeping network-specific behavior provisional.

## Decision

Adopt local minigame contract version 1 as a stable shared interface. The contract consists of a manifest, immutable setup context, shell-provided per-player input source, controller lifecycle, outcome-only result, registry, and shell-owned runner.

The shared shell owns scene loading and unloading, player and input assignments, phase transitions, pause and forced exit, result acceptance, and board reward policy. A minigame owns its rules, presentation, local state, scoring, and cleanup. A completed minigame returns placements, including tie groups, and optional per-player scores. It does not return beans, items, board advantages, or other economy mutations.

Network-specific setup, replication, authority, and transport APIs remain provisional until the networking plan's validation milestones complete. They must extend the local contract instead of creating a separate minigame lifecycle.

A proposal must receive explicit approval before substantial implementation intended for integration begins. Lightweight experiments may proceed without approval in personal branches or draft pull requests, but they do not establish shared conventions and are not integration-ready contributions.

## Consequences

- Breaking local contract changes require a new contract version and a decision-record update.
- Contributors receive a scaffold, reference implementation, development harness, and automated contract checks.
- The shell translates placements and scores into board rewards, so economy changes do not require editing minigames.
- Local minigames do not access physical device assignments, raw networking peers, or another minigame directly.
- Networking metadata may be declared for planning, but it does not make a minigame network-capable until the provisional networking contract is implemented and validated.
- Licensing remains an explicitly deferred project decision. Existing originality, permission, and provenance requirements still apply.
