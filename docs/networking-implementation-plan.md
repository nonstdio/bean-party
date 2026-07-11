# Networking implementation plan

This plan breaks Bean Party online networking into reviewable milestones. Each milestone should ship as its own focused pull request. Do not begin production netcode until [Decision 0003](decisions/0003-peer-hosted-networking.md) has passed human review.

Related documents:

- [Networking architecture](networking-architecture.md) — topology, authority, phases, messages
- [Minigame contribution contract](minigame-contract.md) — network-facing minigame rules
- [Godot project architecture](godot-architecture.md) — repository layout

## Principles

- Implement **offline session model first**, then attach ENet, then minigames.
- Board and minigames never construct transport peers directly.
- Prefer automated consistency checks (phase, results, snapshot hash) over subjective “feels fine” alone.
- Human playtesting remains required for perceived responsiveness.

## Milestone overview

| # | Milestone | Depends on |
| --- | --- | --- |
| 1 | Offline session / `PlayerSlot` model | — |
| 2 | Local phase state machine + snapshots | 1 |
| 3 | ENet host/join harness | 1 |
| 4 | Networked lobby (multi-local per peer) | 1, 3 |
| 5 | Authoritative board stub | 2, 4 |
| 6 | Networked scene flow (briefing → results) | 2, 4, 5 |
| 7 | Simple movement minigame (`HOST_SNAPSHOT`) | 6 |
| 8 | Prediction / reconciliation experiment | 7 |
| 9 | Disconnect recovery (non-host reconnect, clean host exit) | 2, 6, 7 |
| 10 | Steam transport investigation | 3 |
| 11 | Formal minigame networking API | 7, 9 |
| 12 | Host migration (Case B) — post-acceptance | 9, 11 |

---

## Milestone 1: Offline session and player model

### Purpose

Separate **network peers** from logical **`PlayerSlot`s** so local couch play and future online play share one identity model.

### Player-facing proof

From the starter app, two to four local players can join a couch session with distinct names/colors; the UI shows who occupies each slot without any network connection.

### Implementation boundary

- `scripts/shared/` — proposed `PlayerSlot` data, session registry (proposal names)
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

### Open questions before milestone 2

- `player_id` format (UUID vs incremental match id)
- Whether empty slots are allowed in a 2-player match or always compacted

---

## Milestone 2: Local phase state machine and phase-boundary snapshots

### Purpose

Implement the host-owned phase machine and snapshot capture/restores **without network** so recovery logic is testable offline.

### Player-facing proof

A debug or stub flow walks Lobby → Board (stub) → Briefing → Results → Board locally; restarting from a saved snapshot restores the same phase and board stub state.

### Implementation boundary

- `scripts/shared/` — phase controller, snapshot serializer (proposal)
- `tests/unit/` — transition guards, snapshot round-trip, `match_epoch` increment
- No ENet yet; “host” is always the local process

### Automated tests

- Illegal transitions rejected (e.g. `ActiveMinigame` → `Lobby` without teardown)
- Snapshot round-trip: hash equality after serialize/deserialize
- Snapshot contains all fields listed in [networking architecture](networking-architecture.md#phase-boundary-snapshots)

### Manual tests

- Save snapshot on board, force reload, confirm economy/phase restored
- Walk full phase diagram once on one machine

### Stop condition

GUT tests prove snapshot round-trip and phase guards; manual run completes one full loop.

### Open questions before milestone 3

- Snapshot format (JSON vs binary vs Godot `var_to_bytes`)
- Whether `match_epoch` bumps on every snapshot or only authority change

---

## Milestone 3: ENet host/join harness

### Purpose

Prove LAN/direct-IP connect/disconnect through a **session layer** that wraps `ENetMultiplayerPeer`, not scattered peer creation.

### Player-facing proof

Two instances on one machine: host clicks “Host,” client enters address and joins; both see connected peer list; clean disconnect returns to menu.

### Implementation boundary

- `scripts/shared/` — proposed `MatchSession`, `EnetTransportAdapter`
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

- Default port and firewall documentation
- Heartbeat interval for detecting silent drops

---

## Milestone 4: Networked lobby with multiple local players per peer

### Purpose

Sync `PlayerSlot` assignment across peers; one connection may register multiple local players.

### Player-facing proof

Peer A joins with 2 local players; Peer B joins with 1; lobby shows 3 `PlayerSlot`s with correct ownership; ready states sync.

### Implementation boundary

- `scripts/shared/` — lobby authority on host, slot claim validation
- `tests/unit/` — reject slot claim from wrong `peer_id`, reject fifth player

### Automated tests

- Host rejects `PlayerSlot` claim for another peer's `local_player_index`
- Host rejects match start when over `MAX_PLAYERS` (fifth player)

### Manual tests

- 2 peers × 2 local players on one machine (4 windows or simulated peers)
- Malformed ready RPC ignored (manual or test double)

### Stop condition

All peers display identical lobby `PlayerSlot` list and ready flags after each change.

### Open questions before milestone 5

- Lobby host migration needed before match start? (**deferred** until 12)
- Display name profanity/trust (**deferred**)

---

## Milestone 5: Authoritative board stub

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

- Turn order tie-breaking
- How board stub connects to real board design later

---

## Milestone 6: Networked scene loading, briefing, readiness, countdown, and results

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

- 4 `PlayerSlot`s, 2 peers × 2 local
- Record messages/sec and KB/s for results table

### Stop condition

Result agreement automated test passes; manual playtest at 4 players with no persistent desync.

### Open questions before milestone 8

- 30 vs 60 Hz sim for this minigame

---

## Milestone 8: Prediction and reconciliation experiment

### Purpose

Measure whether milestone 7 needs local prediction for acceptable responsiveness at 50–100 ms simulated latency.

### Player-facing proof

Same minigame with optional prediction on local player; debug overlay shows correction magnitude/frequency.

### Implementation boundary

- Changes isolated to movement minigame + small shared debug helpers
- Feature flag or sync profile sub-option

### Automated tests

- Log correction count per session in test harness (threshold TBD in PR)

### Manual tests

- Latency simulation: 0, 50, 100, ~150 ms via OS QoS, [clumsy](https://jagt.github.io/clumsy/), or Linux `tc netem`
- Jitter and ~1–2% packet loss
- Differing render FPS (30 vs 60 vs 120) on host vs client

### Stop condition

Documented table: latency vs correction frequency vs player verdict; recommendation to adopt or skip default prediction.

### Open questions before milestone 9

- Snap vs blend correction default
- Whether prediction ships for all `HOST_SNAPSHOT` minigames or only this one

---

## Milestone 9: Disconnect recovery (v1 scope)

### Purpose

Implement **non-host disconnect**, **non-host reconnect at phase boundaries**, and **clean session end when the host leaves in any phase**. **Host migration and abort/replay after host loss are out of scope**—see milestone 12.

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

Non-host disconnect/reconnect tests pass; **every host-departure scenario ends the session cleanly** with explicit UI. **Decision 0003 may move toward Accepted after milestones 1–7 and this milestone pass review**—milestone 12 is not required.

### Open questions before milestone 10

- Reconnect grace period at phase boundaries
- Whether inactive slots block match start

---

## Milestone 10: Steam transport investigation and spike

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

- Compare RPC channel behavior vs ENet
- Note SDR NAT traversal result

### Stop condition

Written report: go / no-go / conditional go for Steam adapter; list channel/limitation gaps.

### Open questions before milestone 11

- Ship Steam as required transport or optional
- Godot Steam peer extension choice

---

## Milestone 11: Formal stabilization of minigame networking API

### Purpose

Freeze the shell → minigame network contract as GDScript types/interfaces; update [minigame contract](minigame-contract.md) with real symbols.

### Player-facing proof

A second minimal network-capable minigame (or refactor of milestone 7) integrates using only the documented API—no new ad hoc RPCs in shell.

### Implementation boundary

- `scripts/shared/` public API surface
- Documentation update in minigame contract
- Example minigame README section

### Automated tests

- Contract conformance test or lint that network-capable minigames register sync profile
- Teardown test: no lingering connections after minigame exit

### Manual tests

- Contributor dry-run: add stub minigame using API in under an hour

### Stop condition

Two minigames (or one minigame + stub) use identical integration path; API reviewed and merged.

### Open questions after milestone 11

- Versioning policy for breaking API changes
- Promotion path for shared helpers from minigames to `scripts/shared/`

---

## Milestone 12: Host migration (Case B) — post-acceptance

### Purpose

Explore **continuing a match after host loss** without requiring everyone to re-host manually. After migration works at phase boundaries, validate **abort + replay** when the host leaves during `Countdown` or `ActiveMinigame` (restore last phase-boundary snapshot, replay round). This is **deferred** and does not block Decision 0003 **Accepted** or milestones 1–11.

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
| 2 peers × 2 local `PlayerSlot`s | Couch + online on one host PC (4 players total) |
| 4 single-player peers | `MAX_PLAYERS` stress |

### Latency and impairment profiles

Apply to milestones 7–9 at minimum:

| Profile | Target | Tools (spike options, no addon required) |
| --- | --- | --- |
| Baseline | ~0 ms added | — |
| Moderate | ~50 ms | Clumsy, `tc netem delay 50ms`, Windows QoS |
| High | ~100 ms | Same |
| Stress | ~150 ms + jitter | `tc netem` delay + jitter |
| Loss | ~1–2% packet loss | Clumsy, `tc netem loss 2%` |

### Disconnect recovery matrix

Mark each cell: **pass**, **fail**, **session end (v1)**, **continue (milestone 12)**, or **abort replay (milestone 12 only)**. In milestones 1–11, **every host disconnect should end the session cleanly**. Milestone 12 adds continue/replay behaviors that require surviving authority.

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
| Correction frequency | Prediction overlay / logs (milestone 8) | Documented per latency tier |
| Correction magnitude | Max position error after reconcile | Documented per latency tier |
| Disconnect recovery | Matrix above | Host loss → session end in v1; non-host reconnect reliable; milestone 12 tracked separately |
| Bandwidth | KB/s and msgs/sec sampled | Recorded for 2 and 4 players; no fixed cap yet |
| Input responsiveness | Human playtest | Subjective notes **plus** one of: input-to-ack latency sample, correction rate |

“Feels good” alone is not sufficient for merge to milestones 7–9; pair with at least one quantitative metric.

### Human playtesting

Required for milestones 6–9 before merge. Minimum: two people on two machines when CI cannot cover internet path; four people for 4-slot couch-online hybrid when testing slot ownership.

---

## What this plan deliberately does not implement

- Matchmaking, accounts, progression, voice chat, anti-cheat
- Mid-minigame late join or spectators
- Dedicated servers
- Third-party networking addons
- Production Steam release integration (milestone 10 is investigation)

Update [Decision 0003](decisions/0003-peer-hosted-networking.md) to **Accepted** after milestones 1–7 and milestone 9 pass review. **Host migration (milestone 12) is not a gate** for accepting the peer-hosted architecture decision.
