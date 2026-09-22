# F0-03 Project config, main scene, audio buses, export preset

Status: done
Export step: blocked (no export templates on this host; see Outcome)
Type: integration
parallel-safe: no
Depends on: F0-02

## Goal

Take ownership of the shared project files and put them in their final shape: strict warnings, the full input map, `scenes/main.tscn` as the composition root and main scene, the three audio buses Options will bind to, and a Windows export preset with a first export attempt.

## Read first

- `docs/engineering/CONVENTIONS.md`: "Typing and warnings", "Input actions", "Architecture rules", "Shared-file protocol"
- `docs/adr/0002-single-composition-root-without-autoloads.md`
- `docs/GUIDE.md` Section 5 "Main composition" and Section 14 (menus expect to be instanced under a CanvasLayer)
- `docs/PLANEJAMENTO.md` Section 8 (bindings)

## Facts already established

- `project.godot` currently has no `[input]` section, main scene `res://scenes/ui/main_menu.tscn`, Forward Plus, Jolt, D3D12, 1280 × 720 `canvas_items` stretch.
- No `default_bus_layout.tres`, no `export_presets.cfg`.
- No export templates are installed under `%APPDATA%\Godot\export_templates`. Downloading them is a user action (about 1 GB); the session asks the user and records a blocker if declined.

## Deliverables

### `project.godot`

- `[debug]`: `gdscript/warnings/untyped_declaration=2`, `unused_variable=2`, `unused_parameter=2`, `shadowed_variable=2` (2 = Error).
- `[application]`: `run/main_scene="res://scenes/main.tscn"`.
- `[input]`: sixteen actions with deadzone 0.2, bound exactly as below. Write the section directly (Godot's `InputEventKey`, `InputEventJoypadButton`, `InputEventJoypadMotion` serialization) or through the editor, then verify by loading the project headless.

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| `move_forward` / `move_back` | W / S | Left stick Y (negative / positive) |
| `move_left` / `move_right` | A / D | Left stick X (negative / positive) |
| `ascend` / `descend` | Space / Left Ctrl | Right shoulder (RB) / Left shoulder (LB) |
| `camera_left` / `camera_right` | Left / Right arrow | Right stick X |
| `camera_up` / `camera_down` | Up / Down arrow | Right stick Y |
| `fire` | J | Right trigger axis |
| `focus` | Left Shift | Left trigger axis |
| `lock_target` | K | Y |
| `next_target` | Tab | X |
| `bomb` | L | B |
| `pause` | Escape | Start |

No mouse bindings. Built-in `ui_*` actions are left untouched.

### `default_bus_layout.tres`

Buses `Master`, `Music` (send Master), `SFX` (send Master). Referenced from `[audio] buses/default_bus_layout`.

### `scenes/main.tscn` and `scripts/session/game_session.gd`

- Tree: `Main` (Node, script `game_session.gd`), `WorldRoot` (Node3D), `ProjectileRoot` (Node3D), `Interface` (CanvasLayer, `process_mode = PROCESS_MODE_ALWAYS`), `Audio` (Node, `PROCESS_MODE_ALWAYS`). `Main` itself is `PROCESS_MODE_ALWAYS` so it can handle the pause action while the tree is paused.
- `game_session.gd`: `class_name GameSession extends Node`, `@export` references to the four children, `_ready` validation per the setup-error policy, and for now only: instance `scenes/ui/main_menu.tscn` under `Interface`. No navigation logic (F2). Doc comment says so.
- Running the project shows the main menu exactly as before.

### `export_presets.cfg`

Preset "Windows Desktop": `platform="Windows Desktop"`, `export_path="build/Touhou-3D.exe"`, `binary_format/embed_pck=true`, `application/console_wrapper_icon` off, include filters default. `build/` is already ignored by F0-01.

### First export

Run `tools/godot.ps1 --headless --path . --export-release "Windows Desktop" build/Touhou-3D.exe`. If templates are missing, ask the user to install them (Editor > Manage Export Templates, or the official 4.7.2 templates archive) and record the outcome. Launch the exe once if it was produced.

## Tests required

- `tests/scene/test_main_contract.gd`: instances `scenes/main.tscn` headless, asserts the five node names and types, asserts `Interface` and `Main` have `PROCESS_MODE_ALWAYS`, and asserts a `MainMenu` child appears under `Interface` after one frame.
- `tests/unit/project/test_input_map.gd`: asserts all sixteen actions exist in `InputMap` with deadzone 0.2 and at least one keyboard and one joypad event each.

## Out of scope

Menu navigation, settings application, any gameplay.

## Definition of Done

- Tests green. `tools/godot.ps1 --headless --path . --quit` prints no errors.
- Export produced, or the template blocker recorded in this ticket and the roadmap with `Status: blocked` only for the export step (the rest of the ticket still completes).
- GUIDE.md Section 5 "Main composition" updated to the actual tree; Section 6 row for `game_session.gd` updated with the exports.
- Handoff log entry marked `[shared]`; commit `project: [shared] own project.godot, add input map, main scene, buses, export preset`.

## Handoff notes for Astra

`project.godot`, `default_bus_layout.tres`, `export_presets.cfg`, and `scenes/main.tscn` are now Claude's. The startup scene is `main.tscn`; the menu still appears first. Use F6 on any menu scene to preview it as before.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/foundation/issues/03-project-config-main-scene-buses-export.md, then implement that ticket. Finish with its Definition of Done and commit.
```

## Outcome (2026-09-21)

- Delivered as specified: warnings as errors, sixteen actions (physical keycodes, `device = -1`, `location = LEFT` on Left Ctrl and Left Shift), `scenes/main.tscn` with `GameSession`, `default_bus_layout.tres`, `export_presets.cfg`. GUIDE Sections 5, 6, and 10 updated; module doc `docs/engineering/project.md`.
- Tests: `tests/scene/test_main_contract.gd` (4), `tests/unit/project/test_input_map.gd` (5), plus `tests/unit/project/test_audio_buses.gd` (2) so F3 has the bus contract pinned. 27 tests green. The axis test uses `is_action_pressed`, because Godot matches a joypad axis event in both directions and only the pressed flag carries the direction.
- Verified: `--headless --quit` prints no errors; every `.gd` under `scripts/`, `tests/`, `tools/` passes `--check-only` under the new warnings; the project runs windowed (Vulkan Forward+) and a 1280 × 720 screenshot of `main.tscn` shows the main menu exactly as before.
- Export step blocked: this session ran on Linux, where `~/.local/share/godot/export_templates/4.7.2.stable/` is empty. Godot reported `No export template found at the expected path: .../windows_release_x86_64.exe` (and `windows_debug_x86_64.exe`). The user installs the 4.7.2 templates (Editor > Manage Export Templates, about 1 GB), then runs `tools/godot.sh --headless --path . --export-release "Windows Desktop" build/Touhou-3D.exe` and launches the exe once. Nothing else in the ticket depends on it; F14-01 repeats the export.
- Additions beyond the ticket: `tools/godot.sh` and `tools/test.sh`, POSIX mirrors of the PowerShell wrappers, because this host has no PowerShell (Astra hit the same limit on Stage 2). Four Astra-owned `tools/validate_*.gd` scripts had untyped `for` iterators over untyped arrays and stopped compiling; they received type annotations only, announced in the handoff log.

## Comments

### 2026-09-22 — Review fix: gameplay roots processed while paused

A review of the four commits after `7447407` found (P2) that `WorldRoot` and `ProjectileRoot` inherited `PROCESS_MODE_ALWAYS` from `Main` and kept processing while the tree was paused; a runtime probe confirmed five frames of processing. Fixed by setting both to `PROCESS_MODE_PAUSABLE` in `scenes/main.tscn`, with two regression tests in `tests/scene/test_main_contract.gd`: `test_world_and_projectile_roots_are_pausable` and `test_only_interface_and_audio_keep_processing_while_paused`. The second failed against the old scene with three `_process` calls and one `_physics_process` call per root. The runner's watchdog is now `PROCESS_MODE_ALWAYS` so it survives a paused tree. 47 tests green. The same review noted (P3) that commit `e54b7d6` lacked a handoff entry; it was added retroactively to `docs/HANDOFF_LOG.md`.
