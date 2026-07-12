# Project governance

## Branch model

`main` is the protected default branch and should always represent a coherent, reviewable project state. Contributors work in topic branches and merge through pull requests.

The current protection baseline for `main` is:

- pull requests are required before merging;
- zero approving reviews are temporarily required, so an author can merge their own pull request;
- approvals are dismissed when new commits are pushed, if a review has been given;
- all review conversations must be resolved;
- force pushes and branch deletion are blocked;
- repository administrators can bypass the rule in an emergency.

Restore one required independent approval when at least two active contributors are available. This preserves a lightweight pull-request record now without treating an unavailable reviewer as a permanent merge blocker.

The required `Godot tests` status check runs the headless import and GUT suite on Windows, macOS, and Linux. The `Repository quality` check enforces project-owned GDScript formatting and lint, tests the repository guard, and rejects non-exempt files over 5 MiB. Add `Repository quality` to the protected `main` branch's required checks after its first successful workflow run, then keep both checks required for pull requests; add export and additional checks as those workflows become repeatable.

## Review expectations

Reviewers should check gameplay clarity, minigame integration boundaries, asset provenance, accessibility, and whether the change matches its proposal. A reviewer does not need to be an expert in the chosen engine to spot unclear setup instructions, missing credits, scope creep, or a confusing player experience.

GitHub does not permit pull-request authors to approve their own work. While no approval is required, authors should still request feedback when another contributor is available. If a change affects the shared shell, minigame design guide or integration contract, engine version, or project-wide art conventions, request review from a maintainer when possible and update the appropriate document.

## Decision records

Use a short decision record in `docs/decisions/` for consequential, hard-to-reverse choices, such as the engine, target platform, networking model, licenses, shared minigame API, or common art pipeline. Include the context, options considered, decision, consequences, and date. Do not bury a project-wide decision inside a single minigame pull request.

## Maintainer responsibilities

Maintainers preserve a welcoming contribution path, maintain branch protection and automation, resolve ownership or licensing questions before release, and keep project-wide documents current. They may use the administrator bypass only for recovery or urgent maintenance, then document why it was used.
