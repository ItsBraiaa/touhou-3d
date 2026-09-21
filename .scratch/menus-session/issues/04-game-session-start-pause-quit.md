# F2-04 GameSession: start, pause, quit

Status: todo
Type: integration
parallel-safe: no
Depends on: F1-04, F2-02, F2-03

## Goal

`game_session.gd` becomes the real composition root: it reacts to menu actions, starts a Campaign or Direct Stage by instancing the stage and the player under `WorldRoot`, ticks `RunState`, handles pause (tree paused, overlay shown, timers frozen), resume, restart, return to menu, and quit. After this ticket the player can fly through the static Stage 1 from the main menu on keyboard and gamepad.

## Read first

- `docs/adr/0002-single-composition-root-without-autoloads.md`
- `docs/GUIDE.md` Section 5 "Main composition", Section 7 rows "Pause requested" and "Player defeated", Section 14 (which button does what)
- `docs/STAGE_01_HANDOFF.md` "Open and integrate" and "Spatial contract" (`PlayerStart`, flight interior X -45..45, Y up to 75, route -Z)
- `.scratch/menus-session/issues/01`, `02`, `03` and `.scratch/player-flight/issues/02` (`PlayerController.setup(bounds)`)
- `docs/engineering/CONVENTIONS.md`: "Time and randomness" (pause freezes Active Time), "Architecture rules"

## Deliverables

`scripts/session/game_session.gd`, `class_name GameSession extends Node` (extends the F0-03 skeleton).

### Exports

`world_root: Node3D`, `projectile_root: Node3D`, `interface: Interface`, `audio: Node` (all required), `player_scene: PackedScene` (player_ship), `stage_scenes: Dictionary` mapping `&"stage_01"` and `&"stage_02"` to `PackedScene` (stage_02 may be null for now and is reported as unavailable, not crashed).

### Behavior

- `_ready`: validate, create `RunState`, connect `interface.action_requested`, connect `RunState` signals, `interface.show_home(MAIN_MENU)`.
- Actions: `start_campaign` (mode CAMPAIGN, stage_01), `start_direct_stage` (mode DIRECT_STAGE, payload stage), `open_stage_select`, `open_options`, `open_controls`, `open_credits`, `quit` (`get_tree().quit()`), `resume`, `restart_stage`, `return_to_menu`, `back_refused` (ignored on the main menu).
- Start: `_unload_stage()` if any; instance the stage under `world_root`; instance the player under `world_root`, place it at the stage's `PlayerStart` global transform; call `player.setup(bounds)` with an `AABB` from the stage (`FlightBounds` metadata if present, else the handoff numbers X -45..45, Y 0..75, Z from the stage's authored range as an export on the stage root added in F10; for now a `stage_flight_bounds: Dictionary` export on the Session keyed by stage id); connect `player.targeting.target_changed` to `player.camera_rig` per the one-place rule (or have `PlayerController.setup` do it; choose one and document); `run_state.start(...)`, `begin_attempt()`, `interface.show_home(HUD)`.
- `_physics_process`: `run_state.tick_active(delta)` only when `not get_tree().paused`. `Main` is `PROCESS_MODE_ALWAYS`, so this guard is mandatory.
- `_unhandled_input`: `pause` action during `IN_STAGE` toggles pause. Pause: `get_tree().paused = true`, `run_state.set_paused(true)`, `player.set_controls_enabled(false)`, `interface.push_overlay(PAUSE, {"score": ..., "graze": ...})`. Resume reverses all four. Options from Pause: `interface.show_screen(OPTIONS)`; Back returns to Pause and the game stays paused (router guarantees the stack; the Session never unpauses on Back).
- `restart_stage`: unpause, `run_state.restart_stage()`, reload the stage and player as in Start, `begin_attempt()`.
- `return_to_menu`: unpause, `run_state.end_run(false)`, `_unload_stage()` (queue_free stage and player, clear `projectile_root` children), `interface.show_home(MAIN_MENU)`.
- Stage completion and defeat are not reachable yet; leave the `stage_completed` and `run_ended` handlers returning to the menu with a TODO referencing F11.

## Tests required

`tests/scene/test_game_session_flow.gd` (headless, instancing `main.tscn`):

- After ready, MAIN_MENU is visible and `WorldRoot` is empty.
- Emitting `action_requested(&"start_direct_stage", {"stage": &"stage_01"})` puts a `Stage` and a `PlayerShip` under `WorldRoot`, the player at `PlayerStart`, HUD visible, menus hidden, `RunState.phase == IN_STAGE`.
- Pause action: tree paused, PAUSE overlay visible, 30 ticks later `run_state` Active Time unchanged; `resume` unpauses and time accumulates again.
- Options from Pause then `back()` leaves the tree paused with PAUSE visible.
- `restart_stage` yields a new `PlayerShip` instance at `PlayerStart` with `clear_time()` 0.
- `return_to_menu` empties `WorldRoot` and `ProjectileRoot` and shows MAIN_MENU.
- Starting `stage_02` with a null scene shows an error and stays on the menu (no crash).

Manual (record in `docs/validation/menus.md`): run from the main scene with keyboard and gamepad; fly the Stage 1 route; pause mid-flight and confirm the ship freezes; Options and back; quit from the main menu.

## Out of scope

Defeat, results, checkpoints, HUD values, settings application, projectiles.

## Definition of Done

- Tests green; manual run recorded.
- GUIDE Section 6 `game_session.gd` row complete; Section 10 rows "Main composition and session" and "Menus/options" set to CODE_READY with evidence links.
- `docs/engineering/menus-session.md` complete for this Feature.
- Handoff log entry; commit `session: implement GameSession start, pause, restart, quit`.

## Handoff notes for Astra

Stage scenes are referenced from `Main`'s Inspector; when Stage 2 exists, add it there and tell Claude the flight interior bounds. `PlayerStart` must exist in every stage root.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/menus-session/issues/04-game-session-start-pause-quit.md, then implement that ticket. Use /run to verify the menu-to-flight flow. Finish with its Definition of Done and commit.
```
