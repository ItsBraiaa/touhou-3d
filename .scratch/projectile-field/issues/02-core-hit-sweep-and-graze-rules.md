# F5-02 Core hit sweep and Graze rules

Status: done
Type: core
parallel-safe: yes
Depends on: F5-01
Lane: path
Model: Claude Opus 5.5, 3-agent workflow (implementer, test-writer, reviewer)

## Goal

`ProjectileField` sweeps every hostile Projectile against the player's moving Core and Graze Volume on every tick. It reports a hit as `player_hit(projectile_id, damage)` and a near miss as `grazed(projectile_id)`, and it enforces the ENGINEERING_BRIEF Section 4.D invariants: a fast Projectile that crosses the Core between two ticks hits; a hit takes precedence over Graze on the same contact; each hostile Projectile grazes at most once; and Invulnerability never lets the player farm Graze. The field only decides contact. What a hit does is `CombatState.take_hit()` (F4-01), and the Session wires that in F7-01.

## Read first

- `docs/adr/0004-central-projectile-field.md` (sphere-versus-segment sweeps each physics tick; `DamageCore` and `GrazeVolume` stay geometry sources)
- `docs/PLANEJAMENTO.md` Section 4 "Graze and score" (once per Projectile, a sphere slightly larger than the Core, a hit or Shield hit takes priority, no new Graze during Invulnerability) and "Focus and vulnerable core"
- `docs/ENGINEERING_BRIEF.md` Section 4.D and Section 8 ("Fast projectile segment crossing the core and hit-before-graze priority", "Graze once per projectile; no rewards from cleanup or invulnerability")
- `docs/engineering/projectile-field.md` (F5-01: tick order, events rule) and `.scratch/projectile-field/spec.md`
- `docs/engineering/combat-hud.md` "Hit outcomes" (the core rejects hits while invulnerable; several hits in one tick resolve in call order)
- `scenes/player/player_ship.tscn` for scale only: Core radius 0.18, Graze radius 0.55 (F6-02 reads them from the shapes)

## Files

- **Creates:** nothing.
- **Edits:** `scripts/combat/projectile_field.gd` (player state, the sweep, a graze-spent flag array, the two signals); `tests/unit/combat/test_projectile_field.gd` (new cases).
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F5-02 row), `docs/HANDOFF_LOG.md`, `docs/engineering/projectile-field.md` ("Core sweep and Graze" section and invariant rows).
- **Must not touch:** `scripts/combat/combat_state.gd`, `scripts/combat/pattern_emitter.gd` and `scripts/definitions/pattern_definition.gd` (F5-04 may be running beside this ticket), anything under `scenes/`.
- **Conflicts with:** F5-01 and F5-03 (the same two files; serialized by Depends on). Disjoint from F5-04.

## Deliverables

On `ProjectileField`:

- `set_player(previous_center: Vector3, center: Vector3, core_radius: float, graze_radius: float, invulnerable: bool)`: the Core's center at the previous tick and now, both radii, and whether the player is invulnerable. The adapter calls it before every `tick`, and the values hold until it is called again. `clear_player()`: there is no player to sweep (between stages, after the ship is freed). A new field starts with no player.
- Signals: `player_hit(projectile_id: int, damage: int)` and `grazed(projectile_id: int)`, with `##` comments. Both follow F5-01's events rule: they are emitted after the pass, in slot order.
- The sweep is step 4 of F5-01's tick order: after the obstacle check, before the move. It applies to HOSTILE Projectiles only. Player Projectiles never hit or graze the player.
  - **Relative segment.** In the player's frame the Projectile moves from `from - previous_center` to `to - center`. Its closest distance `d` to the origin decides contact, so a fast bullet, a fast player, or both at once cannot tunnel through.
  - **Core contact:** `d <= core_radius + radius`. If the player is not invulnerable, the Projectile is removed and `player_hit(id, damage)` is queued. It never grazes: hit before Graze on the same contact.
  - **Graze contact:** `d <= graze_radius + radius`, no Core contact, and the Projectile has not yet spent its Graze. The Projectile is marked spent and `grazed(id)` is queued, at most once per Projectile for its whole life.
  - **Invulnerable:** a Core contact reports nothing and does not remove the Projectile, which passes through. Any contact, Core or Graze, marks the Projectile spent, so it cannot graze later either. This is Claude's strict reading of "disable new graze awards during invulnerability", chosen so a Bomb or a hit window can never pre-load Graze; a test pins it.
  - **The first `player_hit` of a tick makes the rest of that tick invulnerable.** The event reaches `CombatState` only after the pass, and an accepted hit starts Invulnerability or defeat there. So later Core contacts in the same pass report nothing and pass through, later contacts are marked spent, and the tick awards no further Graze. This keeps the field and the core in agreement.
- Every rule is written in the class doc comment beside F5-01's tick order.

## Tests required

In `tests/unit/combat/test_projectile_field.gd`:

- `test_fast_projectile_crossing_the_core_between_ticks_hits` (ENGINEERING_BRIEF 8: 600 units per second at 1/60, the Core in the middle of one tick's segment)
- `test_projectile_passing_just_outside_the_core_does_not_hit`
- `test_player_moving_through_a_slow_projectile_is_hit` (the relative sweep)
- `test_hit_removes_the_projectile_and_reports_its_damage`
- `test_hit_takes_priority_over_graze_on_the_same_contact` (ENGINEERING_BRIEF 8)
- `test_each_hostile_projectile_grazes_at_most_once` (ENGINEERING_BRIEF 8: a slow Projectile that stays in the Graze Volume for 60 ticks gives exactly one `grazed`)
- `test_invulnerability_does_not_enable_graze` (ENGINEERING_BRIEF 8: no Graze while invulnerable, and none from the same Projectile after Invulnerability ends)
- `test_invulnerable_player_is_not_hit_and_the_projectile_passes_through`
- `test_after_the_first_hit_in_a_tick_the_rest_of_the_tick_is_invulnerable` (two contacts in one tick give one `player_hit` and no `grazed`)
- `test_projectile_radius_counts_toward_contact`
- `test_player_projectiles_never_hit_or_graze_the_player`
- `test_projectile_blocked_by_an_obstacle_does_not_hit_the_player`
- `test_without_a_player_nothing_is_swept`
- `test_events_are_emitted_after_the_pass_in_slot_order`
- `test_clear_all_from_a_listener_drops_the_remaining_events`

Grep the output for `SCRIPT ERROR`.

## Out of scope

- Clears, hit spheres and `enemy_hit` (F5-03).
- Converting `player_hit` into `CombatState.take_hit()` and `grazed` into `RunState.add_graze()` plus score (F7-01).
- Reading the radii from the ship's shapes and feeding `set_player` each tick (F6-02).
- Graze light and sound feedback (F7-01, and F13, which is cut pending the user).

## Definition of Done

- `tools/test.ps1` is green with no `SCRIPT ERROR`, every test above exists, and there are no Error-level warnings.
- `docs/engineering/projectile-field.md` is updated with the sweep, the Graze rules, the strict Invulnerability reading, and one invariant-to-test row per ENGINEERING_BRIEF 8 item above.
- A handoff log entry, ticket `Status: done` with an Outcome, and the roadmap row.
- One commit: `combat: add ProjectileField Core sweep and Graze rules`.

## Handoff notes for Astra

None: this is code only. The Graze rule uses `GrazeVolume`'s authored radius (0.55) and the Core's (0.18) as F6-02 reads them. Changing those spheres changes contact exactly, with no code change.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/projectile-field/issues/02-core-hit-sweep-and-graze-rules.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```

## Outcome (2026-09-23)

Delivered as specified in `scripts/combat/projectile_field.gd`, lane path, as implementer plus reviewer. **No unit tests:** the user's no-new-tests rule for the rest of the sprint (relayed by the planning session on 2026-09-23) arrived while this ticket was in progress; the test-writer was stopped before it wrote anything, and the "Tests required" list is not delivered. Verification is the existing suite (the 12 F5-01 tests still pass against the extended core), the `tools/lane.ps1 land` run, and the review. The sweep's first real run is F6-02 and F7-01.

- `set_player(previous_center, center, core_radius, graze_radius, invulnerable)` and `clear_player()`; `setup()` keeps the player. It asserts `0 < core_radius <= graze_radius`.
- Signals `player_hit(projectile_id, damage)` and `grazed(projectile_id)`, buffered during the pass (three packed arrays) and emitted after it in slot order. A listener's `clear_all()` empties the buffer, which ends the emission loop.
- The sweep is the relative-segment closest distance of the ticket. A zero-length relative segment uses its start point.
- Strict Invulnerability reading as the ticket states it. **Ruling 5 pending:** D-07 Part B had not landed when F5-02 did. The lenient alternative is a one-line move of the spend into the `grazed` branch.
- Note for F5-03: a hostile clear called from a listener must cancel the pending `grazed` events of the Projectiles it removes (its ticket requires it) without dropping `player_hit`. Checking `is_alive` at emit time would be wrong, because a Projectile may graze and then leave the bounds in the same pass.
