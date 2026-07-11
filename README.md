# Bean Party

Bean Party is a collaborative party game: a shared board game punctuated by short, competitive, cooperative, and team-based minigames. Players collect beans, take risks, trigger surprises, and compete for the win.

It takes structural inspiration from Mario Party-style board-and-minigame games, while its world, tone, and presentation draw from [Bean Battles on Steam](https://store.steampowered.com/app/765410/Bean_Battles/). This is an independent fan project, not an official Gupa Games product.

## Project goals

- Make it easy for contributors to create, test, and share self-contained minigames.
- Keep the core board game experience lightweight, approachable, and fun in local or online play.
- Build clear, reusable interfaces so minigames can plug into the main game without rewriting shared systems.
- Create a recognizably Bean Battles-inspired presentation without copying its code, art, audio, characters, or branding assets.

## Project status

The project is in pre-production. We have selected **Godot 4.7 stable** with **GDScript** for the initial shared codebase. The repository currently contains:

- a local 2–4 player `PlayerSlot` model, debug phase flow, board stub, and phase-boundary snapshot restore;
- accepted local minigame contract version 1, a scaffold, a development harness, and the `reference-tap` executable example; and
- an ENet debug slice covering host/join, a host-authoritative multi-local-player lobby, a board stub, and synchronized placeholder minigame phases through results and return to board.

These are contributor and architecture proofs, not a playable game or validated production netcode. The local minigame harness is not yet connected to the app's local or network match flows, and the network flow still uses an internal placeholder scene. [Decision 0003](docs/decisions/0003-peer-hosted-networking.md) therefore remains **Proposed**. See the [networking plan status](docs/plans/networking.md#milestone-overview) for implemented evidence and validation still outstanding. Target platforms, final art pipeline, licensing, and board economy remain open decisions.

## Run the current project

Agents should first follow [Godot setup for agents](docs/guides/godot-setup.md), which installs the pinned editor and runs the terminal-first validation and test commands on Windows, macOS, and Linux.

### Download the latest Windows test build

Windows playtesters can download [BeanParty.exe](https://github.com/nonstdio/bean-party/releases/download/latest-windows/BeanParty.exe) and run the current `main` branch without installing Godot. This is an automated, unsigned development build, so Windows SmartScreen may ask the player to confirm that they want to run it. The download is replaced only after a new `main` build exports successfully.

This convenience build does not establish Windows as the project's final supported release target. Contributors who need the editor, tests, or local minigame harness should use the source workflow below.

1. Install [Godot 4.7 stable](https://godotengine.org/download/archive/).
2. Import the repository’s `project.godot` file in the Godot Project Manager.
3. Select the project and press `F5`, or run `godot --editor --path .` from the repository root and run the main scene.

The main scene is a deliberately utilitarian debug shell. It exposes the local session and phase proofs plus the ENet milestones implemented so far. Follow [Use the runtime debug harnesses](docs/guides/runtime-debug-harnesses.md) for the exact workflows and limitations. For local minigame development, run `res://scenes/dev/minigame_harness.tscn` as the current scene with `F6`. See the [Godot project architecture](docs/architecture/godot-project.md) before adding shared systems or a minigame.

## Host a multiplayer session

The main scene (`F5`) is a network debug shell with **ENet (LAN)** and **WebRTC (internet)** transport. These are architecture proofs, not production matchmaking.

### LAN host (ENet)

1. Run the main scene (`F5`).
2. Select transport **ENet (LAN)**.
3. Choose a port (default `7777`) and select **Host**.
4. Share your LAN IP address and port with other players. They select **ENet (LAN)**, enter the same address and port, and select **Join**.

ENet requires every peer to reach the host directly on the LAN. It does not traverse NAT.

### Internet host (WebRTC)

**One-time setup on the host machine:**

1. Install the [webrtc-native GDExtension](docs/guides/webrtc-setup.md#install-webrtc-native-desktop). On Windows, from the repository root:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\setup-webrtc-native.ps1
   ```
   Restart Godot after installing the extension.
2. Install [Node.js](https://nodejs.org/) 18+ and start the signaling server:
   ```bash
   cd tools/signaling
   npm install
   npm start
   ```
   Default signaling URL: `ws://127.0.0.1:9080`.

**Each session:**

1. Keep the signaling server running.
2. Run the game (`F5` in the editor, or an exported build that includes webrtc-native).
3. Select transport **WebRTC (internet)**.
4. Enter the signaling URL (`ws://127.0.0.1:9080` for local testing; use a reachable `wss://` URL when friends join from other networks).
5. Leave **room code** empty and select **Host**. Copy the room code shown in the status line.
6. Share the signaling URL and room code with joiners. They enter both fields and select **Join**.

To test on one PC, run two Godot instances against `ws://127.0.0.1:9080`. STUN hole-punch works on many home networks; restrictive NAT needs TURN relay — see [WebRTC operations runbook](docs/guides/webrtc-ops.md). See [WebRTC setup](docs/guides/webrtc-setup.md) and [runtime debug harnesses](docs/guides/runtime-debug-harnesses.md) for troubleshooting and the lobby → board → minigame flow.

## Contributing

Ideas, minigame concepts, art, music, code, and playtesting feedback are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), then open a minigame proposal before beginning a substantial implementation.

## Project guides

- [Documentation index](docs/README.md) — where project documentation belongs and how it evolves.
- [Game design target](docs/design/game.md) — what “Mario Party-style” means for this project.
- [Creative direction](docs/design/creative-direction.md) — how to evoke Bean Battles without copying it.
- [Minigame design guide](docs/design/minigames.md) — how proposals become clear, testable minigame briefs.
- [Create a minigame](docs/guides/create-a-minigame.md) — scaffold, implement, run, test, and prepare a local minigame for review.
- [Runtime debug harnesses](docs/guides/runtime-debug-harnesses.md) — exercise the implemented local and ENet architecture proofs and understand their limits.
- [WebRTC setup](docs/guides/webrtc-setup.md) — webrtc-native install, signaling server, and internet transport spikes.
- [WebRTC operations runbook](docs/guides/webrtc-ops.md) — TURN/ICE config, signaling deployment, NAT test matrix.
- [Minigame integration contract](docs/architecture/minigame-integration.md) — runtime, ownership, result, cleanup, and networking boundaries.
- [Networking architecture](docs/architecture/networking.md) — implemented debug boundaries plus the proposed online topology, authority, and phase machine.
- [Networking implementation plan](docs/plans/networking.md) — current milestone status, future sequence, and test matrix.
- [Godot project architecture](docs/architecture/godot-project.md) — repository layout and Godot conventions.
- [Godot 3D movement standards](docs/architecture/godot-3d-movement.md) — physics, movement feel, interpolation, prediction, camera, and validation practices.
- [Engine evaluation](docs/research/engine-evaluation.md) — the evaluation that led to the Godot decision.
- [Project governance](docs/project/governance.md) — pull requests and the `main` branch rules.
- [Agent guide](AGENTS.md) — instructions for AI-assisted work in this repository.

## Open decisions

- Is the first playable version local-only, online-only, or local-first with online play later? (Networking direction is [proposed](docs/decisions/0003-peer-hosted-networking.md); local-first remains the implementation order.)
- Which software and content licenses should govern contributions and releases?
- What is the final board economy: beans, victory tokens, or both?
