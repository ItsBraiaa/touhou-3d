# F2-02 Interface and menu controller

Status: todo
Type: adapter
parallel-safe: no
Depends on: F0-03, F2-01

## Goal

`interface.gd` on `Main/Interface` instances every menu scene and the HUD once, drives them through `ScreenRouter`, and turns button presses into `action_requested` signals for the Session. `menu_controller.gd`, shared by the eight menu scenes, wires the buttons listed in GUIDE Section 14 by path, sets initial focus, restores remembered focus, and hides the keyboard footer hint when a gamepad is active.

## Read first

- `docs/GUIDE.md` Section 14 entirely (registry paths, focus rules, runtime text, hidden ReplayButton rule)
- `docs/engineering/CONVENTIONS.md`: "Architecture rules" (one connection place, signals outward), "Setup errors", "Language"
- `.scratch/menus-session/issues/01-screen-router-core.md`
- `scenes/ui/*.tscn` (confirm the paths; they are stable per GUIDE)

## Deliverables

### `scripts/ui/menu_controller.gd`, `class_name MenuController extends Control`

- Identifies its screen from the root node name (`MainMenu`, `StageSelect`, `Options`, `Controls`, `PauseMenu`, `Defeat`, `Results`, `Credits`) and maps it to the router id.
- Holds a constant table `ACTIONS_BY_SCREEN: Dictionary` of `{ "Layout/StartButton": &"start_campaign", ... }` built from GUIDE Section 14, one entry per button row. Missing paths produce a `push_error` naming screen and path, and that button is skipped; the rest of the screen still works.
- Emits `action_requested(action: StringName, payload: Dictionary)` on press. Payloads: `start_direct_stage` carries `{"stage": &"stage_01"}` or `&"stage_02"`.
- `enter(params: Dictionary, focus_path: NodePath)`: shows, grabs focus on `focus_path` if valid else on the first focusable button in tree order; applies params (Results: hide `ReplayButton` or `ContinueButton` per run mode and rebuild focus neighbors so hidden buttons are skipped; Defeat: set `Layout/RetryLocation` text; Pause: score and graze labels; Results heading `Jornada concluída` on final victory). Text values are Portuguese literals.
- `leave() -> NodePath`: returns the currently focused control's path for the router's memory, then hides.
- Footer hint: when `Input.get_connected_joypads()` is non-empty and the last input event was a joypad event, hide the footer node if present (`Layout/Footer` or the authored name; discover by name, log once if absent).

### `scripts/ui/interface.gd`, `class_name Interface extends CanvasLayer`

- Exports: `menu_scenes: Array[PackedScene]` (the eight), `hud_scene: PackedScene`.
- `_ready`: instance all, hide all, connect each `MenuController.action_requested` to a single `_on_action_requested` that re-emits `action_requested(action, payload)` upward to the Session. Create the `ScreenRouter`, connect `screen_shown`/`screen_hidden` to show, `enter`, `leave`, hide.
- Public: `show_home(id)`, `show_screen(id, params)`, `push_overlay(id, params)`, `back() -> bool`, `is_gameplay_covered() -> bool`, `get_hud() -> Control`.
- `_unhandled_input`: `ui_cancel` calls `back()`; if false, emits `action_requested(&"back_refused", {})` so the Session can decide (for example, Escape on the main menu does nothing).
- Runs with `PROCESS_MODE_ALWAYS` (set in F0-03) so menus work while paused.

## Tests required

- `tests/scene/test_menu_registry_contract.gd`: instances each of the eight scenes headless; asserts every path in `ACTIONS_BY_SCREEN` for that screen exists and is a `BaseButton`; asserts `enter({}, NodePath())` gives focus to some button; asserts Results with `{"mode": "campaign_stage_1"}` hides `ReplayButton` and shows `ContinueButton`, and with `{"mode": "final_victory"}` hides both and sets the heading.
- `tests/scene/test_interface_contract.gd`: instances `main.tscn` headless; after ready, `Interface` has eight `MenuController` children and one HUD, all hidden; `show_home(MAIN_MENU)` makes exactly one visible; simulating a press on `Layout/OptionsButton` (call `emit_signal("pressed")`) emits `action_requested(&"open_options", {})`.

Manual: navigate every screen with keyboard, then with a gamepad; confirm focus is visible on entry and restored on Back; footer hides on gamepad.

## Out of scope

Applying settings widgets (F3), binding HUD values (F4), starting a stage (F2-04).

## Definition of Done

- Tests green; manual navigation recorded in `docs/validation/menus.md`.
- GUIDE Section 6 rows for `menu_controller.gd` and `interface.gd`.
- `docs/engineering/menus-session.md` updated.
- Handoff log entry; commit `ui: implement Interface and MenuController wiring`.

## Handoff notes for Astra

Button paths from Section 14 are now load-bearing. Renaming a button requires a matching change in `MenuController.ACTIONS_BY_SCREEN`; announce it in the log first.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/menus-session/issues/02-interface-and-menu-controller.md, then implement that ticket. Finish with its Definition of Done and commit.
```
