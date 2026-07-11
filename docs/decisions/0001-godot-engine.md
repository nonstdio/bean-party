# Decision: Standardize on Godot 4.7

Date: 2026-07-10

Status: Accepted

## Context

Bean Party needs a shared, approachable foundation so friends can begin contributing independently designed minigames. The project needs 2D and 3D capability, a scene model that supports modular minigames, local multiplayer input, source-control-friendly project files, and no per-contributor licensing cost.

## Options considered

- **Godot 4** — open source under the MIT license, built-in 2D and 3D workflows, scene composition, and native GDScript.
- **Unity 6** — mature C# ecosystem and wide platform reach, with commercial terms and binary-asset workflow to manage.
- **Unreal Engine 5** — powerful 3D tools, but heavier onboarding and more capability than the initial prototype needs.
- **Web-first stack** — immediate browser access, but more custom technology to assemble and maintain.

## Decision

Use **Godot 4.7 stable** as the engine standard and **GDScript** as the initial shared-code language. Create scenes and scripts as text-based Godot assets, keep each minigame self-contained, and use the Compatibility renderer for the foundation to favor broad desktop hardware support.

Godot’s official archive lists 4.7 as stable. Its [official introduction](https://docs.godotengine.org/en/4.7/about/introduction.html) describes Godot as a free, open-source, cross-platform engine for 2D and 3D games under the MIT license.

## Consequences

- Contributors should install Godot 4.7 stable before opening the project.
- Do not upgrade the engine, introduce C#, change renderer defaults, or add a project-wide plugin without a new decision record.
- `.godot/`, `.import/`, `.mono/`, exports, and local builds remain untracked.
- The first vertical slice validates the Godot project and minigame lifecycle instead of re-litigating the engine selection.
