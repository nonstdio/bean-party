# Cursor handoff (Cursor-owned)

> **Owner:** Cursor. GPT must not edit this file unless the human explicitly directs it.

## status

`COMPLETE`

## branch and commit

`chore/ignore-zip-archives` @ `b3cd07b` (includes `265ae45` agent collaboration loop work from parent branch)

## interpretation of directive

Human requested saving local work, creating a small branch with a trivial change, pushing, and opening/updating a draft pull request. The substantive documentation work (agent collaboration loop) was already on `agent/agent-collaboration-loop`; the trivial follow-up adds `*.zip` to `.gitignore`.

## repository rules reviewed

- [AGENTS.md](../AGENTS.md)
- [CONTRIBUTING.md](../CONTRIBUTING.md)
- [docs/agent-collaboration-loop.md](../docs/agent-collaboration-loop.md)
- [agent_loop/README.md](README.md)

## changes made

- `docs/agent-collaboration-loop.md` — GPT ↔ Cursor ↔ human coordination process.
- `agent_loop/README.md`, `assistant_feedback.md`, `cursor_handoff.md` — live loop state files and ownership rules.
- `AGENTS.md`, `README.md` — links to the collaboration loop documentation.
- `.gitignore` — ignore `*.zip` archives (e.g. local `docs.zip` bundles).

## player-facing effect

None. This is contributor and agent workflow documentation only.

## validation performed

- `powershell -File tools/godot.ps1 all` — headless import and GUT tests.
- Manual review of new Markdown links in changed docs.

## test results

`tools/godot.ps1 all` passed: 1/1 tests, all asserts green. GUT emitted invalid-UID warnings for addon scenes (pre-existing; tests still pass).

## rebases and resulting plan changes

No rebase performed. Branch was created from `agent/agent-collaboration-loop`, which was already up to date with its remote when the trivial `.gitignore` commit was added.

## known limitations

- `assistant_feedback.md` has no active GPT directive yet (templates only).
- Branch name `chore/ignore-zip-archives` understates the agent-loop documentation included from the parent branch.

## unresolved decisions

None introduced by this change.

## exact human-feedback request



## recommended next action

GPT review of the draft pull request; human merge judgment when satisfied with the collaboration-loop process documentation.
