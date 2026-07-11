# Agent loop coordination files

This folder holds the live coordination state for the GPT ↔ Cursor ↔ human collaboration loop. Process rules are defined in [docs/agent-collaboration-loop.md](../docs/agent-collaboration-loop.md).

## File ownership

| File | Owner | Purpose |
| --- | --- | --- |
| `assistant_feedback.md` | **GPT** | Current directive, scope, rules, validation expectations, stop condition, and human-feedback question. |
| `cursor_handoff.md` | **Cursor** | Implementation status, branch/commit, changes, validation, rebase notes, limitations, and handoff request. |

**Neither agent edits the other’s file** unless the human explicitly directs it. The human may edit either file when steering the loop.

## Loop states

Set the `status` field at the top of the owning agent’s file when the state changes.

| Status | Meaning |
| --- | --- |
| `READY_FOR_CURSOR` | GPT has issued a directive; Cursor should read canonical docs, rebase from `main`, and begin work on a fresh `agent/<topic>` branch. |
| `CURSOR_WORKING` | Cursor is implementing, validating, or rebasing on the current branch. |
| `READY_FOR_GPT_REVIEW` | Cursor has completed the bounded task (or stopped with a clear report) and updated the handoff; GPT should review the diff and handoff. |
| `HUMAN_FEEDBACK_REQUIRED` | Agents need a human decision—design, playtest, provenance, merge, or rule conflict—before continuing. |
| `BLOCKED` | Work stopped on a documented stop condition; do not proceed until the human unblocks or redirects. |
| `COMPLETE` | The bounded cycle finished; branch and draft pull request are ready for human merge judgment. Agents still do not merge. |

Typical flow:

```text
READY_FOR_CURSOR → CURSOR_WORKING → READY_FOR_GPT_REVIEW → HUMAN_FEEDBACK_REQUIRED → COMPLETE
                              ↘ BLOCKED
```

After `COMPLETE` or a human redirect, GPT writes the next directive and sets `READY_FOR_CURSOR` again.
