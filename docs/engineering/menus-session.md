# Menus and Session

Feature F2: which screen is shown, how Back returns to the caller, and, as later tickets land, the Run's state and the Session that starts, pauses and ends it. Started with ticket F2-01 on 2026-09-22 and extended by F2-03 the same day. `ScreenRouter` and `RunState` are CODE_READY. `Interface` and `MenuController` (F2-02) and `GameSession` (F2-04) add their own sections to this page.

## Purpose

`ScreenRouter` owns the navigation rules for the nine screens of GUIDE Section 14 and the HUD: which screens are visible, which overlays sit above gameplay, where Back returns to, whether gameplay is covered, and which control had focus on each screen that is waiting to be returned to. It reports every change as `screen_hidden` and `screen_shown`, so the `Interface` adapter (F2-02) only has to show, hide and focus.

It does not own any Node, any actual Control focus, input, pausing the tree, or what a button does. It does not know whether a Run is active beyond the HUD being on its stack.

`RunState` owns the Run: its Run Mode and stage order, which stage is in play and whether it is complete, the Attempt count, the pause flag Active Time respects, the Active Time, score, Graze and bombs used of the current Attempt and what a Checkpoint committed, each stage's entry values (starting Power Level, carried score), the Snapshot slice of all that, and the four lifecycle signals the Session reacts to. It does not own combat resources (Health, Shield, Bombs held), Power Progress, the live Power Level, Encounter or Objective flags (F8-03 adds them to the Snapshot), pausing the tree, loading scenes, or deciding when a Checkpoint activates.

## Files

- `scripts/ui/screen_router.gd` (Rules Core, `class_name ScreenRouter extends RefCounted`).
- `tests/unit/ui/test_screen_router.gd` (13 tests).
- `scripts/session/run_state.gd` (Rules Core, `class_name RunState extends RefCounted`, with the internal inner class `RunState.Tally`).
- `tests/unit/session/test_run_state.gd` (19 tests).

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

One transition emits every hide before any show: hides top of the stack first, shows bottom first. Each screen gets at most one signal per transition, and a screen that stays visible gets none (the HUD under a new Pause). Entries are compared by identity, so `home(HUD)` from `[hud, defeat]` (Retry) emits hidden `defeat`, hidden `hud`, shown `hud`: the adapter must tolerate a hide immediately followed by a show of the same screen.

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

The intended adapter wiring, which relies on the hide-before-show order: on `screen_hidden(id)`, `router.remember_focus(id, menu.leave())`, then hide; on `screen_shown(id, params)`, show, then `menu.enter(params, router.focus_for(id))`. A covered screen is still on the stack when its `screen_hidden` fires, so the memory sticks; a screen that Back removes has already left, so the call is a no-op.

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

## Dependencies

None. `ScreenRouter` imports nothing and holds no Node. `Interface` (F2-02) constructs it in `_ready` and connects both signals there, once.

None for `RunState` either. `GameSession` (F2-04) constructs it in `_ready`, connects its four signals there, once, and ticks it from `_physics_process` only while the tree is not paused (`Main` is `PROCESS_MODE_ALWAYS`).

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

Mutation-checked: per-id focus that is never forgotten, re-showing screens that stayed visible, hiding bottom first, "covered" meaning anything but the HUD, and Back dropping the uncovered screen's params each fail a named test above.

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

## Setup for Astra

Nothing to attach: `ScreenRouter` is code only. The screen ids are code; which scene root maps to which id is `MenuController`'s job (F2-02).

Nothing to attach for `RunState` either. The stage ids `&"stage_01"` and `&"stage_02"` and Direct Stage 2's entry Power Level of 2 are constants in the core (`CAMPAIGN_ORDER`, `ENTRY_POWER_LEVEL`), taken from PLANEJAMENTO Section 6; tell Claude before changing either rule.

## Open issues

- **Back from Pause resumes in the router only.** `back()` from `[hud, pause]` removes Pause, but the router cannot unpause the tree. F2-02's `Interface` calls `back()` on every `ui_cancel`, so Escape on the pause menu would leave the tree paused with no menu. F2-02 or F2-04 must route that case into the Session's `resume` — for example, `Interface` emits `action_requested(&"resume", {})` instead of calling `back()` when `current()` is `PAUSE`. F2-04's "the Session never unpauses on Back" is about Back from Options, which the router already keeps paused.
- **Decisions beyond the ticket text:** Back refuses Defeat and Results; focus memory is dropped when its screen leaves the stack; a full screen hides the HUD too (Pause's dim layer and the HUD are not left visible under Options, so directional focus cannot reach Pause's buttons); `replace(HUD)` is a programmer error.
- The kind asserts are stripped in release builds, like every `assert` here (CONVENTIONS "Setup errors are loud").
- **RunState decisions beyond the ticket text**, each pinned by a test above: (a) score is a Run result carried into Campaign Stage 2, while Clear Time, Graze and bombs used are per stage — PLANEJAMENTO names only power and score as carried, and Section 5 calls score "a run result"; if results should show a Run-total Graze, that is one line in `_entry_tally()`. (b) The Attempt index is counted per stage, so "cleared on Attempt 1" means no Retry or Restart in that stage (STAGE_DESIGN asks each stage-clear test to record whether Checkpoints were retried). (c) Attempt changes are ignored outside `IN_STAGE`, so replaying a completed Direct Stage (F11) must call `start()` again, not `restart_stage()`. (d) `advance()` takes the Power Level as a required argument instead of an optional one.
- **Names differ from the ticket text.** State is read through `get_phase()`, `get_attempt_index()` and `is_paused()`, as the other cores do (`TargetSelector.get_current_id()`), not through public fields; the ticket's `committed_active_time` and `committed_score` are keys of `capture()`. F2-04's test line `RunState.phase == IN_STAGE` becomes `run_state.get_phase() == RunState.Phase.IN_STAGE`, and its Pause overlay reads `stage_result()["score"]` and `["graze"]`.
- **Not here:** STAGE_DESIGN's "separate uninterrupted-clear measurement for the academic duration check" is not a `RunState` value; F11-03 (active-and-clear-time-verification) owns it.
- **Runner gap met while testing:** a runtime error after a test's first assertion still reports PASS (`testing.md`). A `restore()` that kept its input emptied the core's order and crashed the restore test that way, green; both copy tests now compare captures before anything indexes the order, and the mutation run counted `SCRIPT ERROR` lines as well as FAILs.
