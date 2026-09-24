# Weapon and rendering

Feature F6: the Projectile Field in the running game, and the ship's weapon. Started with ticket F6-02 on 2026-09-23, which folds in the F6-01 rendering measurement. `ProjectileSystem` is CODE_READY (F6-02), and so are the `WeaponModel` core (F6-03 part 1, oc-a) and the `PlayerWeapon` adapter with its dev Familiars and target dummies (F6-03 part 2).

## Purpose

`ProjectileSystem` puts the F5 `ProjectileField` on `Main/ProjectileRoot`. Every physics step it hands the field the ship's Core and Graze spheres, ticks it after the actors have moved and registered, answers its obstacle query with a layer-1 ray, calls back the targets that registered a hit sphere, and draws both factions with one `MultiMeshInstance3D` each. The Session sets it up on every stage load and clears it on every unload.

It does not own any Projectile rule (the field's, ADR-0004), what a hit or a Graze does to `CombatState`, `RunState` or score (F7-01), the Bomb (F7-02), player shots (F6-03), enemy registration (F9-02), patterns (F5-04) or final Projectile art (Astra). It never pauses itself: `ProjectileRoot` is PAUSABLE, so a paused tree freezes every Projectile.

## Files

- `scripts/combat/projectile_system.gd` (Adapter, `class_name ProjectileSystem extends Node3D`, attached to `Main/ProjectileRoot` in `scenes/main.tscn`).
- `scenes/dev/projectile_player_mesh.tres`, `scenes/dev/projectile_hostile_mesh.tres` (dev `SphereMesh` of radius 1, unshaded and emissive, cyan and rose).
- `scenes/dev/dev_spray.gd` (`DevSpray`, dev only: rings of hostile Projectiles on a timer), used by `scenes/dev/arena_harness.tscn`.
- No test file: the sprint's no-new-tests rule (2026-09-23). `tests/scene/test_game_session_flow.gd`'s Return to Menu case was adjusted to spawn a Projectile and expect `count() == 0`.
- The folded F6-01 measurement: [spikes/projectile-rendering.md](spikes/projectile-rendering.md).
- `scripts/combat/weapon_model.gd` (Rules Core, `class_name WeaponModel extends RefCounted`; F6-03 part 1).
- `scripts/combat/player_weapon.gd` (Adapter, `class_name PlayerWeapon extends Node`, on `PlayerShip/Weapon`).
- `scenes/dev/familiar.tscn` (dev Familiar: a `Node3D` and an emissive sphere, no collision), `scenes/dev/target_dummy.gd` and `.tscn` (`TargetDummy`, dev only).

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
| `damage_targets_in_radius(center: Vector3, radius: float, damage: int) -> int` | Session `_on_bomb_activated` (F7-02) | Calls `on_damage(damage)` once on every target registered for the coming tick whose sphere overlaps the radius (a target registered twice is damaged once) and returns how many. It must run after the actors registered this tick, as the weapon's physics priority (50) guarantees. |
| `set_player_invulnerable(active: bool)` | F7-01, mirroring `CombatState.is_invulnerable()` | Passed to the field's sweep every tick: while true a Core contact passes through and no Graze is awarded. |
| `get_field() -> ProjectileField` | tests, dev tools | The field itself. |

### Physics step

`process_physics_priority` is `TICK_PRIORITY` (100). Actors keep the default 0, so enemies register their spheres and the ship moves before this step reads them. Each step:

1. While the ship of the last `setup` is valid, inside the tree and its shapes are usable: `set_player(previous, current, core, graze, invulnerable)`, with the Core's `global_position` now and at the previous step. Otherwise `clear_player()`. (The Session removes the ship from the tree before freeing it, and a step may fall in between.)
2. The world's `direct_space_state` is read, then `tick(delta)`. The obstacle query reuses one `PhysicsRayQueryParameters3D`: bodies only, `obstacle_mask`, and `hit_from_inside`, so a Projectile that starts inside scenery dies there.
3. Just before `tick`, the callbacks registered since the last step become the tick's own and a fresh set starts, so a registration lasts one tick, like the field's registry, and a target that registers from inside the tick's events keeps its callback for the next tick. The field emits `enemy_hit` inside `tick`, looked up in the tick's set.
4. Both renderers are refreshed from `get_positions` and `get_radii`: each instance is the unit mesh scaled by the Projectile's radius, written into a persistent `PackedFloat32Array` of `capacity × 12` floats (a `TRANSFORM_3D` buffer) and assigned to `multimesh.buffer`, with `visible_instance_count` set to the alive count. A faction that was and still is empty is skipped. Rendering happens in physics, with no interpolation.

Before the first `setup` the field has a unit placeholder Flight Volume at the origin (the field refuses an empty one), so nothing spawned on the main menu survives.

## WeaponModel

`scripts/combat/weapon_model.gd` (Rules Core, `class_name WeaponModel extends RefCounted`), delivered by oc-a as F6-03 part 1; its contract is in its doc comments, summarized here.

- `enum Source { MAIN, FAMILIAR_LEFT, FAMILIAR_RIGHT }`; inner class `Shot` (`source: int`, `assist_degrees: float`); inner class `Tuning` with `main_interval` 0.1, `familiar_interval_level_2` 0.25, `familiar_interval_level_3` 0.15, `main_assist_degrees` 10, `familiar_assist_degrees_level_2` 10, `familiar_assist_degrees_level_3` 20 (seconds and degrees; Claude's proposals).
- `configure(tuning)` copies a `Tuning` (intervals must be positive, asserted).
- `tick(delta, fire_held, power_level) -> Array[Shot]`: each source's cooldown counts down every tick and stops at 0; while fire is held, a cooled source fires and adds its interval, looping so a long `delta` fires every due shot. The first shot of a press fires at once when cooled; tapping cannot beat the cadence. Familiars fire only from Power Level 2, faster and with a wider cone at 3.
- `familiar_count(power_level) -> int`: 0 at level 1, 2 at levels 2 and 3.
- `static assist_direction(origin, forward, target_point, max_degrees) -> Vector3`: the direction to the target when it lies within `max_degrees` of `forward`, else `forward`, normalized. No homing.
- `reset()` clears the cooldowns. No Bomb logic: the Bomb edge is `CombatState`'s.

## PlayerWeapon contract

`scripts/combat/player_weapon.gd` (Adapter, `class_name PlayerWeapon extends Node`, on `PlayerShip/Weapon`, wired in `scenes/player/player_ship.tscn`).

### Exports

| Export | Type | Default | Required | Meaning |
| --- | --- | --- | --- | --- |
| `muzzle` | `Marker3D` | `../Muzzle` | yes | Where the main shot leaves, in ship coordinates. |
| `familiar_anchors` | `Node3D` | `../FamiliarAnchors` | yes | Holds the `Left` and `Right` markers the Familiars sit on and fire from. |
| `camera_rig` | `CameraRig` | `../CameraRig` | yes | Yaw source for the offsets, and the camera whose view the shots follow. |
| `familiar_scene` | `PackedScene` | `scenes/dev/familiar.tscn` | yes | One Familiar's visuals: a `Node3D` root and no `CollisionObject3D` (ENGINEERING_BRIEF 4.E), checked in `_ready`. |
| `shot_speed`, `shot_lifetime`, `shot_radius` | `float` | 60, 1.2, 0.15 | yes | Every shot: 72 units of range, beyond the 60-unit lock range. |
| `shot_damage`, `familiar_shot_damage` | `int` | 1, 1 | yes | Damage a main or a Familiar shot carries to `on_damage`. |
| The six `Tuning` values | `float` | as `WeaponModel.Tuning` | yes | Copied into the model in `_ready`. |
| `bomb_radius`, `bomb_damage`, `bomb_visual_scene` | `float`, `int`, `PackedScene` | 10.0, 20, `scenes/dev/bomb_blast.tscn` | the scene is optional | The "Bomb" group (F7-02): read by the Session's Bomb handler, not by the weapon ([damage-pickups.md](damage-pickups.md) "Bomb"). |

A missing reference, a missing `Left` or `Right` marker, or a Familiar scene with a collision object is reported with `push_error` and disables the weapon.

A target that has left the tree but is not freed yet is ignored for Aim Assist. `_exit_tree` disconnects the weapon from the `CombatState` and the `Targeting` at once, so a ship on its way out never reacts to the next stage's `power_changed`.

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `setup(combat_state: CombatState, projectile_system: ProjectileSystem, targeting: Targeting)` | Session `_load_stage` (after `projectile_system.setup`), the arena harness | Disconnects any earlier setup, connects `targeting.target_changed` (the Aim Assist target) and `combat_state.power_changed` (Familiar visibility), resets the cadence, shows the Familiars for the current Power Level and enables fire. |
| `set_fire_enabled(enabled: bool)` | `PlayerController.set_controls_enabled()` | While false: no shots and no Bomb feed, and the held Bomb button is forgotten. |

### Each physics tick (set up and enabled)

The weapon's `process_physics_priority` is `PHYSICS_PRIORITY` (50, since F7-02): after every actor (0), so this tick's lock, yaw, ship position and enemy registrations are what a shot or a Bomb sees, and before the `ProjectileSystem` (100), which moves this tick's shots.


1. `WeaponModel.tick(delta, Input.is_action_pressed(&"fire"), power_level)`.
2. `_fire(shots)`, the single fire path (F13-03 adds `shots_fired` here). For each shot:
   - **Origin:** the ship's position plus `Basis(UP, camera_rig.get_yaw())` × the local offset (`Muzzle`, or the `Left` or `Right` anchor under `FamiliarAnchors`). The body never yaws (F1-02), so the offsets are rotated in code and no authored node moves.
   - **Forward:** toward the point the camera's center ray reaches at the locked target's depth along the view, or at the shot's range (`shot_speed × shot_lifetime`) with no lock, and always at least `MIN_AIM_AHEAD` (8 units) ahead of the shot's origin along the view, so a close target never turns it up or back. This is Claude's reading of "where the view looks". The camera sits 8.5 behind and 3.2 above the Muzzle, and measured from the camera's own axis that parallax alone put a locked target 12.4° off, outside the 10° main cone. Measured from the view point, the cone sees the target's real offset from the screen center.
   - **Aim Assist:** with a lock, `WeaponModel.assist_direction(origin, forward, hit_volume_point, shot.assist_degrees)`.
   - `projectile_system.spawn(...)` of a PLAYER `ProjectileSpawn` at `shot_speed`, `shot_lifetime`, `shot_radius` and the source's damage.
3. `combat_state.update_bomb_input(_bomb_held)`, once. A Bomb shows up as `CombatState.bomb_activated()` (F7-02 connects it); there is no `bomb_requested` signal.

### Bomb button

`_unhandled_input` sets `_bomb_held` on a `bomb` press and clears it on the release, only while fire is enabled; nothing is consumed. The weapon is under `WorldRoot`, which is PAUSABLE, so it hears nothing while the tree is paused, and gamepad B on Pause (Back, then resume) is consumed by `Interface` before gameplay.

### Familiars

Two `familiar_scene` instances, `top_level` children of `Left` and `Right`, hidden until `familiar_count(level) > 0`. `_process` places them at the yaw-rotated anchor points on a small orbit (`FAMILIAR_ORBIT_RADIUS` 0.3, one turn per second, the right one half a turn behind). They are placed the moment they are shown, so they never flash at the origin. Shots leave from the anchor point, not the orbiting visual.

## TargetDummy

`scenes/dev/target_dummy.gd` (`class_name TargetDummy extends Node3D`), the root of `scenes/dev/target_dummy.tscn`; dev only.

- It is in `targetable`, with a `HitVolume` (`Area3D`, layer 5 = 16, mask 0, monitoring off, `SphereShape3D` radius 0.8) and a `Visual` sphere.
- `setup(projectile_system)`. Every physics tick, at the default priority and so before the ProjectileSystem's step, it calls `register_target(get_instance_id(), hit_volume.global_position, radius, _on_damage)`.
- `_on_damage(damage)` adds to `hit_count` and `damage_taken`, and raises the emission of its own copy of the material for 0.1 s. It never dies.

## DevSpray

`scenes/dev/dev_spray.gd`, dev only and never in `main.tscn`. A `Node3D` with the required export `projectile_system` and the dev values `interval` 1.5 s (0 stops the timer), `ring_size` 24, `speed` 6 and `lifetime` 10 s. Every `interval` of physics time it calls `spawn_ring()`: one horizontal ring of hostile Projectiles from its position, each ring rotated half a gap from the last. `spawn_ring() -> int` returns how many the field accepted. In the arena harness it sits at (0, 6, 0), so each ring crosses the ship's start at (0, 6, 18) after 3 s and dies on the perimeter walls.

## Arena harness

`scenes/dev/arena_harness.tscn` gains a `ProjectileSystem` child with the dev meshes, set up with the arena's Flight Volume and the ship, and a `DevSpray`. The readout adds `bullets hostile N player N` and `hits N grazes N refused N`, counted from `player_hit` and `grazed`. Since F6-03 the ship's weapon is set up with the harness's `CombatState` and `ProjectileSystem`, three `TargetDummy`s under `Dummies` (at (-10, 7, -6), (10, 11, -10) and (0, 14, -34)) register with it, the dev keys 1, 2 and 3 restart the `CombatState` at that Power Level, and the readout adds `power N bombs N` and each dummy's hits.

## Session wiring

`GameSession`'s export `projectile_root: Node3D` is now `projectile_system: ProjectileSystem` (the node keeps its name `ProjectileRoot`), validated in `_ready`. `_load_stage` ends with `projectile_system.setup(bounds, _player)`. `_unload_stage` frees only `WorldRoot`'s children and calls `projectile_system.clear_all()`: the renderers are `ProjectileRoot`'s own children and stay.

Since F6-03, `_load_stage` then calls `_player.weapon.setup(_combat_state, projectile_system, _player.targeting)`, and `PlayerController.set_controls_enabled()` turns the weapon's fire off and on with the controls, so pause and Defeat stop firing through the Session's one `_set_paused` call.

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
| Holding fire shoots at the main cadence; Power Level 2 and 3 add Familiars and shots (ENGINEERING_BRIEF 4.E) | Harness run: 5, 9 and 13 shots in 30 ticks at levels 1, 2 and 3 |
| Familiars add no collision volume (ENGINEERING_BRIEF 4.E) | Harness run: 0 `CollisionObject3D`; `PlayerWeapon._ready` refuses a Familiar scene with one |
| Aim Assist bends shots onto a locked dummy | Harness run: 10 hits in 60 ticks |
| Shots follow the camera yaw | Harness run: after a 90° orbit, shots travel along the view |
| One Bomb press spends one Bomb, through the real input path | Harness run: three held presses spend the 2 Bombs |

## Setup for Astra

- Nothing to wire: the node is in the Claude-owned `scenes/main.tscn`.
- `DamageCore` and `GrazeVolume` stay `monitoring = false`. Their sphere radii (0.18 and 0.55) are the hit and Graze sizes, so resizing a sphere changes gameplay exactly.
- For final Projectile art (D-02), deliver a mesh of radius 1 with one material per faction; Claude swaps the two exports on `Main/ProjectileRoot` and on the harness.
- Closed Gate barriers and any solid scenery must be `StaticBody3D` on layer 1 for Projectiles to die on them; foliage stays off layer 1 (F1-05).
- `PlayerShip/Weapon` carries the shot values, cadences and Aim Assist cones as Inspector exports (Claude's proposals). A final Familiar scene (D-02) must have a `Node3D` root and no `CollisionObject3D`; the weapon refuses one that does. Keep each target's `HitVolume` centered on its visible body: Aim Assist aims at it.
- The body and `VisualRoot` never yaw; shots and Familiars follow the camera yaw in code, so an F1 pass that turns `VisualRoot` toward the view changes nothing here.

## Open issues

- **No scene tests.** The ticket's twelve contract tests and three flow cases were not written (sprint rule); the behavior is verified by running the game.
- **One ray per moving Projectile per tick.** The measurement in the spike record gives the cost; no mitigation is built.
- **Rendering in physics, no interpolation.** At 60 physics ticks per second and a higher frame rate, Projectiles step once per tick.
- **Every Core hit is preceded by a Graze** (reviewer finding, for F7-01 and D-07 Part B). The Graze shell is about 0.37 units thick and a speed-6 bullet moves 0.1 per tick, so a bullet on a head-on path grazes a few ticks before it hits: F5-02's "hit before Graze" holds within one tick only. If a hit should cancel its own Graze, that is a field rule (F5-02) or an F7-01 policy, not this adapter's.
- **`obstacle_mask` is read once in `_ready`;** changing it later has no effect.
- **F6-03 reading: shots aim at the view point.** Forward is toward the center ray's point at the lock's depth (or at shot range), not the camera's own axis; see "PlayerWeapon contract". With no lock the shots converge on the screen center 72 units out.
- **The dummies never die**, and a shot that reaches one in the tick that pauses the tree still counts (dev only; F9-02's enemies should ignore damage while paused).
- **Swap pending: D-02** (the Projectile meshes and the Familiar scene).
