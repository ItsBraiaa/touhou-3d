# F16-07 controls-visual-and-device-acceptance

Status: todo
Type: design+acceptance
Owner: Astra; Claude coordinates code fixes
Lane: sol
Depends on: F16-06
Parallel-safe: no

## Read first

- [Spec](../spec.md): product rules, exact widget paths, data shapes and proposed APIs.
- [Execution plan](../../../docs/engineering/controls-expansion-plan.md): ownership, task steps and review focus.
- docs/engineering/SPRINT.md in the worktree: no-new-tests rule and lane loop.

## Goal

Approve the integrated screen and dash presentation with honest physical-device evidence.

## Files

- scenes/ui/controls.tscn (layout/materials only; preserve integrated wiring)
- scenes/ui/components/binding_row.tscn (visuals only)
- scenes/ui/components/dash_cooldown.tscn (visuals only)
- scenes/player/visuals/dash_visual.tscn (visuals only)
- assets/ui/controls/* (visual corrections)
- assets/vfx/dash/* (visual corrections)
- docs/validation/controls-expansion.md (final acceptance matrix)
- docs/engineering/player-flight.md (accepted tuning and limitations only)

Also update this ticket's Outcome, only its own docs/engineering/ROADMAP.md row, and append a newest-first docs/HANDOFF_LOG.md entry. New production scripts/assets include their generated .uid/.import sidecars. No files outside this boundary without first coordinating the owner and recording the expansion.

## Work

- [ ] Inspect all spec-defined visual states at 1280×720, 1600×900 and 1920×1080, including long binding names, scrolling and modal focus.
- [ ] Walk keyboard/mouse and each available Xbox/DualShock/DualSense device: rebind, save/relaunch, menus, capture drift, conflict, rollback, unplug and pointer recovery.
- [ ] Judge mouse/free/locked recenter, dash left/right under Focus, wall behavior, live-bullet protection/Graze and cooldown readability.
- [ ] Record each case with actual hardware/backend and pass/fail/not-verified. Send engineering failures with reproduction to Claude in the owning lane; do not repair scripts or trunk wiring yourself.
- [ ] Record final numeric tuning requests and whether each was applied; update all F16 implementation rows only after their owners have landed.

## Manual acceptance / existing gate

- All spec acceptance branches have a result and evidence, including unavailable-device limitations.
- No fully-passed claim based on simulated input or a static mockup.
- Known blockers get a named owner and reproduction; visual acceptance is not marked done with unresolved gameplay failures.
- No change to pinned base_speed/focus_multiplier/follow offsets; trunk implements any approved dash numeric change.

Write no new tests or disposable test drivers. Run the existing tools/lane.ps1 land gate after the scoped commit. A static/headless result does not certify physical device feel. Failures belong in Outcome and the handoff; never bypass the gate.

## Outcome

Not started. Claude supplies engineering follow-ups and final convergence; no automatic export or package replacement.
