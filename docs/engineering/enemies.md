# Enemies

## Purpose

The enemy module separates authored common-Enemy values from the Node-free `EnemyModel` rules core. It owns health, exactly-once defeat, bounded Spirit/Sentry movement, a visible Anticipation cadence and sampled-aim attacks through `PatternEmitter`. Since F9-02 the `EnemyActor` adapter puts a model in the world: position, hostile spawns to the `ProjectileSystem`, the registered hit sphere, `targetable`, the off-screen warning and the one defeat report. Since F15-02 it also plays the visual's Anticipation clip, flashes on each hit, turns toward the player and plays `Death` before freeing itself. Spawning from Encounters and score application are the Director's (F10-01).

## Files

- `scripts/definitions/enemy_definition.gd` (`EnemyDefinition` Resource)
- `scripts/enemies/enemy_model.gd` (`EnemyModel` Rules Core)
- No F9-01 test files were added under the sprint's no-new-tests rule.
- `scripts/enemies/enemy_actor.gd` (`EnemyActor` Adapter, F9-02), on the `Enemy` root of a common-Enemy prefab.
- `scenes/dev/spirit.tscn`, `scenes/dev/sentry.tscn` (dev prefabs with Astra's `spirit_lume` and `sentry_lantern` visuals).
- `content/enemies/spirit.tres`, `content/enemies/sentry.tres`, `content/patterns/spirit_aimed_burst.tres`, `content/patterns/sentry_fan.tres` (dev values, `metadata/dev = true`).
- No F9-02 test file (sprint rule); the scripted runs are in [validation/enemies.md](../validation/enemies.md).

## Public contract

### Exports (Adapter)

The Node adapter is `EnemyActor` (F9-02, "EnemyActor contract" below). `EnemyDefinition` exposes these authored Resource fields:

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

## EnemyActor contract (F9-02)

`scripts/enemies/enemy_actor.gd` (Adapter, `class_name EnemyActor extends Node3D`), on the `Enemy` root of `scenes/dev/spirit.tscn` and `sentry.tscn` and of Astra's final `scenes/enemies/spirit.tscn` and `sentry.tscn`.

### Exports

| Export | Type | Required | Meaning |
| --- | --- | --- | --- |
| `visual_root` | `Node3D` | yes | `VisualRoot`, Astra's visual scene instance. Since F15-02 the actor turns it (yaw only) toward the player, plays clips on its `Model/AnimationPlayer` and flashes its meshes; see "Presentation" below. |
| `hit_volume` | `Area3D` | yes | `HitVolume`: layer 5 (bit 16), mask 0, monitoring and monitorable off. Its **node position is the hit center** (what `Targeting`, the HUD marker, Aim Assist and the registered sphere use), and the radius of the `SphereShape3D` in its first `CollisionShape3D` child is the hit radius. Node scale is ignored. |
| `emitter` | `Marker3D` | yes | `Emitters/Main`, where the pattern leaves from. |

`_ready` reports each missing reference, and a first `CollisionShape3D` without a positive-radius `SphereShape3D`, with `push_error` naming the node path, and disables the node. Physics processing is off until `spawn_setup`.

### Signals

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `threat_reported` | `side: int` | An Anticipation starts while the actor's origin is outside the current camera's frustum: -1 when it is left of the camera (against the camera's local +X), +1 otherwise. Since F15-02 at most once per Enemy, so a threat is warned when it is new, not on every attack (Astra's coalescing rule, `sound_effects/README.md`). The owner forwards it to `Hud.show_threat(side, seconds)`. |
| `defeated` | `enemy_id: StringName`, `encounter_id: StringName` | The model's health first reaches 0. Emitted once and at once, on the lethal hit, after the actor left `targetable` and stopped physics (so it registers no hit sphere from the next tick). Since F15-02 the `Death` clip then plays and the actor frees itself when it ends (0.667 s); without the clip it frees at once. |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `spawn_setup(definition: EnemyDefinition, enemy_id: StringName, encounter_id: StringName, rng: RandomNumberGenerator, projectile_system: ProjectileSystem, player: Node3D, bounds: AABB) -> bool` | The Director (F10-01), the arena harness | Call once, after `add_child` under `RuntimeActors` and with the actor at its spawn marker's global transform. Returns true when the Enemy started. Returns false and refuses with one `push_error` per problem (the actor stays inert, out of `targetable`, registering nothing, and the caller frees it): an actor outside the tree (one error, naming the node), a scene that failed its own check, a second call, a null or invalid definition (its `validate()` messages), an empty id, a null `rng` or `projectile_system`, a player null or outside the tree, bounds with no volume. Otherwise builds the `EnemyModel` from `global_position` (clamped into `bounds`), connects `anticipation_started` and `defeated` once, joins `targetable` and starts physics. |
| `take_damage(damage: int)` | The `ProjectileSystem`, as the registered `on_damage` (player shots, and the Bomb through `damage_targets_in_radius`) | Forwards to the model and flashes the visual. Ignored before `spawn_setup`, after defeat (the model's exactly-once rule), while the tree is paused, and for `damage <= 0`. |
| `get_health() -> int` | The harness readout, the Director | Remaining health, 0 before `spawn_setup`. |
| `static threat_side(camera_transform: Transform3D, point: Vector3) -> int` | `_on_anticipation_started`, dev tools | -1 when `point` is left of the camera and +1 otherwise, straight ahead and behind included. |

### Each physics tick (after `spawn_setup`)

Priority 0 (the default), so before `PlayerWeapon` (50) and the `ProjectileSystem` (100):

1. The player's `global_position` is read while the player is valid and in the tree; otherwise the last one is kept (the Session takes the ship out of the tree before freeing it).
2. `model.tick(delta, player_position, emitter.global_position - global_position)`.
3. `global_position = model.get_position()`.
4. `projectile_system.spawn()` for every returned hostile `ProjectileSpawn`.
5. `VisualRoot` turns toward the player (below).
6. `projectile_system.register_target(get_instance_id(), hit_volume.global_position, radius, take_damage)`: the sphere lasts one tick, so a defeated actor, which stops physics, drops out on the next.

### Presentation (F15-02)

`_ready` finds the visual's player at `VisualRoot/Model/AnimationPlayer` (ENEMY_VISUAL_HANDOFF) and checks three clips: its `autoplay` (`Flying_Idle`, the idle), the clip named by `VisualRoot`'s `metadata/anticipation_clip` (D-05: `Yes` for Spirits, `Punch` for Sentries) and `Death`. A missing player or a named clip it lacks is warned once with `push_warning` and that cue is skipped; an empty metadata value means no Anticipation clip.

- **Anticipation.** On every `anticipation_started` the Anticipation clip plays once at `clip length / anticipation_seconds` speed, so it spans exactly the Anticipation (1.167 s over 1.0 s, speed 1.167), then the idle is queued at normal speed. It replaced F9-02's dev scale pulse.
- **Hit flash.** Each accepted hit sets an additive, unshaded, fog-free overlay on every `MeshInstance3D` under `VisualRoot` and fades it from `HIT_FLASH_COLOR` (0.85 grey) to black over `HIT_FLASH_SECONDS` (0.12 s), then removes it, so an Enemy nobody is shooting draws no extra pass. Each actor builds its own material, so one Enemy's flash never lights another with the same visual. Held fire restarts the fade on every hit. `HitReact` is not played: it would restart on every shot.
- **Facing.** Every tick `VisualRoot`'s local yaw eases toward the player about the actor's up axis, `1 - exp(-TURN_RATE * delta)` of the remaining angle with `TURN_RATE` 6 per second; `spawn_setup` snaps it. The visuals face their local +Z. Pitch and roll are never touched. A dying actor stops turning.
- **Defeat.** `defeated` is emitted on the lethal hit, as before, so the Director scores and the Encounter advances at once. Then `Death` plays and a Tween of the actor frees it when the clip ends; the Tween stops while the tree is paused. A Retry removes every child of `RuntimeActors` and frees it, dying actors included, and their Tweens go with them. Checked headless: `retry_from_checkpoint` called while three enemies were mid-Death removed all three at once and freed them two frames later. Since F15-10's 1 s defeat beat, a 0.667 s Death has already ended when the Defeat overlay opens.

All Tweens are the actor's own, so they stop while the tree is paused. Score is not the actor's: the Director reads `definition.score` when it receives `defeated`.

## Dependencies

`EnemyModel` receives a validated `EnemyDefinition`, stable actor and encounter ids, the Attempt's `RandomNumberGenerator`, a spawn position and an `AABB`. The definition references F5-04's `PatternDefinition`; the model drives its `PatternEmitter` and returns `ProjectileSpawn` values. `EnemyActor` submits them to the `ProjectileSystem` (F6-02), registers its sphere there, and is found by `Targeting` (F1-04) through `targetable` and its `HitVolume`. The Director owns spawning, the Attempt RNG, the encounter bounds and score awarding.

## Invariants and tests

| Invariant | Test |
| --- | --- |
| Required enemies remain inside reachable bounds; outside positions snap to the anchor and emit `repositioned`. | No new tests during the sprint (SPRINT.md). |
| Anticipation precedes every attack, and the player position is sampled at fire time rather than tracked during the burst. | No new tests during the sprint (SPRINT.md). |
| Damage cannot defeat an Enemy more than once; defeated models emit no more shots. | No new tests during the sprint (SPRINT.md). |
| Movement and burst attacks use the injected Attempt RNG; same-seed runs are deterministic. | No new tests during the sprint (SPRINT.md). |
| An actor is inert until `spawn_setup`: not in `targetable`, registering nothing | Scripted run, [validation/enemies.md](../validation/enemies.md) |
| One `defeated` per Enemy, with both ids, even under repeated damage in one tick; the actor leaves `targetable` and frees itself | Scripted run |
| No hostile shot before the first Anticipation ends | Scripted run: 0 at 0.93 s, 10 at 1.1 s |
| An attack that starts off-screen reports its side | Scripted run, camera turned 180° |

## Setup for Astra

Your final `scenes/enemies/spirit.tscn` and `sentry.tscn` can copy the dev tree one to one:

- `Enemy` (`Node3D`, `scripts/enemies/enemy_actor.gd`, `visual_root` → `VisualRoot`, `hit_volume` → `HitVolume`, `emitter` → `Emitters/Main`). No group: the actor joins `targetable` itself when spawned.
- `VisualRoot`: your visual scene instance (`spirit_lume.tscn`, `sentry_lantern.tscn` or a variant). Its origin is the body's center in the current visuals.
- `HitVolume` (`Area3D`, layer 16, mask 0, monitoring and monitorable off) with a `CollisionShape3D` holding a `SphereShape3D`. Keep it outside the scaled `Model` and **move the `HitVolume` node itself** to re-center it (the child shape stays at its origin): the node's position is what Target Lock, the HUD marker and Aim Assist aim at. Claude's proposals: Spirit radius 1.0, Sentry 0.9, both at the root origin, where the current visuals are centered.
- `Emitters/Main` (`Marker3D`), where shots leave; at the hit center for now.
- No `AnimationPlayer` of the prefab's own: the visual's `Model/AnimationPlayer` autoplays `Flying_Idle`.

Tune the values in `content/enemies/*.tres` and `content/patterns/*.tres` and drop `metadata/dev` when reviewed (D-05). The health proposals follow F6-03's recorded fire: 1 damage every 0.1 s at Power Level 1, so 20 is about 2 s for a Spirit and 30 about 3 s for a Sentry (measured: a locked Spirit at 30 units falls in 2.35 s). The Anticipation gesture is your `metadata/anticipation_clip` on the visual's `VisualRoot` (D-05); change it there. The hit-flash colour and length and the turn rate are Claude's proposals (constants in `enemy_actor.gd`); send Claude new values to change them.

## Open issues

## SealRules core (F9-03, part 1)

`SealRules` is the Node-free Stage 2 progression core in
`scripts/progression/seal_rules.gd`. A Seal starts `DORMANT` and activates its
linked Guard group exactly once on approach, or when a linked Guard is shot.
Each linked Guard defeat is counted once; after the final Guard, the Seal enters
`EXPOSED`, drops its shield and accepts damage. Damage before exposure is
ignored, including Bomb damage. Reaching zero enters `DESTROYED` exactly once.

The core emits `guards_activated`, `guard_link_cleared`, `shield_dropped` and
`destroyed`. `capture()` and `restore()` contain only the state, defeated Guard
ids and remaining health; restore emits no signals. The `Seal` Node adapter and
scene wiring are F9-03 part 2 / F12-05.

### Seal adapter (F9-03, part 2)

`Seal` on each `Encounters/S2-03/Seals/SealN` root resolves Guard ids from
`guard_spawn` metadata through `EncounterMachine.enemy_id`. It enables the
approach Area3D once setup is complete, forwards Director Guard reports to the
core, hides defeated Guard links and the shield, and joins `targetable` only
while exposed. Its hit sphere is registered with `ProjectileSystem` every
physics tick while exposed. Destruction leaves the target group, stops
registration, hides the dev core visual, and emits `seal_destroyed` once.

- The lateral figure-eight for DRIFT and vertical sine bob for HOVER are initial engineering proposals. Tune speed and range against authored Spirit and Sentry movement in the running arena; the model clamps movement to bounds but does not implement steering or collision avoidance.
- **Locked shots miss close enemies (for trunk, F6-03).** From 10 to 16 units, once `CameraRig`'s lock framing blends in, the weapon's shots pass about 3.5 units from a Spirit's center, just outside the 10° main Aim Assist cone; from about 30 units they hit steadily. See [validation/enemies.md](../validation/enemies.md) "Finding for another lane".
- Facing, the hit flash and Death playback were added in F15-02 ("Presentation"). `HitReact` stays unused.
- The off-screen test uses the actor's origin and the frustum only: an enemy hidden behind scenery but inside the frustum reports nothing, and vertical warnings are out of scope (GUIDE Section 15).

## Dormant Guards (F12-05)

`EnemyActor.set_engaged(engaged: bool)` pauses only model ticking: a dormant Guard stays targetable, registers its hit sphere and accepts damage. The Director calls it immediately after spawn_setup, before the first physics tick; engagement begins its first Anticipation. `damaged(enemy_id: StringName)` is emitted for each accepted positive hit before applying it, including lethal hits, and never after defeat. The Seal's notify_guard_shot receives this signal, engaging the linked pair before defeat is reported. Ordinary enemies remain engaged by default. Gate optionally resolves an OpenVisual child and toggles it with its open state.
