# F16 Controls, camera and invulnerable lateral dash — design

Status: ready-for-agent
Date: 2026-09-24
Design owner: Astra (sol)
Engineering and orchestration owner: Claude (trunk)
Source: the user's controls-screen request, accepted lateral-dash invulnerability, and request for a written Astra/Claude orchestration plan.
Implementation status: planned, not implemented.

## Intent and scope

Extend Opções → Controles into a fully navigable binding editor for keyboard/mouse and Xbox, DualShock and DualSense controllers. Add mouse camera control, camera recentering, and short left/right dashes with invulnerability. Keep every existing gameplay action, settings value, menu return route and controller-disconnect recovery working.

The user explicitly chose dash invulnerability. The numeric values below are the accepted planning baseline, subject to Astra's later playtest. This feature supersedes F3's earlier "no input remapping / no glyphs / no migration" exclusions for this work only. It does not declare the existing packaged build updated.

No new tests of any kind, including disposable test drivers. Use the existing lane landing gate and manual play through the game. Production implementation is a later task, orchestrated by Claude; this planning session does not launch implementers.

## Product rules

### Binding coverage and profiles

- Cover move_forward, move_back, move_left, move_right, ascend, descend, camera_left, camera_right, camera_up, camera_down, fire, focus, lock_target, next_target, bomb and pause, plus camera_recenter, dash_left and dash_right. Inventory the UI actions actually used by menus; include ui_up, ui_down, ui_left, ui_right, ui_accept, ui_cancel, ui_focus_next and ui_focus_prev. No gameplay or menu shortcut may remain hardcoded outside the action catalog.
- Keyboard/mouse and gamepad are independent saved profiles. Permit two bindings per action per profile; blank secondary slots are allowed. Do not silently erase existing defaults when adding secondary slots.
- Keys use physical positions for gameplay movement, with human-readable current keyboard-layout labels. Menu keys must still work on the active layout. Support mouse buttons/wheel directions, joypad buttons, triggers and positive/negative stick axes. Preserve analog magnitude for movement/camera; a remapped analog input is not forced into digital full-speed movement.
- Gamepads share normalized action bindings across Xbox and PlayStation layouts. This delivery does not promise a different profile per physical controller. Do not save transient device indices.
- Labels use Xbox (A/B/X/Y, LB/RB, LT/RT, LS/RS) or PlayStation (✕/○/□/△, L1/R1, L2/R2, L3/R3) names and glyphs. Add Ícones do controle: Automático / Xbox / PlayStation for adapters that report a generic device. Show a readable text fallback if a glyph is missing.
- Input-device preference (Automático / Teclado / Controle) and camera-input choice are separate settings. Retain the existing automatic-device and disconnect policy; meaningful mouse use counts as keyboard/mouse activity, without flickering device prompts on jitter.
- Persist only validated primitive descriptors, not arbitrary serialized InputEvent objects. Load bindings before the first interactive screen. Preserve existing audio/display settings, camera sensitivity and inversion from old settings.cfg files.

### Capture, conflicts and recovery

Capture flow: idle → wait for the opening input to be released and sticks neutral → listen → review candidate/conflict → apply or cancel. The modal consumes input; capture must not fire, dash, pause, activate another row or move focus behind it.

Ignore key repeat, synthetic InputEventAction, mouse motion and stick drift. For axis capture, require neutral below 0.2, then deliberate deflection above 0.6; remember axis and sign. Treat triggers correctly for the backend's reported range. A ten-second timeout returns unchanged.

Every candidate, including Escape and the current cancel button, can be captured: show a candidate-review screen, then release before using the old menu bindings to confirm/cancel. Do not make Escape impossible to assign by consuming it as instant cancellation during listening. A visible Cancelar button and the timeout remain available.

Compare conflicts within the same profile and overlapping contexts. Gameplay movement and menu navigation can share an input; pause/ui_cancel's existing context sharing must remain valid. For conflicting actions offer Trocar, Substituir, Cancelar. Substituir is disabled if it would leave a required action without any binding. Opposite axes on the same stick are distinct; the same axis/sign cannot drive conflicting actions.

Changes remain a draft until Aplicar. Validate the entire profile, write a temporary ConfigFile and replace the real file only after a successful save; then install its InputMap bindings. On failure retain the previous live map/file and show Não foi possível salvar os controles. Do not show success for a failed save.

After applying menu bindings, offer a 10-second confirmation using the new bindings: Manter controles / Reverter. No confirmation, device disconnect or loss of app focus during confirmation restores the prior profile and map. Store the prior profile and a pending-confirmation marker before activating an unconfirmed profile; a crash/relaunch during the countdown restores the prior profile. A candidate key release cannot confirm itself. Restore defaults operates on the current tab; global Options defaults includes the new settings and profiles. Voltar with a dirty draft offers Aplicar / Descartar / Cancelar.

### Camera

Keyboard camera mode: Teclas or Mouse; default Teclas preserves current behavior. Right-stick orbit remains available with either keyboard camera mode. Provide mouse sensitivity independent of the existing keyboard/stick sensitivity (retain its existing 0.2–2.0 values and saved meaning), inversion for each camera source, and gamepad camera deadzone (default 0.2, range 0.05–0.5). Mouse sensitivity defaults to 0.12 degrees per pixel, range 0.02–0.50.

Mouse mode captures the cursor only during active gameplay. Menus, pause, focus loss, controller disconnect and leaving a Run release it. Regaining app focus does not unexpectedly resume gameplay or capture the pointer; normal Resume does. Discard accumulated mouse motion on mode changes, focus changes and resume. Convert relative mouse displacement to angle once, without multiplying it by frame delta. Keep pitch limits, scenery obstruction and zero roll.

While locked, mouse look temporarily overrides framing while preserving the lock; after 0.25 seconds without deliberate mouse motion, blend back to the locked framing. Keyboard/stick behavior remains compatible. Avoid two competing camera writers.

camera_recenter defaults: R and middle mouse; right-stick press (RS/R3). Without a lock, return to the ship's authored forward direction (-Z, since the current visual ship does not yaw with the camera), default pitch -9 degrees, and normal follow offset. This is intentionally not the last movement direction. With a lock, restore normal ship-and-target framing without releasing it. Use the shortest yaw path over 0.25 seconds; manual camera input interrupts; obstruction limits still win. Repeated requests restart from the current pose, never queue.

### Lateral dash

| Property | Initial value |
| --- | --- |
| Actions | dash_left / dash_right |
| Keyboard defaults | Q / E |
| Gamepad defaults | D-pad left / D-pad right (gameplay context only) |
| Unobstructed travel | 3.0 world units |
| Active duration | 0.15 seconds (about nine 60 Hz ticks; not render-frame counted) |
| Shared cooldown | 0.8 seconds from activation, not from dash end |
| Invulnerability | Entire 0.15-second activation window |
| Cost | No Shield, Bomb, Power or pickup cost |

Capture camera-horizontal left/right at activation. Replace ordinary movement velocity during the burst: there is no diagonal speed stacking and no vertical dash. Normal movement resumes afterward. Focus does not scale dash speed or distance. Fire and Target Lock continue normally. One press causes one dash; holding cannot repeat. Both directions pressed together do nothing and consume no cooldown; presses during cooldown are ignored, not buffered.

Sweep body motion through the existing collision path and clamp to the Flight Volume. Contact cancels remaining dash travel without sliding around the obstacle; it does not refund cooldown. The granted protection still ends at the original activation +0.15 seconds even if movement was stopped by a wall. Closed Gates remain solid. Do not teleport through thin scenery.

Invulnerability must use the existing CombatState authority, reach ProjectileSystem before the activation tick's hit/Graze sweep, and preserve any longer hit/Bomb protection using max(existing remaining, granted duration). Protected hits consume neither health nor Shield. No Graze is awarded during any protected tick; preserve the field's existing one-award-per-projectile rule. Do not make a second damage or Graze implementation.

Gameplay pause freezes dash progress, protection and cooldown. Defeat, disabled controls, stage unload and Retry cancel movement; a new Attempt starts ready with no leftover dash protection. Dash state is transient and not added to checkpoint snapshots. Existing Bomb/hit protection is not cleared merely by dash end.

Visuals: a short cyan propulsion trail and readable ship accent during protection, with the luminous Core still visible. No camera roll, shake or full-screen flash. Coordinate with existing invulnerability flicker so the dash trail cannot outlive protection. HUD cooldown is one compact shared indicator, label Impulso with readiness/progress; disabled and cooling-down states must not look ready.

## Astra screen and layout contract

Reuse scenes/ui/controls.tscn and the existing Opções → Controles route. Keep the Controls root, its existing script attachment, Layout/BackButton and Layout/NavigationHint intact; script attachment and behavior remain Claude's. Retain the theme and illustrated background, with an opaque readable content panel.

At 1280×720 use 48-pixel side margins, heading at y=40, tabs at y=104, content between y=158 and y=606, and fixed footer below y=628. Minimum actionable row height 44 px; use Containers and scrolling, not clipping at smaller windows. On narrower windows stack the details panel beneath the list. Fonts: heading 32, body 20, help 16 logical pixels.

~~~text
CONTROLES                                  [device family / glyph choice]
[ Teclado e mouse ] [ Controle ] [ Câmera ]
┌ Movimento / Combate / Câmera / Menus ────────────────────────────────┐
│ Ação                    Principal       Alternativo      Redefinir │
│ Avançar                 [ W ]           [ — ]            [ ↺ ]    │
│ Impulso à esquerda      [ Q ]           [ — ]            [ ↺ ]    │
│ Centralizar câmera      [ R ]           [ Mouse 3 ]      [ ↺ ]    │
│ ...scrolling rows...                 Help for the focused action  │
└────────────────────────────────────────────────────────────────────┘
[ Restaurar esta aba ]            [ Aplicar ]              [ Voltar ]
[current bindings for select / change / back]
~~~

Astra-authored widget paths (new, agreed contract for Claude):
- Layout/ControlsPanel/Tabs/KeyboardMouse, Gamepad, Camera (Button).
- Layout/ControlsPanel/DeviceFamily (OptionButton: Automático/Xbox/PlayStation).
- Layout/ControlsPanel/BindingScroll/Rows (VBoxContainer, dynamic rows).
- Layout/ControlsPanel/ActionHelp (Label).
- Layout/ControlsPanel/CameraSettings/Mode, MouseSensitivity, OrbitSensitivity, MouseInvert, OrbitInvert, Deadzone (appropriate OptionButton/HSlider/CheckButton).
- Layout/ApplyButton, Layout/RestoreTabButton; preserve Layout/BackButton.
- Overlays/CaptureDialog, ConflictDialog, DirtyDialog, ConfirmBindingsDialog (Control panels with Title, Message and Buttons containers).
- Row template scenes/ui/components/binding_row.tscn: root BindingRow (HBoxContainer), ActionLabel, PrimaryButton, SecondaryButton, ResetButton. No gameplay script in Astra's template.
- Cooldown component scenes/ui/components/dash_cooldown.tscn: root DashCooldown (Control), Label, Progress, ReadyAccent.
- Dash visual scenes/player/visuals/dash_visual.tscn: root DashVisual (Node3D), TrailLeft, TrailRight, ProtectionAccent. Geometry/particles only; no collision or gameplay script.

States Astra must show in the design handoff: idle, focused, listening, conflicting, unbound secondary, changed draft, save failure, confirmation countdown, disabled/cooldown and restored default. Use a visible focus outline plus label/icon state, not color alone. For the controller tab use Portuguese display names and appropriate glyphs rather than Xbox text on a PlayStation pad. Supply original/simple glyph assets with text equivalents.

Menu focus order: tabs → visible controls/rows → Restore tab → Apply → Back, then wrap. Each row: Primary → Secondary → Reset. Focus follows scrolled rows; tab changes retain last focused row. Modal focus stays inside the modal and returns to its invoking control. No keyboard or mouse is required when navigating with a controller. Main-menu and pause-menu callers receive focus back correctly.

Astra owns layout and reusable visual components; Claude instances the cooldown into hud.tscn and dash visuals into the trunk-owned player_ship.tscn. After F16-03 wires controls.tscn, further Astra edits preserve paths and wiring and are announced in the handoff.

## Proposed engineering seams (contracts to create, not existing APIs)

Settings remains the one local settings owner. InputBindings is a Node-free rules object holding the catalog, validated primitive bindings, defaults, contexts and draft conflict decisions. InputBindingAdapter is the only InputMap writer/event normalizer; owned once by Interface, no autoload. ControlsScreen binds the authored widget paths and draft/capture workflow. Reuse the existing InputDeviceState and extend its prompt-family detection.

Proposed primitive binding descriptor: kind (key/mouse_button/joy_button/joy_axis), code (int), axis_sign (-1 or +1 for axes), physical (bool for keys), modifiers (integer mask for key/mouse chords), plus location (KeyLocation for keys, 0 when omitted; F16-02 refinement so Left Shift/Left Ctrl match project.godot exactly). Preserve existing chords such as Shift+Tab and standalone modifiers such as Left Shift/Left Ctrl; capture may not lose either. Context and Portuguese labels belong to the action catalog, not the descriptor. Reject unknown kind/action, invalid indices/signs, non-finite sensitivity/deadzone and malformed arrays. Missing newly introduced actions get defaults independently.

Storage contract: extend [controls] with controls_version=1, binding_profiles, camera_input_mode ("keys" or "mouse"), mouse_sensitivity, mouse_invert_vertical, camera_deadzone and controller_glyph_family ("auto", "xbox", "playstation"). Keep the existing camera_sensitivity and invert_vertical keys for keyboard/stick orbit. Profile IDs are keyboard_mouse and gamepad; slots are 0/1. A pending profile application includes its prior confirmed profiles and marker so boot can recover. InputBindings is owned by the existing Settings instance and exposed read-only to consumers except through the draft/apply workflow. Runtime InputMap ownership stays in Interface's adapter.

Shipped APIs (F16-02 to F16-08, checked against the code 2026-09-24):
~~~text
Settings.get_input_bindings() -> InputBindings
Settings.get_camera_input_mode() -> StringName
Settings.get_mouse_sensitivity() -> float
Settings.get_mouse_invert_vertical() -> bool
Settings.get_camera_deadzone() -> float
Settings.get_controller_glyph_family() -> StringName
Settings.apply_input_bindings(draft: InputBindings, needs_confirmation: bool = false) -> Error   (F16-02: validate, save, then make live)
Settings.confirm_input_bindings() -> Error   /   Settings.revert_input_bindings() -> Error   /   Settings.is_input_bindings_pending() -> bool
Settings F16 keys and constants: CAMERA_INPUT_MODE, MOUSE_SENSITIVITY, MOUSE_INVERT_VERTICAL, CAMERA_DEADZONE, CONTROLLER_GLYPH_FAMILY, BINDING_PROFILES, CONTROLS_VERSION, CONTROL_KEYS, CAMERA_MODE_KEYS, CAMERA_MODE_MOUSE, CAMERA_INPUT_MODES, GLYPHS_AUTO, GLYPHS_XBOX, GLYPHS_PLAYSTATION, GLYPH_FAMILIES, MOUSE_SENSITIVITY_MIN, MOUSE_SENSITIVITY_MAX, DEADZONE_MIN, DEADZONE_MAX   # was: not listed
Interface.get_input_binding_adapter() -> InputBindingAdapter
InputBindings.capture() -> Dictionary
InputBindings.restore(data: Dictionary) -> PackedStringArray
InputBindings.get_bindings(profile: StringName, action: StringName) -> Array[Dictionary]
InputBindings.find_conflicts(profile: StringName, action: StringName, binding: Dictionary) -> Array[StringName]
InputBindings.assign(profile: StringName, action: StringName, slot: int, binding: Dictionary, resolution: StringName = RESOLUTION_NONE) -> PackedStringArray   (RESOLUTION_NONE none, RESOLUTION_SWAP, RESOLUTION_REPLACE, RESOLUTION_CANCEL; an empty binding clears the slot)   # was: resolution: StringName = &""
InputBindings.validate_profile(profile: StringName) -> PackedStringArray
InputBindings.restore_profile_defaults(profile: StringName) -> void
InputBindings.restore_action_defaults(profile: StringName, action: StringName) -> PackedStringArray   (F16-02: a row's Redefinir)
InputBindings.get_default_bindings(profile: StringName, action: StringName) -> Array[Dictionary]; get_fixed_bindings(profile: StringName, action: StringName) -> Array[Dictionary]   # was: get_default_bindings(profile, action) / get_fixed_bindings(profile, action) -> Array[Dictionary]
InputBindings.default_profiles() -> Dictionary   # was: not listed
InputBindings.profile_for(binding: Dictionary) -> StringName   # was: not listed
InputBindings.check_profile_data(profile: StringName, data: Variant) -> PackedStringArray   # was: not listed
InputBindings.normalize_profile(data: Dictionary) -> Dictionary   # was: not listed
InputBindings.key_binding(code: int, physical: bool = true, modifiers: int = 0, location: int = KEY_LOCATION_UNSPECIFIED) -> Dictionary   # was: not listed
InputBindings.mouse_button_binding(button: int, modifiers: int = 0) -> Dictionary   # was: not listed
InputBindings.joy_button_binding(button: int) -> Dictionary   # was: not listed
InputBindings.joy_axis_binding(axis: int, axis_sign: int) -> Dictionary   # was: not listed
InputBindings.parse_binding(value: Variant, profile: StringName = &"") -> Dictionary
InputBindings.same_input(a: Dictionary, b: Dictionary) -> bool
InputBindings.can_share(a: StringName, b: StringName) -> bool
InputBindings.uses_physical_keys(action: StringName) -> bool
InputBindings.get_contexts(action: StringName) -> int
InputBindings.is_required(action: StringName) -> bool
InputBindings.get_category(action: StringName) -> StringName
InputBindings.get_label(action: StringName) -> String
InputBindings.get_actions(category: StringName = &"") -> Array[StringName]
InputBindings constants: CATALOG, CATEGORIES, CATEGORY_LABELS, KEYBOARD_MOUSE, GAMEPAD, PROFILES, SLOT_COUNT, MODIFIER_MASK, KIND_KEY, KIND_MOUSE_BUTTON, KIND_JOY_BUTTON, KIND_JOY_AXIS, CONTEXT_GAMEPLAY, CONTEXT_MENU, RESOLUTION_NONE, RESOLUTION_SWAP, RESOLUTION_REPLACE, RESOLUTION_CANCEL   # was: CATALOG only, inside the static catalog line
InputBindingAdapter.apply_profile(profile: StringName, data: Dictionary) -> PackedStringArray
InputBindingAdapter.apply_bindings(bindings: InputBindings) -> PackedStringArray   (F16-02: both profiles at once)
InputBindingAdapter.apply_defaults() -> void   # was: not listed
InputBindingAdapter.describe_event(event: InputEvent, action: StringName = &"") -> Dictionary   (F16-02: the action picks physical or layout keys)
InputBindingAdapter.find_default_drift() -> PackedStringArray   # was: not listed
ControlsScreen.leave_requested signal   # was: not listed
ControlsScreen.setup(root: Control, settings: Settings, bindings: InputBindings, adapter: InputBindingAdapter) -> void
ControlsScreen.set_prompt_families(prompt_family: StringName, controller_family: StringName) -> void   # was: not listed
ControlsScreen.consume_modal_input(event: InputEvent) -> bool   # was: not listed
ControlsScreen.request_leave() -> bool   # was: not listed
ControlsScreen.note_joypad_connection(connected: bool) -> void   # was: not listed
BindingLabels.UNBOUND   # was: not listed
BindingLabels.describe(binding: Dictionary, family: StringName) -> String   # was: not listed
BindingLabels.glyph_id(binding: Dictionary, family: StringName) -> StringName   # was: not listed
BindingLabels.glyph_path(id: StringName) -> String   # was: not listed
BindingLabels tables: PORTUGUESE_KEY_LABELS, XBOX_BUTTONS, PLAYSTATION_BUTTONS, XBOX_BUTTON_GLYPHS, PLAYSTATION_BUTTON_GLYPHS   # was: not listed
InputDeviceState.prompt_family_changed(family: StringName) signal   # was: not listed
InputDeviceState.controller_family_changed(family: StringName) signal   # was: not listed
InputDeviceState.set_glyph_override(family: StringName) -> void   # was: not listed
InputDeviceState.get_prompt_family() -> StringName   # was: not listed
InputDeviceState.get_controller_family() -> StringName   # was: not listed
InputDeviceState constants: MOUSE_MOTION_THRESHOLD, GLYPH_OVERRIDES, PLAYSTATION_NAME_TOKENS   # was: not listed
CameraRig.request_recenter() -> void
CameraRig.apply_control_settings(p_mode: StringName, p_mouse_sensitivity: float, p_mouse_invert: bool, p_deadzone: float) -> void   (p_mode is MODE_KEYS or MODE_MOUSE)   # was: apply_control_settings(mode, mouse_sensitivity, mouse_invert, deadzone) -> void
CameraRig.set_mouse_capture_active(active: bool) -> void   # was: not listed
CameraRig.clear_pending_look() -> void   # was: not listed
DashModel.configure(duration: float, cooldown: float) -> void
DashModel.try_start(direction: int) -> bool
DashModel.tick(delta: float) -> void
DashModel.cancel() -> void
DashModel.is_enabled() -> bool   # was: not listed
DashModel.is_active() -> bool   # was: not listed
DashModel.get_active_time_left() -> float
DashModel.get_cooldown_left() -> float
DashModel.get_direction() -> int   # was: not listed
DashModel.resolve_direction(left_pressed: bool, right_pressed: bool, left_held: bool, right_held: bool) -> int   # was: not listed
DashModel.TIME_EPSILON   # was: not listed
CombatState.grant_invulnerability(seconds: float) -> void
PlayerController.dash_started(direction: int, duration: float) signal
PlayerController.dash_ended() signal
PlayerController.dash_cooldown_changed(remaining: float, total: float) signal
PlayerController.controls_enabled_changed(enabled: bool) signal   # was: not listed
PlayerController.are_controls_enabled() -> bool   # was: not listed
PlayerController.get_dash_cooldown_left() -> float   # was: not listed
PlayerController.has_dash() -> bool   # was: not listed
~~~

DashModel is Node-free and owns timing/request acceptance; PlayerController owns camera-relative direction, collision and visuals. Camera settings retain CameraRig.apply_settings(sensitivity, invert_vertical) for existing callers. Granting protection emits the existing invulnerability_changed only on state transitions, never an early false at dash end. This list was reconciled with the code by F16-10.

## Verification and completion

Use manual records with actual device/backend, observed values and pass/fail/not-verified; scripts or tools generating synthetic input do not prove physical device acceptance. Verify Xbox, DualShock and DualSense individually, wired/wireless only if actually exercised. An unavailable device stays not verified.

Core acceptance: save/relaunch and old-file migration; remap movement and menu confirm/back safely; capture drift, conflicts and timeout; unplug and focus-loss rollback; correct glyph fallback; mouse capture lifecycle and frame-rate-independent orbit; free/locked recenter interruption; dash travel/cooldown, collision, shield preservation, no Graze, Bomb overlap and pause/Retry reset. F16-07 lists the full walkthrough.

Each ticket updates its Outcome, roadmap row and append-only handoff, commits only its files, then runs tools/lane.ps1 land. No new tests, no pushes, no amends, no primary-tree edits. A completed implementation requires all seven implementation tickets landed and any remaining human-device limitations stated explicitly.
