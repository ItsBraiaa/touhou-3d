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

Delivered by trunk on 2026-09-24. It adds the rebindable action catalog, two editable binding profiles, the five F16 camera and prompt values, a versioned `[controls]` schema with an atomic save and crash recovery, and the one `InputMap` writer. It extends "Public contract" above: `KEYS` still lists the eight Options values (OptionsScreen binds exactly those), the new values are `CONTROL_KEYS`, and `DEFAULTS`, `capture`, `restore`, `restore_defaults`, `load_file` and `save_file` now cover all thirteen values plus the profiles. Every existing key, getter and signal keeps its meaning.

### Files

- `scripts/settings/input_bindings.gd`: `InputBindings`, Rules Core (`RefCounted`). The catalog, descriptors, defaults, contexts, conflicts and edit transactions.
- `scripts/settings/settings.gd`: the new values, the profiles, the schema, migration, the atomic save and the pending confirmation.
- `scripts/ui/input_binding_adapter.gd`: `InputBindingAdapter` (`RefCounted`). The only `InputMap` writer for catalog actions, the event describer and the default-drift check.
- `scripts/ui/interface.gd`: owns the adapter and installs the saved profiles before any menu exists.

### The catalog (`InputBindings.CATALOG`, display order)

Gameplay keys are physical (by position). Keys of menu-only actions are keycodes of the active layout, so Enter and the arrows follow it. Every default equals `project.godot`, or Godot's built-in events for the four `ui_*` directions and `ui_focus_next`/`ui_focus_prev`.

| Action | Label | Category | Contexts | Required | Teclado e mouse | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `move_forward` | Avançar | Movimento | gameplay | yes | W | left stick up (axis 1 −) |
| `move_back` | Recuar | Movimento | gameplay | yes | S | left stick down (axis 1 +) |
| `move_left` | Mover à esquerda | Movimento | gameplay | yes | A | left stick left (axis 0 −) |
| `move_right` | Mover à direita | Movimento | gameplay | yes | D | left stick right (axis 0 +) |
| `ascend` | Subir | Movimento | gameplay | yes | Space | RB (button 10) |
| `descend` | Descer | Movimento | gameplay | yes | Left Ctrl | LB (9) |
| `dash_left` | Impulso à esquerda | Movimento | gameplay | no | Q | D-pad left (13) |
| `dash_right` | Impulso à direita | Movimento | gameplay | no | E | D-pad right (14) |
| `fire` | Disparar | Combate | gameplay | yes | J | RT (axis 5 +) |
| `focus` | Foco | Combate | gameplay | no | Left Shift | LT (axis 4 +) |
| `lock_target` | Fixar alvo | Combate | gameplay | no | K | Y (3) |
| `next_target` | Trocar alvo | Combate | gameplay | no | Tab | X (2) |
| `bomb` | Bomba | Combate | gameplay | no | L | B (1) |
| `camera_left` / `_right` / `_up` / `_down` | Câmera à esquerda / à direita / para cima / para baixo | Câmera | gameplay | no | the arrows | right stick (axes 2 and 3) |
| `camera_recenter` | Centralizar câmera | Câmera | gameplay | no | R, Mouse 3 | RS press (8) |
| `pause` | Pausa | Menus | gameplay and menu | yes | Escape | Start (6) |
| `ui_up` / `ui_down` / `ui_left` / `ui_right` | Navegar para cima / para baixo / à esquerda / à direita | Menus | menu | yes | the arrows | D-pad (11 to 14), then the left stick |
| `ui_accept` | Confirmar | Menus | menu | yes | Enter, Space (Numpad Enter fixed) | A (0) |
| `ui_cancel` | Voltar | Menus | menu | yes | Escape | B (1) |
| `ui_focus_next` | Próximo item | Menus | menu | no | Tab | none |
| `ui_focus_prev` | Item anterior | Menus | menu | no | Shift+Tab | none |

- **Categories** are `CATEGORIES` (`&"movement"`, `&"combat"`, `&"camera"`, `&"menus"`), with Portuguese names in `CATEGORY_LABELS`.
- **Required** means each profile must keep at least one slot bound, so nobody loses the way to play, pause or drive the menus.
- **Fixed bindings** (`get_fixed_bindings`): Numpad Enter on `ui_accept` is Godot's third default key for it. It is installed with the keyboard profile, but never shown in a slot, edited or saved, so the two slots lose no default. It counts as a conflict for other actions, but not towards a required action's binding.
- The inventory grep found only these actions. The scripts read `move_*`, `ascend`, `descend`, `focus`, `fire`, `bomb`, `lock_target`, `next_target`, `camera_*`, `pause` and `ui_cancel`, and Godot's focus navigation and buttons read the other `ui_*` actions. No key is hardcoded anywhere else. `ui_select`, `ui_page_*` and the text-editing `ui_*` actions are not in the catalog; they keep their engine events.

### The binding descriptor

| Field | Type | Meaning |
| --- | --- | --- |
| `kind` | String | `"key"`, `"mouse_button"`, `"joy_button"` or `"joy_axis"`. The keyboard-and-mouse profile takes the first two, the gamepad profile the last two. |
| `code` | int | A key: the physical keycode when `physical`, otherwise the layout keycode. It must be a code a key reports: a printable character (from `KEY_SPACE` to U+10FFFF, without the control characters and surrogates), or one of the special keys Godot 4.7 names in `Key` (`KEY_UNKNOWN` and the unassigned codes between them are refused). A mouse button: 1 to 9, including the wheel. A joypad button: 0 to `JOY_BUTTON_MAX` − 1. An axis: 0 to `JOY_AXIS_MAX` − 1. |
| `axis_sign` | int | −1 or +1 for an axis; a trigger (axis 4 or 5) only has +1. It is 0 for everything else. |
| `physical` | bool | Keys only. |
| `modifiers` | int | A `KEY_MASK_SHIFT`/`CTRL`/`ALT`/`META` chord for a key or mouse button, such as Shift+Tab. A modifier key's own bit is dropped, so Left Shift stays a standalone key. |
| `location` | int | Keys only: `KeyLocation`, to tell Left Shift and Left Ctrl from the right-hand keys. **Refinement of the spec's five fields**, needed to match `project.godot` exactly. It may be omitted on input (read as 0), and it is always present in a normalized descriptor. |

- A blank slot is `{}`. Each action has `SLOT_COUNT` (2) slots per profile. Bound slots come first and a repeat is dropped (packed).
- Rejected: a non-Dictionary, an unknown field or kind, a wrong-typed field, a code out of range (for a key, a code no key reports), a sign on a non-axis or a negative trigger, unknown modifier bits, and a descriptor of the other profile's device.
- `same_input(a, b)` is true for the same kind and code, the same chord, the same axis sign (opposite signs are distinct) and compatible key locations (unspecified matches either side). It ignores `physical`, so a physical key and a layout key with the same code count as one key.
  - **Known limit: mixed key spaces on a non-QWERTY layout.** The comparison is exact for the special keys (Escape, Enter, Tab, the arrows) on any layout, and for every key on US QWERTY. On another layout, a physical and a layout character key are compared by code, not by key, because the Node-free core does not know the layout. Only `pause` (physical, since it is a gameplay action too) and the menu-only actions (layout) meet this way. On AZERTY, for example, `pause` on physical Q and `ui_accept` on layout A are the same key but are not reported, while physical A and layout A are two keys that are reported. The defaults are special keys, so they are not affected. **For F16-03:** when a capture puts a character key on `pause`, or on a menu-only action while `pause` holds one, compare in the layout's space (`DisplayServer.keyboard_get_keycode_from_physical`) in the capture flow before calling `assign`.
- Helpers: `key_binding(code, physical := true, modifiers := 0, location := 0)`, `mouse_button_binding(button, modifiers := 0)`, `joy_button_binding(button)`, `joy_axis_binding(axis, sign)`, `parse_binding(value, profile := &"") -> Dictionary` (normalized, or `{}`), and `profile_for(binding) -> StringName`.

### Contexts and conflicts

- **Contexts.** `CONTEXT_GAMEPLAY` is read while a stage runs with the HUD on top, and `CONTEXT_MENU` while a menu has focus. `pause` has both, because it also resumes from Pause (`GameSession._unhandled_input`).
- **Conflicts** are checked within one profile, between actions whose contexts overlap (`can_share(a, b)` is false).
  - Gameplay and menu-only actions never overlap. So the defaults' shared stick, D-pad, arrows, Space and B stay valid, and movement may share menu navigation.
  - The only permitted overlap is `pause` with `ui_cancel` (Escape): on Pause, `Interface` takes `ui_cancel` first, and both mean resume.
  - `pause` does conflict with every other menu action. Pause bound to Enter would then eat Confirmar on the Pause screen.
- **`validate_profile(profile)`** reports every required action left unbound, and every input that two actions hold when they may not share it.

### Edit transactions (`InputBindings`)

`assign(profile, action, slot, binding, resolution := RESOLUTION_NONE) -> PackedStringArray` is one transaction. An empty result means it was applied; otherwise it returns the reasons, and nothing changed.

- It is refused for:
  - an unknown profile, action, slot or resolution;
  - an invalid binding;
  - a binding that is already in the action's other slot or its fixed binding.
- **Resolutions**, when `find_conflicts(profile, action, binding) -> Array[StringName]` is not empty:
  - `&""` (`RESOLUTION_NONE`) refuses, and names the conflicting actions;
  - `&"swap"` (Trocar) gives each conflicting action this slot's previous binding. A blank previous binding makes it a replacement.
  - `&"replace"` (Substituir) removes the binding from each conflicting action;
  - `&"cancel"` (Cancelar) always refuses and changes nothing.
- **The result must validate.** A replacement that would leave a required action unbound is refused. So is a swap that moves the old binding into a new conflict, or anything that would move a fixed binding. F16-03 can disable Substituir by trying it on a draft copy.
- **An empty `binding` clears the slot:** a refinement, for blanking an Alternativo. It is refused when it would leave a required action unbound.
- **`restore_action_defaults(profile, action) -> PackedStringArray`** is a row's Redefinir, and a refinement. It is refused, with reasons, when another action now holds one of the defaults and the two cannot share it.
- **`restore_profile_defaults(profile)`** is Restaurar esta aba. `get_default_bindings(profile, action)` gives the default slots of one action.
- **`capture()`** deep-copies both profiles: profile id → action → slots. **`restore(data)`** has these fallbacks:
  - a missing profile or action takes its default silently, so a later new action is defaulted independently;
  - malformed slots fall back to that action's default;
  - a fallen-back (missing or malformed) action leaves out each default input that an action kept from the file holds and cannot share, so the player's remaps survive. A required action that this would leave with no binding takes those inputs back from their holders instead. For example, with `fire` on K and `lock_target` on J, a malformed `fire` falls back to J, which `lock_target` holds. `fire` is required, so it takes J back, `lock_target` is left blank, and every other remap stays. An optional action in `fire`'s place would be left blank instead;
  - an unknown key is reported and ignored;
  - a profile that is still inconsistent afterwards falls back to its defaults. That happens only when the kept bindings conflict with each other, or when a take-back leaves a required holder with no binding.

  Each fallback, each default left out and each take-back returns one diagnostic.
- **Static checks for data from outside:** `check_profile_data(profile, data) -> PackedStringArray` is strict (every action present, and nothing else), and `normalize_profile(data)` normalizes data that passed it.

### Settings: new values

| Key | Type | Default | Accepted |
| --- | --- | --- | --- |
| `camera_input_mode` | StringName | `&"keys"` | `CAMERA_MODE_KEYS` or `CAMERA_MODE_MOUSE` (a String is converted) |
| `mouse_sensitivity` | float, degrees per pixel | 0.12 | finite, clamped to 0.02 to 0.50 (not snapped) |
| `mouse_invert_vertical` | bool | false | bool only |
| `camera_deadzone` | float | 0.2 | finite, clamped to 0.05 to 0.5 (not snapped) |
| `controller_glyph_family` | StringName | `&"auto"` | `GLYPHS_AUTO`, `GLYPHS_XBOX` or `GLYPHS_PLAYSTATION` |

- `camera_sensitivity` and `invert_vertical` keep their meaning: keyboard and stick orbit.
- Getters: `get_camera_input_mode()`, `get_mouse_sensitivity()`, `get_mouse_invert_vertical()`, `get_camera_deadzone()` and `get_controller_glyph_family()`. `get_value`/`set_value` also take the new keys.
- Two fixes for every value:
  - an equal float is compared approximately;
  - a restored value of the wrong type is reported instead of hitting Godot 4.7's mixed-type `!=` error.
- `restore_defaults()`, which is Options' global Defaults, now also resets all five new values and both profiles.

### File schema (`[controls]`, `controls_version=1`)

~~~ini
[controls]
input_device=0
camera_sensitivity=1.0
invert_vertical=false
camera_input_mode=&"keys"
mouse_sensitivity=0.12
mouse_invert_vertical=false
camera_deadzone=0.2
controller_glyph_family=&"auto"
binding_profiles={ &"keyboard_mouse": { &"move_forward": [{ "kind": "key", "code": 87, "axis_sign": 0, "physical": true, "modifiers": 0, "location": 0 }, {}], ... }, &"gamepad": { ... } }
bindings_pending_confirmation=true   ; only while a change waits for Manter controles
confirmed_binding_profiles={ ... }   ; only beside the marker
controls_version=1                   ; written last
~~~

`[audio]` and `[display]` are unchanged. No `InputEvent` and no device index is ever saved.

### Loading (`load_file`, never writes)

- **Old files.** A file without `controls_version` predates F16-02. Its eight values are read as before, and the five new values and both profiles take their defaults silently. The user's real file is in this form, and every boot smoke loads it unchanged. It is only rewritten, in the new form, by the next explicit save (an Options change, Defaults, or F16-03's Aplicar).
- **Version 1.** A missing value or profile is reported and defaulted. Malformed bindings fall back per action, then per profile, as in `restore`, without touching the other values.
- **A malformed version** is read as version 1, and a newer one reads only the known values; each gets one diagnostic.
- **A pending marker.** When `bindings_pending_confirmation` is true, the confirmed profiles are live, never the unconfirmed ones, with one diagnostic. Missing or malformed confirmed profiles mean the defaults. The file keeps its marker until the next save, which harms nothing, because every boot comes back to the same confirmed profiles.
- **The path missing but `<path>.bak` present:** only a crash between the save's two renames leaves this, and the backup is read.

### Saving (`save_file`, `apply_input_bindings`)

1. Everything goes to a fresh ConfigFile. `controls_version` is written last.
2. The file is saved to `<path>.tmp` and loaded back, and `controls_version` is checked.
3. The old file is renamed to `<path>.bak`, the temporary file to the path, and the backup is removed.
4. On any failure the temporary file is removed and the old file stays, or is renamed back, and the Error is returned.

Two renames, because a rename onto an existing file is not atomic on every platform.

### Applying a draft and the pending confirmation (for F16-03)

~~~gdscript
var draft := InputBindings.new()
draft.restore(settings.get_input_bindings().capture())
draft.assign(InputBindings.KEYBOARD_MOUSE, &"ui_accept", 0, adapter.describe_event(event, &"ui_accept"), InputBindings.RESOLUTION_SWAP)
var error := settings.apply_input_bindings(draft, true)  # true: a menu binding changed
~~~

- **`apply_input_bindings(draft, needs_confirmation := false) -> Error`.**
  1. `ERR_INVALID_DATA` unless both profiles of the draft validate.
  2. The file is saved with the draft's profiles. With `needs_confirmation` it also gets the marker and the profiles to return to (the live ones, or the original ones when a change is already pending).
  3. Only after a successful save do the live profiles change, and `changed(BINDING_PROFILES, capture)` fires; `Interface` installs it in the `InputMap`.

  On failure nothing changes, neither the file nor the live map. The caller shows Não foi possível salvar os controles.
- **`confirm_input_bindings() -> Error`** (Manter controles) clears the marker and saves. If that save fails, the live profiles stay, but the next boot comes back to the previous controls; report it.
- **`revert_input_bindings() -> Error`** (Reverter, the timeout, a disconnect, a focus loss) makes the confirmed profiles live at once, then saves. If the save fails, the file's marker still restores them at boot.
- **`is_input_bindings_pending() -> bool`.**
- **`get_input_bindings() -> InputBindings`** is the live instance. It is read-only by contract: editing it directly would skip the save-then-install order.

### `InputBindingAdapter` (owned by `Interface`)

| Member | Meaning |
| --- | --- |
| `apply_profile(profile, data) -> PackedStringArray` | Installs one profile (`capture()[profile]`) and keeps the other's events. Refused, with `InputMap` unchanged, unless `check_profile_data` passes. |
| `apply_bindings(bindings) -> PackedStringArray` | Both profiles at once, or neither (refinement). |
| `apply_defaults()` | Every catalog action back at the `project.godot` events. |
| `describe_event(event, action := &"") -> Dictionary` | Event to normalized descriptor (refinement: the optional action). A key is physical or layout as the action takes it (`uses_physical_keys`); with no action, as the event is written. Axis and sign, without magnitude. Mouse motion, `InputEventAction`, a centred axis and a negative trigger give `{}`. Echo, drift and hold filtering are F16-03's job. |
| `find_default_drift() -> PackedStringArray` | Compares the catalog defaults with `ProjectSettings` `input/<action>` events. `Interface` reports each drift with `push_error` in editor builds, so the boot smoke fails on it. |

- Each catalog action's events are its keyboard-and-mouse slots, its gamepad slots and its fixed bindings, all with device −1. So any pad index works and a reconnect keeps the profile.
- Deadzones are never changed, so an axis keeps its analog strength (`get_vector`, `get_axis`, `get_action_strength`). A button bound to movement is digital, as before.
- Only an action whose events differ, or that has a device-bound event, is rewritten, and it is then released with `Input.action_release`, so a key held through the change cannot stay pressed.
- Actions outside the catalog are never touched.

### Wiring in `Interface`

- **`_ready`,** right after `load_file()`: in an editor build `find_default_drift()` runs, then `apply_bindings(settings.get_input_bindings())`. This is before the HUD and the menus are instanced, so no menu accepts input on the old map.
- **`Settings.changed`** with `BINDING_PROFILES` reinstalls both profiles. That covers `apply_input_bindings`, `revert_input_bindings`, `restore_defaults` and `restore`.
- **`_exit_tree`** calls `apply_defaults()`: the `InputMap` is process-wide, and the suite builds `main.tscn` again and again.
- **`get_input_binding_adapter()`** returns the adapter.

### Verification (no tests: the F16 rule)

- The existing suite passed: 225 tests, and no script, parse or compile error.
- The 300-frame headless boot of `main.tscn` printed no ERROR or WARNING line.
- `check_resources.gd --strict-validate` passed: 82 resources, 83 scripts.
- The user's real `settings.cfg` (old form) was not rewritten; its timestamp is unchanged.
- The drift check was proven live: one default was temporarily broken (`ui_up` on W), and the boot reported exactly that action with both event lists. It was reverted, and the check is clean on the real defaults, built-in `ui_*` events included.
- The rest was checked by reading: see [validation/controls-expansion.md](../validation/controls-expansion.md) "Binding profiles and persistence".

## F16 binding labels and prompt family (F16-08)

Delivered in lane oc-a on 2026-09-24, carved out of F16-03, so that trunk's controls workflow only consumes it. It adds a Node-free label table and extends `InputDeviceState` with controller-family detection. No existing function, signal or behavior of `InputDeviceState` changed: `menu_controller.gd` and F15-07's footers keep working.

### `BindingLabels` (`scripts/ui/binding_labels.gd`, Rules Core, `class_name BindingLabels extends RefCounted`)

Static only, no state, never asserts. It reads the F16 primitive descriptor `{kind, code, axis_sign, physical, modifiers}`, where `kind` is `"key"`, `"mouse_button"`, `"joy_button"` or `"joy_axis"`, under the prompt family `&"keyboard_mouse"`, `&"xbox"` or `&"playstation"`.

| Member | Meaning |
| --- | --- |
| `UNBOUND` | `"—"`, the layout's unbound label; a malformed or unknown descriptor describes as it. |
| `describe(binding, family) -> String` | Readable text for one descriptor. A physical key goes through `DisplayServer.keyboard_get_label_from_physical` then `OS.get_keycode_string`; a non-physical key through `OS.get_keycode_string`. The `modifiers` mask prefixes `Shift+`, `Ctrl+`, `Alt+` and `Meta+`, and a standalone modifier key is its own label, never `Shift+Shift`. A short Portuguese table maps Space → `Espaço`, Escape → `Esc` and the four arrows → `Seta ←/→/↑/↓`; Enter, Tab, Shift, Ctrl and Alt stay as Godot names them. Mouse buttons map 1–9 to `Mouse 1`–`Mouse 3`, `Roda ↑/↓/←/→` and `Mouse 4/5`. Joypad buttons map by family (Xbox `A/B/X/Y`, `View/Xbox/Menu`, `LS/RS`, `LB/RB`; PlayStation `✕/○/□/△`, `Create/PS/Options`, `L3/R3`, `L1/R1`; D-pad `↑↓←→` in both), and unknown indices are `Botão %d`. Axes 0–3 are `Analógico esq./dir.` with the sign's arrow, axis 4/5 are `LT/RT` or `L2/R2`. |
| `glyph_id(binding, family) -> StringName` | Astra's stable glyph id (`xbox_*`, `ps_*`, `dpad_*`, `stick_*`) or `&""` when there is none: keys, mouse buttons, the Guide/PS button and the `keyboard_mouse` family. |
| `glyph_path(id) -> String` | `res://assets/ui/controls/glyphs/<id>.png`, the file convention F16-01 names its glyphs by; an empty id gives an empty path. F16-03 falls back to `describe()` text when `ResourceLoader.exists()` is false. |

### `InputDeviceState` additions

| Member | Meaning |
| --- | --- |
| `signal prompt_family_changed(family: StringName)` | The prompt family changed. Emitted only on a change, from an event, a pad connection change or an override change. |
| `set_glyph_override(family: StringName)` | `&"auto"`, `&"xbox"` or `&"playstation"`; anything else is treated as `&"auto"`. |
| `get_prompt_family() -> StringName` | `&"keyboard_mouse"` while `shows_keyboard_prompts()` is true; otherwise the override when one is set; otherwise, for `&"auto"`, `&"playstation"` when the last pad's lowercased `Input.get_joy_name()` contains `playstation`, `ps3`, `ps4`, `ps5`, `dualsense`, `dualshock`, `sony` or `wireless controller`, and `&"xbox"` otherwise. The last pad's device id is kept in memory only, never in settings. |
| Mouse use | A mouse button press counts as keyboard/mouse activity at once; mouse motion counts only once its accumulated relative length since the last gamepad event passes `MOUSE_MOTION_THRESHOLD` (8 px), so jitter cannot flip the prompts. Keys, joypad buttons and sticks are unchanged. |

### Wiring for F16-03

`Interface` keeps the one `InputDeviceState`. F16-03 reads `get_prompt_family()` to choose between text caps and the glyph family, connects `prompt_family_changed` to re-render prompts, and drives `set_glyph_override` from Options' "Ícones do controle". The glyph files are Astra's (F16-01); a missing file uses `describe()` text.

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
