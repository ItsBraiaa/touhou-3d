# F9-01 EnemyModel core

Status: todo
Type: core
parallel-safe: yes
Depends on: F5-04

## Goal

A Node-free `EnemyModel` that holds one common enemy's rules: health and defeat exactly once with stable ids, the visible 1 s Anticipation before every attack, an attack cadence driven by a `PatternDefinition` through `PatternEmitter`, aimed attacks that sample the player's position at fire time rather than tracking, bounded movement for the Spirit (drift) and the Sentry (hover), and repositioning when it finds itself outside its bounds, so a required enemy never softlocks an Encounter. The adapter (F9-02) only copies the position, forwards spawns and reports damage.

## Read first

- `docs/STAGE_DESIGN.md` "Shared encounter rules" (Spirit and Sentry, 1 s Anticipation, sampled aim, reachable bounds and repositioning)
- `docs/ENGINEERING_BRIEF.md` Section 4.F; `docs/PLANEJAMENTO.md` Section 4 "Graze and score" (100 per common enemy)
- `.scratch/projectile-field/issues/04-pattern-emitter-core.md` and its **Outcome**: `PatternDefinition`'s final fields and `PatternEmitter.setup(definition, rng)`, `start()`, `tick(delta, origin, forward, aim_point) -> Array[ProjectileSpawn]`, `is_finished()`, `reset()`. Use what the Outcome says if it differs from this list.
- `docs/engineering/CONVENTIONS.md` "Time and randomness" (one RNG per Attempt, injected), "Architecture rules"
- `CONTEXT.md` "Enemies", "Anticipation", "Pattern", "Emitter"

## Files

- **Creates:** `scripts/definitions/enemy_definition.gd`, `scripts/enemies/enemy_model.gd`, `tests/unit/definitions/test_enemy_definition.gd`, `tests/unit/enemies/test_enemy_model.gd`, `docs/engineering/enemies.md`.
- **Edits:** none.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F9-01 row), `docs/HANDOFF_LOG.md`, `docs/engineering/enemies.md` (new) and its line in `docs/engineering/README.md`.
- **Must not touch:** `scripts/combat/pattern_emitter.gd`, `scripts/definitions/pattern_definition.gd`, `scripts/combat/projectile_spawn.gd` (F5; a gap is a dependency note), `scripts/enemies/boss_machine.gd` (F12-01), `content/` (F9-02).
- **Conflicts with:** none. F12-01 may run alongside it; it creates other files in `scripts/enemies/` and `tests/unit/enemies/`.

## Deliverables

- `EnemyDefinition extends Resource`: `kind: StringName`, `health: int`, `score: int` (100), `anticipation_seconds: float` (1.0), `pattern: PatternDefinition`, `attack_interval: float` (seconds from the end of one attack to the next Anticipation), `enum Movement { DRIFT, HOVER }`, `movement`, `move_speed: float`, `move_range: float` (the furthest it moves from its spawn anchor). `validate()` requires a non-empty kind, `health > 0`, `score >= 0`, `anticipation_seconds >= 0`, a non-null pattern with an empty `validate()`, `attack_interval > 0`, and `move_speed` and `move_range` ≥ 0. No hit radius: the `HitVolume` sphere is the source (CONVENTIONS "Collision", ENEMY_VISUAL_HANDOFF "retain the gameplay type's radius").
- `EnemyModel extends RefCounted`:
  - `setup(definition, enemy_id: StringName, encounter_id: StringName, rng: RandomNumberGenerator, spawn_position: Vector3, bounds: AABB)`: asserts the definition is valid; the anchor is the spawn position clamped into `bounds`. It starts in Anticipation at time 0 and emits `anticipation_started()` on the first `tick`.
  - `tick(delta, player_position: Vector3, emitter_offset: Vector3 = Vector3.ZERO) -> Array[ProjectileSpawn]`: advances movement, then the attack cycle **Anticipation (anticipation_seconds) → Firing → Cooldown (attack_interval) → Anticipation**. When an Anticipation ends it samples `player_position` once as the aim point and starts the emitter; while Firing it passes that same sampled point, with `origin = get_position() + emitter_offset` and `forward` toward it, until `is_finished()`. So a burst never tracks the player after its cue. Returns the emitter's spawns (HOSTILE); empty while not Firing or once defeated.
  - Movement: DRIFT follows a deterministic path around the anchor within `move_range` at `move_speed` (Claude's proposal: a lateral figure-eight whose phase comes from the injected RNG); HOVER is a slow vertical bob within `move_range`. The position is always clamped into `bounds`.
  - `set_bounds(bounds)`, and any tick that finds the position outside the bounds: snap to the anchor clamped into the new bounds and emit `repositioned(position)` once per event (STAGE_DESIGN "repositioned to a valid spawn location, not left blocking completion forever").
  - `take_damage(amount: int)`: asserts `amount > 0`; ignored once defeated. At 0 health or below: defeated, the emitter stops, and `defeated(enemy_id, encounter_id)` fires exactly once however many hits land in the tick.
  - Getters: `get_position()`, `get_health()`, `is_defeated()`, `is_anticipating()`, `get_enemy_id()`, `get_encounter_id()`, `get_score()`.

## Tests required

`tests/unit/definitions/test_enemy_definition.gd`: `test_valid_definition_has_no_errors`, `test_definition_rejects_missing_pattern_and_bad_numbers`.

`tests/unit/enemies/test_enemy_model.gd`, with a fixed-seed RNG and a code-built PatternDefinition:

- `test_first_attack_waits_for_the_anticipation` (no spawns before 1.0 s; `anticipation_started` once at spawn)
- `test_aimed_attack_samples_the_player_position_at_fire_time` (move the player during the burst; every spawn aims at the sampled point)
- `test_attack_cycle_repeats_after_the_interval` (a second `anticipation_started` and a second burst)
- `test_damage_reduces_health_and_defeat_fires_once` (overkill and repeated hits give one signal with both ids)
- `test_defeated_enemy_fires_nothing_and_ignores_damage`
- `test_movement_stays_inside_bounds` (DRIFT and HOVER over 60 s)
- `test_enemy_outside_bounds_is_repositioned_once`
- `test_same_seed_gives_the_same_attacks`

## Out of scope

Node, scene, collision and the hit sphere (F9-02); the off-screen warning (F9-02, which needs the camera); score awarding (the Director, F10-01); the boss Phase logic (F12-01); Anticipation visuals and animation clips.

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR` in the output. Named tests cover ENGINEERING_BRIEF 4.F "enemies needed for progression remain reachable" (repositioning) and the STAGE_DESIGN Anticipation and sampled-aim rules.
- No Error-level warnings. `docs/engineering/enemies.md` written from `TEMPLATE.md` with its README line.
- Handoff log entry; `Status: done` with an Outcome; ROADMAP row.
- One commit: `enemies: add EnemyModel core`.

## Handoff notes for Astra

Health, cadence and movement values arrive as dev `.tres` in F9-02 for you to tune. Both visual variants of a type share one Definition (ENEMY_VISUAL_HANDOFF). Nothing to wire here.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/enemies/issues/01-enemy-model-core.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
