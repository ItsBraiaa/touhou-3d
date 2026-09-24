# F16-00 plan-and-orchestration

Status: done
Type: docs
Owner: Astra
Lane: sol
Depends on: F3-04, F7-02
Parallel-safe: no

## Read first

- [Spec](../spec.md): product rules, exact widget paths, data shapes and proposed APIs.
- [Execution plan](../../../docs/engineering/controls-expansion-plan.md): ownership, task steps and review focus.
- docs/engineering/SPRINT.md in the worktree: no-new-tests rule and lane loop.

## Goal

Write a complete design and implementation handoff for Astra and Claude; do not implement production behavior.

## Files

- .scratch/controls-expansion/spec.md
- .scratch/controls-expansion/CLAUDE_KICKOFF.md
- .scratch/controls-expansion/issues/*.md
- docs/engineering/controls-expansion-plan.md
- docs/engineering/ROADMAP.md
- docs/engineering/README.md
- docs/HANDOFF_LOG.md

Also update this ticket's Outcome, only its own docs/engineering/ROADMAP.md row, and append a newest-first docs/HANDOFF_LOG.md entry. New production scripts/assets include their generated .uid/.import sidecars. No files outside this boundary without first coordinating the owner and recording the expansion.

## Work

- [x] Inspect the landed settings, camera, menus, invulnerability and lane contracts.
- [x] Record the user's dash-invulnerability choice and exact initial tuning; separate authored layout from wiring.
- [x] Write F16-01 through F16-07 with file boundaries and dependencies; provide Claude's orchestration kickoff.
- [x] Self-review scope, action/widget/API names, device recovery, protection ordering and no-new-tests compliance.

## Manual acceptance / existing gate

- All requested features map to tickets; every named ticket and local document link exists.
- No runtime scene, script, setting or test changes in this planning commit.
- Existing lane gate after commit; failures remain explicit in the final handoff.

Write no new tests or disposable test drivers. Run the existing tools/lane.ps1 land gate after the scoped commit. A static/headless result does not certify physical device feel. Failures belong in Outcome and the handoff; never bypass the gate.

## Outcome

Spec, execution plan, seven implementation tickets and Claude kickoff authored. Implementation tickets remain todo. Landing evidence is reported at session completion.
