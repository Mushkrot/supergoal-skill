# Workstep Design — slicing work that auto-chains cleanly

Terminology note: this reference used to call internal slices "phases." In user-visible summaries, ROADMAP/STATE content, transcript prose, durable project docs, and Recallant closeout reports, call these internal units **Worksteps**. Reserve **Project Phase** for phases from a user's/source project roadmap.

The goal of Workstep decomposition: hand the executor a sequence of **independently verifiable** units of work that compose into the full task. Done well, each Workstep has a clear "this is finished" signal and the next Workstep can start without re-reading the user's intent.

## How many Worksteps?

**Whatever the task actually needs.** Workstep count is derived, not chosen. There is no fixed range and no upper cap. Use these as loose orientation, not rules:

- **2 Worksteps** — small change with a meaningful Polish & Harden pass at the end (one screen + harden; one API route + harden). Below this, you don't need Supergoal — just do the work.
- **3–4 Worksteps** — small features, single-surface changes (one screen, one API route, one migration with tests).
- **5–7 Worksteps** — typical features (foundation + core + integration + states/edges + polish, with a fork or two).
- **8–12 Worksteps** — large features, full-stack greenfield apps, complex refactors that need a safety-net + staged migration.
- **13+ Worksteps** — major migrations, multi-system rewrites, brownfield untangles. Don't combine just to hit a target number; combining hides dependencies.

**Two tests for whether you have the right count:**

1. **Each Workstep is independently verifiable.** It builds, typechecks, lints, and tests on its own; you could ship it as a partial increment. If a Workstep only makes sense once the next one is also done, merge them.
2. **Each Workstep delivers one coherent thing.** If you can't write its name in five words without using "and", you're packing two Worksteps into one — split.

If you find yourself counting Worksteps and trying to stay in some range, you're optimizing the wrong thing. Derive the count from the work; let it be 4 if that's right, 14 if that's right.

## Workstep shapes that work

### The standard 5-Workstep shape (feature work)

1. **Foundation** — types, schemas, migrations, scaffolding. Builds but doesn't ship behavior.
2. **Core mechanic** — the central thing the feature does, working for the golden path.
3. **Integration** — wire into existing surfaces (routes, navigation, auth checks, etc.).
4. **States & edges** — loading, empty, error, unauthorized, offline; edge inputs.
5. **Polish & Harden** — copy, a11y, perf, security review, regression sweep, final QA.

### Brownfield refactor shape

1. **Safety net** — add characterization tests if coverage is thin.
2. **Extract** — pull out the abstractions you want without changing behavior.
3. **Migrate** — move callers to the new shape, one cluster at a time.
4. **Delete** — remove the old code.
5. **Polish & Harden** — final sweep.

### UI redesign shape

1. **Tokens & primitives** — design tokens, base components.
2. **Layout** — page shells, navigation, responsive grid.
3. **Content surfaces** — the actual screens, in order of prominence.
4. **Interactions** — animations, micro-interactions, state transitions.
5. **Polish & Harden** — a11y, contrast, copy, dark mode, motion-reduced, edge widths.

## Acceptance criteria — the test of a good Workstep

Each Workstep's acceptance criteria should be:

- **Observable in the transcript** — "build succeeds" is good; "feels right" is not
- **Atomic** — one fact per criterion
- **Falsifiable** — you can say yes or no, not "kind of"
- **Tied to commands or evidence** — `npm test` output, a file existing, a screenshot diff

Bad: "User authentication works."
Good:
- `npm run build` succeeds with 0 errors
- `npm run typecheck` succeeds with 0 errors
- Tests in `tests/auth/*.test.ts` pass
- `/api/auth/signin` returns 200 for valid credentials and 401 for invalid
- `<SignInForm/>` renders without console errors
- Authenticated middleware rejects requests without a session cookie

## Cleanliness (grep-checked at VERIFY)

Every Workstep's VERIFY block reports three grep-based counts against the complete set of added/new lines since the baseline — `bash <run-root>/repo-state.sh added-lines <Baseline ref>` (includes uncommitted + untracked work, not just committed; see `repo-state-comparison.md`):

- **Debug prints added** — `console.log`/`console.error` for JS/TS, `print(`/`pprint(` for Python, `print(`/`dump(` for Swift, `fmt.Println`/`log.Println` for Go (adjust per stack).
- **Session TODO/FIXME added** — `\b(TODO|FIXME|XXX)\b` introduced in this run's diff (not pre-existing).
- **Dead imports added** — new `import` statements with no usage in the same file.

Any unexplained non-zero count is treated like a failed acceptance criterion and enters the autonomous recovery ladder. If a Workstep legitimately needs to ship debug output (for example, a Workstep building a debug overlay or logging integration), declare it in the Workstep spec with:

```
Cleanliness override: debug prints allowed (this Workstep ships <component>)
```

The override is read by the executor at VERIFY time and counts are reported but not failed. Keep overrides narrow — they're a release valve, not a default.

## Mandatory commands

Every Workstep must include the engineering commands the agent has to run and surface output for:

```
- pnpm build          (must exit 0)
- pnpm typecheck      (must exit 0)
- pnpm lint           (must exit 0, or only pre-existing warnings)
- pnpm test           (must exit 0, or pre-existing failures proven unrelated)
```

Adjust per stack. For iOS: `xcodebuild`, `swiftlint`, `swift test`. For Python: `uv run pytest`, `ruff check`, `mypy`.

If a command produces too much output to surface, require a **summary line** ("Tests: 47 passed, 0 failed") plus saving the full output to a file.

## Evidence required

For each Workstep, list what the agent must print into the conversation to prove completion. The evaluator only sees the transcript. Common evidence types:

- **Command output excerpts** — last 10 lines of the test run, build summary
- **File listings** — `ls -la` of the new files created, with sizes
- **Diff snippets** — key changes inline, not full diffs
- **Screenshots** — for UI Worksteps, paths to screenshots saved during execution
- **API responses** — `curl -X POST ... | jq` outputs for new endpoints
- **STATE.md update** — the new content of the Workstep's row

## Dependencies

State them explicitly. Workstep 4 depends on Worksteps 1, 2 and 3 — not "the previous ones". This lets you reason about whether mid-chain interruption breaks the next Workstep.

Almost always linear (1 → 2 → 3 → 4 → 5). True parallel Worksteps are rare in a single-session goal chain; if you find yourself wanting them, you probably want sub-tasks within a Workstep, not a parallel Workstep.

## Deferred work and unlock conditions

If a user-requested item cannot be executed in the Workstep where it first appears because a file, surface, route, schema, dependency, or credential does not exist yet, do not drop it and do not ask the user by default. Move it to the first Workstep where the prerequisite exists, or record it in `<run-root>/deferred-work.md` with:

- The original source Project Phase/request or Workstep
- The blocker
- The concrete unlock condition
- The target Workstep
- The evidence required to mark it done

Deferred work is still scope. The final audit fails if a required deferred item remains pending after its unlock condition and target Workstep have passed.

## Command gating

Mandatory commands should be classified during planning:

- `baseline-safe` — valid before Workstep 1 starts; eligible for Stage 6.5 pre-flight
- `requires-phase-N` — compatibility label meaning valid only after Workstep N creates/configures prerequisites
- `external/env` — depends on credentials, device/simulator, production services, paid APIs, or other non-local systems

Do not let pre-flight fail on a command that needs future artifacts. That is an ordering/classification bug; repair the Workstep graph instead.

## The Polish & Harden Workstep — non-negotiable

Always the last Workstep. Its job: catch what the earlier Worksteps missed because they were focused on shipping behavior. Required sub-passes:

1. **UX & copy** — every visible string reads well, no debug placeholders, no Lorem ipsum
2. **States** — empty, loading, error, unauthorized states verified for every new surface
3. **Edges** — empty inputs, very long inputs, special characters, slow networks (where applicable)
4. **Security** — input validation, auth checks, no secrets in client bundles, no obvious injection surfaces
5. **A11y** (UI) — keyboard navigation, focus states, screen reader labels, contrast
6. **Perf** — no obvious N+1 queries, no megabyte client bundles, no blocking renders
7. **Diff review** — final `git diff` reviewed for stray debug logs, commented-out code, TODOs from this session
8. **Regression sweep** — re-run the full test suite; manually exercise one or two adjacent features

This is where "every aspect is perfect" gets enforced. Without this Workstep, Supergoal is just a multi-step planner.
