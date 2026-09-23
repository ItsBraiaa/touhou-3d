# Player flight

The player's movement rules, the ship that obeys them, the camera that watches it, and the Target Lock the camera frames. Started with ticket F1-01 on 2026-09-21 and extended by F1-02, F1-03 and F1-04 on 2026-09-22. `FlightModel`, `PlayerController`, `CameraRig`, `TargetSelector` and `Targeting` are all CODE_READY.

## Purpose

`FlightModel` owns how input axes and a camera yaw become a velocity: camera-relative horizontal movement with a world-vertical axis, bounded diagonal speed, the Focus speed factor, the Flight Volume limit, the edge-proximity value used for boundary feedback, and the visual bank angle.

`PlayerController` is the Adapter that gives those rules a body: it reads the sixteen input actions, asks the camera rig for its yaw, drives the core, moves the `CharacterBody3D` against scenery, banks `VisualRoot`, and exposes control enable, reset and edge feedback to whoever owns the ship.

`CameraRig` is the Adapter that decides where the camera is and where it looks: it follows the ship without inheriting its rotation, orbits with the `camera_*` actions, frames a Target Lock together with the ship, shortens against scenery, and publishes the one number the other two depend on — its yaw. It has no Rules Core, because every question it answers is a question about the scene: where the ship is, where the target is, what the ray hit (ADR-0001).

`TargetSelector` owns the Target Lock rules: which target a fresh lock takes, where `next_target` steps to, when a held lock is invalidated, and when the lock changes. `Targeting` is its Adapter: it describes every `targetable` node as the camera sees it each physics tick, reads `lock_target` and `next_target`, and reports the locked node, which the ship hands to its camera.

None of them owns the weapon, Aim Assist shots (F6-03), the HUD marker (F4-02) or anything that reads the damage Core. The cores never integrate and never touch a Node; no adapter decides a movement or selection rule.

## Files

- `scripts/player/flight_model.gd` (Rules Core, `class_name FlightModel extends RefCounted`).
- `scripts/player/player_controller.gd` (Adapter, `class_name PlayerController extends CharacterBody3D`, attached to `PlayerShip` in `scenes/player/player_ship.tscn`).
- `scripts/player/camera_rig.gd` (Adapter, `class_name CameraRig extends Node3D`, attached to `PlayerShip/CameraRig` in the same scene).
- `scripts/player/target_selector.gd` (Rules Core, `class_name TargetSelector extends RefCounted`, with the inner value class `TargetSelector.Candidate`).
- `scripts/player/targeting.gd` (Adapter, `class_name Targeting extends Node`, attached to `PlayerShip/Targeting`).
- `tests/unit/player/test_flight_model.gd` (18 tests), `tests/unit/player/test_target_selector.gd` (14 tests), `tests/scene/test_player_ship_contract.gd` (11 tests), `tests/scene/test_camera_rig_contract.gd` (11 tests) and `tests/scene/test_targeting_contract.gd` (10 tests).
- `scenes/dev/arena_harness.tscn` and `scenes/dev/arena_harness.gd` (dev only: the scene to run while flying, the stand-in owner until F2-04, and a readout of the flight, the camera and the lock).
- `tools/validate_player_flight.gd` (offline flight, camera and targeting QA: drives the harness with simulated input, measures it, writes the screenshots in `docs/validation/player-flight.md`).

## Public contract

### Exports (Adapter)

Authored in `scenes/player/player_ship.tscn`. The numbers are Astra's to tune; the four references must stay pointing at the nodes below.

| Export | Type | Default | Required | Meaning |
| --- | --- | --- | --- | --- |
| `base_speed` | float | 12.0 | — | Top speed in world units per second, on any axis and on any diagonal (GUIDE Section 13). |
| `focus_multiplier` | float | 0.45 | — | Factor applied to `base_speed` while Focus is held (PLANEJAMENTO Section 4). |
| `edge_margin` | float | 4.0 | — | Distance from a Flight Volume face at which the edge feedback starts to rise. Proposal, not an authored value. |
| `max_bank_angle_degrees` | float | 25.0 | — | Largest roll of `VisualRoot` at full lateral speed. Proposal, not an authored value. |
| `bank_smoothing` | float | 8.0 | — | Rate the bank eases toward its target, in reciprocal seconds. Frame-rate independent; 0 leaves the ship level. |
| `visual_root` | Node3D | `VisualRoot` | yes | The only node banking is applied to. |
| `camera_rig` | CameraRig | `CameraRig` | yes | Yaw source for camera-relative movement. Typed to the class since F1-03; the stored `NodePath` did not change. |
| `damage_core` | Area3D | `DamageCore` | yes | Projectile damage volume. Not read yet; F7 owns damage. |
| `graze_volume` | Area3D | `GrazeVolume` | yes | Near-miss volume. Not read yet; F5 owns graze. |
| `targeting` | Targeting | `Targeting` | yes | Target Lock selection. Not driven from here; the ship owns it and its camera, so `_ready` makes the one connection `targeting.target_changed → camera_rig.set_lock_target` (F1-04). |

A missing reference is reported with `push_error` naming this node's path and the field, and the adapter sets its own `process_mode` to `DISABLED` instead of running half-configured (CONVENTIONS "Setup errors are loud").

### Signals

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `FlightModel.edge_proximity_changed` | `value: float` | `edge_proximity()` computes a value more than `EDGE_PROXIMITY_EPSILON` (0.01) away from the last one that was emitted. The remembered value moves only on an emission, so a drift below the threshold still reports once it adds up to one. It starts at 0.0, so a ship that spawns away from every face is silent on its first tick. |
| `PlayerController.edge_proximity_changed` | `value: float` | Re-emitted from the core, for the HUD and any boundary presentation. |
| `PlayerController.focus_changed` | `active: bool` | Focus starts or stops, once per edge and never per tick. Disabling the controls releases Focus, so a pause cannot leave it stuck on. |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `FlightModel.configure(base_speed, focus_multiplier, edge_margin) -> void` | Adapter `_ready` | Stores the authored flight values. Until it is called `base_speed` is 0.0, so the model reports no movement. |
| `FlightModel.set_bounds(bounds: AABB) -> void` | Adapter `setup` | Sets the Flight Volume. An `AABB` is a position and a size, not two corners: a caller holding a min and a max passes `AABB(min, max - min)`. |
| `FlightModel.compute_velocity(move: Vector2, vertical: float, focus: bool, camera_yaw: float) -> Vector3` | Adapter `_physics_process` | World velocity in units per second. `move.x` is strafe (right positive), `move.y` is forward (positive forward), `vertical` is ascend positive; all three are already dead-zoned and in [-1, 1]. The 3D input vector is clamped to length 1 before being scaled, so a full three-axis diagonal still flies at `base_speed`. The horizontal part is rotated by `camera_yaw` around world Y and the vertical part is world Y, which keeps the horizon stable. Pure: no delta, no stored state. |
| `FlightModel.clamp_position(position: Vector3) -> Vector3` | Adapter `_physics_process`, after `move_and_slide` | The nearest point inside the Flight Volume, or `position` unchanged while no bounds have been set. |
| `FlightModel.edge_proximity(position: Vector3) -> float` | Adapter `_physics_process` | 0 while farther than `edge_margin` from every face, rising linearly to 1 at the nearest face, and 1 outside. 0 while no bounds or no margin have been configured. Emits `edge_proximity_changed` as described above. |
| `FlightModel.bank_angle(velocity: Vector3, camera_yaw: float, max_angle: float) -> float` | Adapter `_process` | Roll for `VisualRoot`, in radians, from the part of `velocity` that is lateral to the camera, clamped to ± `max_angle`. Negative leans into a turn to the ship's right, which is the sign `VisualRoot.rotation.z` needs for the right wing to dip while the nose points at -Z. Visual only. |
| `PlayerController.setup(bounds: AABB) -> void` | The ship's owner: `scenes/dev/arena_harness.gd` today, `GameSession` from F2-04, the Stage Director when the active Encounter changes | Sets the Flight Volume. Until it is called the ship is limited by scenery collision alone and the edge feedback stays at 0. |
| `PlayerController.set_controls_enabled(enabled: bool) -> void` | The ship's owner, on pause, defeat and stage transitions | While false the input is not read, the velocity is zero, Focus is released and the bank eases back to level. Idempotent. |
| `PlayerController.reset_to(transform: Transform3D) -> void` | The ship's owner, on respawn and checkpoint restore | Teleports the ship and clears its motion: no carried velocity, no carried bank. |

### Ticking

`_physics_process` reads the input, asks the model for a velocity, calls `move_and_slide()`, then clamps the position and updates the edge proximity — in that order, so the authored walls and the Flight Volume rule both apply and the feedback describes where the ship actually ended up. `_process` only eases `VisualRoot.rotation.z` toward `bank_angle`, with `lerpf(current, target, 1 - exp(-bank_smoothing * delta))`, which is the frame-rate-independent form (CONVENTIONS "Time and randomness").

The body is `motion_mode = MOTION_MODE_FLOATING` with no gravity, collision layer 2 and mask 1 (scenery only). Floating mode leaves `velocity` alone when a slide is blocked, so the value a HUD reads is the commanded velocity, not the achieved one; nothing accumulates, because the velocity is recomputed from the input every tick.

## Camera contract

### The yaw, and why it lives in a node rotation

Camera-relative movement is one number: the yaw the horizontal input is rotated by. `CameraRig` keeps it in its own `global_rotation.y` and publishes it through `get_yaw()`, which is what `PlayerController._camera_yaw()` calls. Both readings are the same value on purpose, and the scene node is the single source of truth: the rig reads its own rotation at the start of every tick, modifies it, and writes it back, so anything that turns the node — a test, a future respawn placing the camera behind the ship — turns where "forward" flies with it.

The alternative, a private `_yaw` that only rotates the `Camera3D`, fails silently: the rig node stays unrotated, `global_rotation.y` reads 0 forever, and the ship keeps flying along world axes while the camera turns, with nothing raising an error. `test_forward_input_follows_the_camera_yaw_instead_of_the_world_axis` is the regression test for exactly that, and the measured `camera-relative forward` case repeats it in the running game.

The pitch is private, because nothing outside the rig reads it.

### Exports (CameraRig)

Authored on `PlayerShip/CameraRig`. `camera` must point at the `Camera3D`; the rest are framing and feel values for Astra to tune in the Inspector.

| Export | Type | Default | Required | Meaning |
| --- | --- | --- | --- | --- |
| `camera` | Camera3D | `Camera3D` | yes | The camera the rig places. Its `current` flag is left as authored. |
| `follow_distance` | float | 8.5 | — | Distance behind the ship at rest, before the pitch rotates the offset (GUIDE Section 13). |
| `follow_height` | float | 3.2 | — | Height above the ship at rest, on the same terms. |
| `default_pitch_degrees` | float | -9.0 | — | Pitch the rig starts at. Negative lifts the camera and looks down; -9° is the export form of the authored -0.16 rad. |
| `pitch_limits_degrees` | Vector2 | (-60, 35) | — | Lowest and highest pitch. `x` looks down from above the ship, `y` looks up from below it. |
| `orbit_speed_degrees` | float | 120.0 | — | Turn rate of the `camera_*` actions at full deflection, in degrees per second. |
| `sensitivity` | float | 1.0 | — | Player's camera sensitivity (PLANEJAMENTO Section 7); scales the turn rate. |
| `invert_vertical` | bool | false | — | When true, `camera_up` looks down instead of up. |
| `position_damping` | float | 10.0 | — | Rate the camera position eases toward its place behind the ship, in reciprocal seconds. |
| `rotation_damping` | float | 8.0 | — | Rate the aim chases the Target Lock framing. Follow mode's angles come straight from the input, so this shapes locked framing only. |
| `lock_blend_speed` | float | 4.0 | — | Rate the lock framing fades in and out. At 4.0 a lock takes a quarter of a second to take hold and the same to let go. |
| `obstruction_margin` | float | 0.4 | — | Distance the camera is held short of whatever the ray hit. |
| `collision_mask` | int (3D physics flags) | 1 | — | Layers the obstruction ray tests. Layer 1 is scenery and closed Gate barriers; the player body is layer 2 and is deliberately not in it. |

A missing `camera`, or a rig whose parent is not a `Node3D`, is reported with `push_error` naming this node's path and the rig sets its own `process_mode` to `DISABLED` (CONVENTIONS "Setup errors are loud").

### Methods (CameraRig)

| Method | Called by | Effect |
| --- | --- | --- |
| `get_yaw() -> float` | `PlayerController` every tick; F1-04 and the HUD later | The yaw the camera faces, in radians around world Y. The same value as the node's `global_rotation.y`. |
| `set_lock_target(target: Node3D) -> void` | F1-04's targeting; the dev harness today | Frames `target` together with the ship: the yaw eases toward the direction from the ship to it, the pitch toward their midpoint, fading in over `lock_blend_speed`. A target that is freed is dropped as if it had been cleared; passing null clears the lock. |
| `clear_lock_target() -> void` | The same caller | Returns to follow mode, fading the framing out over `lock_blend_speed` and leaving the camera where it is instead of snapping it behind the ship. |
| `apply_settings(p_sensitivity: float, p_invert_vertical: bool) -> void` | F3's settings | Stores the two camera settings of PLANEJAMENTO Section 7. Reading and persisting them is F3's. |

### Framing geometry

The rig is `top_level`, so the body's bank and any rotation an owner gives it never reach the camera. Every physics tick the rig places itself at the ship's position with a basis that is a pure yaw rotation — rebuilt, not rotated, so no pitch or roll can accumulate in it — and the camera is placed at `Vector3(0, follow_height, follow_distance)` rotated by the pitch around the rig's right axis and then by the yaw around world Y. The camera's own basis is built from the same yaw and pitch with an explicit zero roll. That is the whole of the stable horizon: there is no code path that can tilt it.

Because the offset and the view direction rotate by the same pitch, the angle between them is constant, so the ship keeps the same place on screen at every pitch — about 20.5° below the view centre with the authored values.

- **Follow mode.** The yaw and pitch change only from the `camera_*` actions, at `orbit_speed_degrees × sensitivity`, with `invert_vertical` on the vertical axis. The actions name where the *view* turns: `camera_up` raises the view, which orbits the camera below the ship. The pitch is clamped to `pitch_limits_degrees`.
- **Lock mode.** The framing pull is applied before the input, scaled by the blend, so the orbit input still moves the camera while locked and the framing eases back when it stops. The pitch aims at the midpoint between ship and target, measured from where the camera actually is, and is clamped by the same limits.
- **Obstruction.** Every physics tick a ray runs from the ship to the desired camera position on `collision_mask`. A hit caps how far the camera may sit from the ship, at the hit distance minus `obstruction_margin`. `_process` eases the camera position toward the desired one and then applies that cap, which means the camera leaves an obstruction smoothly and enters one immediately — easing in would spend those frames inside the scenery the ray already found.

### Ticking (CameraRig)

`_physics_process` owns everything that is coupled to the simulation: the lock blend, the aim, the rig's own transform, the desired camera position and the obstruction ray, which may only be cast during a physics step. `_process` interpolates: it eases the camera position toward the desired one, applies the obstruction cap and writes the camera's transform (CONVENTIONS "Time and randomness").

The rig runs after `PlayerController` in the same tick, because Godot calls a parent before its children, so the controller uses the yaw from the previous tick. One tick of camera latency on movement direction is invisible and keeps the pivot exact: the rig reads the ship's position after `move_and_slide` and the clamp, never before.

## Targeting contract

### The rules (TargetSelector)

PLANEJAMENTO Section 3 fixes two sentences: "Aim assist prioritizes visible targets near the screen center" and "Lock remains stable until explicitly switched, released, or invalidated by target death/range". The core turns them into four questions over a list of `Candidate` values the adapter builds each tick.

| Candidate field | Type | Meaning |
| --- | --- | --- |
| `id` | int | Opaque to the core; the adapter uses the node's instance id. Node ids are positive, so `NO_TARGET` (-1) is never one. |
| `screen_offset` | Vector2 | Normalized per axis: (0, 0) is the screen center, x = ±1 the right and left edges, y = ±1 the bottom and top edges. **y grows downward**, as viewport pixels do. The ellipse this makes on a 16:9 screen is what `max_screen_radius` is measured in. |
| `distance` | float | World distance from the ship, not from the camera. |
| `visible` | bool | In front of the camera with nothing on the occlusion mask in between. |

| Method | Rule |
| --- | --- |
| `configure(max_distance: float, max_screen_radius: float) -> void` | Stores the two limits. Until it is called both are 0 and nothing qualifies. |
| `select_best(candidates) -> int` | A fresh lock: among candidates that are visible, within `max_distance` and inside `max_screen_radius`, the one with the smallest `screen_offset.length()`, the nearer in distance winning a tie. `NO_TARGET` when none qualifies. |
| `select_next(candidates, current_id) -> int` | A switch: the next candidate **to the right on screen** among those that are visible and within range, wrapping from the rightmost to the leftmost; the same x goes top to bottom, then by id. Falls back to `select_best` when `current_id` is not among them (no lock, a target no longer listed, a lock held behind scenery). With one of them it returns that one. |
| `validate(candidates, current_id) -> bool` | Whether a held lock survives the tick: false when the id is not listed or is beyond `max_distance`, and for `NO_TARGET`. Occlusion and the screen radius do not matter. |
| `set_current(id: int) -> void` / `get_current_id() -> int` | Holds the lock. `target_changed(id: int)` is emitted only when the id actually changes; `NO_TARGET` is a release. |

Two rules differ from the ticket as written, and both came out of running the real camera against the three arena targets:

- **The switch ring is ordered left to right, not by angle around the screen center.** The camera turns to frame every new lock. A turn slides every target sideways by the same amount, so their left-to-right order survives it, while the locked target itself sits near the center, where its angle is noise: a hair above center it reads as twelve o'clock and "next" goes clockwise to the right, a hair below and "next" goes to the left.
- **The screen radius gates a fresh lock only, not a switch.** Measured from the arena's start: locked on High, the camera turns right and Low slides to x -0.965 — still on screen, but outside the 0.85 radius — so a ring that kept the radius wrapped from High to Middle and back, and Low could never be reached by cycling. `test_next_target_visits_all_three_before_wrapping_while_the_camera_follows` failed exactly that way (Middle, High, Middle, High) before the rule changed, and `test_select_next_reaches_visible_targets_outside_the_screen_radius` pins it in the core. A switch can therefore land on a target past the screen edge, as long as it is in front of the camera, in range and unoccluded; the camera then turns to it.

### Exports (Targeting)

Authored on `PlayerShip/Targeting`. `camera` must point at the rig's camera; the other four are values for Astra to tune.

| Export | Type | Default | Required | Meaning |
| --- | --- | --- | --- | --- |
| `camera` | Camera3D | `../CameraRig/Camera3D` | yes | Screen position and the occlusion ray are measured from it. |
| `max_distance` | float | 60.0 | — | Farthest a target may be from the ship to be acquired or kept, in world units. The arena's far corner is 68.6 from Low and 69.1 from Middle, so a release by range can be flown there. Proposal. |
| `max_screen_radius` | float | 0.85 | — | How far from the screen center a fresh lock may land, in the normalized units above: 1.0 reaches the edges. Proposal. |
| `occlusion_mask` | int (3D physics flags) | 1 | — | Layers that hide a target: scenery and closed Gates. A target's own volumes must not be on it, or it hides itself; `HitVolume` is on layer 5 and the ray ignores areas anyway. |
| `group_name` | StringName | `targetable` | — | Group the targets are in (GUIDE Section 13). |

A missing `camera`, or a `Targeting` whose parent is not a `Node3D`, is reported with `push_error` naming this node's path and the adapter sets its own `process_mode` to `DISABLED`.

### Signal and methods (Targeting)

| Member | Called by | Effect |
| --- | --- | --- |
| `signal target_changed(target: Node3D)` | — | The newly locked node, or null when the lock was released by the player, by range, or because the target disappeared. Connected once, in `PlayerController._ready`, to `CameraRig.set_lock_target`, which treats null as a release. F4-02's HUD marker and F6-03's Aim Assist connect to the same signal. |
| `get_current_target() -> Node3D` | The harness readout; the HUD and weapon later | The locked node, or null. A target freed since the last tick is already null here, one tick before the signal reports the release. |
| `build_candidates() -> Array[TargetSelector.Candidate]` | Its own tick; the contract test and the validation tool | One candidate per group member that is a `Node3D` with a `HitVolume` child, in group order: `camera.unproject_position` of the `HitVolume` normalized by half the viewport, `camera.is_position_behind`, one ray from the camera to the `HitVolume` on `occlusion_mask`, and the distance from the ship. Casts rays, so it is only valid during a physics step. |

A group member that is not a `Node3D` or has no `HitVolume` child is skipped, with one `push_warning` naming it; it is reported once per node, not every tick.

### Ticking (Targeting)

`_physics_process` reads `lock_target` and `next_target` with `is_action_just_pressed`. With no lock and neither pressed it returns before building anything, so an idle ship casts no rays. Otherwise it builds the candidates, drops a held lock that `validate` rejects, and then applies the press: `lock_target` is a toggle (acquire with `select_best` when free, release when locked) and `next_target` switches with `select_next`, keeping the current lock when there is nowhere to go. `next_target` with no lock acquires, like the harness stand-in it replaced.

`Targeting` runs after `PlayerController` and before `CameraRig` in the same tick, by tree order, so it measures the ship where it ended up this tick and the camera where the rig left it last frame.

## Dependencies

The core imports nothing, holds no Node, and is constructed with `FlightModel.new()` by the adapter, which injects the authored values through `configure()` and the Flight Volume through `set_bounds()`.

`PlayerController` depends on five scene nodes through its exports, on the input actions in `project.godot`, and on the camera rig for one number: `camera_rig.get_yaw()`. It is driven by an owner that calls `setup()`, and optionally `set_controls_enabled()` and `reset_to()`. Nothing calls up: the adapter's two signals are the only way out. As the owner of both `Targeting` and `CameraRig` it makes the one connection between them, in `_ready` — not in `setup()`, which an owner calls again whenever the Flight Volume changes.

`CameraRig` depends on its `camera` export, on its own parent being the `Node3D` it follows, on the four `camera_*` actions, and on the 3D physics space for the obstruction ray. It holds no reference to `PlayerController` or `Targeting` and emits no signal: `Targeting.target_changed` and F3 call down into it, and the only thing that flows out is `get_yaw()`.

`TargetSelector` imports nothing and holds no Node; ids are opaque integers. `Targeting` constructs it and injects the two limits through `configure()`. `Targeting` depends on its `camera` export, on its parent being the ship, on the `lock_target` and `next_target` actions, on the scene tree group, and on the 3D physics space for the occlusion ray. It holds no reference to the rig: its signal is the only way out.

## Invariants and tests

| Invariant | Test |
| --- | --- |
| The authored values reach the model, rather than being hardcoded in it | `test_configure_values_are_the_ones_the_model_uses`, `test_the_authored_flight_values_arrive_as_exports_not_metadata` |
| Frame-rate-independent movement (ENGINEERING_BRIEF 4.B, Section 8 "Movement normalization") | `test_integration_is_frame_rate_independent` |
| Bounded diagonal speed: three full axes still fly at `base_speed`, not `base_speed * sqrt(3)` (4.B) | `test_full_diagonal_on_three_axes_is_bounded_to_base_speed`, `test_partial_input_keeps_its_magnitude`, and the measured `three-axis diagonal` case in `tools/validate_player_flight.gd` |
| Focus scales every axis by 45 % (PLANEJAMENTO Section 4) | `test_focus_scales_every_axis_by_the_focus_multiplier`, and the measured `focus diagonal` case |
| Stable horizon: yaw rotates the horizontal plane only, ascent is world-vertical (PLANEJAMENTO Section 3) | `test_camera_yaw_rotates_the_horizontal_plane_only`, `test_vertical_input_ignores_camera_yaw` |
| The ship stays inside the Flight Volume (CONVENTIONS "Collision") | `test_clamp_position_keeps_points_inside_and_pulls_points_outside_to_the_nearest_face`, `test_clamp_position_is_identity_before_bounds_are_set`, `test_the_injected_flight_volume_clamps_the_ship_and_reports_the_edge`, and the measured `clamped floor y` case |
| Boundary feedback rises only near a face and reports events, not every tick (PLANEJAMENTO Section 3) | `test_edge_proximity_is_zero_at_the_center_and_one_at_a_face`, `test_edge_proximity_is_zero_without_bounds`, `test_edge_proximity_changed_fires_once_per_real_change`, `test_edge_proximity_changed_measures_drift_from_the_last_value_emitted`, and the measured `readout edge` cases |
| Visual banking cannot move the damage Core (ENGINEERING_BRIEF 4.B "Key boundary") | `test_the_model_holds_no_position_state`, `test_bank_angle_is_level_in_forward_flight_and_leans_with_lateral_motion`, `test_bank_angle_is_clamped_and_follows_the_camera`, and `test_banking_moves_the_visuals_and_leaves_the_combat_volumes_alone`, which forces a roll and checks that `DamageCore`, `GrazeVolume` and `Muzzle` do not move while `VisualRoot/EngineL` does |
| The input actions reach the core, on the axes CONVENTIONS "Input actions" names | `test_the_input_actions_drive_the_body_through_the_core`, and the six measured single-axis cases |
| An owner can take the controls away and get them back | `test_disabled_controls_ignore_the_input_and_hold_the_ship_still`, `test_focus_changed_reports_the_edges_of_the_focus_input` |
| Respawn carries no motion over | `test_reset_to_teleports_the_ship_and_clears_its_motion` |
| A scene missing a reference fails loudly instead of running half-configured (CONVENTIONS "Setup errors are loud") | `test_a_missing_visual_root_is_reported_and_stops_the_adapter` |
| The body wiring Claude owns stays as documented | `test_root_is_a_player_controller_with_the_authored_body_wiring`, `test_required_exports_resolve_to_the_authored_nodes` |
| Camera-relative movement follows the rig, not the world axes (PLANEJAMENTO Section 3) | `test_forward_input_follows_the_camera_yaw_instead_of_the_world_axis`, `test_get_yaw_is_finite_and_is_the_rig_node_rotation`, and the measured `camera-relative forward` case. Mutation-checked: making `_camera_yaw()` return 0 fails the first one and nothing else |
| Stable horizon: the camera never rolls, in any state (ENGINEERING_BRIEF 4.B) | `test_the_horizon_stays_level_in_every_state` (at rest, with the body pitched, turned and rolled, while orbiting, while locked, after release), plus a roll assertion on every measured camera case |
| The camera follows the body's position and not its rotation | `test_the_rig_follows_the_body_position_but_not_its_rotation`, `test_the_authored_rig_places_the_authored_camera` (which pins `top_level`) |
| The rest pose is the authored camera (GUIDE Section 13) | `test_the_rig_rests_behind_and_above_the_ship`, and the measured `camera rest offset` and `camera rest pitch` cases |
| The `camera_*` actions orbit at the authored rate and stop at the pitch limits | `test_the_camera_actions_orbit_the_rig`, and the measured `orbit yaw`, `orbit pitch`, `pitch ceiling` and `pitch floor` cases |
| The vertical camera axis can be inverted (PLANEJAMENTO Section 7) | `test_apply_settings_inverts_the_vertical_orbit` |
| A Target Lock frames ship and target together, and a release does not snap (PLANEJAMENTO Section 3) | `test_the_lock_framing_turns_the_yaw_toward_the_target`, `test_clearing_the_lock_returns_to_follow_mode`, and the measured `lock Low`, `lock Middle` and `lock High` cases, which check the aim, both ends in view and the roll at three target heights |
| Scenery between ship and camera shortens the rig and lets it back out (ENGINEERING_BRIEF 4.B) | `test_scenery_between_the_ship_and_the_camera_shortens_the_rig`. Mutation-checked: a ray on mask 0 fails it with 9.08 against the expected 3.63 |
| A rig missing its camera fails loudly instead of running half-configured | `test_a_missing_camera_is_reported_and_stops_the_rig` |
| A fresh lock prefers visible targets near the screen center, not the nearest one (PLANEJAMENTO Section 3) | `test_best_pick_is_the_candidate_nearest_the_screen_center_not_the_nearest_in_distance`, `test_distance_breaks_a_tie_in_screen_offset`, and the measured `lock_target acquires Middle` case, whose expectation was worked by hand from GUIDE Section 13's positions |
| Hidden, out-of-range and off-center targets are never freshly locked | `test_invisible_candidates_are_never_selected`, `test_candidates_beyond_range_are_never_selected`, `test_a_fresh_lock_never_lands_outside_the_screen_radius`, `test_configure_values_are_the_ones_the_selector_uses`, `test_an_empty_list_selects_nothing` |
| `next_target` visits every visible target in range once, left to right, before wrapping, including while the camera turns to each new lock | `test_select_next_visits_every_visible_candidate_in_range_once_left_to_right_before_wrapping`, `test_select_next_reaches_visible_targets_outside_the_screen_radius`, `test_select_next_with_one_candidate_returns_the_same_id`, `test_select_next_falls_back_to_the_best_pick_when_the_current_target_is_not_in_the_ring`, `test_next_target_visits_all_three_before_wrapping_while_the_camera_follows`, and the measured `next_target visits all three` case |
| The lock is invalidated by target death and by range, and by nothing else (PLANEJAMENTO Section 3, ENGINEERING_BRIEF 4.B "target disappearance") | `test_validate_is_false_when_the_current_target_is_missing_or_beyond_range`, `test_validate_holds_a_lock_that_is_merely_occluded_or_off_screen`, `test_lock_target_acquires_one_of_the_three_and_freeing_it_releases_within_one_tick`, `test_a_target_that_leaves_range_releases_the_lock`, and the measured flown range release |
| Scenery hides targets from a fresh lock but does not drop a held one (ENGINEERING_BRIEF 4.B "scenery occlusion") | `test_scenery_hides_targets_from_acquisition_but_does_not_drop_a_held_lock`, and the measured shrine-gate case |
| `target_changed` reports changes, not ticks | `test_target_changed_fires_once_per_change_and_not_for_the_same_id` |
| The adapter describes the scene the way the core expects: one candidate per target, instance ids, distance from the ship, normalized y-down offsets | `test_the_adapter_builds_one_candidate_per_arena_target`, `test_a_target_without_a_hit_volume_is_skipped` |
| The ship's camera frames whatever its targeting locks | `test_the_ship_frames_the_target_its_targeting_locks`, `test_the_ship_carries_a_wired_targeting_adapter`, and the three measured `lock ... reached the rig and the readout` cases |
| A targeting adapter missing its camera fails loudly | `test_a_missing_camera_is_reported_and_stops_the_adapter` |

The F1-04 tests were checked by mutation, each one caught by the test named: dropping the distance tie-break, ignoring visibility, letting `validate` drop an occluded lock, keeping the screen radius in the switch ring, emitting on every `set_current`, ordering the ring by angle, returning `NO_TARGET` instead of falling back, skipping `validate` in the adapter (caught by the free and range tests), casting the occlusion ray on mask 0, measuring distance from the camera instead of the ship, and removing the ship's `target_changed` connection.

Manual and measured results, with screenshots, are in [docs/validation/player-flight.md](../validation/player-flight.md).

## Setup for Astra

`PlayerShip` in `scenes/player/player_ship.tscn` is wired and needs nothing new. What changed for you:

- The root node now carries real exported values instead of `metadata/base_speed` and `metadata/focus_multiplier`, which were removed. Tune `base_speed`, `focus_multiplier`, `edge_margin`, `max_bank_angle_degrees` and `bank_smoothing` in the Inspector under **Flight values**; they take effect on the next run, and the contract test pins 12.0 and 0.45 as the authored pair, so tell Claude if you change those two.
- Under **Scene references**, `visual_root`, `camera_rig`, `damage_core`, `graze_volume` and, since F1-04, `targeting` point at `VisualRoot`, `CameraRig`, `DamageCore`, `GrazeVolume` and `Targeting`. Renaming or moving one of those nodes breaks the reference; the game then prints `PlayerShip: required export '<field>' is not set` and the ship does not move at all.
- Keep `DamageCore`, `GrazeVolume` and `Muzzle` outside `VisualRoot`. Banking rolls `VisualRoot`, and anything under it rolls with it.
- The root also carries `motion_mode = 1` (floating) with collision layer 2 and mask 1. Those are Claude's wiring; ask instead of editing them.
- `scenes/dev/arena_harness.tscn` is Claude's dev scene. It instances your `combat_arena.tscn` untouched and adds a debug readout on top. Run that scene, not the arena, when you want to fly. Since F1-03 the readout also shows the camera's yaw, pitch, roll and distance from the ship. Since F1-04 `K` / `Y` locks and releases and `Tab` / `X` switches through the ship's real `Targeting`, and the last readout line shows the locked target and its distance against the 60-unit range; the harness's own stand-in is gone.
- `PlayerShip/Targeting` now carries the `Targeting` script's values: `camera` points at `../CameraRig/Camera3D`. `max_distance` 60, `max_screen_radius` 0.85, `occlusion_mask` layer 1 and `group_name` `targetable` are at their defaults, so the scene file does not list them; they show in the Inspector under **Selection** and are yours to tune.
- Every target — the arena markers today, every enemy prefab from F9 — must be a `Node3D` in the `targetable` group with a child named `HitVolume` (any `Node3D`, the `Area3D` in practice): that is the point the screen position, the distance and the occlusion ray are measured to. A group member without one is skipped, with one warning naming it. Keep the target's own volumes off layer 1, or it hides itself.
- Only scenery with collision on layer 1 hides a target. The arena's trees, lanterns and backdrop peaks are meshes without collision, so a target behind a tree stays visible to targeting; the shrine gate, the floor and the walls are what can hide one there. Trees that should block Aim Assist and acquisition in the stages need layer-1 collision.
- `PlayerShip/CameraRig` now carries the `CameraRig` script's values: `camera` points at `Camera3D`, and `follow_distance` 8.5 and `follow_height` 3.2 are your authored camera offset moved onto the rig. The `Camera3D` node keeps its authored transform as the documented rest pose, but the rig writes that transform every frame at runtime, so moving the camera node in the editor no longer changes where the camera sits — change `follow_distance`, `follow_height` and `default_pitch_degrees` instead. Its FOV, near and far are still yours and are not touched.
- The rig sets `top_level` on itself at run time, which is why the camera does not roll with the banking ship. Do not clear it.
- `tools/build_scene_handoff.py` no longer reproduces the integrated `player_ship.tscn`: it still writes the two retired `metadata/*` entries and none of the `PlayerShip` exports, its `node_paths` marker or `motion_mode`, and since F1-03 none of the `CameraRig` exports or its own `node_paths` marker either. Since F1-04 it also misses `"targeting"` in the root's `node_paths` marker, the root's `targeting = NodePath("Targeting")`, and the `Targeting` node's `node_paths=PackedStringArray("camera")` with `camera = NodePath("../CameraRig/Camera3D")`. Reconcile it before any rerun (GUIDE Section 9 step 0), or the ship loses its wiring and the camera stops working.

## Open issues

- `edge_margin` 4.0 and `max_bank_angle_degrees` 25.0 are still Claude's proposals; no design document fixes them. They are now visible: the feedback reads 0.75 one unit from a face and the roll is 24.5 degrees at full lateral speed. Astra tunes them.
- The Flight Volume is the rectangular `AABB` Astra authored, but the Stage 1 platform is a circle of radius 39 centered at (0, 0, -6), so the rectangle's corners are open void inside the playable volume. Measured: past the rim the clamp is the only floor and holds the ship at y 0 over nothing, with the edge feedback at 1.0 ([screenshot](../validation/player-flight-clamp.png)). It is consistent, not pretty. Whether the volume should become a cylinder, or the scenery should fill the corners, is Astra's call.
- A three-axis diagonal is bounded by its speed but not split evenly between the axes: `Input.get_vector` normalizes the horizontal pair before the model clamps the whole 3D vector, so holding forward, right and ascend gives (0.5, 0.707, -0.5) × `base_speed` — the vertical axis keeps the larger share. Total speed is exactly 12.0, which is the invariant the brief fixes. If the ascent should not dominate, the input layer has to read the two horizontal axes separately and let the 3D clamp do all the work; that is a feel decision, not a bug.
- ~~F1-03 must keep the camera rig's yaw in the rig node's own rotation~~ — decided and closed by F1-03: the yaw lives in the rig node's `global_rotation.y`, `get_yaw()` publishes it, `_camera_yaw()` calls `get_yaw()`, the export is typed `CameraRig`, and the round trip is pinned by a test and by a measured case. See "The yaw, and why it lives in a node rotation" above.
- The camera framing values are Claude's proposals except `follow_distance` and `follow_height`, which are Astra's authored camera offset. `default_pitch_degrees` -9, the (-60, 35) pitch limits, 120 degrees per second of orbit, the three damping rates and `obstruction_margin` 0.4 are all first guesses that no design document fixes. They are visible in the Inspector and in the harness readout; Astra tunes them.
- The obstruction rule has no minimum distance. Turned into the west wall with the ship parked against it, the camera collapses to 0.75 units from the ship and the hull fills the frame ([screenshot](../validation/player-flight-camera-obstruction.png)). The remedies are a distance floor below which the camera stops shortening, or the ship transparency PLANEJAMENTO Section 3 already anticipates ("the ship may become partially transparent when it obscures bullets near the vulnerable core"). Neither is in F1-03's scope; the second belongs with the ship material, which is Astra's.
- Entering an obstruction is a snap, not an ease: that is the rule the ticket fixes, because easing in would put the camera inside the geometry for those frames. Measured under the shrine gate, the shortening is a single-frame change of 6.5 units. A swept sphere instead of a ray, or a shorten rate cap, would trade that pop for some clipping; it is a feel decision and needs Astra's eyes on it before anyone spends the frames.
- A teleport sweeps the camera. `PlayerController.reset_to` moves the body instantly and the rig's pivot follows instantly, but the camera position is eased, so a respawn or checkpoint restore flies the camera across the arena over about half a second. Nothing calls `reset_to` in anger yet; F7 and F10 will, and whoever wires them should ask the rig for a snap.
- `damage_core` and `graze_volume` are validated but unread until F5 and F7 use them. They are required now so the scene fails loudly at the handoff rather than in a later ticket.
- The pad bindings are still proven only by `tests/unit/project/test_input_map.gd` and by simulated actions, which ENGINEERING_BRIEF Section 8 explicitly says is not the same thing. What F1-03 added is the device fact: `tools/validate_player_flight.gd` now prints the connected joypads, and on the F1-03 run this host had `0:DualSense Wireless Controller` with Godot reporting a standard mapping, so the Xbox-named bindings of CONVENTIONS "Input actions" do land on real buttons. On the F1-04 runs no joypad was connected at all. Nobody has pressed them. A human pass on keyboard and on that pad — flight, Focus, the right stick, `K`/`Y` to lock and release, `Tab`/`X` to switch — is owed by F1-02, F1-03 and F1-04.
- `max_distance` 60 and `max_screen_radius` 0.85 are the F1-04 ticket's proposals; no design document fixes them. Measured in the arena, 60 is reachable: flying away from a lock on Middle releases it at 60.05 near the far corner. Astra tunes both.
- Occlusion is one ray to the `HitVolume` center, so a target counts as hidden the moment its center is, even with part of it still in view. Behind the shrine gate the ray hits the beam while Middle's ring still shows above and below it ([screenshot](../validation/player-flight-targeting-occluded.png)). It does not matter for a held lock, which ignores occlusion; for a fresh lock it errs on the side of not picking a half-hidden target. Several rays to the shape's extremes would fix it if a boss turns out to be hard to acquire behind thin scenery.
- `next_target` can land on a target past the screen edge — in front of the camera, in range and unoccluded, but not on screen — and the camera then turns to it. That is deliberate (see "The rules"), and it is what lets the player reach the target on the far side of a wide spread; if it reads badly with real enemies, the fix is a second, wider radius for the ring, not the acquisition radius.
- Aim Assist (F6-03) will want "the best visible target near the center" without a lock. `select_best` over `build_candidates()` is already that question; F6-03 should call it rather than add a second rule, and decide then whether it runs every shot or reuses the adapter's tick.
- Nothing releases the lock when an owner takes the controls away. `set_controls_enabled(false)` stops flight input, but `Targeting` keeps reading `lock_target` and `next_target`, and a lock held at defeat or at a stage transition stays held. Pausing is fine, because the ship stops processing with its root. Whoever wires defeat and transitions (F7, F10) decides whether those should release it.
- The clamp does not cancel the velocity that pushed into a face, and measurement found no jitter: the ship rests at exactly x -38.000 against the west wall, y 0.400 on the platform and y 0.000 on the clamped floor. Because floating mode leaves `velocity` alone, a blocked ship still reports the commanded speed; if a HUD ever needs ground speed it should measure position change instead.
