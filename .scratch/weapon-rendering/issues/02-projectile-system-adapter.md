# F6-02 ProjectileSystem adapter

Status: todo
Type: adapter
parallel-safe: no
Depends on: F5-03
Lane: trunk

> **Sprint note (D-02):** if `scenes/combat/visuals/projectile_player_mesh.tres` and `projectile_hostile_mesh.tres` are on the integration branch, point the two mesh exports at them; otherwise ship the dev meshes and log "swap pending: D-02".

> **Sprint change (2026-09-23, docs/engineering/SPRINT.md): F6-01 is folded in here.**
> - Build one `MultiMeshInstance3D` per faction, with `capacity = 2048`.
> - Do not build a `MeshInstance3D` pool. Wherever this ticket says "the approach F6-01 recommended" or "set from F6-01", read MultiMesh and 2048.
> - Before the Definition of Done, run the measurement F6-01 describes (its "Goal" and measurement sections) once, windowed at 1280 × 720, with the dev spray at 300, 1000 and 3000 Projectiles. Record FPS, frame time, field tick time and ray cost in `docs/engineering/spikes/projectile-rendering.md`, noting that other lanes were running.
> - If 3000 is under 60 FPS, record it and propose the mitigation (a lower capacity, or fewer rays per tick) in the Outcome; do not build it here.
> - The buffer read-out stays optional, and only if the measurement shows per-instance `set_instance_transform` is the bottleneck.

## Goal

`scripts/combat/projectile_system.gd` puts the F5 `ProjectileField` in the running game on `Main/ProjectileRoot`:

- It ticks the field every physics step after the actors have moved and registered.
- It answers the field's obstacle query with a layer-1 ray, so Projectiles die on scenery and closed Gates.
- It feeds the field the ship's authored Core and Graze spheres.
- It calls back the targets that registered a hit sphere.
- It draws both factions with the approach F6-01 recommended.

The Session sets it up on every stage load and clears it on unload, where it used to free `ProjectileRoot`'s children. A dev spray in the arena harness shows it working before any enemy exists.

## Read first

- `docs/engineering/spikes/projectile-rendering.md` (F6-01: the approach, the capacity, whether a buffer read-out is needed)
- `docs/engineering/projectile-field.md` (F5-01 to F5-03, including the events rule and `clear_player()`)
- `docs/adr/0004-central-projectile-field.md`; `docs/engineering/CONVENTIONS.md` "Collision" (layers; `DamageCore` and `GrazeVolume` are geometry sources with monitoring off)
- `docs/GUIDE.md` Section 5 "Main composition" and "Player", Section 6 row `projectile_system.gd`, and Section 13 "Collision layer allocation"
- `scripts/session/game_session.gd` (`projectile_root`, `_load_stage`, `_unload_stage`), `scenes/main.tscn`, `tests/scene/test_game_session_flow.gd` (lines that use `_projectile_root`), `scenes/dev/arena_harness.gd` and `.tscn`
- `scenes/player/player_ship.tscn`: `DamageCore/CollisionShape3D` is a sphere of radius 0.18, and `GrazeVolume/CollisionShape3D` a sphere of radius 0.55

## Files

- **Creates:**
  - `scripts/combat/projectile_system.gd`
  - `scenes/dev/projectile_player_mesh.tres` and `scenes/dev/projectile_hostile_mesh.tres` (dev `SphereMesh` of radius 1, each with an unshaded emissive material in a distinct color)
  - `scenes/dev/dev_spray.gd` (dev only: rings of hostile `ProjectileSpawn`s on a timer, with no pattern core)
  - `tests/scene/test_projectile_system_contract.gd`
  - `docs/engineering/weapon-rendering.md`
  - `docs/engineering/spikes/projectile-rendering.md` (the folded F6-01 measurement)
- **Edits:**
  - `scenes/main.tscn`: attach the script to `ProjectileRoot`, set its exports, and change the `Main` export `projectile_system = NodePath("ProjectileRoot")`.
  - `scripts/session/game_session.gd`: rename and retype `projectile_root: Node3D` to `projectile_system: ProjectileSystem` and validate it; add `projectile_system.setup(bounds, _player)` at the end of `_load_stage`; make `_unload_stage` free only `world_root`'s children and call `projectile_system.clear_all()`; update the doc comments.
  - `tests/scene/test_game_session_flow.gd`: `_projectile_root` becomes `projectile_system`; the "ProjectileRoot empty" check becomes `count() == 0` after a spawn; new cases below.
  - `tests/scene/test_main_contract.gd`, only if the retype breaks it (`ProjectileRoot` stays a `Node3D`).
  - `scenes/dev/arena_harness.gd` and `.tscn`: a `ProjectileSystem` child with the dev meshes, `setup(bounds, _player)`, a `DevSpray` node, and a readout line with the hostile and player counts, hits, Grazes and refused spawns.
  - Only if F6-01 asked for it: `scripts/combat/projectile_field.gd` plus `tests/unit/combat/test_projectile_field.gd`, for a buffer read-out such as `get_multimesh_buffer(faction) -> PackedFloat32Array` with its unit test.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F6-02 row), `docs/HANDOFF_LOG.md`, `docs/engineering/weapon-rendering.md` (new) and its line in `docs/engineering/README.md`, the `docs/GUIDE.md` Section 6 row `projectile_system.gd`, the Section 5 `Main/ProjectileRoot` line and the `game_session.gd` row (export renamed), and `docs/engineering/menus-session.md` "GameSession contract" (the unload change).
- **Must not touch:**
  - `scenes/player/player_ship.tscn`: monitoring and masks stay as authored, because the shapes are read, not monitored.
  - `scenes/tests/combat_arena.tscn` and `scenes/stages/*.tscn` (Astra's).
  - `scripts/combat/combat_state.gd`.
  - `scripts/combat/player_weapon.gd` (F6-03).
- **Conflicts with:**
  - F4-02, F6-03, F7-01, F7-02 and F10-01, for `game_session.gd` and `test_game_session_flow.gd`.
  - F4-02 and F6-03, for `arena_harness.*`.
  - All of these are serialized; none is parallel-safe.

## Deliverables

### `ProjectileSystem` (`scripts/combat/projectile_system.gd`)

`class_name ProjectileSystem extends Node3D`, an Adapter.

**Exports**, all values being Claude's proposals:

- `capacity: int`, set from F6-01, with 2048 if the spike was cut short.
- `cull_margin: float = 5.0`, added around the Flight Volume.
- `@export_flags_3d_physics obstacle_mask: int = 1`.
- `player_projectile_mesh: Mesh` and `hostile_projectile_mesh: Mesh`, both required and dev by default.

**`_ready`:**

- Validate the exports (CONVENTIONS "Setup errors are loud").
- Create the field with `setup(capacity, AABB(), _is_blocked)`.
- Build the renderers the spike chose, created in code as children.
- Set `process_physics_priority` above every actor's (for example 100). Actors keep the default 0, so enemies register and the ship moves first.

**Obstacle query.** `_is_blocked(from, to) -> bool` is `intersect_ray` with `obstacle_mask`, bodies only, and no areas. So layer-1 scenery and closed Gate `BarrierBody`s block, while hit volumes, the Core and the Graze Volume never do.

**`setup(bounds: AABB, player: PlayerController)`:**

- `set_bounds(bounds.grow(cull_margin))` and `clear_all()`.
- Read the radii from the first `CollisionShape3D` child of `player.damage_core` and of `player.graze_volume`, whose shapes must be `SphereShape3D`. A missing or non-sphere shape is reported with both paths, and the sweep is disabled. Node scale is ignored, which is documented.
- Remember `player.damage_core.global_position` as the previous center.

**`_physics_process(delta)`:**

- While the player `is_instance_valid`, call `set_player(previous, current, core, graze, _invulnerable)`. Otherwise call `clear_player()`.
- `tick(delta)`.
- Empty the damage-callback registry, since registrations last one tick.
- Refresh the render instances from the field read-out. Rendering happens in physics, with no interpolation.

**Methods:**

- `spawn(request) -> int`, `clear_hostile_in_radius`, `clear_hostile_all`, `targets_in_radius` and `count(faction)` are passthroughs.
- `register_target(target_id, center, radius, on_damage: Callable)`: `field.register_target(...)`, with the callback stored by id.
- On the field's `enemy_hit(target_id, projectile_id, damage)`, call the stored callback's `call(damage)` when `is_valid()`.
- `clear_all()`: clears the field and the callbacks, and resets the previous center to the current one, so a Retry teleport never sweeps across the stage.
- `set_player_invulnerable(active)` and `get_field()`.

**Signals:** `player_hit(projectile_id: int, damage: int)` and `grazed(projectile_id: int)`, re-emitted from the field. Nothing here touches `CombatState` or `RunState`; that is F7-01's job.

**Refused spawns:** the first refusal in a stage produces a `push_warning` with `get_refused_count()`. It warns once, never spams.

`ProjectileRoot` is PAUSABLE, so a paused tree freezes every Projectile without code.

### Dev spray and harness

`DevSpray` is a `Node3D` placed in the arena with an exported `projectile_system`. Every 1.5 s it spawns one horizontal ring of 24 hostile Projectiles at speed 6, which crosses the ship's flight area and dies on the arena's perimeter walls. It is dev only and never in `main.tscn`.

## Tests required

`tests/scene/test_projectile_system_contract.gd`, which builds a test root with a `ProjectileSystem`, the dev meshes and `player_ship.tscn`:

- `test_main_projectile_root_carries_the_projectile_system`
- `test_setup_reads_the_core_and_graze_radii_from_the_ship` (0.18 and 0.55)
- `test_projectile_dies_on_layer_1_scenery` (a `StaticBody3D` box on layer 1 between the spawn point and a far point; the Projectile is never past the box)
- `test_bodies_off_layer_1_do_not_block_projectiles`
- `test_hostile_projectile_hits_the_ship_core_once`
- `test_projectile_passing_the_graze_volume_reports_one_graze`
- `test_invulnerable_player_is_not_hit`
- `test_registered_target_receives_damage_through_its_callback`
- `test_a_target_that_stops_registering_is_not_hit`
- `test_clear_all_removes_every_projectile_and_render_instance`
- `test_render_instances_follow_the_field_counts`
- `test_ship_combat_volumes_keep_monitoring_off` (ADR-0004)

New cases in `tests/scene/test_game_session_flow.gd`: `test_projectiles_freeze_while_paused`, `test_restart_and_return_to_menu_clear_every_projectile`, and `test_stage_load_sets_up_the_projectile_system`.

Grep the output for `SCRIPT ERROR`. Scene tests need physics frames: await `physics_frame` as the flow test does.

## Out of scope

- Hits into `CombatState`, Graze into `RunState` and score, and defeat (F7-01). The Bomb (F7-02).
- Player shots (F6-03). Enemy registration (F9-02).
- Final Projectile art (Astra). Physics interpolation.
- Profiling real boss patterns (F12-03, F14-02).

## Definition of Done

- `tools/test.ps1` is green with no `SCRIPT ERROR`, every test above exists, and there are no Error-level warnings.
- Verified with `/run`: the dev arena harness shows the rings, they vanish at the walls, and flying through them counts Grazes and hits in the readout. Run headless first, then windowed, then record it in `docs/validation/weapon-rendering.md` with `docs/validation/weapon-rendering-spray.png`. The main menu to Stage 1 flow still works: start, pause, restart, return.
- `docs/engineering/weapon-rendering.md` is written from `TEMPLATE.md`, with the `ProjectileSystem` contract and its Open issues. The GUIDE Section 5 and 6 rows and the `menus-session.md` GameSession contract are updated.
- A handoff log entry, ticket `Status: done` with an Outcome, and the roadmap row.
- One commit: `combat: [shared] add ProjectileSystem on ProjectileRoot`.

## Handoff notes for Astra

- `DamageCore` and `GrazeVolume` stay `monitoring = false`. Their sphere radii are the hit and Graze sizes, so resizing them changes gameplay exactly.
- Projectile visuals are two dev meshes in `scenes/dev/`. For final art, deliver a mesh of radius 1 with one material per faction, sized to the spike's budget. Claude swaps the two exports on `Main/ProjectileRoot`.
- Closed Gate barriers and any solid scenery must be `StaticBody3D` on layer 1 for Projectiles to die on them. Foliage should stay off layer 1 (the F1-05 decision).

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/weapon-rendering/issues/02-projectile-system-adapter.md, then implement that ticket. Use /run to verify the dev spray in the arena harness and the menu-to-Stage-1 flow. Finish with its Definition of Done and commit.
```
