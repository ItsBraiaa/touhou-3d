# Projectile Field

Feature F5: the Node-free cores that own every Projectile (ADR-0004). Started with ticket F5-01 on 2026-09-23. `ProjectileSpawn` and the spawn, move and cull part of `ProjectileField` are CODE_READY (F5-01), and so are the Core sweep and Graze rules (F5-02). The hostile clears and enemy hit spheres (F5-03) and the `PatternEmitter` (F5-04) are not built yet.

## Purpose

`ProjectileField` holds every Projectile of both factions in packed arrays indexed by slot. It spawns them from a `ProjectileSpawn` request with a stable id, moves them each physics tick, and removes them when their lifetime ends, when they meet scenery or a closed Gate (through an injected obstacle query), and when they leave the Flight Volume. It sweeps every hostile Projectile against the player's moving Core and Graze Volume and reports `player_hit` and `grazed`. Its capacity is fixed, and it exposes a per-faction read-out for rendering.

It does not own any Node, the physics ray behind the obstacle query, reading the ship's Core and Graze radii, rendering, or the `_physics_process` that ticks it (all F6-02's `ProjectileSystem`); what a hit or a Graze does to `CombatState`, `RunState` or an enemy (F7, F9); patterns (F5-04). Acceleration, homing and curved paths are not in PLANEJAMENTO and not supported: a Projectile's velocity is constant.

## Files

- `scripts/combat/projectile_spawn.gd` (value, `class_name ProjectileSpawn extends RefCounted`).
- `scripts/combat/projectile_field.gd` (Rules Core, `class_name ProjectileField extends RefCounted`).
- `tests/unit/combat/test_projectile_field.gd` (12 tests for F5-01; F5-02 added none, by the sprint's no-new-tests rule).

## ProjectileSpawn

A plain request. `enum Faction { PLAYER, HOSTILE }`. Fields, in `_init` order with their defaults: `position: Vector3` (`ZERO`), `velocity: Vector3` in units per second (`ZERO`), `faction: Faction` (`HOSTILE`), `lifetime: float` in seconds (`1.0`), `radius: float` in world units (`0.25`), `damage: int` (`CombatState.HIT_DAMAGE`, 10). The field copies the values and never keeps the request, so one request may be changed and reused for a whole volley.

## ProjectileField contract

### Exports

None. A Rules Core has no exports (ADR-0001); capacity and the Flight Volume margin become Inspector values on F6-02's `ProjectileSystem`.

### Signals

Both are emitted after the tick's pass, in ascending slot order (see "Events rule"). F5-03 adds `enemy_hit`.

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `player_hit` | `projectile_id: int, damage: int` | A HOSTILE Projectile met the Core while the player was not invulnerable, and was removed. `damage` is its `ProjectileSpawn.damage`. At most once per tick. F7-01 calls `CombatState.take_hit(damage)`. |
| `grazed` | `projectile_id: int` | A HOSTILE Projectile passed through the Graze Volume without touching the Core, while the player was not invulnerable, for the first time in its life. F7-01 adds Graze and score. |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `setup(capacity: int, bounds: AABB, obstacle_query: Callable)` | F6-02 at stage load | Sizes the arrays once (capacity 1 to `MAX_CAPACITY`, 65 536), empties the field and resets the refusal counter. `bounds` is the Flight Volume, a position plus a positive size. `obstacle_query` is `func(from: Vector3, to: Vector3) -> bool`, true when scenery or a closed Gate blocks the segment; an invalid `Callable()` means no obstacles. Ids from before a `setup` stay dead. |
| `spawn(request: ProjectileSpawn) -> int` | F6-02 (from F5-04 emitters and F6-03's weapon) | Takes the lowest free slot and returns a new id, or `NO_PROJECTILE` (-1) when full. Asserts lifetime, radius and damage above 0 (`CombatState.take_hit` asserts a positive damage). A request outside the bounds is accepted and culled on its first tick. |
| `tick(delta: float)` | F6-02, every physics tick | One pass in ascending slot order (see "Tick order"), then the tick's events. |
| `set_player(previous_center: Vector3, center: Vector3, core_radius: float, graze_radius: float, invulnerable: bool)` | F6-02, before every tick | The Core's center at the previous tick and now, the Core and Graze radii (`0 < core <= graze`, asserted), and `CombatState.is_invulnerable()`. Holds until called again; `setup` keeps it. |
| `clear_player()` | F6-02 between stages, after the ship is freed | No player: later ticks sweep nothing. A new field starts with no player. |
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
4. A HOSTILE Projectile is swept against the player (see "Core sweep and Graze"); F5-03 inserts the target sweep for PLAYER ones here.
5. It moves to `to`, and is removed when `to` is outside the bounds.

### Core sweep and Graze

With a player set, each HOSTILE Projectile's tick segment is taken in the player's frame: from `from - previous_center` to `to - center`. The closest distance `d` from that relative segment to the origin decides contact, so a fast bullet, a fast player, or both at once cannot tunnel through (ENGINEERING_BRIEF 8). PLAYER Projectiles never touch the player.

- **Core contact**, `d <= core_radius + radius`: the Projectile is removed and `player_hit(id, damage)` is queued. It never also grazes: hit before Graze on the same contact.
- **Graze contact**, `d <= graze_radius + radius` without Core contact: if the Projectile's Graze is not spent, it is spent and `grazed(id)` is queued. Each Projectile grazes at most once in its life.
- **Invulnerable** (the `invulnerable` flag of `set_player`): a Core contact reports nothing and the Projectile passes through. Any contact, Core or Graze, spends the Projectile's Graze for good, so it cannot graze after Invulnerability ends either. This is Claude's **strict reading** of PLANEJAMENTO Section 4, "disable new graze awards during invulnerability", chosen so a Bomb or a hit window can never pre-load a Graze. D-07 Part B ruling 5 confirms or changes it (pending when F5-02 landed).
- **The first hit of a tick makes the rest of that tick invulnerable.** The event reaches `CombatState` only after the pass, and an accepted hit starts Invulnerability or defeat there (a Shield hit included). So later Core contacts in the same pass pass through, later contacts are spent, and the tick queues no further Graze. A Graze queued earlier in the same pass, by a lower slot, still stands.
- A Projectile removed by the obstacle query never reaches the sweep: a wall between the bullet and the player protects the player.

The ship's authored spheres set the scale: Core radius 0.18 and Graze radius 0.55 in `player_ship.tscn`. F6-02 reads them from the shapes, so changing a sphere changes contact exactly.

### Events rule

F5-02's `player_hit` and `grazed` follow it, and F5-03's `enemy_hit` must. Events decided during the pass are buffered and emitted after it, in ascending slot order. A listener may call `spawn`, `despawn` or a clear; a Projectile spawned then is first moved on the next tick. `clear_all()` from a listener also drops the tick's events not yet emitted (a defeat that unloads the stage); the hostile clears of F5-03 do not. Neither a listener nor the obstacle query may call `tick`, and the obstacle query must not call back into the field at all.

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
| A fast Projectile crossing the Core between ticks hits (ENGINEERING_BRIEF 8) | None: the sprint's no-new-tests rule (2026-09-23). Relative-segment closest distance in `_player_contact`; verified by review only. |
| Hit takes precedence over Graze on the same contact (ENGINEERING_BRIEF 8) | None (same rule). A Core contact returns before the Graze branch. |
| Each hostile Projectile grazes at most once (ENGINEERING_BRIEF 8) | None (same rule). The per-slot `_graze_spent` flag, reset only by `spawn`. |
| Invulnerability does not enable Graze farming (ENGINEERING_BRIEF 8) | None (same rule). Any contact while invulnerable spends the Graze; the strict reading above. |
| Cleared Projectiles award no Graze (ENGINEERING_BRIEF 8) | `clear_all` emits nothing and drops the tick's pending events; F5-03 covers the hostile clears. |

## Setup for Astra

None: code only. Capacity and the Flight Volume margin become Inspector values on `ProjectileSystem` in F6-02.

## Open issues

- **F5-02's rules have no unit tests.** The sprint's no-new-tests rule (2026-09-23) landed while F5-02 was in progress; the sweep, the Graze rules and the events rule were verified by review only, and first run for real in F6-02 and F7-01.
- **Ruling 5 pending.** The strict Invulnerability reading holds until D-07 Part B rules on it. The lenient alternative (a Projectile touched while invulnerable may still graze once afterwards) is a one-line change in `tick`: spend the Graze only when `grazed` is queued.
- **Hot-path cost is unmeasured.** Each tick calls the obstacle query once per moving Projectile, and the player sweep once per hostile one; `_remove` keeps the free list sorted with a native binary search and insert. F6-02's benchmark measures both at 1000 to 3000 Projectiles.
- The read-out allocates two new arrays per faction per call. F6-02 may add a buffer-shaped read-out if its benchmark asks for one.
