---
name: supergoal
description: Plan and autonomously execute a software task end-to-end in Codex. Use only when the user explicitly invokes `/supergoal` or clearly asks for autonomous delivery such as "plan and ship", "do not stop until done", "I do not want to babysit this", or an equivalent request. Reconcile stale native Goals, inspect the repo, preserve every requirement, repair plan and pre-flight defects without reducing scope or quality, dispatch through native `create_goal`, execute all Worksteps, recover from failures, run the final audit and closeout gates, then close the native Goal. Use Codex `/goal` only as an emergency fallback when native Goal dispatch is unavailable.
---

# Supergoal

Execute the user's task autonomously from request to verified result.

The task is:

`$ARGUMENTS`

Use the native Codex Goal lifecycle in the current task. Do not ask for plan approval or a separate launch confirmation, and do not require the user to paste a slash command on the normal path.

## Non-negotiable result contract

Translate the request into measurable requirements and preserve all of them through planning and recovery:

- **Functional:** golden path and obvious edge cases work.
- **Engineering:** build, typecheck, tests, and relevant lint checks pass, or pre-existing lint debt is baseline-proven and not worsened.
- **Polish:** applicable loading, empty, error, unauthorized, copy, and responsive states are handled.
- **Hardening:** input validation, security, accessibility, performance, and regression surfaces are reviewed where relevant.
- **Verification:** every requirement maps to a Workstep criterion and final verification evidence.

Never clear a red flag by dropping scope, weakening tests, bypassing security, skipping accessibility, or redefining the requested outcome.

## Native Goal authorization gate

Call `create_goal` only when this skill was explicitly invoked or the user explicitly requested autonomous end-to-end execution. Skill auto-discovery for an ordinary coding request is not authorization to create a persistent Goal.

Do not pass `token_budget` unless the user explicitly requested one.

## State machine

Persist the current state in the run's `STATE.md`:

```text
REQUESTED
→ RECONCILING_EXISTING_GOAL
→ PLANNING
→ REPAIRING_PLAN
→ PREFLIGHT
→ CREATING_GOAL
→ EXECUTING
→ FINAL_AUDIT
→ CLOSING_OUT
→ COMPLETE
```

Exceptional terminal states:

- `FALLBACK_READY`: native Goal dispatch is unavailable and a Codex `/goal` fallback is prepared.
- `GENUINELY_BLOCKED`: evidence proves that no safe authorized path remains.
- `PAUSED_BY_USER`: the user explicitly asked to pause or stop.

Do not infer completion or blockage from one stale status field. Use artifacts and repository evidence.

## Locate the skill and run roots

```bash
SUPERGOAL_DIR=$(dirname "$(ls -1 \
  "$HOME/.codex/skills/supergoal/SKILL.md" \
  "$PWD/.codex/skills/supergoal/SKILL.md" \
  2>/dev/null | head -n1)")
export SUPERGOAL_DIR
export SUPERGOAL_BASE="${SUPERGOAL_BASE:-.supergoal}"
mkdir -p "$SUPERGOAL_BASE"
```

Each run receives a namespaced `$SUPERGOAL_ROOT` under `$SUPERGOAL_BASE`. Keep compatibility anchors unchanged: `SUPERGOAL_PHASE_*`, `PHASE_POSITION`, `phases/phase-N.md`, `phase-position.md`, and `Current phase`. In human-facing text, call internal slices **Worksteps** and reserve **Project Phase** for phases from an external project roadmap.

## Stage 0 — Reconcile native and local state

Set runtime lifecycle state to `RECONCILING_EXISTING_GOAL` before planning. Before a fresh run root exists, persist reconciliation under `$SUPERGOAL_BASE/reconciliations/<timestamp>-<slug>.md`; do not rewrite an old completed run merely to record that inspection. After a new run is claimed, copy the reconciliation result into its `STATE.md`. When an associated old run is safely closed or resumed, add only a link to the reconciliation record in that run's append-only notable events.

### 0.1 Inspect the native Goal first

Call `get_goal`.

- If no Goal exists, continue to local-run inspection.
- If a Goal exists, do not treat its nonterminal status as proof of unfinished work. Reconcile it before creating or dispatching anything new.

### 0.2 Associate the Goal with a Supergoal run

New native Goal objectives must contain:

```text
Supergoal run root: <run-root>
```

For a legacy Goal without that line, locate the best matching run using its objective, run title, `STATE.md`, `ROADMAP.md`, current Workstep, final checkpoints, and repository changes. Do not guess when two candidates remain equally plausible; continue evidence collection first.

### 0.3 Audit the associated run

Run:

```bash
bash "$SUPERGOAL_DIR/scripts/audit-run-state.sh" <run-root>
```

Read the generated evidence together with:

- `STATE.md` and `ROADMAP.md`;
- Workstep completion and deliverables;
- `requirement-contract.md` coverage;
- mandatory command and final-audit evidence;
- `deferred-work.md` resolution;
- documentation trace;
- auto-commit result or valid skip reason;
- Recallant closeout result or valid skip reason;
- handoff/failure markers;
- current repository state.

The script is evidence, not the final decision. Independently verify any uncertain objective-specific result.

### 0.4 Classify and act

Write the decision using `templates/goal-reconciliation.md` at the reconciliation-ledger path above. Keep each inspection as a separate file so concurrent or repeated launches cannot overwrite evidence.

#### `STALE_COMPLETE`

Use only when required work is verifiably complete and all completion gates are satisfied or can be safely reconstructed.

1. Record the evidence and remaining stale field.
2. Call `update_goal({status: "complete"})`.
3. Call `get_goal` again.
4. Continue the incoming request after terminal state is confirmed.

Do not delete run artifacts. Marking a verified completed Goal complete is the safe repair.

#### `RECOVERABLE_INCOMPLETE`

Use when unfinished work is identifiable and safely executable.

1. Preserve the incoming request under `$SUPERGOAL_BASE/pending-launch/`.
2. Resume the old run at its first incomplete Workstep or checkpoint.
3. Finish and audit the old run without narrowing its objective.
4. Close it with `update_goal({status: "complete"})`.
5. Automatically resume the preserved incoming request.

#### `INDETERMINATE`

Use when evidence is insufficient. Inspect the objective, repository, tests, deliverables, and nearby run artifacts again. Do not close the Goal merely because stale Goals are common. Convert to another classification only when evidence supports it.

#### `GENUINELY_BLOCKED`

Use only when required work remains and no safe authorized solution survives the recovery ladder. Preserve exact evidence. Call `update_goal({status: "blocked"})` only after the same blocking condition has recurred for at least three consecutive Goal turns, as required by Codex. Otherwise leave the Goal active and continue meaningful recovery.

### 0.5 Reconcile local run artifacts

Scan `$SUPERGOAL_BASE/*/STATE.md` and the legacy `$SUPERGOAL_BASE/STATE.md`.

- Resume a matching recoverable run.
- Treat completed evidence with a stale local status as a local reconciliation, not a blocker.
- Keep unrelated run artifacts isolated.
- Do not run two autonomous source-editing executions in one working tree. Use a separate git worktree when real concurrent execution is detected.

Preload unresolved scope from `$SUPERGOAL_BASE/PENDING_WORK.md`, matching active/recent run ledgers at `$SUPERGOAL_BASE/*/deferred-work.md`, and the selected run's `deferred-work.md`. Import only items that plausibly apply to the incoming task, record their source and reason in `applied-pending-work.md`, and keep the cross-run ledger synchronized when a run finishes or genuinely blocks. Never rely on the user to remember deferred scope.

For a fresh run:

```bash
SUPERGOAL_ROOT="$(bash "$SUPERGOAL_DIR/scripts/claim-run.sh" "$ARGUMENTS")"
export SUPERGOAL_ROOT
```

## Stage 1 — Autonomous intake

Set lifecycle state to `PLANNING`.

Infer defaults in this order:

1. Explicit user request and attached artifacts.
2. Repository conventions, tests, docs, and current architecture.
3. Applicable memory and prior durable decisions exposed by Codex.
4. Existing project patterns and compatibility requirements.
5. Current primary documentation or research when facts may have changed.
6. The safest reversible professional default.

Record assumptions in `ROADMAP.md`; do not request approval for them. Ask the user only when execution is impossible without unavailable credentials, a required irreversible external action lacks authority, explicit requirements remain logically incompatible after redesign, or Codex/system policy requires user action.

For Project Phase-targeted requests, locate the source plan, preserve Project Phase `N of M`, and create `phase-position.md`. If the source plan cannot be found, search the repo and attached artifacts before treating the missing source as a genuine blocker.

## Stage 2 — Recon

Run the appropriate scripts and save their output under `$SUPERGOAL_ROOT`:

```bash
# Existing repository
bash "$SUPERGOAL_DIR/scripts/detect-stack.sh" > "$SUPERGOAL_ROOT/context.md"
bash "$SUPERGOAL_DIR/scripts/summarize-repo.sh" > "$SUPERGOAL_ROOT/repo-map.md"

# Greenfield environment
bash "$SUPERGOAL_DIR/scripts/detect-env.sh" > "$SUPERGOAL_ROOT/context.md"
```

Inspect the actual source of truth. Preserve unrelated dirty work. Detect available tools and relevant skills from the current Codex session without assuming specific MCP names. Record capabilities in `tools.md`.

Detect Recallant using project-specific evidence only. Do not attach, onboard, or connect a project merely to satisfy closeout. Preserve the existing verified/unknown/unavailable closeout behavior in `recallant-status.md`.

## Stage 3 — Requirement contract and deep think

Create `$SUPERGOAL_ROOT/requirement-contract.md` from `templates/requirement-contract.md` before Workstep decomposition.

Assign stable IDs `REQ-001`, `REQ-002`, and so on to every explicit requirement, preserved compatibility promise, required quality gate, and imported pending item. For each requirement record:

- source;
- exact intent;
- non-degradation invariant;
- planned Workstep and acceptance criterion IDs;
- final verification;
- status.

Write `THINKING.md` with goals, constraints, top three risks, dependency ordering, applicable memory, pending work, documentation plan, Recallant plan, and current best practices. Keep it concise.

## Stage 4 — Decompose into Worksteps

Derive the number of Worksteps from independently verifiable units; do not impose a fixed count.

- Give every Workstep measurable deliverables, acceptance criteria, commands, evidence, dependencies, and covered requirement IDs.
- Use stable criterion IDs such as `AC-2.1`.
- Add an early safety-net Workstep when changing weakly tested brownfield behavior.
- Add visual verification for UI work.
- Make the final Workstep `Polish & Harden`, including documentation trace, regression, security, accessibility, performance, and diff review where applicable.

Read `references/phase-design.md` and `references/planning-depth.md` for the quality bar.

For long-running visibility, also assign each Workstep effort points, a planned duration range, and evidence-backed milestones. Read `references/progress-reporting.md`; weighted progress supplements Workstep acceptance and never replaces it.

## Stage 5 — Write run artifacts

Create:

- `ROADMAP.md` from `templates/ROADMAP.md`;
- `STATE.md` from `templates/STATE.md`;
- `requirement-contract.md`;
- `deferred-work.md`;
- `documentation-trace.md`;
- `recallant-status.md`;
- `progress.tsv` rendered from `templates/progress.tsv`;
- optional `phase-position.md`;
- one `phases/phase-N.md` per Workstep from `templates/phase-goal.txt`.

Validate every Workstep spec:

```bash
bash "$SUPERGOAL_DIR/scripts/validate-phase.sh" "$SUPERGOAL_ROOT/phases/phase-N.md"
```

Never silently drop imported pending work. Resolve it in a Workstep, retain a concrete unlock condition and target Workstep, or classify it as a genuine blocker. `out-of-scope` requires an explicit user exclusion, not an implementation convenience.

## Stage 5.5 — Progress-aware plan repair

Set lifecycle state to `REPAIRING_PLAN` and build `plan-integrity.md`.

Check artifact creation/use order, command prerequisites, migrations, dependency edges, requirement coverage, deferred items, documentation, Recallant, destructive steps, incompatible criteria, and independently verifiable Workstep boundaries.

Use this repair ladder without reducing scope or quality:

1. Reclassify a premature command.
2. Move a criterion or action to the first valid Workstep.
3. Move or add a narrow prerequisite earlier.
4. Split a mixed Workstep.
5. Merge Worksteps that cannot verify independently.
6. Resequence dependencies and compatibility filenames.
7. Add a foundation Workstep.
8. Choose a scope-preserving alternative design.
9. Rebuild the plan from `requirement-contract.md`.

After each repair:

1. Rebuild the plan graph.
2. Revalidate every affected Workstep.
3. Verify 100% requirement coverage.
4. Compare the new integrity fingerprint with the prior round.

For every structural plan change, update the replacement progress plan and run `progress.sh replan` so verified milestones carry by stable ID, the plan revision increments, and the next forced report exposes any changed denominator. Never hide a lower recalculated percentage.

Continue while the flag set or severity improves. If the same unresolved fingerprint repeats, escalate to the next repair level. After the full-plan rebuild, classify a remaining issue as a genuine blocker only when no safe authorized scope-preserving solution exists. Do not turn a mechanical planning defect into a user question.

For lint, preserve the pre-edit baseline and prove that run-touched files add no new errors. Never report a red baseline as green.

## Stage 6 — Informational summary and pre-flight

Before pre-flight, initialize and validate durable progress state with `bash "$SUPERGOAL_DIR/scripts/progress.sh" init "$SUPERGOAL_ROOT"`. Treat reporting errors as nonblocking: print the reference fallback, preserve the diagnostic, and repair progress at the next safe boundary while continuing the product task.

Print a compact summary of Worksteps, assumptions chosen, requirements covered, repairs made, risks, deferred work, and artifacts. Then print:

```text
AUTO_ADVANCE_TO_PREFLIGHT
No user decision required; running pre-flight now.
```

Do not pause after the summary.

Set lifecycle state to `PREFLIGHT`. Run only deduplicated `baseline-safe` commands. Classify future-artifact commands as `requires-phase-N` and credential/external commands as `external/env`.

For a red command:

- fix a misclassification;
- assign a broken baseline to the Workstep that repairs it;
- add/reorder a foundation Workstep;
- redesign the plan without weakening verification;
- rerun Stage 5.5 and pre-flight.

Never offer to skip a meaningful red pre-flight check. Stop only on a genuine blocker or required platform permission.

## Stage 7 — Native Goal dispatch

After pre-flight is acceptable:

1. Capture `Baseline ref` and `baseline-status.txt`.
2. Render `PROTOCOL.md` with the literal run root.
3. Copy `repo-state.sh` and `references/goal-format.md` into the run root as `repo-state.sh` and `GOAL_FORMAT.md`.
4. Copy `scripts/progress.sh` into the run root as `progress.sh` so resume behavior is pinned to the run contract.
5. Revalidate every Workstep spec and requirement mapping.
6. Set lifecycle state to `CREATING_GOAL`.
7. Build a compact objective containing:
   - `Supergoal run root: <run-root>`;
   - instructions to read `ROADMAP.md`, `requirement-contract.md`, and `PROTOCOL.md`;
   - all-Workstep execution and autonomous scope-preserving recovery;
   - final audit, documentation, auto-commit, Recallant, and optional Project Phase gates;
   - no unresolved required deferred work or handoff marker;
   - native Goal closeout after verified completion.
8. Call `create_goal({objective: <objective>})` without `token_budget` unless explicitly requested.

On success, write `Goal dispatch method: native`, set lifecycle state to `EXECUTING`, set progress mode `active`, and force the `goal-dispatched` snapshot. Begin Workstep 1 immediately in the same task. Do not stop after creating the Goal or ask about the progress report.

### Dispatch failure routing

- If `create_goal` reports an unfinished Goal, return to Stage 0, reconcile it, and retry native creation once.
- If `create_goal` is absent, route directly to fallback. If it is callable but fails technically, retry once; after the retry fails and `get_goal` still confirms no active Goal, set `FALLBACK_READY`, record `Goal dispatch method: slash-fallback`, and emit the exact Codex `/goal` objective from `references/goal-format.md`.
- If a ghost Goal remains after evidence-based reconciliation and cannot be closed natively, emit `/goal clear` followed by the prepared `/goal` command as an emergency manual sequence. Do not claim execution started.

## Execution, audit, and closeout

Follow the rendered `PROTOCOL.md` for Workstep execution, requirement checks, deferred work, memory writeback, documentation, final audit, auto-commit, Recallant closeout, Project Phase footer, and recovery. Use `references/goal-format.md` for transcript blocks.

At every return of control, ask the pinned run `progress.sh` for a non-forced snapshot. Force snapshots at Workstep completion, recovery/replan transitions, audit boundaries, genuine blockage, and completion. Follow `references/progress-reporting.md` for cadence, ETA, migration, and fallback rules.

When the user voluntarily sends a change during execution, incorporate it at the next safe Workstep boundary, update the requirement contract and affected specs, re-run integrity checks, and continue automatically. Pause only when the user explicitly asks to pause or stop.

After all completion gates pass:

1. Set lifecycle state to `CLOSING_OUT`.
2. Persist final audit, commit/skip, documentation, Recallant, deferred-work, and last-checkpoint evidence in `STATE.md`.
3. Set run status to `COMPLETE`.
4. Print `SUPERGOAL_RUN_COMPLETE`.
5. Call `update_goal({status: "complete"})`.
6. Record the native closeout result in `STATE.md` when filesystem work remains possible; otherwise ensure the transcript contains it.

If native closeout fails after work is complete, preserve enough checkpoint evidence for the next run to classify it as `STALE_COMPLETE`.

## Recovery ladder

Do not equate three command attempts with a genuine blocker. For a failing criterion or audit gap:

1. Diagnose the root cause and record evidence.
2. Retry after a mechanical fix.
3. Try an independent technical approach.
4. Write and execute a focused fix spec.
5. Rebuild the current Workstep.
6. Replan dependent Worksteps.
7. Perform a full scope-preserving redesign from the requirement contract.
8. Re-run affected verification and the final audit.

Set progress mode `recovering` and force a snapshot when entering recovery. After successful repair, set mode `active`, update/replan durable progress if structure changed, force the recovery-complete snapshot, and continue. A progress subsystem failure is never itself a genuine blocker.

Classify the failure as command-specific, approach-specific, environment-specific, authority-specific, or logically impossible. Use `GENUINELY_BLOCKED` only after the applicable ladder is exhausted and no meaningful progress remains. Respect Codex's three-consecutive-Goal-turn requirement before calling `update_goal({status: "blocked"})`.

## Operating principles

- Normal path: zero approval prompts and zero manual slash-command pastes.
- Status is a hint; artifacts and repository evidence determine truth.
- Explicit requirements are invariants, not negotiable planner inputs.
- Prefer reversible, compatibility-preserving changes.
- Preserve unrelated dirty work and never commit it accidentally.
- Keep runtime artifacts out of product commits unless explicitly deliverable.
- Use current tools opportunistically; never hard-require an optional MCP.
- Keep local memory writeback separate from canonical Recallant closeout.
- Never claim success while required deferred work, a failed criterion, or a handoff marker remains.

## References

- `references/planning-depth.md`: planning quality and research guidance.
- `references/phase-design.md`: Workstep slicing and dependency rules.
- `references/goal-format.md`: native Goal lifecycle, fallback objective, and transcript blocks.
- `references/repo-state-comparison.md`: complete working-tree comparison strategy.
- `references/progress-reporting.md`: weighted progress, ETA, cadence, migration, and rendering contract.

## Scripts

- `scripts/claim-run.sh`: atomically claim a run namespace.
- `scripts/detect-stack.sh`: detect brownfield stack and commands.
- `scripts/detect-env.sh`: inspect a greenfield environment.
- `scripts/summarize-repo.sh`: produce a compact repo map.
- `scripts/repo-state.sh`: compare complete working-tree state against baseline.
- `scripts/validate-phase.sh`: validate Workstep structure and requirement mappings.
- `scripts/audit-run-state.sh`: gather deterministic stale-Goal reconciliation evidence.
- `scripts/progress.sh`: validate and update durable progress, estimate ETA, suppress duplicate heartbeats, and render operator snapshots.

## Templates

- `templates/STATE.md`, `ROADMAP.md`, `phase-goal.txt`, and `PROTOCOL.md`.
- `templates/requirement-contract.md` and `goal-reconciliation.md`.
- `templates/documentation-trace.md`, `recallant-status.md`, `recallant-closeout.md`, and `phase-position.md`.
- `templates/progress.tsv`: dependency-light durable progress schema.
