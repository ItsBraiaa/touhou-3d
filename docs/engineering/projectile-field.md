# Projectile Field

Feature F5: the Node-free cores that own every Projectile (ADR-0004). Started with ticket F5-01 on 2026-09-23. `ProjectileSpawn` and the spawn, move and cull part of `ProjectileField` are CODE_READY. The Core sweep and Graze (F5-02), the hostile clears and enemy hit spheres (F5-03) and the `PatternEmitter` (F5-04) are not built yet.

## Purpose

`ProjectileField` holds every Projectile of both factions in packed arrays indexed by slot. It spawns them from a `ProjectileSpawn` request with a stable id, moves them each physics tick, and removes them when their lifetime ends, when they meet scenery or a closed Gate (through an injected obstacle query), and when they leave the Flight Volume. Its capacity is fixed, and it exposes a per-faction read-out for rendering.

It does not own any Node, the physics ray behind the obstacle query, rendering, or the `_physics_process` that ticks it (all F6-02's `ProjectileSystem`); what a hit or a Graze does to `CombatState` or an enemy (F7, F9); patterns (F5-04). Acceleration, homing and curved paths are not in PLANEJAMENTO and not supported: a Projectile's velocity is constant.

## Files

- `scripts/combat/projectile_spawn.gd` (value, `class_name ProjectileSpawn extends RefCounted`).
- `scripts/combat/projectile_field.gd` (Rules Core, `class_name ProjectileField extends RefCounted`).
- `tests/unit/combat/test_projectile_field.gd` (12 tests for F5-01).

## ProjectileSpawn

A plain request. `enum Faction { PLAYER, HOSTILE }`. Fields, in `_init` order with their defaults: `position: Vector3` (`ZERO`), `velocity: Vector3` in units per second (`ZERO`), `faction: Faction` (`HOSTILE`), `lifetime: float` in seconds (`1.0`), `radius: float` in world units (`0.25`), `damage: int` (`CombatState.HIT_DAMAGE`, 10). The field copies the values and never keeps the request, so one request may be changed and reused for a whole volley.

## ProjectileField contract

### Exports and signals

None yet. A Rules Core has no exports (ADR-0001); capacity and the Flight Volume margin become Inspector values on F6-02's `ProjectileSystem`. F5-02 adds `player_hit` and `grazed`, F5-03 adds `enemy_hit`.

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `setup(capacity: int, bounds: AABB, obstacle_query: Callable)` | F6-02 at stage load | Sizes the arrays once (capacity 1 to `MAX_CAPACITY`, 65 536), empties the field and resets the refusal counter. `bounds` is the Flight Volume, a position plus a positive size. `obstacle_query` is `func(from: Vector3, to: Vector3) -> bool`, true when scenery or a closed Gate blocks the segment; an invalid `Callable()` means no obstacles. Ids from before a `setup` stay dead. |
| `spawn(request: ProjectileSpawn) -> int` | F6-02 (from F5-04 emitters and F6-03's weapon) | Takes the lowest free slot and returns a new id, or `NO_PROJECTILE` (-1) when full. Asserts lifetime and radius above 0. A request outside the bounds is accepted and culled on its first tick. |
| `tick(delta: float)` | F6-02, every physics tick | One pass in ascending slot order; see "Tick order". |
| `despawn(id: int) -> bool` | anyone holding an id | Removes the Projectile; an unknown, dead or recycled id returns false and changes nothing. |
| `clear_all()` | F6-02, F10 when a stage unloads | Removes every Projectile of both factions, awarding nothing; keeps the id counter. |
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
4. F5-02 inserts the Core sweep here, and F5-03 the target sweep.
5. It moves to `to`, and is removed when `to` is outside the bounds.

### Events rule

No signal exists yet; F5-02 and F5-03 must follow this rule when they add theirs. Events decided during the pass are buffered and emitted after it, in ascending slot order. A listener may call `spawn`, `despawn` or a clear; a Projectile spawned then is first moved on the next tick. `clear_all()` from a listener also drops the tick's events not yet emitted (a defeat that unloads the stage); the hostile clears of F5-03 do not. The obstacle query itself must not call back into the field.

### Full-field policy

The capacity is fixed at `setup`. When every slot is alive, `spawn` refuses the new request, returns `NO_PROJECTILE` and adds one to `get_refused_count()`. An existing Projectile is never evicted, because a bullet the player is reading must not vanish. A spawn takes the lowest free slot, so the alive Projectiles stay packed at the start of the arrays and each pass stops at the highest alive slot.

### Id rule

An id is never handed out twice in the field's lifetime: not after its slot is recycled, not after `clear_all`, not after a new `setup`. An id packs the slot in its low 16 bits (`SLOT_BITS`) and a field-wide spawn serial above them, so it is a 64-bit int: keep ids in an `int` or a `PackedInt64Array`, never a `PackedInt32Array`. A dead id's slot may hold a newer Projectile, which the id check tells apart.

## Dependencies

`setup` receives the capacity, the Flight Volume and the obstacle query from F6-02's `ProjectileSystem`, which implements the query as a physics-server segment query against collision layer 1 (scenery, Flight Volume walls, closed Gate barriers). `ProjectileSpawn` reads `CombatState.HIT_DAMAGE` for its default damage.

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

## Setup for Astra

None: code only. Capacity and the Flight Volume margin become Inspector values on `ProjectileSystem` in F6-02.

## Open issues

- **Hot-path cost is unmeasured.** Each tick calls the obstacle query once per moving Projectile; `_remove` keeps the free list sorted with a native binary search and insert. F6-02's benchmark measures both at 1000 to 3000 Projectiles.
- The read-out allocates two new arrays per faction per call. F6-02 may add a buffer-shaped read-out if its benchmark asks for one.
