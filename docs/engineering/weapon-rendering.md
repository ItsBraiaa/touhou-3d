# Weapon and rendering

Feature F6: the Projectile Field in the running game, and the ship's weapon. Started with ticket F6-02 on 2026-09-23, which folds in the F6-01 rendering measurement. `ProjectileSystem` is CODE_READY (F6-02); `WeaponModel` and `PlayerWeapon` (F6-03) are not built yet.

## Purpose

`ProjectileSystem` puts the F5 `ProjectileField` on `Main/ProjectileRoot`. Every physics step it hands the field the ship's Core and Graze spheres, ticks it after the actors have moved and registered, answers its obstacle query with a layer-1 ray, calls back the targets that registered a hit sphere, and draws both factions with one `MultiMeshInstance3D` each. The Session sets it up on every stage load and clears it on every unload.

It does not own any Projectile rule (the field's, ADR-0004), what a hit or a Graze does to `CombatState`, `RunState` or score (F7-01), the Bomb (F7-02), player shots (F6-03), enemy registration (F9-02), patterns (F5-04) or final Projectile art (Astra). It never pauses itself: `ProjectileRoot` is PAUSABLE, so a paused tree freezes every Projectile.

## Files

- `scripts/combat/projectile_system.gd` (Adapter, `class_name ProjectileSystem extends Node3D`, attached to `Main/ProjectileRoot` in `scenes/main.tscn`).
- `scenes/dev/projectile_player_mesh.tres`, `scenes/dev/projectile_hostile_mesh.tres` (dev `SphereMesh` of radius 1, unshaded and emissive, cyan and rose).
- `scenes/dev/dev_spray.gd` (`DevSpray`, dev only: rings of hostile Projectiles on a timer), used by `scenes/dev/arena_harness.tscn`.
- No test file: the sprint's no-new-tests rule (2026-09-23). `tests/scene/test_game_session_flow.gd`'s Return to Menu case was adjusted to spawn a Projectile and expect `count() == 0`.
- The folded F6-01 measurement: [spikes/projectile-rendering.md](spikes/projectile-rendering.md).

## ProjectileSystem contract

### Exports

| Export | Type | Default | Required | Meaning |
| --- | --- | --- | --- | --- |
| `capacity` | `int` (1..65536) | 2048 | yes | Projectiles alive at once, both factions together; also each renderer's instance count. A full field refuses new spawns, warned once per stage. |
| `cull_margin` | `float` | 5.0 | yes | World units added around the stage's Flight Volume before a Projectile is culled. |
| `obstacle_mask` | layers | 1 | yes | Bodies on these layers stop Projectiles: scenery, Flight Volume walls, closed Gate `BarrierBody`s. Areas never block, so hit volumes, the Core and the Graze Volume never do. |
| `player_projectile_mesh` | `Mesh` | dev cyan sphere | yes | Unit-radius mesh for player Projectiles, scaled by each one's radius. |
| `hostile_projectile_mesh` | `Mesh` | dev rose sphere | yes | Unit-radius mesh for hostile Projectiles. |

All values are Claude's proposals. A missing mesh is reported with `push_error` and disables the node.

### Signals

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `player_hit` | `projectile_id: int, damage: int` | Re-emitted from the field: a hostile Projectile met the Core while the ship was not invulnerable. F7-01 calls `CombatState.take_hit(damage)`. |
| `grazed` | `projectile_id: int` | Re-emitted from the field: a hostile Projectile's first Graze. F7-01 adds Graze and score. |

Nothing here touches `CombatState` or `RunState`.

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `setup(bounds: AABB, player: PlayerController)` | Session `_load_stage` (last), the arena harness | Re-runs the field's `setup` with `bounds.grow(cull_margin)` (which empties it and restarts its refusal count; the arrays keep their size) and sets each renderer's `custom_aabb` to the same bounds; clears `set_player_invulnerable`; reads the Core and Graze radii from the first `CollisionShape3D` child of `player.damage_core` and `player.graze_volume` (each must be a `SphereShape3D`, Core no larger than Graze; otherwise the ship is reported and the sweep is off), re-arms the refusal warning and calls `clear_all()`. Node scale is ignored. |
| `clear_all()` | Session `_unload_stage`, `setup` | Removes every Projectile and every damage callback, awarding nothing, empties both renderers, and resets the previous Core center to the current one, so a teleport never sweeps across the stage. |
| `spawn(request: ProjectileSpawn) -> int` | F5-04 emitters, F6-03's weapon, `DevSpray` | The field's `spawn`. The first refusal of a stage prints one `push_warning` with the refused count. |
| `clear_hostile_in_radius(center, radius) -> int`, `clear_hostile_all() -> int`, `targets_in_radius(center, radius) -> PackedInt64Array`, `count(faction) -> int` | F7-02, F10, F12, the harness | Passthroughs to the field. |
| `register_target(target_id: int, center: Vector3, radius: float, on_damage: Callable)` | enemy adapters (F9-02, F12-02), F6-03's dummy, every physics tick | Registers the hit sphere for the coming tick and keeps `on_damage` (`func(damage: int) -> void`) by id. When the field reports `enemy_hit` for that id, `on_damage.call(damage)` runs if the Callable is still valid. |
| `set_player_invulnerable(active: bool)` | F7-01, mirroring `CombatState.is_invulnerable()` | Passed to the field's sweep every tick: while true a Core contact passes through and no Graze is awarded. |
| `get_field() -> ProjectileField` | tests, dev tools | The field itself. |

### Physics step

`process_physics_priority` is `TICK_PRIORITY` (100). Actors keep the default 0, so enemies register their spheres and the ship moves before this step reads them. Each step:

1. While the ship of the last `setup` is valid, inside the tree and its shapes are usable: `set_player(previous, current, core, graze, invulnerable)`, with the Core's `global_position` now and at the previous step. Otherwise `clear_player()`. (The Session removes the ship from the tree before freeing it, and a step may fall in between.)
2. The world's `direct_space_state` is read, then `tick(delta)`. The obstacle query reuses one `PhysicsRayQueryParameters3D`: bodies only, `obstacle_mask`, and `hit_from_inside`, so a Projectile that starts inside scenery dies there.
3. Just before `tick`, the callbacks registered since the last step become the tick's own and a fresh set starts, so a registration lasts one tick, like the field's registry, and a target that registers from inside the tick's events keeps its callback for the next tick. The field emits `enemy_hit` inside `tick`, looked up in the tick's set.
4. Both renderers are refreshed from `get_positions` and `get_radii`: each instance is the unit mesh scaled by the Projectile's radius, written into a persistent `PackedFloat32Array` of `capacity × 12` floats (a `TRANSFORM_3D` buffer) and assigned to `multimesh.buffer`, with `visible_instance_count` set to the alive count. A faction that was and still is empty is skipped. Rendering happens in physics, with no interpolation.

Before the first `setup` the field has a unit placeholder Flight Volume at the origin (the field refuses an empty one), so nothing spawned on the main menu survives.

## DevSpray

`scenes/dev/dev_spray.gd`, dev only and never in `main.tscn`. A `Node3D` with the required export `projectile_system` and the dev values `interval` 1.5 s (0 stops the timer), `ring_size` 24, `speed` 6 and `lifetime` 10 s. Every `interval` of physics time it calls `spawn_ring()`: one horizontal ring of hostile Projectiles from its position, each ring rotated half a gap from the last. `spawn_ring() -> int` returns how many the field accepted. In the arena harness it sits at (0, 6, 0), so each ring crosses the ship's start at (0, 6, 18) after 3 s and dies on the perimeter walls.

## Arena harness

`scenes/dev/arena_harness.tscn` gains a `ProjectileSystem` child with the dev meshes, set up with the arena's Flight Volume and the ship, and a `DevSpray`. The readout adds `bullets hostile N player N` and `hits N grazes N refused N`, counted from `player_hit` and `grazed`.

## Session wiring

`GameSession`'s export `projectile_root: Node3D` is now `projectile_system: ProjectileSystem` (the node keeps its name `ProjectileRoot`), validated in `_ready`. `_load_stage` ends with `projectile_system.setup(bounds, _player)`. `_unload_stage` frees only `WorldRoot`'s children and calls `projectile_system.clear_all()`: the renderers are `ProjectileRoot`'s own children and stay.

## Dependencies

- `ProjectileField` and `ProjectileSpawn` (F5), created and owned here.
- `PlayerController` (`damage_core`, `graze_volume`), passed to `setup`.
- The world's physics space, for the obstacle ray.

## Invariants and tests

The sprint's no-new-tests rule (2026-09-23) replaced the ticket's listed scene tests with running the game; see [validation/weapon-rendering.md](../validation/weapon-rendering.md).

| Invariant | Evidence |
| --- | --- |
| Projectiles die on layer-1 scenery (ADR-0004) | Harness run: no ring passes the arena walls |
| The ship's authored spheres drive hits and Graze | Harness run: hits and Grazes counted from the ring |
| A paused tree freezes every Projectile | Main run: positions unchanged over 30 paused ticks |
| Restart and Return to Menu leave no Projectile | Main run; `test_game_session_flow.gd::test_return_to_menu_unloads_everything_and_shows_the_main_menu` |
| `DamageCore` and `GrazeVolume` keep `monitoring = false` | `player_ship.tscn` untouched |

## Setup for Astra

- Nothing to wire: the node is in the Claude-owned `scenes/main.tscn`.
- `DamageCore` and `GrazeVolume` stay `monitoring = false`. Their sphere radii (0.18 and 0.55) are the hit and Graze sizes, so resizing a sphere changes gameplay exactly.
- For final Projectile art (D-02), deliver a mesh of radius 1 with one material per faction; Claude swaps the two exports on `Main/ProjectileRoot` and on the harness.
- Closed Gate barriers and any solid scenery must be `StaticBody3D` on layer 1 for Projectiles to die on them; foliage stays off layer 1 (F1-05).

## Open issues

- **No scene tests.** The ticket's twelve contract tests and three flow cases were not written (sprint rule); the behavior is verified by running the game.
- **One ray per moving Projectile per tick.** The measurement in the spike record gives the cost; no mitigation is built.
- **Rendering in physics, no interpolation.** At 60 physics ticks per second and a higher frame rate, Projectiles step once per tick.
- **Every Core hit is preceded by a Graze** (reviewer finding, for F7-01 and D-07 Part B). The Graze shell is about 0.37 units thick and a speed-6 bullet moves 0.1 per tick, so a bullet on a head-on path grazes a few ticks before it hits: F5-02's "hit before Graze" holds within one tick only. If a hit should cancel its own Graze, that is a field rule (F5-02) or an F7-01 policy, not this adapter's.
- **`obstacle_mask` is read once in `_ready`;** changing it later has no effect.
- **Swap pending: D-02** (Projectile meshes).
