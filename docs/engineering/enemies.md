# Enemies

## Purpose

The enemy module separates authored common-Enemy values from the Node-free `EnemyModel` rules core. It owns health, exactly-once defeat, bounded Spirit/Sentry movement, a visible Anticipation cadence and sampled-aim attacks through `PatternEmitter`; the `EnemyActor` adapter, hit sphere, scene presentation, off-screen warning and score application belong to later integration work.

## Files

- `scripts/definitions/enemy_definition.gd` (`EnemyDefinition` Resource)
- `scripts/enemies/enemy_model.gd` (`EnemyModel` Rules Core)
- No F9-01 test files were added under the sprint's no-new-tests rule.

## Public contract

### Exports (Adapter)

No Node adapter is included in F9-01. `EnemyDefinition` exposes these authored Resource fields:

| Export | Type | Default | Meaning |
| --- | --- | --- | --- |
| `kind` | `StringName` | empty | Enemy type identifier; required by validation. |
| `health` | `int` | 100 | Positive health total. |
| `score` | `int` | 100 | Nonnegative score for the Director to award. |
| `anticipation_seconds` | `float` | 1.0 | Visible cue duration before each attack. |
| `pattern` | `PatternDefinition` | null | Valid projectile pattern emitted by this Enemy. |
| `attack_interval` | `float` | 1.0 | Positive cooldown after the pattern ends. |
| `movement` | `Movement` | `DRIFT` | `DRIFT` for Spirit-style lateral motion or `HOVER` for Sentry-style bobbing. |
| `move_speed` | `float` | 1.0 | Nonnegative movement speed in world units per second. |
| `move_range` | `float` | 2.0 | Nonnegative maximum offset from the spawn anchor. |

`validate() -> PackedStringArray` reports one error per invalid condition, each naming `kind`. A pattern must be assigned and its own `validate()` result must be empty. No hit radius is authored here; the scene's `HitVolume` shape supplies it.

### Signals

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `anticipation_started` | none | The first tick begins the initial cue and whenever a cooldown completes. |
| `repositioned` | `position: Vector3` | An out-of-bounds Enemy snaps to its anchor clamped into the current bounds. |
| `defeated` | `enemy_id: StringName`, `encounter_id: StringName` | Health first reaches zero; never emitted twice. |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `setup(definition, enemy_id, encounter_id, rng, spawn_position, bounds)` | Enemy adapter | Validates the definition, clamps the spawn anchor, injects the Attempt RNG and starts in Anticipation without emitting until the first tick. |
| `tick(delta, player_position, emitter_offset = Vector3.ZERO) -> Array[ProjectileSpawn]` | Enemy adapter | Advances bounded movement and the Anticipation → Firing → Cooldown cycle; returns hostile spawns. |
| `set_bounds(bounds)` | Enemy adapter / Director | Replaces movement bounds and repositions immediately if needed. |
| `take_damage(amount)` | Enemy adapter | Reduces health and reports exactly-once defeat. |
| `get_position()`, `get_health()`, `is_defeated()`, `is_anticipating()` | Enemy adapter / Director | Reads current model state. |
| `get_enemy_id()`, `get_encounter_id()`, `get_score()` | Enemy adapter / Director | Reads stable ids and the authored score reward. |

At the end of Anticipation the model samples `player_position` once, starts its PatternEmitter and keeps that point for the whole pattern run. While Firing, the emitter origin follows `get_position() + emitter_offset`; the firing direction aims toward the saved point. The cooldown begins after the last volley and ends before the next Anticipation.

## Dependencies

`EnemyModel` receives a validated `EnemyDefinition`, stable actor and encounter ids, the Attempt's `RandomNumberGenerator`, a spawn position and an `AABB`. The definition references F5-04's `PatternDefinition`; the model drives its `PatternEmitter` and returns `ProjectileSpawn` values for F9-02 to submit to the Projectile Field. The adapter owns Nodes, collision and the hit sphere; the Director owns score awarding.

## Invariants and tests

| Invariant | Test |
| --- | --- |
| Required enemies remain inside reachable bounds; outside positions snap to the anchor and emit `repositioned`. | No new tests during the sprint (SPRINT.md). |
| Anticipation precedes every attack, and the player position is sampled at fire time rather than tracked during the burst. | No new tests during the sprint (SPRINT.md). |
| Damage cannot defeat an Enemy more than once; defeated models emit no more shots. | No new tests during the sprint (SPRINT.md). |
| Movement and burst attacks use the injected Attempt RNG; same-seed runs are deterministic. | No new tests during the sprint (SPRINT.md). |

## Setup for Astra

No scene attachment is required for this core. F9-02's `EnemyActor` should construct the model from its `EnemyDefinition`, pass stable ids, the shared Attempt RNG, the authored spawn position and encounter bounds, then forward model position, hostile spawns and defeat/reposition signals. Keep the `HitVolume` sphere authored in the scene; its radius is not duplicated in the Resource.

## Open issues

The lateral figure-eight for DRIFT and vertical sine bob for HOVER are initial engineering proposals. Tune speed and range against authored Spirit and Sentry movement in the running arena; the model clamps movement to bounds but does not implement steering or collision avoidance.
