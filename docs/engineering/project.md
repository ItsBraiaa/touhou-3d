# Project configuration and composition root

The shared project files Claude took over with ticket F0-03 on 2026-09-21, and the `GameSession` that boots the game; its full contract since F2-04 is in [menus-session.md](menus-session.md) "GameSession contract". CODE_READY except the Windows export, which is blocked on export templates (see Open issues).

## Purpose

Owns `project.godot` (warnings as errors, input map, main scene, bus layout reference), `default_bus_layout.tres`, `export_presets.cfg`, `scenes/main.tscn`, and `scripts/session/game_session.gd`. This page keeps the project files and the composition root's shape; what `GameSession` does with the Run — menu actions, stage loading, pause — is documented with the rest of Feature F2 in [menus-session.md](menus-session.md). It does not own settings persistence (F3) or any gameplay.

## Files

- `project.godot`: `[debug]` sets `untyped_declaration`, `unused_variable`, `unused_parameter`, `shadowed_variable` to Error; `[application] run/main_scene` is `res://scenes/main.tscn`; `[audio] buses/default_bus_layout`; `[input]` holds the sixteen gameplay actions, plus `ui_accept` and `ui_cancel` with their default keys and the gamepad's A and B added (F2-02; Godot 4.7 binds those two to keys only).
- `default_bus_layout.tres`: buses `Master`, `Music` (send Master), `SFX` (send Master).
- `export_presets.cfg`: preset "Windows Desktop", `build/Touhou-3D.exe`, embedded PCK, x86_64.
- `scenes/main.tscn`: composition root (ADR-0002); tree in GUIDE.md Section 5. `Main`, `Interface`, and `Audio` are `PROCESS_MODE_ALWAYS`; `WorldRoot` and `ProjectileRoot` are `PROCESS_MODE_PAUSABLE`, so gameplay stops with the tree while menus, pause handling, and audio keep running. Since F2-02 `Interface` carries `scripts/ui/interface.gd` with `menu_scenes` (the eight `scenes/ui/` menus) and `hud_scene` (`scenes/ui/hud.tscn`); contract in [menus-session.md](menus-session.md).
- `scripts/session/game_session.gd` (Adapter, attached to `Main`). Since F2-04 `Main` also sets `player_scene`, `stage_scenes` and `stage_flight_bounds`.
- `tests/scene/test_main_contract.gd`, `tests/unit/project/test_input_map.gd`, `tests/unit/project/test_audio_buses.gd`.

## Public contract

### Exports (GameSession)

| Export | Type | Default | Required | Meaning |
| --- | --- | --- | --- | --- |
| `world_root` | Node3D | `Main/WorldRoot` | yes | Holds the loaded Stage instance; PAUSABLE, stops while the tree is paused |
| `projectile_system` | ProjectileSystem | `Main/ProjectileRoot` | yes | The projectile system (F6-02, [weapon-rendering.md](weapon-rendering.md)); PAUSABLE, stops while the tree is paused |
| `interface` | `Interface` (was `CanvasLayer` until F2-02) | `Main/Interface` | yes | Menus and HUD; processes while paused |
| `player_scene`, `stage_scenes`, `stage_flight_bounds` | see [menus-session.md](menus-session.md) | set in `main.tscn` since F2-04 | `player_scene` only | The ship, the stage scenes by id, and Stage 1's Flight Volume |

### Signals

None yet.

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `_ready()` | engine | Validates the four root exports and `player_scene`. On success connects `Interface.action_requested` and two `RunState` signals (F2-04) and calls `interface.show_home(ScreenRouter.MAIN_MENU)`; `Interface` has already instanced every menu (F2-02). On failure calls `push_error` with the node path and each missing field, then sets `process_mode = DISABLED`. |

### Input actions

| Action | Keyboard (physical key) | Gamepad |
| --- | --- | --- |
| `move_forward` / `move_back` | W / S | Left stick Y negative / positive |
| `move_left` / `move_right` | A / D | Left stick X negative / positive |
| `ascend` / `descend` | Space / Left Ctrl | RB / LB |
| `camera_left` / `camera_right` | Left / Right arrow | Right stick X negative / positive |
| `camera_up` / `camera_down` | Up / Down arrow | Right stick Y negative / positive |
| `fire` | J | Right trigger |
| `focus` | Left Shift | Left trigger |
| `lock_target` | K | Y |
| `next_target` | Tab | X |
| `bomb` | L | B |
| `pause` | Escape | Start |

Deadzone 0.2 on every action, `device = -1` (any device), no mouse bindings; the built-in `ui_*` actions are untouched. `descend` and `focus` carry `location = LEFT`, so only the left modifier matches. Godot matches a stick axis event in both directions and reports the opposite one as "not pressed", so code reads `Input.get_action_strength()` or `is_action_pressed()`, never `InputMap.event_is_action()` alone.

### Audio buses

`Master` (index 0), `Music` (1, send Master), `SFX` (2, send Master). F3 binds the Options sliders to these by name.

## Dependencies

None injected. `GameSession` receives its four children, the ship and the stage scenes through the exports set in `scenes/main.tscn`.

## Invariants and tests

| Invariant | Test |
| --- | --- |
| `scenes/main.tscn` has `Main` (`GameSession`) with exactly `WorldRoot`, `ProjectileRoot`, `Interface`, `Audio` of the documented types | `test_main_contract.gd::test_root_is_main_with_game_session_attached`, `::test_four_children_with_the_documented_types` |
| `Main`, `Interface`, `Audio` process while the tree is paused | `test_main_contract.gd::test_main_interface_and_audio_process_while_paused` |
| `WorldRoot` and `ProjectileRoot` are `PROCESS_MODE_PAUSABLE`: nodes under them receive no `_process` or `_physics_process` while the tree is paused and resume when it is unpaused, while nodes under `Interface` and `Audio` keep processing | `test_main_contract.gd::test_world_and_projectile_roots_are_pausable`, `::test_only_interface_and_audio_keep_processing_while_paused` |
| The main menu is instanced under `Interface` after one frame | `test_main_contract.gd::test_main_menu_is_instanced_under_interface` |
| Sixteen actions exist with deadzone 0.2, one keyboard and one joypad event each, no mouse | `test_input_map.gd::test_every_action_exists_with_deadzone`, `::test_every_action_has_one_keyboard_and_one_joypad_event` |
| Each binding in the table presses its action; the opposite stick direction does not | `test_input_map.gd::test_keyboard_bindings_match_the_table`, `::test_joypad_buttons_match_the_table`, `::test_joypad_axes_match_the_table` |
| Three buses in order, Music and SFX sending to Master | `test_audio_buses.gd` |
| Every `.gd` under `scripts/`, `tests/`, `tools/` compiles with the four warnings as errors | Verified manually on 2026-09-21 with `tools/godot.sh --headless --path . --check-only --script res://<file>` over every file; not automated |
| The project boots windowed and shows the main menu | Verified manually on 2026-09-21 (Vulkan Forward+, 1280 × 720 screenshot); not automated |

## Setup for Astra

Nothing to attach. `scenes/main.tscn` is Claude's; do not add nodes to it. Keep previewing menus with F6 on their own scenes; F5 now boots `main.tscn`, which shows the main menu exactly as before. Every script must compile with the four warnings as errors: type `for` iterator variables when the collection is an untyped `Array` (`for path: String in paths`).

## Open issues

- Windows export blocked: no export templates under `~/.local/share/godot/export_templates/4.7.2.stable/` on this Linux host; the export needs `windows_release_x86_64.exe` and `windows_debug_x86_64.exe` there. Install them (Editor > Manage Export Templates, or the official 4.7.2 templates archive), then run `tools/godot.sh --headless --path . --export-release "Windows Desktop" build/Touhou-3D.exe` and launch the exe once. F14 repeats the export.
- `audio/buses/default_bus_layout` is written explicitly although it equals Godot's default; the editor drops the line on its next save of `project.godot`. Harmless either way.
- Only the Windows preset exists, as the ticket asked; no Linux preset.
