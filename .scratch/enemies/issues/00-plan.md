# F9-00 Plan the Enemies feature

Status: todo
Type: docs
parallel-safe: no
Depends on: F7-03, F8-01

## Goal

Write `.scratch/enemies/spec.md` and the full tickets for F9. Enemies come before the Stage Director so the Director is integrated against real Waves.

## Planned tickets

1. `01-enemy-model-core` (parallel-safe): `EnemyModel`: health, Anticipation timer (1 s default), attack cadence driven by a `PatternDefinition`, aimed attacks sample the player's position at fire time, damage reception, defeat exactly once, out-of-bounds repositioning request, score value; emits `defeated(enemy_id, encounter_id)`.
2. `02-dev-prefabs-and-enemy-actor`: `scenes/dev/spirit.tscn` and `sentry.tscn` following GUIDE Section 5 trees (`Enemy` root, `VisualRoot`, `HitVolume`, `Emitters`, `AnimationPlayer` optional) with primitive meshes; `enemy_actor.gd` adapter: Spirit movement (moving, aimed bursts) and Sentry (floating, spaced fans), hit sphere registration, `targetable` group, Anticipation visual, `threat_reported(direction)` when firing from off-screen; spawn API for the Director (`spawn_at(transform, definition, encounter_id, rng)`).
3. `03-seal-and-guard-rules`: `seal.gd` (Node-free rules inside, adapter around): shielded while any linked Guard lives, exposed Seal becomes a `targetable` stationary target with low health, one-time `seal_destroyed(seal_id)`; portal light state; all six seal orders tested; guard groups activate once on approach or when a guard is shot.

## Read first when planning

- `docs/STAGE_DESIGN.md` "Shared encounter rules", "Three-seal progression challenge"
- `docs/ENGINEERING_BRIEF.md` Section 4.F
- `docs/GUIDE.md` Section 5 "Enemy and boss prefabs", Section 6 rows `enemy_actor.gd`, `seal.gd`, Section 7 rows "Enemy defeated", "Seal destroyed"
- `docs/MODEL_SELECTION.md` (Sentry reuse strategy)
- `docs/HANDOFF_LOG.md` for any enemy prefabs Astra delivered (if present, integrate them instead of dev prefabs)

## Definition of Done

- `spec.md` and three ticket files; roadmap rows replaced; commit `plan: write F9 enemies tickets`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/enemies/issues/00-plan.md, then write the F9 spec and tickets as described. Finish with its Definition of Done and commit.
```
