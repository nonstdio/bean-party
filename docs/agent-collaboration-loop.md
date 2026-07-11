# Agent collaboration loop

This document defines how GPT, Cursor, and a human maintainer coordinate implementation work in Bean Party. It does not replace repository rules; it routes agents through them. Canonical guidance lives in [AGENTS.md](../AGENTS.md), [CONTRIBUTING.md](../CONTRIBUTING.md), [project governance](project-governance.md), [game design target](game-design.md), [minigame contribution contract](minigame-contract.md), and [Godot project architecture](godot-architecture.md).

## Roles

| Role | Responsibility |
| --- | --- |
| **Human** | Owns priorities, playtests, merge decisions, and judgment calls on fun, feel, and unresolved design. |
| **GPT** | Owns `agent_loop/assistant_feedback.md`: one narrow player-facing objective, bounded scope, relevant rules, validation expectations, stop conditions, and human-feedback questions. |
| **Cursor** | Owns `agent_loop/cursor_handoff.md`: reads repository instructions first, implements on a fresh branch, validates, rebases, and documents what changed and what still needs human input. |

Neither agent edits the other agent’s loop file unless the human explicitly directs it.

## Branch and pull-request rules

- One narrow **player-facing objective** per implementation branch.
- Create a fresh `agent/<topic>` branch from current `main` for each loop cycle. Open a **draft** pull request into `main`. Never push directly to `main`.
- Rebase from `main` **before beginning work** and **before handoff**. After each rebase, inspect incoming changes and revise the plan, assumptions, tests, and handoff notes accordingly.
- Keep pull requests focused. Do not bundle a minigame, broad refactor, engine migration, and design rewrite in one change. See [CONTRIBUTING.md](../CONTRIBUTING.md) and [project governance](project-governance.md).

## Required reading before implementation

Cursor must read, in order:

1. [AGENTS.md](../AGENTS.md)
2. [CONTRIBUTING.md](../CONTRIBUTING.md)
3. [docs/agent-collaboration-loop.md](agent-collaboration-loop.md) and the current contents of `agent_loop/assistant_feedback.md` and `agent_loop/cursor_handoff.md`
4. Every document relevant to the task: at minimum [game design target](game-design.md), [minigame contribution contract](minigame-contract.md), and [Godot project architecture](godot-architecture.md) for code work; [project governance](project-governance.md) for shared-system or process changes; [creative direction](creative-direction.md) when presentation is in scope

Treat target platforms, networking model, licensing, asset pipeline, and the shared minigame API as **open decisions** unless a maintainer has recorded otherwise in `docs/decisions/`.

## Proposals and decision records

- **Substantial minigames** require a proposal before implementation. Follow the lifecycle in [minigame contribution contract](minigame-contract.md) and the repository’s minigame proposal issue template.
- **Consequential shared-system choices**—networking, licensing, platform, engine, renderer, or art-pipeline decisions—require a short decision record in `docs/decisions/` per [project governance](project-governance.md). Do not bury project-wide decisions inside a single minigame pull request.

## Loop stages

Work moves through these stages. Status values and file ownership are defined in [agent_loop/README.md](../agent_loop/README.md).

```text
READY_FOR_CURSOR → CURSOR_WORKING → READY_FOR_GPT_REVIEW → (optional) HUMAN_FEEDBACK_REQUIRED → COMPLETE
                                                      ↘ BLOCKED (any stage)
```

### 1. Validation (Cursor)

Before handoff or review request:

- Verify Markdown links and internal consistency when documentation changes.
- Run `tools/godot.ps1 all` on Windows or `bash tools/godot.sh all` on macOS and Linux before opening or updating a pull request, as documented in [AGENTS.md](../AGENTS.md) and [Godot project architecture](godot-architecture.md).
- If validation cannot run, record the exact reason in the handoff and pull request. Do not claim success without evidence.

### 2. Handoff (Cursor)

Update `agent_loop/cursor_handoff.md` with branch and commit, interpretation of the directive, rules reviewed, changes made, player-facing effect, validation performed, test results, rebase outcomes, known limitations, unresolved decisions, and an exact human-feedback request.

Set status to `READY_FOR_GPT_REVIEW` when the bounded task is complete or `BLOCKED` when stopped.

### 3. GPT review

GPT reads the handoff and pull request diff. It checks scope, rule compliance, missing proposals or decision records, validation claims, and asset provenance. GPT updates `agent_loop/assistant_feedback.md` with the next directive, refined scope, or a request for human feedback.

### 4. Human playtest and merge judgment

The human reviews when the change affects player experience, feel, or open design questions. Humans decide whether to playtest, request changes, or merge. **Agents may not merge pull requests** or declare the game fun without human judgment.

## Stop conditions

Stop work, set status to `BLOCKED` or `HUMAN_FEEDBACK_REQUIRED`, and document the reason in the handoff when any of the following apply:

| Condition | Action |
| --- | --- |
| **Rule conflict** | Conflicting instructions between loop files, issues, and canonical docs. Escalate to the human; do not guess. |
| **Scope expansion** | The task grows beyond one narrow player-facing objective. Split work or request a new directive. |
| **Missing proposal or decision** | A substantial minigame or consequential shared-system change lacks an approved proposal or decision record. Stop and request one. |
| **Unresolved test failure** | Headless import or GUT tests fail and cannot be fixed within the bounded scope. Report failures exactly; do not merge. |
| **Uncertain asset provenance** | Source or license for art, audio, or third-party material is unclear. Stop until the human confirms. See [CONTRIBUTING.md](../CONTRIBUTING.md). |
| **Hard-to-reverse choice** | The change would lock engine, platform, networking, licensing, or art-pipeline direction without a decision record. Stop and propose a record. |
| **Human-feel checkpoint** | Gameplay clarity, pacing, or fun requires playtesting or design judgment. Hand off with a specific question; do not self-approve feel. |
| **Completed bounded task** | The directive is satisfied, validation is documented, and the draft pull request is ready. Set `READY_FOR_GPT_REVIEW` or `COMPLETE` as appropriate. |

## Agents must not

- Merge pull requests or bypass branch protection.
- Declare the game “fun” or ship-ready without human playtest and judgment.
- Push directly to `main`.
- Edit the other agent’s loop file without explicit human direction.
- Resolve open design decisions (board economy, networking model, licenses, and similar) without a recorded human decision.
