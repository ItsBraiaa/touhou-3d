# F16-10 spec-api-list-matches-shipped-code

Status: done
Type: docs
Owner: OpenCode
Lane: oc-b
Model: DeepSeek V4.1 Flash
Depends on: F16-06
Parallel-safe: yes. Docs only; F16-07 (sol) and F16-09 (oc-a) do not edit `spec.md`.

## Problem

`.scratch/controls-expansion/spec.md` has a block, "Proposed APIs for the implementation tickets", written before any code existed. F16-02 to F16-06 and F16-08 shipped real APIs that differ from it in places. For example, F16-05's `DashModel` and `PlayerController` additions are missing, which F16-05 and F16-06 both recorded as a follow-up. That block is where the next reader looks, so it must match the code.

## Work

1. Read the block (from the line "Proposed APIs for the implementation tickets:" to the end of its `~~~text` fence) and the paragraph after it.
2. For every class the block names, read the real public API in the code: `class_name`, public `func` and `signal` lines, and public constants other tickets use. Skip anything that starts with `_`.

   | Class | File |
   | --- | --- |
   | `Settings` | `scripts/settings/settings.gd` |
   | `InputBindings` | `scripts/settings/input_bindings.gd` |
   | `InputBindingAdapter` | `scripts/ui/input_binding_adapter.gd` |
   | `Interface` | `scripts/ui/interface.gd` (only its F16 additions) |
   | `ControlsScreen` | `scripts/ui/controls_screen.gd` |
   | `BindingLabels` | `scripts/ui/binding_labels.gd` |
   | `InputDeviceState` | `scripts/ui/input_device_state.gd` (F16 additions) |
   | `CameraRig` | `scripts/player/camera_rig.gd` (F16 additions) |
   | `DashModel` | `scripts/player/dash_model.gd` |
   | `PlayerController` | `scripts/player/player_controller.gd` (dash signals and functions) |
   | `CombatState.grant_invulnerability` | `scripts/combat/combat_state.gd` |

   Cross-check with the F16 sections of `docs/engineering/settings.md`, `player-flight.md` and `combat-hud.md`, which the implementers wrote.
3. Rewrite the block as the shipped contract, one line per public member, in its existing form (`Class.method(args: Type) -> Return`, `Class.name(args) signal`):
   - Keep lines that are still true.
   - Correct changed signatures, add missing public members that F16 introduced, and drop members that do not exist, each with a short `# was: ...` note at the end of the line.
   - Keep F16 APIs only; do not list the pre-F16 API.
4. Change the heading line to "Shipped APIs (F16-02 to F16-08, checked against the code 2026-09-24):". Also change the paragraph right after the block: its "Claude may refine seams..." sentence becomes one sentence saying the list was reconciled with the code by F16-10.
5. Change nothing else in `spec.md`: the product rules and the layout contract are Astra's.

## Files

- **Edits:** `.scratch/controls-expansion/spec.md`, only the API block, its heading line and the paragraph after it. Astra owns the spec, so the commit is tagged `[shared]`.
- **At session end:** this ticket's Outcome, its `docs/engineering/ROADMAP.md` row, and one `docs/HANDOFF_LOG.md` entry addressed to Astra, newest first.
- **Must not touch:** any code, scene or test, and every other doc.

## Verification (no tests)

- Write no tests and no scripts.
- For each changed line, the Outcome names the file and function it was checked against.
- `tools/lane.ps1 land` is the gate.

## Definition of Done

`land` passes. The ticket is `Status: done` with an Outcome, the ROADMAP row is updated, and one handoff entry is written. One commit: `(F16-10) spec API list matches the shipped code [shared]`.

## Kickoff prompt

```
Model: DeepSeek V4.1 Flash. You are lane oc-b. Work only in C:\Users\Braia\Documents\touhou-3d-oc-b. First run powershell -NoProfile -ExecutionPolicy Bypass -File tools\lane.ps1 sync. Read AGENTS.md and .scratch/controls-expansion/issues/10-spec-api-list-matches-shipped-code.md, then do that ticket exactly: docs only, no code, scene or test changes, no tests or scripts. Finish with the ticket's Definition of Done: one commit, then powershell -NoProfile -ExecutionPolicy Bypass -File tools\lane.ps1 land. If land fails twice, stop and paste its output.
```

## Outcome

Done 2026-09-24 (lane oc-b, DeepSeek V4.1 Flash). One commit `(F16-10) spec API list matches the shipped code [shared]`.

`.scratch/controls-expansion/spec.md`, the "Proposed APIs for the implementation tickets" block and its heading, plus the paragraph after it. The heading is now "Shipped APIs (F16-02 to F16-08, checked against the code 2026-09-24):", the last sentence of the following paragraph is now "This list was reconciled with the code by F16-10.", and nothing else in `spec.md` changed.

Kept unchanged (proposal already matched): `Settings.get_input_bindings`, `get_camera_input_mode`, `get_mouse_sensitivity`, `get_mouse_invert_vertical`, `get_camera_deadzone`, `get_controller_glyph_family`, `apply_input_bindings`, `confirm_input_bindings`, `revert_input_bindings`, `is_input_bindings_pending` (`scripts/settings/settings.gd`); `Interface.get_input_binding_adapter` (`scripts/ui/interface.gd`); `InputBindings.capture`, `restore`, `get_bindings`, `find_conflicts`, `validate_profile`, `restore_profile_defaults`, `restore_action_defaults`, `parse_binding`, `same_input`, `can_share`, `uses_physical_keys`, `get_contexts`, `is_required`, `get_category`, `get_label`, `get_actions`, `CATALOG` (`scripts/settings/input_bindings.gd`); `InputBindingAdapter.apply_profile`, `apply_bindings`, `describe_event` (`scripts/ui/input_binding_adapter.gd`); `ControlsScreen.setup` (`scripts/ui/controls_screen.gd`); `CameraRig.request_recenter` (`scripts/player/camera_rig.gd`); `DashModel.configure`, `try_start`, `tick`, `cancel`, `get_active_time_left`, `get_cooldown_left` (`scripts/player/dash_model.gd`); `CombatState.grant_invulnerability` (`scripts/combat/combat_state.gd`); `PlayerController.dash_started`, `dash_ended`, `dash_cooldown_changed` (`scripts/player/player_controller.gd`).

Corrected signatures:
- `InputBindings.assign` (`scripts/settings/input_bindings.gd:427`): default is `resolution: StringName = RESOLUTION_NONE`, not `&""` (same value, the named constant); note added.
- `CameraRig.apply_control_settings` (`scripts/player/camera_rig.gd:231`): parameters are `p_mode, p_mouse_sensitivity, p_mouse_invert, p_deadzone`; note added.
- `InputBindings.get_default_bindings` / `get_fixed_bindings` (`scripts/settings/input_bindings.gd:301,313`): full typed parameters; note added.

Added (F16 public members missing from the proposal, all `# was: not listed`):
- `Settings` F16 keys and constants (`scripts/settings/settings.gd`: `CAMERA_INPUT_MODE` 38, `MOUSE_SENSITIVITY` 39, `MOUSE_INVERT_VERTICAL` 40, `CAMERA_DEADZONE` 41, `CONTROLLER_GLYPH_FAMILY` 42, `BINDING_PROFILES` 45, `CONTROLS_VERSION` 29, `CONTROL_KEYS` 53, `CAMERA_MODE_KEYS` 63, `CAMERA_MODE_MOUSE` 65, `CAMERA_INPUT_MODES` 66, `GLYPHS_AUTO`/`GLYPHS_XBOX`/`GLYPHS_PLAYSTATION` 74–76, `GLYPH_FAMILIES` 77, `MOUSE_SENSITIVITY_MIN`/`MAX` 68–69, `DEADZONE_MIN`/`MAX` 71–72).
- `InputBindings.default_profiles` 240, `profile_for` 173, `check_profile_data` 323, `normalize_profile` 352, `key_binding` 140, `mouse_button_binding` 145, `joy_button_binding` 150, `joy_axis_binding` 156, and the constants `CATEGORIES` 56, `CATEGORY_LABELS` 57, `KEYBOARD_MOUSE`/`GAMEPAD` 26–27, `PROFILES` 28, `SLOT_COUNT` 30, `MODIFIER_MASK` 98, `KIND_KEY`/`KIND_MOUSE_BUTTON`/`KIND_JOY_BUTTON`/`KIND_JOY_AXIS` 32–35, `CONTEXT_GAMEPLAY`/`CONTEXT_MENU` 38/40, `RESOLUTION_NONE`/`SWAP`/`REPLACE`/`CANCEL` 43–49 (`scripts/settings/input_bindings.gd`).
- `InputBindingAdapter.apply_defaults` 48, `find_default_drift` 91 (`scripts/ui/input_binding_adapter.gd`).
- `ControlsScreen.leave_requested` 27, `set_prompt_families` 235, `consume_modal_input` 248, `request_leave` 272, `note_joypad_connection` 286 (`scripts/ui/controls_screen.gd`).
- `BindingLabels.UNBOUND` 14, `describe` 88, `glyph_id` 109, `glyph_path` 127 and the label tables 18/28/43/58/72 (`scripts/ui/binding_labels.gd`, new in F16-08).
- `InputDeviceState.prompt_family_changed` 21, `controller_family_changed` 25, `set_glyph_override` 71, `get_prompt_family` 78, `get_controller_family` 88, `MOUSE_MOTION_THRESHOLD` 33, `GLYPH_OVERRIDES` 36, `PLAYSTATION_NAME_TOKENS` 39 (`scripts/ui/input_device_state.gd`, F16-08 additions).
- `CameraRig.set_mouse_capture_active` 245, `clear_pending_look` 253, and `MODE_KEYS`/`MODE_MOUSE` mentioned in the `apply_control_settings` note (`scripts/player/camera_rig.gd`).
- `DashModel.is_enabled` 73, `is_active` 79, `get_direction` 94, `resolve_direction` 104, `TIME_EPSILON` 24 (`scripts/player/dash_model.gd`).
- `PlayerController.controls_enabled_changed` 45, `are_controls_enabled` 239, `get_dash_cooldown_left` 244, `has_dash` 250 (`scripts/player/player_controller.gd`).

Cross-checked with the F16 sections of `docs/engineering/settings.md` (`InputBindings`, `InputBindingAdapter`, `BindingLabels`, `InputDeviceState`, `ControlsScreen` contracts), `docs/engineering/player-flight.md` (`DashModel`, `PlayerController`, `CameraRig` F16-04/05) and `docs/engineering/combat-hud.md` (`grant_invulnerability`). Dropped: none; every member the proposal listed still ships.

No code, scene or test changed, and no test or script was written. `tools/lane.ps1 land` is the gate.

