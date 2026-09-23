# F3 Settings — spec

Status: ready-for-agent
Owner: Claude (lane glm-b for 01 to 03, lane trunk for 04)
Source: PLANEJAMENTO Section 7 (the settings list, "Save settings locally", Automatic mode follows the last-used device, a controller disconnect pauses and the keyboard recovers); GUIDE Section 14 "Options values and fields" and "Focus and responsive layout"; ENGINEERING_BRIEF Section 4.I ("controller disconnect recovery, input mode selection, corrupt settings fallback, independent volume buses") and Section 8 ("Settings defaults, validation, and persistence"); ADR-0001 (settings is a Rules Core), ADR-0002 (no autoload).

## Goal

Options does what its widgets say. One Node-free `Settings` holds the eight Section 14 values, validates every write, and persists them to `user://settings.cfg`. The file is read once at boot, and a missing or corrupt file falls back to defaults. The three buses and the main window follow the values from boot, and Defaults restores them. The Automático, Teclado and Controle choice decides which prompts the menus show. Unplugging a controller in flight pauses the game, and the keyboard can take over. The ship's camera uses the saved sensitivity and invert-vertical values from its first frame, and changes made from Pause reach it too.

## Reinstated (2026-09-23)

The one-pass plan cut F3 on 2026-09-23 to protect the Stage 1 loop. The same day the PO reinstated it in the sprint plan (`docs/engineering/SPRINT.md`) in a reduced but real form:

- no input remapping;
- no gamepad glyph icons (the keyboard footer hides, as GUIDE Section 14 allows);
- the resolution applies in Janela only;
- no settings version or migration.

## Tickets

1. `01-settings-core-and-configfile.md`: F3-01. Core, parallel-safe, lane glm-b. Depends on F0-02.
2. `02-options-screen-binding.md`: F3-02. Adapter, lane glm-b. Depends on F3-01 and F4-02.
3. `03-input-device-mode-and-controller-disconnect.md`: F3-03. Adapter, lane glm-b. Depends on F3-02.
4. `04-settings-to-camera-wiring.md`: F3-04. Integration, lane trunk. Depends on F10-03 and F3-02.

## Cross-feature contracts

**`Settings`** (`scripts/settings/settings.gd`, F3-01, `class_name Settings extends RefCounted`):

- **Enums:** `WindowMode { WINDOWED, FULLSCREEN }` and `InputDevice { AUTOMATIC, KEYBOARD, GAMEPAD }`. Their values equal the item ids of the Options `OptionButton`s.
- **Keys:** the StringName constants `MASTER_VOLUME`, `MUSIC_VOLUME`, `SFX_VOLUME`, `WINDOW_MODE`, `RESOLUTION`, `INPUT_DEVICE`, `CAMERA_SENSITIVITY` and `INVERT_VERTICAL`, listed in `KEYS`.
- **Constants:** `RESOLUTIONS: Array[Vector2i]` (1280×720, 1600×900, 1920×1080, in widget order), `DEFAULTS` (GUIDE Section 14's display defaults) and `DEFAULT_PATH := "user://settings.cfg"`.
- **Storage:** `_init(path := DEFAULT_PATH)`, `load_file() -> PackedStringArray` (problems) and `save_file() -> Error`.
- **Values:** `get_value(key)` and `set_value(key, value) -> bool` (sanitises the value, and returns true when it changed). `restore_defaults()`, `capture() -> Dictionary` and `restore(data) -> PackedStringArray`.
- **Typed getters:** `get_master_volume()`, `get_music_volume()`, `get_sfx_volume() -> int`, `get_window_mode() -> WindowMode`, `get_resolution() -> Vector2i`, `get_input_device() -> InputDevice`, `get_camera_sensitivity() -> float` and `get_invert_vertical() -> bool`.
- **Volume helpers:** static `volume_db(percent)` and `is_muted(percent)`.
- **Signal:** `changed(key: StringName, value: Variant)`. It fires once for each stored value that changes, whatever the cause: a widget, Defaults, `restore` or `load_file`.

**`Interface`** (F3-02). It owns the one `Settings` for the process:

- `@export var settings_path: String = Settings.DEFAULT_PATH`. Tests set it on the instance before `main.tscn` enters the tree.
- `get_settings() -> Settings`.
- `restore_defaults` is resolved inside `Interface`, as `back` is, and never reaches the Session.

**`OptionsScreen`** (`scripts/ui/options_screen.gd`, F3-02, `extends Node`). `Interface` creates it in code under the Options root, so no scene is edited:

- It fills the widgets before it connects them.
- It is the only writer of bus volume and mute and of the main window's mode and size.
- `display_applied(window_mode, window_size)` is how headless tests see a display change.

**`InputDeviceState`** (`scripts/ui/input_device_state.gd`, F3-03, a Node-free core) and **`MenuController.set_keyboard_prompts(shown)`** (F3-03):

- One tracker in `Interface` replaces the per-menu footer tracking of F2-02.
- A controller disconnect with the HUD on top injects an `InputEventAction` `pause` through `Input.parse_input_event`, which reaches `GameSession._unhandled_input`, so the pause needs no edit to `game_session.gd`.

**Session** (F3-04, trunk). `GameSession._ready` connects `interface.get_settings().changed` once. `_apply_camera_settings()` calls `_player.camera_rig.apply_settings(get_camera_sensitivity(), get_invert_vertical())`. It runs from F10-03's `_spawn_player()`, and from the signal handler for the two camera keys.

**Audio** (F13): the bus volumes and mutes belong to `OptionsScreen`. `audio_controller.gd` plays streams on `Music` and `SFX` and never writes a bus volume or mute. F13 does not read `Settings`.

## File boundaries

- `game_session.gd`: F3-04 only (trunk).
- `interface.gd`: F4-02 (trunk), then F3-02, then F3-03.
- `menu_controller.gd` and `test_menu_registry_contract.gd`: F3-03 changes the footer only. F11-01 (trunk) changes `enter()`, `_ready` and the list of load-bearing paths. The two tickets are not ordered by Depends on, so whichever lands second merges `_ready`'s tail by hand.
- F3 edits no `.tscn`. `options.tscn` is read only.

**Test files.** The four worktrees share one `user://` directory, because it comes from the project name. Every F3 test file therefore uses `"user://test_settings_%d.cfg" % OS.get_process_id()` and deletes it before and after each test. Tests that change a bus restore all three buses to 0 dB, unmuted, in `after_each`, because `AudioServer` state outlives a test.

## Done when

- F3 tests are green, including named tests for ENGINEERING_BRIEF Section 8 "Settings defaults, validation, and persistence" and for the Section 4.I items "corrupt settings fallback", "independent volume buses", "input mode selection" and "controller disconnect recovery".
- From the main menu or from Pause, changing an Options value applies it at once and saves it. A relaunch shows the saved values. Defaults restores GUIDE Section 14's values.
- Unplugging the pad in flight shows Pause, and Escape resumes.
- A new ship's camera uses the saved sensitivity and invert-vertical values.
- `docs/engineering/settings.md` covers all four tickets. The GUIDE Section 6 rows for `interface.gd`, `menu_controller.gd` and `game_session.gd` are updated.

## Out of scope

- Input remapping, and the Controls diagram, which stays static.
- Gamepad glyph icons.
- Per-monitor or custom resolutions, exclusive fullscreen, and V-Sync or quality options.
- A settings version or migration.
- Any sound that plays when an option changes (F13).
- Any edit to `scenes/ui/*.tscn`.
