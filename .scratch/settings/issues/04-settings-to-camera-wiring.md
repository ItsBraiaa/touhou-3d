# F3-04 Settings to camera wiring

Status: done
Type: integration
parallel-safe: no
Depends on: F10-03, F3-02
Lane: path (part 1 and part 2; part 2 moved from trunk on 2026-09-24)
Model: part 1 Claude Opus 5.5, solo (lane path); part 2 Claude Opus 5.5, solo

> **Split (SPRINT.md):**
> - **Part 1, lane path** (after F3-02 and F3-03): the windowed F3 pass, `docs/validation/settings.md` and its screenshots. No code edits. Commit with `(F3-04 part 1)`.
> - **Part 2, lane trunk** (after F10-03, F3-02 and part 1): the Session additions. It closes the ticket.

## Goal

The ship's camera uses the player's settings. The Session applies camera sensitivity and invert vertical through `CameraRig.apply_settings()` at two moments:

- **At spawn.** Every ship is made in F10-03's `_spawn_player()`: Start, Direct Stage, Restart, Retry and the Campaign continuation. It gets the values before its first physics tick.
- **On change.** Options changes either value, even with Options opened from Pause, and the live rig gets it at once.

This ticket also runs the feature's windowed pass for F3-02 and F3-03, whose lane cannot use `/run`.

## Read first

- `.scratch/settings/spec.md` "Cross-feature contracts". `docs/engineering/settings.md`: `Interface.get_settings()`, `Settings.changed`, `get_camera_sensitivity()`, `get_invert_vertical()` and the key constants.
- `scripts/player/camera_rig.gd`: `apply_settings(p_sensitivity, p_invert_vertical)` only stores the values. `scripts/player/player_controller.gd`: `camera_rig: CameraRig`.
- `scripts/session/game_session.gd` as F10-03 left it: `_ready`, `_spawn_player(at)` and `_load_stage`.
- `docs/engineering/menus-session.md` "Pause". Options opened from Pause keeps the tree paused, and `Interface` processes while paused.

## Files

- **Creates:** `tests/scene/test_settings_camera_wiring.gd`, `docs/validation/settings.md`, `docs/validation/settings-1600x900.png`, `docs/validation/settings-fullscreen.png`.
- **Edits:** `scripts/session/game_session.gd`:
  - **`_ready`:** after the existing connections, `interface.get_settings().changed.connect(_on_setting_changed)`, once for the Session's life. It is skipped when `get_settings()` is null, because `Interface` disabled itself and has reported why.
  - **`_apply_camera_settings()`:** returns when there is no `_player` or no settings. Otherwise it calls `_player.camera_rig.apply_settings(settings.get_camera_sensitivity(), settings.get_invert_vertical())`.
  - **`_spawn_player(at)`:** calls `_apply_camera_settings()` right after `setup(_flight_volume)`.
  - **`_on_setting_changed(key: StringName, _value: Variant)`:** calls `_apply_camera_settings()` for `Settings.CAMERA_SENSITIVITY` and `Settings.INVERT_VERTICAL` only.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F3-04 row, and F3 marked done when 01 to 03 are done.
  - `docs/HANDOFF_LOG.md`: one entry.
  - `docs/engineering/settings.md`: a "Camera wiring" section, with Open issues updated from the windowed pass.
  - `docs/GUIDE.md`: the Section 6 rows `game_session.gd` and `camera_rig.gd` ("`apply_settings()` for F3" becomes "called by the Session at spawn and on change").
- **Must not touch:**
  - `settings.gd`, `options_screen.gd`, `input_device_state.gd`, `interface.gd` and `menu_controller.gd` (the glm-b F3 files; a gap is a note).
  - `camera_rig.gd`, `player_controller.gd` and `scenes/player/player_ship.tscn`: no scene change is needed.
  - `tests/scene/test_game_session_flow.gd`: the new cases have their own file.
- **Conflicts with:** `game_session.gd`: F10-03 comes before, through Depends on. F11-01, F11-02, F12-03 and F13-03 come after, in trunk order.

## Deliverables

- **The Session's four additions above**, and nothing else in `game_session.gd`. The connection is made once in `_ready`, never per stage (CONVENTIONS "Every connection is made in exactly one place"), so Restart and Retry never double-connect.
- **Ordering.** The rig gets the values after `setup()` and before any physics tick, so the first frame of flight already orbits at the saved rate.
- **While paused.** `apply_settings` only stores, so an application while paused is safe. The new values take effect on the first tick after Resume.

## Tests required

`tests/scene/test_settings_camera_wiring.gd` runs on `main.tscn`, with `Interface.settings_path` set to `"user://test_settings_%d.cfg" % OS.get_process_id()` before `add_child`. The file is seeded with sensitivity 1.5 and invert true, and deleted before and after each test.

- `test_a_new_ship_gets_the_saved_camera_settings`: Direct Stage 1 gives a rig with `sensitivity` 1.5 and `invert_vertical` true.
- `test_options_from_the_main_menu_reach_the_first_ship`: set the Sensitivity slider to 0.5 before starting.
- `test_options_opened_from_pause_update_the_live_rig`: set the slider to 0.5 and switch the toggle off. The rig reads 0.5 and false while the tree is paused, and still does after Back and Resume.
- `test_restart_and_retry_ships_keep_the_current_settings`: after a Restart, and after a Retry from CP1-A (use F10-03's `test_retry_restart_flow.gd` approach), the new rig has the current values.
- `test_other_settings_leave_the_rig_alone`: set the rig to 0.77 by hand, then change Master volume. It still reads 0.77.
- `test_the_settings_signal_is_connected_once`: after three Restarts, `changed` has one connection to the Session.

## Out of scope

- Any change to how the rig uses the two values; F1-03's contract test covers that.
- Mouse camera, which is not in this delivery.
- The glm-b F3 files.

## Definition of Done

- `tools/test.ps1` is green, and its output has no `SCRIPT ERROR` line. The named tests above exist. No Error-level warnings.
- **`/run`, headless first, then windowed.** Windowed runs can hang. It covers the whole feature:
  - Options from the main menu: Tela cheia and back; 1600 × 900 and 1920 × 1080 in Janela with the layout intact (the two screenshots above).
  - Volumes, checked by `AudioServer` readback, because the game is silent until F13-03.
  - Quit and relaunch: the values persist.
  - Sensitivity 2.0 against 0.2 is visibly different, and invert flips `camera_up`.
  - Options from Pause applies with the game paused.

  Record it in `docs/validation/settings.md`, naming what is owed to a person: the physical keyboard and DualSense pass, and a real controller unplug in flight.
- Module doc, GUIDE rows, handoff log, `Status: done` with an Outcome, ROADMAP row.
- One commit: `session: apply camera settings to every ship`. Then run the trunk land step from `docs/engineering/SPRINT.md`.

## Handoff notes for Astra

`CameraRig.sensitivity` and `invert_vertical` in `player_ship.tscn` are now overwritten by the player's settings at every spawn. Tune the orbit rate with `orbit_speed_degrees` instead.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/SPRINT.md, docs/engineering/ROADMAP.md and .scratch/settings/issues/04-settings-to-camera-wiring.md, then implement that ticket and verify it with /run. Finish with its Definition of Done and commit.
```

## Outcome (2026-09-24)

Both parts delivered solo in lane path: part 1 (`30affad`, the windowed F3 pass) and part 2, which moved here from trunk on 2026-09-24 and closes the ticket. Part 2 added the four Session members the ticket lists to `scripts/session/game_session.gd`, and nothing else there: `_connect_camera_settings()` (one call in `_ready`, so the `_ready` addition is a single line), `_apply_camera_settings()`, one call in `_spawn_player` after `setup`, and `_on_setting_changed()`. The contract is in `docs/engineering/settings.md` "Camera wiring".

- **No new tests** (sprint rule): `tests/scene/test_settings_camera_wiring.gd` was not created. A throwaway headless script ran the ticket's six named cases instead (16 checks, all passed): the saved file reaches a new ship, main-menu Options reach the first ship, Options from Pause update the live rig while paused and after Resume, Restart and Retry from CP1-A (a Snapshot injected into the Director's store) keep the current values, Master volume leaves the rig alone, and three Restarts keep one `changed` connection. It measured the orbit too: 0.4189 rad at 2.0, 0.0419 at 0.2 and −0.4189 at 2.0 inverted over six ticks of `camera_up`. A short windowed run showed the same. Recorded in `docs/validation/settings.md` "Camera wiring".
- **Owed to a person:** the physical keyboard and DualSense pass, including the orbit at a saved sensitivity, and a real controller unplug in flight.
- **Shared-file note:** `game_session.gd` is a trunk file, edited here by the 2026-09-24 exception in the path queue. Every addition is in its own function with a one-line call site; the second lander merges both.
