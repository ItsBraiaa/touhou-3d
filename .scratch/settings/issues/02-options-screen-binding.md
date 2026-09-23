# F3-02 Options screen binding

Status: todo
Type: adapter
parallel-safe: no
Depends on: F3-01, F4-02
Lane: oc-b
Model: GLM-5.3 (fallback GPT 5.6 Luna), after GLM-5.3's first window resets

## Goal

The Options screen shows and changes the real settings, and the game uses them from boot.

- `Interface` owns the one `Settings`. It reads the file once in `_ready` and hands the `Settings` to a new `OptionsScreen` adapter.
- `OptionsScreen` fills the eight widgets before it connects a single callback. It applies:
  - Master, Music and SFX to the F0-03 buses, where zero mutes;
  - the window mode and the resolution to the main window, keeping the 1280 × 720 layout.
- It saves after each explicit change. Defaults restores GUIDE Section 14's values, refreshes the widgets and saves once.
- Camera sensitivity and invert vertical are stored and exposed through `Interface.get_settings()`. Applying them to the ship is F3-04 (trunk), because this lane never edits `game_session.gd`.

## Read first

- `.scratch/settings/spec.md` "Cross-feature contracts", and `docs/engineering/settings.md`. Use F3-01's real `Settings` names from there.
- `docs/GUIDE.md` Section 14:
  - "Options values and fields": the paths, widget types and item order, and "Load validated saved settings into the widgets before accepting change callbacks".
  - "Focus and responsive layout": "The existing project stretch configuration is retained".
- `docs/engineering/menus-session.md`: "Interface contract", and the "GameSession contract" Actions row, where `restore_defaults` is only a warning today.
- `scripts/ui/interface.gd` as F4-02 left it. `scripts/ui/menu_controller.gd`: `Layout/DefaultsButton` requests `restore_defaults`. `scenes/ui/options.tscn`, read only.
- `tests/unit/project/test_audio_buses.gd`: the buses `Master`, `Music` and `SFX`.
- `project.godot` `[display]`: viewport 1280×720, stretch `canvas_items`, aspect `expand`.
- `tests/scene/test_interface_contract.gd`: `Interface` has exactly nine children.

## Files

- **Creates:** `scripts/ui/options_screen.gd`, `tests/scene/test_options_settings.gd`.
- **Edits:** `scripts/ui/interface.gd`:
  - `@export var settings_path: String = Settings.DEFAULT_PATH`;
  - `_settings`, `_options_screen`;
  - `get_settings() -> Settings`;
  - the `restore_defaults` case in `_on_action_requested`.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F3-02 row.
  - `docs/HANDOFF_LOG.md`: one entry.
  - `docs/engineering/settings.md`: an "Options binding" section.
  - `docs/engineering/menus-session.md`: in the Interface contract, the export, `get_settings` and the resolved `restore_defaults`; in the GameSession Actions row, `restore_defaults` no longer arrives.
  - `docs/GUIDE.md`: the Section 6 `interface.gd` row, and Section 14 "State and verification", where "no setting is applied or persisted until F3" now points to `settings.md`.
- **Must not touch:**
  - `scripts/session/game_session.gd` and `scenes/main.tscn` (trunk's).
  - `scenes/ui/*.tscn` (Astra's).
  - `scripts/ui/menu_controller.gd`: the registry is unchanged, because Defaults is resolved in `Interface`.
  - `scripts/settings/settings.gd`: a gap is a note in the Outcome and in `settings.md` Open issues.
  - `camera_rig.gd`, `project.godot` and `default_bus_layout.tres`.
  - `test_interface_contract.gd` and `test_menu_registry_contract.gd`.
- **Conflicts with:**
  - `interface.gd`: F4-02 comes before (Depends on) and F3-03 after, in the same lane.
  - `settings.md`: F3-03 and F3-04.

## Deliverables

### `Interface`

- **`_ready`, in order:**
  1. Validate the exports.
  2. `_settings = Settings.new(settings_path)`. Each `load_file()` message is `push_warning` with the Interface's path: a bad user file is not a setup error.
  3. The HUD and the menus, as today.
  4. If the Options screen exists, `_options_screen = OptionsScreen.new()`, named `OptionsScreen`, is added as a child of the Options root, then `setup(_menus[ScreenRouter.OPTIONS], _settings)`. It goes under the Options root rather than under `Interface`, which the contract test pins at nine children. A missing Options screen is already reported, and then nothing is applied.
- **`get_settings() -> Settings`:** the one instance, for F3-04, F3-03 and tests.
- **`restore_defaults`:** `_on_action_requested` resolves it with `_options_screen.restore_defaults()` and never emits it. The Session's "not implemented" warning goes away without an edit to `game_session.gd`.

### `OptionsScreen` (`scripts/ui/options_screen.gd`, `class_name OptionsScreen extends Node`)

This Adapter is created in code and attached in no scene, so its contract lives in `settings.md` and the `interface.gd` row, not in a Section 6 row of its own.

- **`signal display_applied(window_mode: Settings.WindowMode, window_size: Vector2i)`.** Emitted on each display application; `window_size` is `Vector2i.ZERO` in fullscreen. The headless DisplayServer ignores window changes, so this signal is how tests see them.
- **Constants.** `WIDGET_PATHS` maps each `Settings` key to its GUIDE path, such as `Layout/Audio/MasterVolume` and `Layout/Controls/InvertVertical`. `BUS_BY_KEY` maps each volume key to `&"Master"`, `&"Music"` or `&"SFX"`.
- **`setup(options: Control, settings: Settings)`**, once; a second call is `push_error` and nothing else:
  1. Resolves every path. A missing or mistyped widget is `push_error` with its path, and that field stays unbound while the rest still bind. It checks the `OptionButton` item counts (2, 3, 3) and the slider min/max against the `Settings` ranges, and reports a mismatch.
  2. Writes every widget from `settings` with the no-signal setters: `Range.set_value_no_signal`, `OptionButton.select` (which does not emit) and `BaseButton.set_pressed_no_signal`.
  3. Only then connects `value_changed`, `item_selected` and `toggled`, each bound to its key, and `settings.changed`.
  4. Applies the three buses and the display once. That is the boot application.
- **A user edit:**
  - The widget value is converted: a slider value becomes an int for the volumes; an item index becomes an enum value, or `Settings.RESOLUTIONS[index]` for the resolution.
  - Then `settings.set_value(key, value)` runs. When it returns true, `settings.save_file()` follows; a failed save is `push_warning` and play goes on.
  - The widget is then rewritten, without a signal, from the stored value.
- **`settings.changed(key, value)`** is the one place where anything is applied, whether the change came from a widget, Defaults or elsewhere. A volume key calls `_apply_bus(key)`, and `WINDOW_MODE` or `RESOLUTION` calls `_apply_display()`. Every key rewrites its widget without a signal. The camera and input-device keys are only stored, for F3-04 and F3-03.
- **`restore_defaults()`:** `settings.restore_defaults()`, then one `save_file()`.
- **`_apply_bus(key)`:**
  - `AudioServer.get_bus_index(name)`; -1 is reported once.
  - `set_bus_mute(index, Settings.is_muted(percent))`, and `set_bus_volume_db(index, Settings.volume_db(percent))` when the bus is not muted.
- **`_apply_display()`** works on `get_tree().root`:
  - Windowed: `mode = Window.MODE_WINDOWED`, `size = window_size_for(resolution, DisplayServer.screen_get_usable_rect(window.current_screen).size)`, then `move_to_center()`.
  - Fullscreen: `mode = Window.MODE_FULLSCREEN`. The resolution is kept for the return to Janela and is not applied, because stretch scales the layout to the screen (Claude's proposal).
  - Nothing here touches `content_scale_*` or the stretch settings, so the 1280 × 720 composition holds at every size.
- **`static func window_size_for(resolution: Vector2i, usable: Vector2i) -> Vector2i`:**
  - The chosen resolution when it fits, or when `usable` has no area (headless).
  - Otherwise the largest `RESOLUTIONS` entry that fits, or the smallest when none does.

## Tests required

`tests/scene/test_options_settings.gd` has two fixtures:

- **Standalone:** `options.tscn` under `tree.root`, a `Settings` on the temp path, and an `OptionsScreen` added under it, with recorders connected before `setup`.
- **Main:** `main.tscn`, with `Interface.settings_path` set to the temp path before `add_child`. The file is seeded first.

Temp path per process, as in F3-01. `after_each` deletes the file and resets all three buses to 0 dB, unmuted. To simulate a user edit, set `slider.value`, which emits. For an `OptionButton`, call `select(i)`, then `item_selected.emit(i)`.

The tests:

- `test_setup_fills_every_widget_before_connecting`: non-default values are shown; `changed` fires 0 times; no file is written.
- `test_setup_applies_the_buses_and_the_display_once`: `display_applied` fires once, with `WINDOWED` and 1600×900.
- `test_a_volume_change_applies_saves_and_emits_once`: `MasterVolume.value = 40` gives Master close to `linear_to_db(0.4)`, and a fresh `load_file()` reads 40.
- `test_zero_volume_mutes_only_its_bus_and_raising_it_unmutes` (ENGINEERING_BRIEF 4.I "independent volume buses")
- `test_window_mode_and_resolution_changes_apply_the_display`
- `test_window_size_for_keeps_a_fitting_resolution_and_steps_down_when_too_large`
- `test_sensitivity_invert_and_input_device_are_stored_and_saved`
- `test_defaults_restores_refreshes_and_saves_once` (main fixture, `Options/Layout/DefaultsButton.pressed.emit()`):
  - the widgets and buses are at GUIDE defaults, and so is the file;
  - `changed` fires once per field that differed, with no echo from the widget refresh;
  - an `interface.action_requested` recorder never sees `restore_defaults`.
- `test_boot_reads_the_file_once`: after boot, overwrite the file, then `show_screen(OPTIONS)`. The widgets and `get_settings()` still hold the boot values.
- `test_a_corrupt_file_boots_with_defaults_and_is_replaced_only_by_a_change`
- `test_changes_apply_while_opened_from_pause`: Direct Stage 1, paused with an injected `pause` action, then Options. An SFX change applies with the tree paused.
- `test_a_missing_widget_is_reported_and_the_rest_bind`: free `MusicVolume` before `setup`.
- `test_project_keeps_the_stretch_that_preserves_the_layout`: `canvas_items`, `expand`, 1280×720.

## Out of scope

- Camera application (F3-04).
- Prompts, device tracking and the disconnect pause (F3-03).
- Sounds on change (F13).
- Any `.tscn` edit.

## Definition of Done

- `tools/test.ps1` is green, and its output has no `SCRIPT ERROR` line.
- ENGINEERING_BRIEF 4.I "independent volume buses" and "save/reload options", and Section 8 "persistence", have named tests. No Error-level warnings.
- Verified headless through the tests above. The windowed display pass (a real resize, fullscreen, the layout intact) is done by F3-04's `/run`. Record it as owed in `settings.md` until then.
- Module doc, the GUIDE rows and the `menus-session.md` lines, handoff log, `Status: done` with an Outcome, ROADMAP row.
- One commit: `settings: bind Options to Settings, buses and window`. Then run the lane glm-b land step from `docs/engineering/SPRINT.md`.

## Handoff notes for Astra

- **Load-bearing names.** The eight Section 14 widget paths are load-bearing. So is the item order of `WindowMode`, `Resolution` and `InputDevice`: item index = enum value or `RESOLUTIONS` index. The slider ranges must match `Settings`, and a mismatch is reported at boot.
- **Authored values.** The values authored in `options.tscn` are now overwritten at boot by the saved values or the defaults.
- **Resolution.** It applies in Janela only (Claude's proposal).

## Kickoff prompt

```
In your lane worktree, read AGENTS.md, docs/engineering/SPRINT.md (your lane section), docs/engineering/ROADMAP.md and .scratch/settings/issues/02-options-screen-binding.md. Check its dependencies with tools/lane.ps1 status F3-01 F4-02, implement it test-first, run tools/test.ps1 until green with no SCRIPT ERROR, finish its Definition of Done, commit, then run tools/lane.ps1 land.
```
