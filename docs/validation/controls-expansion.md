# F16 controls, camera and dash: validation record

These are manual records only (spec, "Verification and completion"). Each one names the device and backend actually used, what was observed, and pass, fail or not verified. Synthetic input never certifies a physical device, and an unavailable device stays not verified. Each ticket fills only its own section below, so parallel lanes merge cleanly. Do not reorder or merge sections.

## Layout and components (F16-01, sol)

**Static scene inspection: pass.** Godot 4.7.2, Windows, OpenGL Compatibility on AMD Radeon RX 9070 XT. The screen was rendered directly at each viewport size:

| Viewport | Capture | Observation |
| --- | --- | --- |
| 1280×720 | [PNG](controls-expansion/controls-1280x720.png) | 48 px side margins; 32 px heading; tabs at y=104; panel y=158–606; scroll ends above help; footer below y=628. No cropped columns or footer overlap. |
| 1600×900 | [PNG](controls-expansion/controls-1600x900.png) | Centered 1280 px content frame; columns and buttons remain legible. |
| 1920×1080 | [PNG](controls-expansion/controls-1920x1080.png) | Centered frame; illustrated background expands without moving the footer over content. |

**Widget inventory:** `Controls` keeps `menu_controller.gd`, `Layout/BackButton` and `Layout/NavigationHint`. `Layout/ControlsPanel/Tabs` has `KeyboardMouse`, `Gamepad`, `Camera`; the panel also has `DeviceFamily`, `BindingScroll/Rows`, `ActionHelp`, and `CameraSettings/{Mode,MouseSensitivity,OrbitSensitivity,MouseInvert,OrbitInvert,Deadzone}`. The fixed footer adds `Layout/RestoreTabButton` and `Layout/ApplyButton`. `Overlays` has `CaptureDialog`, `ConflictDialog`, `DirtyDialog`, `ConfirmBindingsDialog`, each with `Title`, `Message`, `Buttons`. The reusable scenes expose `BindingRow/{ActionLabel,PrimaryButton,SecondaryButton,ResetButton}`, `DashCooldown/{Label,Progress,ReadyAccent}`, and `DashVisual/{TrailLeft,TrailRight,ProtectionAccent}`.

The six `Preview*` rows show the authored idle layout and overflow. F16-03 removes or replaces those rows when it populates the action catalog. The camera panel and dialogs are hidden until the future adapter shows them. The row template has a cyan outline on keyboard/controller focus and 44 px minimum buttons; long action text truncates with a tooltip, the secondary slot uses `—`, and the reset button has both an icon and a text tooltip. `ActionHelp` supplies the focused action description.

The existing MenuController still selects BackButton on entry, preserving the current menu contract and caller focus restoration. F16-03 takes ownership of the specified tabs → rows → footer focus order when it wires the workflow.

**State copy and treatment:** idle uses the dark panel; focused uses the cyan outline; listening uses `CaptureDialog` with an explicit countdown; conflict uses `ConflictDialog`; unbound secondary is `—`; changed draft is represented by the later adapter's changed label and Apply state; save failure uses the dialog Message and a retained draft; confirmation uses `ConfirmBindingsDialog` countdown; cooldown uses the cyan Progress bar with `Label` switching from `PRONTO` to a time value; disabled uses muted Label/Progress; restored default returns to the unmodified row and ready accent. These are authored visual contracts; state transitions and text updates belong to F16-03/F16-05.

All 36 original controller glyph PNGs use the F16-08 IDs under `res://assets/ui/controls/glyphs/`. They have visible text abbreviations, while F16-08's `describe()` supplies a text fallback if a texture is missing. The dash scene is unshaded translucent cyan mesh behind the ship, without collision or a script; Claude controls its lifetime. No external assets were used. Physical devices, remapping, save failure and dash feel are **not verified** by these static captures.

## Binding profiles and persistence (F16-02, trunk)

2026-09-24, Claude (trunk). Windows 11, Godot 4.7.2 editor binary headless, no physical device. The contract is in [settings.md "F16 binding profiles and persistence"](../engineering/settings.md#f16-binding-profiles-and-persistence-f16-02).

**Run (existing gate pieces only, no test or driver written).**

| Check | Result |
| --- | --- |
| `tools/test.ps1`, the existing suite | pass: 225 passed, 0 failed, no script, parse or compile error |
| 300-frame headless boot of `main.tscn` | pass: no ERROR or WARNING line |
| `check_resources.gd --strict-validate` | pass: 82 resources, 83 scripts |
| The catalog defaults against `project.godot` and Godot's built-in `ui_*` events (`find_default_drift`, run by every editor-build boot) | pass. It was proven live by breaking `ui_up` to W for one boot: exactly that action was reported, then the break was reverted. |
| The defaults are valid profiles (every boot runs `check_profile_data` on both) | pass |
| The real `user://settings.cfg` (old, eight-value form) after the suite and the boots | pass: not rewritten, timestamp unchanged |

**Checked by reading (not executed).**

- **Migration.** A file without `controls_version` keeps its eight values, and gets the five new values and both profiles at their defaults, with no diagnostic and no write.
- **Per-action fallback.** One malformed action falls back to its own default and leaves the other actions and the other profile alone:
  - a non-Array or over-long slot list;
  - an unknown kind or field, or a wrong-typed field;
  - a code out of range, a key code no key reports (a control character, an unassigned special code, `KEY_UNKNOWN`), a sign on a non-axis, or a negative trigger;
  - a joypad descriptor in the keyboard profile;
  - a required action left blank.

  A missing or malformed action's default never undoes a remap (review fix): each default input that a kept action holds is left out, and a required action that would be left unbound takes it back from the holder instead (`fire` malformed after a K/J swap with `lock_target`: `fire` gets J back, `lock_target` is blank, the other remaps stay). A profile still inconsistent after that falls back as a whole, which now needs the file's own bindings to conflict or a take-back to leave a required holder unbound. Unknown actions and profiles are reported and ignored.
- **Known limit, for F16-03.** `pause` takes physical keys and the menu-only actions take layout keys, and the Node-free core compares them by code. That is exact for the special keys on any layout and for every key on US QWERTY, but not for character keys on another layout (AZERTY `pause` on physical Q and `ui_accept` on layout A are one key, not reported). F16-03's capture compares them in the layout's space.
- **Transactions.**
  - Swap and Replace work on a deep copy, and are committed only when the whole profile validates.
  - Replace is refused when it leaves a required action (every menu action, movement, fire, pause) unbound.
  - A swap that moves the old binding into a new conflict is refused.
  - Cancel changes nothing.
  - Opposite axis signs never conflict, and `pause`/`ui_cancel` sharing Escape stays valid.
- **Save.** The temporary file is written and read back, then the old file is moved to `.bak` and the temporary file renamed into place. A failure keeps or restores the old file and returns the Error, and `apply_input_bindings` changes the live profiles only after `OK`.
- **Pending recovery.** The marker and the confirmed profiles are saved before the unconfirmed profiles go live. A boot with the marker set uses the confirmed profiles, or the defaults when they are malformed, never the unconfirmed ones.
- **Device index.** Every installed event has device −1 and no descriptor has a device field, so a reconnect with another index keeps the profile.

**Needs the human pass (not verified).**

- **Restart persistence.** Remap through F16-03 once it exists, quit, relaunch: the exact bindings return. Until F16-03, only the Options values can be changed; change one, relaunch, and check that the new-format file keeps the old values.
- **Old-file migration.** Keep the current eight-value `settings.cfg`, boot, and change one Options value: audio, display, camera sensitivity and invert are unchanged, and the new keys appear with their defaults.
- **A crash during unconfirmed application.** After F16-03: apply a menu remap, kill the process inside the 10-second countdown, relaunch. The previous controls are live, and one boot warning says so.
- **A device-index change.** Unplug a pad, plug in another (or the same one on another port) and drive the menus and the ship. The bindings still apply, and the pad follows the gamepad profile, not a device slot.
- **Physical Xbox, DualShock and DualSense feel** (analog movement and camera through a remap) belongs to F16-07.

## Binding labels and prompt family (F16-08, oc-a)

No test or driver script: the ticket forbids them. Verified on 2026-09-24 by reading the code against the spec and the ticket, and by the lane gate.

- `BindingLabels` is static and Node-free, holds no state and never asserts: `describe()` and `glyph_id()` parse `kind` and `code` first, and a malformed or unknown descriptor returns `—` and `&""`.
- The key path follows the ticket exactly: a physical key through `DisplayServer.keyboard_get_label_from_physical` then `OS.get_keycode_string`, a non-physical key through `OS.get_keycode_string`. The modifier prefix skips the key's own family, so a standalone modifier is never `Shift+Shift`, and the Portuguese table covers Space/Escape and the four arrows.
- The mouse button map, both per-family joypad button tables, the D-pad range, the `Botão %d` fallback, the stick/trigger labels and every glyph id match the ticket's tables.
- `glyph_path()` matches the file convention F16-01 was told to name its glyphs by, and an empty id gives an empty path.
- `InputDeviceState` keeps every existing function, signal and behavior. `prompt_family_changed` fires only on a real change; the override accepts only `auto`/`xbox`/`playstation`; the last pad id is memory only; a mouse button counts at once and mouse motion only past 8 px accumulated since the last gamepad event.
- `tools/lane.ps1 land` is the gate: the existing suite, the 300-frame boot smoke and the resource check (82 scripts) pass.
- Physical Xbox and PlayStation behaviour, and the glyph art itself, are the F16-07 device pass; this ticket does not claim them.

## Rebinding workflow and prompts (F16-03, trunk)

Pending.

## Mouse camera and recenter (F16-04, path)

- **Date and scope:** 2026-09-24, lane path, `scripts/player/camera_rig.gd` only.
- **Devices:** none. No physical mouse, stick or display was exercised.
- **Method:** code reading plus the existing gate on Windows 11 with Godot 4.7.2: `tools/test.ps1` passed 225 tests with 0 failed, including all eleven `test_camera_rig_contract.gd` cases, and `check_resources.gd --strict-validate` showed 82 resources and 81 scripts, none failed. No new tests or drivers (sprint rule).
- **Why the arena was not exercised:** in mouse mode, `set_mouse_capture_active` and `request_recenter` are called only by F16-06's code, and no such caller exists yet.

| Check | How | Result |
| --- | --- | --- |
| Default Teclas behaves as before | Reading: capture is off and the mode is keys, so no mouse motion is collected, `_look_override` stays 0, the pull factor is unchanged, and `stick_deadzone` 0.2 equals the implicit average of the four actions' 0.2 deadzones. Gate: rest pose, orbit rate, inversion, lock framing, release, horizon and obstruction contract tests pass | pass (existing gate) |
| Pinned values | follow_distance 8.5, follow_height 3.2 and default pitch -9° are unchanged; no roll is written anywhere (`_apply_camera_transform` still builds `(pitch, yaw, 0)`) | pass (reading) |
| Mouse turn is independent of render and tick rate | Reading: motion accumulates in `_input` and is spent once per physics tick as pixels × degrees per pixel, never multiplied by delta; ticks with nothing pending add 0 | pass (reading); physical feel not verified |
| Mouse inversion is independent of stick inversion | Reading: `mouse_invert_vertical` applies to the mouse term only, `invert_vertical` to the action term only | pass (reading); not verified on a device |
| No stale jump after clearing | Reading: `clear_pending_look`, `set_mouse_capture_active` (every call) and `apply_control_settings` zero `_pending_look`, and collection requires mouse mode and capture on | pass (reading); the capture-warp timing on a real backend is pending F16-06 |
| Recenter across the yaw wrap | Reasoning below | pass (reading) |
| Recenter from both pitch limits | Reasoning below | pass (reading) |
| Locked recenter and look keep the lock | Reading: neither path writes `_lock_target`; only `set_lock_target`, `clear_lock_target` and a freed target change it | pass (reading) |
| Obstruction still wins | Reading: `_clear_distance` runs every tick on the desired position computed from the recentered or mouse-turned angles, and `_process` still caps at once | pass (reading); contract test for obstruction passes |
| Jitter or look split is independent of frame rate (review fix) | Reading: deliberate means the tick's motion is above `mouse_jitter_speed` × the real seconds since the previous tick, which is the span the motion was collected over. At 30 fps the tick that spends a frame's motion also measures a frame, and the next tick has no motion; at 60 fps and above each tick measures the frames it spends | pass (reading); not verified on a device |
| Manual input interrupts; repeats restart and do not queue | Reading: after the 0.1 s grace, a non-zero action vector or deliberate mouse clears `_recentering` before the pull; `request_recenter` resets the elapsed time and holds no queue | pass (reading) |
| The press that requests a recenter cannot cancel it (review fix) | Reading: while `_recenter_elapsed` is under `recenter_grace_seconds`, the recenter branch runs whatever the input, so a Mouse 3 nudge or an R3 tilt is dropped, and the look hold is not armed by it. Whether 0.1 s covers a real wheel click, release included, needs a device | pass (reading); grace length pending F16-07 |
| Session lifecycle: capture on Pause, focus and Resume, settings at spawn and Retry, `camera_recenter` wiring | Owned by F16-06 | pending F16-06, not passed |
| Physical mouse and controller feel, including high-refresh stepping at the 60 Hz tick | Needs devices | not verified (F16-07) |

**Yaw wrap.** Each tick starts from `global_rotation.y`, which is in [-π, π], and `lerp_angle` moves by `angle_difference`, the signed shortest difference.

- From +170° toward a goal of -170°: `d = fmod(-340°, 360°) = -340°`, and `fmod(2d, 360°) - d = -320° + 340° = +20°`. The camera turns 20° through ±180°, not 340° back.
- From -170° toward +170°: the result is -20°.
- At exactly 180° the first step picks one side. Every later step then sees less than 180° remaining, so the direction cannot flip.

The yaw value may leave [-π, π] inside a tick. It is written as `Basis(Vector3.UP, yaw)` and read back wrapped, so the wrap costs nothing.

**Pitch limits.** `_pitch` starts clamped. Every action and mouse write passes through `_clamped_pitch`.

- A recenter moves the pitch with `lerpf(_pitch, goal, weight)`, from one in-range value to another.
- The goal is clamped: the free goal is -9°, inside (-60°, 35°), and the locked goal comes from `_framing_pitch`, which clamps.
- `weight = (after - before) / (1 - before)` stays in [0, 1], because smoothstep never decreases and `after < 1` on that branch. The pitch therefore stays inside the limits at every step.
- From the floor the pitch travels 51° up to -9°; from the ceiling it travels 44° down.

## Lateral dash (F16-05, rescue)

Pending.

## Integrated walkthrough (F16-06, trunk)

Pending.

## Visual and device acceptance (F16-07, sol)

Pending.
