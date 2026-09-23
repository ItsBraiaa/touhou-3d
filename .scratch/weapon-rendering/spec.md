# F6 Weapon and rendering — spec

Status: ready-for-agent
Owner: Claude
Source: ADR-0004 (only the rendering side is left to a measured spike); ENGINEERING_BRIEF Section 4.D "Refinement question", Section 4.E and Section 8 "Profile a dense final-boss encounter"; PLANEJAMENTO Section 4 "Shots, power, and familiars", "Spiritual bomb"; GUIDE Section 5 "Player" and "Main composition", Section 6 rows `player_weapon.gd` and `projectile_system.gd`, Section 13 authored player values; CONVENTIONS "Collision" and "Input actions".

## Goal

Measure how to draw hundreds to thousands of Projectiles on this machine, then put the F5 `ProjectileField` in the running game. `ProjectileSystem` sits on `Main/ProjectileRoot`, ticks the field every physics step, answers its obstacle query with a layer-1 ray, sweeps the ship's authored Core and Graze spheres, calls back registered targets, and draws both factions. The ship then shoots through it. `WeaponModel` decides cadence, Familiar shots and Aim Assist cones per Power Level, and `PlayerWeapon` fires from `Muzzle` and the Familiar anchors toward the Target Lock and feeds the Bomb button to `CombatState`. After F6, holding fire in the dev arena harness hits dev target dummies, Power Level 2 adds two Familiars, and the pieces F7 connects (hits, Graze, the Bomb) all exist.

## Tickets

1. `01-rendering-spike.md` (spike, not parallel-safe: FPS must be measured with nothing else running; time-box 1 h)
2. `02-projectile-system-adapter.md` (adapter)
3. `03-weapon-model-and-player-weapon.md` (core+adapter)

Order: 01, then 02 (also needs F5-03), then 03 (also needs F4-01 and F4-02). None is parallel-safe.

## Cross-feature contracts

- `ProjectileSystem` (F6-02, `scripts/combat/projectile_system.gd`, `class_name ProjectileSystem extends Node3D` on `Main/ProjectileRoot`, script attached in `scenes/main.tscn`). `GameSession`'s export `projectile_root: Node3D` is renamed and retyped to `projectile_system: ProjectileSystem`; the node keeps its name `ProjectileRoot`.
  - `setup(bounds: AABB, player: PlayerController)` on every stage load. It reads the Core and Graze radii from the ship's `DamageCore` and `GrazeVolume` sphere shapes, and clears the field.
  - `clear_all()`, which `GameSession._unload_stage()` now calls instead of freeing `ProjectileRoot`'s children.
  - `spawn(request: ProjectileSpawn) -> int`, `clear_hostile_in_radius(center, radius) -> int`, `clear_hostile_all() -> int`, `targets_in_radius(center, radius) -> PackedInt64Array`, `count(faction) -> int`.
  - `register_target(target_id: int, center: Vector3, radius: float, on_damage: Callable)` every physics tick, with `on_damage = func(damage: int) -> void`, called when a player Projectile hits that sphere.
  - `set_player_invulnerable(active: bool)`.
  - Signals `player_hit(projectile_id: int, damage: int)` and `grazed(projectile_id: int)`.
  - `get_field() -> ProjectileField`, for tests and dev tools only.
  - It ticks after the actors: `process_physics_priority` is higher than theirs, so this tick's registrations and ship position are used. The obstacle query is `PhysicsDirectSpaceState3D.intersect_ray` on layer 1, bodies only.
  - F7-02 adds `damage_targets_in_radius(center: Vector3, radius: float, damage: int) -> int`.
- `WeaponModel` (F6-03, `scripts/combat/weapon_model.gd`, `class_name WeaponModel extends RefCounted`) owns cadence, Familiar count and cadence per Power Level, and the Aim Assist cone. It has no Bomb logic: the rising edge of the Bomb button lives in `CombatState.update_bomb_input()` (F4-01).
- `PlayerWeapon` (F6-03, `scripts/combat/player_weapon.gd`, `class_name PlayerWeapon extends Node` on `PlayerShip/Weapon`).
  - Exports `muzzle: Marker3D`, `familiar_anchors: Node3D`, `camera_rig: CameraRig`, `familiar_scene: PackedScene` (dev), and the shot values.
  - `setup(combat_state: CombatState, projectile_system: ProjectileSystem, targeting: Targeting)` and `set_fire_enabled(enabled: bool)`.
  - Every physics tick it feeds `combat_state.update_bomb_input(held)`. `held` is tracked from `bomb` events in `_unhandled_input`, never from `Input.is_action_just_pressed` (F2-04: B is also `ui_cancel`). A Bomb therefore shows up as `CombatState.bomb_activated()`, with the 2 s Invulnerability already granted by the core, and there is no `bomb_requested` signal.
  - `PlayerController` gains a required export `weapon: PlayerWeapon`, and `set_controls_enabled()` also calls `weapon.set_fire_enabled()`.
- Dev targets: `scenes/dev/target_dummy.tscn` with `scenes/dev/target_dummy.gd` (`TargetDummy`). It is in `targetable`, has a `HitVolume` child on layer 5, registers with `register_target` each tick, and flashes and counts hits.
- Session wiring:
  - F6-02: `projectile_system.setup(bounds, _player)` in `_load_stage`, and `clear_all()` in `_unload_stage`.
  - F6-03: `_player.weapon.setup(_combat_state, projectile_system, _player.targeting)` in `_load_stage`. `_combat_state` is F4-02's.
  - F7 connects `player_hit`, `grazed` and `bomb_activated`.

## Done when

- The spike record names one rendering approach, with FPS and frame time at 300, 1000 and 3000 Projectiles at 1280 × 720, plus the obstacle-query cost.
- F6 tests pass. A Projectile dies on layer-1 scenery in a scene test. The ship's authored spheres drive hits and Graze through the real node. Power Level 1 to 3 changes shots and Familiars. Familiars add no collision volume (ENGINEERING_BRIEF 4.E). One Bomb press spends one Bomb through the real input path.
- In the dev arena harness you can fly, hold fire, lock a dummy and watch the shots converge and the dummy flash, see Familiars at Power Level 2 and 3, and see hostile dev rings die on the arena walls.
- GUIDE Section 6 rows `projectile_system.gd` and `player_weapon.gd` are complete. `docs/engineering/weapon-rendering.md` is written.

## Out of scope

- What a hit, a Graze or a Bomb does in play: F7-01 (`take_hit`, Graze score, defeat, flicker) and F7-02 (clear radius, enemy damage, its visual).
- Pickups (F7-03). Enemies and their patterns (F9). Final Projectile and Familiar art (requested from Astra; `scenes/dev/` placeholders ship).
- Physics interpolation of Projectile visuals.
- Profiling real boss patterns (F12-03 and the F14-02 acceptance record).
- Sound (F13, cut pending the user).
