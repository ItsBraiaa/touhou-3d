# Touhou 3D Implementation Plan

> **Status: non-authoritative draft, not approved for execution.** The user assigned programming to Claude and requested engineering refinement with mattpocock skills. Start with [ENGINEERING_BRIEF.md](../../../ENGINEERING_BRIEF.md). The file layout, signatures, and implementation suggestions below remain unvalidated reference material; they do not prescribe a skill workflow or authorize delegation.

**Goal:** Deliver the approved two-stage 3D bullet hell with keyboard/gamepad control, readable combat, checkpoint restoration, and a complete Portuguese menu flow.

**Architecture:** Build a playable vertical slice first. Keep combat state separate from presentation, use a stage director for encounter progression, and reconstruct encounters from checkpoint snapshots. Content resources supply patterns and encounter parameters; shared systems handle both stages.

**Tech stack:** Existing Godot 4 project, GDScript, 3D scenes, imported GLB/glTF assets, local audio, built-in audio buses and input actions. Verify installed engine compatibility before implementation. Use a lightweight native GDScript test runner rather than introducing a test framework dependency.

**Specs:** [Game design](../../../PLANEJAMENTO.md) and [Stage progression](../../../STAGE_DESIGN.md). Read both before execution. Paths below are relative to the project root, `C:/Users/Braia/Documents/touhou-3d`.

## Global constraints

- Documentation and code identifiers are English; player-facing UI remains Portuguese.
- Two complete stages; Stage 2 must provide at least five minutes of active gameplay, measured without menus, failures, or deliberate stalling.
- Real three-axis flight and free movement around bosses. Keyboard works without a mouse; gamepad works throughout gameplay and menus.
- Preserve all approved mechanics: aim assist, target lock, focus, vulnerable core, shield, health, bomb, power pickups, familiars, graze, named boss attacks, and the Stage 2 miniboss.
- Checkpoints refill 100% health, one shield, and two bombs on first activation and retry. Re-entering an active checkpoint does not refill again.
- Menus stay concise. Combat HUD contains only essential indicators; score and total graze belong in pause/results.
- Keep downloaded source files intact. Integrate selected assets and their dependencies into `assets/`; do not rename or move the original packs.
- Scope is a game implementation, not an asset-catalog application. No inventory, multiplayer, extra stages, or input-remapping editor.
- Runtime and visual checks are separate: a headless pass cannot demonstrate readable 3D combat or gamepad ergonomics.

## Verified starting state

Inspected on 2026-09-20:

- `project.godot` exists with no main scene configured. It declares Godot 4.7 features, Forward Plus, Jolt, and D3D12. Installed editor compatibility is not yet established.
- No gameplay scenes or scripts were found at the project root.
- `All models/kenney_space-kit`, `All models/Ultimate Monsters`, and `All models/Ultimate nature` exist.
- `all-sounds/` contains Digital Audio, Impact Sounds, Interface Sounds, and Sci-fi Sounds packages.
- `Music/` contains five MP3s with the previously discussed Touhou track names. Their presence does not establish recording provenance or redistribution permission.
- No Godot executable resolved through the shell's `godot`/`godot4` lookup. Locate the existing installation before installing anything.
- No `.git` directory was visible at the project root. Do not assume commits or worktrees are available; check repository status before using Git.

## Dependency order and work ownership

Tasks 1 → 2 → 3 establish one playable combat arena. Tasks 4 and 5 add encounters and stage content. Task 6 implements menus and persistence against stable session contracts. Task 7 integrates production art/audio. Task 8 validates and packages.

One owner controls shared files: `project.godot`, `src/session/`, and shared contracts. If delegation is chosen during execution, stage-content or asset-review work can run independently only after these interfaces are stable. Never let two agents edit the same file simultaneously. Delegate concrete tasks with their specs and dependency outputs; verify integration in the main workspace.

## Planned file map

| Files | Responsibility |
| --- | --- |
| `scenes/main.tscn`, `src/session/game_session.gd` | Root composition, campaign/isolated mode, scene transitions |
| `scenes/player/player_ship.tscn`, `src/player/player_controller.gd` | Physical ship movement and visual banking |
| `src/player/flight_math.gd`, `src/player/camera_rig.gd`, `src/player/targeting.gd` | Movement math, follow/lock camera, target selection |
| `src/combat/combat_state.gd`, `src/combat/projectile_system.gd` | Health/resources, swept projectile collision and graze |
| `src/combat/player_weapon.gd`, `src/combat/pickup.gd`, `src/combat/pattern_emitter.gd` | Shooting/familiars, collection, enemy patterns |
| `src/enemies/enemy_actor.gd`, `src/enemies/boss_controller.gd` | Common enemy behavior and segmented boss encounters |
| `src/progression/encounter_definition.gd`, `src/progression/stage_director.gd`, `src/progression/checkpoint_store.gd` | Encounter data, progression gates, snapshots/restores |
| `scenes/stages/stage_01.tscn`, `scenes/stages/stage_02.tscn`, `data/stages/stage_01.tres`, `data/stages/stage_02.tres` | Stage layout and ordered encounter data |
| `scenes/ui/`, `src/ui/menu_controller.gd`, `src/ui/hud.gd`, `src/settings/settings_store.gd` | Localized flow, essential HUD, persistent options |
| `src/audio/audio_controller.gd`, `default_bus_layout.tres` | Music/SFX lifecycle and independent volume buses |
| `assets/`, `ASSET_CREDITS.md` | Selected production resources and source records |
| `tests/run_tests.gd`, `tests/test_*.gd`, `scenes/tests/combat_arena.tscn` | State/physics assertions and visual test arena |
| `docs/validation.md`, `export_presets.cfg` | Recorded verification and Windows export settings |

## Verification commands

During Task 1, locate the console-capable executable and set a task-local PowerShell variable `$godotExe` to its verified absolute path. Record that path in `docs/validation.md`. Commands below deliberately use that discovered value rather than an invented installation path.

```powershell
& $godotExe --version
& $godotExe --headless --path . --editor --import
& $godotExe --headless --path . --script res://tests/run_tests.gd
& $godotExe --path . res://scenes/tests/combat_arena.tscn
```

The test runner collects each test suite's failure strings, prints every failure, and exits with `quit(1)` on any failure or `quit(0)` otherwise. Test suite interface: `func run() -> PackedStringArray`. Import failures are setup errors, not successful red-phase behavior tests. First verify a behavioral assertion fails for the intended reason, then implement and rerun.

## Task 1: Flight and camera vertical slice

**Dependencies:** none.

**Files:** create player/controller/math/camera/targeting files, `scenes/tests/combat_arena.tscn`, `scenes/main.tscn`, `tests/run_tests.gd`, `tests/test_flight.gd`, and `docs/validation.md`; modify `project.godot`.

**Interfaces:**

```gdscript
# flight_math.gd — pure helper
static func desired_velocity(input_axes: Vector3, yaw: float, speed: float, focus_scale: float) -> Vector3
# targeting.gd
func lock_target(candidate: Node3D) -> void
func release_target() -> void
func next_target() -> void
func get_target() -> Node3D
# player_controller.gd
func reset_at(spawn_transform: Transform3D) -> void
# camera_rig.gd
func set_target(target: Node3D) -> void
```

Input axes are right/up/back. Normalize the combined input before multiplying speed; rotate horizontal motion by camera yaw around world up. Camera pitch must not change vertical input. Use a CharacterBody3D for scenery collision, with a separate visual root for banking.

- [ ] Locate Godot and verify its version against the existing project. Inspect the import log and record any renderer/export limitations.
- [ ] Add input actions from the design: move_left/right/forward/back, ascend, descend, camera_left/right/up/down, fire, focus, lock_target, next_target, bomb, pause. Bind the specified keyboard and gamepad inputs, with mouse camera support optional.
- [ ] Add the native test runner and a flight test with the assertions below. Verify failure before implementing movement math.

```gdscript
var diagonal := FlightMath.desired_velocity(Vector3(1, 1, -1), 0.0, 10.0, 1.0)
if not is_equal_approx(diagonal.length(), 10.0):
    failures.append("Three-axis movement must not exceed base speed")
var focused := FlightMath.desired_velocity(Vector3.UP, 1.2, 10.0, 0.45)
if not focused.is_equal_approx(Vector3(0, 4.5, 0)):
    failures.append("Focus scales vertical motion; camera yaw must not tilt it")
```

- [ ] Implement the math using `input_axes.limit_length(1.0).rotated(Vector3.UP, yaw) * speed * focus_scale`; apply it in the physics update and use `move_and_slide()`.
- [ ] Build an arena with floor/height references, three dummy targets at different heights, environment lighting, and a visible ship core. Use a simple temporary mesh while asset selection is pending.
- [ ] Implement stable follow/lock framing, line-of-sight target selection, explicit switching, and target invalidation. Check `is_instance_valid()` before using a target after destruction. Keep interpolation time-based.
- [ ] Run headless tests and manually fly/orbit/ascend/descend using keyboard and a physical controller. Confirm no mouse dependency and no camera roll.

**Done:** the player can reach each dummy, lock/switch targets, circle at different heights, and collide with scenery without camera flips. Record actual controller availability rather than claiming an unperformed test.

## Task 2: Combat state, bullets, shield, focus, and graze

**Dependencies:** Task 1.

**Files:** create `src/combat/combat_state.gd`, `src/combat/projectile_system.gd`, `tests/test_combat.gd`, and `tests/test_projectiles.gd`; modify player scene and test arena.

**Interfaces:**

```gdscript
# CombatState extends RefCounted
var health_percent: float = 100.0
var shield: bool = true
var bombs: int = 2
var power_level: int = 1
var power_progress: int = 0
var invulnerability_left: float = 0.0
func apply_hit(damage: float) -> bool # true only when a hit is accepted
func tick(delta: float) -> void
func refill() -> void # health=100, shield=true, bombs=2
func snapshot() -> Dictionary
func restore(data: Dictionary) -> void
# ProjectileSystem extends Node3D
func spawn_projectile(position: Vector3, velocity: Vector3, hostile: bool, damage: float, radius: float, lifetime: float) -> int
func clear_hostile() -> void
func clear_radius(center: Vector3, radius: float) -> void
func reset_all() -> void
```

- [ ] Add a shield regression test; verify it fails for the intended behavior.

```gdscript
var state := CombatState.new()
state.apply_hit(10.0)
if state.shield or state.health_percent != 100.0:
    failures.append("First hit must remove shield without reducing health")
state.apply_hit(10.0)
if state.health_percent != 100.0:
    failures.append("Invulnerability must reject a second immediate hit")
state.tick(1.1)
state.apply_hit(10.0)
if state.health_percent != 90.0:
    failures.append("An unshielded later hit must remove 10 percentage points")
```

- [ ] Implement the hit ordering: reject during invulnerability/death; otherwise consume shield or reduce health, then grant 1 second of invulnerability. Clamp health to zero and emit defeat once through the owning player node.
- [ ] Implement projectile records with unique IDs, previous/current positions, bounded lifetime, and reusable visuals. Use segment-to-core collision rather than endpoint-only distance. A segment crossing the core must register even when both endpoints are outside.
- [ ] Add graze detection outside the core, with one award per projectile and hit precedence. Disable awards during invulnerability; explicit cleanup never awards graze.
- [ ] Add tests for a fast projectile crossing the core, duplicate graze callbacks, simultaneous hit/graze, and hostile-only cleanup. Implement and rerun until behavior passes.
- [ ] Add visible nucleus/shield feedback and one simple aimed enemy burst in the arena. Test vertical dodging and readability at near/far distances.

**Done:** hits, near misses, invulnerability, projectile cleanup, and scenery occlusion behave consistently at varying frame rates.

## Task 3: Player offense, pickups, bombs, and familiars

**Dependencies:** Task 2.

**Files:** create `src/combat/player_weapon.gd`, `src/combat/pickup.gd`, `tests/test_power_bomb.gd`; modify combat state, projectile system, and arena.

**Interfaces:**

```gdscript
# Additional CombatState methods
func collect_power() -> int # returns excess-pickup score, otherwise zero
func collect_shield() -> bool # false when already protected
func spend_bomb() -> bool # false with zero charges or dead state
# PlayerWeapon
func set_firing(enabled: bool) -> void
func try_bomb() -> bool
```

- [ ] Test that 5 pickups reach level 2, another 5 reach level 3, and an extra pickup yields 50 score. Test shield pickup refusal when already shielded and bomb refusal at zero charges.
- [ ] Implement hold-to-fire cadence and target-assisted trajectories that still collide with obstacles. Use the projectile system for both player and familiar shots.
- [ ] Add two visual familiars at power 2 and strengthen their cadence/tracking at power 3. Keep their visuals outside the player's collision contract.
- [ ] Implement reachable floating pickups with short-range attraction. Consume a pickup only after its state mutation succeeds; reject duplicate collection callbacks.
- [ ] Implement a bomb with a configurable sphere, moderate damage, 2-second invulnerability, and charge consumption. Initial test-arena radius: 12 world units; tune to actual arena scale. Bomb damage must not carry through a boss phase boundary.
- [ ] Test that friendly projectiles survive hostile cleanup, the bomb leaves hostile bullets outside its radius, and holding the input does not spend both charges in one press.
- [ ] Play the arena with all power levels, two bombs, shield pickup, and focus. Confirm VFX preserve readability.

**Done:** the arena demonstrates every player mechanic in the spec with no final-boss or stage dependencies.

## Task 4: Encounter progression and checkpoint restoration

**Dependencies:** Task 3.

**Files:** create progression files, `src/session/game_session.gd`, `tests/test_progression.gd`, `tests/test_checkpoint.gd`; modify main scene and arena.

**Interfaces:**

```gdscript
# EncounterDefinition extends Resource
@export var encounter_id: StringName
@export var next_encounter_id: StringName
@export var enemy_count: int
@export var power_reward: int
@export var checkpoint_id: StringName
# StageDirector extends Node
func start_stage(stage_id: int, entry: Dictionary) -> void
func activate_encounter(encounter_id: StringName) -> void
func report_enemy_defeated(encounter_id: StringName, enemy_id: int) -> void
func report_objective_destroyed(objective_id: StringName) -> void
func activate_checkpoint(checkpoint_id: StringName) -> bool
func retry_checkpoint() -> void
func restart_stage() -> void
# CheckpointStore extends RefCounted
func capture(checkpoint_id: StringName, state: Dictionary) -> bool
func read_snapshot() -> Dictionary
# GameSession extends Node
func start_campaign() -> void
func start_single_stage(stage_id: int) -> void
func continue_campaign() -> void
func return_to_menu() -> void
```

- [ ] Create regression tests for duplicate enemy-death callbacks and repeated checkpoint entry. Gates/rewards must resolve once; a second checkpoint activation must return false and leave damaged resources unchanged.
- [ ] Implement inactive/active/completed encounter states, distinct enemy IDs, one-time rewards, and gate changes. Complete a combat segment only when its enemy/objective condition is satisfied.
- [ ] Implement snapshots using deep copies. Required keys: stage_id, next_encounter_id, combat, score, graze_count, active_time, bombs_used, completed_encounters, objectives. Include partial power progress. Refill before capture.
- [ ] Test capture at power 2/progress 3/score 450; mutate those values and defeat the player; restore and assert the original power/progress/score plus full resources. Failed-segment time and rewards must roll back.
- [ ] Retry must cancel queued spawns and clear enemies, bullets, pickups, targeting, and transient damage state before rebuilding the saved segment. Emit a resume event only after restoration completes.
- [ ] Implement stage-entry snapshots independently from checkpoint snapshots. Campaign preserves power/score between stages; direct Stage 2 begins at power 2 with zero score.
- [ ] Exercise a two-sector arena with a gate and checkpoint: clear, activate, take damage, revisit, die, retry, and explicitly restart stage.

**Done:** replaying a failed segment never duplicates rewards or inflates successful-path statistics; stage restart differs correctly from checkpoint retry.

## Task 5: Enemy patterns, bosses, and both stages

**Dependencies:** Task 4.

**Files:** create enemy/boss/pattern files, both stage scenes/resources, `tests/test_stage_data.gd`, `tests/test_boss.gd`; modify director to consume stage data.

**Interfaces:**

```gdscript
# EnemyActor extends Node3D
signal defeated(enemy_id: int)
func take_damage(amount: float) -> void
# BossController extends EnemyActor
signal phase_changed(index: int, display_name: String)
func configure(phase_health: PackedFloat32Array, attack_names: PackedStringArray) -> void
# PatternEmitter
func emit_ring(origin: Vector3, axis: Vector3, count: int, speed: float, gap_angle: float) -> void
func emit_aimed_burst(origin: Vector3, sampled_target: Vector3, count: int, speed: float) -> void
```

- [ ] Add tests requiring S1-01 through S1-07 and S2-01 through S2-07, reachable next IDs, exact checkpoint IDs, and three unique seal IDs. Reject an unknown next ID with a clear load error instead of starting an unwinnable stage.
- [ ] Implement Spirits and Sentries, visible anticipation, bounded spawn volumes, and parameterized ring/fan/spiral/aimed emitters. Preserve escape gaps and use projectile cleanup at phase/encounter transitions.
- [ ] Test boss overflow: damage greater than current segment health advances only one phase. Test that the final segment emits defeat once. Implement the same segmented controller for two-phase miniboss and three-phase final bosses.
- [ ] Build Stage 1's seven segments exactly from `STAGE_DESIGN.md`, including portal guard links, reward bundles, CP1-A and CP1-B. Start with simple geometry and stable encounter IDs.
- [ ] Build Stage 2's seven segments, including guard activation by approach or attack, three low/mid/high seals, and all six destruction orders. Give the miniboss a scaled Sentry visual with rotating parts.
- [ ] Add CP2-A before the miniboss and CP2-B before the final boss. Test death after the miniboss restores CP2-A until CP2-B is reached.
- [ ] Verify barriers span the allowed volume and required enemies remain reachable. Reposition escaped required enemies without granting rewards.
- [ ] Play both complete stages with temporary art. Measure duration, record dominant safe exploits, and adjust patterns/layout before decorating.

**Done:** both stages can be cleared directly and consecutively; the gates, miniboss, checkpoints, and boss phase sequences match the stage spec.

## Task 6: Menus, HUD, settings, and pause

**Dependencies:** Task 4 session contracts; integrate with Task 5 scenes.

**Files:** create UI/settings files and `scenes/ui/main_menu.tscn`, `scenes/ui/hud.tscn`, `scenes/ui/pause_menu.tscn`, `scenes/ui/results.tscn`, `scenes/ui/options.tscn`, `tests/test_settings.gd`.

**Interfaces:**

```gdscript
# SettingsStore extends RefCounted
func load_settings() -> Dictionary
func save_settings(settings: Dictionary) -> Error
# MenuController
func show_main_menu() -> void
func show_results(result: Dictionary, campaign: bool) -> void
# HUD
func refresh(combat: CombatState) -> void
```

- [ ] Implement the four main entries: Iniciar, Selecionar fase, Opções, Sair. Wire them to the existing GameSession methods. Both stage cards are unlocked and use names/images only.
- [ ] Implement the approved controls diagram and audio/display/input options. Persist only settings to `user://settings.cfg`; clamp volumes/sensitivity and fall back to defaults for malformed values.
- [ ] Test missing config and invalid volume/device values. Verify a save/load round trip without storing campaign state.
- [ ] Implement pause with processing isolated to the menu. Freeze physics, spawns, invulnerability, projectile lifetimes, and active run time. Ignore fire/bomb input while paused.
- [ ] Build the minimal HUD and transient attack names. Keep score/graze totals in pause/results. Add directional off-screen warning icons tied to actual threat origin.
- [ ] Handle controller disconnect by pausing and assigning keyboard focus. In automatic mode, update prompts from the last input device without losing menu selection.
- [ ] Walk every menu route on keyboard and gamepad, including restart, retry, campaign continuation, isolated-stage victory, and exit.

**Done:** the complete flow is navigable without a mouse; pause cannot change combat state and options survive an application restart.

## Task 7: Production models, animations, SFX, and music

**Dependencies:** Tasks 1–6 behavior is stable. Asset inspection can start earlier without editing shared gameplay files.

**Files:** create `assets/models/`, `assets/audio/`, `ASSET_CREDITS.md`, `src/audio/audio_controller.gd`, `default_bus_layout.tres`; modify player/enemy/stage presentation scenes.

**Interfaces:**

```gdscript
# AudioController
func play_sfx(event_name: StringName, world_position: Vector3) -> void
func play_music(track_key: StringName) -> void
func stop_music() -> void
```

- [ ] Preview `All models/kenney_space-kit/Models/GLTF format/craft_speederA.glb` and `craft_racer.glb` as ship candidates; choose one based on core visibility and silhouette. These are candidate filenames, not already approved models.
- [ ] Inspect `All models/Ultimate Monsters/Flying/glTF/Ghost.gltf` and `Dragon.gltf` as guardian candidates. Read actual animation names; choose compatible idle/anticipation/attack/defeat clips or animate parts directly. Do not assume clip names from model names.
- [ ] Copy only selected models plus their referenced buffers/textures. Preserve source packs. Record source, selected file, license, scale correction, forward axis, and used clips.
- [ ] Select trees/rocks from Ultimate nature and dress both routes with the agreed palettes. Ensure collision geometry, camera clearance, and firing paths still work.
- [ ] Add simple ship banking/core pulses/propulsion and clearly visible boss model animation. Ensure visual banking does not move the damage core.
- [ ] Audition short SFX from the verified `all-sounds/` packs. Use `laser1.ogg` only as an initial candidate, not a final selection. Bind menu, shot, hit, pickup, shield break, bomb, warning, victory, and defeat events.
- [ ] Use Master/Music/SFX buses. Cap simultaneous repeated shot sounds so dense fire does not drown out warnings or the soundtrack.
- [ ] Inspect the five MP3 recordings and source permissions before including them in a distributable export. If provenance remains unresolved, use permitted alternate tracks from the documented catalog; keep combat functional independently of music availability.
- [ ] Verify atmosphere, bullet contrast, readable UI, and sound balance through complete runs. Save asset decisions and animation checks in the validation record.

**Done:** selected assets render and animate correctly; audio events cover the spec; credits include every distributed third-party file.

## Task 8: Acceptance, performance, and delivery

**Dependencies:** Tasks 1–7.

**Files:** modify `docs/validation.md`, create `export_presets.cfg`, `DELIVERY.md`; exported files go under `build/windows/`.

- [ ] Run all native tests and the editor import check. Fix failures before declaring success; record commands and actual results.
- [ ] Run the complete acceptance checklists from both specs. Include all six seal orders, checkpoint boundaries, bomb kills of last enemies, and retry/statistics integrity.
- [ ] Measure uninterrupted Stage 2 clears at starting power 2 and campaign power 3, using bombs efficiently. Record active duration; add meaningful encounter content or adjust pacing if below five minutes. Never count pauses or failed retries.
- [ ] Profile dense final-boss patterns on the presentation computer. Aim for 60 FPS; record hardware, resolution, peak projectile count, and observed performance. Reduce decorative cost before changing approved combat scope.
- [ ] Verify actual keyboard-only and physical-gamepad runs. If no controller is available, mark that specific check unverified instead of treating simulated input as a complete substitute.
- [ ] Export a Windows build using installed templates and an explicit Windows Desktop preset. Example after preset creation: `& $godotExe --headless --path . --export-release 'Windows Desktop' 'build/windows/Touhou-3D.exe'`.
- [ ] Launch the exported executable outside the editor. Verify menus, both stages, settings, audio, asset paths, and checkpoint behavior. Confirm the complete build's accompanying files are retained.
- [ ] Prepare a project ZIP excluding `.godot`, generated builds, and unused duplicate source assets while retaining the selected game assets and source project. Test reopening a separate extracted copy before delivery.
- [ ] Write `DELIVERY.md` with launch instructions, controls, credits location, tested hardware, and remaining limitations. Prepare a ten-minute presentation route using stage selection to demonstrate both stages and a checkpoint.

**Done:** evidence supports both specs' acceptance criteria, the exported build runs on the target machine, and the project package reopens independently. Classroom submission is performed by the user.

## Review and completion discipline

At each task boundary, record modified files, behavioral checks, manual evidence, and remaining failures. Commit only if a Git repository is available and the workspace permits it; do not report a commit when none occurred. A failed runtime or usability check keeps that task incomplete even if the headless tests pass.

This plan has not been executed. Source-level code snippets define implementation direction and test expectations; they are not verified implementation artifacts.
