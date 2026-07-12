# Decision: Mixed-source standard asset pipeline

Date: 2026-07-11
Status: Accepted

## Context

Bean Party needs reusable early assets before contributors independently create incompatible versions of the same player markers, materials, character proxies, and presentation tokens. These assets must remain editable without making Blender a runtime, test, or ordinary contributor dependency. The project content license and final production art pipeline remain open.

## Options considered

- Godot-native assets only - lowest setup cost, but inadequate as the sole source format for authored 3D models.
- Direct `.blend` import - convenient for artists, but requires Blender on every machine that imports or tests the Godot project.
- Editable source plus committed glTF export - preserves source history while keeping the Godot handoff portable.

## Decision

Use a mixed-source pipeline for standard assets:

- Keep editable Blender sources under `assets/source/standard/`, behind `.gdignore` so Godot does not import them.
- Commit binary glTF (`.glb`) exports and Godot-native resources under `assets/standard/`.
- Pin the initial standard 3D source and byte-for-byte export check to Blender 5.1.2. Record the exact tested version per asset and review any version upgrade before changing the pin.
- Provide repeatable build, export, and stale-export checks through `tools/assets.ps1` and `tools/assets.sh`.
- Treat the standard asset catalog as the source for status, canonical path, editable source, purpose, and provenance.

Godot 4.7 recommends glTF 2.0 for 3D interchange and notes that direct `.blend` imports add Blender as a dependency for the whole team: [Godot 4.7 available 3D formats](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).

## Consequences

- Contributors can run and test the project without Blender.
- A contributor changing Blender-authored geometry must use Blender 5.1.2, update the editable source, regenerate the GLB, and run the asset check.
- Binary source and export changes are not meaningfully reviewable as text, so the pull request must include visual evidence and provenance notes.
- Canonical prototype assets are the reuse default but may be replaced through review; this decision does not make their current appearance production-final.
- Rigging, animation, attachment conventions, textures, audio, fonts, licensing, and final platform budgets remain undecided.
