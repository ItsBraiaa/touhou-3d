# F4-01 CombatState core

Status: done (2026-09-23)
Type: core
parallel-safe: yes
Depends on: F0-02

## Goal

A Node-free `CombatState` that holds the player's combat resources for one life: Health 0 to 100, a one-charge Shield, the Invulnerability window, two Bombs, Power Level 1 to 3 with Power Progress (5 per level), excess pickups as score, defeat exactly once, and a `capture()`/`restore()` slice. It enforces the ENGINEERING_BRIEF Section 4.C and Section 8 invariants: a shielded hit never damages Health; Invulnerability rejects follow-up hits; Power never decreases on damage; Bombs cannot activate while paused or defeated; one press consumes one Bomb. The adapter that feeds it input and forwards its signals is F7-01's; the HUD that reads it is F4-02's.

## Read first

- `docs/PLANEJAMENTO.md` Section 4 (health, shield, invulnerability, bombs, power) and Section 6 (Direct Stage 2 starts at Power Level 2)
- `docs/ENGINEERING_BRIEF.md` Section 4.C and Section 8
- `CONTEXT.md`: Combat and Player terms (Health, Shield, Invulnerability, Bomb, Power Level, Power Progress, Pickup, Checkpoint, Retry)
- `docs/STAGE_DESIGN.md` "Checkpoint contract"
- `docs/engineering/CONVENTIONS.md`: "Snapshots"

## Deliverables

`scripts/combat/combat_state.gd`, `class_name CombatState extends RefCounted`. No Node, SceneTree, Input, physics or timers (ADR-0001).

- Enum `HitOutcome { REJECTED, ABSORBED, DAMAGED, DEFEATED }`.
- Constants (PLANEJAMENTO Section 4 initial tuning): `MAX_HEALTH = 100`, `HIT_DAMAGE = 10`, `HIT_INVULNERABILITY = 1.0`, `BOMB_INVULNERABILITY = 2.0`, `MAX_BOMBS = 2`, `MIN_POWER_LEVEL = 1`, `MAX_POWER_LEVEL = 3`, `PICKUPS_PER_LEVEL = 5`, `EXCESS_PICKUP_SCORE = 50`.
- **Live** means neither paused nor defeated. `take_hit`, `update_bomb_input`, `collect_power_pickup`, `collect_shield_pickup`, `refill` and `tick` change nothing unless live; `start`, `restore` and `set_paused` always work.
- `CombatState.new()` holds the stage-entry resources: Health 100, Shield on, 2 Bombs, Power Level 1, Power Progress 0, not invulnerable, not defeated, not paused, bomb button treated as held.
- `start(power_level: int, power_progress := 0)`: stage entry (Start, Direct Stage, Restart, Campaign transition). Asserts the level is in 1..3, the progress in 0..4, and 0 at level 3. Refills everything, sets the level and progress, clears Invulnerability and defeat, unpauses, treats the bomb button as held. Direct Stage 2 calls `start(2)`.
- `take_hit(damage := HIT_DAMAGE) -> HitOutcome`: asserts `damage > 0`. Not live or invulnerable: `REJECTED`, nothing changes. Shield on: Shield off, 1 s of Invulnerability, Health untouched whatever the damage: `ABSORBED`. Otherwise Health drops to at least 0; at 0 the core is defeated, `defeated()` fires after `health_changed(0)`, no Invulnerability starts: `DEFEATED`; else 1 s of Invulnerability: `DAMAGED`. Power never changes on a hit. Several hits in one tick resolve in call order, so the first accepted one makes the rest `REJECTED`.
- `tick(delta: float)`: counts Invulnerability down while live; at 0 it becomes exactly 0 and `invulnerability_changed(false)` fires.
- `update_bomb_input(held: bool) -> bool`: called once per physics tick with the button state; records `held` every call, live or not. A rising edge (held after released) activates only when live with Bombs left: Bombs − 1, Invulnerability `max(remaining, 2.0)`, `bomb_activated()`, returns true. Otherwise the edge is spent and does not fire later while held. `new()`, `start()`, `restore()` and `set_paused(true)` mark the button as held, so a release must be seen first.
- `collect_power_pickup() -> bool`: false unless live. At Power Level 3, `score_awarded(50)` and true. Otherwise Power Progress + 1, and at 5 the level rises and progress returns to 0; `power_changed(level, progress)`; true.
- `collect_shield_pickup() -> bool`: false unless live, or while the Shield is on (the Pickup stays in the world). Otherwise Shield on and true.
- `refill()`: first Checkpoint activation. When live: Health 100, Shield on, 2 Bombs. Power and Invulnerability untouched.
- `set_paused(paused: bool)`: sets the flag; pausing marks the button as held. No signal.
- `capture() -> Dictionary`: a new Dictionary of primitives, `health`, `has_shield`, `bombs`, `power_level`, `power_progress`. No transient state (STAGE_DESIGN: Retry removes damage timers).
- `restore(data: Dictionary)`: puts the five values back, clears defeat and Invulnerability, marks the button as held, leaves the pause flag, keeps no reference to `data`.
- Getters: `get_health()`, `has_shield()`, `get_bombs()`, `get_power_level()`, `get_power_progress()`, `is_invulnerable()`, `is_defeated()`, `is_paused()`.
- Signals, each only when its value changes, payload the new value: `health_changed(health: int)`, `shield_changed(shielded: bool)`, `bombs_changed(bombs: int)`, `power_changed(level: int, progress: int)`, `invulnerability_changed(invulnerable: bool)`; events: `bomb_activated()`, `score_awarded(points: int)`, `defeated()` (once per life). The only guaranteed cross-signal order is `health_changed(0)` before `defeated()`.

## Tests required

`tests/unit/combat/test_combat_state.gd`:

- Entry resources: `test_new_state_holds_the_stage_entry_resources`, `test_start_sets_the_power_level_and_refills_everything`.
- Shielded hit never damages Health: `test_shielded_hit_never_damages_health`, `test_shield_absorbs_a_hit_of_any_size`, `test_unshielded_hit_deals_its_damage`.
- Invulnerability rejects follow-up hits: `test_invulnerability_rejects_follow_up_hits`, `test_hits_land_again_once_invulnerability_ends`, `test_two_hits_in_one_tick_count_once`, `test_invulnerability_does_not_count_down_while_paused`, `test_paused_state_rejects_hits_and_pickups`.
- Power never decreases on damage: `test_power_never_decreases_on_damage`.
- Exactly-once defeat: `test_health_stops_at_zero_and_defeat_fires_exactly_once`, `test_defeated_state_accepts_nothing`.
- One press consumes one Bomb: `test_one_press_consumes_one_bomb`, `test_bomb_grants_two_seconds_of_invulnerability`, `test_no_bomb_without_charges`.
- Bombs cannot activate while paused or defeated: `test_bombs_cannot_activate_while_paused`, `test_press_begun_while_paused_does_not_bomb_on_resume`, `test_bombs_cannot_activate_while_defeated`.
- Power thresholds and excess score: `test_five_power_pickups_raise_the_power_level`, `test_power_level_stops_at_3_and_excess_pickups_award_score`.
- Pickups and Checkpoints: `test_shield_pickup_stays_available_while_shielded`, `test_refill_restores_health_shield_and_bombs_but_not_power`.
- Deep snapshots: `test_capture_is_not_changed_by_later_mutations`, `test_restore_returns_to_the_captured_life`.
- Signals: `test_signals_fire_only_on_change`.

## Out of scope

Graze and score totals (RunState, Projectile Field), duplicate-pickup dedup by pickup id (the F7-03 pickup adapter owns one-time collection), bomb clear radius and enemy damage (F6, F7), the adapter that feeds input and forwards signals (F7-01), HUD binding (F4-02), the `Snapshot` class (F8-03).

## Definition of Done

- Tests green.
- `docs/engineering/combat-hud.md` written with the `CombatState` contract, and a line for it in `docs/engineering/README.md`.
- Handoff log entry; commit `combat: add CombatState core`.

## Handoff notes for Astra

None needed for scenes: `CombatState` is code only. The tuning constants are the initial PLANEJAMENTO Section 4 values; if Astra wants to tune them, the F7 combat adapter will expose them in the Inspector.

## Outcome (2026-09-23)

Delivered as specified from a fixed API written first, with the test file and the core written in parallel from the spec by separate agents, so the tests derive from the design documents rather than from the implementation. Design readings, each pinned by a test and listed in `docs/engineering/combat-hud.md` Open issues:

- **The bomb button must be seen released after `new()`, `start()`, `restore()` and pausing.** So B pressed on the Pause menu, where it is Back and resumes the game, never bombs on resume.
- **A defeating hit starts no Invulnerability.** The life is over; nothing is left to protect.
- **Hits, pickups, refills and ticks are ignored while paused or defeated.** `start`, `restore` and `set_paused` always work.
- **A Shield pickup is refused, not consumed, while shielded.** `collect_shield_pickup()` returns false and the Pickup stays in the world (PLANEJAMENTO Section 4).
- **A Bomb is allowed during hit Invulnerability** and extends it to `max(remaining, 2 s)`; it never shortens a longer window.
- **`start()` takes an optional `power_progress`,** so the Session can decide whether a Campaign transition carries partial Power Progress; `RunState.advance()` carries only the level today.
- **Duplicate-pickup dedup by id is left to F7-03.** The core counts every call it is given.

Tests: 26 in tests/unit/combat/test_combat_state.gd; suite green at 198.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/combat-hud/issues/01-combat-state-core.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
