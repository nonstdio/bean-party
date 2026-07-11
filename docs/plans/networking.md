# Networking implementation plan

Status: **Active**

This plan breaks Bean Party online networking into reviewable milestones. Each milestone should ship as its own focused pull request. Do not begin production netcode until [Decision 0003](../decisions/0003-peer-hosted-networking.md) has passed human review.

Related documents:

- [Networking architecture](../architecture/networking.md) — topology, authority, phases, messages
- [Minigame integration contract](../architecture/minigame-integration.md) — network-facing minigame rules
- [Godot project architecture](../architecture/godot-project.md) — repository layout
- [Godot 3D movement standards](../architecture/godot-3d-movement.md) — player movement engineering standard (spikes may document deviations)

## Principles

- Implement **offline session model first**, then attach ENet, then minigames.
- Board and minigames never construct transport peers directly.
- Prefer automated consistency checks (phase, results, snapshot hash) over subjective “feels fine” alone.
- Human playtesting remains required for perceived responsiveness.

## Milestone overview

Milestones are marked **Implemented proof** when their intended code/test surface exists in the repository, even if the milestone's complete manual stop condition is not recorded. **In progress** means a required behavior is known to be absent. No milestone below is labeled complete without its required manual evidence.

| # | Milestone | Status in current artifacts | Depends on |
| --- | --- | --- | --- |
| 1 | Offline session / `PlayerSlot` model | Implemented proof; session-local controller indices exist, but physical input routing and recorded manual 2/4-player evidence are absent | — |
| 2 | Local phase state machine + snapshots | Implemented proof with unit coverage and debug UI; manual completion evidence is not stored | 1 |
| 3 | ENet host/join harness | Implemented proof with lifecycle/teardown/echo unit coverage; multi-instance, LAN, and internet evidence is not stored | 1 |
| 4 | Networked lobby | Implemented proof with ownership/cap/round-trip unit coverage; **launch policy: one `PlayerSlot` per peer online** (multi-local per peer deferred); manual malformed-RPC and multi-peer evidence is not stored | 1, 3 |
| 5 | Authoritative board stub | Implemented proof with authority, frozen-roster, and hash agreement unit coverage; manual peer testing is not stored | 2, 4 |
| 6 | Networked scene flow (briefing → results) | In progress: placeholder flow, phase agreement, and result/reward idempotency are covered; disconnect behavior and required manual two-peer validation are absent | 2, 4, 5 |
| 7 | Simple movement minigame (`HOST_SNAPSHOT`) | Implemented proof: Snapshot Arena, `NetworkMinigameSession`, result/hash agreement unit coverage; online lobby enforces one player per peer; durable 4-player and bandwidth evidence not stored | 6 |
| 8 | Prediction / reconciliation experiment (`HOST_SNAPSHOT`, optional) | Implemented proof: client prediction, input replay, blend reconciliation; preliminary manual findings at 0 ms, 50 ms, and 50 ms + 10% drop | 7 |
| 9 | Disconnect recovery (non-host reconnect, clean host exit) | In progress: session-end signal, inactive slots during match, board-phase reclaim; manual disconnect matrix still open | 2, 6, 7 |
| 10 | 3D combat spike (`HOST_ACTION`) + action-netcode kit | Implemented proof (spike): action-netcode kit, `NetworkActionMinigameSession`, Action Spike graybox with tank movement, hitscan combat, ticked input/replay, and tie-aware results; lag compensation, projectiles, physics props, respawn, and full [movement-standard](../architecture/godot-3d-movement.md) compliance deferred; manual latency matrix not stored | 7, 8 |
| 11 | Steam transport investigation | Not started | 3 |
| 12 | Formal minigame networking API stabilization | Not started | 7, 9, 10 |
| 13 | Host migration (Case B) — post-acceptance | Deferred / not started | 9, 12 |

The status above is based on executable code, tests, scenes, tools, and durable documentation in this repository. Pull-request descriptions or informal playtests that are not preserved here are not counted as completion evidence. See [Runtime debug harnesses](../guides/runtime-debug-harnesses.md) for the exact current workflows and limitations.

---

## Milestone 1: Offline session and player model

Implementation status: **Implemented proof; physical input routing and durable manual evidence remain.**

### Purpose

Separate **network peers** from logical **`PlayerSlot`s** so local couch play and future online play share one identity model.

### Player-facing proof

From the starter app, two to four local players can join a couch session with distinct names/colors; the UI shows who occupies each slot without any network connection.

### Implementation boundary

- `scripts/shared/` — implemented `PlayerSlot` data and `OfflineMatchSession`
- `tests/unit/` — slot assignment, cap at `MAX_PLAYERS = 4`
- No `MultiplayerPeer`, no board, no minigame changes required

### Automated tests

- Cannot exceed 4 `PlayerSlot`s
- `player_id` stable when toggling ready
- Multiple `local_player_index` values on one offline “peer”; controller mapping stays local

### Manual tests

- 2-player and 4-player couch assignment on one machine
- Reassign controller slot without duplicating `player_id`

### Stop condition

Shell can enumerate `PlayerSlot`s and map inputs by `local_player_index` → local controller on the owning machine in a headless or minimal scene test.

### Spike outcomes and remaining questions

- The current proof uses incremental match-scoped ids (`player_N`) and never reuses an id after removal.
- Removing a local slot compacts `local_player_index` values. There is no persistent empty-slot model.
- Mapping the stored local device slot to real gameplay input remains outside this milestone proof.

---

## Milestone 2: Local phase state machine and phase-boundary snapshots

Implementation status: **Implemented proof with automated coverage; durable manual completion evidence remains.**

### Purpose

Implement the host-owned phase machine and snapshot capture/restores **without network** so recovery logic is testable offline.

### Player-facing proof

A debug or stub flow walks Lobby → Board (stub) → Briefing → Results → Board locally; restarting from a saved snapshot restores the same phase and board stub state.

### Implementation boundary

- `scripts/shared/` — implemented local phase controller, snapshot model/serializer, and board stub
- `tests/unit/` — transition guards, snapshot round-trip, `match_epoch` increment
- No ENet yet; “host” is always the local process

### Automated tests

- Illegal transitions rejected (e.g. `ActiveMinigame` → `Lobby` without teardown)
- Snapshot round-trip: hash equality after serialize/deserialize
- Snapshot contains all fields listed in [networking architecture](../architecture/networking.md#phase-boundary-snapshots)

### Manual tests

- Save snapshot on board, force reload, confirm economy/phase restored
- Walk full phase diagram once on one machine

### Stop condition

GUT tests prove snapshot round-trip and phase guards; manual run completes one full loop.

### Spike outcomes

- `MatchSnapshotSerializer` uses canonicalized JSON and stores 64-bit RNG seed/state values as decimal strings to preserve round trips.
- The offline controller increments `match_epoch` on every snapshot capture and advances it monotonically on restore. The separate network phase proof currently increments its epoch on host phase transitions; the two proofs are not unified.

---

## Milestone 3: ENet host/join harness

Implementation status: **Implemented proof; required manual network-path evidence remains.**

### Purpose

Prove LAN/direct-IP connect/disconnect through a **session layer** that wraps `ENetMultiplayerPeer`, not scattered peer creation.

### Player-facing proof

Two instances on one machine: host clicks “Host,” client enters address and joins; both see connected peer list; clean disconnect returns to menu.

### Implementation boundary

- `scripts/shared/` — implemented `MatchSession` and concrete `EnetTransportAdapter` debug boundary
- Minimal UI in `scenes/app/` or debug scene only
- No board, no minigame

### Automated tests

- Headless or integration test: host starts, client connects, peer count correct (if Godot headless multiplayer supports; otherwise scripted manual checklist in PR)
- Session teardown clears `multiplayer.multiplayer_peer`

### Manual tests

- Host/join on one machine (two windows)
- Host/join two LAN machines
- Host/join two internet machines (port forward or LAN emulator documented in PR)

### Stop condition

Reliable RPC echo test passes host → client and client → host; disconnect on either side does not crash.

### Open questions before milestone 4

- Port `7777` is the implemented debug default; firewall and internet-hosting guidance remains open.
- Heartbeat interval for detecting silent drops

---

## Milestone 4: Networked lobby

Implementation status: **Implemented proof; required manual multi-peer evidence remains.** Online launch policy is **one `PlayerSlot` per peer**; multi-local online play (multiple controllers on one connected machine) is **deferred**.

### Purpose

Sync `PlayerSlot` assignment across peers. The repository still models multiple `local_player_index` values per peer for offline/couch proofs, but the networked lobby authority rejects a second slot for the same `peer_id`.

### Player-facing proof

Up to four peers each join with one local player; the lobby shows one `PlayerSlot` per connected peer with correct ownership and ready states.

### Implementation boundary

- `scripts/shared/` — lobby authority on host, slot claim validation, one-slot-per-peer enforcement online
- `tests/unit/` — reject slot claim from wrong `peer_id`, reject fifth player, reject second slot for same peer

### Automated tests

- Host rejects `PlayerSlot` claim for another peer's `local_player_index`
- Host rejects match start when over `MAX_PLAYERS` (fifth player)
- Host rejects a second slot for the same `peer_id`

### Manual tests

- 4 peers × 1 local player on one machine (4 windows)
- Malformed ready RPC ignored (manual or test double)

### Stop condition

All peers display identical lobby `PlayerSlot` list and ready flags after each change.

### Spike outcomes and remaining questions

- Multi-local online couch (for example 2 peers × 2 local `PlayerSlot`s) remains a deferred layout. Offline milestone 1 still supports multiple local players on one offline peer.
- Lobby host migration needed before match start? (**deferred** until 13)
- Display name profanity/trust (**deferred**)

### Open questions before milestone 5

- When to revisit multi-local online play relative to controller routing and bandwidth goals

---

## Milestone 5: Authoritative board stub

Implementation status: **Implemented proof; required manual peer evidence remains.**

### Purpose

Host-owned board with client move **requests** and reliable application broadcasts.

### Player-facing proof

Clients propose moves; only host applies; all peers see the same board stub state after each turn.

### Implementation boundary

- `scripts/shared/` or `scenes/shared/` — minimal board stub only
- No full board art/rules—enough to validate authority

### Automated tests

- Client-side direct state mutation API absent or no-op
- Host rejects out-of-turn move
- Board-state hash matches on host and client after each applied move (integration test)

### Manual tests

- 2–4 peers take turns on stub board
- Client spam invalid moves does not desync

### Stop condition

Board-state hash equal on all peers after every turn in automated test.

### Open questions before milestone 6

- The stub advances sequentially through the frozen board roster; real board turn-order and tie-breaking policy remains open.
- How board stub connects to real board design later

---

## Milestone 6: Networked scene loading, briefing, readiness, countdown, and results

Implementation status: **In progress.** The host-synchronized placeholder flow and automated phase/idempotency checks exist. Required manual two-peer evidence is not stored, and disconnect during briefing is unresolved: the frozen phase roster can continue waiting on a departed slot.

### Purpose

Host-driven phase transitions with scene loads and synchronized briefing/countdown/results **without** a full minigame sim yet (placeholder scene).

### Player-facing proof

From board stub, host starts minigame flow: all peers load placeholder, ready up, see countdown, enter placeholder “active” scene, host ends round, all see results, return to board with rewards applied once.

### Implementation boundary

- Shell scene flow in `scenes/app/` + `scripts/shared/` phase controller
- Placeholder minigame scene under `scenes/shared/` or `minigames/_network_stub/`

### Automated tests

- Phase agreement: all peers report same phase after each transition (test harness with N mock peers if feasible)
- Results applied once per `result_id` / `reward_application_id` (idempotency test)

### Manual tests

- Full phase loop with 2 peers
- Client disconnect during briefing → slot inactive; host can continue or wait (document chosen behavior)

### Stop condition

Phase agreement test green; manual 2-peer loop completes without duplicate reward application.

### Open questions before milestone 7

- Scene load failure on one peer (retry? kick?) — **open question**
- Countdown skew tolerance

---

## Milestone 7: One simple movement minigame using host snapshots

Implementation status: **Implemented proof; durable manual 4-player and bandwidth evidence remain.**

### Purpose

Validate `HOST_SNAPSHOT` profile end-to-end: input upstream, host sim, snapshots downstream, interpolation on clients.

### Player-facing proof

2–4 peers play a graybox movement minigame (e.g. arena with position sync); remote beans move smoothly; host declares winner; results match on all peers.

### Implementation boundary

- One minigame under `minigames/<slug>/` — network-capable, `HOST_SNAPSHOT`
- Shell integration only through approved session interface
- May adapt an existing graybox if on `main`; do not couple unrelated minigame PRs

### Automated tests

- Result agreement test: same placement order on host and clients after forced end
- Snapshot hash at minigame end (optional mid-run sampling)

### Manual tests

- Up to 4 peers × 1 local `PlayerSlot` each (launch policy); 2-peer loopback runs are acceptable preliminary evidence
- Record messages/sec and KB/s for results table

### Stop condition

Result agreement automated test passes; manual playtest at 4 players with no persistent desync.

### Spike outcomes and remaining questions

- Snapshot Arena (`minigames/snapshot-arena/`) is the milestone 7 graybox. The shell drives it through `NetworkMinigameSession` with host-authoritative simulation at **20 Hz** snapshots and client interpolation for remote players.
- Automated coverage includes result agreement, snapshot hash agreement after apply, remote input ownership validation, and early-win final snapshot broadcast.
- The main debug shell no longer exposes offline couch sessions; network host/join is the primary manual path. Local minigame work remains on `res://scenes/dev/minigame_harness.tscn`.
- Online lobby policy is **one local player per peer** (four players still means up to four peers). The lobby UI auto-joins each connected peer with a single slot and shows per-peer RTT from periodic echo probes.
- Durable manual evidence for 4 `PlayerSlot`s across peers, messages/sec, and KB/s is not stored in the repository.

### Open questions before milestone 8

- 30 vs 60 Hz sim for this minigame — current proof uses 20 Hz host snapshots

---

## Milestone 8: Prediction and reconciliation experiment (`HOST_SNAPSHOT`)

Implementation status: **In progress.** Client prediction with input tick ack/replay, correction telemetry, and blend display reconciliation are implemented; the full latency matrix and default recommendation are not finalized.

### Purpose

Measure whether milestone 7 needs local prediction for acceptable responsiveness at 50–100 ms simulated latency. Scope is **`HOST_SNAPSHOT` only**—`HOST_ACTION` requires prediction by design and is validated in milestone 10.

### Player-facing proof

Same minigame with optional prediction on local player; debug overlay shows correction magnitude/frequency.

### Implementation boundary

- `NetworkMinigameSession` — client input tick IDs, retained local input history, snapshot `acked_input_tick`, authority reset + replay of unacknowledged inputs, blend correction offsets
- `HostSnapshotPredictionTracker` — correction telemetry for debug overlay
- Snapshot Arena status line surfaces correction stats during networked play

### Automated tests

- Correction count and replay: delayed snapshot with continuous input keeps predicted state ahead of acknowledged authority (unit test)

### Manual tests

- Latency simulation: 0, 50, 100, ~150 ms via OS QoS, [clumsy](https://jagt.github.io/clumsy/), or Linux `tc netem`
- Jitter and ~1–2% packet loss
- Differing render FPS (30 vs 60 vs 120) on host vs client

### Stop condition

Documented table: latency vs correction frequency vs player verdict; recommendation to adopt or skip default prediction.

### Spike outcomes (preliminary)

Manual testing used two Godot instances on one machine (host + client), Clumsy `outbound and loopback` lag on the client, and the Snapshot Arena status overlay (`pred corrections`, `last`, `max` px). Prediction defaults **on** for networked clients. These results are **loopback-only preliminary evidence**; multi-computer LAN validation remains open.

| Added latency | Reconcile mode | Corrections (order of magnitude) | Max correction (order of magnitude) | Player verdict (informal) |
| --- | --- | --- | --- | --- |
| ~0 ms | Snap (initial) | ~100+ per short session | ~2–3 px | Responsive; corrections barely visible |
| ~50 ms | Snap (initial) | Frequent (~20 Hz) | Larger than baseline | Visible jitter and snap-back to prior position |
| ~50 ms | Blend (error decay) | Similar counts to snap | Similar magnitudes | **Significantly less jitter**; smoother drift-in |
| ~50 ms + ~10% drop (in/out) | Blend + replay | Not recorded | Not recorded | **Felt good** (loopback preliminary) |

**Working recommendation:** keep client prediction enabled for local movement; on each snapshot apply authoritative position for the acknowledged input tick, replay newer local inputs, and use **blend (error decay)** for display correction rather than hard snap.

Still open: 100 ms and ~150 ms profiles, jitter + 1–2% loss, differing render FPS, prediction-off baseline at each tier, and whether blend parameters should be shared-shell defaults vs minigame-tuned.

### Open questions before milestone 9

- ~~Snap vs blend correction default~~ — preliminary evidence favors **blend** for player-facing movement at moderate latency
- Whether prediction ships as the default recommendation for all `HOST_SNAPSHOT` minigames or only Snapshot Arena until milestone 12

---

## Milestone 9: Disconnect recovery (v1 scope)

### Purpose

Implement **non-host disconnect**, **non-host reconnect at phase boundaries**, and **clean session end when the host leaves in any phase**. **Host migration and abort/replay after host loss are out of scope**—see milestone 13.

### Player-facing proof

- **Host Alt+F4 during any phase** (lobby, board, minigame, results): all peers see a clear “host left” message and return to menu/lobby—not a silent stall
- **Non-host disconnect:** slot becomes inactive; match can continue
- **Non-host reconnect** at phase boundary restores the correct slot from snapshot

### Implementation boundary

- `scripts/shared/` — disconnect detection, non-host reconnect, clean host-departure handling, idempotency keys for reliable side effects
- Disconnect matrix tests in `tests/`

### Automated tests

- Non-host disconnect during board: slot `inactive`, board hash still matches
- Host disconnect during `ActiveMinigame`, `Board`, and `Lobby`: all clients transition to ended/lobby state within N seconds
- Duplicate `result_id` / `reward_application_id` ignored (no double apply)
- No duplicate minigame start in soak test

### Manual tests

- Host disconnect during each major phase (matrix below)—expect **session end**, not replay
- Reconnecting non-host client at phase boundary restores correct slot

### Stop condition

Non-host disconnect/reconnect tests pass; **every host-departure scenario ends the session cleanly** with explicit UI. **Decision 0003 may move toward Accepted after milestones 1–7 and this milestone pass review**—milestones 10, 12, and 13 are not required for **Accepted**.

### Open questions before milestone 10

- Reconnect grace period at phase boundaries
- Whether inactive slots block match start

---

## Milestone 10: 3D combat spike (`HOST_ACTION`) and action-netcode kit

Implementation status: **Implemented proof (accepted spike).** Netcode kit, Action Spike minigame, and automated coverage exist. Full combat scope (projectiles, props, respawn, lag compensation) and [Godot 3D movement standards](../architecture/godot-3d-movement.md) compliance remain follow-up work. Durable manual impairment evidence is not stored.

### Purpose

Validate the networking contract for Bean Battles-like 3D combat **before** the minigame API is frozen. A movement-only `HOST_SNAPSHOT` minigame (milestone 7) is insufficient to prove hitscan, projectiles, damage, physics props, and entity lifecycles.

### Player-facing proof (delivered in spike)

2–4 peers play a bounded **90 second** graybox combat arena containing:

- tank-style character movement and jumping;
- one host-authoritative hitscan weapon with health and eliminations;
- last-standing win with tie-aware placements on timeout or equal scores.

Local player movement uses required client prediction with host reconciliation. Remote players use snapshot-driven display interpolation (not yet full movement-standard buffered interpolation).

### Spike deviations from movement standard

Documented per [Godot 3D movement standards](../architecture/godot-3d-movement.md) spike policy:

- clamp-based motor (`HostActionSimulator`) instead of `CharacterBody3D` / `move_and_slide()`;
- visible cover is cosmetic (no matching collision bodies);
- simulation pose copied to meshes/camera without separate render interpolation;
- third-person camera without `SpringArm3D` or exp-damped follow;
- remote entities use simple snapshot chase rather than buffered interpolation delay.

### Deferred beyond this spike

- physical projectile;
- movable or explosive physics prop;
- knockback;
- death and respawn;
- lag-compensated hitscan rewind;
- full movement-standard validation matrix (FPS, latency, jitter, cover collision).

### Implementation boundary (delivered)

- Shared **action-netcode kit** in `scripts/shared/` (`ActionNetcodeFixedTick`, `ActionNetcodeInputBuffer`, `ActionNetcodeEntityRegistry`, `ActionNetcodeHitscan`, `HostActionSimulator`, `NetworkActionMinigameSession`)
- `minigames/action-spike/` — network-capable, `HOST_ACTION`
- Shell integration through `NetworkMatchPhaseSession` phase routing
- Transport message lanes separated per [networking architecture](../architecture/networking.md#transport-message-lanes)

Lag compensation, projectile authority helpers, and debug overlay remain future kit work.

### Automated tests (delivered)

- Host action simulator: tank movement, hitscan damage, last-standing eligibility, tie placements, snapshot hash round-trip
- Network action session: tick-ordered input consumption, processed-tick acks, yaw reconciliation replay
- Input buffer: out-of-order and idempotent frame recording
- Minigame contract and boundary tests include Action Spike discovery

### Automated tests (original full scope — partial)

- Result agreement across live multiplayer peers after forced end (unit coverage only; multi-peer automation not stored)
- Entity lifecycle idempotency for spawn/despawn/damage RPCs (registry foundation only)
- Hit confirmation across network boundary (host raycast unit tests only)

### Manual tests (required — not stored for spike)

| Scenario | Notes |
| --- | --- |
| 4 `PlayerSlot`s | 4 peers × 1 player (launch policy) |
| Latency 50, 100, 150 ms | Clumsy, `tc netem`, or OS QoS |
| Jitter + 1–2% loss | Document tools used |
| Different host vs client frame rates | 30 vs 60 vs 120 render |
| Simultaneous shots and kills | No double-death or missed scoring |
| Lost, duplicated, delayed, reordered inputs | Adversarial or simulated |
| Host vs client responsiveness | Subjective notes + correction rate / input-to-ack sample |

**Deferred (multi-local online couch):** 2 peers × 2 local `PlayerSlot`s on one host PC; 2 local players on one peer submitting both inputs in the same upstream frame. Offline milestone 1 still supports multiple local players on one offline peer.

Record bandwidth (KB/s, msgs/sec) for 2 and 4 players.

### Stop condition

Spike completes a full round without persistent desync; action-netcode kit APIs are exercised through Action Spike and unit tests; contract gaps for shooters are identified **before** milestone 12 freezes the API. **Met for spike scope** — full combat and movement-standard compliance are explicitly deferred.

### Open questions before milestone 11

- Lag-compensation rewind cap (ms or ticks)
- Projectile merge policy for cosmetic vs authoritative spawn
- Whether 30 or 60 Hz sim is required for `HOST_ACTION` v1

---

## Milestone 11: Steam transport investigation and spike

### Purpose

Determine whether Steam Networking Sockets / SDR can sit behind `TransportAdapter` without rewriting gameplay.

### Player-facing proof

Spike branch or gated build: host/join via Steam (or LAN simulation through Steam) using the same lobby flow as milestone 4—not production Steam integration.

### Implementation boundary

- `scripts/shared/` transport adapter only; no Steam SDK commit without license/legal review
- Investigation notes in PR or `docs/` addendum

### Automated tests

- Same RPC echo tests as milestone 3 through Steam adapter (if CI cannot run Steam, document manual-only)

### Manual tests

- Compare RPC **channel** behavior vs ENet (session, lifecycle, inputs, snapshots, cosmetic lanes)
- Note SDR NAT traversal result
- **Channel parity is a release blocker** for Steam—not a minor note

### Stop condition

Written report: go / no-go / conditional go for Steam adapter; list channel/limitation gaps.

### Open questions before milestone 12

- Ship Steam as required transport or optional
- Godot Steam peer extension choice

---

## Milestone 12: Formal stabilization of minigame networking API

### Purpose

Freeze the shell → minigame network contract as GDScript types/interfaces **after** milestones 7, 9, and 10 validate both `HOST_SNAPSHOT` and `HOST_ACTION` paths. Update the [minigame integration contract](../architecture/minigame-integration.md) with real symbols.

### Player-facing proof

A second minimal network-capable minigame (or refactor of milestone 7 or 10) integrates using only the documented API—no new ad hoc RPCs in shell.

### Implementation boundary

- `scripts/shared/` public API surface
- Documentation update in the minigame integration contract
- Example minigame README section

### Automated tests

- Contract conformance test or lint that network-capable minigames register sync profile
- Teardown test: no lingering connections after minigame exit

### Manual tests

- Contributor dry-run: add stub minigame using API in under an hour

### Stop condition

Two minigames covering **both** `HOST_SNAPSHOT` and `HOST_ACTION` (or one minigame + stub per profile) use identical integration paths; API reviewed and merged.

### Open questions after milestone 12

- Versioning policy for breaking API changes
- Promotion path for shared helpers from minigames to `scripts/shared/`

---

## Milestone 13: Host migration (Case B) — post-acceptance

### Purpose

Explore **continuing a match after host loss** without requiring everyone to re-host manually. After migration works at phase boundaries, validate **abort + replay** when the host leaves during `Countdown` or `ActiveMinigame` (restore last phase-boundary snapshot, replay round). This is **deferred** and does not block Decision 0003 **Accepted** or milestones 1–12.

### Player-facing proof

- Host leaves on board or results → remaining peers elect a new host and continue from the last phase-boundary snapshot
- Host leaves during minigame → round aborts, last boundary restored, minigame replayable (requires surviving authority from migration)

### Implementation boundary

- `scripts/shared/` — election (proposal), snapshot handoff, `match_epoch` bump, RPC authority rebind

### Automated tests

- Remaining peers reach same `match_epoch`, phase, and board-state hash within N seconds after host loss at `Board`
- No duplicate minigame start or double reward after migration soak

### Manual tests

- 4-peer Case B sessions; host Alt+F4 on board and on results

### Stop condition

Case B matrix passes or is explicitly deferred again with maintainer sign-off.

### Open questions

- Election algorithm, snapshot source on crash, cold vs in-place `MultiplayerPeer` handoff

---

## Network testing plan

Run these environments in addition to per-milestone manual tests. Record measurements in the PR or a test log.

### Environments

| Environment | Purpose |
| --- | --- |
| Two peers, one machine | Baseline connectivity, fast iteration |
| Two LAN machines | Real NIC latency, MTU |
| Four LAN machines | Phase agreement under N>2 (**when milestone requires**) |
| Two internet machines | NAT, variable RTT |
| 4 single-player peers | `MAX_PLAYERS` stress (**launch validation layout**) |

**Deferred:** 2 peers × 2 local `PlayerSlot`s (couch + online on one host PC).

### Latency and impairment profiles

Apply to milestones 7–10 at minimum:

| Profile | Target | Tools (spike options, no addon required) |
| --- | --- | --- |
| Baseline | ~0 ms added | — |
| Moderate | ~50 ms | Clumsy, `tc netem delay 50ms`, Windows QoS |
| High | ~100 ms | Same |
| Stress | ~150 ms + jitter | `tc netem` delay + jitter |
| Loss | ~1–2% packet loss | Clumsy, `tc netem loss 2%` |

### Disconnect recovery matrix

Mark each cell: **pass**, **fail**, **session end (v1)**, **continue (milestone 13)**, or **abort replay (milestone 13 only)**. In milestones 1–12, **every host disconnect should end the session cleanly**. Milestone 13 adds continue/replay behaviors that require surviving authority.

| Phase | Non-host disconnect | Host disconnect |
| --- | --- | --- |
| `Lobby` | | |
| `Board` | | |
| `MinigameSelection` | | |
| `Briefing` | | |
| `Countdown` | | session end (v1) |
| `ActiveMinigame` | | session end (v1) |
| `Results` | | |
| `ReturnToBoard` | | |
| `MatchResults` | | |

### Adversarial and edge cases

- Conflicting move requests same tick
- Client claims extra `PlayerSlot` or fifth player
- Duplicate `command_id`, `result_id`, or `reward_application_id` ignored (no double apply)
- Client sends results RPC (must be ignored)
- Host and client at different render frame rates
- Two local players on one peer: both inputs in same upstream frame

### Measurable acceptance criteria

| Measurement | How | Target (initial) |
| --- | --- | --- |
| Phase agreement | All peers report same phase enum after each transition | 100% in automated runs |
| Result agreement | Placements and scores equal host vs each client | 100% |
| Board-state hash | Canonical snapshot hash at phase boundaries | Match on all connected peers |
| Correction frequency | Prediction overlay / logs (milestones 8, 10) | Documented per latency tier |
| Correction magnitude | Max position error after reconcile | Documented per latency tier |
| Disconnect recovery | Matrix above | Host loss → session end in v1; non-host reconnect reliable; milestone 13 tracked separately |
| Bandwidth | KB/s and msgs/sec sampled | Recorded for 2 and 4 players in milestones 7 and 10; no fixed cap yet |
| Input responsiveness | Human playtest | Subjective notes **plus** one of: input-to-ack latency sample, correction rate |

“Feels good” alone is not sufficient for merge to milestones 7–9; pair with at least one quantitative metric.

### Human playtesting

Required for milestones 6–10 before merge. Minimum: two people on two machines when CI cannot cover internet path; four people for 4-slot couch-online hybrid when testing slot ownership.

---

## What this plan deliberately does not implement

- Matchmaking, accounts, progression, voice chat, anti-cheat
- Mid-minigame late join or spectators
- Dedicated servers
- Third-party networking addons
- Production Steam release integration (milestone 11 is investigation)

Update [Decision 0003](../decisions/0003-peer-hosted-networking.md) to **Accepted** after milestones 1–7 and milestone 9 pass review. **Host migration (milestone 13) is not a gate** for accepting the peer-hosted architecture decision. **Do not treat the minigame networking API as frozen** until milestone 12 completes after milestone 10.
