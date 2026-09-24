# F16-04 mouse-camera-and-recenter

Status: todo
Type: adapter
Owner: Claude
Lane: path
Depends on: F16-02
Parallel-safe: yes, only within the orchestration plan's disjoint file boundaries

## Read first

- [Spec](../spec.md): product rules, exact widget paths, data shapes and proposed APIs.
- [Execution plan](../../../docs/engineering/controls-expansion-plan.md): ownership, task steps and review focus.
- docs/engineering/SPRINT.md in the worktree: no-new-tests rule and lane loop.

## Goal

Implement mouse orbit and recenter in CameraRig without touching trunk-owned settings/Session/scenes.

## Files

- scripts/player/camera_rig.gd
- docs/engineering/player-flight.md (F16 camera section only)
- docs/validation/controls-expansion.md (camera adapter observations only)

Also update this ticket's Outcome, only its own docs/engineering/ROADMAP.md row, and append a newest-first docs/HANDOFF_LOG.md entry. New production scripts/assets include their generated .uid/.import sidecars. No files outside this boundary without first coordinating the owner and recording the expansion.

## Work

- [ ] Keep apply_settings compatibility; add the spec's request_recenter and apply_control_settings plus set_mouse_capture_active and clear_pending_look lifecycle methods.
- [ ] Accumulate only active captured mouse motion, apply once without frame-delta scaling, and preserve rate-based keyboard/stick input and zero roll.
- [ ] Implement locked manual-look override with 0.25 s idle return; preserve Target Lock.
- [ ] Implement shortest-yaw 0.25 s free/locked recenter; manual look interrupts, repeated requests never queue, obstruction wins.

## Manual acceptance / existing gate

- Inspect mouse motion at different render rates and with vertical inversion; no stale jump after clearing pending input.
- Recenter from both yaw-wrap sides and both pitch limits; preserve valid lock and obstacle clearance.
- Default Teclas and existing follow offsets behave as before.
- Exercise adapter using existing editor/arena capabilities; record unexercised Session lifecycle as pending F16-06, not passed.

Write no new tests or disposable test drivers. Run the existing tools/lane.ps1 land gate after the scoped commit. A static/headless result does not certify physical device feel. Failures belong in Outcome and the handoff; never bypass the gate.

## Outcome

Not started. Can overlap F16-03 and F16-05 because it edits no Interface, Settings, Session, PlayerController or player_ship.tscn.
