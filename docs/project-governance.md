# Project governance

## Branch model

`main` is the protected default branch and should always represent a coherent, reviewable project state. Contributors work in topic branches and merge through pull requests.

The current protection baseline for `main` is:

- pull requests are required before merging;
- one approving review is required;
- approvals are dismissed when new commits are pushed;
- all review conversations must be resolved;
- force pushes and branch deletion are blocked;
- repository administrators can bypass the rule in an emergency.

No code owner or required status check exists yet. Add those only after the project has a stable directory layout and a repeatable build. At that point, require formatting, tests, and a build before merge.

## Review expectations

Reviewers should check gameplay clarity, minigame integration boundaries, asset provenance, accessibility, and whether the change matches its proposal. A reviewer does not need to be an expert in the chosen engine to spot unclear setup instructions, missing credits, scope creep, or a confusing player experience.

Authors should not approve their own work. If a change affects the shared shell, minigame contract, engine version, or project-wide art conventions, request review from a maintainer and update the appropriate document.

## Decision records

Use a short decision record in `docs/decisions/` for consequential, hard-to-reverse choices, such as the engine, target platform, networking model, licenses, shared minigame API, or common art pipeline. Include the context, options considered, decision, consequences, and date. Do not bury a project-wide decision inside a single minigame pull request.

## Maintainer responsibilities

Maintainers preserve a welcoming contribution path, maintain branch protection and automation, resolve ownership or licensing questions before release, and keep project-wide documents current. They may use the administrator bypass only for recovery or urgent maintenance, then document why it was used.
