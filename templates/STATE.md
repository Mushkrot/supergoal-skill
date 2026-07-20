# State: {{TASK_TITLE}}

**Status:** REQUESTED
**Lifecycle state:** REQUESTED
**Current phase:** —    <!-- compatibility field; display as Current workstep -->
**Started:** {{DATE}}
**Last update:** {{DATE}}
**Run root:** {{RUN_ROOT}}

## Native Goal lifecycle

- Native Goal status: none
- Goal dispatch method: pending    <!-- native | slash-fallback | pending -->
- Goal objective: —
- Goal reconciliation result: NO_ACTIVE_GOAL
- Native Goal closeout status: pending
- Last verified checkpoint: requested

## Repository baseline

- Baseline ref: {{BASELINE_SHA}}
- Baseline dirty paths: {{BASELINE_DIRTY_COUNT}}
- Final checkpoint commit: —

## Completion gates

- Requirement coverage: pending
- Final audit status: pending
- Documentation trace: pending
- Auto-commit status: pending
- Recallant connected: —
- Recallant closeout status: pending
- Required deferred work: pending
- Project Phase footer: not-applicable

## Project Phase position

- Requested project phase: —
- Total project phases: —
- Next project phase: —

## Plan integrity status

- Integrity rounds: {{INTEGRITY_ROUNDS}}
- Integrity fingerprint: —
- Red flags found: {{INTEGRITY_FLAGS_FOUND}}
- Auto-repaired: {{INTEGRITY_AUTO_REPAIRED}}
- Full-plan rebuilds: 0
- Deferred into later worksteps: {{INTEGRITY_DEFERRED}}
- Genuine blockers: 0

## Requirement status

| Requirement | Worksteps | Criteria | Final verification | Status |
|---|---|---|---|---|
| REQ-001 | {{REQ_001_WORKSTEPS}} | {{REQ_001_CRITERIA}} | {{REQ_001_VERIFY}} | pending |

## Deferred work status

- Pending: {{DEFERRED_PENDING}}
- Done: {{DEFERRED_DONE}}
- Needs user decision: {{DEFERRED_NEEDS_USER_DECISION}}
- Out of scope by explicit user decision: {{DEFERRED_OUT_OF_SCOPE}}

## Workstep progress

| # | Workstep | Effort | Requirements | Status | Started | Completed | Notes |
|---|---|---:|---|---|---|---|---|
| 1 | {{P1_NAME}} | {{P1_EFFORT}} | {{P1_REQUIREMENTS}} | pending | — | — | — |
| 2 | {{P2_NAME}} | {{P2_EFFORT}} | {{P2_REQUIREMENTS}} | pending | — | — | — |
| ... | ... | ... | ... | pending | — | — | — |
| N | Polish & Harden | {{PN_EFFORT}} | {{PN_REQUIREMENTS}} | pending | — | — | — |

## Progress snapshot

- Schema version: 1
- Plan revision: 1
- Previous / current Worksteps: {{N}} / {{N}}
- Weighted progress: 0%
- Completed Worksteps: 0 / {{N}}
- Wall / active elapsed: 0m / 0m
- ETA range: {{ETA_INITIAL_RANGE}}
- Confidence: low
- Mode: planning
- Current Workstep: —
- Last progress report: —
- Progress state: {{RUN_ROOT}}/progress.tsv
- Progress history: {{RUN_ROOT}}/progress-history.tsv

## Engineering check status

- Build: —
- Typecheck: —
- Lint: —
- Tests: —

## Notable events

- {{DATE}} — Run requested.

## Failure and recovery log

Record every recovery level, evidence, and result. A command failure is not itself a blocker.

- {{DATE}} — none
