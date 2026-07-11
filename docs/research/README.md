# Research notes

Research notes preserve evidence and analysis that will remain useful beyond one issue or pull request. They help contributors understand what was investigated, what was observed, and which trade-offs informed later work.

Research is informative, not authoritative. A concluded research note may recommend a direction, but a consequential project choice still requires a decision record in [`docs/decisions/`](../decisions/README.md).

## What belongs here

Create a durable research note when the work:

- gathers sources or experimental evidence that would be expensive to rediscover;
- compares options that may inform a project-wide decision;
- records results that future contributors will need to interpret architecture or plans; or
- is likely to be referenced by more than one issue or pull request.

Keep short-lived spike logs, status updates, debugging transcripts, and findings relevant to only one change in the associated issue or pull request.

## Status

Use one of these statuses near the top of a research note when its state is not already explicit:

- `In progress` — evidence is still being gathered or evaluated.
- `Concluded` — the investigation reached a documented conclusion.
- `Stale` — assumptions or sources may no longer reflect the current project or ecosystem.

Marking research stale does not erase its historical value. Link to newer research or a superseding decision so readers know where to continue.

## Suggested structure

```md
# <Research topic>

Status: In progress | Concluded | Stale

## Question

What are we trying to learn?

## Context

Which constraints and assumptions matter?

## Sources and evidence

What documentation, experiments, measurements, or playtests did we use?

## Findings

What did the evidence show?

## Options and trade-offs

Which paths remain plausible, and what does each cost?

## Conclusion

What is the supported recommendation or outcome? This does not establish project policy by itself.

## Follow-up

Which issue, plan, architecture document, or decision record uses these findings?
```

## Research index

- [Engine evaluation](engine-evaluation.md) — evaluation supporting the accepted Godot engine decision.
