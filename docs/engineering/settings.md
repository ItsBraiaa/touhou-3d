# Settings

## Purpose

The Settings Rules Core owns the eight GUIDE Section 14 Options values, their
defaults, validation and ConfigFile persistence. It is Node-free and does not
apply values to audio buses, the window, input devices or the camera; F3-02 (the
`OptionsScreen` adapter, "Options binding" below) and later adapters consume the
typed getters.

## Files

- `scripts/settings/settings.gd` (`Settings` Rules Core, ADR-0001)
- `scripts/ui/options_screen.gd` (`OptionsScreen` Adapter, F3-02), created by `scripts/ui/interface.gd`
- `scripts/ui/input_device_state.gd` (`InputDeviceState` Rules Core, F3-03), owned by `scripts/ui/interface.gd`

## Public contract

### Signals

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `changed` | `key: StringName, value: Variant` | A stored value changes; never for an equivalent sanitised write. |

### Constants and enums

`WindowMode` is `WINDOWED` (0) or `FULLSCREEN` (1). `InputDevice` is
`AUTOMATIC` (0), `KEYBOARD` (1) or `GAMEPAD` (2). `KEYS` is ordered as Master,
Music, SFX, Window Mode, Resolution, Input Device, Camera Sensitivity and
Invert Vertical.

`RESOLUTIONS` is `(1280, 720)`, `(1600, 900)` and `(1920, 1080)`. Volumes are
0–100. Sensitivity is 0.2–2.0 in 0.05 steps. Defaults are 80, 65, 80,
Windowed, 1280×720, Automatic, 1.0 and false.

### Methods

| Method | Effect |
| --- | --- |
| `_init(path := DEFAULT_PATH)` | Starts at defaults without I/O; the default path is `user://settings.cfg`. |
| `get_value` / `set_value` | Read or sanitise one field. `set_value` never saves and reports unknown keys with `push_error`. |
| Typed getters | Return each validated field in its native type. |
| `restore_defaults()` | Restores defaults and emits only actual changes. |
| `capture()` / `restore(data)` | Deep-copy all fields; restore sanitises known keys, defaults missing fields and ignores unknown keys, returning diagnostics. |
| `load_file()` | Missing files use defaults silently; corrupt files use defaults, report the path/error and remain untouched; valid files are restored field by field. |
| `save_file()` | Writes all eight fields to a fresh ConfigFile and returns its `Error`. |
| `volume_db(percent)` / `is_muted(percent)` | Static helpers for F3-02 bus application. |

## File layout

`[audio]` stores `master_volume`, `music_volume` and `sfx_volume`.
`[display]` stores `window_mode` and `resolution` (`Vector2i`). `[controls]`
stores `input_device`, `camera_sensitivity` and `invert_vertical`.

## Sanitising rules

| Field | Accepted | Invalid input |
| --- | --- | --- |
| Volumes | int/finite float; rounded then clamped | Field default |
| Window mode/input device | Valid enum int | Field default |
| Resolution | Supported `Vector2i` | Field default |
| Sensitivity | Finite int/float; clamped then snapped | Field default |
| Invert vertical | bool only | Field default |

## Dependencies

The owner constructs `Settings`, calls `load_file()` once at startup, applies the
typed values, and calls `save_file()` only after an explicit user change. No Node,
SceneTree, AudioServer or DisplayServer is referenced.

## Invariants

| Invariant | Where it holds |
| --- | --- |
| Defaults are stable and every write is validated. | Constants and `_sanitise`. |
| Invalid ConfigFile data falls back independently per field. | `restore` and `load_file`. |
| Corrupt files are not overwritten during load. | `load_file`; only `save_file` writes. |
| Persistence is explicit and change signals are idempotent. | `set_value`, `restore`, `restore_defaults`, `save_file`. |

## Setup for Astra

No scene attachment is required. F3-02 constructs the core, calls
`load_file()`, binds the eight widget values from the typed getters, and listens
to `changed` when runtime application is needed. The default file path is used
by the game; injected paths are intended for isolated callers.

## Options binding (F3-02)

`scripts/ui/options_screen.gd` (Adapter, `class_name OptionsScreen extends Node`). No scene attaches it: `Interface` creates it in code, named `OptionsScreen`, under the Options root (so `Interface` keeps its nine children), and calls `setup`. Delivered by path on 2026-09-23.

### Who owns what

- **`Interface`** owns the one `Settings`.
  - `_ready` validates its exports, builds `Settings.new(settings_path)` and calls `load_file()` once. Each message is a `push_warning` naming `Interface`: a bad user file is not a setup error.
  - It then instances the HUD and the menus, and binds the Options screen.
  - `get_settings() -> Settings` hands that instance to F3-03, F3-04 and dev tools.
  - `restore_defaults` from `Layout/DefaultsButton` is resolved by `OptionsScreen.restore_defaults()` and never emitted to the Session.
- **`OptionsScreen`** binds the eight GUIDE Section 14 widgets (`WIDGET_PATHS`) and applies the audio and display values. The camera sensitivity, invert vertical and input device are stored and saved only: F3-04 applies the camera values and F3-03 the input device.

### `OptionsScreen` contract

| Member | Meaning |
| --- | --- |
| `signal display_applied(window_mode: Settings.WindowMode, window_size: Vector2i)` | Each display application; `window_size` is `Vector2i.ZERO` in fullscreen. The headless DisplayServer ignores window changes, so this is how a caller sees them. |
| `WIDGET_PATHS` | Each `Settings` key to its path under the Options root, for example `Layout/Audio/MasterVolume`. |
| `BUS_BY_KEY` | `master_volume` → `Master`, `music_volume` → `Music`, `sfx_volume` → `SFX` (the F0-03 buses). |
| `setup(options: Control, settings: Settings)` | Once; a second call is a `push_error` and nothing else. The steps are listed below. |
| `restore_defaults()` | `settings.restore_defaults()`, then one `save_file()`. Each field that differed is applied and written back through `changed`. |
| `static window_size_for(resolution: Vector2i, usable: Vector2i) -> Vector2i` | The resolution when it fits, or when `usable` has no area (headless). Otherwise the largest `RESOLUTIONS` entry that fits, or the smallest when none does. |

`setup` runs these steps in order:

1. **Resolve and check every widget.** A missing or mistyped widget, an `OptionButton` whose item count is not 2, 3 and 3, or a slider whose min and max differ from the `Settings` range gets one `push_error` naming its path. That field stays unbound; the rest still bind.
2. **Write every widget from the stored values without signals:** `Range.set_value_no_signal`, `OptionButton.select`, `BaseButton.set_pressed_no_signal`.
3. **Connect the callbacks:** `value_changed`, `item_selected` and `toggled`, each bound to its key, then `settings.changed`.
4. **Apply the three buses and the display once:** the boot application.

### Flow

- **A user edit.**
  1. The widget value is converted: a volume slider value is rounded to an int, the sensitivity stays a float, an item index is the enum value, and a resolution index becomes `RESOLUTIONS[index]`.
  2. `settings.set_value(key, value)` runs. When it returns true, `save_file()` follows; a failed save is a `push_warning` and play goes on.
  3. The widget is rewritten, without a signal, from the stored value, which sanitising may have adjusted.
- **`settings.changed(key, value)` is the only place anything is applied,** whatever changed the value. A volume key applies its bus, and `window_mode` or `resolution` applies the display. Every bound key rewrites its widget without a signal, so Defaults refreshes the screen without echoing a change.
- **A bus.**
  - `AudioServer.get_bus_index(name)`; a missing bus is reported once with `push_error`, and the value stays stored.
  - `set_bus_mute(index, Settings.is_muted(percent))`, so 0 mutes only that bus.
  - `set_bus_volume_db(index, Settings.volume_db(percent))` while not muted.
- **The display** works on `get_tree().root`.
  - Janela: `mode = MODE_WINDOWED`, `size = window_size_for(resolution, screen_get_usable_rect(current_screen).size)`, then `move_to_center()`.
  - Tela cheia: `mode = MODE_FULLSCREEN`. The resolution is kept for the return to Janela and is not applied, because the stretch mode scales the layout (Claude's proposal).
  - Nothing touches `content_scale_*` or the stretch settings, so the 1280 × 720 composition (stretch `canvas_items`, aspect `expand`) holds at every size.
- **While paused.** Options opened from Pause is under `Interface`, which always processes. Widget signals and `AudioServer` calls do not depend on the tree running, so a change applies over a paused game.
- **Persistence.** The file is read once at boot and written only after an explicit change or Defaults, never at boot. A corrupt file boots with the defaults, stays untouched, and is replaced by the next change.

### Verification (no tests: the sprint rule)

A throwaway `SceneTree` script, deleted after use, checked every behavior the ticket lists, headless, on a per-process temp path:

- **Standalone.** Every widget filled with non-default values, 0 `changed` and no file after `setup`, one `display_applied` (Janela, 1600 × 900), Music muted at 0 and Master at 55.
- **Volumes.** Master 40 gives −7.96 dB (`linear_to_db(0.4)`), one `changed`, and the file reads 40. SFX 0 mutes only SFX, and SFX 30 unmutes it at −10.46 dB.
- **Display.** Resolution then fullscreen apply `(1920, 1080)` then `(FULLSCREEN, ZERO)`, and both are saved.
- **`window_size_for`** passes its four cases.
- **Stored-only values.** Sensitivity, invert and input device are stored and saved.
- **Refusals.** A second `setup` is refused, and a freed `MusicVolume` is reported while Master still binds.
- **Through `main.tscn`.**
  - The seeded file is read at boot, and `Interface` keeps nine children.
  - Overwriting the file after boot changes nothing: it is read once.
  - Defaults emits `changed` once per differing field (three), puts the widget, the bus and the file at the defaults, and `restore_defaults` never reaches `action_requested`.
  - SFX 25 applies at −12.04 dB with the tree paused under Options from Pause.
  - A corrupt file boots with the defaults and is untouched until a change replaces it.
- **Project and file.** The stretch stays `canvas_items` and `expand` at 1280 × 720. The real `user://settings.cfg` is untouched.

The existing suite passes (225 tests). A windowed boot of `main.tscn` (180 frames) printed no error and wrote no settings file.

## Input device and disconnect (F3-03)

Delivered by path on 2026-09-23. Options' `InputDevice` (Automático, Teclado, Controle) decides which prompts the menus show, and whether unplugging a controller pauses. It is a prompt preference and a disconnect rule only: it never filters input, so a wrong choice cannot lock anyone out (Claude's proposal).

### `InputDeviceState` (`scripts/ui/input_device_state.gd`, Rules Core, `class_name InputDeviceState extends RefCounted`)

| Member | Meaning |
| --- | --- |
| `signal prompts_changed(keyboard: bool)` | The prompts to show changed; emitted only on a change. |
| `JOYPAD_AXIS_THRESHOLD` | 0.5: a stick counts as gamepad use at or past it (moved here from `MenuController`). |
| `set_mode(mode: Settings.InputDevice)`, `get_mode()` | The preference. The last device starts as the keyboard and is kept across mode changes. |
| `note_event(event: InputEvent)` | A key makes the keyboard the last device. A joypad button, or a stick at or past the threshold, makes the gamepad the last device and marks `event.device` connected. The mouse, any `InputEventAction` (so an injected `pause` changes nothing) and stick drift are ignored. |
| `note_joypad(device: int, connected: bool)` | Keeps the set of connected pads. When the last one leaves, the keyboard becomes the last device. |
| `shows_keyboard_prompts() -> bool` | Teclado: always. Controle: while no pad is connected. Automático: while the last device is the keyboard. |
| `pauses_on_disconnect() -> bool` | Every mode but Teclado, where nobody is playing on the pad (Claude's proposal). |

### Wiring in `Interface`

- **At boot,** after F3-02's settings load and the Options binding:
  - the saved mode goes into `set_mode`;
  - each pad in `Input.get_connected_joypads()` goes into `note_joypad(id, true)`;
  - `prompts_changed`, `Settings.changed` (the input-device key calls `set_mode`) and `Input.joy_connection_changed` are connected once;
  - the first prompt state is pushed to every menu.
- **`_input(event)`** calls `note_event` and never handles the event. It runs before a focused button consumes the gamepad's accept press, and it runs while paused (`Interface` always processes).
- **`prompts_changed`** calls `MenuController.set_keyboard_prompts(keyboard)` on all eight menus. It sets `Layout/NavigationHint` on the five full screens and does nothing on the three overlays.
- **A pad leaving.** `note_joypad(device, false)`, then, if `pauses_on_disconnect()` and the HUD is on top, `_request_pause()`: an `InputEventAction` `pause` press and release through `Input.parse_input_event`.
  - It reaches `GameSession._unhandled_input` like Start or Escape, so the Session pauses only while a stage is in play.
  - Over Pause, Options from Pause, Defeat, Results or the menus nothing is injected, so an unplug never resumes or starts anything.
- **Keyboard recovery.** Pause takes focus on entry (F2-02), and the arrows, Enter and Escape work in every mode. When the last pad leaves, the prompts turn back to the keyboard's.

### Verification (no tests: the sprint rule)

A throwaway `SceneTree` script, deleted after use, ran headless on `main.tscn` with `settings_path` on a per-process temp file. Events went through `root.push_input`, connections through `Input.joy_connection_changed.emit`, and the mode through the Options widget.

- **The core.**
  - Automático follows the last device.
  - Drift at 0.3 is ignored and a push at 0.8 counts.
  - Actions and the mouse are ignored.
  - Teclado keeps the keyboard prompts and skips the disconnect pause.
  - Controle shows the gamepad's prompts only while a pad is connected.
  - The last pad leaving restores the keyboard prompts.
  - `prompts_changed` fired twice for pad, pad, key, key.
- **The footers in the flow.**
  - In Automático a pad button hides the footer on MainMenu, Options and StageSelect at once, and a key brings them back.
  - Teclado keeps them after pad input.
  - Controle hides them while a pad is known, and shows them once it leaves.
- **Disconnects.**
  - In the menus: nothing starts.
  - During Direct Stage 1 with the HUD on top: the tree pauses, Pause is on top and `RunState` is paused. Down then moves Pause's focus (Continuar → Reiniciar), and Escape resumes to the HUD.
  - On Pause, and in Options opened from Pause: nothing changes.
  - In Teclado mode during gameplay: no pause.
- **Regressions.** `tools/validate_menus.gd` still gives `MENUS_OK`, footer checks included, and the suite passes (225 tests). `test_menu_registry_contract.gd`'s footer case now drives `set_keyboard_prompts` directly (`test_set_keyboard_prompts_shows_and_hides_the_footer`).

## Camera wiring (F3-04)

Delivered by path on 2026-09-24 (part 2; the windowed pass of part 1 is in [validation/settings.md](../validation/settings.md)). `GameSession` (`scripts/session/game_session.gd`) applies the camera sensitivity and invert vertical to the ship in play through `CameraRig.apply_settings(sensitivity, invert_vertical)`. No `Settings`, `OptionsScreen`, `Interface`, rig or scene file changed.

| Session member | Effect |
| --- | --- |
| `_connect_camera_settings()` | Called once from `_ready`, after the other connections: `interface.get_settings().changed.connect(_on_setting_changed)`. Skipped when `get_settings()` is null, because `Interface` disabled itself and reported why. Never per stage, so Restart and Retry never double it. |
| `_apply_camera_settings()` | Returns when there is no `_player` or no `Settings`; otherwise `_player.camera_rig.apply_settings(settings.get_camera_sensitivity(), settings.get_invert_vertical())`. |
| `_spawn_player(ship, at)` | Calls `_apply_camera_settings()` right after `setup(_flight_volume)`, before the ship's first physics tick. Every ship passes through it: Start, Direct Stage, Restart, Retry and, from F11-02, the Campaign continuation. |
| `_on_setting_changed(key, _value)` | Calls `_apply_camera_settings()` for `Settings.CAMERA_SENSITIVITY` and `Settings.INVERT_VERTICAL` only. |

- **While paused.** Options from Pause is under `Interface`, which always processes, so a change reaches the live rig at once. The rig only stores the values, so they take effect on the first tick after Resume.
- **The rig's own exports** `sensitivity` and `invert_vertical` in `player_ship.tscn` are overwritten at every spawn. The orbit rate is tuned with `orbit_speed_degrees`.
- **Verification (no tests: the sprint rule).** A throwaway headless script ran the ticket's six cases (16 checks) and measured the orbit: six ticks of `camera_up` turn 0.4189 rad at 2.0, 0.0419 rad at 0.2 and −0.4189 rad at 2.0 inverted. A short windowed run showed the same. Both are in [validation/settings.md](../validation/settings.md) "Camera wiring".

## F16 binding profiles and persistence (F16-02)

Pending (lane trunk).

## F16 binding labels and prompt family (F16-08)

Pending (lane oc-a).

## F16 capture workflow and prompts (F16-03)

Pending (lane trunk).

## Open issues

- Bus and window application are live since F3-02 ("Options binding"), the input device since F3-03 ("Input device and disconnect"), and the camera values since F3-04 ("Camera wiring").
- **Owed: the physical keyboard and DualSense pass** over Options and the camera orbit at a saved sensitivity, invert on and off. F3-04 drove the orbit with `Input.action_press` only.
- **Owed: a physical DualSense unplug in flight** (ENGINEERING_BRIEF Section 8: a simulated gamepad event does not replace a physical controller). F3-03 was verified with synthetic events and `joy_connection_changed` emissions only. It belongs to the human pass.
- No gamepad glyphs or gamepad hint text: Controle and Automático after pad use hide the keyboard hint (GUIDE Section 14 allows hiding).
- **The windowed display pass** (a real resize, fullscreen, the layout intact at each resolution) was run by F3-04 part 1 and is recorded in [validation/settings.md](../validation/settings.md); F3-02 itself was verified headless through `display_applied`.
- Defaults applies the display twice when both the window mode and the resolution differ (one `changed` each). This is harmless, and it keeps `changed` as the one application point.
- Defaults remain the GUIDE-authored values until Astra tunes them.
