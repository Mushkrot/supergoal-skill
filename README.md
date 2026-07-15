# Supergoal for Codex — Autonomous Fork

> One task in. A verified result out. No `Start now`, no plan-approval ping-pong,
> and no clipboard relay race with a hand-written `/goal` command.

This is my Codex-focused fork of
[Supergoal](https://github.com/cskwork/supergoal-skill), created by
[cskwork](https://github.com/cskwork). The original project, name, and core idea
belong to the upstream author; the original MIT license and copyright notice are
preserved.

This fork is maintained by [Mushkrot](https://github.com/Mushkrot) for developers
who trust Codex with end-to-end delivery and do not want to babysit every step of
the process. Give it the objective, let it work, come back for the result. Codex
should not need emotional support between Worksteps.

This is an official GitHub fork, but it is an independent derivative and is not
an official release of the upstream project or OpenAI.

## What is different here?

The upstream project is a broad, portable agent workflow. This fork takes a more
opinionated, Codex-native direction: maximum practical autonomy with the native
Codex Goal lifecycle doing the long-running execution.

On the normal path, Supergoal:

1. captures every requirement and turns it into measurable acceptance criteria;
2. reconciles stale or apparently active native Goals before starting another;
3. inspects the real repository and prepares a dependency-aware Workstep plan;
4. repairs planning and pre-flight red flags automatically without reducing
   scope, weakening tests, or quietly redefining success;
5. calls Codex's native `create_goal` tool directly;
6. executes, verifies, recovers from failures, and completes the final audit;
7. closes the native Goal only after the evidence says the task is actually done.

There is no routine plan-approval pause, no separate `Start now` message, and no
need to copy a generated `/goal` command back into the same chat. If native Goal
dispatch is unavailable, Supergoal prepares that command as an emergency
fallback instead of pretending everything is fine.

## Is this a replacement for Codex `/goal`?

For everyday use, yes: invoke Supergoal instead of manually preparing and
launching `/goal`.

Under the hood, it does **not** replace the native Goal engine. It orchestrates
that engine through `create_goal`, adds planning, automatic repair, stale-state
reconciliation, verification, and closeout, and removes the human relay work.
Think of native Goal as the engine and this Supergoal as the driver who already
knows the route and does not ask you to approve every turn.

## Autonomous does not mean reckless

The fork is intentionally hands-off, but it is not "YOLO mode." It must not make
a red flag disappear by deleting requirements, skipping tests, weakening
security, or lowering the requested quality bar. It asks for help only when a
genuine blocker remains, such as unavailable credentials, missing authority for
an irreversible external action, incompatible requirements, or a platform/policy
restriction that the agent cannot resolve safely.

## Install

Clone one canonical checkout and link it into Codex:

```bash
git clone https://github.com/Mushkrot/supergoal-skill.git ~/supergoal-skill
mkdir -p ~/.codex/skills
ln -s ~/supergoal-skill ~/.codex/skills/supergoal
```

If `~/.codex/skills/supergoal` already exists, preserve that installation before
replacing it with the symlink. Do not overwrite local edits blindly.

The same approach works on a local server running Codex: clone the repository on
that server and link the checkout into the server user's Codex skills directory.

To update later:

```bash
cd ~/supergoal-skill
git pull --ff-only
```

## Use

```text
/supergoal <the complete task you want delivered>
```

You can also invoke `$supergoal` in Codex surfaces that use skill mentions.

Examples:

```text
/supergoal Add SSO to this application, migrate the existing users, test the
full login flow, update the documentation, and do not stop until it is verified.

/supergoal Diagnose and fix the intermittent checkout failure. Preserve current
behavior, add regression coverage, and ship the complete verified result.
```

## Repository layout

```text
SKILL.md       Core autonomous workflow and native Goal orchestration
agents/        Codex skill metadata
references/    Planning, Workstep, Goal-format, and repository-state rules
scripts/       Deterministic discovery, validation, run-claim, and audit helpers
templates/     Durable run state, protocol, requirement, and closeout templates
```

## Upstream and attribution

- Original project: [cskwork/supergoal-skill](https://github.com/cskwork/supergoal-skill)
- Original author: [cskwork](https://github.com/cskwork)
- Autonomous Codex fork: [Mushkrot/supergoal-skill](https://github.com/Mushkrot/supergoal-skill)
- License: MIT; see [LICENSE](LICENSE)

Upstream changes are reviewed deliberately because this fork has a different
execution contract. A blind merge could reintroduce the very approval loops this
version exists to remove — and nobody wants to babysit the babysitting remover.
