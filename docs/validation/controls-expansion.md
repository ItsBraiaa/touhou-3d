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

**State copy and treatment:** idle uses the dark panel; focused uses the cyan outline; listening uses `CaptureDialog` with an explicit countdown; conflict uses `ConflictDialog`; unbound secondary is `—`; changed draft is represented by the later adapter's changed label and Apply state; save failure uses the dialog Message and a retained draft; confirmation uses `ConfirmBindingsDialog` countdown; cooldown uses the cyan Progress bar with `Label` switching from `PRONTO` to a time value; disabled uses muted Label/Progress; restored default returns to the unmodified row and ready accent. These are authored visual contracts; state transitions and text updates belong to F16-03/F16-05.

All 36 original controller glyph PNGs use the F16-08 IDs under `res://assets/ui/controls/glyphs/`. They have visible text abbreviations, while F16-08's `describe()` supplies a text fallback if a texture is missing. The dash scene is unshaded translucent cyan mesh behind the ship, without collision or a script; Claude controls its lifetime. No external assets were used. Physical devices, remapping, save failure and dash feel are **not verified** by these static captures.

## Binding profiles and persistence (F16-02, trunk)

Pending.

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

Pending.

## Lateral dash (F16-05, rescue)

Pending.

## Integrated walkthrough (F16-06, trunk)

Pending.

## Visual and device acceptance (F16-07, sol)

Pending.
