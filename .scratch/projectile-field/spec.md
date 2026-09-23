# F5 Projectile Field — spec

Status: ready-for-agent
Owner: Claude
Source: ADR-0004 (one central Projectile Field; scenery and Gates through an injected obstacle query); ENGINEERING_BRIEF Section 4.D, the Section 5 decision "Pattern data versus scripted behavior", and Section 8; PLANEJAMENTO Section 4 ("Graze and score", "Spiritual bomb") and Section 10 ("Patterns share configurable ring, fan, spiral, and burst emitters"); STAGE_DESIGN "Shared encounter rules" and the boss attack descriptions; CONTEXT Combat terms; ADR-0001.

## Goal

Two Node-free Rules Cores, tested headless with fixed deltas and seeds. `ProjectileField` holds every Projectile of both factions in packed arrays. It moves them, removes them on lifetime end, on leaving the Flight Volume and on scenery or a closed Gate (through an injected obstacle query), sweeps hostile Projectiles against the player's moving Core and Graze Volume so a fast bullet cannot tunnel through, awards Graze at most once and never during Invulnerability or from a clear, clears hostile Projectiles locally for a Bomb or entirely for Gates, Checkpoints and boss Phases, and sweeps player Projectiles against the hit spheres enemies register. `PatternEmitter` turns a `PatternDefinition` (ring, fan, spiral, burst, aimed) into timed `ProjectileSpawn` requests with the Attempt's RNG. After F5, F6-02 only has to tick the field from physics, implement the obstacle query with a ray, read the ship's radii and draw it.

## Tickets

1. `01-field-core-spawn-move-cull.md`: `ProjectileSpawn`, and `ProjectileField` spawn, move and cull, stable ids, the full-field policy, the render read-out (parallel-safe)
2. `02-core-hit-sweep-and-graze-rules.md`: swept Core hits, Graze once, hit before Graze, no Graze while invulnerable (parallel-safe; same files as 01 and 03, so it waits for 01)
3. `03-bomb-phase-clears-and-hit-spheres.md`: hostile clears that award nothing, registered target spheres, `enemy_hit`, `targets_in_radius` (parallel-safe; waits for 02)
4. `04-pattern-emitter-core.md`: `PatternDefinition` and `PatternEmitter` (parallel-safe; needs only 01's `ProjectileSpawn`)

Order: 01 first. Then 02 → 03 in one lane and 04 in the other; the lanes share no code file, only `docs/engineering/projectile-field.md`, the roadmap and the handoff log, which are edited one session at a time at session end (CONVENTIONS "Sessions"). Any F5 ticket may run beside another parallel-safe core whose files are disjoint (F8-01, F8-02, F12-01), never beside a non-parallel-safe ticket (CONVENTIONS "Sessions"). F6-01 (rendering spike) needs only 01.

## Cross-feature contracts

Later tickets bind to these names. A session that must change one records it in its ticket Outcome and the module doc.

- `ProjectileSpawn` (`scripts/combat/projectile_spawn.gd`, `class_name ProjectileSpawn extends RefCounted`): `enum Faction { PLAYER, HOSTILE }`; fields `position: Vector3`, `velocity: Vector3`, `faction: Faction`, `lifetime: float`, `radius: float`, `damage: int`; `_init` takes the six in that order with defaults (`HOSTILE`, damage `CombatState.HIT_DAMAGE`).
- `ProjectileField` (`scripts/combat/projectile_field.gd`, `class_name ProjectileField extends RefCounted`):
  - F5-01: `NO_PROJECTILE = -1`; `setup(capacity: int, bounds: AABB, obstacle_query: Callable)` with `obstacle_query = func(from: Vector3, to: Vector3) -> bool`, true = blocked by scenery or a closed Gate; `spawn(request: ProjectileSpawn) -> int` (a unique id never reused, or -1 when full: the new request is refused, never an old Projectile evicted); `tick(delta: float)`; `despawn(id: int) -> bool`; `clear_all()`; `set_bounds(bounds: AABB)`; `count(faction) -> int`; `is_alive(id) -> bool`; `get_position(id) -> Vector3`; `get_refused_count() -> int`; `get_capacity() -> int`; render read-out `get_positions(faction) -> PackedVector3Array` and `get_radii(faction) -> PackedFloat32Array`, parallel, ascending slot order.
  - F5-02: `set_player(previous_center: Vector3, center: Vector3, core_radius: float, graze_radius: float, invulnerable: bool)` before each `tick`; `clear_player()` (no player: no sweep); signals `player_hit(projectile_id: int, damage: int)` and `grazed(projectile_id: int)`.
  - F5-03: `clear_hostile_in_radius(center: Vector3, radius: float) -> int` and `clear_hostile_all() -> int`, both award nothing; `register_target(target_id: int, center: Vector3, radius: float)`, valid for the next `tick` only; `targets_in_radius(center: Vector3, radius: float) -> PackedInt64Array`; signal `enemy_hit(target_id: int, projectile_id: int, damage: int)`.
  - **Events are emitted after the tick's pass, in ascending slot order.** A listener may call `spawn`, `despawn` or any clear from inside one; a Projectile spawned then is first moved on the next tick. `clear_all()` called from a listener also drops the tick's events not yet emitted (a defeat that unloads the stage); the hostile clears do not.
- `PatternDefinition` (`scripts/definitions/pattern_definition.gd`, `class_name PatternDefinition extends Resource`, owned by F5-04, not F8-01): `enum Shape { RING, FAN, SPIRAL, BURST, AIMED }`, the fields listed in ticket 04, `validate() -> PackedStringArray`.
- `PatternEmitter` (`scripts/combat/pattern_emitter.gd`, `class_name PatternEmitter extends RefCounted`): `setup(definition: PatternDefinition, rng: RandomNumberGenerator)`, `start()`, `tick(delta: float, origin: Vector3, forward: Vector3, aim_point: Vector3) -> Array[ProjectileSpawn]`, `is_finished() -> bool`, `reset()`. Every spawn is HOSTILE (player shots come from F6-03's `WeaponModel`). AIMED samples `aim_point` at the run's first volley and holds it. The caller shows the Anticipation before `start()` (F9-01, F12-01).

Consumers: F6-01 (spike, 01 only); F6-02 `ProjectileSystem` wraps the field on `Main/ProjectileRoot`; F7-01 connects `player_hit` and `grazed`; F7-02 uses `clear_hostile_in_radius` and `targets_in_radius`; F9-01 `EnemyModel` and F12-01 `BossMachine` drive `PatternEmitter`s; F10 and F12 use `clear_hostile_all` when a Gate opens, before a Checkpoint activates and between boss Phases (STAGE_DESIGN "Shared encounter rules").

## Done when

- The four tickets are done, with a named test for each ENGINEERING_BRIEF Section 8 invariant F5 owns: a fast Projectile crossing the Core between ticks hits; hit takes precedence over Graze; each hostile Projectile grazes at most once; Invulnerability does not enable Graze farming; cleared Projectiles award no Graze; a local Bomb does not clear the whole stage. Cleanup on lifetime, bounds, obstacles and `clear_all` is tested, and one test shows a single emitter expressing a ring, an aimed burst and a spiral with no duplicated lifecycle code (ENGINEERING_BRIEF Section 5).
- `docs/engineering/projectile-field.md` documents both cores and has its line in `docs/engineering/README.md`.

## Out of scope

Anything with a Node, which is F6-02's: the physics ray, rendering, reading the ship's shapes, and ticking from `_physics_process`. Also out: what a hit, a Graze or an enemy hit does to `CombatState`, `RunState` or an enemy (F7, F9); Attack sequencing, boss movement and height drift (F12-01); per-Projectile homing or curved paths, which the design does not have; authored pattern `.tres` content (F9-02, F12-03); profiling representative boss patterns (F6-01 measures raw density; the boss profile belongs to F12-03 and the F14-02 acceptance record).
