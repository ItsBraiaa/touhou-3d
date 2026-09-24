# F16 controls, camera and dash: validation record

These are manual records only (spec, "Verification and completion"). Each one names the device and backend actually used, what was observed, and pass, fail or not verified. Synthetic input never certifies a physical device, and an unavailable device stays not verified. Each ticket fills only its own section below, so parallel lanes merge cleanly. Do not reorder or merge sections.

## Layout and components (F16-01, sol)

Pending.

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
