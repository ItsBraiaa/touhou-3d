# Projectile Field

Feature F5: the Node-free cores that own every Projectile (ADR-0004). Started with ticket F5-01 on 2026-09-23. `ProjectileSpawn` and the spawn, move and cull part of `ProjectileField` are CODE_READY (F5-01), as are the Core sweep and Graze rules (F5-02), the hostile clears and enemy hit spheres (F5-03), and the typed `PatternDefinition` and `PatternEmitter` (F5-04).

## Purpose

`ProjectileField` holds every Projectile of both factions in packed arrays indexed by slot. It spawns them from a `ProjectileSpawn` request with a stable id, moves them each physics tick, and removes them when their lifetime ends, when they meet scenery or a closed Gate (through an injected obstacle query), and when they leave the Flight Volume. It sweeps every hostile Projectile against the player's moving Core and Graze Volume and reports `player_hit` and `grazed`, and every player Projectile against the hit spheres enemies register for the tick, reporting `enemy_hit`. It clears hostile fire, awarding nothing, locally for a Bomb and entirely for Gates, Checkpoints and boss Phases, and lists the targets inside a blast. Its capacity is fixed, and it exposes a per-faction read-out for rendering. `PatternDefinition` and `PatternEmitter` describe reusable ring, fan, spiral, burst and aimed hostile patterns without putting attack sequencing or Anticipation in the core.

It does not own any Node, the physics ray behind the obstacle query, reading the ship's Core and Graze radii or an enemy's `HitVolume`, rendering, or the `_physics_process` that ticks it (all F6-02's `ProjectileSystem`); what a hit or a Graze does to `CombatState`, `RunState` or an enemy (F7, F9); or attack selection and Anticipation (F9-01, F12-01). Acceleration, homing and curved paths are not in PLANEJAMENTO and not supported: a Projectile's velocity is constant.

## Files

- `scripts/combat/projectile_spawn.gd` (value, `class_name ProjectileSpawn extends RefCounted`).
- `scripts/combat/projectile_field.gd` (Rules Core, `class_name ProjectileField extends RefCounted`).
- `scripts/definitions/pattern_definition.gd` (authored Resource, `class_name PatternDefinition`).
- `scripts/combat/pattern_emitter.gd` (Rules Core, `class_name PatternEmitter extends RefCounted`).
- `tests/unit/combat/test_projectile_field.gd` (12 tests for F5-01; F5-02 and F5-03 added none, by the sprint's no-new-tests rule).
- F5-04 adds no test files under the sprint's no-new-tests rule.

## ProjectileSpawn

A plain request. `enum Faction { PLAYER, HOSTILE }`. Fields, in `_init` order with their defaults: `position: Vector3` (`ZERO`), `velocity: Vector3` in units per second (`ZERO`), `faction: Faction` (`HOSTILE`), `lifetime: float` in seconds (`1.0`), `radius: float` in world units (`0.25`), `damage: int` (`CombatState.HIT_DAMAGE`, 10). The field copies the values and never keeps the request, so one request may be changed and reused for a whole volley.

## ProjectileField contract

### Exports

None. A Rules Core has no exports (ADR-0001); capacity and the Flight Volume margin become Inspector values on F6-02's `ProjectileSystem`.

### Signals

All three are emitted after the tick's pass, in ascending slot order (see "Events rule").

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `player_hit` | `projectile_id: int, damage: int` | A HOSTILE Projectile met the Core while the player was not invulnerable, and was removed. `damage` is its `ProjectileSpawn.damage`. At most once per tick. F7-01 calls `CombatState.take_hit(damage)`. |
| `grazed` | `projectile_id: int` | A HOSTILE Projectile passed through the Graze Volume without touching the Core, while the player was not invulnerable, for the first time in its life. F7-01 adds Graze and score. |
| `enemy_hit` | `target_id: int, projectile_id: int, damage: int` | A PLAYER Projectile reached the registered hit sphere `target_id` (the actor's `get_instance_id()`) before any other along its segment, and was removed. The enemy adapter (F9-02, F12-02, F6-03's dummy) applies `damage`. |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `setup(capacity: int, bounds: AABB, obstacle_query: Callable)` | F6-02 at stage load | Sizes the arrays once (capacity 1 to `MAX_CAPACITY`, 65 536), empties the field and resets the refusal counter. `bounds` is the Flight Volume, a position plus a positive size. `obstacle_query` is `func(from: Vector3, to: Vector3) -> bool`, true when scenery or a closed Gate blocks the segment; an invalid `Callable()` means no obstacles. Ids from before a `setup` stay dead. |
| `spawn(request: ProjectileSpawn) -> int` | F6-02 (from F5-04 emitters and F6-03's weapon) | Takes the lowest free slot and returns a new id, or `NO_PROJECTILE` (-1) when full. Asserts lifetime, radius and damage above 0 (`CombatState.take_hit` asserts a positive damage). A request outside the bounds is accepted and culled on its first tick. |
| `tick(delta: float)` | F6-02, every physics tick | One pass in ascending slot order (see "Tick order"), then the tick's events. |
| `set_player(previous_center: Vector3, center: Vector3, core_radius: float, graze_radius: float, invulnerable: bool)` | F6-02, before every tick | The Core's center at the previous tick and now, the Core and Graze radii (`0 < core <= graze`, asserted), and `CombatState.is_invulnerable()`. Holds until called again; `setup` keeps it. |
| `clear_player()` | F6-02 between stages, after the ship is freed | No player: later ticks sweep nothing. A new field starts with no player. |
| `register_target(target_id: int, center: Vector3, radius: float)` | F6-02's `ProjectileSystem.register_target`, for each enemy every physics tick | A hit sphere for the next tick only (radius above 0, asserted). The same id again before that tick replaces the sphere and keeps its registration place. |
| `targets_in_radius(center: Vector3, radius: float) -> PackedInt64Array` | F7-02 (the Bomb) | Ids of the spheres registered for the coming tick with `distance <= radius + target radius`, in registration order. Changes nothing. |
| `clear_hostile_in_radius(center: Vector3, radius: float) -> int` | F7-02 (the Bomb) | Removes every HOSTILE Projectile with `distance <= radius + projectile radius`; returns how many. Awards and emits nothing. |
| `clear_hostile_all() -> int` | F10 (a Gate opens, a Checkpoint activates), F12 (between boss Phases) | Removes every HOSTILE Projectile; returns how many. Awards and emits nothing. |
| `despawn(id: int) -> bool` | anyone holding an id | Removes the Projectile; an unknown, dead or recycled id returns false and changes nothing. |
| `clear_all()` | F6-02, F10 when a stage unloads | Removes every Projectile of both factions, awarding nothing; keeps the id counter and the target registry. |
| `set_bounds(bounds: AABB)` | F6-02 | Replaces the Flight Volume; Projectiles outside it are removed on the next tick. |
| `count(faction) -> int` | HUD debug, tests | Alive Projectiles of one faction. |
| `is_alive(id) -> bool`, `get_position(id) -> Vector3` | anyone holding an id | `get_position` returns `Vector3.ZERO` for a dead id. |
| `get_refused_count() -> int`, `get_capacity() -> int` | F6-02 benchmark, tests | Refusals since the last `setup`; the capacity. |
| `get_positions(faction) -> PackedVector3Array`, `get_radii(faction) -> PackedFloat32Array` | F6-02 renderer | New parallel arrays of that faction's alive Projectiles in ascending slot order. If F6-02's benchmark needs a buffer-shaped read-out, F6-02 adds it. |

### Tick order

For each alive Projectile, in ascending slot order:

1. Its lifetime goes down by `delta`. At 0 or below, it is removed without moving.
2. Otherwise its segment is `from = position` to `to = position + velocity × delta`.
3. When `obstacle_query.call(from, to)` returns true, it is removed at `from`. This comes before any Core or target sweep: a wall between the bullet and the player protects the player. The error is under one tick of travel and never in the bullet's favor.
4. A HOSTILE Projectile is swept against the player (see "Core sweep and Graze"), a PLAYER one against the registered targets (see "Hit spheres").
5. It moves to `to`, and is removed when `to` is outside the bounds.

After the pass the target registry is emptied, then the tick's events are emitted.

### Core sweep and Graze

With a player set, each HOSTILE Projectile's tick segment is taken in the player's frame: from `from - previous_center` to `to - center`. The closest distance `d` from that relative segment to the origin decides contact, so a fast bullet, a fast player, or both at once cannot tunnel through (ENGINEERING_BRIEF 8). PLAYER Projectiles never touch the player.

- **Core contact**, `d <= core_radius + radius`: the Projectile is removed and `player_hit(id, damage)` is queued. It never also grazes: hit before Graze on the same contact.
- **Graze contact**, `d <= graze_radius + radius` without Core contact: if the Projectile's Graze is not spent, it is spent and `grazed(id)` is queued. Each Projectile grazes at most once in its life.
- **Invulnerable** (the `invulnerable` flag of `set_player`): a Core contact reports nothing and the Projectile passes through. Any contact, Core or Graze, spends the Projectile's Graze for good, so it cannot graze after Invulnerability ends either. This is Claude's **strict reading** of PLANEJAMENTO Section 4, "disable new graze awards during invulnerability", chosen so a Bomb or a hit window can never pre-load a Graze. D-07 Part B ruling 5 confirms or changes it (pending when F5-02 landed).
- **The first hit of a tick makes the rest of that tick invulnerable.** The event reaches `CombatState` only after the pass, and an accepted hit starts Invulnerability or defeat there (a Shield hit included). So later Core contacts in the same pass pass through, later contacts are spent, and the tick queues no further Graze. A Graze queued earlier in the same pass, by a lower slot, still stands.
- A Projectile removed by the obstacle query never reaches the sweep: a wall between the bullet and the player protects the player.

The ship's authored spheres set the scale: Core radius 0.18 and Graze radius 0.55 in `player_ship.tscn`. F6-02 reads them from the shapes, so changing a sphere changes contact exactly.

### Hit spheres

- **Registry lifetime.** An enemy registers its sphere every physics tick (CONVENTIONS "Collision": center and radius from its `HitVolume`). A registration is valid for the next `tick` only and is emptied after that tick's pass, so a target that stops registering (defeated, freed) cannot be hit afterwards. A registration made by a listener during emission counts for the following tick. `setup` empties the registry; `clear_all` keeps it.
- **Sweep.** Each PLAYER Projectile's segment `from → to` is tested against every registered sphere, held still for the tick. Contact is `distance <= target radius + projectile radius`. The Projectile hits only the target it reaches first along the segment: the smallest fraction of the segment at entry, 0 when it starts inside a sphere, with a tie going to the earlier registration. It is then removed and `enemy_hit(target_id, projectile_id, damage)` is queued. One Projectile hits at most one target.
- HOSTILE Projectiles never hit targets. The obstacle check comes first, so an Aim Assist shot dies on scenery for its whole travel (ADR-0004).

### Clears

- `clear_hostile_in_radius` (a Bomb) removes HOSTILE Projectiles whose sphere overlaps the blast. PLAYER Projectiles and hostile ones outside the blast stay: a local Bomb does not clear the entire stage (ENGINEERING_BRIEF 8).
- `clear_hostile_all` removes every HOSTILE Projectile: STAGE_DESIGN "Shared encounter rules" (a combat Gate opens, before a Checkpoint activates, between boss Phases).
- Both return the count, emit nothing and award nothing. A cleared Projectile never grazes. Called from a listener, for example the Session reacting to `player_hit`, a hostile clear also takes back the `grazed` that a removed Projectile queued in the current pass, and nothing else.
- Both rebuild the free list once after the removals, so a full clear of thousands of Projectiles costs one pass over the capacity.

### Events rule

`player_hit`, `grazed` and `enemy_hit` follow it. Events decided during the pass are buffered and emitted after it, in ascending slot order. A listener may call `spawn`, `despawn`, `register_target` or a clear; a Projectile spawned then is first moved on the next tick. `clear_all()` from a listener also drops the tick's events not yet emitted (a defeat that unloads the stage). The hostile clears drop only the `grazed` of the Projectiles they remove. Neither a listener nor the obstacle query may call `tick`, and the obstacle query must not call back into the field at all.

### Full-field policy

The capacity is fixed at `setup`. When every slot is alive, `spawn` refuses the new request, returns `NO_PROJECTILE` and adds one to `get_refused_count()`. An existing Projectile is never evicted, because a bullet the player is reading must not vanish. A spawn takes the lowest free slot, so the alive Projectiles stay packed at the start of the arrays and each pass stops at the highest alive slot.

### Id rule

An id is never handed out twice in the field's lifetime: not after its slot is recycled, not after `clear_all`, not after a new `setup`. An id packs the slot in its low 16 bits (`SLOT_BITS`) and a field-wide spawn serial above them, so it is a 64-bit int: keep ids in an `int` or a `PackedInt64Array`, never a `PackedInt32Array`. A dead id's slot may hold a newer Projectile, which the id check tells apart.

## PatternDefinition

`PatternDefinition` is a typed `Resource` (ADR-0003) kept separate from F8-01's content Definitions. Its Inspector values are proposals until Astra authors pattern `.tres` content.

| Export | Default | Meaning |
| --- | --- | --- |
| `id: StringName` | empty | Authored identifier included in validation messages. |
| `shape: Shape` | `RING` | `RING`, `FAN`, `SPIRAL`, `BURST` or `AIMED`. |
| `projectiles_per_volley: int` | 12 | Count before any ring gap is applied. |
| `volley_count: int` | 1 | Number of volleys in an emitter run. |
| `volley_interval: float` | 0.2 s | Delay between volleys. |
| `speed: float` | 8.0 | Projectile speed in units per second. |
| `lifetime: float` | 6.0 s | Projectile lifetime. |
| `projectile_radius: float` | 0.25 | Collision radius in world units. |
| `damage: int` | 10 | Damage carried by each hostile request. |
| `spread_degrees: float` | 60° | FAN/AIMED arc width and full BURST cone width. |
| `gap_degrees: float` | 0° | RING's empty arc centered on its rotated base. |
| `rotation_step_degrees: float` | 0° | World-up rotation per volley after volley zero. |
| `pitch_degrees: float` | 0° | Additional elevation applied to directions. |
| `height_offsets: PackedFloat32Array` | empty | World-up origin offsets cycled by volley; empty means zero. |
| `speed_variance: float` | 0.0 | BURST speed variation fraction, from `1 - variance` to `1 + variance`. |

`validate() -> PackedStringArray` returns a message naming `id` for each invalid value: counts must be at least one; repeated volleys require a positive interval; speed, lifetime and radius must be positive and damage at least one; spread and gap must be in 0..360, with positive BURST spread and at least one surviving RING projectile; speed variance must be in 0..1; SPIRAL requires nonzero rotation.

## PatternEmitter

`setup(definition, rng)` retains the non-null typed Resource and the Attempt's `RandomNumberGenerator`, then resets run state. `start()` restarts with volley zero due immediately. `reset()` clears elapsed time, the volley cursor, accumulated rotation state (derived from the cursor) and sampled aim. `tick(delta, origin, forward, aim_point) -> Array[ProjectileSpawn]` advances elapsed time and emits every due volley in order, including catch-up volleys after a long delta; due-time comparisons use a `1e-6` tolerance. Before start and after the last volley it returns an empty array. `is_finished()` becomes true once every volley has fired.

Every request is `HOSTILE`, uses the definition's speed, lifetime, radius and damage, and starts at `origin + Vector3.UP * height_offsets[k % size]` (or `origin` when empty). The horizontal basis is `forward` flattened onto XZ, falling back to `Vector3.FORWARD` when vertical; volley `k` rotates it around world up by `k * rotation_step_degrees`, and `pitch_degrees` is then applied.

- RING and SPIRAL emit evenly spaced directions around world up. RING omits directions in the gap around the rotated base; SPIRAL has no gap.
- FAN emits evenly spaced directions across `spread_degrees` in the plane of forward and horizontal right, preserving forward pitch. One projectile points along the center direction.
- BURST samples uniformly within its cone from the injected RNG and independently samples speed within the configured variance. It is the only shape that consumes randomness.
- AIMED uses a FAN around `aim_point - origin`, sampled at the first volley and held for the run; it does not track later aim points.

## STAGE_DESIGN pattern mapping

| Source | PatternDefinition / caller |
| --- | --- |
| Spirit aimed bursts; Sentinela phase 1; Fios de Luz burst | AIMED, three volleys at a short interval. |
| Sentry spaced fans; Fios de Luz paired fans | FAN; use two emitters or paired `height_offsets`. |
| Ritual das Lanternas alternating-height rings with a rotating gap | RING with `gap_degrees`, `rotation_step_degrees` and alternating `height_offsets`. |
| Sentinela phase 2 rotating fans; Espiral da Tempestade | FAN or SPIRAL with rotation; boss movement owns height drift. |
| Círculos do Trovão high and low rings | RING with `height_offsets`; the caller owns the ring cue / Anticipation. |

## Dependencies

`ProjectileField.setup` receives the capacity, the Flight Volume and the obstacle query from F6-02's `ProjectileSystem`, which implements the query as a physics-server segment query against collision layer 1 (scenery, Flight Volume walls, closed Gate barriers). `register_target` receives each enemy's hit sphere (its `HitVolume`, layer 5, monitoring off) through `ProjectileSystem`, keyed by the actor's `get_instance_id()`. `ProjectileSpawn` reads `CombatState.HIT_DAMAGE` for its default damage. `PatternEmitter` receives one `PatternDefinition` and the Attempt's seeded `RandomNumberGenerator`; each returned request is passed to `ProjectileField.spawn` by its caller.

## Invariants and tests

| Invariant | Test |
| --- | --- |
| Ids are distinct, and counts are kept per faction; the field copies the request | `test_spawn_returns_distinct_ids_and_counts_by_faction` |
| A Projectile moves by velocity × delta | `test_projectile_moves_by_velocity_times_delta` |
| Frame-rate variation does not change the path (ENGINEERING_BRIEF 4.D) | `test_movement_is_independent_of_the_tick_rate` |
| Removed when its lifetime ends (CONVENTIONS "Collision") | `test_projectile_is_removed_when_its_lifetime_ends` |
| Removed on leaving the Flight Volume; a spawn outside is accepted and culled on its first tick; `set_bounds` applies from the next tick | `test_projectile_leaving_the_bounds_is_removed` |
| Removed on scenery or a closed Gate before it passes, even when one tick would jump the wall (ADR-0004) | `test_projectile_meeting_an_obstacle_is_removed_before_it_passes` |
| The obstacle query receives each tick's segment, in slot order, and never for a Projectile whose lifetime ended | `test_obstacle_query_receives_the_tick_segment` |
| A full field refuses and counts, never evicts | `test_full_field_refuses_new_spawns_and_counts_them` |
| Ids are never reused, across slot recycling and a new `setup` | `test_ids_are_never_reused_after_a_slot_is_recycled` |
| `despawn` of a dead, unknown or expired id is a no-op returning false | `test_despawn_returns_false_for_a_dead_id` |
| `clear_all` empties the field and old ids stay dead (cleanup when encounters end, ENGINEERING_BRIEF 4.D) | `test_clear_all_empties_the_field_and_old_ids_stay_dead` |
| The render read-out lists one faction's alive Projectiles in ascending slot order, radii parallel | `test_render_read_out_lists_alive_projectiles_of_one_faction` |
| A fast Projectile crossing the Core between ticks hits (ENGINEERING_BRIEF 8) | None: the sprint's no-new-tests rule (2026-09-23). Relative-segment closest distance in `_player_contact`; verified by review only. |
| Hit takes precedence over Graze on the same contact (ENGINEERING_BRIEF 8) | None (same rule). A Core contact returns before the Graze branch. |
| Each hostile Projectile grazes at most once (ENGINEERING_BRIEF 8) | None (same rule). The per-slot `_graze_spent` flag, reset only by `spawn`. |
| Invulnerability does not enable Graze farming (ENGINEERING_BRIEF 8) | None (same rule). Any contact while invulnerable spends the Graze; the strict reading above. |
| Cleared Projectiles award no Graze (ENGINEERING_BRIEF 8) | None (same rule). Every clear emits nothing; `clear_all` from a listener drops the pending events, and a hostile clear from a listener marks the removed Projectiles' pending `grazed` as dropped. |
| A local Bomb does not clear the entire stage (ENGINEERING_BRIEF 8) | None (same rule). `clear_hostile_in_radius` tests each HOSTILE Projectile's overlap with the blast. |
| A fast player Projectile does not tunnel through a target; it hits only the first target along its path | None (same rule). Entry fraction along the segment in `_first_target_along`. |
| A registration lasts one tick | None (same rule). The registry is emptied after each pass. |
| Authored patterns reject invalid dimensions and shape-specific constraints | None: no new tests during the sprint. |
| Every due volley is emitted in order; AIMED holds its sampled point and BURST uses only the injected RNG | None: no new tests during the sprint. |
| Every pattern result is a HOSTILE `ProjectileSpawn` with the authored damage, radius, speed and lifetime | None: no new tests during the sprint. |

## Setup for Astra

None: code only. Capacity and the Flight Volume margin become Inspector values on `ProjectileSystem` in F6-02.

## Open issues

- **F5-02's and F5-03's rules have no unit tests.** The sprint's no-new-tests rule (2026-09-23) landed while F5-02 was in progress. The sweeps, the Graze rules, the clears, the registry and the events rule were verified by review only; they first run for real in F6-02, F7-01, F7-02 and F9-02.
- **Targets are static for one tick.** A moving enemy's sphere is tested where it was registered, which is accurate enough at enemy speeds (F5-03 out of scope). A fast boss dash could let a shot pass where the boss was a tick later; a relative sweep like the player's would fix it.
- **Ruling 5 pending.** The strict Invulnerability reading holds until D-07 Part B rules on it. The lenient alternative (a Projectile touched while invulnerable may still graze once afterwards) is a one-line change in `tick`: spend the Graze only when `grazed` is queued.
- **Hot-path cost is unmeasured.** Each tick calls the obstacle query once per moving Projectile, the player sweep once per hostile one, and tests every registered sphere for each player one; `_remove` keeps the free list sorted with a native binary search and insert. F6-02's benchmark measures both at 1000 to 3000 Projectiles.
- The read-out allocates two new arrays per faction per call. F6-02 may add a buffer-shaped read-out if its benchmark asks for one.
