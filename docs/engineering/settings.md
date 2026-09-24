# Settings

## Purpose

The Settings Rules Core owns the eight GUIDE Section 14 Options values, their
defaults, validation and ConfigFile persistence. It is Node-free and does not
apply values to audio buses, the window, input devices or the camera; F3-02 and
later adapters consume the typed getters.

## Files

- `scripts/settings/settings.gd` (`Settings` Rules Core, ADR-0001)

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

## Open issues

Bus, window, input-device and camera application are F3-02 through F3-04.
Defaults remain the GUIDE-authored values until Astra tunes them.
