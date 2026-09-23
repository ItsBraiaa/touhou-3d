# F4-02 HUD binding and target marker

Status: todo
Type: adapter
parallel-safe: no
Depends on: F4-01, F2-04
Lane: trunk

## Goal

`scripts/ui/hud.gd` becomes the `Hud` adapter: it observes the Session's `CombatState` and renders GUIDE Section 15's player panel, and it projects a target marker from `Targeting.target_changed`, hidden when there is no lock or the target is behind the camera. The HUD never changes a combat value (ENGINEERING_BRIEF 4.I "Key boundary"). The Session gains its one `CombatState`, starts it at every stage entry, pauses it with the tree, and binds the HUD to each new ship. After this ticket a Run from the main menu shows real entry values: 100 %, Shield, two Bombs, Power Level 1, or 2 for a Direct Stage 2.

## Read first

- `docs/GUIDE.md` Section 15 (paths, authored states, binding duties) and Section 7 rows "Combat state changed" and "Target changed"
- `docs/PLANEJAMENTO.md` Section 7 "HUD" (little text, essential numbers, no score or Graze on the HUD)
- `docs/engineering/combat-hud.md` "CombatState contract" (the real API: `start`, the change signals, the getters)
- `docs/engineering/menus-session.md` "GameSession contract" and "Interface contract"
- `scripts/session/game_session.gd` (`_start_run`, `_restart_stage`, `_load_stage`, `_unload_stage`, `_set_paused`), `scripts/ui/interface.gd` (`get_hud`), `scripts/player/targeting.gd` (`target_changed`, `get_current_target`, `HIT_VOLUME_PATH`)
- `scenes/ui/hud.tscn` (read only: root `HUD` full-rect Control, `PlayerStatus/*`, `TargetMarker`)

## Files

- **Creates:** `tests/scene/test_hud_contract.gd`.
- **Edits:** `scripts/ui/hud.gd` (replace Astra's placeholder with `class_name Hud extends Control`); `scripts/ui/interface.gd` (`_hud: Hud`, `get_hud() -> Hud`, refuse a `hud_scene` whose root is not a `Hud` with `push_error`); `scripts/session/game_session.gd` (`_combat_state`, `get_combat_state()`, `start()` at stage entry, `set_paused()`, HUD bind and unbind); `tests/scene/test_game_session_flow.gd` (new cases below); `tests/scene/test_interface_contract.gd` only if the retype breaks it; `scenes/dev/arena_harness.gd` and `scenes/dev/arena_harness.tscn` (add a `HudLayer` CanvasLayer with an instance of `scenes/ui/hud.tscn`, bound to a new harness-owned `_combat_state`, which F6-03 later reuses for the weapon).
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F4 rows), `docs/HANDOFF_LOG.md` (one entry), `docs/engineering/combat-hud.md` ("Hud contract" section), `docs/GUIDE.md` Section 6 `scripts/ui/hud.gd` row and the GUIDE Section 7 "Combat state changed" row.
- **Must not touch:** `scenes/ui/hud.tscn` and every other `scenes/ui/*.tscn` (Astra's), `scripts/combat/combat_state.gd` (F4-01 is done; a needed change is a note, not an edit), `tools/validate_hud_handoff.gd` (Astra's), `scenes/tests/hud_preview.tscn`.
- **Conflicts with:** F4-03 (`hud.gd`, `test_hud_contract.gd`), F6-02, F6-03, F7-01, F7-02 (`game_session.gd`, `test_game_session_flow.gd`), F6-02 and F6-03 (`arena_harness.*`). All are serialized: none is parallel-safe.

## Deliverables

### `Hud` (`scripts/ui/hud.gd`)

- Constants for the Section 15 paths (`PlayerStatus/HealthBar`, `HealthValue`, `Shield`, `Bomb1`, `Bomb2`, `PowerValue`, `PowerProgress`, `TargetMarker`), resolved in `_ready`; a missing one is reported with `push_error` naming the path, and the HUD disables its processing (CONVENTIONS "Setup errors are loud").
- Exports `lit_modulate: Color = Color(1, 1, 1, 1)` and `dim_modulate: Color = Color(1, 1, 1, 0.25)` (Claude's proposal, Astra tunes) for the Shield and Bomb icons.
- `bind(combat_state: CombatState, targeting: Targeting, camera: Camera3D)`: calls `unbind()` first, connects `health_changed`, `shield_changed`, `bombs_changed`, `power_changed` and `targeting.target_changed`, then renders the current values from the getters and `targeting.get_current_target()`. Binding twice never double-connects.
- `unbind()`: disconnects everything `bind` connected, drops the three references, hides `TargetMarker`. Safe when not bound.
- Rendering: `HealthBar.value` = Health; `HealthValue.text` = `"%d%%"`; `Shield.modulate` lit when shielded, dim otherwise; `Bomb1` lit at 1 or more Bombs, `Bomb2` at 2; `PowerValue.text` = the level; `PowerProgress.value` = Power Progress, and at `CombatState.MAX_POWER_LEVEL` the bar is full (`max_value`), since progress is always 0 there (Claude's reading of "handle maximum power according to design"; noted in Open issues).
- Target marker, in `_process`: the point is the target's `HitVolume` global position (as `Targeting` measures it), else the target's own. Shown only while bound, the target `is_instance_valid`, and `not camera.is_position_behind(point)`; its center sits on `camera.unproject_position(point)` (position minus half its size). Otherwise hidden. `target_changed(null)` hides it at once.
- The HUD calls no `CombatState` method except the getters.

### `GameSession` (`scripts/session/game_session.gd`)

- `var _combat_state := CombatState.new()`, one for the Session's lifetime, and `get_combat_state() -> CombatState` for tests and dev tools, like `get_run_state()`.
- `_start_run`: after `_run_state.start(...)`, `_combat_state.start(_run_state.starting_power_level())`. `_restart_stage`: the same after `_run_state.restart_stage()`.
- `_set_paused(paused)`: also `_combat_state.set_paused(paused)`.
- `_load_stage`, after the ship is set up: `interface.get_hud().bind(_combat_state, _player.targeting, _player.camera_rig.camera)`. `_unload_stage`: `interface.get_hud().unbind()` before freeing the ship.
- No `CombatState` signal is connected here yet; F7-01 connects them once in `_ready`.

### Dev harness

`scenes/dev/arena_harness.tscn` gains `HudLayer` (CanvasLayer) with the HUD instance; `arena_harness.gd` exports `hud: Hud`, creates `var _combat_state := CombatState.new()`, calls `start(1)` and `hud.bind(_combat_state, _player.targeting, _player.camera_rig.camera)`.

## Tests required

`tests/scene/test_hud_contract.gd` (instances `scenes/ui/hud.tscn`, a `CombatState`, `Targeting.new()` driven by emitting `target_changed` directly, a `Camera3D` and a target `Node3D` with a `HitVolume` child in a test `Node3D`):

- `test_hud_root_is_a_hud_with_every_section_15_path`
- `test_bind_renders_the_current_values`: after `start(2)`, `PowerValue` is `"2"`, Health 100 and `"100%"`, Shield and both Bombs lit.
- `test_hits_and_bombs_update_the_panel`: `take_hit()` dims the Shield, `tick(CombatState.HIT_INVULNERABILITY)` then `take_hit()` shows 90 % and `"90%"`, a Bomb via `update_bomb_input(false)` then `(true)` dims `Bomb2`.
- `test_power_progress_and_the_full_bar_at_max_level`
- `test_rebinding_never_double_connects` (each signal has one connection to the HUD after two binds)
- `test_unbind_disconnects_and_hides_the_marker`
- `test_hud_never_changes_the_combat_state` (ENGINEERING_BRIEF 4.I): `capture()` and every getter are unchanged after bind, signals and 10 frames.
- `test_marker_centers_on_the_projected_target`, `test_marker_hides_behind_the_camera`, `test_marker_hides_on_release_and_when_the_target_is_freed`

`tests/scene/test_game_session_flow.gd`, new: `test_a_run_starts_the_combat_state_and_binds_the_hud` (Direct Stage 2 gives Power Level 2 on the HUD), `test_pause_pauses_the_combat_state`, `test_restart_rebinds_the_hud_to_the_new_ship`, `test_return_to_menu_unbinds_the_hud`.

Grep the test output for `SCRIPT ERROR`: a runtime error after an assertion still reports PASS.

## Out of scope

Boss panel, attack cue and threats (F4-03); anything that changes `CombatState` (F7); invulnerability flicker (F7-01); screen-edge markers for off-screen targets (the marker simply hides; F4-03's threats cover off-screen warnings); layout or visual changes to `hud.tscn`.

## Definition of Done

- `tools/test.ps1` green with no `SCRIPT ERROR`; the named tests above exist; no Error-level warnings.
- Verified with `/run`: the dev arena harness shows the bound HUD, and locking each of the three targets with `K` puts the marker on it; orbiting the camera away until the target is behind hides it. A headless pass of the harness first, then windowed (windowed validation can hang). Record in `docs/validation/combat-hud.md` with one screenshot `docs/validation/combat-hud-marker.png`.
- `docs/engineering/combat-hud.md` gains the "Hud contract" (exports, methods, what it observes, Open issues); GUIDE Section 6 `hud.gd` row complete; handoff log entry; ticket `Status: done` with an Outcome section; roadmap row.
- One commit: `ui: [shared] bind the HUD to CombatState and Targeting`.

## Handoff notes for Astra

`hud.tscn` is not edited. The binding depends on every Section 15 path under `PlayerStatus` and on `TargetMarker`: renaming one needs a matching code change. `dim_modulate` (alpha 0.25) and the full Power bar at level 3 are Claude's proposals; tune `dim_modulate` in the Inspector on the HUD root, or say if level 3 should read differently.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/combat-hud/issues/02-hud-binding-and-target-marker.md, then implement that ticket. Use /run to verify the bound HUD and the target marker in the dev arena harness. Finish with its Definition of Done and commit.
```
