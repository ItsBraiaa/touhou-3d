# F2-01 ScreenRouter core

Status: todo
Type: core
parallel-safe: yes
Depends on: F0-02

## Goal

A Node-free `ScreenRouter` that models which screen is shown, which overlays sit above gameplay, how Back returns to the caller, and which control had focus on each screen, so `interface.gd` only has to show, hide, and focus.

## Read first

- `docs/GUIDE.md` Section 14 "Scene and action registry" (every "Return to caller" and "preserving return destination" row), "Focus and responsive layout"
- `docs/adr/0002-single-composition-root-without-autoloads.md`
- `docs/engineering/CONVENTIONS.md`

## Deliverables

`scripts/ui/screen_router.gd`, `class_name ScreenRouter extends RefCounted`.

- Screen ids as `StringName` constants: `MAIN_MENU`, `STAGE_SELECT`, `OPTIONS`, `CONTROLS`, `CREDITS`, `HUD`, `PAUSE`, `DEFEAT`, `RESULTS`. Two kinds: full screens (the first five plus HUD) and overlays (PAUSE, DEFEAT, RESULTS).
- `home(id)`: clears all history and overlays and shows `id`. Used when entering the main menu or starting a run (HUD).
- `replace(id, params := {})`: shows a full screen, pushing the previous full screen onto a history stack so `back()` can return to it (Options opened from the main menu returns to the main menu; Credits opened from Results returns to Results).
- `push(id, params := {})`: shows an overlay above the current stack. Overlays can be stacked (Pause, then Options as a full screen over Pause: Options replaces the visible screen but the overlay stack remembers Pause, so Back returns to Pause with the game still paused).
- `back() -> bool`: returns to the previous entry; false when nothing to return to (the adapter then ignores `ui_cancel`).
- `current() -> StringName`, `visible_stack() -> Array[StringName]` (bottom to top), `has_overlay(id) -> bool`, `is_gameplay_covered() -> bool` (any overlay or any non-HUD full screen while a run is active).
- Focus memory: `remember_focus(screen: StringName, control_path: NodePath)`, `focus_for(screen) -> NodePath` (empty when unknown).
- Signals: `screen_shown(id: StringName, params: Dictionary)`, `screen_hidden(id: StringName)`. Emitted in the order hide-then-show.

## Tests required

`tests/unit/ui/test_screen_router.gd`:

- `home(MAIN_MENU)` then `replace(OPTIONS)` then `back()` shows MAIN_MENU; history is empty afterwards.
- MAIN_MENU, OPTIONS, CONTROLS, back, back returns through OPTIONS to MAIN_MENU.
- `home(HUD)`, `push(PAUSE)`, `replace(OPTIONS)`, `back()` shows PAUSE with HUD underneath and `has_overlay(PAUSE)` true throughout; a second `back()` returns to HUD with no overlays.
- `home(HUD)`, `push(RESULTS)`, `replace(CREDITS)`, `back()` shows RESULTS.
- `home()` clears both history and overlays.
- `back()` returns false on a fresh `home()` and emits nothing.
- Focus memory round-trips and is per screen.
- Signals are emitted once per transition, hide before show, with the params passed through.

## Out of scope

Any Node, any actual Control focus, input handling.

## Definition of Done

- Tests green.
- `docs/engineering/menus-session.md` started with the router contract.
- Roadmap row, handoff log entry, commit `ui: add ScreenRouter core`.

## Handoff notes for Astra

None.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/menus-session/issues/01-screen-router-core.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
