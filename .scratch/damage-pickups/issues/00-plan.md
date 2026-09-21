# F7-00 Plan the Damage, bomb, and pickups feature

Status: todo
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
