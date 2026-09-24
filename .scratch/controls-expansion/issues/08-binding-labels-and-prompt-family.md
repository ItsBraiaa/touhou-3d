# F16-08 binding-labels-and-prompt-family

Status: todo
Type: core+adapter
Owner: OpenCode
Lane: oc-a
Model: DeepSeek V4.1 Flash
Depends on: F16-00
Parallel-safe: yes. No other running F16 ticket touches these files.

## Read first

- [Spec](../spec.md): "Binding coverage and profiles" (labels, glyph families, device preference) and "Proposed engineering seams" (the binding descriptor).
- `scripts/ui/input_device_state.gd`, and its caller `scripts/ui/menu_controller.gd` (read only).
- `docs/engineering/settings.md`, "Input device and disconnect (F3-03)".

## Goal

This ticket carves the small, self-contained labels and prompt-family work out of F16-03, so that trunk's controls workflow only has to consume it. It has two parts:

- a Node-free label table for binding descriptors;
- controller-family detection in the existing `InputDeviceState`.

## Files

- **Creates:** `scripts/ui/binding_labels.gd` (and its `.uid`).
- **Edits:** `scripts/ui/input_device_state.gd`. Additions only: the existing functions, signal and behavior stay as they are, because `menu_controller.gd` and F15-07's footers use them.
- **Docs:**
  - `docs/engineering/settings.md`: only the section "F16 binding labels and prompt family (F16-08)";
  - `docs/validation/controls-expansion.md`: only its F16-08 section.
- **At session end:** this ticket's Outcome, its `docs/engineering/ROADMAP.md` row, and one `docs/HANDOFF_LOG.md` entry, newest first.
- **Must not touch:** `interface.gd`, `menu_controller.gd`, `settings.gd`, `input_bindings.gd`, `input_binding_adapter.gd`, `project.godot`, and every scene. Other lanes are editing them.

## Deliverables

### 1. `class_name BindingLabels extends RefCounted` (static functions only)

The binding descriptor comes from the spec: `{kind, code, axis_sign, physical, modifiers}`, where `kind` is `"key"`, `"mouse_button"`, `"joy_button"` or `"joy_axis"`. The family is `&"keyboard_mouse"`, `&"xbox"` or `&"playstation"`.

**`static func describe(binding: Dictionary, family: StringName) -> String`** returns readable text for one descriptor.

- **Keys:**
  - A physical key goes through `DisplayServer.keyboard_get_label_from_physical(code)`, then `OS.get_keycode_string()`. A non-physical key uses `OS.get_keycode_string(code)`.
  - The `modifiers` mask adds the prefixes `Shift+`, `Ctrl+`, `Alt+` and `Meta+`. A standalone modifier key (Left Shift, Left Ctrl) is its own label, never `Shift+Shift`.
  - A short Portuguese table covers the names Godot gives in English: Space → `Espaço`, Escape → `Esc`, the arrows → `Seta ←`, `Seta →`, `Seta ↑` and `Seta ↓`. Enter, Tab, Shift, Ctrl and Alt stay as they are.
- **Mouse buttons:** 1 `Mouse 1`, 2 `Mouse 2`, 3 `Mouse 3`, 4 `Roda ↑`, 5 `Roda ↓`, 6 `Roda ←`, 7 `Roda →`, 8 `Mouse 4`, 9 `Mouse 5`.
- **Joypad buttons**, by family (Godot `JoyButton` indices):

  | Index | xbox | playstation |
  | --- | --- | --- |
  | 0 | A | ✕ |
  | 1 | B | ○ |
  | 2 | X | □ |
  | 3 | Y | △ |
  | 4 (BACK) | View | Create |
  | 5 (GUIDE) | Xbox | PS |
  | 6 (START) | Menu | Options |
  | 7 | LS | L3 |
  | 8 | RS | R3 |
  | 9 | LB | L1 |
  | 10 | RB | R1 |

  11 to 14 are `D-pad ↑`, `D-pad ↓`, `D-pad ←` and `D-pad →`, in both families. Any other index is `Botão %d`.
- **Joypad axes:**
  - Axes 0 and 1 are `Analógico esq.` and axes 2 and 3 are `Analógico dir.`, followed by the arrow for the sign: axis 0 or 2 negative `←`, positive `→`; axis 1 or 3 negative `↑`, positive `↓`.
  - Axis 4 is `LT` / `L2`, and axis 5 is `RT` / `R2`.
- **Malformed or unknown descriptors** return `—`, the layout's unbound label. `describe()` never asserts or errors on bad data.

**`static func glyph_id(binding: Dictionary, family: StringName) -> StringName`** returns a stable id for Astra's glyph file, or `&""` when there is none (keys and mouse use text caps). The ids:

- **xbox:** `xbox_a`, `xbox_b`, `xbox_x`, `xbox_y`, `xbox_view`, `xbox_menu`, `xbox_lb`, `xbox_rb`, `xbox_lt`, `xbox_rt`, `xbox_ls`, `xbox_rs`;
- **playstation:** `ps_cross`, `ps_circle`, `ps_square`, `ps_triangle`, `ps_create`, `ps_options`, `ps_l1`, `ps_r1`, `ps_l2`, `ps_r2`, `ps_l3`, `ps_r3`;
- **both families:** `dpad_up`, `dpad_down`, `dpad_left`, `dpad_right`, `stick_left_left`, `stick_left_right`, `stick_left_up`, `stick_left_down`, `stick_right_left`, `stick_right_right`, `stick_right_up` and `stick_right_down`.

**`static func glyph_path(id: StringName) -> String`** returns `"res://assets/ui/controls/glyphs/%s.png" % id`. This is the file convention F16-01 names its glyphs by. F16-03 falls back to `describe()` text when `ResourceLoader.exists()` is false.

### 2. `InputDeviceState` additions

- **`set_glyph_override(family: StringName) -> void`** takes `&"auto"`, `&"xbox"` or `&"playstation"`; anything else is treated as `&"auto"`.
- **`get_prompt_family() -> StringName`:**
  - It is `&"keyboard_mouse"` while `shows_keyboard_prompts()` is true.
  - Otherwise it is the override, when one is set.
  - Otherwise, for `&"auto"`, it comes from `Input.get_joy_name()` of the last pad that sent an event. The lowercased name containing `playstation`, `ps3`, `ps4`, `ps5`, `dualsense`, `dualshock`, `sony` or `wireless controller` means `&"playstation"`; any other name means `&"xbox"`.
  - Remember the last pad's device id in memory only, never in settings.
- **`signal prompt_family_changed(family: StringName)`** is emitted only when the value of `get_prompt_family()` really changes. That can follow an event, a pad connection change or an override change.
- **Meaningful mouse use:**
  - A mouse button press counts as keyboard/mouse activity at once.
  - Mouse motion counts only after its accumulated relative length since the last gamepad event exceeds 8 px, so jitter never flips the prompts. Read how `note_event` treats the mouse today first.
  - Keys and joypad handling stay unchanged.

## Verification (no tests: the F16 rule)

- Write no tests and no test or driver scripts.
- `tools/lane.ps1 land` is the gate: the existing suite, the boot smoke and the resource check.
- In the F16-08 validation section, record what was checked by reading the code, and that the physical Xbox and PlayStation checks belong to F16-07.

## Definition of Done

`land` passes. Document `BindingLabels` and the new `InputDeviceState` API in the settings.md section. The ticket is `Status: done` with an Outcome, the ROADMAP row is updated, and one handoff entry is written. One commit: `(F16-08) binding labels and prompt family`.

## Kickoff prompt

```
Model: DeepSeek V4.1 Flash. You are lane oc-a. Work only in C:\Users\Braia\Documents\touhou-3d-oc-a. First run: powershell -NoProfile -ExecutionPolicy Bypass -File tools\lane.ps1 sync. Read AGENTS.md and .scratch/controls-expansion/issues/08-binding-labels-and-prompt-family.md, then implement that ticket exactly. Strictly typed GDScript; warnings are errors (untyped declarations, unused variables or parameters, shadowing). No tests of any kind and no test or driver scripts. Finish with the ticket's Definition of Done: one commit, then powershell -NoProfile -ExecutionPolicy Bypass -File tools\lane.ps1 land. If land fails twice, stop and paste its output.
```

## Outcome

Not started.
