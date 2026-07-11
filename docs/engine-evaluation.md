# Engine evaluation

## Decision status

**Accepted: Godot 4.7 stable with GDScript.** The decision is recorded in [Decision 0001](decisions/0001-godot-engine.md). The first priority is a sustainable contributor workflow for a party-game prototype, not maximum graphical power.

## Requirements to validate

The engine should make the following possible with low friction:

- 2–4 local players, controller support, and a shared-screen camera;
- short 2D and 3D minigames in the same project;
- a board scene that can load and unload independently developed minigames safely;
- fast setup for friends with mixed experience levels;
- source-control-friendly text assets and a workable approach to binary art files;
- deterministic-enough local rules and a path to online play later, without making online networking a first-slice dependency (see [Decision 0003](decisions/0003-peer-hosted-networking.md) and [networking implementation plan](networking-implementation-plan.md));
- Windows builds first, with future desktop/web/mobile/console needs made explicit before committing to them;
- accessible UI, input rebinding, audio controls, and build automation when the project matures.

## Candidates

| Candidate | Strengths for this project | Watch-outs | Best reason to choose it |
| --- | --- | --- | --- |
| **Godot 4** | Free, open source under MIT; built-in 2D and 3D tools; scene/node model suits modular minigames; GDScript and C# options. | Smaller commercial console and third-party ecosystem; contributors need to agree on language, version, and asset workflow. | A low-cost, open, small-team-friendly local-first prototype. |
| **Unity 6** | Mature C# workflow; broad deployment options; strong learning ecosystem; built-in tools for 2D, 3D, input, and multiplayer services. | Subscription terms and thresholds need periodic review; editor and binary asset merges demand discipline. | Contributors already know C#, or broad platform support is a near-term requirement. |
| **Unreal Engine 5** | High-end 3D rendering, Blueprints, C++, and source access; strong option for an experienced 3D team. | Heavier tooling and onboarding; likely more capability than the first party-game slice needs; game revenue above its threshold has royalty implications. | A polished 3D presentation is the dominant goal and the team is already fluent in Unreal. |
| **Web-first stack** | A browser build can make playtesting and contributor demos nearly instant. | The team must assemble more of the engine, controller, packaging, and online stack itself. | Zero-install browser access is more important than editor-led production. |

Godot’s official documentation describes the engine as free, open source, cross-platform, and available for 2D and 3D work under the MIT license. [Godot](https://godotengine.org/) is therefore the most natural first spike candidate. [Unity](https://unity.com/products/unity-engine) supports 2D and 3D work across many platforms with C#; its current plan terms should be reviewed before a production commitment. [Unreal’s license page](https://www.unrealengine.com/license) currently states a 5% royalty on lifetime gross revenue over $1 million for qualifying games.

## How the decision was made

Godot was selected before a full multi-engine spike because contributor momentum and a common foundation are more valuable to the project right now than delaying implementation for a comparison. Its MIT license, integrated 2D/3D workflow, scene composition, and native GDScript are a good fit for independently built minigames in a small project.

The following vertical slice is still required, but it now validates the Godot architecture rather than choosing an engine:

1. a four-player board stub that assigns controllers and launches a minigame;
2. one 45-second minigame with a briefing screen, restart, scoring, and results;
3. a second minigame that differs in camera or dimensionality;
4. an exported Windows build that friends can run without the editor.

Evaluate each spike with the same questions:

- Can a new contributor open, run, and modify it in under an hour?
- Can the shared shell load, pass inputs to, and cleanly unload a minigame?
- Are controller mapping, player join, pause, and results simple to implement?
- How painful are Git diffs, merges, and art imports?
- Can the group produce a repeatable build and test it with four players?

Use at least two potential contributors to try the slice. Record the finalized project layout, build commands, and minigame API in follow-up decision records.

## Questions the group must answer next

- What is the first release platform: Windows desktop, web, or something else?
- Is remote online multiplayer a launch requirement or a later milestone? (Proposed architecture: [Decision 0003](decisions/0003-peer-hosted-networking.md).)
- Are the first boards and minigames primarily 2D, 3D, or deliberately mixed?
- Is a commercial release plausible, and what licensing model do we want for code and assets?
