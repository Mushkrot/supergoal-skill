# Roadmap: {{TASK_TITLE}}

**Task:** {{ONE_LINE_TASK}}
**Type:** {{TAGS}}
**Created:** {{DATE}}
**Total worksteps:** {{N}}
**Total effort points:** {{TOTAL_EFFORT_POINTS}}
**Requirement contract:** {{RUN_ROOT}}/requirement-contract.md

## Context summary

- **Stack:** {{STACK}}
- **Package manager:** {{PM}}
- **Build / test / lint:** {{COMMANDS}}
- **Risky areas:** {{RISKS_ONE_LINE}}

## Autonomous decisions

These decisions were inferred from the request, repository, durable context, and safest reversible defaults. They do not require plan approval.

- {{ASSUMPTION_1}}
- {{ASSUMPTION_2}}

## Top risks

1. **{{RISK_1}}** — likelihood: {{L}}; mitigation: {{M}}
2. **{{RISK_2}}** — likelihood: {{L}}; mitigation: {{M}}
3. **{{RISK_3}}** — likelihood: {{L}}; mitigation: {{M}}

## Requirement coverage

Every required row must map to at least one Workstep criterion and one final verification. Plan repair must keep coverage at 100%.

| Requirement | Source | Worksteps | Acceptance criteria | Final verification | Status |
|---|---|---|---|---|---|
| REQ-001 | {{REQ_001_SOURCE}} | {{REQ_001_WORKSTEPS}} | {{REQ_001_CRITERIA}} | {{REQ_001_VERIFY}} | planned |

## Plan integrity repair

- **Rounds:** {{INTEGRITY_ROUNDS}}
- **Flags found:** {{INTEGRITY_FLAGS_FOUND}}
- **Auto-repaired:** {{INTEGRITY_AUTO_REPAIRED}}
- **Full-plan rebuilds:** {{INTEGRITY_REBUILDS}}
- **Deferred into later worksteps:** {{INTEGRITY_DEFERRED}}
- **Genuine blockers:** {{INTEGRITY_BLOCKERS}}

## Deferred work

| Item | Requirement | Source | Blocked by | Unlock condition | Target workstep | Status |
|---|---|---|---|---|---|---|
| {{DEFERRED_ITEM}} | {{DEFERRED_REQ}} | {{SOURCE}} | {{BLOCKER}} | {{UNLOCK_CONDITION}} | {{TARGET_WORKSTEP}} | pending |

## Documentation and Recallant

- **Documentation target:** {{DOC_TARGET}}
- **Recallant connected:** {{RECALLANT_CONNECTED}}
- **Recallant closeout:** {{RECALLANT_CLOSEOUT_PLAN}}

## Workstep map

| # | Workstep | Effort | Planned range | Requirements | Depends on | Deliverable |
|---|---|---:|---:|---|---|---|
| 1 | {{P1_NAME}} | {{P1_EFFORT}} | {{P1_MIN}}–{{P1_MAX}} min | {{P1_REQUIREMENTS}} | — | {{P1_DELIVERABLE}} |
| 2 | {{P2_NAME}} | {{P2_EFFORT}} | {{P2_MIN}}–{{P2_MAX}} min | {{P2_REQUIREMENTS}} | 1 | {{P2_DELIVERABLE}} |
| ... | ... | ... | ... | ... | ... | ... |
| N | Polish & Harden | {{PN_EFFORT}} | {{PN_MIN}}–{{PN_MAX}} min | {{PN_REQUIREMENTS}} | 1..N-1 | All requirements verified |

## Progress milestones

Milestone points must sum to the Effort points of their Workstep. Mark a milestone done only when its evidence condition is satisfied.

| ID | Workstep | Points | Evidence condition |
|---|---:|---:|---|
| M1.1 | 1 | {{M1_1_POINTS}} | {{M1_1_EVIDENCE}} |

## Workstep 1 — {{P1_NAME}}

**Why:** {{P1_WHY}}

**Requirements:** {{P1_REQUIREMENTS}}

**Effort points:** {{P1_EFFORT}}

**Planned duration:** {{P1_MIN}}–{{P1_MAX}} minutes

**Deliverables:**
- {{P1_FILE_OR_FEATURE_1}}
- {{P1_FILE_OR_FEATURE_2}}

**Acceptance criteria:**
- [ ] AC-1.1 [{{P1_REQ_1}}] {{CRIT_1}}
- [ ] AC-1.2 [{{P1_REQ_2}}] {{CRIT_2}}

**Mandatory commands:**
- `{{CMD_1}}`
- `{{CMD_2}}`

**Evidence required:**
- {{EVIDENCE_1}}
- {{EVIDENCE_2}}

**Dependencies:** none

## Workstep N — Polish & Harden

Verify applicable UX/copy, states, edges, security, accessibility, performance, documentation trace, memory/Recallant closeout preparation, diff cleanliness, full regression, requirement coverage, and required deferred work. Re-run all mandatory commands and produce evidence for every remaining requirement.
