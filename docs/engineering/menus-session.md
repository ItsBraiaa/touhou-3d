# Menus and Session

Feature F2: which screen is shown, how Back returns to the caller, and, as later tickets land, the Run's state and the Session that starts, pauses and ends it. Started with ticket F2-01 on 2026-09-22, extended by F2-03 the same day and by F2-02 and F2-04 on 2026-09-23. `ScreenRouter`, `RunState`, `Interface`, `MenuController` and `GameSession` are CODE_READY, which completes the Feature: from the main menu the player starts a Campaign or a Direct Stage, flies the static stage, pauses, opens Options from Pause, resumes, restarts, returns to the menu and quits.

## Purpose

`ScreenRouter` owns the navigation rules for the nine screens of GUIDE Section 14 and the HUD: which screens are visible, which overlays sit above gameplay, where Back returns to, whether gameplay is covered, and which control had focus on each screen that is waiting to be returned to. It reports every change as `screen_hidden` and `screen_shown`, so the `Interface` adapter (F2-02) only has to show, hide and focus.

It does not own any Node, any actual Control focus, input, pausing the tree, or what a button does. It does not know whether a Run is active beyond the HUD being on its stack.

`Interface` (adapter on `Main/Interface`) owns the nine screen instances: it instances the eight menus and the HUD once, shows, hides and focuses them as its `ScreenRouter` reports, resolves Back (`ui_cancel` and the Back buttons), and passes every other menu action up to the Session as `action_requested`. `MenuController` (adapter on each menu scene root) owns one screen's buttons, its focus on entry and return, its runtime text, and its keyboard footer. Neither decides what an action does, pauses the tree, or reads gameplay state; the Session does (F2-04).

`RunState` owns the Run: its Run Mode and stage order, which stage is in play and whether it is complete, the Attempt count, the pause flag Active Time respects, the Active Time, score, Graze and bombs used of the current Attempt and what a Checkpoint committed, each stage's entry values (starting Power Level, carried score), the Snapshot slice of all that, and the four lifecycle signals the Session reacts to. It does not own combat resources (Health, Shield, Bombs held), Power Progress, the live Power Level, Encounter or Objective flags (F8-03 adds them to the Snapshot), pausing the tree, loading scenes, or deciding when a Checkpoint activates.

`GameSession` (adapter on `Main`, the composition root of ADR-0002) owns the Run's lifecycle in the scene: it holds the one `RunState`, acts on every `Interface.action_requested`, loads the stage and the ship under `WorldRoot` and unloads them with every projectile, pauses and resumes the tree, the ship's controls and Active Time together, and ticks Active Time while the tree runs. It does not own navigation (the router), what a menu shows (the menus), flight or targeting (the ship's adapters), or any gameplay rule. Stage completion, defeat, Retry and Results are F10 and F11's; until then their handlers return to the menu.

## Files

- `scripts/ui/screen_router.gd` (Rules Core, `class_name ScreenRouter extends RefCounted`).
- `tests/unit/ui/test_screen_router.gd` (14 tests).
- `scripts/ui/interface.gd` (Adapter, `class_name Interface extends CanvasLayer`), attached to `Main/Interface` in `scenes/main.tscn`.
- `scripts/ui/menu_controller.gd` (Adapter, `class_name MenuController extends Control`), attached by Astra's eight `scenes/ui/*.tscn` menu roots since F0 (it was a placeholder until F2-02).
- `tests/scene/test_menu_registry_contract.gd` (15 tests), `tests/scene/test_interface_contract.gd` (11 tests), and one test in `tests/unit/project/test_input_map.gd` for the menu bindings.
- `tools/validate_menus.gd`: offline navigation QA with keyboard and gamepad events, results in [validation/menus.md](../validation/menus.md).
- `scripts/session/run_state.gd` (Rules Core, `class_name RunState extends RefCounted`, with the internal inner class `RunState.Tally`).
- `tests/unit/session/test_run_state.gd` (19 tests).
- `scripts/session/game_session.gd` (Adapter, `class_name GameSession extends Node`), attached to `Main` in `scenes/main.tscn`, which sets its seven exports.
- `tests/scene/test_game_session_flow.gd` (20 tests), headless on `scenes/main.tscn`; `tools/validate_menus.gd` plays the menu-to-flight flow through it on both devices.

## ScreenRouter contract

### Screen ids

`StringName` constants on `ScreenRouter`. The kinds are the constants `FULL_SCREENS` and `OVERLAYS`.

| Constant | Id | Scene (GUIDE Section 14) | Kind |
| --- | --- | --- | --- |
| `MAIN_MENU` | `&"main_menu"` | `main_menu.tscn` / MainMenu | full screen |
| `STAGE_SELECT` | `&"stage_select"` | `stage_select.tscn` / StageSelect | full screen |
| `OPTIONS` | `&"options"` | `options.tscn` / Options | full screen |
| `CONTROLS` | `&"controls"` | `controls.tscn` / Controls | full screen |
| `CREDITS` | `&"credits"` | `credits.tscn` / Credits | full screen |
| `HUD` | `&"hud"` | `hud.tscn` (GUIDE Section 15) | full screen, opened only by `home()` |
| `PAUSE` | `&"pause"` | `pause_menu.tscn` / PauseMenu | overlay |
| `DEFEAT` | `&"defeat"` | `defeat.tscn` / Defeat | overlay, Back cannot leave it |
| `RESULTS` | `&"results"` | `results.tscn` / Results | overlay, Back cannot leave it |

### The stack

Everything shown is one stack of entries, bottom to top, each with its id, the params it was opened with, and its remembered focus.

- A **full screen** covers every entry below it. An **overlay** leaves the entries below it visible. `visible_stack()` is therefore the topmost full screen plus every overlay above it.
- `replace()` and `push()` add an entry, `back()` removes the top one, `home()` starts a new stack of one.
- So Options opened from Pause covers both the HUD and Pause (`visible_stack()` is `[options]`) while `has_overlay(PAUSE)` stays true, and Back uncovers `[hud, pause]` with the game still paused. Credits opened from Results comes back to `[hud, results]` with Results' original params, so the adapter can hide Replay or Continue again.
- Back from Pause removes Pause and leaves `[hud]`. Back returns false, and emits nothing, on a single entry or with Defeat or Results on top.

### Signals

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `screen_hidden` | `id: StringName` | `id` stopped being visible: covered by a full screen, removed by `back()`, or cleared by `home()`. |
| `screen_shown` | `id: StringName, params: Dictionary` | `id` became visible, with the params it was opened with, including when `back()` uncovers it. |

One transition emits every hide before any show, and every hide before the stack changes: hides top of the stack first, shows bottom first. So during a `screen_hidden` handler `current()` is still the old top. Each screen gets at most one signal per transition, and a screen that stays visible gets none (the HUD under a new Pause). Entries are compared by identity, so `home(HUD)` from `[hud, defeat]` (Retry) emits hidden `defeat`, hidden `hud`, shown `hud`: the adapter must tolerate a hide immediately followed by a show of the same screen.

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `home(id)` | `Interface.show_home` (Session: entering the main menu, starting an Attempt) | Clears history, overlays and every remembered focus; shows the full screen `id`, anew even if it was visible. |
| `replace(id, params := {})` | `Interface.show_screen` | Shows the full screen `id` over the stack, which Back returns to. Asserts `id` is a full screen other than the HUD. |
| `push(id, params := {})` | `Interface.push_overlay` | Shows the overlay `id` above the stack, which stays visible. Asserts `id` is an overlay. |
| `back() -> bool` | `Interface.back` (`ui_cancel`, Back buttons) | Removes the top entry. False on a single entry or on Defeat/Results; the adapter then emits `back_refused`. |
| `current() -> StringName` | adapter, Session | The top entry, which holds focus. `&""` before the first `home()`. |
| `visible_stack() -> Array[StringName]` | adapter, tests | The visible screens, bottom to top. |
| `has_overlay(id) -> bool` | Session | Whether overlay `id` is on the stack, visible or covered. |
| `is_gameplay_covered() -> bool` | `Interface.is_gameplay_covered` | The HUD is on the stack and something is above it. False with no HUD: no Run, nothing to cover. |
| `remember_focus(screen, control_path)` | adapter, from `screen_hidden` | Records `screen`'s focused control (path relative to the screen root) on its entry. Does nothing for a screen not on the stack. |
| `focus_for(screen) -> NodePath` | adapter, from `screen_shown` | The remembered path, or an empty one: the screen is being entered, not returned to, and takes its initial focus. |

`params` are stored as given and passed back on every uncovering; the router does not copy them, so a caller must not mutate a dictionary after passing it.

### Focus memory

GUIDE Section 14 asks for "initial focus on screen entry, preserve focus on return". A screen's focus lives on its stack entry, so it survives exactly as long as the screen waits for Back:

- Options → Controls → Back restores Options' focus; Pause → Options → Back restores Pause's.
- Resume, then pause again: the new Pause entry starts with no memory, so focus goes to its initial button rather than to "End run" if that was the last one visited.
- `home()` forgets everything, so the main menu after a Run starts on its initial button.

The adapter wiring (`Interface`, F2-02): on `screen_hidden(id)`, `router.remember_focus(id, menu.leave())`, where `leave()` hides; on `screen_shown(id, params)`, `menu.enter(params, router.focus_for(id))`, where `enter()` shows. Every hide fires before the stack changes, so the memory lands on the entry being hidden: a covered entry keeps it, and an entry that `back()` removes or `home()` clears drops it. Until F2-02 the hides fired after the stack changed; then `home(MAIN_MENU)` with the main menu already shown handed the old entry's focus to the new one, found by `tools/validate_menus.gd` and pinned by `test_home_of_the_shown_screen_does_not_hand_its_old_focus_to_the_new_entry`.

## Interface contract

`class_name Interface extends CanvasLayer` on `Main/Interface`, which `scenes/main.tscn` sets to `PROCESS_MODE_ALWAYS`, so every menu works over a paused tree.

### Exports

| Export | Type | Set in `main.tscn` to | Required |
| --- | --- | --- | --- |
| `menu_scenes` | `Array[PackedScene]` | the eight `scenes/ui/` menus; order does not matter, each is identified by its root name | yes: an empty slot disables the node; a missing, repeated or foreign scene is reported and skipped |
| `hud_scene` | `PackedScene` | `scenes/ui/hud.tscn` | yes |
| `settings_path` | `String` | not set: the default `Settings.DEFAULT_PATH` (`user://settings.cfg`) | no; tests inject a temp path (F3-02) |

### Behaviour

- `_ready` instances the HUD first (so every menu, overlays included, draws above it), then each menu, all hidden, connects each `MenuController.action_requested` to one handler, reports any menu screen no scene provides, and connects the router's two signals. Nothing is shown until the Session calls `show_home`.
- Since F3-02 `_ready` first builds the one `Settings` from `settings_path` and reads the file once (its messages are `push_warning`s), and after the menus it adds an `OptionsScreen` under the Options root, which binds the eight widgets and applies the buses and the display ([settings.md](settings.md) "Options binding").
- A menu action other than `back` and `restore_defaults` is re-emitted unchanged as `action_requested(action, payload)`. `back` never leaves `Interface`: it is resolved like `ui_cancel` below. `restore_defaults` (Options' Defaults) never leaves it either: `OptionsScreen.restore_defaults()` restores and saves once (F3-02).
- `ui_cancel` (Escape, gamepad B) in `_unhandled_input`, while a menu is on top: on Pause it emits `action_requested(&"resume", {})` and leaves Pause up for the Session to remove, because the router's `back()` cannot unpause the tree; elsewhere it calls `back()`, and when that returns false (main menu, Defeat, Results) it emits `action_requested(&"back_refused", {})`. Either way the event is marked handled, so the same Escape press cannot also reach the Session as `pause`.
- `ui_cancel` with the HUD on top (running gameplay), or before the first `show_home`, is left unhandled: over gameplay Escape is the Session's `pause`.
- Focus follows the router's memory: see "Focus memory" above.

### Signal

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `action_requested` | `action: StringName, payload: Dictionary` | A registry button other than a Back button was pressed (the actions and payloads of `MenuController.ACTIONS_BY_SCREEN`), or `ui_cancel` / a Back button produced `resume` or `back_refused`. |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `show_home(id)` | Session | `router.home(id)`: `MAIN_MENU` when entering the menus, `HUD` when an Attempt starts. The screen takes its initial focus, also when it was already shown. |
| `show_screen(id, params := {})` | Session, on `open_*` | `router.replace(id, params)`: a full screen Back returns from. |
| `push_overlay(id, params := {})` | Session: pause, defeat, results | `router.push(id, params)`. |
| `back() -> bool` | Session, e.g. on `resume` to remove Pause | `router.back()`. Does not unpause anything. |
| `current_screen() -> StringName` | Session, tests | `router.current()`. |
| `is_gameplay_covered() -> bool` | Session | `router.is_gameplay_covered()`. |
| `get_hud() -> Control` | Session (F4 binds it) | The HUD instance. |
| `get_settings() -> Settings` | F3-03, F3-04, tests | The one `Settings`, loaded at boot (F3-02). Null only when the exports failed validation. |

## MenuController contract

`class_name MenuController extends Control`, the root script of all eight menu scenes. `get_screen_id()` maps the root node name to the router id (`MainMenu`, `StageSelect`, `Options`, `Controls`, `Credits`, `PauseMenu`, `Defeat`, `Results`, table `SCREEN_IDS`); any other name is reported and the node disables itself.

### Registry (`ACTIONS_BY_SCREEN`, from GUIDE Section 14)

| Screen | Button path | Action | Payload |
| --- | --- | --- | --- |
| MainMenu | `Layout/StartButton` | `start_campaign` | |
| MainMenu | `Layout/StageSelectButton` | `open_stage_select` | |
| MainMenu | `Layout/OptionsButton` | `open_options` | |
| MainMenu | `Layout/QuitButton` | `quit` | |
| StageSelect | `Layout/ForestCard/SelectButton` | `start_direct_stage` | `{"stage": &"stage_01"}` |
| StageSelect | `Layout/MountainCard/SelectButton` | `start_direct_stage` | `{"stage": &"stage_02"}` |
| StageSelect, Options, Controls, Credits | `Layout/BackButton` | `back` (resolved by `Interface`) | |
| Options | `Layout/Controls/BindingsButton` | `open_controls` | |
| Options | `Layout/DefaultsButton` | `restore_defaults` (F3) | |
| Options, Results | `Layout/CreditsButton` | `open_credits` | |
| PauseMenu | `Layout/ResumeButton` | `resume` | |
| PauseMenu | `Layout/RestartButton` | `restart_stage` | |
| PauseMenu | `Layout/OptionsButton` | `open_options` | |
| PauseMenu, Defeat, Results | `Layout/MenuButton` | `return_to_menu` | |
| Defeat | `Layout/RetryButton` | `retry` (F11) | |
| Results | `Layout/ContinueButton` | `continue_campaign` (F11) | |
| Results | `Layout/ReplayButton` | `replay_stage` (F11) | |

Each press emits `action_requested(action, payload)` with a new payload Dictionary. A path missing from the scene is reported with the screen and path, and only that button is skipped.

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `enter(params, focus_path)` | `Interface`, on `screen_shown` | Shows the screen, writes the params below, and focuses `focus_path` (relative to the root) if that control is visible and focusable, otherwise the first visible focusable control in tree order. |
| `leave() -> NodePath` | `Interface`, on `screen_hidden` | Returns the focused control's path relative to the root (empty when focus is not inside the screen), then hides. |
| `get_screen_id() -> StringName` | `Interface`, tests | The router id, valid before `_ready`. |

Initial focus in tree order is: MainMenu Iniciar, StageSelect the forest card, Options the Geral slider (`Layout/Audio/MasterVolume`), Controls and Credits Voltar, Pause Continuar, Defeat Tentar novamente, Results Continuar, Jogar novamente or Menu principal depending on the mode.

### Params

| Screen | Key | Effect |
| --- | --- | --- |
| PauseMenu | `score`, `graze` (int) | `Layout/Score` reads `Pontos  <score>     Graze  <graze>`; a missing value shows `—`, so no params restore the authored text. |
| Defeat | `checkpoint` (the latest Checkpoint's id) | `Layout/RetryLocation` reads `Último checkpoint · <id>`; absent or empty reads `Início da fase`. |
| Results | `mode` | `RESULTS_CAMPAIGN_STAGE` (`&"campaign_stage_1"`, also the default): Continue shown, Replay hidden. `RESULTS_DIRECT_STAGE` (`&"direct_stage"`): Replay in Continue's place. `RESULTS_FINAL_VICTORY` (`&"final_victory"`): both hidden and `Layout/Heading` reads `Jornada concluída`; the other modes restore the authored heading. `focus_next` and `focus_previous` of the visible buttons are relinked into one loop, so Tab skips the hidden ones; the directional search already skips hidden controls. An unknown mode is reported and shown as the Campaign layout. |

The Results value labels (time, score, Graze, bombs) are F11's.

### Footer

`Layout/NavigationHint` is the keyboard hint on the five full screens. Since F3-03 no menu tracks devices: `Interface` owns the one `InputDeviceState` and calls `MenuController.set_keyboard_prompts(shown)` on every menu when the prompts change, so the next screen opens with the right state and the menus cannot disagree. Which prompts show depends on Options' input device (Automático follows the last device used, Teclado always shows the hint, Controle hides it while a pad is connected): see [settings.md](settings.md) "Input device and disconnect". Pause, Defeat and Results are authored without a footer; the path is pinned by a test instead of a runtime log.

### Menu input bindings

Menus use the built-in `ui_*` actions. Godot 4.7 binds `ui_accept` and `ui_cancel` to keys only, so `project.godot` adds the gamepad's A to `ui_accept` and B to `ui_cancel`; without them a pad could move focus but never press a button or go back. The D-pad and left stick already drive `ui_up`/`ui_down`/`ui_left`/`ui_right`.

## RunState contract

### Phases

`RunState.Phase`: `IDLE` (before the first `start()`), `IN_STAGE`, `STAGE_COMPLETE`, `RUN_ENDED`. `start()` and `advance()` enter `IN_STAGE`, `complete_stage()` moves to `STAGE_COMPLETE`, and `advance()` after the last stage or `end_run()` moves to `RUN_ENDED`. **Only `IN_STAGE` accepts a change to the Attempt**: `begin_attempt`, `tick_active`, `add_score`, `add_graze`, `note_bomb_used`, `commit_checkpoint`, `rollback_attempt` and `restart_stage` do nothing in any other phase. So a completed stage's result is final — a Graze from a Projectile still in flight after the Boss falls changes neither what `stage_completed` reported nor what `advance()` carries — and a duplicate callback cannot report a transition twice.

### What each stage accounts for

| Value | Scope | At stage entry | Commit (`commit_checkpoint`) | Retry (`rollback_attempt`) | Restart (`restart_stage`) |
| --- | --- | --- | --- | --- | --- |
| Active Time | this stage | 0 | folded into committed | back to committed | back to 0 |
| score | the Run | 0 in a new Run; the previous stage's final score in Campaign Stage 2 | folded | back to committed | back to the entry score |
| Graze | this stage | 0 | folded | back to committed | back to 0 |
| bombs used | this stage | 0 | folded, and not undone by the Checkpoint's refill | back to committed | back to 0 |
| Power Level at start | this stage | 1 for Stage 1 in either mode, 2 for Direct Stage 2, the value passed to `advance()` for Campaign Stage 2 | unchanged | unchanged | unchanged |
| Attempt index | this stage | 0; `begin_attempt()` makes it 1 | unchanged | unchanged; the following `begin_attempt()` adds 1 | unchanged; the following `begin_attempt()` adds 1 |

Clear Time is committed Active Time plus the current Attempt's (CONTEXT "Clear Time"). A commit does not begin a new Attempt: the Attempt continues from zero uncommitted values.

### Signals

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `stage_started` | `stage: StringName` | `start()` or `advance()` entered a stage of the order. Not on `restart_stage()` or `restore()`, which stay in the same stage. |
| `stage_completed` | `result: Dictionary` | `complete_stage()` in `IN_STAGE`; `result` is `stage_result()` at that moment. |
| `run_ended` | `victory: bool` | `advance()` after the last stage (true), or `end_run(victory)` while a Run is in progress. Never before `start()` and never twice. |
| `paused_changed` | `paused: bool` | The pause flag changed, through `set_paused()`, `begin_attempt()` (unpauses) or `start()` (unpauses). Never when it already had that value. |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `start(mode: RunMode, first_stage: StringName)` | Session, from the menu | New Run; discards one in progress without `run_ended`. Campaign order is `CAMPAIGN_ORDER` (`[&"stage_01", &"stage_02"]`) from `first_stage` on, asserted to be in it; Direct Stage order is `[first_stage]`. Unpauses, enters the first stage with Attempt index 0. Call `begin_attempt()` next. |
| `begin_attempt()` | Session, after `start`, `advance`, a Retry and a Restart | Attempt index + 1, uncommitted values discarded, unpaused. |
| `set_paused(paused: bool)` | Session, on pause and resume | Sets the flag `tick_active` respects. |
| `tick_active(delta: float)` | Session `_physics_process`, only while the tree is not paused | Adds `delta` seconds of Active Time in `IN_STAGE` while not paused. |
| `add_score(points: int)`, `add_graze(count := 1)`, `note_bomb_used()` | Session, relaying combat events | Add to the current Attempt. |
| `commit_checkpoint()` | Session, on the Director's first activation of a Checkpoint | Folds the current Attempt into the committed values. Revisits must not call it again; the core does not know which Checkpoint it was. |
| `rollback_attempt()` | Session, on Retry | Discards the current Attempt's uncommitted values. |
| `restart_stage()` | Session, on Restart | Also returns the committed values to the stage-entry values. |
| `complete_stage()` | Session, on the Director's stage completion | `STAGE_COMPLETE`, emits `stage_completed`. |
| `advance(power_level: int)` | Session, from Results (Continue) | From `STAGE_COMPLETE` only: enters the next stage, carrying the score and starting at `power_level`, or ends the Run with a victory. `power_level` is required so the Session cannot forget the carry-over; it is unused when the Run ends. |
| `end_run(victory := false)` | Session, on Return to Menu | `RUN_ENDED`, emits `run_ended(victory)`. |
| `clear_time() -> float` | Session, results | Seconds. |
| `stage_result() -> Dictionary` | Session, Pause (score, Graze), results | A new Dictionary: `clear_time` (float), `score`, `graze`, `bombs_used` (int), `mode` (`RunMode`), `stage` (StringName), `is_final` (bool: this is the last stage of the order, so its completion ends the Run). Only valid after `start()`; before it, it indexes an empty order. |
| `starting_power_level() -> int` | Session, when spawning the player, and on Retry and Restart | The current stage's entry Power Level. |
| `get_phase() -> Phase`, `get_attempt_index() -> int`, `is_paused() -> bool` | Session, tests | Read-only state. |
| `capture() -> Dictionary`, `restore(data: Dictionary)` | Session, Snapshot (F8-03) | See below. |

### Snapshot slice

`capture()` returns a new Dictionary of primitives and one copied `Array[StringName]`: `mode`, `stage_order`, `stage_index`, `entry_power_level`, `entry_score`, `committed_active_time`, `committed_score`, `committed_graze`, `committed_bombs_used`. The current Attempt's uncommitted values are not in it. Nothing in it is shared with the core, in either direction: later play does not change a capture, and editing a capture does not reach the core.

`restore(data)` copies those values back, discards the current Attempt's uncommitted values and puts the stage in play (`IN_STAGE`), also into a fresh `RunState`. It leaves the Attempt index and the pause flag alone and emits nothing. F8-03 turns this Dictionary into the `Snapshot` class and adds combat resources, Power Progress and Encounter flags beside it.

## GameSession contract

`class_name GameSession extends Node` on `Main` in `scenes/main.tscn`, which is `PROCESS_MODE_ALWAYS`, so it hears `pause` and the menus' requests while the tree is paused.

### Exports

| Export | Type | Set in `main.tscn` to | Required |
| --- | --- | --- | --- |
| `world_root` | `Node3D` | `WorldRoot` | yes |
| `projectile_system` | `ProjectileSystem` | `ProjectileRoot` | yes |
| `interface` | `Interface` | `Interface` | yes |
| `audio` | `Node` | `Audio` | yes |
| `player_scene` | `PackedScene` | `scenes/player/player_ship.tscn`; its root must be a `PlayerController` | yes |
| `stage_scenes` | `Dictionary[StringName, PackedScene]` | `&"stage_01"` → `stage_01.tscn`, `&"stage_02"` → `stage_02.tscn` | no: a stage with no entry, or a null one, is refused when started |
| `stage_flight_bounds` | `Dictionary[StringName, AABB]` | `&"stage_01"` → `AABB(-45, 0, -570, 90, 75, 605)` | no: only for a stage whose scene records no bounds |

A missing required export is reported with `Main`'s path and the node stops processing, as before.

### Actions

| Action (`Interface.action_requested`) | From | Effect |
| --- | --- | --- |
| `open_stage_select`, `open_options`, `open_controls`, `open_credits` | main menu, Options, Pause, Results | `interface.show_screen(id)`: a full screen Back returns from. Options from Pause keeps the tree paused. |
| `start_campaign` | main menu | Start (below) with `RunMode.CAMPAIGN` on `RunState.CAMPAIGN_ORDER[0]`, Stage 1. |
| `start_direct_stage` | Stage Select, payload `{"stage": id}` | Start with `RunMode.DIRECT_STAGE` on `id`. |
| `resume` | Pause's Continuar, `ui_cancel` on Pause | Resume (below). |
| `restart_stage` | Pause | Unpause, `run_state.restart_stage()`, reload the stage and a new ship, `begin_attempt()`, HUD. |
| `return_to_menu` | Pause (Defeat and Results in F11) | Unpause, unload, `run_state.end_run(false)`, `show_home(MAIN_MENU)`. |
| `quit` | main menu | `_quit()`: `audio.silence()`, then `get_tree().quit()` after `QUIT_SILENCE_SECONDS` (0.1 s), so no stream is still playing at exit. The window's close button and Alt+F4 take the same path (`auto_accept_quit` is off once the Session is set up). |
| `back_refused` | main menu, Defeat, Results | Nothing. |
| anything else (`retry`, `continue_campaign`, `replay_stage`) | Defeat, Results | A warning naming the action; F11 implements them. `restore_defaults` no longer arrives: `Interface` resolves it (F3-02). |

### Starting a stage

`_load_stage(id)` checks everything before it touches what is loaded: the scene exists in `stage_scenes`, its root has a `PlayerStart` `Node3D` (GUIDE Section 5), a Flight Volume is known, and `player_scene`'s root is a `PlayerController`. Any failure is one `push_error` naming the stage and the reason; nothing is loaded, no Run starts and the menu stays (the same for Restart, which cannot fail on a stage it already loaded). Then it unloads, adds the stage under `WorldRoot`, places the new ship at `PlayerStart`'s global transform **before** adding it (so `CameraRig._ready` starts behind the ship at the marker instead of easing in from the origin), adds it, and calls `player.setup(bounds)`. Start then calls `run_state.start(mode, id)`, `begin_attempt()` and `interface.show_home(HUD)`.

The Flight Volume is the `min`/`max` `Vector3` metadata on the stage's `FlightBounds/Limits` when the scene records it (Stage 2: X -55..55, Y 0..160, Z -760..40), else `stage_flight_bounds[id]`. Stage 1 records none; its entry is the inner faces of its `FlightBounds` walls (West and East at X ±47 with 4-unit depth, Ceiling at Y 77, Entrance at Z 37, End at Z -572): X -45..45, Y 0..75, Z -570..35, the handoff's "X=-45..45 and Y up to 75". Both are in stage coordinates, and so is `PlayerStart`: `WorldRoot` and every stage root stay at the origin, as the handoffs author them.

`Targeting.target_changed` → `CameraRig.set_lock_target` is not the Session's: `PlayerController._ready` makes that one connection (F1-04), so every new ship is wired by instancing it and a restart cannot double-connect.

### Unloading

`_unload_stage()` removes every child of `WorldRoot` (the stage and the ship) from the tree at once, then `queue_free`s them, and calls `projectile_system.clear_all()` (since F6-02; `ProjectileRoot`'s own children are the renderers and stay). `_load_stage()` ends with `projectile_system.setup(bounds, ship)` (contract in [weapon-rendering.md](weapon-rendering.md)). Removing them first keeps a stage loaded in the same frame from sharing the tree, the physics space or the `targetable` group with the old one, and keeps its name `Stage`. Today every caller runs from an input event or a button signal; F10 and F11 must defer the call when it is triggered from a physics callback (an `Area3D` `body_entered`), where removing collision objects is not allowed.

### Pause

- `_unhandled_input`: `pause` (Escape, gamepad Start) acts only while `run_state.get_phase() == IN_STAGE` and only with the HUD or Pause on top: from the HUD it pauses, on Pause it resumes, and anywhere else — Options or Controls opened from Pause — it is ignored, so Start cannot resume behind Options. Escape is `ui_cancel` as well, and `Interface` consumes it first wherever a menu is on top: on Pause that arrives here as `resume`.
- Pause: `get_tree().paused = true`, `run_state.set_paused(true)`, `player.set_controls_enabled(false)` (which also releases a held Focus), then `interface.push_overlay(PAUSE, {"score": ..., "graze": ...})` from `run_state.stage_result()`.
- Resume: only while the tree is paused, so a Pause the Session did not open is left alone. `interface.back()` removes Pause, then the three flags are reversed.
- `_physics_process` ticks `run_state.tick_active(delta)` only while the tree is not paused. `Main` is `PROCESS_MODE_ALWAYS`, so without that check a paused tree would still add Active Time whenever `RunState`'s own flag was clear.
- Options from Pause then Back returns to Pause with the tree still paused: the router keeps Pause on its stack, and nothing here unpauses on Back.

### RunState signals

`_ready` connects `stage_completed` and `run_ended`, once. `stage_completed` returns to the menu (TODO F11: Results). `run_ended(true)` returns to the menu (TODO F11: Results in its final-victory mode); `run_ended(false)` does nothing, because it only comes from `return_to_menu`, which has already left. `stage_started` and `paused_changed` have no listener yet: the HUD (F4) and audio (F13) will be connected by the Session.

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `get_run_state() -> RunState` | tests, `tools/validate_menus.gd` | The Run's state, to read. Only the Session drives it. |

Everything else is private and reached through `Interface.action_requested` and the `pause` action.

## Dependencies

None. `ScreenRouter` imports nothing and holds no Node. `Interface` (F2-02) constructs it in `_ready` and connects both signals there, once.

None for `RunState` either. `GameSession` (F2-04) constructs it as a member, connects `stage_completed` and `run_ended` in `_ready`, once, and ticks it from `_physics_process` only while the tree is not paused (`Main` is `PROCESS_MODE_ALWAYS`).

`Interface` depends on `ScreenRouter`, on `MenuController` (screen ids, `enter`, `leave`, `action_requested`) and on the nine scenes set in `main.tscn`. `MenuController` depends on `ScreenRouter`'s id constants and on the Section 14 node paths. `GameSession` depends on `Interface` (`action_requested`, connected once in `_ready`; `show_home`, `show_screen`, `push_overlay`, `back`, `current_screen`), on `RunState`, on `PlayerController` (`setup`, `set_controls_enabled`; its own `_ready` wires targeting to the camera), on each stage root's `PlayerStart` and optional `FlightBounds/Limits` metadata, and on the scenes set in `main.tscn`.

## Invariants and tests

| Invariant (ticket F2-01, GUIDE Section 14) | Test |
| --- | --- |
| Options from the main menu returns to it; the history is empty afterwards | `test_back_from_options_opened_on_the_main_menu_returns_to_the_main_menu` |
| Main menu → Options → Controls → Back → Back unwinds one caller at a time | `test_back_unwinds_nested_screens_one_caller_at_a_time` |
| Options from Pause returns to Pause with the HUD under it, Pause on the stack throughout; a second Back returns to the HUD | `test_options_opened_from_pause_returns_to_pause_with_the_hud_underneath` |
| Credits from Results returns to Results with its params | `test_credits_opened_from_results_returns_to_results_with_its_params` |
| Back never dismisses Defeat or Results | `test_back_never_dismisses_defeat_or_results` |
| Gameplay is covered by any overlay or full screen above the HUD, never without a HUD | `test_gameplay_is_covered_by_any_overlay_or_full_screen_above_the_hud` |
| Nothing is current or visible before the first `home()` | `test_nothing_is_current_or_visible_before_the_first_home` |
| `home()` clears history and overlays | `test_home_clears_history_and_overlays` |
| `back()` on a fresh `home()` returns false and emits nothing | `test_back_on_a_fresh_home_returns_false_and_emits_nothing` |
| Signals once per screen per transition, hide before show, params through | `test_transitions_emit_hide_before_show_once_per_screen_with_params` |
| Focus memory round-trips and is per screen | `test_focus_memory_round_trips_per_screen` |
| Focus is forgotten when its screen leaves the stack | `test_focus_is_forgotten_when_its_screen_leaves_the_stack` |
| Focus remembered from `screen_hidden` comes back on return | `test_focus_remembered_on_hide_comes_back_on_return` |

Mutation-checked: per-id focus that is never forgotten, re-showing screens that stayed visible, hiding bottom first, "covered" meaning anything but the HUD, and Back dropping the uncovered screen's params each fail a named test above. F2-02 added `test_home_of_the_shown_screen_does_not_hand_its_old_focus_to_the_new_entry`, red against the old hide-after-change order.

| Invariant (ticket F2-02, GUIDE Section 14) | Test |
| --- | --- |
| Every registry row of Section 14 is a `BaseButton` at its path, and the table has exactly those rows | `test_menu_registry_contract.gd::test_every_registry_row_is_a_button_on_its_screen` |
| Each button requests its action; the stage cards carry their stage | `::test_each_button_requests_its_registry_action` |
| A payload is a new, editable Dictionary on each press | `::test_a_payload_is_a_new_dictionary_on_each_press` |
| Entering a screen focuses its first control | `::test_entering_a_screen_focuses_its_first_control` |
| A remembered focus is restored; a stale or unfocusable one falls back; `leave()` reports and hides | `::test_returning_restores_the_remembered_focus_and_leaving_reports_it`, `::test_leaving_without_focus_inside_the_screen_reports_nothing` |
| Results per mode: Continue or Replay or neither, the heading, the rebuilt focus loop, and the authored heading back on the next Results | `::test_results_after_campaign_stage_1_shows_continue_and_skips_replay`, `::test_results_after_a_direct_stage_shows_replay_in_place_of_continue`, `::test_results_final_victory_hides_both_and_names_the_journey`, `::test_a_remembered_button_hidden_by_the_run_mode_is_not_focused` |
| Defeat names the retry location; Pause shows score and Graze | `::test_defeat_names_the_retry_location`, `::test_pause_shows_the_score_and_graze_it_is_given` |
| A missing button is skipped and the rest of the screen works | `::test_a_missing_button_is_reported_and_the_rest_of_the_screen_works` |
| The footer exists on the five full screens, hides on gamepad input, ignores stick drift, returns on a key | `::test_the_five_full_screens_carry_the_keyboard_footer`, `::test_the_footer_hides_on_gamepad_input_and_returns_on_keyboard_input` |
| `Interface` instances the eight menus and the HUD once, the HUD first | `test_interface_contract.gd::test_interface_instances_the_eight_menus_and_the_hud_once` |
| Startup shows only the main menu, focused on Iniciar; `show_home` shows exactly one screen and re-enters a shown menu on its first button | `::test_startup_shows_only_the_main_menu_with_its_first_button_focused`, `::test_show_home_shows_exactly_that_screen`, `::test_show_home_of_the_shown_menu_starts_on_its_first_button` |
| A press is passed up with its payload | `::test_a_button_press_is_passed_up_as_an_action_request` |
| Back (button or `ui_cancel`) returns to the caller with its focus, nested too, and is not passed up | `::test_a_back_button_returns_to_the_caller_with_its_focus`, `::test_nested_screens_restore_each_callers_focus` |
| Options from Pause returns to Pause over the HUD with Pause's focus and params | `::test_options_opened_from_pause_returns_to_pause_with_the_hud_underneath` |
| `ui_cancel` on Pause requests `resume`, on the main menu and Defeat `back_refused`, consumed in both; over gameplay it is left for the Session | `::test_cancel_on_pause_requests_resume`, `::test_cancel_with_nowhere_to_go_back_is_refused`, `::test_cancel_over_running_gameplay_is_left_to_the_session` |
| `ui_accept` and `ui_cancel` answer the gamepad's A and B as well as their keys | `test_input_map.gd::test_menus_confirm_and_go_back_on_the_keyboard_and_on_a_gamepad` |

Mutation-checked, thirteen mutants, each failing a named test above by assertion with no `SCRIPT ERROR`: `enter` ignoring the remembered focus, `leave` hiding before reading focus, the Results loop not rebuilt, the Results heading never restored, the payload not copied, stick drift counted as gamepad use, initial focus limited to buttons, `ui_cancel` left unhandled, `ui_cancel` on Pause calling `back()`, `ui_cancel` handled over gameplay, `back` passed up, the HUD added last, and focus never remembered.

| Invariant (ticket F2-03, ENGINEERING_BRIEF Sections 4.H and 8, PLANEJAMENTO Section 6) | Test |
| --- | --- |
| Campaign: Stage 1, then Stage 2, then a victory; `is_final` false then true | `test_campaign_plays_stage_1_then_stage_2_then_ends_in_victory` |
| Direct Stage 2 is one stage at Power Level 2 and ends in victory with `is_final` true | `test_direct_stage_2_is_one_stage_that_starts_at_power_level_2` |
| Stage 1 starts at Power Level 1 in either mode | `test_stage_1_starts_at_power_level_1_in_either_mode` |
| Campaign Stage 2 starts at the Power Level Stage 1 ended with | `test_campaign_stage_2_starts_at_the_power_level_stage_1_ended_with` |
| 120 ticks of 1/60 are 2.0 s of Active Time | `test_active_time_is_the_sum_of_the_physics_ticks_in_a_stage` |
| Paused ticks add nothing, and time resumes after unpausing | `test_paused_ticks_add_no_active_time` |
| Ticks in `IDLE` add nothing | `test_ticks_before_a_run_starts_add_no_active_time` |
| Clear Time: commit at 10 s, play 5 s, 15; Retry 10; Restart 0 (failed attempts cannot inflate duration; Restart differs from Retry) | `test_clear_time_is_committed_time_plus_the_current_attempt` |
| Score and Graze follow the same commit and rollback rules (failed attempts cannot farm score) | `test_score_and_graze_are_committed_and_rolled_back_like_time` |
| Bombs used survive a commit and roll back with a failed Attempt | `test_bombs_used_survive_a_checkpoint_and_roll_back_with_a_failed_attempt` |
| Campaign Stage 2 carries the score and starts its own time, Graze and bombs; Restart returns to the carried score | `test_campaign_stage_2_carries_the_score_and_starts_its_own_time_graze_and_bombs` |
| A new Run starts from zero, unpaused, even after a Run ended while paused | `test_a_new_run_starts_from_zero` |
| `begin_attempt` counts per stage, discards uncommitted values and unpauses | `test_begin_attempt_counts_the_attempt_and_starts_it_clean_and_unpaused` |
| `paused_changed` fires only on a change | `test_paused_changed_fires_only_when_the_flag_changes` |
| Each lifecycle signal fires once per transition, never out of phase | `test_repeated_lifecycle_calls_report_each_transition_once` |
| A completed stage's result no longer changes | `test_a_completed_stage_result_no_longer_changes` |
| A capture is not changed by later play (deep checkpoint snapshots) | `test_a_capture_is_not_changed_by_later_play` |
| Editing a capture does not reach the core | `test_editing_a_capture_does_not_reach_the_core` |
| Restore resumes at the captured values, in place and into a fresh core, without keeping its input | `test_restore_resumes_at_the_captured_checkpoint` |

Mutation-checked, twelve mutants, each failing a named test above by assertion: a capture sharing the stage order, a restore keeping its input, `paused_changed` on no change, ticks ignoring the pause flag, an entry that drops the carried score, Graze counted after completion, `advance` outside `STAGE_COMPLETE`, a commit that keeps the Attempt's values, a Restart that keeps the committed ones, `advance` ignoring its Power Level, the Attempt index counted per Run, and `begin_attempt` leaving the flag paused.

| Invariant (ticket F2-04, GUIDE Sections 5, 7 and 14, CONVENTIONS "Time and randomness") | Test (`test_game_session_flow.gd`) |
| --- | --- |
| After ready, the main menu is shown alone over an empty `WorldRoot`, no Run | `test_startup_shows_the_main_menu_over_an_empty_world` |
| `open_*` shows its screen, each over the previous one | `test_open_actions_show_their_screen` |
| A Direct Stage puts a `Stage` and a `PlayerShip` under `WorldRoot`, the ship at `PlayerStart`, the HUD alone, `IN_STAGE` on Attempt 1 | `test_a_direct_stage_loads_the_stage_and_the_ship_at_player_start` |
| Iniciar plays Campaign Stage 1, not final | `test_start_campaign_plays_stage_1_of_the_campaign` |
| Stage 1's Flight Volume comes from the Session export: the ship is clamped to X 45 and Y 75 | `test_stage_1_keeps_the_ship_inside_its_flight_interior` |
| Stage 2's comes from its `FlightBounds/Limits`: clamped to X -55; Direct Stage 2 starts at Power Level 2 | `test_stage_2_takes_its_flight_interior_from_the_scene` |
| `pause` pauses the tree and RunState under Pause over the HUD; 30 paused ticks add no Active Time; `resume` removes Pause and time runs again | `test_pause_freezes_the_tree_and_active_time_until_resume` |
| A paused tree adds no Active Time even with RunState's flag clear (`Main` is ALWAYS) | `test_a_paused_tree_adds_no_active_time_even_with_the_run_unpaused` |
| Paused mid-flight with the input held, the ship holds still; a second `pause` resumes and it flies again | `test_pausing_mid_flight_freezes_the_ship_and_resuming_hands_it_back` |
| Pause takes the ship's controls (Focus released) and resume returns them | `test_pausing_releases_focus_and_resuming_restores_the_controls` |
| Options from Pause keeps the game paused, `pause` under Options is ignored, Back returns to Pause still paused | `test_options_from_pause_keeps_the_game_paused` |
| `ui_cancel` on Pause resumes and removes Pause | `test_cancel_on_pause_resumes_and_removes_pause` |
| The gamepad B press that resumes never reaches gameplay as a `bomb` event, in `_input` or `_unhandled_input`; the next press does | `test_the_b_press_that_resumes_never_reaches_gameplay_as_a_bomb` |
| Restart: a new stage and a new ship at `PlayerStart`, Clear Time 0 even after a Checkpoint commit, Attempt 2, unpaused, HUD alone | `test_restart_reloads_the_stage_with_a_new_ship_at_player_start` |
| Return to Menu empties `WorldRoot` and every Projectile, unpauses, ends the Run, shows the main menu | `test_return_to_menu_unloads_everything_and_shows_the_main_menu` |
| A stage with a null scene is refused: nothing loaded, still on the menu, no Run; the other stage still plays | `test_a_stage_without_a_scene_is_refused_and_the_menu_stays` |
| A stage with no Flight Volume or no `PlayerStart` is refused the same way | `test_a_stage_without_player_start_or_flight_volume_is_refused` |
| A completed stage returns to the menu until F11 | `test_a_completed_stage_returns_to_the_menu_until_results_exist` |
| Pause and resume need a stage in play; a Pause the Session did not open stays | `test_pause_and_resume_need_a_stage_in_play` |

Mutation-checked, sixteen mutants, each failing a named test above by assertion: the tick ignoring the paused tree, `pause` resuming under any screen, resume not removing Pause, resume without its paused guard, pause leaving the controls on, the ship placed at the origin, projectiles not cleared, stages freed without leaving the tree, Stage 2's metadata ignored, Restart without `run_state.restart_stage()`, Return to Menu leaving the tree paused, Start without `begin_attempt()`, a completed stage kept on screen, `pause` acting with no stage in play, and the missing-bounds and missing-`PlayerStart` refusals. Two of them survived the first draft of the tests — the controls one (the paused tree already freezes the ship) and the Restart one (with nothing committed, Retry and Restart agree) — which is why the Focus test and the Checkpoint commit in the Restart test exist.

## Setup for Astra

Nothing to attach: `ScreenRouter` is code only. The screen ids are code; which scene root maps to which id is `MenuController`'s job (F2-02).

Nothing to attach for `RunState` either. The stage ids `&"stage_01"` and `&"stage_02"` and Direct Stage 2's entry Power Level of 2 are constants in the core (`CAMPAIGN_ORDER`, `ENTRY_POWER_LEVEL`), taken from PLANEJAMENTO Section 6; tell Claude before changing either rule.

Nothing to attach for `Interface` or `MenuController`: the eight menu roots already carry `menu_controller.gd`, and `Main/Interface` is Claude's. What the scenes must keep:

- The root node names (`MainMenu` … `Results`): they are how each menu knows its screen.
- Every button path in the registry above, and `Layout/Score`, `Layout/RetryLocation`, `Layout/Heading` and `Layout/NavigationHint`. Renaming or moving one needs the same change in `MenuController`; announce it in the handoff log first. A missing path is reported at startup and that button stops working.
- Tree order decides the initial focus (the first visible focusable control), so reordering nodes can move it.
- Slider focus is not visible: see Open issues.

Nothing to attach for `GameSession`: `Main` is Claude's. What it needs from the stage scenes:

- Every stage root has a `PlayerStart` `Node3D`; the ship spawns at its global transform, and a stage without one is refused.
- A stage's Flight Volume is read from `FlightBounds/Limits` `min`/`max` metadata when present, as Stage 2 records it. Stage 1 has none, so `Main` carries X -45..45, Y 0..75, Z -570..35 for it; adding the same marker to Stage 1 would make the scene the single source.
- Stage roots stay at the origin: `PlayerStart` and the bounds are used in stage coordinates.
- A new stage is added to `Main`'s `stage_scenes` by Claude; tell Claude its id and bounds.


## Open issues

- **Resolved by F2-02: Back from Pause.** `Interface` turns `ui_cancel` on Pause into `action_requested(&"resume", {})` instead of calling `back()`, and leaves Pause up; the Session unpauses and removes it (`interface.back()`).
- **Slider focus is not visible (theme, Astra).** A focused `HSlider` shows only a slightly brighter grabber: Godot 4.7's `Slider` draws no `focus` stylebox, so `menu_theme.tres`'s `HSlider/styles/focus` is never used, and `grabber_area_highlight` is the same `SliderFill` as `grabber_area`. Options opens on the Geral slider (`docs/validation/menus-options-entry.png`), so its entry focus is hard to see. Buttons, `OptionButton` and `CheckButton` show the gold border. Requested from Astra in the roadmap: a distinct `HSlider/icons/grabber_highlight` or `grabber_area_highlight`.
- **For F7: gamepad B is both `ui_cancel` and `bomb` (F2-04 finding).** B on Pause resumes, and `Interface` consumes that press, so a bomb read as an input event (`_input` or `_unhandled_input`) never sees it: pinned by `test_the_b_press_that_resumes_never_reaches_gameplay_as_a_bomb`. A poll does see it: `Input.is_action_just_pressed(&"bomb")` is still true on the first unpaused physics tick, and `Input.action_release(&"bomb")` from the Session does not clear it, because Godot 4.7 keeps "just pressed" for the frame of the press even after a release (`input_devices/compatibility/legacy_just_pressed_behavior` is off). Measured by a first draft of that test, which failed. So the weapon (F6-03 / F7-02) must take its Bomb request from the event, not from a poll.
- **Resolved by F16-09: targeting and the resume press.** `Targeting` ignores `lock_target` and `next_target` from spawn and from each `set_controls_enabled(true)` until both are released (`require_release()`), so the B press that resumes from Pause, or the A that starts a stage, cannot lock or switch even when remapped onto either action. The dash's equivalent guard is F16-06.
- **Resolved by F2-04: Start while Options is open from Pause.** The Session toggles pause only with the HUD or Pause on top (`test_options_from_pause_keeps_the_game_paused`).
- **F2-04 decisions beyond the ticket text:** (a) Stage 2 is wired in `main.tscn` now: its scene exists and records its bounds, so Direct Stage 2 flies instead of being refused; the refusal is tested with a null entry. (b) `stage_scenes` and `stage_flight_bounds` are typed dictionaries. (c) A stage is refused not only without a scene but also without `PlayerStart` or a Flight Volume, or with a ship scene that is not a `PlayerController`, all checked before anything loaded is touched. (d) The targeting-to-camera connection stays in `PlayerController._ready` (F1-04); the Session makes none. (e) Resume acts only while the tree is paused, and `pause` only in `IN_STAGE`, so a Pause shown without a Run (as the Interface tests do) is left alone. (f) `run_ended(false)` needs no handler work, since only `return_to_menu` produces it; `stage_started` and `paused_changed` are not connected yet. (g) Unimplemented actions warn instead of passing silently. (h) `get_run_state()` exists for tests and the validation tool. (i) Unload removes nodes from the tree before freeing them; F10 and F11 must defer it when called from physics callbacks.
- **Stage 1 is flyable up to its first Gate.** All four Gates are closed in the static scene, so from `PlayerStart` (Z 20) the route ends at `Gate_S1_02` (Z -140) until F10 opens them.
- **The flow pass is synthetic.** `tools/validate_menus.gd` flew Stage 1 from the main menu on keyboard and gamepad events through the real bindings, paused, opened Options and returned, resumed and went back to the menu, and Sair was checked to exit with code 0; but no person has pressed a key or a pad button. The physical keyboard and DualSense pass is still owed, as for F1 and F2-02.
- **F2-02 decisions beyond the ticket text:** (a) initial focus is the first visible focusable *control* in tree order, not the first button, so Options starts on its first slider, the top of its authored focus loop; (b) `back` is resolved inside `Interface` and never reaches the Session, which F2-04's action list already assumes; (c) `ui_cancel` is ignored while the HUD is on top, and consumed whenever a menu is; (d) `current_screen()` was added for the Session; (e) the footer is `Layout/NavigationHint`, the authored name, and its absence on the three overlays is by design, so a test pins it instead of a runtime log; (f) a Results `mode` missing from the params means the authored Campaign layout; (g) Defeat shows the raw Checkpoint id (`Último checkpoint · CP1-A`) — a player-facing name per Checkpoint is a design call; (h) `GameSession.interface` is typed `Interface`; (i) `ScreenRouter` now emits every hide before the stack changes (see "Focus memory"); (j) gamepad A and B were added to `ui_accept` and `ui_cancel`.
- **Results with neither Continue nor Replay** leaves the empty slot where they sit above Menu principal (`docs/validation/menus-results-final.png`). Moving the two remaining buttons up is a layout call for Astra; the focus loop already skips the slot.
- **The navigation pass is synthetic.** `tools/validate_menus.gd` sends key and joypad events through the real bindings and focus search; no person has pressed a key or a pad button on these menus yet, and no pad was connected during the run. A physical keyboard and DualSense pass is still owed, as for F1.
- **Decisions beyond the ticket text:** Back refuses Defeat and Results; focus memory is dropped when its screen leaves the stack; a full screen hides the HUD too (Pause's dim layer and the HUD are not left visible under Options, so directional focus cannot reach Pause's buttons); `replace(HUD)` is a programmer error.
- The kind asserts are stripped in release builds, like every `assert` here (CONVENTIONS "Setup errors are loud").
- **RunState decisions beyond the ticket text**, each pinned by a test above: (a) score is a Run result carried into Campaign Stage 2, while Clear Time, Graze and bombs used are per stage — PLANEJAMENTO names only power and score as carried, and Section 5 calls score "a run result"; if results should show a Run-total Graze, that is one line in `_entry_tally()`. (b) The Attempt index is counted per stage, so "cleared on Attempt 1" means no Retry or Restart in that stage (STAGE_DESIGN asks each stage-clear test to record whether Checkpoints were retried). (c) Attempt changes are ignored outside `IN_STAGE`, so replaying a completed Direct Stage (F11) must call `start()` again, not `restart_stage()`. (d) `advance()` takes the Power Level as a required argument instead of an optional one.
- **Names differ from the ticket text.** State is read through `get_phase()`, `get_attempt_index()` and `is_paused()`, as the other cores do (`TargetSelector.get_current_id()`), not through public fields; the ticket's `committed_active_time` and `committed_score` are keys of `capture()`. F2-04's test line `RunState.phase == IN_STAGE` becomes `run_state.get_phase() == RunState.Phase.IN_STAGE`, and its Pause overlay reads `stage_result()["score"]` and `["graze"]`.
- **Not here:** STAGE_DESIGN's "separate uninterrupted-clear measurement for the academic duration check" is not a `RunState` value; F11-03 (active-and-clear-time-verification) owns it.
- **Runner gap met while testing:** a runtime error after a test's first assertion still reports PASS (`testing.md`). A `restore()` that kept its input emptied the core's order and crashed the restore test that way, green; both copy tests now compare captures before anything indexes the order, and the mutation run counted `SCRIPT ERROR` lines as well as FAILs.
