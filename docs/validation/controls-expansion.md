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

2026-09-24, Claude (trunk). Windows 11, Godot 4.7.2 editor binary headless, no physical device. The contract is in [settings.md "F16 capture workflow and prompts"](../engineering/settings.md#f16-capture-workflow-and-prompts-f16-03). No test or driver was written (F16 rule).

**Run (existing gate pieces only).**

| Check | Result |
| --- | --- |
| `tools/test.ps1`, the existing suite | pass: 225 passed, 0 failed, no script, parse or compile error |
| 300-frame headless boot of `main.tscn` | pass: no ERROR or WARNING line |
| `check_resources.gd --strict-validate` | pass: 85 resources, 85 scripts, none failed |
| `ControlsScreen.setup` at every boot (paths, rows, camera ranges, focus links) | pass: runs in the boot and the suite without an error |
| Options → Controls → Back → Back through `main.tscn` (existing `test_interface_contract`) | pass: the screen is entered and left; entry focus stays on Voltar and Options gets its focus back |
| The standalone menu footer contract (`test_set_keyboard_prompts_shows_and_hides_the_footer`) | pass: a menu with no bindings still shows F15-07's texts |

A first boot showed that `BindingLabels`' physical-key lookup prints `ERROR: Not supported by this display server` on the headless display server. Every prompt now goes through `MenuController.describe_binding`, which names a physical key by its code there, and hidden rows are not written; the boot then printed nothing.

**Checked by reading (not executed).**

| Rule | Where it holds | Result |
| --- | --- | --- |
| The opener never binds | The slot's `pressed` fires on release, and capture waits until no key, mouse button or pad button is held before listening | pass (reading) |
| Echo, `InputEventAction`, mouse motion ignored | `_candidate_from` returns nothing for them; every event is consumed while listening | pass (reading) |
| Drift and held sticks never bind | An axis must read below 0.2 during the capture before a pull past 0.6 counts; axes off-centre at the start stay unarmed | pass (reading); feel not verified |
| Triggers | Pull is the 0 to 1 value; a −1-at-rest backend is detected and rescaled; only +1 is proposed | pass (reading); no such backend exercised |
| Escape, accept and cancel can be captured | While listening nothing is treated as cancel except a click on Cancelar and the other device's `ui_cancel` | pass (reading) |
| A candidate's release never confirms it | Review buttons take input only after every key and button is released and an axis candidate is centred (a refused axis of the other device is not waited for); the GUI activates on a fresh press/release | pass (reading) |
| Chords and standalone modifiers | A modifier waits: the next key or button makes a chord (Shift+Tab); its release alone binds it (Left Shift, with location) | pass (reading) |
| 10 s timeout returns unchanged | Deadline per capture and per review; the draft is only changed by Usar, Trocar or Substituir | pass (reading) |
| Nothing leaks behind a dialog | `Interface._input` marks consumed events handled before the GUI, `Interface._unhandled_input` and the Session; `ui_cancel` is consumed as the dialog's cancel; `Overlays` blocks the mouse; focus is trapped among the dialog's buttons | pass (reading) |
| Focus returns to the invoker | The first dialog of a chain remembers the focused control; closing gives it focus back, or the active tab | pass (reading) |
| Substituir disabled when a required action would lose its last binding, or a fixed binding would move | Trial `assign(RESOLUTION_REPLACE)` on a copy; the message names the reason (required, fixed, or a generic refusal); disabled buttons also lose focus mode | pass (reading) |
| Layout-space conflicts (F16-02's limit) | `pause` versus menu-only actions compared through `keyboard_get_keycode_from_physical` for character keys; Substituir only | pass (reading); non-QWERTY not exercised |
| Draft until Aplicar; failure keeps the draft and the live map | Every edit is on the draft; `Settings.apply_input_bindings` saves before installing and changes nothing on failure; ActionHelp shows "Não foi possível salvar os controles." | pass (reading); failure path not exercised |
| Confirmation on the new bindings; timeout, disconnect, focus loss and hiding revert | `ConfirmBindingsDialog` opens after the profiles are live; `_process`, `note_joypad_connection`, `NOTIFICATION_APPLICATION_FOCUS_OUT` and the hide handler call `revert_input_bindings` | pass (reading) |
| Dirty Back | `Interface._go_back` asks `request_leave` for both Voltar and `ui_cancel` | pass (reading); the clean case passes in the suite |
| Focus order and scrolling | Tabs → Ícones → rows (Principal → Alternativo → Redefinir) → Restaurar → Aplicar → Voltar, wrapping; only the shown tab is linked; `ensure_control_visible` on focus; per-tab memory | pass (reading); controller walk not done |
| Footers from bindings | `MenuController.set_prompts` from `Interface` at boot and on every family or binding change | pass (reading) |
| Global Defaults | `Settings.restore_defaults` covers the F16 values and profiles; `Interface` now reapplies the glyph override on its change | pass (reading) |

**Manual walkthrough for the human pass (not verified).** Record the device and backend for each line; an unavailable device stays not verified.

1. Keyboard only: Opções → Controles. Tab and the arrows reach every tab, Ícones, each row's three buttons, Restaurar esta aba, Aplicar and Voltar, and wrap. The list scrolls with the focus, the category heading shows above each category's first row, and ActionHelp names the focused action.
2. Controller only (Xbox, DualShock, DualSense each): the same walk with the D-pad and the stick; A/✕ opens a capture, B/○ goes back. Entering Controles while using the pad opens the Controle tab, with the pad's glyphs.
3. Capture ordinary keys, Escape, Enter, Space, Left Shift and Left Ctrl alone, Shift+Tab, Mouse 1 to 5, the wheel, D-pad, face buttons, RB/LB, both sticks in each direction and both triggers. Each shows its review, then its name or glyph in the row.
4. Hold the opening button, hold a trigger, and rest a drifting stick while a capture opens: none of them binds. Let a capture run out: after 10 s nothing changed.
5. Cancel a capture with Cancelar (mouse), with Escape on the Controle tab and with B on the keyboard tab; while listening, Escape on the keyboard tab is captured, not a cancel.
6. Conflicts: K on Bomba (Trocar gives Fixar alvo the L; Substituir leaves Fixar alvo blank), Escape on Bomba and W on Recuar (Substituir disabled: Pausa and Avançar are required), and Numpad Enter on Pausa (both disabled; the message says it is fixed on Confirmar). Cancelar changes nothing.
7. Redefinir on a remapped row, and on a row whose default another action now holds (refused, with the holder named). Restaurar esta aba on each tab.
8. Change Confirmar on the controller to X and press Aplicar: the confirmation runs on X; navigate to Manter controles and press X. Repeat and press nothing: after 10 s the previous controls return without a restart.
9. During the confirmation: unplug the controller, and Alt+Tab away. Both revert.
10. Make a change and press Voltar, and Escape: the Dirty dialog offers Aplicar, Descartar and Continuar editando; each does what it says.
11. Save failure: make `settings.cfg` read-only, press Aplicar: "Não foi possível salvar os controles."; the old controls stay live and the draft stays.
12. Save, quit and relaunch: the exact bindings and the Ícones choice return. Kill the game during a confirmation: the previous controls return, with one boot warning.
13. Câmera tab: every widget changes and saves its value; Opções shows the same orbit sensitivity and inversion. Restaurar esta aba resets them.
14. Menu footers on the main menu, Selecionar fase, Opções, Controles and Créditos name the live bindings: keyboard text, then Xbox text after pad use, PlayStation text with a DualSense or with Ícones: PlayStation. Remap Confirmar and see every footer follow.
15. Opções → Restaurar padrões: bindings, camera values and Ícones return to the defaults, and the footers follow.
16. With a non-US layout (AZERTY if available): put a letter key (for example A) on Confirmar's Alternativo, then capture the same key for Pausa's Alternativo. The conflict is reported and only Substituir is offered.
17. Open Controles from Pause during a stage: nothing fires, dashes, pauses or resumes while capturing; Voltar returns to Opções and then to Pause.

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

- **Date and scope:** 2026-09-24, lane rescue, parts 1 and 2 together.
- **Devices:** none. No keyboard, pad or display was exercised by hand.
- **Method:** code reading plus the existing gate on Windows 11 with the Godot 4.7.2 console binary, headless.
  - `tools/test.ps1`: 225 passed, 0 failed, with no script, parse or compile error.
  - `check_resources.gd --strict-validate`: 85 resources and 85 scripts, none failed.
  - The 300-frame boot of `main.tscn` printed no ERROR or WARNING.
  - No test or driver was written (sprint rule). Line numbers below are for the F16-05 commit (`601b722`). The fixes that followed its review are under "Review fixes".

### Physics order inside one tick

Godot runs `_physics_process` by `process_physics_priority`, lowest first, then by tree order. `Main` (`scenes/main.tscn:39`, ALWAYS) is the parent of `WorldRoot` (`:55`, PAUSABLE) and `ProjectileRoot` (`:58`, PAUSABLE). The stage is added to `WorldRoot` before the ship (`game_session.gd:409`, `:438`).

| # | Node, priority | What it does this tick |
| --- | --- | --- |
| 1 | `Main`, 0 | `GameSession._physics_process` (`game_session.gd:151`) calls `_combat_state.tick(delta)` (`:154`, body `combat_state.gd:154–158`). This counts down a window granted on an earlier tick. |
| 2 | The stage's actors, 0 | Enemies move and register their hit spheres. |
| 3 | `WorldRoot/PlayerShip`, 0 | `PlayerController._physics_process` (`player_controller.gd:159`). `_advance_dash` (`:162`) ends a window that ran out. `_try_start_dash` (`:167`) emits `dash_started` (`:308`) **before** `_move_dash` (`:169`) moves the ship. The emission runs the chain below synchronously. |
| 4 | `PlayerShip/Targeting`, `PlayerShip/CameraRig`, 0 | Children after their parent: the lock, then the rig follows the ship where the dash left it. |
| 5 | `PlayerShip/Weapon`, 50 (`player_weapon.gd:35`, `:116`) | Fire, then the Bomb edge (`:153`). A Bomb in the same tick raises the window to `max(0.15, 2.0)` and emits nothing new. |
| 6 | `ProjectileRoot`, 100 (`projectile_system.gd:29`, `:82`) | `_physics_process` (`:100`) passes `_player_invulnerable` to `_field.set_player` (`:103`) and ticks the field (`:110`). The field copies the flag at the start of its pass (`projectile_field.gd:222`). A Core contact while invulnerable reports nothing (`:241`), and any contact spends the Graze without an award (`:246–249`). |

**The chain from step 3.**

1. `dash_started` is connected once per ship, without deferral (`game_session.gd:448`), to `_on_dash_started` (`:669–670`).
2. That calls `CombatState.grant_invulnerability(0.15)` (`combat_state.gd:187–191`), which sets `max(remaining, 0.15)`.
3. `_set_invulnerability` (`:348–352`) emits `invulnerability_changed(true)`, only on the transition.
4. That reaches `GameSession._on_invulnerability_changed`, connected once in `_ready` (`game_session.gd:133`, handler `:657–658`).
5. The handler calls `ProjectileSystem.set_player_invulnerable(true)` and the ship's `set_invulnerable_visual(true)`.

All of it returns before step 3 moves the ship, so it is in place long before step 6.

**No fix to the order was needed.** Neither `projectile_system.gd` nor the priorities changed. **One fix to the arithmetic was needed**; see "Last tick".

### First and last protected tick

- **First tick.** Call the activation tick N. Step 1 of N ran before the grant, so it does not count the new window down. Step 6 of N sweeps with `invulnerable = true`. **The activation tick is protected.**
- **Last tick.** From tick N+1, step 1 subtracts δ = 1/60 once per tick. After the tick N+k decrement the window holds 0.15 − kδ, and the tick is protected while that value is above `TIME_EPSILON` (1e-6 s).
  - k = 8 leaves 0.01667: tick N+8 is protected.
  - k = 9 leaves 2.08e-17. That residue is the error of subtracting 1/60 nine times from 0.15. It is below the epsilon, so it becomes 0, and `invulnerability_changed(false)` fires in step 1 of N+9.
  - Tick N+9 starts at activation + 9δ = activation + 0.15 s, and it is **vulnerable**.
  - Protected ticks: **N through N+8, nine ticks, exactly 0.15 s**.
- **Why the epsilon was needed.** Before this ticket, `tick` stopped only at `<= 0`. The 2.08e-17 residue kept tick N+9 protected, a tenth tick and one extra frame, and N+10 was the first vulnerable tick. The residue was measured with the same double arithmetic: 0.15 needs 10 decrements to reach 0.
- **The fix.** `CombatState.TIME_EPSILON` (1e-6 s) is applied in `tick` (`combat_state.gd:154–158`). It is far below a tick at any rate (1/240 s = 4.2e-3). As a side effect, a Bomb's and a Retry's 2.0 s windows now last exactly 120 ticks instead of 121. The hit window, 1.0 s = 60 ticks, was already exact.
- **Other rates.** A tick is protected when its start lies within [activation, activation + 0.15). At 144 Hz that is ticks N through N+21. N+21 starts at +0.1458 s; N+22 starts at +0.1528 s and is vulnerable.
- **The burst ends on the same tick.** `DashModel` counts down with the same epsilon (`dash_model.gd:103–105`). It starts at 0.15 in step 3 of N, after that tick's own `_advance_dash`, and loses δ in step 3 of every later tick. So it becomes inactive in step 3 of N+9, the same tick the core's window ends.
  - The ship moves in ticks N through N+8: nine steps of 20 × δ = 1/3 unit, 3.0 units in total.
  - The last step is clamped to `min(delta, active time left)` (`player_controller.gd:321`).
  - `DashVisual` requires both the active burst and the mirrored Invulnerability (`:374–381`). Both clear inside tick N+9's physics steps, before a frame is drawn.
- **Longer protection.** A Bomb or hit window that outlasts the dash stays: the grant uses `max`, and `_end_dash` (`:352`) never calls the core. There is no early `false`, and no second `true` when a grant falls inside a running window.

### Other rules checked by reading

| Check | Reading | Result |
| --- | --- | --- |
| One press, one dash; holding never repeats | `is_action_just_pressed` in `_try_start_dash` (`player_controller.gd:296–299`) | pass (reading) |
| Both directions do nothing and cost nothing | `DashModel.resolve_direction` returns 0 when both are down, pressed together or one pressed while the other is held. `try_start(0)` returns before touching the cooldown (`dash_model.gd:47`) | pass (reading) |
| Cooldown presses are dropped, not buffered | `try_start` refuses while `_cooldown_left > 0`, and the press is spent that tick. The 0.8 s run from activation: at 60 Hz, 48 decrements, so a press on tick N+48 is accepted | pass (reading) |
| No vertical part, no diagonal stacking, no Focus scaling | The burst assigns `velocity = direction * distance / duration`, with the direction flattened (`:304–306`, `:320`). It replaces `compute_velocity` for the tick | pass (reading) |
| Stops at scenery and closed Gates without sliding or tunnelling | `move_and_collide` sweep. Any contact normal facing the travel cancels the rest of the travel (`:322–331`, `:336–340`). A Flight Volume face does the same: since the review fixes, `_stop_dash_at_flight_volume` puts the ship back along its own step at the first face it crossed, so no part of the step slides along the face | pass (reading); no scenery was flown |
| No health, Shield or Graze loss while protected | Field rules at `projectile_field.gd:241` and `:246–249`, unchanged. The Session's `take_hit` rejects while invulnerable (`combat_state.gd:134`) | pass (reading) |
| Pause freezes progress, protection and cooldown | The ship and `ProjectileRoot` are PAUSABLE and the core is paused (`game_session.gd:341–346`). `set_controls_enabled(false)` keeps the dash when `can_process()` is false (`player_controller.gd:227–229`) | pass (reading) |
| Beats, defeat, Retry, Restart and unload leave nothing behind | A beat cancels the dash (`game_session.gd:362`, `player_controller.gd:229`). Every Attempt spawns a new ship with a ready `DashModel`, and its `dash_started` connection is freed with the old ship. `start` and `restore` end the core's window | pass (reading) |
| Dash state is not in a Snapshot | Nothing in `CombatState.capture`, `RunState` or the Director reads the ship's dash | pass (reading) |
| HUD never looks ready while unavailable or cooling | `Hud._render_dash`: `PRONTO` and `ReadyAccent` only with the controls on, a dash (`has_dash()`, since the review fixes) and 0 left | pass (reading) |
| Existing HUD paths | All GUIDE Section 15 and F4-03 paths unchanged. `test_hud_contract.gd` passes | pass (existing gate) |

### Review fixes

The review of `601b722` found three minor issues. All three were fixed and checked by reading, and the same gate was run again.

- **Slide along a Flight Volume face.** The clamp works axis by axis. With the camera at an angle to a face, it kept the part of a crossing step along the face: up to 1/3 unit in one tick. Now `_move_dash` records where its step started, and `_stop_dash_at_flight_volume` puts the ship at the fraction of the step where it first met a face, then ends the travel. If the step started outside a Flight Volume that has just narrowed, the fraction is held to 0..1 and the ordinary clamp does the rest.
- **One epsilon.** `DashModel.TIME_EPSILON` is now `CombatState.TIME_EPSILON` itself, so the two countdowns cannot be tuned apart.
- **A ship without a dash.** With `dash_duration` 0, every request is refused, yet the HUD showed `PRONTO`. Now `DashModel.is_enabled()` and `PlayerController.has_dash()` report it, and the HUD shows such a ship as unavailable. The shipped 0.15 s is unaffected.

### Manual checks owed

None of these was run: no one pressed a key or watched a frame.

- **Travel and duration.** Fly the arena or Stage 1, dash left and right from rest and at full speed, forward and diagonal, with the camera turned. Expect 3.0 units along the camera's horizontal left or right, no climb, in 0.15 s. Hold Focus and expect the same distance.
- **Obstruction.** Dash into a wall, a tree trunk, a closed Gate and each Flight Volume face, straight and at a glancing angle. Expect the ship to stop at contact with no slide and no pass-through, including at a Flight Volume face met at an angle with the camera turned. Dash along the floor while resting on it: it must not stop. If it does, Jolt is reporting the side-on floor contact as facing the travel, and `DASH_GLANCE_TOLERANCE` needs another look.
- **Protection.**
  - Cross a hostile pattern with and without the Shield: no Health or Shield loss and no Graze during the burst.
  - Graze normally right after it.
  - Dash inside a Bomb and inside the post-hit window: the blink continues after the trail disappears, and there is no flash of vulnerability.
- **Input.** Hold Q or E, spam them, and press Q+E together, on the keyboard and on the D-pad. Expect one dash per press, nothing for Q+E, and no queued dash when the cooldown ends. The HUD reads `IMPULSO · 0,8 s` down to `PRONTO`.
- **Pause.** Pause mid-burst and mid-cooldown, open Options, then resume. The burst, protection and cooldown continue from where they stopped, and the indicator is dimmed while paused.
- **Lifecycle.** Take the defeating hit during a dash's cooldown, then Retry and Restart. Also clear a stage mid-cooldown and Continue. Each new Attempt must start `PRONTO` with no trail, no accent and no extra protection, and the Retry ship keeps only its own 2 s window.
- **Look (F16-07).** The trail beside the engines and the accent around the ship, and whether the trail should sit on the dash's side or opposite it. It blinks with the ship's flicker. The Core stays readable. There is no camera roll, shake or flash. The indicator sits above the player panel at 1280×720, 1600×900 and 1920×1080.

## Integrated walkthrough (F16-06, trunk)

2026-09-24, Claude (trunk). Windows 11, Godot 4.7.2 console binary, headless. No physical device, and no window. The contract is in [settings.md "F16 Session integration"](../engineering/settings.md#f16-session-integration-f16-06) and [player-flight.md "F16 Session integration"](../engineering/player-flight.md#f16-session-integration-f16-06). No test or driver was written (F16 rule).

**Integrated revision for F16-07.** Take the `dev-01` commit that lands this ticket's commit, "integration: controls, mouse camera, recenter and dash through the Session lifecycle (F16-06) [shared]". It was made on `lane/trunk` at base `8a4e070`, which already contains F16-01 to F16-05 and F16-08 with their review fixes. After `tools/lane.ps1 land`, `git log dev-01 --grep "(F16-06)" -1 --format=%H` names it. Walk that revision or a later one, never the packaged executable, which predates F16.

**Run (existing gate pieces only).**

| Check | Result |
| --- | --- |
| `tools/test.ps1`, the existing suite | pass: 225 passed, 0 failed, no script, parse or compile error |
| 300-frame headless boot of `main.tscn` | pass: no ERROR or WARNING line |
| `check_resources.gd --strict-validate` | pass: 85 resources, 86 scripts, none failed |

The headless display server ignores `Input.mouse_mode` and sends no focus notifications, so the gate runs the new code paths in Teclas mode only.

**Checked by reading (not executed).**

| Rule | Where it holds | Result |
| --- | --- | --- |
| All six camera values reach every new ship before its first tick | `_spawn_player` → `_apply_camera_settings` (both rig calls), on Start, Direct Stage, Restart, Retry, Continuar and Jogar novamente | pass (reading) |
| A change reaches the live rig, over Pause too | `Settings.changed` → `_on_setting_changed` for `CAMERA_SETTING_KEYS`, connected once in `_ready` | pass (reading) |
| Captured only in flight in Mouse mode | `_update_pointer`: ship, HUD on top, tree running, mode `mouse` | pass (reading) |
| Shown on every menu, Pause, Defeat, Results, unload and main menu | `_set_paused` (every pause and resume route), `_show_hud`, `_unload_stage`, `_on_setting_changed`, `_on_focus_lost`, `_exit_tree` | pass (reading) |
| Pending look dropped on capture, release, mode change and Resume, and once more after a capture warp | `set_mouse_capture_active` with each decision, `apply_control_settings`, `_drop_capture_warp` | pass (reading); a real backend warp not exercised |
| Focus loss pauses a stage in play; regaining it resumes nothing | `_notification` → `_on_focus_lost` → `_pause()`; `_on_focus_gained` only runs `_update_pointer()`, outside a beat | pass (reading) |
| No capture while the window is away (a gamepad Resume there) | `_window_focused` in `_update_pointer`, set by the four focus notifications; the focus-in captures a player already flying | pass (reading) |
| Recenter only in flight, never under a menu or the capture | `camera_recenter` event in `_unhandled_input`, gated by `_gameplay_active`; `Interface._input` consumes every capture event first | pass (reading) |
| The press that resumes never dashes | `PlayerController._dash_input_armed`: off at spawn and on `set_controls_enabled(true)`, on again after a tick with both dash actions released | pass (reading) |
| Pause freezes the dash (order kept) | `_set_paused` pauses the tree before `set_controls_enabled(false)` | pass (reading) |
| No duplicate connection after repeated Retry and Restart | No per-ship connection added; `dash_started` and `shots_fired` are freed with the ship; `Settings.changed` connected once by the Session, `Interface`, `OptionsScreen` and `ControlsScreen` each | pass (reading) |
| Options → Controls → caller from both callers | `ScreenRouter` replace and back, with remembered focus; Pause stays on the stack under Options | pass (reading); the main-menu route also passes in the suite |

**Manual walkthrough for the human pass (not verified).** Record the device and backend for each line; an unavailable device stays not verified. On Opções → Controles → Câmera, pick "Câmera: Mouse" for steps 1 to 9.

1. **Capture on entry.** From the main menu, Iniciar. The pointer is hidden, and moving the mouse orbits the camera. The first frames show no jump. Up looks up unless Inverter mouse is on.
2. **Values over Pause.** Pause, then Opções → Controles → Câmera. Change the mouse sensitivity, both inversions and the deadzone (rest a drifting stick), then Voltar, Voltar, Continuar. Each value applies at once, and orbit sensitivity and inversion still work for the keys and the stick.
3. **Pause and Continuar.** Esc and Start show the pointer at once, free to click. Continuar by mouse click, Enter and A captures it again with no camera jump.
4. **A free cursor in Controls.** From Pause, open Controles and click a slot. Capture Mouse 4, then click Cancelar in another capture. Voltar, Voltar: Pause has focus on Opções. Continuar.
5. **Alt+Tab in flight.** The game is on Pause, with the pointer free. Come back by clicking the window or by Alt+Tab: it is still paused, and the pointer is not taken back. Continuar resumes and captures. Alt+Tab away again, then press A on Continuar with the pad while another window has the focus: the game resumes behind it, and the pointer stays free and is not held to the game window. Click the game window: the pointer is captured, with no camera jump.
6. **Held keys through Alt+Tab.** Hold W and J, Alt+Tab away, release them outside, come back and press Continuar. The ship neither flies nor fires by itself.
7. **Controller disconnect.** Unplug the pad in flight, in Automático and in Controle: Pause, the pointer free, and the keyboard drives Pause. In Teclado nothing pauses and the capture stays.
8. **Defeat.** The pointer stays captured through the 1 s defeat beat, and the mouse still orbits there. It is free on Defeat. Tentar novamente captures again, in Mouse mode, at the chosen sensitivity. Menu principal frees it. Take a defeating hit again and Alt+Tab during the beat: the pointer is freed at once, nothing pauses, and Defeat still appears with the pointer free. Coming back during the beat does not take the pointer back. Once more, in Controle, unplug the pad during the beat: nothing pauses, the pointer stays captured until Defeat, and Defeat shows it.
9. **Every Attempt route.** Clear Campaign Stage 1 and press Continuar; clear a Direct Stage and press Jogar novamente; use Pause → Reiniciar fase; Tentar novamente before and after a Checkpoint. Each shows the pointer on Results and Defeat, captures it on the new Attempt and keeps every camera value.
10. **Teclas.** Nothing ever captures the pointer; the arrows and the right stick orbit, and the mouse leaves the camera alone. Alt+Tab still pauses.
11. **Recenter.** Press R, Mouse 3 and RS/R3 in flight. With no lock, the camera turns the short way round to the ship's authored forward at −9° in about 0.25 s. With a lock (K / Y) it returns to the ship-and-target framing and keeps the lock. Mouse or stick input after the first 0.1 s interrupts it, and a second press restarts it. Recenter against a wall and under the shrine gate: the camera stays out of the scenery and never rolls. On Pause, Opções and Controles nothing recenters. While a capture listens, R is captured, not a recenter.
12. **The dash through the lifecycle.** Q and E, and the D-pad, dash; the HUD shows Impulso. Pause mid-cooldown, open Opções, then Continuar: the cooldown goes on from where it stopped. Take the defeating hit during a cooldown, then Tentar novamente. Also try Reiniciar fase, Continuar into Stage 2 and Jogar novamente. Each new Attempt starts `IMPULSO  ·  PRONTO`, with no trail, no accent and no leftover protection; the Retry ship keeps only its own 2 s blink.
13. **The resume guard.** On the Controle tab put Impulso à esquerda on B with Substituir (Bomba loses B), and Aplicar. In flight: Start, then B (Voltar) resumes, and the ship does not dash. B in flight then dashes. Afterwards, Restaurar esta aba and Aplicar.
14. **Confirmation from Pause.** Put Confirmar on X on the Controle tab and Aplicar. Keep it with X and return to the game with the new bindings. Repeat twice more: Alt+Tab during the countdown, and unplug the pad during it. Both revert, and the pointer is free throughout.
15. **Global Defaults from Pause.** Opções → Restaurar padrões, Voltar, Continuar. The camera mode is "Câmera: Teclas" again, so nothing captures; the bindings and the camera values are the defaults.
16. **Repeats.** Tentar novamente five times and Reiniciar fase five times. One Q press still makes one dash, a sensitivity change still applies once, the footers are right, and the console shows no error.

## Visual and device acceptance (F16-07, sol)

2026-09-24, Astra (sol). Integrated source: `40969f0`; `40dd592` changes only the scene-test settings isolation. Windows 11, Godot 4.7.2, OpenGL Compatibility on AMD Radeon RX 9070 XT. The user reported **no physical checks yet**. Actual keyboard, mouse, Xbox, DualShock and DualSense devices exercised for this pass: **none**. Every physical-device result below is **not verified**; no simulated event or earlier headless check is counted as a device pass.

**Inspection and scoped presentation change.** The F16-01 static `1280×720`, `1600×900` and `1920×1080` images show the authored keyboard page, but predate the dynamic catalog, focused scrolling and modal states. The integrated Godot window opened after a local class-cache import; the sandbox desktop did not provide a capturable screen (`CopyFromScreen`: invalid handle), so no interactive frame or play input could be judged. The initial direct launch, before import, printed missing global-class parse errors; importing refreshed the worktree cache and the second launch reached the OpenGL window. The second launch printed only a sandbox root-certificate-store error. Neither launch is an acceptance pass. Scene inspection found that the three Câmera sliders were named only in tooltips and ActionHelp. `controls.tscn` now draws 15 px Portuguese labels inside the existing MouseSensitivity, OrbitSensitivity and Deadzone rows, without changing their paths or input wiring. Their rendered appearance remains not verified.

| Acceptance branch | Actual device / backend | Result | Evidence or remaining action |
| --- | --- | --- | --- |
| Integrated Controls readability at 1280×720, 1600×900, 1920×1080; long names, focus outline and row clipping | None / Windows OpenGL Compatibility window | not verified | Only F16-01 static images exist; capture the integrated page at all three sizes. |
| Focused row scrolling, heading at category boundary, per-tab focus memory, fixed footer | None / Windows OpenGL Compatibility window | not verified | Walk the populated catalog in the running game. |
| Câmera tab labels, sliders, inversion, deadzone and value persistence | None / Windows OpenGL Compatibility window | not verified | New slider labels are present in the scene source; inspect and operate them in-game. |
| Listening, candidate review, timeout, cancel and focus return | None / Windows OpenGL Compatibility window | not verified | F16-03 steps 3–5. |
| Conflict Trocar/Substituir/Cancelar, required/fixed refusals and exact Portuguese copy | None / Windows OpenGL Compatibility window | not verified | F16-03 step 6, including the revised fixed-binding message. |
| Draft mark, Redefinir, restore tab, dirty exit, save failure and persistence after relaunch | None / Windows OpenGL Compatibility window | not verified | F16-03 steps 7, 10–12. |
| Ten-second new-binding confirmation; timeout, unplug, focus-loss and crash rollback | None / Windows OpenGL Compatibility window | not verified | F16-03 steps 8–9 and 12; do not alter the real settings file just to claim a pass. |
| Dynamic keyboard/Xbox/PlayStation row glyphs and all menu footers after remapping | None / Windows OpenGL Compatibility window | not verified | F16-03 steps 2, 14–15. |
| `✕ ○ □ △` in the actual footer font | None / Windows OpenGL Compatibility window | not verified | The theme names no custom font; an actual PlayStation footer frame is still required. The PNG row glyphs alone cannot prove footer text rendering. |
| Keyboard-only menu navigation and binding capture | None / Windows OpenGL Compatibility window | not verified | F16-03 steps 1, 3–17; no keyboard report was supplied. |
| Xbox pad buttons, D-pad/sticks, trigger neutral/drift, glyphs and disconnect | None / no Xbox pad or backend reported | not verified | F16-03 steps 2–9, 14, 17; F16-06 steps 3, 5, 7, 11–16. |
| DualShock pad buttons, D-pad/sticks, trigger neutral/drift, glyphs and disconnect | None / no DualShock pad or backend reported | not verified | Same device walk, with the controller model and connection type recorded. |
| DualSense pad buttons, D-pad/sticks, trigger neutral/drift, glyphs and disconnect | None / no DualSense pad or backend reported | not verified | Same device walk, including the PlayStation footer characters. |
| Non-US layout conflict detection | None / no keyboard layout reported | not verified | F16-03 step 16. |
| Mouse capture, free/locked orbit, no jump, recenter, inversion and obstruction | None / Windows OpenGL Compatibility window | not verified | F16-04 and F16-06 steps 1–6, 10–11. |
| Pause, focus loss, controller unplug, defeat/victory beat and every Attempt route | None / Windows OpenGL Compatibility window | not verified | F16-06 steps 5–9, 12–16, including the F16-06 review additions. |
| Dash left/right travel, Focus independence, simultaneous/held input, cooldown and resume guard | None / Windows OpenGL Compatibility window | not verified | F16-05 owed checks; F16-06 steps 12–13. |
| Dash stop at wall, trunk, gate, floor and angled Flight Volume face | None / Windows OpenGL Compatibility window | not verified | F16-05 obstruction list, including the review-fixed angled-face case. |
| Live-bullet protection, no Shield/Health loss or Graze, Bomb/hit overlap | None / Windows OpenGL Compatibility window | not verified | F16-05 protection list; a headless boot cannot establish it. |
| Trail side/accent/Core readability and cooldown ready, active, paused and disabled states at three sizes | None / Windows OpenGL Compatibility window | not verified | Run dashes both ways and inspect the HUD at all three sizes. |

**Design rulings pending the visual pass.** No dash, camera or HUD numbers are changed. The spec's `3.0` units, `0.15` s active/protected window and `0.8` s cooldown remain the baseline. The pointer during defeat/victory beats, arrows in Mouse mode, a HUD without a key hint and a dash tapped within one tick of Resume require the requested player-facing judgment in a real run; none is accepted or rejected by this record.

**Engineering follow-up.** F16-06 already identified a code-reading concern in `scripts/player/targeting.gd`: remapping `lock_target` or `next_target` to the Back input can trigger it on the first tick after resuming Pause. This was not reproduced here. Claude assigned the release guard to OpenCode (oc-a) as F16-09 during this land. No `player_ship.tscn`, script or numeric edit was made by Astra.

**Acceptance decision:** blocked pending interactive keyboard/mouse and available controller checks. The presentation-label change is scoped and ready for the lane gate, but F16-07 is not approved as a completed device pass.

## Target Lock handoff (F16-11, path)

2026-09-24, Windows 11, Godot 4.7.2, headless run of `main.tscn` by a throwaway driver outside the repo (not a test, not a physical pass). 60 Hz physics, `max_distance` 60, `max_screen_radius` 0.85.

| Case | Result |
| --- | --- |
| (a) Locked target killed, two others eligible | pass: one `target_changed` on the death tick, to the successor rule's choice; camera, HUD and weapon on it; dying node never listed |
| (b) An unrelated enemy killed while locked (three cases) | pass: lock kept, no emission |
| (c) Manual unlock, then the old target killed | pass: no lock over 20 ticks, no recenter |
| (d) Last eligible target killed (others absent, hidden, or out of range) | pass: one `target_changed(null)`, `lock_lost_to_defeat` once, the rig recenters; no reacquire afterwards |
| (e) Range loss with another target eligible | pass: released as before, not reacquired, no recenter |
| (f)(h) Death clip 0.67 s; `next_target` ring and the toggle | pass: unchanged |
| Same-tick `lock_target` press on the death tick | pass: release then the press's fresh lock, as before |
| (g) Lantern Guardian, Tempest Sentinel, Storm Guardian killed while locked | pass: lock held through Phase transitions, released at defeat, **no recenter** (boss rule); boss in the camera frustum on 39/39, 39/39 and 38/38 ticks of its Death clip. Before the boss rule the Tempest Sentinel's recenter turned 90° and kept it in view on only 7 of 39 ticks. |
| Retry and Restart | lock cleared as before (the driver's own lock precondition was not met; read by code: every lock change resets the watch) |
| Seal | not exercised (the driver could not lock one); by reading, a Seal has no `defeated` signal, so it keeps the old release |

Physical keyboard and controller play of the handoff is owed to the user's pass.
