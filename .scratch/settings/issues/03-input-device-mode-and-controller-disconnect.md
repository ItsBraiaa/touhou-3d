# F3-03 Input device mode and controller disconnect

Status: todo
Type: adapter
parallel-safe: no
Depends on: F3-02
Lane: path
Model: Claude Opus 5.5, solo

> **Moved to lane path (shared OpenCode budget).** It was planned for oc-b on GLM-5.3, but on the shared meter one GLM-5.3 ticket takes most of a 5-hour window. Path (Opus) runs it in its gap, right before its F3-04 part 1 windowed pass.

## Goal

- **Prompts.** Options' `InputDevice` (Automático, Teclado, Controle) decides which prompts every menu shows. Automático follows the last device used (PLANEJAMENTO Section 7). One tracker in `Interface` replaces the per-menu footer tracking of F2-02, so the eight menus cannot disagree.
- **Disconnect pause.** Unplugging a controller while the HUD is on top pauses the game through the existing `pause` path, and the keyboard can then drive Pause.
- **What the mode is.** A prompt preference and a disconnect rule. It never filters input, so a wrong choice cannot lock anyone out (Claude's proposal).

## Read first

- `.scratch/settings/spec.md` "Cross-feature contracts", and `docs/engineering/settings.md`: F3-01's `Settings.InputDevice` and `changed`, and F3-02's `Interface.get_settings()`.
- `docs/PLANEJAMENTO.md` Section 7: "Automatic mode follows the last-used device", and "Disconnecting a controller pauses the game and permits keyboard recovery".
- `docs/GUIDE.md` Section 14 "Focus and responsive layout" ("update or hide it when gamepad is active"), and the Section 7 row "Pause requested".
- `docs/engineering/menus-session.md`: "Footer", the Interface contract, and the GameSession "Pause" section. `pause` over the HUD pauses, and over any other screen it is ignored.
- `scripts/ui/menu_controller.gd`: `_input`, `_set_gamepad_active`, `_on_joy_connection_changed`, `JOYPAD_AXIS_THRESHOLD`. `scripts/ui/interface.gd` as F3-02 left it. `scripts/session/game_session.gd` `_unhandled_input`, read only.
- Tooling quirks:
  - `tree.root.push_input` dispatches events synchronously, headless too.
  - `Input.parse_input_event` followed by `Input.flush_buffered_events()` dispatches to the root viewport.
  - `Input.get_connected_joypads()` is empty headless, so gate on events, not on polling.

## Files

- **Creates:** `scripts/ui/input_device_state.gd`, `tests/unit/ui/test_input_device_state.gd`, `tests/scene/test_input_device_flow.gd`.
- **Edits:**
  - `scripts/ui/interface.gd`: owns `InputDeviceState`, adds `_input`, the joypad connection handler, the pause injection and the prompt push to every menu.
  - `scripts/ui/menu_controller.gd`, footer only. Remove `_input`, `_set_gamepad_active`, `_on_joy_connection_changed`, `JOYPAD_AXIS_THRESHOLD`, and the `set_process_input` / `joy_connection_changed` lines at the end of `_ready`; `_ready` keeps resolving `_footer`. Add `set_keyboard_prompts(shown: bool)`.
  - `tests/scene/test_menu_registry_contract.gd`: `test_the_footer_hides_on_gamepad_input_and_returns_on_keyboard_input` becomes `test_set_keyboard_prompts_shows_and_hides_the_footer`. The device assertions move to `test_input_device_flow.gd`.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F3-03 row.
  - `docs/HANDOFF_LOG.md`: one entry.
  - `docs/engineering/settings.md`: an "Input device and disconnect" section.
  - `docs/engineering/menus-session.md`: the "Footer" subsection points to `settings.md`.
  - `docs/GUIDE.md`: the Section 6 rows `interface.gd` and `menu_controller.gd`, and the Section 7 row "Pause requested", which now also covers a disconnect over the HUD.
- **Must not touch:**
  - `game_session.gd`: the pause arrives as an injected action.
  - `scenes/main.tscn` and `scenes/ui/*.tscn`.
  - `settings.gd`, and `options_screen.gd` (F3-02 binds the `InputDevice` widget).
  - `project.godot`: no new action.
- **Conflicts with:**
  - `interface.gd`: F3-02, before.
  - `menu_controller.gd` and `test_menu_registry_contract.gd`: F11-01 (trunk) edits `_ready`, `enter()` and the load-bearing path list, and it is not ordered against this ticket. The hunks are disjoint except `_ready`'s tail. Whichever ticket lands second keeps both: F11-01's label lookups, and this ticket's `_footer` lookup without the joypad connection.

## Deliverables

### `InputDeviceState` (`scripts/ui/input_device_state.gd`, `class_name InputDeviceState extends RefCounted`, Node-free)

- `signal prompts_changed(keyboard: bool)`, emitted only on a change. `const JOYPAD_AXIS_THRESHOLD := 0.5`, moved here from `MenuController`.
- `set_mode(mode: Settings.InputDevice)`, `get_mode()`. The last device starts as keyboard.
- **`note_event(event: InputEvent)`:**
  - `InputEventKey` makes the keyboard the last device.
  - `InputEventJoypadButton`, or `InputEventJoypadMotion` at or past the threshold, makes the gamepad the last device and marks `event.device` connected.
  - Everything else is ignored: mouse, `InputEventAction` (so the injected pause changes nothing), and stick drift.
- **`note_joypad(device: int, connected: bool)`** keeps the set of connected ids. When the last pad leaves, the last device becomes the keyboard.
- **`shows_keyboard_prompts() -> bool`:** `KEYBOARD` always; `GAMEPAD` only while no pad is connected; `AUTOMATIC` while the last device is the keyboard.
- **`pauses_on_disconnect() -> bool`:** `mode != KEYBOARD` (Claude's proposal: in Teclado nobody is playing on the pad).

### `Interface`

- **`_ready`, after F3-02's settings load:**
  - `_device_state.set_mode(_settings.get_input_device())`, and `note_joypad(id, true)` for each `Input.get_connected_joypads()` entry.
  - Connect `prompts_changed` to `set_keyboard_prompts` on every menu, `_settings.changed` (which calls `set_mode` for `INPUT_DEVICE`) and `Input.joy_connection_changed`.
  - Then push the initial prompt state to every menu.
- **`_input(event)`:** `_device_state.note_event(event)`. The event is never handled here. `_input` runs before a focused button consumes a gamepad accept.
- **`_on_joy_connection_changed(device, connected)`:** `note_joypad(...)`. Then, if `not connected and _device_state.pauses_on_disconnect() and _router.current() == ScreenRouter.HUD`, it calls `_request_pause()`.
- **`_request_pause()`:** `Input.parse_input_event` of an `InputEventAction` `pause`, pressed, and then the same action released.
  - It reaches `GameSession._unhandled_input` like Start or Escape, and the Session pauses only when a stage is in play.
  - Checking for the HUD on top means Pause, Options opened from Pause, Defeat, Results and the menus are never toggled or resumed.

### `MenuController`

- `set_keyboard_prompts(shown: bool)` sets `_footer.visible`. It does nothing on the three overlays, which are authored without a footer.
- **Keyboard recovery:** Pause already takes focus on entry (F2-02), and arrows, Enter and Escape work in every mode. When the last pad leaves, the prompts turn to the keyboard's.

## Tests required

`tests/unit/ui/test_input_device_state.gd`:

- `test_automatic_follows_the_last_device`
- `test_stick_drift_below_the_threshold_is_not_gamepad_use`
- `test_actions_and_mouse_events_are_ignored`
- `test_keyboard_mode_always_shows_keyboard_prompts`
- `test_gamepad_mode_shows_gamepad_prompts_only_while_a_pad_is_connected`
- `test_the_last_pad_leaving_restores_keyboard_prompts_in_automatic`
- `test_prompts_changed_fires_once_per_change`
- `test_only_keyboard_mode_skips_the_disconnect_pause`

`tests/scene/test_input_device_flow.gd`:

- **Fixture.** It runs on `main.tscn` with `Interface.settings_path` redirected to the per-process temp file of F3-01.
- **Driving it.** Events go through `tree.root.push_input`, and connections through `Input.joy_connection_changed.emit(device, connected)`. The injected pause lands after `Input.flush_buffered_events()` and two awaited frames.
- **The mode.** It is chosen through the Options widget: `select(i)`, then `item_selected.emit(i)`.

The tests:

- `test_every_menu_footer_follows_the_device_in_automatic`: MainMenu's and Options' footers hide after a pad button and return after a key.
- `test_keyboard_mode_keeps_the_footer_after_gamepad_input`
- `test_gamepad_mode_hides_the_footer_while_a_pad_is_connected`
- `test_controller_disconnect_during_gameplay_pauses`: Direct Stage 1 with the HUD on top. The tree is paused, Pause is on top and `RunState` is paused.
- `test_keyboard_recovers_after_a_disconnect_pause`: `ui_down` moves Pause's focus, and Escape resumes to the HUD.
- `test_disconnect_while_paused_or_in_options_does_not_resume`
- `test_disconnect_in_the_menus_starts_nothing`
- `test_keyboard_mode_does_not_pause_on_disconnect`
- In `test_menu_registry_contract.gd`: `test_set_keyboard_prompts_shows_and_hides_the_footer`.

## Out of scope

- Gamepad glyph icons, and a gamepad footer text (hiding is what GUIDE Section 14 allows).
- Remapping, and any mode that blocks a device.
- Rumble.
- The physical unplug check, which is owed to a person.

## Definition of Done

- `tools/test.ps1` is green, and its output has no `SCRIPT ERROR` line.
- ENGINEERING_BRIEF 4.I "controller disconnect recovery" and "input mode selection" have named tests. No Error-level warnings.
- Verified headless through the tests above.
- A physical DualSense unplug in flight is owed to a person (ENGINEERING_BRIEF Section 8: "A simulated gamepad event does not replace testing a physical controller"). List it in `settings.md` Open issues.
- Module doc, the GUIDE rows and the `menus-session.md` line, handoff log, `Status: done` with an Outcome, ROADMAP row.
- One commit: `ui: add input device mode and controller-disconnect pause`. Then run the lane glm-b land step from `docs/engineering/SPRINT.md`.

## Handoff notes for Astra

- `Layout/NavigationHint` stays load-bearing on the five full screens.
- Controle mode, and Automático after pad use, hide it. No gamepad hint text or glyph icons are planned this sprint.

## Kickoff prompt

```
In your lane worktree, read AGENTS.md, docs/engineering/SPRINT.md (your lane section), docs/engineering/ROADMAP.md and .scratch/settings/issues/03-input-device-mode-and-controller-disconnect.md. Check its dependencies with tools/lane.ps1 status F3-02, implement it test-first, run tools/test.ps1 until green with no SCRIPT ERROR, finish its Definition of Done, commit, then run tools/lane.ps1 land.
```
