# F2-04 GameSession: start, pause, quit

Status: done (2026-09-23)
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
  - Added by F2-03: `RunState` state is read through getters, so `RunState.phase == IN_STAGE` below means `run_state.get_phase() == RunState.Phase.IN_STAGE`; the Pause overlay's score and Graze are `run_state.stage_result()["score"]` and `["graze"]`; `advance()` takes the Power Level as a required argument. Every Attempt change is ignored outside `IN_STAGE`, and `start()` unpauses. Contract in `docs/engineering/menus-session.md` "RunState contract".
  - Added by F2-02: `interface` is already typed `Interface` and `_ready` already calls `interface.show_home(ScreenRouter.MAIN_MENU)`; `Interface` has instanced every menu and the HUD. Connect `interface.action_requested` once in `_ready`. `back` never reaches the Session (Interface resolves Back buttons and `ui_cancel`); `ui_cancel` on Pause arrives as `resume`, with Pause still shown, so the resume handler must also call `interface.back()` to remove it. `back_refused` arrives from the main menu, Defeat and Results. The Pause overlay params are `{"score": int, "graze": int}`. Two traps: gamepad B is both `ui_cancel` (resume) and `bomb`, so a resume on B's press can register as a bomb on the first unpaused tick; and Start is `pause` only, so with Options open from Pause a blind pause toggle would resume under Options: toggle only when `interface.current_screen()` is `HUD` or `PAUSE`. `tools/validate_menus.gd` plays the `open_*` navigation this ticket takes over; its `_on_action_requested` is the reference. Contract in `docs/engineering/menus-session.md` "Interface contract".
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

## Outcome (2026-09-23)

Done. `scripts/session/game_session.gd` is the composition root's Session: every menu action, Campaign and Direct Stage start with the stage and the ship under `WorldRoot`, pause and resume, Options from Pause, Restart, Return to Menu and Quit. `scenes/main.tscn` sets `player_scene`, `stage_scenes` (Stage 1 and Stage 2) and `stage_flight_bounds` (Stage 1). Contract in `docs/engineering/menus-session.md` "GameSession contract". Evidence: `tests/scene/test_game_session_flow.gd` (20 tests; suite 172 green), sixteen mutants caught by assertion, `tools/validate_menus.gd` reworked to play the menu-to-flight flow through the real Session on keyboard and gamepad (`MENUS_OK`, headless and windowed, `docs/validation/menus-flight.png` and a re-captured `menus-pause-return.png`), a clean windowed boot of the real main scene, and Sair exiting with code 0. Recorded in `docs/validation/menus.md`.

Differences from the text above, each listed in the module doc's Open issues:

- **Stage 2 is wired, not null.** Its scene exists and records its flight interior on `FlightBounds/Limits`, so Direct Stage 2 flies. The null-scene refusal is tested by clearing the entry in the test.
- **Bounds.** `FlightBounds/Limits` `min`/`max` metadata wins when present (Stage 2); otherwise `stage_flight_bounds[id]` (Stage 1: X -45..45, Y 0..75, Z -570..35, the inner faces of its walls). A stage without either, or without `PlayerStart`, is refused like a missing scene.
- **Targeting to camera** stays connected once in `PlayerController._ready` (F1-04); the Session makes no connection.
- **Resume acts only while the tree is paused, and `pause` only in `IN_STAGE` with the HUD or Pause on top**, so Start under Options from Pause is ignored and a Pause the Session did not open stays.
- **`run_ended(false)` needs no handler work** (only `return_to_menu` produces it); `stage_completed` and a victory return to the menu with TODO(F11). `stage_started` and `paused_changed` are not connected yet.
- **`get_run_state()`** added for tests and the validation tool.

The B-as-bomb trap is only half solvable here: `Interface` consumes the B press that resumes, so an event-driven bomb reader never sees it (tested), but `Input.is_action_just_pressed(&"bomb")` still reads true on the first unpaused tick, and `Input.action_release` does not clear it in Godot 4.7. F7's Bomb request must come from the input event. The manual pass was synthetic: no person pressed a key and no pad was connected; the physical keyboard and DualSense pass is still owed. Stage 1 is flyable only up to its first closed Gate until F10.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/menus-session/issues/04-game-session-start-pause-quit.md, then implement that ticket. Use /run to verify the menu-to-flight flow. Finish with its Definition of Done and commit.
```
