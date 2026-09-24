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

- **Date and scope:** 2026-09-24, lane rescue, parts 1 and 2 together.
- **Devices:** none. No keyboard, pad or display was exercised by hand.
- **Method:** code reading plus the existing gate on Windows 11 with the Godot 4.7.2 console binary, headless.
  - `tools/test.ps1`: 225 passed, 0 failed, with no script, parse or compile error.
  - `check_resources.gd --strict-validate`: 85 resources and 85 scripts, none failed.
  - The 300-frame boot of `main.tscn` printed no ERROR or WARNING.
  - No test or driver was written (sprint rule). Line numbers below are for the F16-05 commit.

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
| Stops at scenery and closed Gates without sliding or tunnelling | `move_and_collide` sweep. Any contact normal facing the travel cancels the rest of the travel (`:322–331`, `:336–340`). A Flight Volume face does the same through the clamp (`:175–178`) | pass (reading); no scenery was flown |
| No health, Shield or Graze loss while protected | Field rules at `projectile_field.gd:241` and `:246–249`, unchanged. The Session's `take_hit` rejects while invulnerable (`combat_state.gd:134`) | pass (reading) |
| Pause freezes progress, protection and cooldown | The ship and `ProjectileRoot` are PAUSABLE and the core is paused (`game_session.gd:341–346`). `set_controls_enabled(false)` keeps the dash when `can_process()` is false (`player_controller.gd:227–229`) | pass (reading) |
| Beats, defeat, Retry, Restart and unload leave nothing behind | A beat cancels the dash (`game_session.gd:362`, `player_controller.gd:229`). Every Attempt spawns a new ship with a ready `DashModel`, and its `dash_started` connection is freed with the old ship. `start` and `restore` end the core's window | pass (reading) |
| Dash state is not in a Snapshot | Nothing in `CombatState.capture`, `RunState` or the Director reads the ship's dash | pass (reading) |
| HUD never looks ready while unavailable or cooling | `Hud._render_dash`: `PRONTO` and `ReadyAccent` only with the controls on and 0 left | pass (reading) |
| Existing HUD paths | All GUIDE Section 15 and F4-03 paths unchanged. `test_hud_contract.gd` passes | pass (existing gate) |

### Manual checks owed

None of these was run: no one pressed a key or watched a frame.

- **Travel and duration.** Fly the arena or Stage 1, dash left and right from rest and at full speed, forward and diagonal, with the camera turned. Expect 3.0 units along the camera's horizontal left or right, no climb, in 0.15 s. Hold Focus and expect the same distance.
- **Obstruction.** Dash into a wall, a tree trunk, a closed Gate and each Flight Volume face, straight and at a glancing angle. Expect the ship to stop at contact with no slide and no pass-through. Dash along the floor while resting on it: it must not stop. If it does, Jolt is reporting the side-on floor contact as facing the travel, and `DASH_GLANCE_TOLERANCE` needs another look.
- **Protection.**
  - Cross a hostile pattern with and without the Shield: no Health or Shield loss and no Graze during the burst.
  - Graze normally right after it.
  - Dash inside a Bomb and inside the post-hit window: the blink continues after the trail disappears, and there is no flash of vulnerability.
- **Input.** Hold Q or E, spam them, and press Q+E together, on the keyboard and on the D-pad. Expect one dash per press, nothing for Q+E, and no queued dash when the cooldown ends. The HUD reads `IMPULSO · 0,8 s` down to `PRONTO`.
- **Pause.** Pause mid-burst and mid-cooldown, open Options, then resume. The burst, protection and cooldown continue from where they stopped, and the indicator is dimmed while paused.
- **Lifecycle.** Take the defeating hit during a dash's cooldown, then Retry and Restart. Also clear a stage mid-cooldown and Continue. Each new Attempt must start `PRONTO` with no trail, no accent and no extra protection, and the Retry ship keeps only its own 2 s window.
- **Look (F16-07).** The trail beside the engines and the accent around the ship, and whether the trail should sit on the dash's side or opposite it. It blinks with the ship's flicker. The Core stays readable. There is no camera roll, shake or flash. The indicator sits above the player panel at 1280×720, 1600×900 and 1920×1080.

## Integrated walkthrough (F16-06, trunk)

Pending.

## Visual and device acceptance (F16-07, sol)

Pending.
