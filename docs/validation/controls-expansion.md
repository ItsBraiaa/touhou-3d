# F16 controls, camera and dash: validation record

These are manual records only (spec, "Verification and completion"). Each one names the device and backend actually used, what was observed, and pass, fail or not verified. Synthetic input never certifies a physical device, and an unavailable device stays not verified. Each ticket fills only its own section below, so parallel lanes merge cleanly. Do not reorder or merge sections.

## Layout and components (F16-01, sol)

Pending.

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

Pending.

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
