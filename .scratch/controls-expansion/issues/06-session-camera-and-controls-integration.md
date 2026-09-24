# F16-06 session-camera-and-controls-integration

Status: todo
Type: integration
Owner: Claude
Lane: trunk
Depends on: F16-03, F16-04, F16-05
Parallel-safe: no

## Read first

- [Spec](../spec.md): product rules, exact widget paths, data shapes and proposed APIs.
- [Execution plan](../../../docs/engineering/controls-expansion-plan.md): ownership, task steps and review focus.
- docs/engineering/SPRINT.md in the worktree: no-new-tests rule and lane loop.

## Goal

Join new controls, camera and dash through the real main/pause/settings lifecycle.

## Files

- scripts/session/game_session.gd
- scripts/ui/interface.gd
- scripts/ui/options_screen.gd
- scripts/ui/controls_screen.gd
- scripts/ui/menu_controller.gd
- scripts/ui/input_device_state.gd
- scripts/settings/settings.gd (integration corrections only)
- scripts/player/camera_rig.gd (integration corrections after path landed)
- scripts/player/player_controller.gd (integration corrections only)
- scenes/main.tscn (only required references)
- scenes/player/player_ship.tscn (only required references/values)
- project.godot (final action defaults only)
- docs/GUIDE.md (new UI/action/adapter contracts)
- docs/PLANEJAMENTO.md (controls and dash rules)
- docs/engineering/settings.md
- docs/engineering/player-flight.md
- docs/validation/controls-expansion.md (integrated walkthrough)

Also update this ticket's Outcome, only its own docs/engineering/ROADMAP.md row, and append a newest-first docs/HANDOFF_LOG.md entry. New production scripts/assets include their generated .uid/.import sidecars. No files outside this boundary without first coordinating the owner and recording the expansion.

## Work

- [ ] Apply saved camera mode/sensitivity/inversion/deadzone at every spawn and while paused; preserve existing settings behavior.
- [ ] Drive cursor capture from active gameplay, release on every menu/focus-loss/disconnect/unload route, pause on focus loss, and clear stale deltas/held-action state before resume.
- [ ] Connect recenter action and locked framing without bypassing input-capture modal ownership.
- [ ] Verify main and pause caller focus, global defaults, pending-application rollback, device prompt policy and signals after repeated Retry/Restart.
- [ ] Update current contracts and gameplay controls docs so their old exclusions no longer contradict shipped F16 behavior.

## Manual acceptance / existing gate

- Open Controls from main menu and Pause, change mouse mode/recenter/dash/menu bindings, Apply/Back/Resume; no unintended gameplay.
- Alt-tab/focus loss and unplug controller in gameplay and profile confirmation; pointer is usable and rollback/recovery works.
- Retry/Restart and Campaign Stage 2 keep settings but reset transient dash state.
- Recenter near scenery, with lock and while mouse input arrives; no roll/clipping regressions.
- Run the existing lane land gate and record the exact integrated revision for Astra.

Write no new tests or disposable test drivers. Run the existing tools/lane.ps1 land gate after the scoped commit. A static/headless result does not certify physical device feel. Failures belong in Outcome and the handoff; never bypass the gate.

## Outcome

Not started. Starts only after 03/04/05 landed; path and sol must not be editing these runtime files. F16-05 in lane rescue hands `game_session.gd`, `player_controller.gd`, `hud.*` and `player_ship.tscn` back to trunk when its part 2 lands (routing, 2026-09-24).
