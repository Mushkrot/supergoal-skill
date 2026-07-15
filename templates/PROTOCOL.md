# Supergoal execution protocol

Run root: `{{RUN_ROOT}}`

Read this file, `ROADMAP.md`, `requirement-contract.md`, `STATE.md`, `plan-integrity.md`, `deferred-work.md`, and `recallant-status.md` before execution. Continue autonomously until the run is complete or evidence proves a genuine blocker.

## Core invariants

- Preserve every requirement and its non-degradation invariant.
- Do not stop after a failed command; use the recovery ladder.
- Do not ask for routine decisions or permission to continue.
- Do not modify unrelated dirty work or commit it accidentally.
- Do not complete while any requirement, criterion, required deferred item, documentation gate, audit, checkpoint, or required closeout remains unresolved.
- Incorporate voluntary user changes at the next safe Workstep boundary and continue unless the user explicitly pauses or stops.

## Workstep loop

For current Workstep `N`:

1. Set lifecycle state to `EXECUTING` and read `STATE.md`.
2. Read the Workstep spec at `phases/phase-N.md`.
3. Re-read the requirement rows and deferred items targeted by this Workstep.
4. Verify dependencies and unlock conditions. If a mechanical dependency is wrong, repair the plan and affected specs before work.
5. Print `SUPERGOAL_PHASE_START` using the format reference.
6. Execute the work while preserving unrelated user changes.
7. Run every mandatory command valid at this point and surface exit codes plus relevant output.
8. Use `repo-state.sh added-lines` against `Baseline ref` for debug prints, run-created TODO/FIXME markers, and dead imports. Apply a declared cleanliness override only when justified in the spec.
9. Print `SUPERGOAL_PHASE_VERIFY` with each requirement and criterion mapped to evidence.
10. Update `deferred-work.md`; mark only evidence-backed completed items `done`.
11. Perform memory writeback when the current Codex memory contract permits it. Never save secrets or transient details.
12. On the final planned Workstep, update `documentation-trace.md`, the durable project documentation, and print `DOCUMENTATION_TRACE` before DONE.
13. Print `SUPERGOAL_PHASE_DONE`, update the Workstep row, requirement statuses, current phase, last checkpoint, and notable events in `STATE.md`.
14. If the user sent a new instruction, incorporate it, update `requirement-contract.md`, repair the remaining plan, and continue. Pause only on explicit pause/stop.
15. Continue to the next Workstep or the final audit.

## Requirement coverage checks

At each Workstep boundary verify:

- every referenced `REQ-*` exists in `requirement-contract.md`;
- every completed requirement has passing mapped criteria and evidence;
- no plan edit removed a requirement, weakened its invariant, or orphaned final verification;
- coverage remains 100%;
- imported pending work remains mapped or explicitly excluded by the user.

A coverage regression is a planning defect. Repair it before advancing.

## Autonomous recovery ladder

For a failed criterion, command, deliverable, or audit check:

1. **Root-cause diagnosis:** classify the failure as command, approach, environment, authority, or logical impossibility; record evidence in `STATE.md` and print `FAILURE_PROBE`.
2. **Mechanical repair and retry:** fix configuration, dependency, typo, ordering, flaky setup, or invalid command classification, then rerun the exact gate.
3. **Independent approach:** attempt a technically distinct implementation that preserves all requirements.
4. **Focused fix spec:** write `phases/phase-N.fix.md`, target only the failed gate, execute it, and rerun the original verification.
5. **Workstep rebuild:** redesign the current Workstep while preserving its requirement IDs and deliverables.
6. **Dependent replan:** update later Worksteps, dependencies, roadmap, state table, and specs; rerun plan integrity and validators.
7. **Full scope-preserving redesign:** rebuild remaining work from `requirement-contract.md`; verify 100% coverage and rerun preconditions.
8. **Genuine blocker assessment:** stop only if no safe authorized path remains.

Do not use a fixed command-attempt count as proof of blockage. Print `FAILURE_ESCALATE` when moving between recovery levels. Emit `FAILURE_HANDOFF` only after all applicable levels are exhausted.

When genuinely blocked:

- set `Status` and `Lifecycle state` to `GENUINELY_BLOCKED`;
- preserve the exact blocking condition, recovery history, and evidence;
- call native `update_goal({status: "blocked"})` only after the same condition has repeated for at least three consecutive Goal turns;
- otherwise keep the Goal active and continue any meaningful recovery available.

## Final audit

After the last Workstep, set lifecycle state to `FINAL_AUDIT`. Audit against the original roadmap and requirement contract, not Workstep self-reports.

For each audit round:

1. Print `AUDIT_START` with Workstep, requirement, criterion, and command counts.
2. Re-read `ROADMAP.md` and `requirement-contract.md`.
3. Verify 100% requirement mapping and evidence.
4. Verify one `SUPERGOAL_PHASE_DONE` per Workstep.
5. Re-run deduplicated mandatory build, typecheck, lint, and test commands. A lint baseline may remain red only when run-touched files add no new or changed errors and all other gates pass; report it as `pre-existing`, never green.
6. Spot-check every deterministic criterion. Mark non-repeatable visual/manual evidence `trust-prior-verify` honestly.
7. For each path-like deliverable, run:

   ```bash
   bash {{RUN_ROOT}}/repo-state.sh deliverable <baseline-ref> "<path>"
   ```

8. Verify every required deferred item is `done` or explicitly excluded by the user.
9. Verify `documentation-trace.md` and its durable target or concrete not-applicable reason.
10. Verify `recallant-status.md` has project-specific evidence and a valid closeout route or evidence-backed allowed skip.
11. Print `AUDIT_VERIFY`.

If gaps exist, print `AUDIT_GAPS` and apply the recovery ladder. Create `phases/audit-fix-<round>.md` for focused gaps, but do not stop after three rounds if a higher recovery level remains. Continue while evidence or the integrity fingerprint improves. Emit `AUDIT_HANDOFF` only after full scope-preserving redesign fails and a genuine blocker is established.

If clean, print `AUDIT_COMPLETE`, update requirement coverage and final audit status in `STATE.md`, and proceed to closeout.

## Documentation trace

The final Workstep must update an existing canonical project document such as `PROJECT_LOG.md`, `CHANGELOG.md`, `README.md`, a runbook, or an existing status file. If none exists in a git repository, create a concise `PROJECT_LOG.md` only when that is consistent with repository conventions.

Use `not applicable` only with a concrete reason. Do not place the only documentation evidence inside ignored `.supergoal` artifacts. Keep private data, secrets, and raw transcripts out of durable docs. Use `Project Phase` and `Workstep` unambiguously.

## Safe auto-commit checkpoint

Run after `AUDIT_COMPLETE` and before Recallant closeout.

1. Set `Auto-commit status: running` and print `AUTO_COMMIT_START`.
2. If no git repository exists, record and print `AUTO_COMMIT_SKIPPED: no git repo`.
3. Save final `git status --porcelain=v1 -uall` to `final-status.txt`.
4. If no changes exist, record and print `AUTO_COMMIT_SKIPPED: no changes`.
5. Compare with `baseline-status.txt`. Do not stage unrelated pre-existing dirty paths.
6. Do not stage ignored/generated runtime artifacts under `.supergoal` unless tracked before the run or explicitly deliverable.
7. Stage only run-produced deliverables and run `git diff --cached --check`.
8. If no safe staged changes remain, record and print `AUTO_COMMIT_SKIPPED: no safe staged changes` with evidence.
9. Commit with a scoped message including run root, baseline, Workstep count, and audit status.
10. On success, print `AUTO_COMMIT_COMPLETE`, save the commit SHA, and update `STATE.md`.
11. For mechanical commit failure, diagnose and retry with an appropriate recovery level. Emit `AUTO_COMMIT_HANDOFF` only for persistent unsafe ambiguity or a genuine git blocker after recovery.

## Recallant closeout

Run after auto-commit complete or an allowed skip.

1. Read `recallant-status.md`.
2. Compute `supergoal:<run_id>:final:<commit_sha_or_no_commit>`.
3. Build the closeout payload with run, roadmap, state, requirement coverage, Worksteps, final audit, commit/skip, documentation, command results, open questions, next step, and artifact references.
4. If project connection is `no` or `unknown`, write `recallant-closeout.md` and print an evidence-backed skipped `RECALLANT_CLOSEOUT`.
5. If connected and capability is verified, prefer callable MCP `memory_closeout`; use CLI `recallant agent-closeout` only when the CLI proves the required active session exists.
6. Do not attach, onboard, or connect the project automatically. Do not create a separate final memory instead of canonical closeout.
7. If capability is proven unavailable, record an evidence-backed skipped closeout; this is not a release blocker.
8. If verified capability fails, apply mechanical and transport recovery. Emit `RECALLANT_HANDOFF` only when the verified closeout remains impossible.
9. Persist every returned readiness field and warning in `recallant-closeout.md` and `STATE.md`.

## Project Phase footer

When `phase-position.md` exists, print `PHASE_POSITION` after Recallant closeout and before completion. Otherwise record `Project Phase footer: not-applicable`.

## Native Goal completion

After all gates pass:

1. Confirm requirement coverage is 100%.
2. Confirm no required deferred item is pending or `needs-user-decision`.
3. Confirm final audit passed.
4. Confirm documentation trace passed.
5. Confirm auto-commit completed or has an allowed evidence-backed skip.
6. Confirm Recallant closeout completed or has an allowed evidence-backed skip.
7. Confirm optional Project Phase footer handling.
8. Set `Status: COMPLETE`, `Lifecycle state: COMPLETE`, and `Last verified checkpoint: all completion gates passed`.
9. Print `SUPERGOAL_RUN_COMPLETE`.
10. Call native `update_goal({status: "complete"})`.
11. Record `Native Goal closeout status: complete` and the tool result in `STATE.md` when possible; always surface it in the transcript.

If native closeout fails, preserve the completed gate evidence and record `Native Goal closeout status: stale — closeout call failed`. A later Supergoal can then reconcile it as `STALE_COMPLETE` without repeating product work.

## Required formats

Use `{{RUN_ROOT}}/GOAL_FORMAT.md` for:

- `GOAL_RECONCILIATION`;
- Workstep START/VERIFY/DONE blocks;
- memory and documentation blocks;
- audit and recovery blocks;
- auto-commit and Recallant blocks;
- `PHASE_POSITION`;
- `SUPERGOAL_RUN_COMPLETE`.
