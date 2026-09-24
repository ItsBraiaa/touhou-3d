# F16-06 session-camera-and-controls-integration

Status: done
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

- [x] Apply saved camera mode/sensitivity/inversion/deadzone at every spawn and while paused; preserve existing settings behavior.
- [x] Drive cursor capture from active gameplay, release on every menu/focus-loss/disconnect/unload route, pause on focus loss, and clear stale deltas/held-action state before resume.
- [x] Connect recenter action and locked framing without bypassing input-capture modal ownership.
- [x] Verify main and pause caller focus, global defaults, pending-application rollback, device prompt policy and signals after repeated Retry/Restart. (By reading; the human walkthrough is owed to F16-07.)
- [x] Update current contracts and gameplay controls docs so their old exclusions no longer contradict shipped F16 behavior.

## Manual acceptance / existing gate

- Open Controls from main menu and Pause, change mouse mode/recenter/dash/menu bindings, Apply/Back/Resume; no unintended gameplay.
- Alt-tab/focus loss and unplug controller in gameplay and profile confirmation; pointer is usable and rollback/recovery works.
- Retry/Restart and Campaign Stage 2 keep settings but reset transient dash state.
- Recenter near scenery, with lock and while mouse input arrives; no roll/clipping regressions.
- Run the existing lane land gate and record the exact integrated revision for Astra.

Write no new tests or disposable test drivers. Run the existing tools/lane.ps1 land gate after the scoped commit. A static/headless result does not certify physical device feel. Failures belong in Outcome and the handoff; never bypass the gate.

## Outcome

Done 2026-09-24 by lane trunk, one commit, after F16-03, F16-04 and F16-05 had landed. `main.tscn`, `player_ship.tscn`, `project.godot`, `settings.gd`, `menu_controller.gd`, `input_device_state.gd` and `options_screen.gd` needed no change. `interface.gd`, `controls_screen.gd` and `camera_rig.gd` changed in doc comments only.

- **Camera values.** `GameSession._apply_camera_settings` now also calls `CameraRig.apply_control_settings(mode, mouse sensitivity, mouse inversion, deadzone)`. It runs at every spawn (so a Retry's new rig gets the saved mode) and on `Settings.changed` for any of the six camera keys (`CAMERA_SETTING_KEYS`), over Pause too, through F3-04's one connection.
- **Pointer.** The Session is the only writer of `Input.mouse_mode`. It captures only while the player flies in Mouse mode: a ship, the HUD on top, the tree running. Every other state shows it. The decision is made in `_set_paused`, `_show_hud`, `_unload_stage`, on a mode change and on a focus loss, never per frame. Each one opens or closes the rig's gate. A capture also drops the pending look once more on the first physics tick after the next input flush (the capture warp). `_exit_tree` shows the pointer.
- **Focus.** `NOTIFICATION_APPLICATION_FOCUS_OUT` or `WM_WINDOW_FOCUS_OUT` pauses a stage in play; in a beat or under a menu it only shows the pointer. Focus-in does nothing. Held keys are released by the engine with the focus.
- **Disconnect.** It is covered by F3-03's injected pause. In Teclado mode an unplug does not pause, and the capture stays.
- **Recenter.** A `camera_recenter` press event in `GameSession._unhandled_input` calls `request_recenter()` only while flying, never in a beat. The Controls capture and the menus consume their events first.
- **Resume guard (F16-05's question).** It is decided on the resume side. `PlayerController` ignores both dash actions from its spawn and from each `set_controls_enabled(true)` until a tick with both released, so a dash remapped to B cannot fire on the Back that resumes from Pause. The capture rules are unchanged, and any binding stays allowed.
- **Callers.** Main menu and Pause → Options → Controls → back, global Defaults, the confirmation rollback, the prompt policy and the connection counts were checked by reading. Nothing needed changing.
- **Not done.** No HUD key hint (PLANEJAMENTO's little-text HUD; `hud.*` is not in the Files list). `Targeting` polls `lock_target` and `next_target` the same way and is unguarded (outside the Files list). The spec API list additions F16-05 asked for were not made, because `spec.md` is outside the Files list.
- **Docs.** GUIDE Sections 5, 6, 7 and 14 (the new "Controls screen (F16)" subsection). PLANEJAMENTO Sections 3, 4 (new "Lateral dash (Impulso)"), 7 and 8. settings.md: Purpose, Public contract, new "F16 Session integration" and Open issues. player-flight.md: new "F16 Session integration". The validation record's F16-06 section, with the 16-step human walkthrough and the integrated revision for F16-07.

Verification: no tests or drivers (F16 rule). `tools/test.ps1` passed 225, 0 failed, with no script, parse or compile error. The 300-frame headless boot was clean, and `check_resources --strict-validate` failed nothing (85 resources, 86 scripts). The headless display server has no mouse mode and no focus events, so the new paths were checked by reading. `tools/lane.ps1 land` was not run in this stage; the orchestrator runs it.
