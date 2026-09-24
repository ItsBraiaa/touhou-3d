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

## Open issues

- Bus and window application are live since F3-02 ("Options binding"). The input device (F3-03) and the camera values (F3-04) are stored and saved but not applied yet.
- **Owed: the windowed display pass** (a real resize, fullscreen, the layout intact at each resolution). F3-04 part 1's `/run` records it; F3-02 was verified headless through `display_applied`.
- Defaults applies the display twice when both the window mode and the resolution differ (one `changed` each). This is harmless, and it keeps `changed` as the one application point.
- Defaults remain the GUIDE-authored values until Astra tunes them.
