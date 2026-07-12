# Friend minigame contributor onboarding

This is the human-facing path from an idea to a reviewable Bean Party minigame. It assumes that you are comfortable asking a coding agent for help but do not already know this repository or Godot workflow.

## 1. Fork and clone

Use GitHub's **Fork** button on [`nonstdio/bean-party`](https://github.com/nonstdio/bean-party), then clone your fork and record the main repository as `upstream`:

```bash
git clone https://github.com/YOUR-GITHUB-USER/bean-party.git
cd bean-party
git remote add upstream https://github.com/nonstdio/bean-party.git
git fetch upstream
```

Do not work directly on `main`. Once your proposal is approved, start a focused branch from current upstream `main`:

```bash
git switch -c minigame/your-minigame upstream/main
```

Follow [Godot setup for agents](godot-setup.md) to install the pinned Godot 4.7 stable editor. Follow its quality-tool setup before preparing a pull request.

## 2. Propose the idea before substantial implementation

Read, in order:

1. [Game design target](../design/game.md)
2. [Creative direction](../design/creative-direction.md)
3. [Minigame design guide](../design/minigames.md)
4. [Create a minigame](create-a-minigame.md)

Open a GitHub issue using the [Minigame proposal template](../../.github/ISSUE_TEMPLATE/minigame-proposal.yml). A maintainer must record `Approved for implementation` before substantial work intended for integration begins. A small self-contained experiment may proceed on a personal branch or draft pull request, but it cannot change shared interfaces or be presented as integration-ready.

### Copyable proposal prompt

Replace the final line with your idea, then paste this into your coding agent:

```text
I want to contribute a minigame to Bean Party. Read AGENTS.md and docs/guides/friend-minigame-onboarding.md, then help me draft a GitHub minigame proposal that answers every field in .github/ISSUE_TEMPLATE/minigame-proposal.yml. Identify unclear rules, integration risks, accessibility needs, and asset-provenance questions. Do not implement the minigame or change shared interfaces yet.

My idea: REPLACE THIS WITH YOUR IDEA.
```

## 3. Implement after approval

Once the issue is approved, give the agent the issue URL and paste:

```text
My Bean Party minigame proposal has received "Approved for implementation": PASTE ISSUE URL HERE. Confirm this checkout is on a focused branch based on current upstream/main. Read AGENTS.md, the approved proposal, docs/architecture/minigame-integration.md, docs/guides/create-a-minigame.md, and minigames/reference-tap/README.md. Scaffold the approved minigame with tools/new-minigame, keep it self-contained, develop through the local harness, add tests and current design documentation, and run the documented quality and Godot checks. Do not expand the approved scope or change a shared interface without stopping and asking me.
```

The scaffold commands are:

```powershell
.\tools\new-minigame.ps1 -Slug "your-minigame" -DisplayName "Your Minigame"
```

```bash
bash tools/new-minigame.sh your-minigame "Your Minigame"
```

Use [`reference-tap`](../../minigames/reference-tap/README.md) as the smallest executable example of the accepted local contract.

## 4. Know what the harness proves

Open `res://scenes/dev/minigame_harness.tscn` in Godot and run the current scene with `F6`. Point its exported `manifest_path` at your minigame.

The harness proves manifest loading, deterministic local players and RNG, normalized shell-owned input, result validation, abort, retry, and clean unload. Its buttons inject the normalized `primary` action. It does **not** prove:

- physical keyboard or controller assignment;
- integration into the app's board or phase flows;
- online transport, authority, prediction, or synchronization;
- balance, clarity, accessibility, or fun with real players.

Automated tests and human playtests are both expected where applicable.

## 5. Prepare for review

Before opening a pull request, run:

```powershell
.\tools\quality.ps1 check
.\tools\godot.ps1 all
```

```bash
bash tools/quality.sh check
bash tools/godot.sh all
```

Complete every applicable part of the [pull-request template](../../.github/PULL_REQUEST_TEMPLATE.md). Reviewers check gameplay clarity, proposal fit, minigame/shell boundaries, accessibility, asset originality and provenance, current documentation, automated validation, intended-player-count testing, and disclosed limitations. Include a screenshot or short clip for visible gameplay.

The local harness is a development tool, not a substitute for watching friends play the minigame without coaching.
