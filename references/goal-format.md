# Codex Goal lifecycle and transcript contract

`SUPERGOAL_PHASE_*`, `PHASE_POSITION`, and `phases/phase-N.md` are compatibility anchors. Human-facing output calls internal execution slices **Worksteps** and external roadmap phases **Project Phases**.

## Native Goal tools

Supergoal uses the current Codex task's native tools:

- `get_goal({})`: inspect the current Goal before dispatch or reconciliation.
- `create_goal({objective})`: create a persistent Goal only after an explicit autonomous request. Omit `token_budget` unless the user requested one.
- `update_goal({status: "complete"})`: close a Goal only after the objective is genuinely achieved.
- `update_goal({status: "blocked"})`: use only after the same blocking condition has repeated for at least three consecutive Goal turns and meaningful progress is impossible.

The native objective is concise because detailed work lives in the run artifacts. Include the literal run root:

```text
Execute the Supergoal run to verified completion.
Supergoal run root: <run-root>
Read <run-root>/ROADMAP.md, <run-root>/requirement-contract.md, and <run-root>/PROTOCOL.md. Complete every Workstep and requirement, resolve all required deferred work, and use scope-preserving recovery for failures. Run the final audit, documentation trace, safe auto-commit checkpoint, Recallant closeout or evidence-backed allowed skip, and optional Project Phase footer. Do not finish with a FAILURE_HANDOFF, AUDIT_HANDOFF, AUTO_COMMIT_HANDOFF, RECALLANT_HANDOFF, missing requirement coverage, or required deferred item pending. After STATE.md is COMPLETE and SUPERGOAL_RUN_COMPLETE is printed, close the native Goal as complete.
```

After successful `create_goal`, start Workstep 1 immediately in the same task. Do not wait for another user message.

## Slash-command emergency fallback

Slash `/goal` is not the normal dispatch path. Use it only when `get_goal` confirms no active Goal and native `create_goal` is absent, or when a callable `create_goal` technically fails twice (initial call plus one retry).

Substitute the literal run root before printing:

```text
/goal "Execute the Supergoal run at <run-root> to verified completion. Read <run-root>/ROADMAP.md, <run-root>/requirement-contract.md, and <run-root>/PROTOCOL.md; complete every Workstep and requirement; resolve all required deferred work; use scope-preserving recovery; run final audit, documentation trace, safe auto-commit, Recallant closeout or an evidence-backed allowed skip, and optional PHASE_POSITION. Done only when STATE.md is COMPLETE, SUPERGOAL_RUN_COMPLETE is printed, all requirement coverage is satisfied, and no FAILURE_HANDOFF, AUDIT_HANDOFF, AUTO_COMMIT_HANDOFF, RECALLANT_HANDOFF, or required deferred item remains."
```

If an unrecoverable ghost Goal prevents native creation, print this emergency sequence and do not claim it ran:

```text
/goal clear
/goal "<the prepared fallback objective>"
```

## Reconciliation block

```text
GOAL_RECONCILIATION
Native status: <status|none>
Associated run: <run-root|none|ambiguous>
Classification: <STALE_COMPLETE|RECOVERABLE_INCOMPLETE|INDETERMINATE|GENUINELY_BLOCKED|NO_ACTIVE_GOAL>
Evidence:
- <evidence>
Action: <native close|resume old run|continue investigation|block|start new run>
```

## Workstep transcript blocks

### `SUPERGOAL_PROGRESS`

Print the helper output exactly when it emits a snapshot. Normal output is three lines:

```markdown
**🟦 SUPERGOAL PROGRESS**
**███████░░░ 68%** · **6/9 Worksteps** · ⏱ **4h 12m** · ETA **2–4h** *(medium)*
Now: **W07 — Integration hardening** · Plan rev **2** · **active**
```

Use `🟨` for recovering/waiting, `🟥` only for genuine blockage, and `🟩` for complete. On replan, the third line shows the old/new Workstep counts and reason. If state cannot be trusted, print the helper fallback with `Progress unavailable` and continue product work.

Mode-specific compact examples:

```text
🟨 recovering — Now: W04 — Repair migration ordering · Plan rev 2 · recovering
🟨 waiting — ETA unavailable · Now: W04 — External environment · waiting
🟥 blocked — ETA unavailable · Now: required authority unavailable · blocked
🟩 complete — 100% · 9/9 Worksteps · ETA 0m · complete
```

These are semantic labels, not a color-only contract. The helper emits bold Markdown and the full three-line block.

### `SUPERGOAL_PHASE_START`

```text
SUPERGOAL_PHASE_START
Workstep: <N> of <total> — <name>
Task: <one-line>
Requirements: <REQ IDs>
Mandatory commands: <commands>
Acceptance criteria: <count>
Depends on worksteps: <list|none>
Deferred items targeted here: <list|none>
```

### `SUPERGOAL_PHASE_VERIFY`

```text
SUPERGOAL_PHASE_VERIFY
Requirements:
- REQ-001: <pass|fail> — <evidence>
Acceptance:
- AC-N.1: <pass|fail> — <evidence>
Deferred work:
- <item>: <done|pending|needs-user-decision|out-of-scope> — <evidence>
Engineering:
- build: <pass|fail|not-applicable>
- typecheck: <pass|fail|not-applicable>
- lint: <pass|fail|pre-existing|not-applicable>
- tests: <pass|fail|not-applicable>
Cleanliness:
- debug prints added: <count>
- session TODO/FIXME added: <count>
- dead imports added: <count>
Files changed: <count>
```

### `MEMORY_SAVED`

```text
MEMORY_SAVED: <name|none — nothing durable learned>
```

### `DOCUMENTATION_TRACE`

```text
DOCUMENTATION_TRACE
doc_target: <path|not applicable>
changed: <yes|no>
reason: <reason>
evidence: <evidence>
public_private_boundary_check: <passed|failed|not_applicable> — <note>
```

### `SUPERGOAL_PHASE_DONE`

```text
SUPERGOAL_PHASE_DONE
Workstep <N> complete. Requirements verified: <REQ IDs>. STATE.md updated.
```

## Final audit blocks

### `AUDIT_START`

```text
AUDIT_START
Round: <N>
Worksteps to verify: <count>
Requirements to verify: <count>
Criteria to re-check: <count>
Commands to re-run: <commands>
```

### `AUDIT_VERIFY`

```text
AUDIT_VERIFY
Requirement coverage:
- REQ-001: <pass|fail> — <Workstep/criterion/evidence>
Workstep completeness:
- Workstep 1: <DONE present|DONE missing>
Commands:
- <command>: exit <code> — <evidence>
Criteria:
- AC-N.M: <pass|fail|trust-prior-verify> — <evidence>
Deliverables:
- <deliverable>: <present|missing> — <evidence>
Deferred work:
- <item>: <done|pending|needs-user-decision|out-of-scope>
Documentation trace: <updated|created|not-applicable|missing>
Recallant status: <connected|not-connected|unknown|missing|ambiguous>
```

### `AUDIT_GAPS`

```text
AUDIT_GAPS
Round: <N>
Gaps:
- <gap>
Recovery level: <root-cause|alternate approach|fix spec|workstep rebuild|dependent replan|full redesign>
```

### `AUDIT_COMPLETE`

```text
AUDIT_COMPLETE
Rounds: <N>
Requirements: <count> pass / 0 fail / 100% mapped
Worksteps re-verified: <count>
Commands re-run clean: <count>
Acceptance criteria: <pass> pass / 0 fail / <trust> trust-prior
Deliverables: <present> present / 0 missing
Deferred work: <done> done / 0 pending-or-needs-decision
Documentation trace: <updated|created|not-applicable>
Recallant status: <status>
Audit coverage: <re-verified> / <trust-prior> (<pct>%)
```

### `AUDIT_HANDOFF`

Emit only after the full recovery ladder, including a scope-preserving redesign, cannot close persistent gaps:

```text
AUDIT_HANDOFF
Persistent gaps:
- <gap>
Recovery levels exhausted: <list>
Blocking class: <environment|authority|logical impossibility|other>
Evidence: <evidence>
STATE.md updated to GENUINELY_BLOCKED.
```

## Auto-commit blocks

```text
AUTO_COMMIT_START
Run: <run-root>
Baseline: <sha|no-git>
Baseline dirty paths: <count>
Branch: <branch>
```

```text
AUTO_COMMIT_COMPLETE
Commit: <sha>
Files committed: <count>
Unstaged pre-existing paths: <count>
```

```text
AUTO_COMMIT_SKIPPED: <no git repo|no changes|no safe staged changes>
Details: <reason>
```

```text
AUTO_COMMIT_HANDOFF
Reason: <persistent git error or unsafe staging ambiguity>
Evidence: <evidence>
STATE.md updated to GENUINELY_BLOCKED.
```

## Recallant blocks

```text
RECALLANT_CLOSEOUT
connected: <yes|no|unknown>
transport: <mcp|cli|skipped>
closeout_tool: <memory_closeout|recallant agent-closeout|skipped>
closeout_capability: <verified|unavailable|unknown>
capability_evidence: <evidence>
lifecycle.next_agent_ready: <true|false|unknown>
checkpoint_updated: <true|false>
searchable_memory_created: <true|false>
recall_verified: <true|false>
next_session_context_verified: <true|false>
closeout_key: <key>
warnings: <none|warnings>
failure_reasons: <none|reasons>
```

```text
RECALLANT_HANDOFF
Reason: <verified capability failed and recovery was exhausted>
Evidence: <evidence>
STATE.md updated to GENUINELY_BLOCKED.
```

## `PHASE_POSITION`

Emit only for Project Phase-targeted runs, after Recallant closeout:

```text
PHASE_POSITION
Completed project phase: Project Phase <N> of <M> — <name>
Next project phase: <Project Phase N+1 of M — name|none — final planned project phase>
```

## Failure and recovery blocks

```text
FAILURE_PROBE
Workstep: <N> — <name>
Failed criterion: <criterion>
Failure class: <command|approach|environment|authority|logical impossibility>
Tried: <attempt>
Root-cause evidence: <evidence>
Next recovery level: <level>
```

```text
FAILURE_ESCALATE
Workstep: <N> — <name>
Failed criterion: <criterion>
Recovery level: <alternate approach|fix spec|workstep rebuild|dependent replan|full redesign>
Plan: <scope-preserving action>
```

```text
FAILURE_HANDOFF
Workstep: <N> — <name>
Failed criterion: <criterion>
Recovery levels exhausted: <list>
Blocking class: <environment|authority|logical impossibility|other>
Evidence: <evidence>
STATE.md updated to GENUINELY_BLOCKED.
```

## Completion block

Print only after all gates are persisted and before native `update_goal({status: "complete"})`:

```text
SUPERGOAL_RUN_COMPLETE
Audit coverage: <re-verified> re-verified, <trust-prior> trust-prior (<pct>%).
All <N> Worksteps and <R> requirements complete.
Checkpoint: <commit sha|skipped: reason>
Documentation: <target and result>
Recallant: <result>
Native Goal closeout: pending update_goal(complete)
```

After the tool call, report its result and persist it in `STATE.md` when possible.

## Anti-patterns

- Do not create a persistent Goal for an ordinary task without explicit autonomous intent.
- Do not trust a nonterminal status without artifact reconciliation.
- Do not close an incomplete Goal to make room for a new one.
- Do not drop a requirement to remove a plan flag.
- Do not stop after `create_goal`; begin execution immediately.
- Do not mark a Goal complete before all run gates pass.
- Do not mark a Goal blocked merely because a command failed several times.
