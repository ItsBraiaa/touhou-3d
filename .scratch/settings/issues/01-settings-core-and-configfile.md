# F3-01 Settings core and ConfigFile

Status: todo
Type: core
parallel-safe: yes
Depends on: F0-02
Lane: oc-b
Model: GPT 5.6 Luna (fallback DeepSeek V4.1 Flash)

## Goal

A Node-free `Settings` Rules Core that:

- holds the eight Options values of GUIDE Section 14 with their authored defaults;
- validates and clamps every write;
- persists the values to a `ConfigFile`, at `user://settings.cfg` by default. The path is injected, so tests use a temp file. Its owner reads the file once at start and writes it only after an explicit change.

A missing file gives the defaults. A corrupt file, or a bad field, falls back to the defaults field by field. Nothing here touches a bus, a window or a Node: F3-02 applies the values.

## Read first

- `docs/GUIDE.md` Section 14 "Options values and fields": the eight fields, their ranges and defaults, and the item order of the three `OptionButton`s.
- `docs/PLANEJAMENTO.md` Section 7: "Save settings locally".
- `docs/ENGINEERING_BRIEF.md`: Section 4.I ("corrupt settings fallback") and Section 8 ("Settings defaults, validation, and persistence").
- `docs/adr/0001-gameplay-rules-in-node-free-cores.md`, which names settings as a core. `docs/engineering/CONVENTIONS.md`: "Typing and warnings", "Architecture rules".
- `scripts/session/run_state.gd` for the `capture()`/`restore()` style, and `tests/unit/session/test_run_state.gd` for the test style.
- `docs/engineering/testing.md`: `signal_recorder`, `assert_almost_eq`.

## Files

- **Creates:** `scripts/settings/settings.gd`, `tests/unit/settings/test_settings.gd`.
- **Edits:** none.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F3-01 row.
  - `docs/HANDOFF_LOG.md`: one entry.
  - `docs/engineering/settings.md`: new, from `TEMPLATE.md`, with the `Settings` contract. Add its line to `docs/engineering/README.md`.
- **Must not touch:**
  - `scripts/ui/*` and `scripts/session/*`.
  - `project.godot` and `default_bus_layout.tres`.
  - `scenes/ui/options.tscn`.
- **Conflicts with:** none, since every file is new. F3-02, F3-03 and F3-04 extend `settings.md` later.

## Deliverables

`scripts/settings/settings.gd`, `class_name Settings extends RefCounted`, with no Node, SceneTree, AudioServer or DisplayServer use.

### Enums and constants

- `enum WindowMode { WINDOWED, FULLSCREEN }`, matching Janela and Tela cheia. `enum InputDevice { AUTOMATIC, KEYBOARD, GAMEPAD }`, matching Automático, Teclado and Controle. Each value equals its widget's item id.
- `const DEFAULT_PATH := "user://settings.cfg"`.
- The key constants, with `KEYS: Array[StringName]` in GUIDE order: `MASTER_VOLUME := &"master_volume"`, `MUSIC_VOLUME`, `SFX_VOLUME`, `WINDOW_MODE`, `RESOLUTION`, `INPUT_DEVICE`, `CAMERA_SENSITIVITY`, `INVERT_VERTICAL`.
- `RESOLUTIONS: Array[Vector2i]`: `(1280, 720)`, `(1600, 900)`, `(1920, 1080)`, in widget order.
- The ranges: `VOLUME_MIN := 0`, `VOLUME_MAX := 100`, `SENSITIVITY_MIN := 0.2`, `SENSITIVITY_MAX := 2.0`, `SENSITIVITY_STEP := 0.05`.
- `DEFAULTS`, GUIDE Section 14's "Current display defaults": 80, 65, 80, `WINDOWED`, `Vector2i(1280, 720)`, `AUTOMATIC`, 1.0, false.
- The file has one section per Options panel. `[audio]` holds the three volumes. `[display]` holds `window_mode` and `resolution`. `[controls]` holds `input_device`, `camera_sensitivity` and `invert_vertical`. Each key is stored under its constant's name: enums as ints, the resolution as a `Vector2i`.

### Sanitising, one rule per field

| Field | Accepted | Out of range | Wrong type or not finite |
| --- | --- | --- | --- |
| The three volumes | int or float | rounded, then clamped to 0..100 | default |
| `window_mode`, `input_device` | an int that is a value of its enum | default | default |
| `resolution` | a `Vector2i` in `RESOLUTIONS` | default | default |
| `camera_sensitivity` | a finite int or float | clamped to 0.2..2.0, then snapped to 0.05 | default |
| `invert_vertical` | bool | — | default (an int 1 is refused) |

### Methods and signal

- **`signal changed(key: StringName, value: Variant)`.** Fires once for each stored value that changes, and never when a write leaves the value as it was.
- **`_init(path: String = DEFAULT_PATH)`.** Starts at `DEFAULTS` and does no I/O. `get_file_path() -> String` returns the path.
- **`get_value(key) -> Variant`** and **`set_value(key, value) -> bool`.**
  - `set_value` sanitises the value, stores it, emits `changed` when it differs, and returns whether it did.
  - It does not save.
  - An unknown key is `push_error` and returns false. (`assert` would abort the headless runner.)
- **Typed getters:** `get_master_volume() -> int`, `get_music_volume() -> int`, `get_sfx_volume() -> int`, `get_window_mode() -> WindowMode`, `get_resolution() -> Vector2i`, `get_input_device() -> InputDevice`, `get_camera_sensitivity() -> float`, `get_invert_vertical() -> bool`.
- **`restore_defaults()`.** Every field returns to `DEFAULTS`.
- **`capture() -> Dictionary`.** Returns a new dictionary of key to value, deep-copied.
- **`restore(data: Dictionary) -> PackedStringArray`.**
  - It reads every key of `KEYS` from `data`: a missing key gives the default, and every value is sanitised. Unknown keys are ignored.
  - It returns one message for each missing, refused or clamped field, naming the key, the value it found and the value it used.
- **`load_file() -> PackedStringArray`.**
  - No file at the path: the defaults, and an empty result.
  - `ConfigFile.load` fails: the defaults, one message naming the path and the error, and the file is left exactly as it is. It is only replaced by the next `save_file()`.
  - Otherwise it builds the dictionary from the three sections and calls `restore()`.
- **`save_file() -> Error`.** Writes all eight fields to a fresh `ConfigFile` at the path.
- **Static helpers for F3-02:**
  - `volume_db(percent: int) -> float` returns `linear_to_db(percent / 100.0)`, so 80 is about -1.94 dB. `is_muted(percent: int) -> bool` is `percent <= 0`.
  - The linear-amplitude mapping is Claude's proposal. Astra tunes it by ear once F13 plays sound.

`restore_defaults`, `restore` and `load_file` emit `changed` only for fields that actually changed.

The methods are named `load_file` and `save_file`, not `load` and `save`, because `load` is a GDScript global function.

## Tests required

`tests/unit/settings/test_settings.gd`:

- **Temp file.** Use `"user://test_settings_%d.cfg" % OS.get_process_id()` and delete it with `DirAccess.remove_absolute` in `before_each` and `after_each`. The four lane worktrees share one `user://` directory, so a fixed name would race between lanes.
- **Float comparisons.** Compare floats with `assert_almost_eq`.

The tests:

- `test_new_settings_hold_the_guide_14_defaults`
- `test_volumes_round_and_clamp_to_0_100`: 150 gives 100, -5 gives 0, and 72.6 gives 73.
- `test_sensitivity_clamps_to_0_2_2_0_and_snaps_to_0_05`: 1.23 gives 1.25, 0.0 gives 0.2, and 9.0 gives 2.0.
- `test_non_finite_sensitivity_falls_back_to_the_default`: `NAN` and `INF`.
- `test_enum_values_outside_their_enum_fall_back`: `window_mode` 7 and `input_device` -1.
- `test_unsupported_resolution_falls_back`: `Vector2i(800, 600)` and `Vector2(1600, 900)`.
- `test_wrong_types_fall_back_per_field`: `"loud"` for a volume, `1` for `invert_vertical`, `"1920x1080"` for the resolution, `true` for a volume.
- `test_set_value_emits_changed_once_only_when_the_stored_value_changes`: the same value, or one that clamps to the stored value, gives false and no emission.
- `test_unknown_key_is_refused_and_changes_nothing`
- `test_restore_defaults_emits_only_for_fields_that_differed`
- `test_capture_is_a_deep_copy_and_restore_sanitises_like_set_value`
- `test_save_then_load_round_trips_every_field`: a second `Settings` on the same path.
- `test_missing_file_loads_defaults_reports_nothing_and_writes_nothing`
- `test_corrupt_file_falls_back_to_defaults_reports_it_and_is_left_untouched`: the bytes are compared before and after.
- `test_one_bad_field_falls_back_alone`: `master_volume="x"` and `music_volume=30` give Music 30, Master 80 and one message.
- `test_out_of_range_values_in_the_file_are_clamped_and_reported`
- `test_load_emits_changed_only_for_values_that_differ`
- `test_nothing_is_written_until_save_file`
- `test_volume_db_maps_percent_and_zero_is_mute`

## Out of scope

- Applying anything to buses or the window (F3-02).
- Device tracking and the disconnect pause (F3-03).
- The camera (F3-04).
- Remapping, a settings version or migration, and any player-facing text.

## Definition of Done

- `tools/test.ps1` is green, and its output has no `SCRIPT ERROR` line. Grep for it: a runtime error after an assertion still reports PASS.
- The ENGINEERING_BRIEF Section 8 invariant "Settings defaults, validation, and persistence" and the Section 4.I item "corrupt settings fallback" have the named tests above.
- No Error-level warnings.
- `docs/engineering/settings.md` is written from `TEMPLATE.md` (purpose, the `Settings` contract, the sanitising table, the file layout, invariants and tests) and has its line in `README.md`.
- Handoff log entry. `Status: done` with an Outcome. ROADMAP row.
- One commit: `settings: add Settings core and ConfigFile persistence`. Then run the lane glm-b land step from `docs/engineering/SPRINT.md`.

## Handoff notes for Astra

- The defaults are GUIDE Section 14's display defaults, and they are now the code's defaults too.
- From F3-02 on, the widget values authored in `options.tscn` are overwritten at boot. Changing a default means asking Claude to change `Settings.DEFAULTS`.

## Kickoff prompt

```
In your lane worktree, read AGENTS.md, docs/engineering/SPRINT.md (your lane section), docs/engineering/ROADMAP.md and .scratch/settings/issues/01-settings-core-and-configfile.md. Check its dependencies with tools/lane.ps1 status F0-02, implement it test-first, run tools/test.ps1 until green with no SCRIPT ERROR, finish its Definition of Done, commit, then run tools/lane.ps1 land.
```
