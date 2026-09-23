# Menus and Session

Feature F2: which screen is shown, how Back returns to the caller, and, as later tickets land, the Run's state and the Session that starts, pauses and ends it. Started with ticket F2-01 on 2026-09-22. `ScreenRouter` is CODE_READY. `RunState` (F2-03), `Interface` and `MenuController` (F2-02) and `GameSession` (F2-04) add their own sections to this page.

## Purpose

`ScreenRouter` owns the navigation rules for the nine screens of GUIDE Section 14 and the HUD: which screens are visible, which overlays sit above gameplay, where Back returns to, whether gameplay is covered, and which control had focus on each screen that is waiting to be returned to. It reports every change as `screen_hidden` and `screen_shown`, so the `Interface` adapter (F2-02) only has to show, hide and focus.

It does not own any Node, any actual Control focus, input, pausing the tree, or what a button does. It does not know whether a Run is active beyond the HUD being on its stack.

## Files

- `scripts/ui/screen_router.gd` (Rules Core, `class_name ScreenRouter extends RefCounted`).
- `tests/unit/ui/test_screen_router.gd` (13 tests).

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

## Dependencies

None. `ScreenRouter` imports nothing and holds no Node. `Interface` (F2-02) constructs it in `_ready` and connects both signals there, once.

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

## Setup for Astra

Nothing to attach: `ScreenRouter` is code only. The screen ids are code; which scene root maps to which id is `MenuController`'s job (F2-02).

## Open issues

- **Back from Pause resumes in the router only.** `back()` from `[hud, pause]` removes Pause, but the router cannot unpause the tree. F2-02's `Interface` calls `back()` on every `ui_cancel`, so Escape on the pause menu would leave the tree paused with no menu. F2-02 or F2-04 must route that case into the Session's `resume` — for example, `Interface` emits `action_requested(&"resume", {})` instead of calling `back()` when `current()` is `PAUSE`. F2-04's "the Session never unpauses on Back" is about Back from Options, which the router already keeps paused.
- **Decisions beyond the ticket text:** Back refuses Defeat and Results; focus memory is dropped when its screen leaves the stack; a full screen hides the HUD too (Pause's dim layer and the HUD are not left visible under Options, so directional focus cannot reach Pause's buttons); `replace(HUD)` is a programmer error.
- The kind asserts are stripped in release builds, like every `assert` here (CONVENTIONS "Setup errors are loud").
