# F7-00 Plan the Damage, bomb, and pickups feature

Status: done (2026-09-23)
Type: docs
parallel-safe: no
Depends on: F6-03

## Goal

Write `.scratch/damage-pickups/spec.md` and the full tickets for F7. After F7 the test arena has a complete shooting-and-damage loop: the player takes hits, the Shield and Invulnerability behave, Bombs clear, Pickups upgrade Power.

## Planned tickets

1. `01-hit-to-combat-state-and-defeat`: field `player_hit` feeds `CombatState.take_hit`; defeat disables controls and fire, stops Active Time, and emits `player_defeated` to the Session (Defeat screen binding stays in F11); invulnerability flicker on `VisualRoot`; deterministic ordering when several hits land in one tick.
2. `02-bomb-clear-and-invulnerability`: bomb action goes through `WeaponModel` edge detection to `CombatState.use_bomb` and `ProjectileField.clear_hostile_in_radius`; 2 s Invulnerability; radius visual (dev); no graze from cleared Projectiles; cannot activate while paused or defeated; moderate damage to registered enemies in range.
3. `03-pickup-adapter-and-rewards`: `pickup.gd` on a root `Area3D` (dev prefab under `scenes/dev/`), attraction within range, exactly-once acceptance, Power Pickup and Shield Pickup kinds, Shield pickup stays while the player already has a Shield, excess Power gives 50 score, `pickup_accepted` signal for audio.

## Read first when planning

- `docs/PLANEJAMENTO.md` Section 4 entirely
- `docs/ENGINEERING_BRIEF.md` Sections 4.C, 4.E, 8
- `docs/GUIDE.md` Section 6 row `pickup.gd`, Section 7 row "Pickup accepted"
- `docs/HANDOFF_LOG.md` for pickup visuals from Astra

## Definition of Done

- `spec.md` and three ticket files; roadmap rows replaced; commit `plan: write F7 damage and pickups tickets`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/damage-pickups/issues/00-plan.md, then write the F7 spec and tickets as described. Finish with its Definition of Done and commit.
```

## Outcome (2026-09-23)

The tickets were written in the one-pass planning session (commit "plan: write F4-F14 tickets"): `spec.md`, `01-hit-to-combat-state-and-defeat.md`, `02-bomb-clear-and-invulnerability.md`, `03-pickup-adapter-and-rewards.md`. They differ from the planned list above in these ways:

- **The real `CombatState` (F4-01) replaces the planned names.** Tickets use `take_hit() -> HitOutcome`, `update_bomb_input(held)` with `bomb_activated`, `collect_power_pickup()` and `collect_shield_pickup()`, and `score_awarded`. CombatState already grants the 2 s of Bomb Invulnerability.
- **01.** Defeat pauses the tree (`_set_paused(true)`) and pushes Defeat; the plan said only "stops Active Time". There is no `player_defeated` Session signal, because the Session is the listener. Retry = Restart until F10-03.
- **02.** The Bomb edge is fed by F6-03's `PlayerWeapon` (from input events); the Session only reacts to `bomb_activated`. There is no `WeaponModel` edge in the Session and no `ProjectileField` call from the weapon.
- **03.** Acceptance polls the overlap every physics tick, so a Shield Pickup touched while shielded is taken once the Shield breaks. `pickup_accepted` has no audio consumer (F13 is cut).
