# Combat state and HUD

Feature F4: the player's combat resources and, as later tickets land, the HUD that shows them and the boss panel. Started with ticket F4-01 on 2026-09-23. `CombatState` is CODE_READY, and since F4-02 the `Hud` adapter shows it and marks the locked target, and the Session owns one `CombatState` for its lifetime. Since F4-03 it also carries the boss panel, attack-cue and threat API that bosses and the Stage Director call.

## Purpose

`CombatState` owns the player's combat resources for one life: Health (an integer percentage, 0 to 100), the one-charge Shield, the Invulnerability window after a hit or a Bomb, the Bomb charges and the rising edge of the bomb button, Power Level 1 to 3 and Power Progress toward the next level, the score an excess Power Pickup is worth, defeat exactly once, the Checkpoint refill, and the Snapshot slice of the five lasting values. It reports every change as a signal carrying the new value.

It does not own any Node, input polling, collision, timers, Graze or score totals (RunState and the Projectile Field), which Pickup was already collected (the F7-03 pickup adapter), the Bomb's clear radius or its damage to enemies (F6, F7), pausing the tree, or what the HUD draws. The Session starts and pauses it and the HUD renders it (F4-02); the F7-01 combat adapter will feed it and forward its signals.

## Files

- `scripts/combat/combat_state.gd` (Rules Core, `class_name CombatState extends RefCounted`).
- `tests/unit/combat/test_combat_state.gd` (26 tests).
- `scripts/ui/hud.gd` (Adapter, `class_name Hud extends Control`, on the root of Astra's `scenes/ui/hud.tscn`).
- `tests/scene/test_hud_contract.gd` (11 tests), plus four F4-02 cases in `tests/scene/test_game_session_flow.gd`.
- `scenes/dev/hud_harness.tscn` and `.gd` (F4-03): a scripted, self-checking sequence over the boss panel, cue and threats; dev only.

## CombatState contract

### Exports

None: a Rules Core is code only (ADR-0001). The F7 combat adapter will expose any tuning Astra needs.

### Live

The core is **live** when it is neither paused nor defeated. `take_hit`, `update_bomb_input`, `collect_power_pickup`, `collect_shield_pickup`, `refill` and `tick` change nothing unless live: `take_hit` returns `REJECTED` and the bool methods return false. `start`, `restore` and `set_paused` always work.

A new instance holds the stage-entry resources: Health 100, Shield on, 2 Bombs, Power Level 1, Power Progress 0, not invulnerable, not defeated, not paused, and the bomb button treated as held.

### Signals

Each value signal fires only when its value actually changes, with the new value as payload.

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `health_changed` | `health: int` | Health changed: an unshielded hit, `refill`, `start` or `restore`. |
| `shield_changed` | `shielded: bool` | The Shield broke on a hit, or came back through a Shield Pickup, `refill`, `start` or `restore`. |
| `bombs_changed` | `bombs: int` | A Bomb went off, or `refill`, `start` or `restore` changed the count. |
| `power_changed` | `level: int, progress: int` | A Power Pickup below Power Level 3 was collected, or `start` or `restore` changed either value. |
| `invulnerability_changed` | `invulnerable: bool` | true when an accepted non-defeating hit or a Bomb starts the window while not already invulnerable; false when `tick` runs it out, or `start` or `restore` clears it. |
| `bomb_activated` | | A Bomb went off. F7 clears Projectiles; the Session calls `RunState.note_bomb_used()`. |
| `score_awarded` | `points: int` | A Power Pickup was collected at Power Level 3 (`EXCESS_PICKUP_SCORE`). The Session forwards it to `RunState.add_score()`. |
| `defeated` | | Health reached 0. Exactly once per life; `start` or `restore` begins a new one. |

On a defeating hit `health_changed(0)` is emitted before `defeated()`. No other order between signals is part of the contract.

### Hit outcomes

`CombatState.HitOutcome`, returned by `take_hit(damage := HIT_DAMAGE)` (asserts `damage > 0`):

| Outcome | When | Effect |
| --- | --- | --- |
| `REJECTED` | Not live, or invulnerable | Nothing changes. |
| `ABSORBED` | Shield on | Shield off, `HIT_INVULNERABILITY` of Invulnerability; Health untouched whatever the damage. |
| `DAMAGED` | Shield off, Health stays above 0 | Health − damage, `HIT_INVULNERABILITY` of Invulnerability. |
| `DEFEATED` | Shield off, Health reaches 0 | Health 0 (never below), defeated, `defeated()` after `health_changed(0)`, no Invulnerability. |

Power Level and Power Progress never change on a hit. Several hits in one tick resolve in call order: the first accepted one starts Invulnerability, so every later one that tick is `REJECTED`.

### Bomb input

The adapter passes the bomb button state once per physics tick to `update_bomb_input(held)`, which records it on every call, live or not. A Bomb goes off only on a rising edge (held now, released at the previous call) while live with a charge left: Bombs − 1, Invulnerability becomes `max(remaining, BOMB_INVULNERABILITY)`, `bomb_activated()`, and the call returns true. Any other rising edge is spent and returns false; it does not fire later while the button stays held. So one press consumes exactly one Bomb however long it is held.

`new()`, `start()`, `restore()` and `set_paused(true)` mark the button as held, so a press that began before them never activates: a release must be seen first. This is how gamepad B pressed on the Pause menu, where it is Back and resumes the game, never bombs on the first unpaused tick (menus-session.md Open issues, "gamepad B is both `ui_cancel` and `bomb`").

### Power

`collect_power_pickup()` below Power Level 3 adds 1 to Power Progress; at `PICKUPS_PER_LEVEL` the level rises and progress returns to 0, then `power_changed(level, progress)`. At Power Level 3 it emits `score_awarded(EXCESS_PICKUP_SCORE)` and leaves both unchanged. Five Pickups raise 1 to 2, ten raise 1 to 3, and the eleventh awards 50. Power Progress is always 0 at Power Level 3.

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `start(power_level: int, power_progress := 0)` | Session: Start, Direct Stage, Restart, Campaign transition | Asserts `power_level` in 1..3, `power_progress` in 0..4 and 0 at level 3. Health 100, Shield on, 2 Bombs, the given level and progress; clears Invulnerability and defeat, unpauses, marks the button as held. Emits what changed. Direct Stage 2 calls `start(2)`; the level comes from `RunState.starting_power_level()`. |
| `take_hit(damage := HIT_DAMAGE) -> HitOutcome` | F7 combat adapter, from the Projectile Field's Core hits | See "Hit outcomes". |
| `tick(delta: float)` | F7 combat adapter `_physics_process` | While live and invulnerable, counts the window down; at 0 or below it becomes exactly 0 and `invulnerability_changed(false)` fires. |
| `update_bomb_input(held: bool) -> bool` | F7 combat adapter, once per physics tick | See "Bomb input". True when this call set off a Bomb. |
| `collect_power_pickup() -> bool` | F7-03 pickup adapter | See "Power". False unless live; true otherwise. |
| `collect_shield_pickup() -> bool` | F7-03 pickup adapter | False unless live, and false while the Shield is on (the Pickup stays in the world). Otherwise Shield on, `shield_changed(true)`, true. |
| `refill()` | Session, on a Checkpoint's first activation | When live: Health 100, Shield on, 2 Bombs, emitting what changed. Power and Invulnerability untouched. |
| `set_paused(paused: bool)` | Session, on pause and resume | Sets the flag. Pausing marks the button as held. No signal. |
| `capture() -> Dictionary` | Session, on a Checkpoint's activation | See "Snapshot slice". |
| `restore(data: Dictionary)` | Session, on Retry with the Checkpoint's capture | See "Snapshot slice". |
| `get_health() -> int`, `has_shield() -> bool`, `get_bombs() -> int`, `get_power_level() -> int`, `get_power_progress() -> int`, `is_invulnerable() -> bool`, `is_defeated() -> bool`, `is_paused() -> bool` | HUD (F4-02), read only; Session; tests | Read-only state. |

### Constants

Initial tuning from PLANEJAMENTO Section 4.

| Constant | Value | Meaning |
| --- | --- | --- |
| `MAX_HEALTH` | 100 | Full Health, an integer percentage. |
| `HIT_DAMAGE` | 10 | A common bullet; `take_hit()`'s default. |
| `HIT_INVULNERABILITY` | 1.0 | Seconds after an accepted hit, absorbed or damaging. |
| `BOMB_INVULNERABILITY` | 2.0 | Seconds after a Bomb, at least. |
| `MAX_BOMBS` | 2 | Bombs at stage entry and after a refill. |
| `MIN_POWER_LEVEL`, `MAX_POWER_LEVEL` | 1, 3 | Power Level range. |
| `PICKUPS_PER_LEVEL` | 5 | Power Pickups per level. |
| `EXCESS_PICKUP_SCORE` | 50 | Score for a Power Pickup at Power Level 3. |

### Snapshot slice

`capture()` returns a new Dictionary of primitives on every call: `health` (int), `has_shield` (bool), `bombs` (int), `power_level` (int), `power_progress` (int). Invulnerability, defeat, the pause flag and the button state are not in it: STAGE_DESIGN "Checkpoint contract" says a Retry removes damage timers. Later play does not change a capture.

`restore(data)` puts those five values back, clears defeat and Invulnerability, marks the button as held, and leaves the pause flag alone. It emits a signal for each value that changed, including `invulnerability_changed(false)` if the core was invulnerable, and keeps no reference to `data`. F8-03 places this slice beside RunState's in the `Snapshot` class.

## Hud contract

`Hud` (`scripts/ui/hud.gd`, F4-02) is the Adapter on the root of `scenes/ui/hud.tscn`. It renders GUIDE Section 15's player panel from a `CombatState` and keeps `TargetMarker` on the target a `Targeting` has locked. It observes and never decides: it calls no `CombatState` method except the getters (ENGINEERING_BRIEF 4.I "Key boundary"). `Interface` instances it once, under every menu; `Interface` processes while the tree is paused, so the HUD does too.

### Exports

| Export | Default | Meaning |
| --- | --- | --- |
| `lit_modulate` | `Color(1, 1, 1, 1)` | Modulate of the Shield and a Bomb icon while available. |
| `dim_modulate` | `Color(1, 1, 1, 0.25)` | Modulate of the Shield and a Bomb icon while spent. Claude's proposal; Astra tunes it on the HUD root. |

### Load-bearing paths

`PlayerStatus/HealthBar`, `HealthValue`, `Shield`, `Bomb1`, `Bomb2`, `PowerValue`, `PowerProgress` and `TargetMarker`, as the `*_PATH` constants. `_ready` reports each missing one with `push_error`, naming the path, and disables the HUD's processing; `bind` then does nothing. Renaming one in the scene needs the matching code change.

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `bind(combat_state: CombatState, targeting: Targeting, camera: Camera3D)` | Session `_load_stage`, after the ship's `setup`; the arena harness | Calls `unbind()` first, connects `health_changed`, `shield_changed`, `bombs_changed`, `power_changed` and `targeting.target_changed`, then renders the current getter values and `targeting.get_current_target()`. Binding twice never connects twice. |
| `unbind()` | Session `_unload_stage`, before the ship is freed | Disconnects what `bind` connected (a freed `Targeting` has already dropped its connection), forgets the three references, hides `TargetMarker`. Safe while unbound. |

### Rendering

| Node | Shows |
| --- | --- |
| `HealthBar.value`, `HealthValue.text` | Health, clamped to 0..100; the label as `"%d%%"` (`"90%"`). |
| `Shield.modulate` | `lit_modulate` while shielded, `dim_modulate` otherwise. |
| `Bomb1.modulate`, `Bomb2.modulate` | Lit at 1 or more and at 2 Bombs respectively, dim otherwise. |
| `PowerValue.text` | The Power Level. |
| `PowerProgress.value` | Power Progress, 0..4 of the authored `max_value` 5; **full at Power Level 3**, where the core always holds 0 (Claude's reading of GUIDE Section 15's "handle maximum power according to design"). |
| `TargetMarker` | In `_process`: centered on `camera.unproject_position(point)`, where the point is the locked target's `HitVolume` (as `Targeting` measures it), else the target's own position. Shown only while bound, the target is valid, and `not camera.is_position_behind(point)`. `target_changed(null)` hides it at once; a freed target hides it on the next frame. The HUD root is full-rect at the origin, so the marker's `position` is in viewport coordinates. |

### Boss panel, cue and threats (F4-03)

Presentation calls for the boss adapter (F12-02, wired by F12-03) and the Stage Director (F10-01, threats). The HUD only shows what it is told: the caller says what each Phase bar holds and how long a cue or a threat shows, and passes Portuguese text from the boss Definitions; the HUD adds none.

| Method | Effect |
| --- | --- |
| `show_boss(display_name: String, phase_count: int)` | `BossStatus` visible, `BossName.text = display_name`, `Phase1`..`Phase<phase_count>` visible at 100 and lit, the others hidden at their authored positions. A `phase_count` outside `MIN_PHASES`..`MAX_PHASES` (2..3) is reported with `push_error` and clamped. Calling it again replaces the boss. |
| `set_phase_health(phase_index: int, ratio: float)` | 0-based. `Phase<index+1>.value = clampf(ratio, 0, 1) * max_value`; at 0 the bar gets `completed_phase_modulate`, above 0 `lit_modulate`. An index outside the Phases shown (any index while no boss is shown) is reported and ignored. |
| `show_attack_cue(text: String, seconds: float)` | `AttackName.text = text`, shown for `seconds` of unpaused time. A new cue replaces the text and restarts the timer. |
| `hide_boss()` | Hides `BossStatus` and `AttackName`; every bar back to full and lit. |
| `show_threat(side: int, seconds: float)` | `-1` shows `ThreatLeft`, `+1` `ThreatRight`, each on its own timer; a repeat while shown extends it to `max(remaining, seconds)`. Any other side is reported and ignored. |

- **Timers.** They count down in `_process` only while `get_tree().paused` is false: the HUD processes during Pause (it lives under `Interface`), and PLANEJAMENTO Section 7 freezes combat timers there. A node counts down while it is visible, so a cue of 0 seconds hides on the next unpaused frame.
- **Clearing.** `unbind()` (so every `bind()` and every stage unload) also calls `hide_boss()` and hides both threats: nothing is left on screen between stages.
- **Export.** `completed_phase_modulate: Color = Color(1, 1, 1, 0.3)`, Claude's proposal for Astra to tune. `lit_modulate` also lights the Phase bars.
- **Load-bearing paths**, added to the ones above: `BossStatus`, `BossStatus/BossName`, `BossStatus/Phase1`..`Phase3` (`PHASE_BAR_PATHS`), `AttackName`, `ThreatLeft`, `ThreatRight`.
- **Dev harness.** `scenes/dev/hud_harness.tscn` plays the whole API in front of the static arena and checks each step (see the validation page).

### Session wiring (`game_session.gd`)

- One `var _combat_state := CombatState.new()` for the Session's lifetime; `get_combat_state() -> CombatState` for tests and dev tools, like `get_run_state()`.
- `_start_run`: `_combat_state.start(_run_state.starting_power_level())` right after `RunState.start`. `_restart_stage`: the same after `RunState.restart_stage()`. A Direct Stage 2 therefore enters at Power Level 2.
- `_set_paused(paused)` also calls `_combat_state.set_paused(paused)`.
- `_load_stage` binds the HUD to the new ship's `targeting` and `camera_rig.camera`; `_unload_stage` unbinds it before freeing the ship.
- No `CombatState` signal is connected by the Session yet: F7-01 connects them once in `_ready`.

`Interface.get_hud()` now returns `Hud`, and `Interface` refuses a `hud_scene` whose root is not a `Hud` with `push_error`, disabling itself as it does for an unset `hud_scene`.

## Dependencies

`CombatState` imports nothing and holds no Node. `Hud` depends on `CombatState` (signals and getters) and `Targeting` (`target_changed`, `get_current_target`, `HIT_VOLUME_PATH`), and is bound by `GameSession`.

Who connects to `CombatState`: the HUD (F4-02) to the four value signals, for rendering only; and, still to come, the Session, forwarding `score_awarded` to `RunState.add_score()` and `bomb_activated` to `RunState.note_bomb_used()`; the F7 bomb clear to `bomb_activated`. The F7-01 combat adapter will own the instance per life, tick it and feed it hits and input; the Session already calls `start` and `set_paused` (F4-02) and will call `refill`, `capture` and `restore`.

## Invariants and tests

| Invariant (ticket F4-01, ENGINEERING_BRIEF Sections 4.C and 8, PLANEJAMENTO Section 4) | Test |
| --- | --- |
| A new core holds the stage-entry resources | `test_new_state_holds_the_stage_entry_resources` |
| `start()` sets the Power Level and refills everything, clearing defeat, Invulnerability and pause | `test_start_sets_the_power_level_and_refills_everything` |
| **A shielded hit never damages Health** | `test_shielded_hit_never_damages_health` |
| The Shield absorbs a hit of any size | `test_shield_absorbs_a_hit_of_any_size` |
| An unshielded hit deals its damage | `test_unshielded_hit_deals_its_damage` |
| **Invulnerability rejects immediate follow-up hits** | `test_invulnerability_rejects_follow_up_hits` |
| Hits land again once Invulnerability ends (post-invulnerability damage) | `test_hits_land_again_once_invulnerability_ends` |
| Several hits in one tick: deterministic, only the first counts | `test_two_hits_in_one_tick_count_once` |
| Invulnerability does not count down while paused | `test_invulnerability_does_not_count_down_while_paused` |
| Paused: hits and pickups are refused | `test_paused_state_rejects_hits_and_pickups` |
| **Power does not decrease on damage** | `test_power_never_decreases_on_damage` |
| Health stops at 0 and defeat fires exactly once, after `health_changed(0)` | `test_health_stops_at_zero_and_defeat_fires_exactly_once` |
| Defeated: hits, pickups, refills and ticks change nothing | `test_defeated_state_accepts_nothing` |
| **One press consumes one Bomb** (bomb input edges, charge consumption) | `test_one_press_consumes_one_bomb` |
| A Bomb grants 2 s of Invulnerability, extending a shorter window | `test_bomb_grants_two_seconds_of_invulnerability` |
| **Bombs cannot activate while paused** | `test_bombs_cannot_activate_while_paused` |
| A press begun while paused does not bomb on resume | `test_press_begun_while_paused_does_not_bomb_on_resume` |
| **Bombs cannot activate while defeated** | `test_bombs_cannot_activate_while_defeated` |
| No Bomb without charges, and the spent edge does not fire later | `test_no_bomb_without_charges` |
| Power thresholds: five Pickups raise the Power Level | `test_five_power_pickups_raise_the_power_level` |
| Power Level stops at 3; excess Pickups award score | `test_power_level_stops_at_3_and_excess_pickups_award_score` |
| A Shield Pickup stays available while shielded | `test_shield_pickup_stays_available_while_shielded` |
| Refill restores Health, Shield and Bombs but not Power (resource restoration) | `test_refill_restores_health_shield_and_bombs_but_not_power` |
| A capture is not changed by later mutations (deep checkpoint snapshots) | `test_capture_is_not_changed_by_later_mutations` |
| Restore returns to the captured life, clearing defeat and Invulnerability | `test_restore_returns_to_the_captured_life` |
| Value signals fire only on a change | `test_signals_fire_only_on_change` |

Bold rows are the five ENGINEERING_BRIEF Section 4.C required invariants.

| Invariant (ticket F4-02, GUIDE Section 15, ENGINEERING_BRIEF 4.I) | Test |
| --- | --- |
| The HUD root is a `Hud` with every Section 15 path, marker hidden | `test_hud_root_is_a_hud_with_every_section_15_path` |
| `bind` renders the current values (Power Level 2, 100 %, Shield and Bombs lit) | `test_bind_renders_the_current_values` |
| `bind` renders values that differ from the authored examples | `test_bind_renders_values_that_differ_from_the_authored_ones` |
| Hits and Bombs update the panel | `test_hits_and_bombs_update_the_panel` |
| Power Progress, and the full bar at Power Level 3 | `test_power_progress_and_the_full_bar_at_max_level` |
| Rebinding never double-connects | `test_rebinding_never_double_connects` |
| `unbind` disconnects and hides the marker | `test_unbind_disconnects_and_hides_the_marker` |
| **The HUD never changes the combat state** | `test_hud_never_changes_the_combat_state` |
| The marker centers on the projected `HitVolume` and follows it | `test_marker_centers_on_the_projected_target` |
| The marker hides behind the camera | `test_marker_hides_behind_the_camera` |
| The marker hides on release and when the target is freed | `test_marker_hides_on_release_and_when_the_target_is_freed` |
| A Run starts the `CombatState` and binds the HUD (Direct Stage 2 at Power Level 2) | `test_game_session_flow.gd::test_a_run_starts_the_combat_state_and_binds_the_hud` |
| Pause pauses the `CombatState` | `test_game_session_flow.gd::test_pause_pauses_the_combat_state` |
| Restart rebinds the HUD to the new ship only, with the entry resources | `test_game_session_flow.gd::test_restart_rebinds_the_hud_to_the_new_ship` |
| Return to Menu unbinds the HUD | `test_game_session_flow.gd::test_return_to_menu_unbinds_the_hud` |

The marker in the running harness is recorded in [validation/combat-hud.md](../validation/combat-hud.md).

## Setup for Astra

Nothing to attach: `CombatState` is a code-only core, and GUIDE Section 6 says code-only helpers such as combat state need no scene-attached script. The constants are the initial PLANEJAMENTO Section 4 values; tell Claude before changing a rule, and ask for any value to be tuned in the Inspector when the F7 combat adapter lands.

`hud.tscn` needs no change for F4-02. Tune `dim_modulate` in the Inspector on the HUD root, or say if Power Level 3 should read differently than a full `PowerProgress` bar. Keep the Section 15 paths above: each one is load-bearing.

## Open issues

- **Not fed yet.** The Session owns, starts and pauses one `CombatState` and the HUD shows it (F4-02), but nothing changes it in play: the F7-01 combat adapter will feed it hits and bomb input and the Session will forward its signals and call `refill`, `capture` and `restore`.
- **Visible feedback.** The HUD now shows the entry values in a Run and in the arena harness; hits and Bombs reach it once F7 feeds the core.
- **F4-02 readings.** (a) At Power Level 3 `PowerProgress` shows full, since the core holds 0 there; (b) Health is clamped to 0..100 on the panel although the core never leaves that range; (c) the marker simply hides for an off-screen or behind-camera target (screen-edge warnings are F4-03's threats); (d) a locked target is kept in front of the camera by `CameraRig`'s lock framing, so orbiting does not put it behind: it is only behind while it moves there faster than the framing turns (validation page).
- **F4-03 readings.** (a) With two Phases `Phase3` is hidden and the right third of `BossStatus` stays empty; a two-Phase layout is Astra's call (D-07 Part B). (b) A Phase raised above 0 again is lit again; the HUD infers no Phase order. (c) No test file covers the F4-03 API: the sprint's no-new-tests rule (2026-09-23) replaced the ticket's ten listed tests with the self-checking `hud_harness.tscn` run.
- **Marker coordinates.** The marker's `position` is set in the HUD root's coordinates, equal to viewport coordinates while the HUD is full-rect at the origin of its CanvasLayer, as in `main.tscn` and the harness.
- **F4-01 design readings beyond the source text**, each pinned by a test above: (a) the bomb button must be seen released after `new()`, `start()`, `restore()` and pausing, so B pressed on the Pause menu, where it is Back, never bombs on resume; (b) a defeating hit starts no Invulnerability; (c) hits, pickups, refills and ticks are ignored while paused or defeated; (d) a Shield Pickup is refused, not consumed, while shielded, so the pickup adapter must leave it in the world when `collect_shield_pickup()` returns false; (e) a Bomb is allowed during hit Invulnerability and extends it to `max(remaining, 2 s)`; (f) `start()` takes an optional `power_progress` so the Session can decide whether a Campaign transition carries partial Power Progress, while `RunState.advance()` carries only the level today; (g) duplicate-pickup dedup by id is left to the F7-03 pickup adapter, and the core counts every call it receives.
- The `start()` and `take_hit()` asserts are stripped in release builds, like every `assert` here (CONVENTIONS "Setup errors are loud").
