# F16-04 mouse-camera-and-recenter

Status: done
Type: adapter
Owner: Claude
Lane: path
Depends on: F16-00
Parallel-safe: yes, only within the orchestration plan's disjoint file boundaries

## Read first

- [Spec](../spec.md): product rules, exact widget paths, data shapes and proposed APIs.
- [Execution plan](../../../docs/engineering/controls-expansion-plan.md): ownership, task steps and review focus.
- docs/engineering/SPRINT.md in the worktree: no-new-tests rule and lane loop.

## Routing (2026-09-24, Claude)

- **Starts now, without waiting for F16-02.** The rig takes its values only through `apply_control_settings(...)` and `request_recenter()`; nothing in this ticket reads Settings or InputBindings. The `camera_recenter` action already exists (F16-02 part 1), but the rig does not read it: F16-06 wires it.
- **Docs:** fill only the pre-made player-flight.md section "F16 mouse camera and recenter (F16-04)" and the F16-04 section of `docs/validation/controls-expansion.md`.

## Goal

Implement mouse orbit and recenter in CameraRig without touching trunk-owned settings/Session/scenes.

## Files

- scripts/player/camera_rig.gd
- docs/engineering/player-flight.md (F16 camera section only)
- docs/validation/controls-expansion.md (camera adapter observations only)

Also update this ticket's Outcome, only its own docs/engineering/ROADMAP.md row, and append a newest-first docs/HANDOFF_LOG.md entry. New production scripts/assets include their generated .uid/.import sidecars. No files outside this boundary without first coordinating the owner and recording the expansion.

## Work

- [x] Keep apply_settings compatibility; add the spec's request_recenter and apply_control_settings plus set_mouse_capture_active and clear_pending_look lifecycle methods.
- [x] Accumulate only active captured mouse motion, apply once without frame-delta scaling, and preserve rate-based keyboard/stick input and zero roll.
- [x] Implement locked manual-look override with 0.25 s idle return; preserve Target Lock.
- [x] Implement shortest-yaw 0.25 s free/locked recenter; manual look interrupts, repeated requests never queue, obstruction wins.

## Manual acceptance / existing gate

- Inspect mouse motion at different render rates and with vertical inversion; no stale jump after clearing pending input.
- Recenter from both yaw-wrap sides and both pitch limits; preserve valid lock and obstacle clearance.
- Default Teclas and existing follow offsets behave as before.
- Exercise adapter using existing editor/arena capabilities; record unexercised Session lifecycle as pending F16-06, not passed.

Write no new tests or disposable test drivers. Run the existing tools/lane.ps1 land gate after the scoped commit. A static/headless result does not certify physical device feel. Failures belong in Outcome and the handoff; never bypass the gate.

## Outcome

Done 2026-09-24 in lane path. Only `scripts/player/camera_rig.gd` changed; no Interface, Settings, Session, PlayerController or player_ship.tscn edits.

- **API.** `apply_control_settings(p_mode, p_mouse_sensitivity, p_mouse_invert, p_deadzone)`, `set_mouse_capture_active(active)`, `clear_pending_look()` and `request_recenter()`, plus the constants `MODE_KEYS` and `MODE_MOUSE`. `apply_settings` is unchanged and now covers the `camera_*` actions only.
- **New exports.** They use the spec defaults:
  - `stick_deadzone` 0.2;
  - `camera_input_mode` keys;
  - `mouse_sensitivity` 0.12 degrees per pixel;
  - `mouse_invert_vertical` false;
  - `mouse_look_hold_seconds` 0.25;
  - `recenter_seconds` 0.25;
  - `mouse_jitter_speed` 60 px/s and `recenter_grace_seconds` 0.1, Claude's proposals.
- **Mouse.** Motion is collected in `_input` from `screen_relative`, which the window stretch does not scale. It is spent once per physics tick as pixels × degrees, with no delta.
- **Locked look.** Deliberate mouse motion turns the lock pull off. After 0.25 s idle the pull fades back in at `lock_blend_speed`. The lock is kept.
- **Recenter.** It lasts 0.25 s, eased with smoothstep, and takes the shortest yaw path with `lerp_angle`. After a 0.1 s grace it is interrupted by the actions or by deliberate mouse motion, and a repeat restarts it from the current pose. The lock pull does not run during it, so there is one writer.
- **Review fixes.**
  - Deliberate mouse motion is now judged by speed over the real time since the previous tick, not by pixels per tick, so the jitter-or-look split no longer moves with the frame rate. `mouse_jitter_pixels` 1.0 became `mouse_jitter_speed` 60 px/s, the same split at 60 Hz.
  - The first 0.1 s of a recenter drops camera input instead of interrupting, so the Mouse 3 click or R3 press that asked for it cannot cancel it.
- **Decision.** In mouse mode the `camera_*` actions, arrow keys included, still orbit. They share the right stick's actions, and the bindings belong to the player.
- **Verification.** The existing suite passed (225 tests, 0 failed), and so did the strict resource check. Everything else was checked by reading: yaw wrap, pitch limits, lock preservation and obstruction. It is recorded in `docs/validation/controls-expansion.md` (F16-04).
- **Pending F16-06, not passed:** the Session lifecycle, meaning capture, focus and Resume, settings at spawn and Retry, and the `camera_recenter` wiring.
- **Not verified:** physical mouse and stick feel, including rotation that steps at the 60 Hz tick on high-refresh displays, and whether the 0.1 s grace covers a real wheel click with its release (F16-07).
- **Gate:** `tools/lane.ps1 land` runs on the review-fix commit.
