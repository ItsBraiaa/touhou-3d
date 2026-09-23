# F5-01 ProjectileField core: spawn, move, cull

Status: todo
Type: core
parallel-safe: yes
Depends on: F0-02

## Goal

A Node-free `ProjectileField` holds every Projectile in packed arrays. It spawns them from a `ProjectileSpawn` request with a stable id, moves them each tick, and removes them when their lifetime ends, when they leave the Flight Volume, and when they meet scenery or a closed Gate, which it learns through an injected obstacle query (ADR-0004). Its capacity is fixed, with a documented policy for when it is full, and it exposes a read-out per faction for rendering. It also fixes the rule for events that F5-02 and F5-03 rely on: every event is emitted after the tick's pass. Core hits and Graze (F5-02), and clears and enemy hit spheres (F5-03), extend this same file. The F6-01 spike and the F5-04 emitter build on this ticket alone.

## Read first

- `docs/adr/0004-central-projectile-field.md` (including "Scenery and Gates") and `docs/adr/0001-gameplay-rules-in-node-free-cores.md`
- `docs/ENGINEERING_BRIEF.md` Section 4.D (frame-rate variation, large populations, cleanup when encounters end)
- `docs/engineering/CONVENTIONS.md` "Architecture rules", "Time and randomness", "Collision" (projectiles die on scenery, on lifetime end and on leaving the Flight Volume)
- `CONTEXT.md` Combat terms (Projectile, Projectile Field, Flight Volume)
- `.scratch/projectile-field/spec.md` "Cross-feature contracts"
- `scripts/combat/combat_state.gd` (`HIT_DAMAGE` is the default damage)

## Files

- **Creates:** `scripts/combat/projectile_spawn.gd`, `scripts/combat/projectile_field.gd`, `tests/unit/combat/test_projectile_field.gd`, `docs/engineering/projectile-field.md`.
- **Edits:** nothing else.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F5 rows), `docs/HANDOFF_LOG.md`, `docs/engineering/projectile-field.md` (new) and its line in `docs/engineering/README.md`.
- **Must not touch:** `scripts/combat/combat_state.gd` (F4-01 is done), `scripts/combat/player_weapon.gd`, `scenes/main.tscn`, anything under `scenes/`.
- **Conflicts with:** F5-02 and F5-03 (the same field and test file; serialized by Depends on). Disjoint from F5-04, F4-*, F8-*.

## Deliverables

### `ProjectileSpawn` (`scripts/combat/projectile_spawn.gd`)

`class_name ProjectileSpawn extends RefCounted`, a plain request value. `enum Faction { PLAYER, HOSTILE }`. Typed public fields `position: Vector3`, `velocity: Vector3` (units per second), `faction: Faction`, `lifetime: float` (seconds), `radius: float` (world units), `damage: int`. Its `_init(p_position := Vector3.ZERO, p_velocity := Vector3.ZERO, p_faction := Faction.HOSTILE, p_lifetime := 1.0, p_radius := 0.25, p_damage := CombatState.HIT_DAMAGE)`. The field copies the values and never keeps the request.

### `ProjectileField` (`scripts/combat/projectile_field.gd`)

`class_name ProjectileField extends RefCounted`, with no Node, SceneTree, physics or timer. State lives in packed arrays indexed by slot: `PackedVector3Array` positions and velocities, `PackedFloat32Array` lifetimes and radii, `PackedInt32Array` damages, factions and generations, and a `PackedByteArray` of alive flags, plus a free-slot list.

- `const NO_PROJECTILE := -1`.
- `setup(capacity: int, bounds: AABB, obstacle_query: Callable)`: asserts `capacity > 0`, allocates the arrays once, empties the field and resets the counters. `obstacle_query` is `func(from: Vector3, to: Vector3) -> bool` and returns true when the segment is blocked by scenery or a closed Gate. An invalid Callable means there are no obstacles.
- `spawn(request: ProjectileSpawn) -> int`: asserts `request.lifetime > 0` and `request.radius > 0`, takes the lowest free slot, and returns a new id.
  - **Ids are unique for the field's lifetime and never reused,** even when a slot is recycled. Encode slot plus generation, or keep a map; the implementer chooses, and a test pins it.
  - **When every slot is alive, the request is refused:** `spawn` returns `NO_PROJECTILE` and `get_refused_count()` goes up by one. Existing Projectiles are never evicted, because a bullet the player is reading must not vanish.
  - A request outside the bounds is accepted and culled on its first tick.
- `tick(delta: float)` makes one pass over the alive slots in ascending slot order:
  1. Lifetime goes down by `delta`. At 0 or below, the Projectile is removed without moving.
  2. Otherwise the segment is `from = position` to `to = position + velocity × delta`.
  3. When `obstacle_query.call(from, to)` returns true, the Projectile is removed at `from`. This comes before any Core or target sweep: a wall between the bullet and the player protects the player. The error is under one tick of travel and never in the bullet's favor.
  4. F5-02 inserts the Core sweep here, and F5-03 the target sweep.
  5. The Projectile moves to `to`, and is removed when `to` is outside the bounds.
- **Events rule** (no signal in this ticket; F5-02 and F5-03 must follow it): events decided during the pass are buffered and emitted after it, in slot order. A listener may call `spawn`, `despawn` or a clear, and a Projectile spawned then is first moved on the next tick. `clear_all()` from a listener also drops the tick's events not yet emitted.
- `despawn(id: int) -> bool`: removes the Projectile and returns true. An unknown, dead or recycled id changes nothing and returns false.
- `clear_all()`: removes every Projectile and keeps the id counter, so an old id stays dead.
- `set_bounds(bounds: AABB)`.
- Read-out:
  - `count(faction) -> int`, `is_alive(id) -> bool`, `get_position(id) -> Vector3` (`Vector3.ZERO` for a dead id), `get_refused_count() -> int`, `get_capacity() -> int`.
  - For rendering, `get_positions(faction) -> PackedVector3Array` and `get_radii(faction) -> PackedFloat32Array`: parallel arrays of that faction's alive Projectiles, in ascending slot order. If the F6-01 spike shows a buffer-shaped read-out is needed, F6-02 adds it.
- A `##` doc comment on every public method, and the tick order written in the class doc comment.

## Tests required

In `tests/unit/combat/test_projectile_field.gd`, with fixed deltas, a fake obstacle query built from a plane or a box, and no scene:

- `test_spawn_returns_distinct_ids_and_counts_by_faction`
- `test_projectile_moves_by_velocity_times_delta`
- `test_movement_is_independent_of_the_tick_rate` (120 ticks of 1/120 and 60 of 1/60 end at the same point)
- `test_projectile_is_removed_when_its_lifetime_ends`
- `test_projectile_leaving_the_bounds_is_removed`
- `test_projectile_meeting_an_obstacle_is_removed_before_it_passes` (a fake wall between from and to; ADR-0004)
- `test_obstacle_query_receives_the_tick_segment`
- `test_full_field_refuses_new_spawns_and_counts_them` (the existing Projectiles survive)
- `test_ids_are_never_reused_after_a_slot_is_recycled`
- `test_despawn_returns_false_for_a_dead_id`
- `test_clear_all_empties_the_field_and_old_ids_stay_dead` (cleanup when encounters end)
- `test_render_read_out_lists_alive_projectiles_of_one_faction`

Grep the output for `SCRIPT ERROR`: a runtime error after an assertion still reports PASS.

## Out of scope

- Core sweep and Graze (F5-02).
- Clears, hit spheres and `enemy_hit` (F5-03).
- Patterns (F5-04).
- The physics-ray obstacle query, rendering, and the Node that ticks the field (F6-02).
- Acceleration, homing or curved paths, which are not in PLANEJAMENTO.

## Definition of Done

- `tools/test.ps1` is green with no `SCRIPT ERROR`, every test above exists, and there are no Error-level warnings.
- `docs/engineering/projectile-field.md` is written from `docs/engineering/TEMPLATE.md` (purpose, tick order, events rule, full-field policy, id rule, read-out), with its line in `docs/engineering/README.md`.
- A handoff log entry, ticket `Status: done` with an Outcome section, and the roadmap row.
- One commit: `combat: add ProjectileField spawn, move and cull`.

## Handoff notes for Astra

None: this is code only. Capacity and the Flight Volume margin become Inspector values on `ProjectileSystem` in F6-02.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/projectile-field/issues/01-field-core-spawn-move-cull.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
