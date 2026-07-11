# Decision: Use GUT for automated Godot tests

Date: 2026-07-10

Status: Accepted

## Context

Bean Party needs a repeatable, headless way for contributors and agents to validate Godot changes before review. The project uses GDScript and Godot 4.7 stable, does not use C#, and needs a test runner that works locally and in GitHub Actions.

## Options considered

- **GUT 9.7.1** — a Godot-4.7-specific GDScript test framework with a headless command-line runner and JUnit support, under the MIT license.
- **GdUnit4** — a feature-rich embedded test framework, but its published release compatibility is less specific to Godot 4.7 stable.
- **A project-owned harness** — avoids a dependency but would duplicate assertions, discovery, reporting, and maintenance work.

## Decision

Vendor GUT 9.7.1 from commit `aeb5d4f` under `addons/gut/`, retain its included MIT license, and enable its editor plugin in `project.godot`. Project-level tests live beneath `tests/`; minigame-local tests live beneath `minigames/<slug>/tests/`. Both run through the repository's platform runners. A GitHub Actions matrix verifies the official Godot 4.7 archive and runs the same validation and test commands on Windows, macOS, and Linux.

## Consequences

- Contributors use `tools/godot.ps1 all` on Windows or `bash tools/godot.sh all` on macOS and Linux before opening a pull request.
- GUT upgrades are deliberate dependency updates: use a released Godot-4.7-compatible version, preserve its license and source record, update this decision record and the runners if necessary, and verify all platforms in CI.
- This establishes headless import and GDScript coverage for shared session logic, the local minigame contract/controller path, repository boundaries, and the main-scene smoke test. Export validation, real multi-process networking automation, physical controller routing tests, and full gameplay automation remain later work.
