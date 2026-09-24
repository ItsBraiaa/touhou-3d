# F9 Enemies — spec

Status: ready-for-agent
Owner: Claude
Source: STAGE_DESIGN.md "Shared encounter rules", "Three-seal progression challenge"; ENGINEERING_BRIEF Section 4.F; GUIDE.md Section 5 "Enemy and boss prefabs", Section 7 ("Enemy defeated", "Seal destroyed"); ENEMY_VISUAL_HANDOFF.md; MODEL_SELECTION.md; ADR-0001, ADR-0004.

## Goal

The two common Enemy Types fight in a real scene before the Stage Director is integrated. A **Spirit** moves and fires aimed bursts; a **Sentry** floats and fires spaced fans. Each appears with a visible 1 s Anticipation before it shoots, aimed fire samples the player's position at fire time, damage comes through the Projectile Field's hit spheres, each enemy reports its defeat exactly once with stable ids, stays inside reachable bounds, and warns when it fires from off-screen. Seals (Stage 2) get their Node-free rules and adapter. F12-05 (Stage 2 S2-03) consumes them and runs the any-order objective in the real scene.

## Tickets

1. `01-enemy-model-core.md` (parallel-safe): `EnemyDefinition` and the `EnemyModel` Rules Core.
2. `02-dev-prefabs-and-enemy-actor.md`: the `EnemyActor` adapter and the dev `spirit.tscn` and `sentry.tscn` prefabs (Astra's visuals as `VisualRoot`), with dev content.
3. `03-seal-and-guard-rules.md`: `SealRules` and the `Seal` adapter (lane glm-a). Consumed by F12-05 (Stage 2 S2-03).

01 can run in parallel with F8 and F12-01 once F5-04 is done.

## Cross-feature contracts

- `EnemyDefinition` (`scripts/definitions/enemy_definition.gd`): `kind`, `health`, `score` (100, PLANEJAMENTO Section 4), `anticipation_seconds` (1.0), `pattern: PatternDefinition`, `attack_interval`, `movement: Movement { DRIFT, HOVER }`, `move_speed`, `move_range`. There is no `hit_radius`: the radius is the `HitVolume` sphere (CONVENTIONS "Collision").
- `EnemyModel` (`scripts/enemies/enemy_model.gd`): `setup(definition, enemy_id, encounter_id, rng, spawn_position, bounds)`, `tick(delta, player_position, emitter_offset := Vector3.ZERO) -> Array[ProjectileSpawn]`, `get_position()`, `take_damage(amount)`, `is_defeated()`, `set_bounds(bounds)`. Signals: `anticipation_started()`, `repositioned(position)`, `defeated(enemy_id, encounter_id)` once.
- `EnemyActor` (`scripts/enemies/enemy_actor.gd`, the root of `scenes/dev/spirit.tscn` and `sentry.tscn`): `spawn_setup(definition: EnemyDefinition, enemy_id: StringName, encounter_id: StringName, rng: RandomNumberGenerator, projectile_system: ProjectileSystem, player: Node3D, bounds: AABB)`, called by the Director after `add_child` under `RuntimeActors` at the marker's transform. It joins `targetable`, registers its hit sphere every physics tick at priority ≤ 0 (the ProjectileSystem runs at 10), and emits `defeated(enemy_id, encounter_id)` and `threat_reported(side)` (-1 left, +1 right). It frees itself on defeat. The Director awards `definition.score`.
- Dev content: `content/enemies/spirit.tres`, `content/enemies/sentry.tres`, `content/patterns/spirit_aimed_burst.tres`, `content/patterns/sentry_fan.tres`, all `metadata/dev = true`.
- `SealRules` (`scripts/progression/seal_rules.gd`) and `Seal` (`scripts/progression/seal.gd`): `seal_destroyed(seal_id)` once, which becomes `EncounterMachine.notify_objective(seal_id)` in F12-05. Stage 1's S1-04 portal guards are **not** Seals: they are an ALL_REQUIRED_ENEMIES Encounter whose `Environment/PortalLinks/GuardLink1..3` the Director hides (F10-02).

## Done when

- All F9 tests pass; a Spirit and a Sentry spawned in the dev arena appear, wait 1 s, fire their patterns, take damage from player shots and disappear on defeat, reporting once.
- GUIDE Section 6 rows `enemy_actor.gd` and `seal.gd` are complete; Section 10 "Common enemies and miniboss" is CODE_READY for common enemies; `docs/engineering/enemies.md` documents everything above.

## Out of scope

Bosses and the Tempest Sentinel (F12); spawning from Encounters (F10-01); per-wave visual variants (lume or twilight per wave: presentation, cut first by PLANEJAMENTO Section 11); Death and HitReact clip playback; Stage 2 seal integration, Guard passivity, portal lights and per-seal rewards (F12-05).
