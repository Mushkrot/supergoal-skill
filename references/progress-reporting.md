# Progress reporting

Use this reference when planning a Supergoal run, updating its Worksteps, emitting operator progress, reconciling an old run, or recovering from a reporting failure.

## Contents

1. [Platform boundary](#platform-boundary)
2. [Progress model](#progress-model)
3. [Durable state](#durable-state)
4. [ETA and confidence](#eta-and-confidence)
5. [Cadence](#cadence)
6. [Lifecycle integration](#lifecycle-integration)
7. [Plan changes and migration](#plan-changes-and-migration)
8. [Rendering contract](#rendering-contract)
9. [Failure behavior](#failure-behavior)

## Platform boundary

The native Codex Goal row owns Goal status, its timer, and pause/resume/edit/clear controls. The supported Goal tools do not expose custom percentage, ETA, Workstep, or card-rendering fields. Do not patch Codex, call private UI APIs, emit ANSI/HTML color hacks, or claim that Supergoal modifies that row.

Emit progress as compact Markdown in the current task. Keep the progress snapshot independent of the renderer so a future supported native metadata adapter can consume the same state. Chat output remains the fallback.

## Progress model

Report two complementary measurements:

- `completed Worksteps / total Worksteps` for an immediate structural count;
- evidence-backed weighted percentage for the amount of verified work.

During planning, assign each Workstep:

- effort points from `1, 2, 3, 5, 8, 13`;
- a planned low/high duration range in minutes;
- one to five stable milestone IDs whose points sum exactly to the Workstep effort;
- one falsifiable evidence condition per milestone.

A milestone becomes `done` only after its evidence exists. Do not award points for agent confidence, elapsed time, code volume, or an unverified claim that work is nearly finished.

```text
weighted_percent = 100 * done_milestone_points / total_workstep_effort_points
```

Round only the displayed percentage. Keep calculations at full precision. A fully completed Workstep requires all of its milestone points and separate Workstep completion evidence.

## Durable state

Use `<run-root>/progress.tsv` as the machine-readable source of truth. Keep `<run-root>/progress-history.tsv` append-only. Mirror only the latest readable snapshot and important progress events into `STATE.md`; do not parse free-form `STATE.md` for normal calculations.

The schema is tab-separated:

```text
meta      <key> <value>
workstep  <id> <status> <effort> <min_minutes> <max_minutes> <started_epoch> <completed_epoch> <paused_at_start> <paused_at_complete> <name>
milestone <id> <workstep_id> <points> <status> <evidence_ref>
```

Required metadata:

- `schema_version=1`
- `run_started_epoch`
- `last_report_epoch`
- `last_signature`
- `plan_revision`
- `previous_total_worksteps`
- `mode`
- `mode_started_epoch`
- `paused_seconds`
- `stable_completions`
- `last_replan_reason`

Allowed Workstep states are `pending`, `active`, and `done`. Allowed milestone states are `pending` and `done`. Allowed modes are `planning`, `active`, `recovering`, `waiting`, `auditing`, `blocked`, and `complete`.

Normalize tabs, CR/LF, and control characters in names and evidence before writing. Mutate state by writing a same-directory temporary file, validating it, and atomically renaming it. Never partially overwrite the canonical file.

Use `SUPERGOAL_PROGRESS_NOW=<epoch>` only for deterministic tests. Production uses `date +%s`.

## ETA and confidence

ETA is a range, never an exact promise.

Before observed completions, sum the remaining planned low/high ranges and use pace factor `1.0` with `low` confidence. For the active Workstep, multiply the range by its remaining milestone-point fraction.

For each completed Workstep with a positive planned midpoint, calculate:

```text
ratio = actual_active_minutes / planned_midpoint_minutes
```

Exclude confirmed waiting time by recording cumulative paused seconds at Workstep start and completion. Recovery remains active work and therefore affects observed pace.

- With one usable ratio, blend it with the prior: `(1.0 + ratio) / 2`.
- With two or more ratios, use the median.
- Multiply the remaining planned range by this pace factor.
- If no positive remaining ranges exist, report `ETA unavailable`.
- In `waiting`, `blocked`, or invalid state, report `ETA unavailable`.

Confidence:

- `low`: less than 20% of effort is verified, fewer than two usable completions, or the plan/recovery calibration is unstable;
- `medium`: 20–60% verified, at least two usable completions, and at least two stable completions since the last replan/recovery transition;
- `high`: more than 60% verified, at least three usable completions, and at least three stable completions;
- `unavailable`: ETA cannot be bounded honestly.

Entering `recovering` or applying `replan` resets stable completions. Each later completed Workstep increments it.

Show wall elapsed from run creation. Use active elapsed for pace calibration. If confirmed pause time is material, the renderer may include active elapsed in the third line.

## Cadence

Force a snapshot at these boundaries:

1. repaired plan initialized and native Goal dispatched;
2. each Workstep completed;
3. entering recovery, successful recovery, and replan;
4. final audit start and completion;
5. genuine blocker and complete run.

At every return of control to the agent, run a non-forced `snapshot`. Emit immediately when its material signature changed. Otherwise suppress duplicates until the adaptive heartbeat:

- remaining ETA high bound up to 2 hours: 15 minutes;
- more than 2 and up to 8 hours: 30 minutes;
- more than 8 hours or unavailable: 60 minutes.

Maximum active silence is 60 minutes. Before a potentially long command, persist a checkpoint. Prefer yielded/pollable execution so the agent regains control at least every 60 seconds, checks the heartbeat, and only writes chat when the reporting interval is due. Do not replay missed heartbeats after application suspension; emit one fresh snapshot on resume.

The material signature includes rounded percentage, completed/total count, mode, plan revision, ETA bucket, and current Workstep. A changed signature bypasses duplicate suppression.

## Lifecycle integration

After Stage 5.5 produces a clean repaired plan:

1. render `progress.tsv` from `templates/progress.tsv` and the roadmap;
2. validate it with `progress.sh init <run-root>`;
3. continue pre-flight;
4. after successful native Goal dispatch, set mode `active` and force event `goal-dispatched`.

In the Workstep loop:

1. call `workstep-start` before the START block;
2. call `milestone-done` only with an evidence reference;
3. call `workstep-done` only after every milestone is verified;
4. force event `workstep-done` and then continue automatically;
5. run non-forced `snapshot` whenever control returns.

Set modes at recovery, waiting, audit, blocker, and completion transitions. Progress output is informational and never asks whether to continue.

If a structural plan change occurs, use `replan` before continuing. During stale Goal reconciliation, inspect progress state together with existing run artifacts; it is evidence, not sole proof of completion.

## Plan changes and migration

Every split, merge, resequence, added Workstep, removed explicitly excluded Workstep, or effort-range change increments `plan_revision`. Record the previous and current Workstep counts. The next forced report must show the count change and a short reason.

Carry verified points by stable milestone ID and its mapped Requirement/Acceptance Criterion evidence, never by Workstep ordinal. A replacement plan may move an existing milestone to another Workstep. Do not copy completion onto a new milestone merely because its name is similar. Validate that each new Workstep's milestone points equal its effort.

Percentage may decrease after an honest replan. Never clamp it upward or hide the changed denominator.

For an old run without `progress.tsv`, `init` may migrate the Workstep table in `STATE.md`:

- create plan revision 1;
- assign one point and one `LEGACY-<id>` milestone to each detected Workstep;
- mark only fully completed/done Worksteps and milestones done;
- leave all incomplete Worksteps at zero partial points;
- use ETA unavailable because old plans have no duration ranges;
- record a migration event in history and `STATE.md`.

## Rendering contract

Normal output is at most three Markdown lines:

```markdown
**🟦 SUPERGOAL PROGRESS**
**███████░░░ 68%** · **6/9 Worksteps** · ⏱ **4h 12m** · ETA **2–4h** *(medium)*
Now: **W07 — Integration hardening** · Plan rev **2** · **active**
```

Use a ten-cell Unicode bar and bold text. State markers must remain understandable without color:

- `🟦 active` or `planning`;
- `🟨 recovering` or `waiting`;
- `🟥 blocked` only for a genuine blocker;
- `🟩 complete`.

Normalize and truncate only the displayed Workstep name; preserve the durable value. On replan, the third line may replace the normal status with `Plan rev 2: 8 → 10 Worksteps — <reason>`.

## Failure behavior

Progress reporting is not a completion gate. If the state is absent, corrupt, unsupported, or cannot be updated:

1. print a diagnostic to stderr or the recovery log;
2. print a compact fallback with any trustworthy Workstep count and wall elapsed available;
3. show `ETA unavailable` and `low`/`unavailable` confidence;
4. continue the product task and its normal verification;
5. repair or reconstruct progress at the next safe boundary.

Never set the native Goal blocked only because progress reporting failed.
