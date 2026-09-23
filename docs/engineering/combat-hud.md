# Combat state and HUD

Feature F4: the player's combat resources and, as later tickets land, the HUD that shows them and the boss panel. Started with ticket F4-01 on 2026-09-23. `CombatState` is CODE_READY; the HUD binding and target marker (F4-02) and the boss panel and attack-cue API (F4-03) are not built yet.

## Purpose

`CombatState` owns the player's combat resources for one life: Health (an integer percentage, 0 to 100), the one-charge Shield, the Invulnerability window after a hit or a Bomb, the Bomb charges and the rising edge of the bomb button, Power Level 1 to 3 and Power Progress toward the next level, the score an excess Power Pickup is worth, defeat exactly once, the Checkpoint refill, and the Snapshot slice of the five lasting values. It reports every change as a signal carrying the new value.

It does not own any Node, input polling, collision, timers, Graze or score totals (RunState and the Projectile Field), which Pickup was already collected (the F7-03 pickup adapter), the Bomb's clear radius or its damage to enemies (F6, F7), pausing the tree, or what the HUD draws. Nothing is wired to it yet: the F7-01 combat adapter will feed it and forward its signals, and F4-02 will render them.

## Files

- `scripts/combat/combat_state.gd` (Rules Core, `class_name CombatState extends RefCounted`).
- `tests/unit/combat/test_combat_state.gd` (26 tests).

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

## Dependencies

None: `CombatState` imports nothing and holds no Node.

Who will connect to it: the HUD (F4-02) to the value signals, for rendering only; the Session, forwarding `score_awarded` to `RunState.add_score()` and `bomb_activated` to `RunState.note_bomb_used()`; the F7 bomb clear to `bomb_activated`. The F7-01 combat adapter will own the instance per life, tick it and feed it hits and input; the Session will call `start`, `refill`, `capture`, `restore` and `set_paused`.

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

## Setup for Astra

Nothing to attach: `CombatState` is a code-only core, and GUIDE Section 6 says code-only helpers such as combat state need no scene-attached script. The constants are the initial PLANEJAMENTO Section 4 values; tell Claude before changing a rule, and ask for any value to be tuned in the Inspector when the F7 combat adapter lands.

## Open issues

- **Not wired yet.** No adapter or scene uses `CombatState`: the F7-01 combat adapter will own it per life, feed it hits and bomb input and forward its signals, and the Session will call `start`, `refill`, `capture`, `restore` and `set_paused`.
- **No visible feedback in a combat scene yet.** ENGINEERING_BRIEF Section 4.C's completion evidence asks for automated tests of the invariants, which exist, plus visible feedback in a combat scene, which needs F7 and the HUD binding (F4-02).
- **F4-01 design readings beyond the source text**, each pinned by a test above: (a) the bomb button must be seen released after `new()`, `start()`, `restore()` and pausing, so B pressed on the Pause menu, where it is Back, never bombs on resume; (b) a defeating hit starts no Invulnerability; (c) hits, pickups, refills and ticks are ignored while paused or defeated; (d) a Shield Pickup is refused, not consumed, while shielded, so the pickup adapter must leave it in the world when `collect_shield_pickup()` returns false; (e) a Bomb is allowed during hit Invulnerability and extends it to `max(remaining, 2 s)`; (f) `start()` takes an optional `power_progress` so the Session can decide whether a Campaign transition carries partial Power Progress, while `RunState.advance()` carries only the level today; (g) duplicate-pickup dedup by id is left to the F7-03 pickup adapter, and the core counts every call it receives.
- The `start()` and `take_hit()` asserts are stripped in release builds, like every `assert` here (CONVENTIONS "Setup errors are loud").
