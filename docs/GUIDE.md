# GUIDE — Godot Scene and Script Integration

**Owners:** Astra — Lead Game Designer and Godot scene author. Claude — Lead Code Engineer and GDScript author.
**Language:** English documentation and code identifiers; Portuguese player-facing UI.
**Status:** Integration contract, version 6. The player/test arena, eight menu layouts, and combat HUD are SCENE_READY; the Stage 1 and Stage 2 areas are SCENE_READY_STATIC. Claude owns the project configuration and `scenes/main.tscn` since F0-03. `scripts/player/player_controller.gd`, `camera_rig.gd` and `targeting.gd` are CODE_READY since F1-02, F1-03 and F1-04, and `PlayerShip` carries real exports instead of handoff metadata; `scripts/ui/interface.gd` and `menu_controller.gd` are CODE_READY since F2-02, and `scripts/session/game_session.gd` since F2-04, so the project plays from the main menu into a static stage and back; the HUD and combat scripts remain explicit placeholders for Claude. See Sections 13–15 for actual files, node paths, and validation limits.

## 1. Working agreement

Astra builds the game's presentation and Godot composition: stages, geometry, model placement, collision shapes, camera rig, lighting, environment, effects, animation setup, interface layouts, audio placement, encounter markers, and Inspector configuration. Astra also creates script placeholders when a scene needs a future attachment and documents their purpose here.

Claude refines engineering details and writes the production GDScript: movement behavior, camera behavior, input processing, targeting, combat, projectiles, enemy AI, progression, checkpoint restoration, menus, settings, audio behavior, and tests. Godot is the engine; Claude is the code lead working in it.

Astra owns what the game looks and feels like and how scenes are assembled. Claude owns how the runtime logic works. Camera placement/framing defaults belong to Astra; following, target lock, collision avoidance, and interpolation logic belong to Claude. Collision shape placement belongs to Astra; collision rules and damage ordering belong to Claude.

This guide is the shared scene-to-code contract. Claude may improve internal architecture with mattpocock skills while preserving the documented scene interface. If a public node name, script path, signal, or Inspector field needs to change, update the contract and coordinate the scene adjustment with Astra rather than silently breaking the scene.

## 2. Reference documents and precedence

- [PLANEJAMENTO.md](PLANEJAMENTO.md): approved product rules and scope.
- [STAGE_DESIGN.md](STAGE_DESIGN.md): encounter progression, rewards, and checkpoint behavior.
- [MODEL_SELECTION.md](MODEL_SELECTION.md): approved models and visual direction.
- [ENGINEERING_BRIEF.md](ENGINEERING_BRIEF.md): engineering risks, invariants, and refinement work.
- [engineering/CONVENTIONS.md](engineering/CONVENTIONS.md): how code is written, tested, committed, and handed off.
- [engineering/ROADMAP.md](engineering/ROADMAP.md): ticket order and status, requests to Astra, and deliverables received from Astra.
- [HANDOFF_LOG.md](HANDOFF_LOG.md): every change to a file owned by the other agent, newest first.
- This guide: ownership, attachment points, exported configuration, runtime messages, and handoff state.

The old Superpowers implementation draft is non-authoritative. Prefer the current design documents and this guide over its candidate paths/signatures. Gameplay decisions remain owned by Astra and the user; technical refinements remain owned by Claude.

## 3. File ownership

| Area | Primary owner | Collaboration rule |
| --- | --- | --- |
| `scenes/` geometry, visuals, layout, markers, materials, and scene-owned visual resources | Astra | Claude requests structural changes or makes an explicitly coordinated integration fix |
| `scripts/`, code-defined resources, tests | Claude | Astra creates a placeholder only before code ownership starts; never overwrites implementation |
| `assets/` selection, materials, VFX, animation presentation | Astra | Claude verifies import/runtime compatibility |
| Stage encounter values and balance, `content/*.tres` values | Astra | Claude supplies validation and interprets the data |
| `project.godot`, `export_presets.cfg`, `default_bus_layout.tres`, autoload registration, input actions, export presets | Claude, since F0-03 | Astra asks for a setting instead of editing it; Claude reports the exact keys changed |
| `scenes/main.tscn` and `scenes/dev/` | Claude | Astra reviews the composition and replaces `scenes/dev/` placeholders with real prefabs through a handoff. `scenes/dev/` holds `arena_harness.tscn` since F1-02, the scene to run while flying; spike and projectile placeholders arrive with F6 |
| Inside any `.tscn`: script attachment, exported values, collision layers, masks, monitoring flags, instancing of Claude's prefabs | Claude | Astra keeps geometry, visuals, layout, markers, materials, and content values in the same file |
| `GUIDE.md` | Shared | Update attachment contracts with every intentional interface change |
| Game design documents | Astra | Claude proposes gameplay changes with technical rationale |
| Engineering/test documentation | Claude | Link results and unresolved issues back to this guide |

Every change to a file owned by the other agent is announced in `docs/HANDOFF_LOG.md`.

Preserve original downloads in `All models/`, `all-sounds/`, and `Music/`. Runtime assets should use selected copies with their texture/buffer dependencies. Never edit the same shared file concurrently.

## 4. Placeholder policy

A placeholder is an explicitly unfinished attachment point, not a fake implementation.

- Astra may create a minimal `.gd` with the correct base class and a comment referring to this guide. Add no empty behavior methods that pretend a system works.
- Attach a placeholder only when the scene remains valid and its purpose is listed here. Otherwise leave the node without a script and document the intended path.
- Once Claude begins a script, Claude owns its contents. Astra edits scene values and presentation instead of replacing script files.
- Do not connect scene signals to missing methods. Claude implements the contract first; then the designated owner wires it.
- Mark each handoff as `PLANNED`, `SCENE_READY`, `SCENE_READY_STATIC`, `CODE_READY`, or `INTEGRATED_VERIFIED` in the table below. `SCENE_READY_STATIC` is a `SCENE_READY` scene that is authored but has no runtime behavior yet. These are project delivery states, not game runtime states.

## 5. Scene composition targets

These node names form the initial integration vocabulary. Finalize each tree when its scene is built and update this guide to match the actual tree.

### Main composition

`scenes/main.tscn` is the project main scene and Claude-owned since F0-03. Actual tree:

, and since F2-04 `player_scene` (`scenes/player/player_ship.tscn`), `stage_scenes` (`stage_01`, `stage_02`) and `stage_flight_bounds` (Stage 1's flight interior) set here.
- `Main/WorldRoot` — Node3D, `process_mode = PAUSABLE`; holds the loaded stage instance and, beside it, the `PlayerShip` the Session spawns at the stage's `PlayerStart` (F2-04). Stops with the tree, and so does everything under it.
- `Main/ProjectileRoot` — Node3D, `process_mode = PAUSABLE`, with `scripts/combat/projectile_system.gd` (`ProjectileSystem`, F6-02) attached in `scenes/main.tscn`; `Main`'s export `projectile_system` points at it. Its two `MultiMeshInstance3D` renderers are created in code as children. Stops with the tree.
- `Main/Interface` — CanvasLayer, `process_mode = ALWAYS`; holds menus and the in-game HUD. Since F2-02 it carries `scripts/ui/interface.gd`, which instances the eight menus and the HUD here once and shows them through `ScreenRouter`; `GameSession` opens the main menu at startup with `interface.show_home(MAIN_MENU)`.
- `Main/Audio` — Node, `process_mode = ALWAYS`; will hold `scripts/audio/audio_controller.gd`.

Systems are connected through Inspector references and composition-time injection; the autoload list stays empty (ADR-0002). Contract test: `tests/scene/test_main_contract.gd`. Audio buses `Master`, `Music`, `SFX` live in `default_bus_layout.tres`; the sixteen gameplay input actions live in `project.godot` (CONVENTIONS "Input actions").

### Player

`scenes/player/player_ship.tscn`:

- `PlayerShip` — CharacterBody3D; attach `scripts/player/player_controller.gd`.
- `PlayerShip/BodyCollision` — CollisionShape3D for scenery collision.
- `PlayerShip/VisualRoot` — Node3D for the imported ship, visual banking, and cosmetic effects.
- `PlayerShip/DamageCore` — Area3D with CollisionShape3D; projectile damage volume.
- `PlayerShip/GrazeVolume` — Area3D with CollisionShape3D; larger proximity volume.
- `PlayerShip/Muzzle` — Marker3D outside the visual banking hierarchy.
- `PlayerShip/FamiliarAnchors` — Node3D with `Left` and `Right` Marker3D children.
- `PlayerShip/Weapon` — Node with `scripts/combat/player_weapon.gd` (`PlayerWeapon`, F6-03) attached; `PlayerShip.weapon` points at it.
- `PlayerShip/Targeting` — Node; attach `scripts/player/targeting.gd`.
- `PlayerShip/CameraRig` — Node3D; attach `scripts/player/camera_rig.gd`; child Camera3D named `Camera3D`.

Astra authors the rig and collision volumes. Claude decides whether the projectile engine uses the Area3D volumes directly or reads their shape geometry for swept collision. The visible core and actual collision must agree. Visual banking must not move the core.

### Stages

`scenes/stages/stage_01.tscn` and `scenes/stages/stage_02.tscn` share this layout:

- `Stage` — Node3D; attach `scripts/progression/stage_director.gd`.
- `Stage/Environment` — sky, lighting, WorldEnvironment, and decoration.
- `Stage/Geometry` — navigable scenery and authored static collisions.
- `Stage/PlayerStart` — Marker3D.
- `Stage/Encounters` — Node3D containing encounter roots named by stable IDs, such as `S1-01`.
- `Stage/Checkpoints` — checkpoint scene instances with stable checkpoint IDs.
- `Stage/RuntimeActors` — Node3D for active spawned enemies and pickups.

Each encounter root holds entry/exit volumes and named spawn markers. These are authored scene elements. Runtime actors must be spawned under `RuntimeActors`, so cleanup cannot delete the authored layout.

### Enemy and boss prefabs

`scenes/enemies/spirit.tscn`, `sentry.tscn`, `tempest_sentinel.tscn`, `lantern_guardian.tscn`, and `storm_guardian.tscn`:

- Root `Enemy` — Node3D; attach `scripts/enemies/enemy_actor.gd` for common enemies or `scripts/enemies/boss_controller.gd` for segmented bosses.
- Child `VisualRoot` — imported model and presentation effects.
- Child `HitVolume` — Area3D and collision shape.
- Child `Emitters` — Node3D with Marker3D children identifying shot origins.
- Child `AnimationPlayer` or an explicitly assigned imported animation reference.

The miniboss reuses the Sentry appearance with enlarged scale and rotating ornaments. It uses two health segments; final bosses use three. Imported clips are selected by actual names, not assumed universal names.

## 6. Script attachment and configuration registry

All fields below are public configuration intentions. Claude chooses safe GDScript types and defaults, then records the final exported fields here before Astra wires a scene. Inject runtime collaborators instead of forcing each script to search the whole scene tree.

| Script path | Attach to | Astra configures | Claude implements |
| --- | --- | --- | --- |
| `scripts/session/game_session.gd` (`GameSession`, CODE_READY F2-04) | Main | Nothing: every export is set in the Claude-owned `scenes/main.tscn` — `world_root`, `projectile_system: ProjectileSystem` (on `ProjectileRoot`, since F6-02), `interface: Interface`, `audio` (required), `player_scene` (required, a `PlayerController` root), `stage_scenes: Dictionary[StringName, PackedScene]`, `stage_flight_bounds: Dictionary[StringName, AABB]` (only for a stage whose scene has no `FlightBounds/Limits` metadata; Stage 1 is X -45..45, Y 0..75, Z -570..35). Every stage root must have `PlayerStart` | Acts on every `Interface.action_requested`: opens screens, starts a Campaign or a Direct Stage (stage and ship under `WorldRoot`, ship at `PlayerStart`, `setup(bounds)`, `RunState.start`, `begin_attempt`, HUD), pauses and resumes on `pause` from the HUD or Pause only (tree, `RunState`, ship controls, Pause overlay with score and Graze), Restart, Return to Menu (unloads the stage and the ship, and `projectile_system.clear_all()`), Quit; `projectile_system.setup(bounds, ship)` on every stage load; ticks Active Time only while the tree runs; refuses and reports a stage without a scene, `PlayerStart` or Flight Volume. Since F11-01 a stage clear freezes the stage under Results (`_on_stage_completed`, `_results_params`), a final stage calls `RunState.advance()` for the one victory, and Results' Menu principal and Créditos work. Since F11-02 Results' Continuar (`continue_campaign`, after Campaign Stage 1 only) advances the Run with the Power Level and score carried and loads Stage 2 at 100 % Health, one Shield and two Bombs (Power Progress starts at 0), and Jogar novamente (`replay_stage`, after a Direct Stage only) starts that stage again as a new Direct Stage Run; both warn and do nothing anywhere else. `get_run_state()`, `get_combat_state()`. Since F7-01 it is also the combat adapter: Core hits to `CombatState.take_hit`, Grazes to `RunState` (1 Graze, `GRAZE_SCORE` 10), Invulnerability mirrored to the `ProjectileSystem` and the ship's blink, excess-Power score to `RunState`, and Defeat (tree, Active Time, controls and `CombatState` paused; the Defeat overlay with `Início da fase`); Since F10-03 `retry` resumes in place from the latest Checkpoint (field cleared, a new ship at its `Respawn` through `_spawn_player`, the one place a ship is bound; the Director restores), and restarts the stage before any Checkpoint; Defeat names the Checkpoint. Since F7-02 a Bomb (`CombatState.bomb_activated`) clears hostile fire within the weapon's `bomb_radius` of the Core, damages the enemies in range once, counts in `RunState.note_bomb_used()` and shows the weapon's `bomb_visual_scene` under `WorldRoot`. Since F10-01 a stage whose root is a `StageDirector` is refused on any `check_setup()` message before anything is unloaded; after the ship's bindings the Session calls its `setup(run_state, combat_state, projectile_system, ship)`, connects `stage_cleared` (deferred) to `RunState.complete_stage()` and `threat_reported` to `Hud.show_threat(side, THREAT_CUE_SECONDS)` (1.0 s), and calls `start_attempt(hash("<stage id>#<attempt>"))` after every `begin_attempt()`. Since F3-04 every ship's `CameraRig` gets the player's camera sensitivity and invert vertical through `apply_settings()` in `_spawn_player`, right after `setup`, and again on every `Settings.changed` of either value, even from Options over Pause (one connection for the Session's life). Since F12-03 the Director's boss signals drive the HUD boss panel, connected once per stage load: `boss_started` to `Hud.show_boss(display_name, phase_count)`, `boss_phase_changed` to `show_attack_cue(attack_display_name, ATTACK_CUE_SECONDS)` (3.0 s, Claude's proposal), `boss_health_changed` to `set_phase_health`, and `hide_boss()` on `boss_defeated`, on Retry and on Restart. Contracts in [engineering/menus-session.md](engineering/menus-session.md), [engineering/damage-pickups.md](engineering/damage-pickups.md), [engineering/stage-director.md](engineering/stage-director.md) and [engineering/settings.md](engineering/settings.md) |

| `scripts/player/player_controller.gd` (`PlayerController`, CODE_READY F1-02) | PlayerShip | **Flight values**: `base_speed` 12.0, `focus_multiplier` 0.45, `edge_margin` 4.0, `max_bank_angle_degrees` 25.0, `bank_smoothing` 8.0. **Feedback** (F7-01): `invulnerability_flicker_hz` 12.0, Claude's proposal. **Weapon** (F6-03, required): `weapon` → `Weapon`. **Scene references** (all required): `visual_root` → `VisualRoot`, `camera_rig` → `CameraRig`, `damage_core` → `DamageCore`, `graze_volume` → `GrazeVolume` | Input, movement, scenery collision, Flight Volume clamp and edge feedback, visual banking, `setup(bounds)`, `set_controls_enabled()`, `reset_to()`; `set_controls_enabled()` also turns the weapon's fire on and off (F6-03); `set_invulnerable_visual(active)` (F7-01: `VisualRoot` blinks at `invulnerability_flicker_hz` while Invulnerable; `CoreVisual`, under `DamageCore`, never blinks); signals `edge_proximity_changed(value)` and `focus_changed(active)`. Since F1-03 `camera_rig` is typed `CameraRig` and the yaw comes from `camera_rig.get_yaw()`; the stored `NodePath` is unchanged. Contract in [engineering/player-flight.md](engineering/player-flight.md) |
| `scripts/player/camera_rig.gd` (`CameraRig`, CODE_READY F1-03) | CameraRig | **Scene references**: `camera` → `Camera3D` (required). **Framing**: `follow_distance` 8.5, `follow_height` 3.2, `default_pitch_degrees` -9.0, `pitch_limits_degrees` (-60, 35). **Orbit**: `orbit_speed_degrees` 120.0, `sensitivity` 1.0, `invert_vertical` false. **Damping**: `position_damping` 10.0, `rotation_damping` 8.0, `lock_blend_speed` 4.0. **Obstruction**: `obstruction_margin` 0.4, `collision_mask` layer 1. The `Camera3D` node's own FOV, near and far stay Astra's; its transform is written by the rig every frame | Follow with a level horizon, orbit from the `camera_*` actions, Target Lock framing through `set_lock_target()` / `clear_lock_target()`, obstruction shortening, `apply_settings()` (called by the Session at spawn and on change, F3-04: the scene's `sensitivity` and `invert_vertical` are overwritten by the player's settings, so the orbit rate is tuned with `orbit_speed_degrees`), and `get_yaw()`. **The yaw lives in the `CameraRig` node's own `global_rotation.y`**, which `get_yaw()` returns: turning that node turns where the ship's forward flies. The rig sets `top_level` on itself in `_ready`, which is what keeps the banking body out of the camera |
| `scripts/player/targeting.gd` (`Targeting`, CODE_READY F1-04) | Targeting | **Scene references**: `camera` → `../CameraRig/Camera3D` (required). **Selection**: `max_distance` 60.0, `max_screen_radius` 0.85 (the acquisition area, in half-screen units per axis: 1.0 reaches the edges), `occlusion_mask` layer 1, `group_name` `targetable`. The four selection values are Claude's proposals, left at their defaults and yours to tune. Every target is a `Node3D` in the group with a `HitVolume` child | Each physics tick describes every group member to the `TargetSelector` Rules Core (screen position, distance from the ship, one occlusion ray from the camera to its `HitVolume`); `lock_target` toggles acquire/release, `next_target` switches left to right on screen; a lock is dropped when its target disappears or leaves range, never for occlusion. Signal `target_changed(target: Node3D)`, null on release; `get_current_target()`. The ship (`PlayerController`, new required export `targeting` → `Targeting`) connects it to its `CameraRig` once. Contract in [engineering/player-flight.md](engineering/player-flight.md) |
| `scripts/combat/player_weapon.gd` (`PlayerWeapon`, CODE_READY F6-03) | `PlayerShip/Weapon` (wired in `player_ship.tscn`) | **Scene references** (required): `muzzle` → `../Muzzle`, `familiar_anchors` → `../FamiliarAnchors` (with `Left` and `Right` markers), `camera_rig` → `../CameraRig`, `familiar_scene` (dev `scenes/dev/familiar.tscn` until D-02; a `Node3D` root with no `CollisionObject3D`). **Shots**: `shot_speed` 60, `shot_lifetime` 1.2, `shot_radius` 0.15, `shot_damage` 1, `familiar_shot_damage` 1. **Cadence and Aim Assist**: `main_interval` 0.1, `familiar_interval_level_2` 0.25, `familiar_interval_level_3` 0.15, `main_assist_degrees` 10, `familiar_assist_degrees_level_2` 10, `familiar_assist_degrees_level_3` 20, `lock_assist_degrees` 25 (F6-04: the main cone under a Target Lock, measured from the camera; Familiar cones widen by the same margin). All Claude's proposals, yours to tune. **Bomb** (F7-02): `bomb_radius` 10.0, `bomb_damage` 20, `bomb_visual_scene` (dev `scenes/dev/bomb_blast.tscn`, a `BombBlast` root, until D-02) | `setup(combat_state, projectile_system, targeting)`, `set_fire_enabled(enabled)`. Holding `fire` spawns player Projectiles through the `WeaponModel` cadence from `Muzzle` and, from Power Level 2, the two Familiar anchors, rotated by the camera yaw, toward the view's center at the lock's depth, bent onto the locked target's `HitVolume` inside each shot's Aim Assist cone, measured from the camera under a lock (F6-04). Two top-level Familiars follow the anchors with a small orbit. The `bomb` button is tracked from events and fed to `CombatState.update_bomb_input()` once per tick. It ticks at physics priority 50, after the actors and before the ProjectileSystem. Contract in [engineering/weapon-rendering.md](engineering/weapon-rendering.md) |
| `scripts/combat/projectile_system.gd` (`ProjectileSystem`, CODE_READY F6-02) | `Main/ProjectileRoot` (attached in the Claude-owned `scenes/main.tscn`) | Nothing to wire. **Visuals**: `player_projectile_mesh` and `hostile_projectile_mesh`, meshes of radius 1 (dev spheres in `scenes/dev/` until D-02; Claude swaps them). **Field**: `capacity` 2048, `cull_margin` 5.0, `obstacle_mask` layer 1 (Claude's proposals). `DamageCore` and `GrazeVolume` must stay `SphereShape3D` with monitoring off: their radii are the hit and Graze sizes | Ticks the `ProjectileField` after the actors (`process_physics_priority` 100), a layer-1 bodies-only ray as the obstacle query, the ship's Core and Graze spheres swept every tick, `register_target(id, center, radius, on_damage)` callbacks, one `MultiMeshInstance3D` per faction; `setup(bounds, player)`, `clear_all()`, `spawn`, `clear_hostile_in_radius`, `clear_hostile_all`, `targets_in_radius`, `damage_targets_in_radius` (F7-02, the Bomb's damage, once per target), `count`, `set_player_invulnerable`; signals `player_hit(projectile_id, damage)` and `grazed(projectile_id)`. Contract in [engineering/weapon-rendering.md](engineering/weapon-rendering.md) |
| `scripts/combat/pickup.gd` (`Pickup`, CODE_READY F7-03) | Pickup prefab root `Area3D`: `collision_layer` 0, `collision_mask` 2 (the player body), `monitoring` on, `monitorable` off, a `CollisionShape3D` child, and a `Visual` `Node3D` child. Dev prefabs `scenes/dev/power_pickup.tscn` and `shield_pickup.tscn` instance D-02's `scenes/combat/visuals/*_pickup_visual.tscn` as `Visual` | `kind` (`POWER` or `SHIELD`, fixed per prefab), `attraction_range` (6.0) and `attraction_speed` (14.0), both Claude's proposals; the `Visual` scene, whose shape and color must differ between the kinds. Keep the root contract; no amount (one Pickup is one collect call) | `setup(pickup_id, combat_state, player)` by the spawner after `add_child` (inert before, or after a bad setup, which is reported). Accepted once, on contact with the player body, through `CombatState.collect_power_pickup()` or `collect_shield_pickup()`; a Shield Pickup is refused and stays while shielded, and is taken on the first tick after the Shield breaks. Drifts toward the player within range while takeable. `accepted(pickup_id, kind, score_awarded)` once, then frees itself. Contract in [engineering/damage-pickups.md](engineering/damage-pickups.md) |
| `scripts/enemies/enemy_actor.gd` (`EnemyActor`, CODE_READY F9-02) | Common enemy root `Enemy` (dev: `scenes/dev/spirit.tscn`, `sentry.tscn`) | **Scene references** (all required): `visual_root` → `VisualRoot` (your visual scene instance), `hit_volume` → `HitVolume` (`Area3D`, layer 16, mask 0, monitoring and monitorable off; its first `CollisionShape3D` holds a `SphereShape3D` whose radius is the hit radius, and the `HitVolume` node's own position is the hit center), `emitter` → `Emitters/Main` (`Marker3D`). No group in the scene. **Values** live in the `EnemyDefinition` the Director passes (`content/enemies/*.tres`, patterns in `content/patterns/*.tres`): health, score, `anticipation_seconds`, pattern, `attack_interval`, movement, `move_speed`, `move_range`. Dev proposals: Spirit radius 1.0, Sentry 0.9, both at the root origin | `spawn_setup(definition, enemy_id, encounter_id, rng, projectile_system, player, bounds) -> bool` after `add_child` under `RuntimeActors` (argument errors are reported, the actor stays inert and it returns false for the caller to free it); each physics tick at priority 0 ticks the `EnemyModel`, copies its position, spawns its hostile Projectiles and registers the `HitVolume` sphere with `take_damage` as `on_damage`; joins `targetable`; a dev scale pulse of `VisualRoot` over each Anticipation; signals `threat_reported(side: int)` (-1 left, +1 right, when an attack starts off-screen) and `defeated(enemy_id, encounter_id)` once, then `queue_free()`; `get_health()`, `static threat_side(camera_transform, point)`. `set_engaged(false)` holds dormant Guards without disabling hit registration; `damaged(enemy_id)` reports accepted hits. Score is the Director's. Contract in [engineering/enemies.md](engineering/enemies.md) |
| `scripts/enemies/boss_controller.gd` (`BossController`, CODE_READY F12-02) | Final boss or miniboss root `Enemy` (dev: `scenes/dev/dev_boss.tscn`; `scenes/enemies/lantern_guardian.tscn` since F12-03, with D-03's four clips set; `tempest_sentinel.tscn` by F12-06, `storm_guardian.tscn` by F12-07) | **Scene references** (required): `visual_root` → `VisualRoot`, `hit_volume` → `HitVolume` (`Area3D`, layer 16, mask 0, monitoring and monitorable off; the node's position is the hit center, the `SphereShape3D` in its first `CollisionShape3D` gives the radius), `emitter` → `Emitters/Main`. **Animation** (optional): `animation_player` → `VisualRoot/Model/AnimationPlayer`, `idle_clip`, `step_clip`, `phase_clip`, `defeat_clip` (`StringName`, empty means no cue; D-03 and D-04 chose `Flying_Idle`, `Punch`, `Yes`, `Death`). Phases, Attacks and names live in the `BossDefinition` the Director passes | `spawn_setup(definition, enemy_id, encounter_id, rng, projectile_system, player, bounds) -> bool` as for `EnemyActor`; clips checked by `has_animation()` (a missing one is warned once and skipped); each physics tick at priority 0 hovers the boss (0.6-unit bob, placeholder), ticks the `BossMachine` from `Emitters/Main`, spawns its Projectiles and registers the `HitVolume` sphere; clears every hostile Projectile when a Phase is depleted; signals `boss_started(display_name, phase_count)`, `phase_changed(phase_index, attack_name)`, `phase_health_changed(phase_index, ratio)`, `threat_reported(side)`, `defeated(enemy_id, encounter_id)` once, then frees itself after `defeat_clip`; `get_score()`. The Stage Director connects them before `spawn_setup` and re-emits the fight for the HUD (F12-03). Contract in [engineering/bosses.md](engineering/bosses.md) |
| `scripts/progression/stage_director.gd` (`StageDirector`, CODE_READY F10-01, attached to Stage 1 and Stage 2) | Stage | Nothing on Stage 1: Claude sets `stage_definition` (`content/stages/stage_01/stage_01.tres`), `actor_scenes` by Wave kind (`spirit`, `sentry`, and `lantern_guardian` → `scenes/enemies/lantern_guardian.tscn`), `enemy_definitions` (`spirit`, `sentry`), `boss_definitions` (`lantern_guardian` → `content/bosses/lantern_guardian.tres`, since F12-03), `power_pickup_scene`, `shield_pickup_scene` and `reward_spread` (1.5). Keep the `Encounters/<ID>/{EntryVolume,ExitVolume,Spawns,RewardOrigin,ShieldPickup}` and `RuntimeActors` names; `monitoring` stays off in the file. For the shrine lighting on the boss's defeat, author an `AnimationPlayer` in the stage and tell Claude its path and clip: Claude sets `defeat_presentation` and `defeat_animation` (empty until D-07) | `check_setup()` before loading; `setup(...)` arms the volumes (deferred `body_entered`) and the `EncounterMachine`; `start_attempt(seed)` begins S1-01; spawns Waves and reward Pickups under `RuntimeActors`, scores each defeat once, relays `threat_reported`, `pickup_accepted` and `stage_cleared`; `get_active_encounter_bounds()`. Since F10-02: `gate_opened` clears hostile fire then opens the `Gate`; each `Checkpoint` is armed and its first valid entry clears hostile fire, then activates through the Director's own `CheckpointStore` (refill, commit, Snapshot) and emits `checkpoint_activated(checkpoint_id)`; `guard_links` (Claude sets `S1-04/Wave1_Sentry1..3` → `Environment/PortalLinks/GuardLink1..3`) hide as their guards die; `_apply_progress()` sets every Gate and link from the machine. Since F10-03: `retry_from_checkpoint(ship, seed)` removes the failed Attempt's actors and Pickups, restores the latest Snapshot through the store and reapplies progress (false before any Checkpoint); `get_respawn_transform()` and `retry_location_name()`. Since F12-03 a Wave kind in `boss_definitions` spawns a `BossController` (`spawn_setup` with its `BossDefinition`), whose fight is re-emitted as `boss_started(display_name, phase_count)`, `boss_phase_changed(phase_index, attack_display_name)`, `boss_health_changed(phase_index, ratio)` and `threat_reported`; its one defeat emits `boss_defeated(boss_id)` (the `BossDefinition.kind`), plays `defeat_animation` on `defeat_presentation` when set, then scores `get_score()` and reports it to the machine, so S1-07 completes from the final Phase only; `check_setup()` refuses a kind in both dictionaries, a boss Definition that fails `validate()` or names another kind, and a half-set defeat presentation or one whose clip its player lacks. Stage 2 adds `portal_lights`, `resolved_light_material`, `activate_checkpoint_on_entry = true`, Seal/Guard setup and per-Seal rewards (F12-05). Contract in [engineering/stage-director.md](engineering/stage-director.md) |
| `scripts/progression/checkpoint.gd` (`Checkpoint`, CODE_READY F10-02; on Stage 1 CP1-A/CP1-B and Stage 2 CP2-A/CP2-B) | Checkpoint root `Area3D` (layer 0, mask 2, `monitoring` off in the file) with a `Collision` child and a `Respawn` `Node3D` | `checkpoint_id` (Claude sets `&"CP1-A"`, `&"CP1-B"`; it must match the `CheckpointDefinition`), the activation volume, `Respawn`'s placement and facing; visual and audio cues react to `StageDirector.checkpoint_activated` | `signal entered(checkpoint_id)` for a `PlayerController` body only; `set_armed(armed)` (deferred `monitoring`); `get_respawn_transform()`. No rule: the Director validates the preceding completion and activates once |
| `scripts/progression/gate.gd` (`Gate`, CODE_READY F10-02; on Stage 1 Gate_S1_02..05 and Stage 2 Gate_S2_01..05) | Gate root `Node3D` named by the Encounter's `gate_id`, with `BarrierBody/Collision` (layer 1, full route span) and `ClosedVisual`; `Arch` is scenery | The barrier shape, `ClosedVisual` and `Arch` | `set_open(open)`, idempotent: deferred `disabled` on the barrier collision and `ClosedVisual` hidden while open; optional `OpenVisual` shown while open; `is_open()`. Starts closed, as authored |
| `scripts/progression/seal.gd` (F9-03/F12-05) | Stage 2 `Encounters/S2-03/Seals/Seal1..3` | `seal_id`, `health`, `shield_visual`, `core_visual`, `hit_volume`, `approach_volume`, `guard_links`; keep GuardLinks guard_spawn metadata | Director calls setup once; guarded vulnerability, one-time destruction, pair engagement on approach or hit; one Power reward per Seal |
| `scripts/ui/interface.gd` (`Interface`, CODE_READY F2-02, F3-02) | `Main/Interface` | Nothing: the node lives in the Claude-owned `scenes/main.tscn`, where `menu_scenes` holds the eight menus and `hud_scene` the HUD. `settings_path` (F3-02) stays at its default `user://settings.cfg`; tests inject a temp path | Instances the eight menus and the HUD once, drives them through `ScreenRouter` (show, hide, initial focus on entry, remembered focus on return), resolves Back: `ui_cancel` and Back buttons return to the caller, request `resume` on Pause and `back_refused` where there is nowhere to go, and are left to the Session over gameplay. Since F3-02 it owns the one `Settings` (read once at boot) and adds a code-built `OptionsScreen` under the Options root, which binds the eight Section 14 widgets, applies the volume buses and the window, and saves after each explicit change; Defaults (`restore_defaults`) is resolved here and never reaches the Session. Since F3-03 it owns the one `InputDeviceState`: `_input` notes every device event, every menu's keyboard footer follows the prompts it reports, and a controller disconnected while the HUD is on top (any mode but Teclado) injects a `pause` action. Signal `action_requested(action, payload)` for every other menu action; `show_home`, `show_screen`, `push_overlay`, `back`, `current_screen`, `is_gameplay_covered`, `get_hud`, `get_settings`. Contracts in [engineering/menus-session.md](engineering/menus-session.md) and [engineering/settings.md](engineering/settings.md) |
| `scripts/ui/menu_controller.gd` (`MenuController`, CODE_READY F2-02) | Menu scene root Control (all eight, already attached) | Nothing in the Inspector. Keep the root names and every Section 14 button path, plus `Layout/Score`, `Layout/RetryLocation`, `Layout/Heading`, `Layout/NavigationHint` and, since F11-01, Results' `Layout/TimeValue`, `ScoreValue`, `GrazeValue` and `BombsValue`: they are load-bearing, and renaming one needs a matching code change announced in the handoff log. Tree order sets the initial focus | Identifies its screen from the root name, connects the registry buttons by path to `action_requested(action, payload)`, focuses the first focusable control on entry or the remembered one on return, writes Pause's score and Graze, Defeat's retry location (the Checkpoint's `display_name`) and Results' mode (Continue or Replay or neither, heading, focus loop) and, since F11-01, its four values (`clear_time` as `M:SS`, seconds floored; `score`, `graze`, `bombs_used`; a missing one shows `—`), and shows or hides the keyboard footer on `set_keyboard_prompts(shown)`, which `Interface` calls on every menu (F3-03; no menu tracks devices itself) |
| `scripts/ui/hud.gd` (`Hud`, CODE_READY F4-02, F4-03) | HUD scene root Control (`scenes/ui/hud.tscn`, already attached) | **Presentation**: `lit_modulate` (1, 1, 1, 1) for the Shield, Bomb icons and Phase bars; `dim_modulate` (1, 1, 1, 0.25) for a spent Shield or Bomb; `completed_phase_modulate` (1, 1, 1, 0.3) for a Phase at 0. The last two are Claude's proposals, yours to tune. Keep every Section 15 path: `PlayerStatus/*`, `TargetMarker`, `BossStatus`, `BossStatus/BossName`, `BossStatus/Phase1`..`Phase3`, `AttackName`, `ThreatLeft`, `ThreatRight` are load-bearing, and renaming one needs a matching code change. With two Phases `Phase3` is hidden at its authored position | `bind(combat_state, targeting, camera)` (unbinds first, so it never double-connects; renders at once) and `unbind()`; renders Health (bar and `"90%"`), Shield and Bomb icons lit or dim, Power Level, and Power Progress (full at Power Level 3); centers `TargetMarker` on the locked target's projected `HitVolume`, hidden with no lock, a freed target or a target behind the camera. Calls no `CombatState` method but the getters. The Session binds it to each new ship and unbinds it before freeing one. Presentation API for bosses and the Director (F4-03): `show_boss(display_name, phase_count)` (2 or 3, else clamped), `set_phase_health(phase_index, ratio)`, `show_attack_cue(text, seconds)`, `hide_boss()`, `show_threat(side, seconds)` (-1 left, +1 right); cue and threat timers stand still while the tree is paused; `unbind()` clears all of it. Contract in [engineering/combat-hud.md](engineering/combat-hud.md) |
| `scripts/ui/strings.gd` | Optional, code-only: attached to nothing | Nothing | Shared Portuguese player-facing text, created only if menus and HUD start duplicating it |
| `scripts/audio/audio_controller.gd` (`AudioController`, CODE_READY F13-02, attached in F13-03) | `Main/Audio` (Node, `process_mode = ALWAYS`) | **Sound effects**: `event_streams: Dictionary[StringName, AudioStream]` (catalogue id to stream, all non-looping; F13-03 fills it from D-01's `assets/audio/sfx/`), `event_volume_db: Dictionary[StringName, float]` (missing events play at 0), `max_voices` 12 (global cap and pool size), `sfx_bus` `&"SFX"`. **Music**: `music_tracks: Dictionary[StringName, AudioStream]` (empty = every music call is a silent no-op), `music_bus` `&"Music"`, `music_crossfade_seconds` 1.0. All numbers are Claude's proposals | Gates every playback through the `AudioLimiter` core (intervals, per-event and global caps, priority steals), plays the 17 catalogue events on a code-built `AudioStreamPlayer` pool, coalesces the menu sounds (focus from the Viewport, accept from `Interface.action_requested` except `back_refused`, at most one per frame, accept first), `stop_all()` for stage unload and Retry (music untouched), crossfades music with a `create_tween()` Tween that runs while paused and never restarts a stream already playing; loud `_ready` validation, a disabled controller plays nothing. Signal `event_played(event)`; queries `get_current_music()`, `get_active_voice_count()`, `missing_events()`. Contract in [engineering/audio.md](engineering/audio.md) |

Code-only helpers such as combat state, checkpoint storage, encounter resource schemas, and settings persistence are owned by Claude and do not need empty scene-attached scripts. Describe their contracts in engineering documentation and expose only the values needed by Astra in the Inspector.

Rules Cores (ADR-0001) are code-only. They are never attached to a node and never appear in this registry; each one is documented in `docs/engineering/<module>.md`, and the Adapter listed above is what a scene attaches.

## 7. Runtime messages and ownership

Use these semantic event contracts; Claude records final typed signal signatures during implementation. Payload IDs must remain stable across retries.

| Event | Producer → consumer | Minimum payload | Required handling |
| --- | --- | --- | --- |
| Combat state changed | Player combat logic → HUD | Since F4-02: `CombatState.health_changed(health: int)`, `shield_changed(shielded: bool)`, `bombs_changed(bombs: int)`, `power_changed(level: int, progress: int)`, each emitted only on a change with the new value | Display only; HUD does not mutate resources. `Hud.bind` connects the four once per ship and renders the getters at once; `unbind` disconnects them. The Session owns the one `CombatState` and starts it at every stage entry |
| Target changed | Targeting → camera/HUD/weapon | `Targeting.target_changed(target: Node3D)` since F1-04: the locked node, or null on release by the player, by range, or because the target disappeared | Clear all consumers when target disappears. The camera is connected by `PlayerController._ready`; HUD (F4-02) and weapon (F6-03) connect to the same signal |
| Enemy defeated | Enemy → stage director | Since F9-02: `EnemyActor.defeated(enemy_id: StringName, encounter_id: StringName)`, the ids passed to `spawn_setup` | Count once, even if damage callbacks repeat. The actor emits it once (the `EnemyModel` defeats once), after leaving `targetable`, and then frees itself; the Director awards `definition.score` (F10-01). Since F10-01 the Director scores only the first report of an enemy it spawned (`RunState.add_score`), then calls `EncounterMachine.notify_enemy_defeated`; a repeat adds nothing |
| Boss phase changed | Boss → presentation/HUD | Since F12-02: `BossController.boss_started(display_name: String, phase_count: int)`, `phase_changed(phase_index: int, attack_name: String)`, `phase_health_changed(phase_index: int, ratio: float)`, `threat_reported(side: int)`, `defeated(enemy_id, encounter_id)` | Clear old phase threats and show a brief cue. The controller clears every hostile Projectile itself before `phase_changed` (and before `defeated`). Since F4-03 the HUD side is a direct call from the owner (F12-03 wires it): `Hud.show_boss(display_name, phase_count)` on `boss_started`, `set_phase_health(phase_index, ratio)` on `phase_health_changed`, `show_attack_cue(attack_name, seconds)` on `phase_changed`, `show_threat(side, seconds)` on `threat_reported`, `hide_boss()` on `defeated` or unload. The arena harness wires exactly this for the dev boss |
| Seal destroyed | Seal → stage director | Seal ID | Resolve objective once, update linked portal lights |
| Checkpoint entered | Checkpoint → stage director | Checkpoint ID, resume encounter ID. Since F10-02: `Checkpoint.entered(checkpoint_id: StringName)`, connected deferred; the resume id comes from the `CheckpointDefinition` | Validate preceding completion; first activation refills and snapshots. Since F10-02 an entry before `after_encounter_id` completes, or a revisit, does nothing; a first valid entry clears hostile fire, then `CheckpointStore.activate` refills, commits and records the Snapshot, `StageDirector.checkpoint_activated(checkpoint_id)` is emitted, and the resume Encounter begins at once if the ship is already inside its EntryVolume |
| Pickup accepted | Pickup/combat logic → session/audio | Pickup ID, kind, resulting reward. Since F7-03: `Pickup.accepted(pickup_id: StringName, kind: Pickup.Kind, score_awarded: int)`, emitted once just before the Pickup frees itself; ids are `&"<encounter_id>/power_<n>"` and `&"<encounter_id>/shield_<n>"`, n from 1 | Remove only on acceptance and prevent duplicate credit. The Pickup already credited `CombatState`; `score_awarded` (50 for a Power Pickup at Power Level 3, else 0) is informational, because those points reach `RunState` only through `CombatState.score_awarded`. The Stage Director spawns and connects it (F10-01); audio hears it through `StageDirector.pickup_accepted` (F13-03) |
| Player defeated | Player → session | Active stage and attempt context | Stop combat and show Retry/Main Menu. Since F7-01: `CombatState.defeated` (once per life) → `GameSession._on_player_defeated()`, which pauses the tree, Active Time, the controls and the core, and pushes the Defeat overlay; since F10-03 the param is `StageDirector.retry_location_name()` (`Último checkpoint · <name>`, or `Início da fase` before any Checkpoint) and `retry` resumes from that Checkpoint or restarts before one |
| Stage completed | Stage director → session | Stage ID and committed result. Since F10-01: `StageDirector.stage_cleared` (no payload; the Session knows the stage), after the machine's last `encounter_completed` | Campaign continuation or isolated-stage results. The Session connects it `CONNECT_DEFERRED` to `RunState.complete_stage()`, which emits `stage_completed(result)`. Since F11-01 the Session freezes the stage under Results with that result (mode `campaign_stage_1`, `direct_stage` or `final_victory`), ends the Run with its one victory after the last stage of the order, and prints one `STAGE_RESULT` line |
| Pause requested | Input/menu → session | Since F2-04: the `pause` action (Escape, gamepad Start) reaches `GameSession._unhandled_input` over the HUD or Pause; Continuar and `ui_cancel` on Pause arrive as `resume` from `Interface`. Since F3-03 a controller disconnected while the HUD is on top (in any input-device mode but Teclado) makes `Interface` inject the same `pause` action through `Input.parse_input_event` | Freeze world/timers, preserve menu processing. Done by `GameSession`: tree paused, `RunState` paused, ship controls off, Pause overlay; ignored under Options opened from Pause. A disconnect over Pause, Options, Defeat, Results or the menus injects nothing, so it never resumes or starts anything; the keyboard then drives Pause |

Connect each event once. Choose either authored connections or runtime wiring for each connection; do not use both. After restore, reconnect only reconstructed actors and clear references to freed targets.

## 8. Stage data and checkpoint integration

Astra supplies content matching STAGE_DESIGN.md. Claude supplies a validated resource/schema to express it. Required encounter data:

- Stable encounter ID and next encounter ID.
- Activation volume and spawn-marker references.
- Waves with enemy type/count, activation rule, and emitter configuration.
- Completion condition: traversal, all required enemies, or specified objectives.
- One-time power/shield rewards and reachable drop locations.
- Gate references and optional checkpoint/resume ID.

Duration is a balancing target, not a timer that automatically completes an encounter.

Since F10-03, Retry is in place and Restart reloads: Defeat's Retry keeps the stage and its Director, which removes the failed Attempt's runtime actors and Pickups, restores the latest Checkpoint's Snapshot and rebuilds its Gates and links, while the Session clears the field and spawns a new ship at the Checkpoint's `Respawn`. Before any Checkpoint Retry is Restart, and Restart reloads the stage with a new Director and `CheckpointStore`, discarding every Checkpoint ([engineering/stage-director.md](engineering/stage-director.md) "Retry and Restart").

Required checkpoint markers: CP1-A, CP1-B, CP2-A, CP2-B. Keep checkpoint activation physically separate from the next combat trigger. The director owns the snapshot and resource restoration; the checkpoint scene provides a location and feedback.

Astra must provide open 3D space around each boss, clear limits, visible depth references, and safe checkpoint spawns. Claude must restore the correct actors/flags, cancel queued spawns, and preserve committed statistics. Use the detailed retry matrix in STAGE_DESIGN.md.

## 9. Per-scene handoff procedure

0. Before rerunning any `tools/build_*.py` generator over an integrated scene, reconcile it with the scene's current wiring or retire it.
1. Astra assembles a scene and records its actual node tree, referenced assets, placeholder paths, intended behavior, and editable parameters.
2. Astra marks the scene `SCENE_READY` only if it opens with valid resources and no dangling script/signal references. A static scene is not marked playable.
3. Claude reads this guide and the applicable design section, refines internal engineering, and writes the scripts and behavioral tests.
4. Claude records public exported fields, signals, methods, setup prerequisites, and test results. Mark `CODE_READY` only after the code checks pass.
5. Astra attaches scripts, assigns Inspector references, configures content values, and performs visual/playability review. Claude resolves code defects discovered during integration.
6. Mark `INTEGRATED_VERIFIED` only after the actual scene runs with the intended behavior. Record manual checks separately from automated ones.

For shared scenes or project settings, announce the files being edited to the collaborator before starting. Do not create separate tasks or dispatch agents automatically as a consequence of this document.

## 10. Handoff tracking

| Deliverable | Scene owner | Code owner | State | Evidence |
| --- | --- | --- | --- | --- |
| Foundation and conventions | Claude | Claude | CODE_READY | F0 done: repository hygiene, `tools/godot.*` and `tools/test.*`, project configuration, input actions, audio buses, export preset, and this contract. The export run itself is blocked on missing export templates; [engineering/ROADMAP.md](engineering/ROADMAP.md) |
| Main composition and session | Claude (`scenes/main.tscn`, F0-03) | Claude | CODE_READY | Composition root instanced headless by `tests/scene/test_main_contract.gd`; since F2-04 `GameSession` starts a Campaign or Direct Stage 1 or 2 from the menus, spawns the ship at `PlayerStart` inside the stage's Flight Volume, pauses (tree, Active Time, controls), resumes, restarts, returns to the menu and quits: 20 flow tests in `tests/scene/test_game_session_flow.gd`, sixteen mutants caught, and the scripted keyboard and gamepad flight pass in [validation/menus.md](validation/menus.md) (`menus-flight.png`, `menus-pause-return.png`). Stage completion and Defeat since F10; Results since F11-01; Continuar into Campaign Stage 2 with Power and score carried, Jogar novamente and the Direct Stage entry values since F11-02 ([validation/run-flow.md](validation/run-flow.md)); the physical keyboard and pad pass is owed |
| Player/camera test arena | Astra | Claude | SCENE_READY | Both scenes load and render in Godot 4.7.2; the camera is driven by `CameraRig` since F1-03; Section 13 |
| Player flight | Astra: ship, arena and Flight Volume | Claude | CODE_READY | F1-01 `FlightModel`, F1-02 `PlayerController`, F1-03 `CameraRig` and F1-04 `TargetSelector` + `Targeting`: the ship flies the arena, stops at the walls and the platform, banks visually, reports edge proximity; the camera follows, orbits, frames a Target Lock and shortens against scenery; the lock acquires near the screen center, switches left to right, and releases by press, range or target loss while surviving occlusion. 64 tests plus measured flight, camera and targeting in [validation/player-flight.md](validation/player-flight.md); a physical keyboard and controller pass is still pending |
| Player combat and projectiles | Astra: presentation | Claude | PLANNED | Product rules documented |
| Common enemies and miniboss | Astra | Claude | CODE_READY (F12-06) | F9-01 `EnemyModel` and F9-02 `EnemyActor` drive common Spirits and Sentries. The Tempest Sentinel in S2-04 uses Astra's `tempest_sentinel.tscn` with `BossController`, two Phases and the `Flying_Idle`, `Punch`, `Yes`, `Death` clips; its final defeat awards 500, drops the Shield and opens the Gate. Numeric content awaits D-06 pass 3. |
| Lantern Guardian | Astra | Claude | CODE_READY (F12-03) | D-03's `scenes/enemies/lantern_guardian.tscn` carries `BossController` with the `Flying_Idle`, `Punch`, `Yes` and `Death` clips; `content/bosses/lantern_guardian.tres` (dev: Phases 1500 / 1500 / 2100, score 1000) spawns at S1-07's `Wave1_Boss1` behind CP1-B, shows the HUD boss panel with three bars and each Attack cue, and its final-Phase defeat clears S1-07 and the stage once. The shrine lighting on `boss_defeated` waits for Astra's `AnimationPlayer` (D-07); [engineering/bosses.md](engineering/bosses.md) |
| Storm Guardian | Astra | Claude | PLANNED | Dragon_Evolved selected; animation metadata inspected |
| Stage 1 area | Astra | Claude | SCENE_READY_STATIC | Encounters, gates, checkpoints and spawn markers authored; no runtime behavior; [STAGE_01_HANDOFF.md](STAGE_01_HANDOFF.md) |
| Stage 1 progression | Astra | Claude | CODE_READY (F10-01, F10-02) | Since F10-01 Stage 1's Encounters play: S1-01 on entry, Waves spawn and fire, defeats score once, rewards drop. Since F10-02 the whole route plays: Gates open as Encounters clear, CP1-A and CP1-B activate once, and, since F12-03, the Lantern Guardian's final-Phase defeat clears S1-07 and the stage. Retry arrives with F10-03 |
| Stage 2 area | Astra | Claude | SCENE_READY_STATIC | Seven encounters, three guarded seals, two checkpoints authored; no runtime behavior; [STAGE_02_HANDOFF.md](STAGE_02_HANDOFF.md) |
| Stage 2 progression | Astra | Astra (sol) | CODE_READY F12-05 | Director, five Gates, three Seals and CP2-A/CP2-B wired; bosses remain Sentry stand-ins pending F12-06/F12-07 |
| Checkpoints/gates/seals | Astra | Claude | CODE_READY (F10-02, Stage 1 Gates and Checkpoints) | Stage 1's four Gates open as their Encounters complete, CP1-A and CP1-B activate once and arm S1-05 and S1-07, and the S1-04 PortalLinks hide with their guards. Retry restore in F10-03; Stage 2 Seals, five Gates, checkpoints and entry fallback integrated by F12-05 |
| Menus/options | Astra | Claude | CODE_READY | Eight menu scenes rendered and checked; Section 14. Navigation wired by F2-02 — registry buttons, focus on entry and return, Back, runtime text, footer — with 26 scene tests; since F2-04 every Main Menu, Stage Select and Pause action does what Section 14 says (start, Options from Pause without unpausing, resume, restart, return, quit), verified by the flow tests and the scripted keyboard and gamepad pass in [validation/menus.md](validation/menus.md). Settings since F3; every Defeat, Results and Pause button since F11-01 and F11-02 (Results' four values bound, Continuar, Jogar novamente, the final victory's `Jornada concluída`), verified in [validation/run-flow.md](validation/run-flow.md); physical-device pass owed |
| Combat HUD | Astra | Claude | SCENE_READY | Normal and synthetic boss states rendered at 1280 × 720; Section 15; gameplay binding pending |
| Audio integration | Astra: selection/mix | Claude: runtime | PLANNED | Sound packs found; event mapping not selected |

## 11. Completion checks for collaboration

- Every attached script has the expected base type and a documented purpose.
- Required Inspector references are assigned; missing references produce a useful setup error instead of silent failure.
- Scene node names and script expectations agree; scene-owned references are not hidden in arbitrary absolute node paths.
- Models/materials retain valid dependencies; effects do not obscure the player core or dodge gaps.
- Camera rig placement and code framing are tested together on keyboard and gamepad.
- Signal connections do not duplicate after retry or stage changes.
- Scene cleanup removes transient gameplay objects while preserving authored geometry and markers.
- Both source specs' acceptance criteria remain the final product tests.

## 12. Prompt for Claude

> Act as Lead Code Engineer for this Godot project. Astra is Lead Game Designer and owns the authored scenes, environments, camera composition, models, effects, UI layout, and Inspector content. Read GUIDE.md first, then the linked game/stage specifications and ENGINEERING_BRIEF.md. Use applicable mattpocock skills to refine internal engineering and implement production GDScript. Preserve the documented scene interfaces or coordinate any necessary contract changes in GUIDE.md before changing them. Implement only the scene/script handoff currently assigned to you, with behavioral tests and exact setup instructions for Astra. Do not rebuild the visual design or overwrite scene work without coordination. Keep engineering documentation in English and player-facing text in Portuguese.

## 13. First scene handoff — player and static arena

### Delivered files

- `scenes/player/player_ship.tscn`: reusable player scene matching the player tree in Section 5.
- `scenes/tests/combat_arena.tscn`: directly runnable static scene; open it directly (F6) for scene testing. The project main scene is `scenes/main.tscn` since F0-03.
- `assets/models/player/craft_speederA.glb`: selected copy of the approved ship, with embedded materials.
- `scripts/combat/player_weapon.gd`: base type and handoff comments only. No aiming, firing or combat logic is implemented. The other three placeholders delivered with it are now Claude's: `scripts/player/player_controller.gd` is `PlayerController` (F1-02), `camera_rig.gd` is `CameraRig` (F1-03), and `targeting.gd` is `Targeting` (F1-04).
- `ASSET_CREDITS.md` and `assets/licenses/kenney-space-kit.txt`: selected asset provenance.
- `docs/validation/first-scene.md`, logs, and `arena-preview.png`: verification evidence.

The arena is a functional scene blockout for later gameplay integration, not either finished stage. It contains a circular stone platform, depth grid, shrine gate, perimeter lanterns, geometric trees/mountains, and targets at three heights. No tutorial text or fake HUD is displayed.

### Actual arena tree

`CombatArena` contains `Environment`, `Geometry`, `FlightBounds`, `Targets`, `PlayerStart`, the instantiated `PlayerShip`, `RuntimeActors`, and `ProjectileRoot`.

`Targets/Low`, `Targets/Middle`, and `Targets/High` are Node3D members of the `targetable` group. Each contains `Orb`, `Ring`, and `HitVolume/Collision`. Their world positions are (-10, 5, -8), (0, 9, -20), and (11, 15, -10). They are static targeting references, not damageable enemies. Target IDs are stored as metadata.

`PlayerStart` and the initial ship position are (0, 6, 18). World up is +Y; forward is -Z. The platform is centered at (0, 0, -6) with radius 39. FlightBounds metadata `min_corner` (-39, 0, -45) and `max_corner` (39, 30, 33) is the Flight Volume, with perimeter and ceiling collision surfaces. Since F1-02 an owner reads that metadata and passes `AABB(min, max - min)` to `PlayerController.setup()`: the position clamp and the `edge_proximity_changed` feedback are the playable-volume limit, and the authored walls stop the body first everywhere except below the platform rim. The circle still does not fill the corners of the rectangle, so past the rim the clamp holds the ship at y 0 over open void with the feedback at 1.0; whether that reads acceptably is Astra's call ([validation/player-flight.md](validation/player-flight.md)).

### Authored player values

| Item | Current value / wiring |
| --- | --- |
| Body collision | Box 2 × 0.8 × 2.1, centered on PlayerShip |
| Damage core | Sphere radius 0.18; visible sphere matches this radius |
| Graze volume | Sphere radius 0.55 |
| Imported model offset | VisualRoot/Model position (-2, -0.4, -1.5), compensating embedded model translation |
| Visual orientation | Nose faces -Z; bank VisualRoot only |
| Muzzle | (0, 0, -1.25), separate from banked visuals |
| Familiar anchors | (-1.6, 0.25, 0.1) and (1.6, 0.25, 0.1). Since F6-03 the Familiars sit here from Power Level 2 (the dev `scenes/dev/familiar.tscn`, swap pending D-02), orbit 0.3 around the anchor once per second, and fire from the anchor point |
| Camera | CameraRig/Camera3D authored at (0, 3.2, 8.5), X rotation -0.16 radians, FOV 68°, near 0.1, far 500. Since F1-03 that transform is the documented rest pose and the `CameraRig` script reproduces it from its own exports — `follow_distance` 8.5, `follow_height` 3.2, `default_pitch_degrees` -9.0 (the export form of -0.16 rad) — and rewrites the camera's transform every frame. FOV, near and far are still read from the node |
| Camera framing and feel | `CameraRig` exports: `pitch_limits_degrees` (-60, 35), `orbit_speed_degrees` 120.0, `sensitivity` 1.0, `invert_vertical` false, `position_damping` 10.0, `rotation_damping` 8.0, `lock_blend_speed` 4.0, `obstruction_margin` 0.4, `collision_mask` layer 1. All Claude's proposals except the two framing values above; tune them in the Inspector |
| Movement values | PlayerShip exports since F1-02: `base_speed` 12.0, `focus_multiplier` 0.45, `edge_margin` 4.0, `max_bank_angle_degrees` 25.0, `bank_smoothing` 8.0. The `metadata/base_speed` and `metadata/focus_multiplier` handoff entries were removed |
| Body wiring | Claude's, since F1-02: `motion_mode` floating, collision layer 2, mask 1, no gravity |
| Rendering | Existing Forward Plus/D3D12 retained; viewport 1280 × 720, 4× MSAA |

The Inspector values now drive behavior: they are read in `_ready` and passed to the `FlightModel` core. `edge_margin`, `max_bank_angle_degrees` and `bank_smoothing` are Claude's proposals awaiting Astra's tuning; `base_speed` and `focus_multiplier` are pinned to 12.0 and 0.45 by `tests/scene/test_player_ship_contract.gd`, so a deliberate change to those two needs the test updated with it. Renaming `VisualRoot`, `CameraRig`, `DamageCore` or `GrazeVolume` breaks a required reference and the ship refuses to move, with the missing field named in the error.

Collision layer allocation: scenery 1; player body 2; damage core 3; graze 4; target hit volume 5. Corresponding bit values are 1, 2, 4, 8, 16. Player body mask is scenery only. Area monitoring is intentionally disabled until Claude selects the projectile/collision strategy; Claude must configure masks/monitoring for the chosen implementation.

The core's unshaded material disables depth testing to make it visible through the ship in this static review. Revisit this presentation during gameplay integration if it incorrectly draws through unrelated geometry. Two teal engine meshes are static visual accents; there is no propulsion animation yet.

### Tools and integration boundaries

`tools/build_scene_handoff.py` was retired by Astra's 2026-09-22 F1 design pass. Its unchanged source is archived as `docs/archive/build_scene_handoff.py.txt`, reference text only. Edit the integrated scenes in Godot; do not restore or execute the archived generator.

Retirement resolves the F1-02/F1-03/F1-04 divergence: the old source omits the PlayerShip exports, `node_paths` markers, `motion_mode`, CameraRig references and Targeting references. The integrated `.tscn` files remain authoritative. Neither scene was regenerated during retirement.

`tools/validate_scene_handoff.gd` is an offline QA script that loads the scene, checks required nodes and imported mesh presence, and captures a rendered preview when a graphics display is available. It is not attached to gameplay nodes and does not implement player behavior.

Source-download folders have `.gdignore` files so Godot imports selected assets instead of every duplicate format. To use another downloaded asset, copy its required dependencies under `assets/` first. The downloaded MP3s are not integrated.

### Next assignment for Claude

Flight, focus movement, the camera and targeting are done (F1-01 to F1-04): normalized three-axis speed, the 45 % Focus factor, the Flight Volume limit with edge feedback, scenery collision, core independence from banking, camera follow and orbit, Target Lock framing at three target heights, camera shortening against scenery, and target acquisition, left-to-right switching, release, loss by range and survival behind the shrine gate are all measured in [validation/player-flight.md](validation/player-flight.md). One of the listed validations is still open: keyboard and physical-gamepad ergonomics were only driven with simulated actions — the host has had a DualSense pad that Godot maps, but nobody has pressed it. Weapon behavior stays with the combat handoff. The authored scene is preserved — only script wiring changed, on the `PlayerShip` root (F1-02, and the `targeting` reference in F1-04), on the `CameraRig` node (F1-03), and on the `Targeting` node (F1-04). The arena's trees have no collision, so they cannot hide a target from targeting; only layer-1 scenery can.

## 14. Menu scene handoff

### State and verification

All eight menu scenes are SCENE_READY and share `assets/ui/menu_theme.tres`. Godot MCP successfully reported the engine/project, created the initial main-menu scene, and ran the authored main menu. Local Godot rendering validated all eight screens and their explicit focus paths with zero reported failures. Screenshots are in `docs/validation/menu-*.png`.

Since F2-02 `scripts/ui/menu_controller.gd` is `MenuController`: every button below requests its action, each screen takes initial focus on entry and gets its focus back on return, Back returns to the caller, the runtime text below is written, and the footer hides while a gamepad is in use (contract in [engineering/menus-session.md](engineering/menus-session.md)). Since F2-04 `GameSession` carries out the Main Menu, Stage Select and Pause actions — start a Campaign or a Direct Stage, pause, Options from Pause, resume, restart, return to the menu, quit. Still not implemented: Retry, Continue and Replay arrive with F11, and since F3-02 the Options widgets show the saved settings and apply the volume buses and the window at boot and on each change, saving after each explicit change and on Defaults (camera and input-device application arrive with F3-04 and F3-03; see [engineering/settings.md](engineering/settings.md) "Options binding").

The project main scene is `scenes/main.tscn`; `Interface` instances all eight menus and the HUD under `Main/Interface` and `GameSession` shows the main menu at startup, so running the project opens it, and Iniciar or a Stage Select card flies the stage. Use F6 on another menu scene to inspect it independently. Menu art is original SVG composition, not a screenshot promising that the playable stages are finished.

### Scene and action registry

All paths below are relative to the named scene root. Every scene has a `Layout` Control; the following button paths are stable.

| Scene / root | Button or control path | Intended action |
| --- | --- | --- |
| `main_menu.tscn` / MainMenu | `Layout/StartButton` | Start campaign at Stage 1 |
| MainMenu | `Layout/StageSelectButton` | Open StageSelect |
| MainMenu | `Layout/OptionsButton` | Open Options, preserving return destination |
| MainMenu | `Layout/QuitButton` | Exit application |
| `stage_select.tscn` / StageSelect | `Layout/ForestCard/SelectButton` | Start isolated Stage 1 |
| StageSelect | `Layout/MountainCard/SelectButton` | Start isolated Stage 2 with specified starting power/resources |
| StageSelect | `Layout/BackButton` | Main menu |
| `options.tscn` / Options | `Layout/Controls/BindingsButton` | Open Controls |
| Options | `Layout/DefaultsButton` | Restore validated default settings and refresh widgets |
| Options | `Layout/CreditsButton` | Open Credits |
| Options | `Layout/BackButton` | Return to caller; retain pause if caller is PauseMenu |
| `controls.tscn` / Controls | `Layout/BackButton` | Return to Options |
| `pause_menu.tscn` / PauseMenu | `Layout/ResumeButton` | Resume the same attempt |
| PauseMenu | `Layout/RestartButton` | Restart stage from stage-entry state |
| PauseMenu | `Layout/OptionsButton` | Open Options without unpausing combat |
| PauseMenu | `Layout/MenuButton` | End run and return to main menu |
| `defeat.tscn` / Defeat | `Layout/RetryButton` | Retry latest checkpoint or stage entry |
| Defeat | `Layout/MenuButton` | End run and return to main menu |
| `results.tscn` / Results | `Layout/ContinueButton` | Continue to Stage 2 after campaign Stage 1; hide for final victory and isolated runs |
| Results | `Layout/ReplayButton` | Replay isolated stage; shares ContinueButton position and is hidden by default |
| Results | `Layout/MenuButton` | Return to main menu |
| Results | `Layout/CreditsButton` | Open Credits while preserving results as return destination |
| `credits.tscn` / Credits | `Layout/BackButton` | Return to caller |

Pause, defeat, and result scenes have a translucent dim layer and central panel, with no embedded gameplay background. Instance them under a CanvasLayer above the current game. Full-screen main/select/options/controls/credits scenes include the authored forest artwork.

### Options values and fields

| Node path in Options | Type | Current display defaults | Runtime responsibility |
| --- | --- | --- | --- |
| `Layout/Audio/MasterVolume` | HSlider | 80, range 0–100, step 1 | Apply Master bus volume; map zero to mute |
| `Layout/Audio/MusicVolume` | HSlider | 65, range 0–100, step 1 | Apply Music bus volume |
| `Layout/Audio/SfxVolume` | HSlider | 80, range 0–100, step 1 | Apply SFX bus volume |
| `Layout/Display/WindowMode` | OptionButton | 0: Janela; 1: Tela cheia | Apply validated window mode |
| `Layout/Display/Resolution` | OptionButton | 0: 1280 × 720; 1: 1600 × 900; 2: 1920 × 1080 | Apply supported size and preserve usable layout |
| `Layout/Controls/InputDevice` | OptionButton | 0: Automático; 1: Teclado; 2: Controle | Switch device preference/prompts with keyboard recovery |
| `Layout/Controls/Sensitivity` | HSlider | 1.0, range 0.2–2.0, step 0.05 | Apply camera sensitivity multiplier |
| `Layout/Controls/InvertVertical` | CheckButton | false | Invert camera vertical input only |

Load validated saved settings into the widgets before accepting change callbacks. Default values are authored starting points. Avoid applying each intermediate widget update as if it were a fresh user edit during load/reset.

### Focus and responsive layout

Every visible action uses real Button/OptionButton/HSlider/CheckButton nodes with keyboard focus enabled, plus explicit focus-next/previous paths for authored widgets. Claude must assign initial focus on screen entry, preserve focus on return, and verify directional gamepad navigation. Hidden ReplayButton must be excluded from the effective result-screen navigation path; rebuild that path for each run mode.

Use the existing `ui_accept`/`ui_cancel` and UI directional actions or document intentional input changes. Intentional change (F2-02): Godot 4.7 binds `ui_accept` and `ui_cancel` to keys only, so `project.godot` adds the gamepad's A to `ui_accept` and B to `ui_cancel`, keeping the default keys. The theme provides hover, pressed, and gold focus borders. The static footer is a keyboard hint; update or hide it when gamepad is active. Do not add tutorial paragraphs.

Layout is authored on a centered 1280 × 720 canvas with a full-viewport background and shared typography. The existing project stretch configuration is retained. Validate alternate resolutions and aspect ratios during functional integration; only the 1280 × 720 visual composition is verified in this handoff.

### Runtime text and presentation

- Defeat: `Layout/RetryLocation` must say `Início da fase` when no checkpoint exists, or identify the latest checkpoint concisely.
- Pause: `Layout/Score` displays committed/current attempt score and graze supplied by session state.
- Results: populate `Layout/TimeValue`, `ScoreValue`, `GrazeValue`, and `BombsValue`. Em dashes in the authored scene indicate data not yet bound, not zero results. Bound since F11-01 (`MenuController.RESULTS_VALUE_PATHS`): Clear Time as `M:SS` with the seconds floored, the others as integers, and a dash only when the Session sent no value. The four labels are load-bearing; announce a rename in the handoff log.
- For final campaign victory, change `Layout/Heading` to `Jornada concluída`, hide both ContinueButton and ReplayButton, and focus MenuButton or CreditsButton.
- Credits currently cover only integrated resources (Kenney ship and original project art). Extend credits when models/audio are integrated rather than claiming unused assets are present.

### Editing and QA tools

`tools/build_menu_handoff.py` is an offline authoring utility, not runtime code. It rewrites all eight menu scenes and shared visual resources. Do not rerun it over Claude's scene integration without reconciling changes first.

`tools/validate_menu_handoff.gd` is an offline QA renderer. It loads scenes, validates focus references and basic label dimensions, and captures screenshots when graphics are available. It does not wire or simulate menu actions and does not prove functional navigation or settings persistence.

## 15. Combat HUD scene handoff

`scenes/ui/hud.tscn` has a Control root named `HUD`, attached to the placeholder `scripts/ui/hud.gd`. Instance it under the gameplay CanvasLayer. `scenes/tests/hud_preview.tscn` composes the static combat arena and HUD for F6 inspection; it is not a playable encounter. The project still starts at `scenes/main.tscn`, which shows the main menu.

All HUD controls ignore mouse input. The player panel anchors to the bottom-left; boss presentation anchors to the top-center. The center remains clear for flight and projectile reading. Only 1280 × 720 composition has been visually verified.

| Path relative to HUD | Authored state | Claude's binding responsibility |
| --- | --- | --- |
| `PlayerStatus/HealthBar` | 100, range 0–100 | Display current health percentage |
| `PlayerStatus/HealthValue` | `100%` | Match health bar; clamp and format consistently |
| `PlayerStatus/Shield` | Shield icon visible | Show filled/bright for one available shield hit, dim when absent |
| `PlayerStatus/Bomb1`, `Bomb2` | Two bright icons | Reflect actual available bombs; dim spent slots |
| `PlayerStatus/PowerValue` | `1` | Display current power level |
| `PlayerStatus/PowerProgress` | 0, range 0–5 | Display partial collectible progress; handle maximum power according to design |
| `BossStatus` | Hidden | Show only during active boss/miniboss encounter |
| `BossStatus/BossName` | `Guardião das Lanternas` | Replace with encounter name |
| `BossStatus/Phase1`, `Phase2`, `Phase3` | Each 100, range 0–100 | Bind phase health; dim/empty completed phases; adjust count/layout for the two-phase sentry |
| `AttackName` | Hidden; `Ritual das Lanternas` | Brief attack cue, cleared after transition rather than persistent tutorial text |
| `TargetMarker` | Hidden | Project valid target to screen; hide on lost/behind-camera target; center icon on projected point |
| `ThreatLeft`, `ThreatRight` | Hidden | Side-warning visual samples; compute actual direction/visibility from threat data |

Threat samples are not a complete 3D warning system. Vertical/offscreen coverage, timing and priority remain to be integrated. Do not turn the target marker on at its default origin: no projected target position exists yet. Health, bomb and power values are authored visual examples, not saved session state. UI observes combat state; it must not own or change resource values.

`tools/validate_hud_handoff.gd` is an offline presentation check. It validates 13 required node paths and non-interactive controls, then renders the normal HUD and a synthetic boss example. The latter uses 70% health, a spent shield/bomb, power 2 with partial progress 3, and reduced phase-one health to inspect visual states. These changes exist only in the QA process. Both screenshots were inspected successfully; import and render logs are in `docs/validation/`. No gameplay bindings, animation timing or physical-gamepad behavior have been verified.
