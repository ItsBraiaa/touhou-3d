# Project configuration and composition root

The shared project files Claude took over with ticket F0-03 on 2026-09-21, and the `GameSession` skeleton that boots the game. CODE_READY except the Windows export, which is blocked on export templates (see Open issues).

## Purpose

Owns `project.godot` (warnings as errors, input map, main scene, bus layout reference), `default_bus_layout.tres`, `export_presets.cfg`, `scenes/main.tscn`, and `scripts/session/game_session.gd`. It deliberately does not own screen navigation, Run state, pause, or stage loading (F2, F11), settings persistence (F3), or any gameplay.

## Files

- `project.godot`: `[debug]` sets `untyped_declaration`, `unused_variable`, `unused_parameter`, `shadowed_variable` to Error; `[application] run/main_scene` is `res://scenes/main.tscn`; `[audio] buses/default_bus_layout`; `[input]` holds the sixteen gameplay actions.
- `default_bus_layout.tres`: buses `Master`, `Music` (send Master), `SFX` (send Master).
- `export_presets.cfg`: preset "Windows Desktop", `build/Touhou-3D.exe`, embedded PCK, x86_64.
- `scenes/main.tscn`: composition root (ADR-0002); tree in GUIDE.md Section 5.
- `scripts/session/game_session.gd` (Adapter, attached to `Main`).
- `tests/scene/test_main_contract.gd`, `tests/unit/project/test_input_map.gd`, `tests/unit/project/test_audio_buses.gd`.

## Public contract

### Exports (GameSession)

| Export | Type | Default | Required | Meaning |
| --- | --- | --- | --- | --- |
| `world_root` | Node3D | `Main/WorldRoot` | yes | Holds the loaded Stage instance |
| `projectile_root` | Node3D | `Main/ProjectileRoot` | yes | Root of the projectile system |
| `interface` | CanvasLayer | `Main/Interface` | yes | Menus and HUD; processes while paused |
| `audio` | Node | `Main/Audio` | yes | Audio controller root; processes while paused |

### Signals

None yet.

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `_ready()` | engine | Validates the four exports. On success instances `scenes/ui/main_menu.tscn` under `interface`. On failure calls `push_error` with the node path and each missing field, then sets `process_mode = DISABLED`. |

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

None injected. `GameSession` receives its four children through the exports set in `scenes/main.tscn`.

## Invariants and tests

| Invariant | Test |
| --- | --- |
| `scenes/main.tscn` has `Main` (`GameSession`) with exactly `WorldRoot`, `ProjectileRoot`, `Interface`, `Audio` of the documented types | `test_main_contract.gd::test_root_is_main_with_game_session_attached`, `::test_four_children_with_the_documented_types` |
| `Main`, `Interface`, `Audio` process while the tree is paused | `test_main_contract.gd::test_main_interface_and_audio_process_while_paused` |
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
