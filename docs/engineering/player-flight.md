# Player flight

The player's movement rules and the ship that obeys them, started with ticket F1-01 on 2026-09-21 and extended by F1-02 on 2026-09-22. `FlightModel` and `PlayerController` are both CODE_READY; the camera rig and targeting arrive with F1-03 and F1-04, and this page grows with them.

## Purpose

`FlightModel` owns how input axes and a camera yaw become a velocity: camera-relative horizontal movement with a world-vertical axis, bounded diagonal speed, the Focus speed factor, the Flight Volume limit, the edge-proximity value used for boundary feedback, and the visual bank angle.

`PlayerController` is the Adapter that gives those rules a body: it reads the sixteen input actions, asks the camera rig for its yaw, drives the core, moves the `CharacterBody3D` against scenery, banks `VisualRoot`, and exposes control enable, reset and edge feedback to whoever owns the ship.

Between them they deliberately do not own the camera's own behavior (F1-03), Target Lock (F1-04), the weapon, or anything that reads the damage Core. The core never integrates and never touches a Node; the adapter never decides a movement rule.

## Files

- `scripts/player/flight_model.gd` (Rules Core, `class_name FlightModel extends RefCounted`).
- `scripts/player/player_controller.gd` (Adapter, `class_name PlayerController extends CharacterBody3D`, attached to `PlayerShip` in `scenes/player/player_ship.tscn`).
- `tests/unit/player/test_flight_model.gd` (18 tests) and `tests/scene/test_player_ship_contract.gd` (10 tests).
- `scenes/dev/arena_harness.tscn` and `scenes/dev/arena_harness.gd` (dev only: the scene to run while flying, and the stand-in owner until F2-04).
- `tools/validate_player_flight.gd` (offline flight QA: drives the harness with simulated input, measures it, writes the screenshots in `docs/validation/player-flight.md`).

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
| `camera_rig` | Node3D | `CameraRig` | yes | Yaw source for camera-relative movement. |
| `damage_core` | Area3D | `DamageCore` | yes | Projectile damage volume. Not read yet; F7 owns damage. |
| `graze_volume` | Area3D | `GrazeVolume` | yes | Near-miss volume. Not read yet; F5 owns graze. |

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

## Dependencies

The core imports nothing, holds no Node, and is constructed with `FlightModel.new()` by the adapter, which injects the authored values through `configure()` and the Flight Volume through `set_bounds()`.

The adapter depends on four scene nodes through its exports, on the input actions in `project.godot`, and on the camera rig for one number: `camera_rig.global_rotation.y`. It is driven by an owner that calls `setup()`, and optionally `set_controls_enabled()` and `reset_to()`. Nothing calls up: the adapter's two signals are the only way out.

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

Manual and measured results, with screenshots, are in [docs/validation/player-flight.md](../validation/player-flight.md).

## Setup for Astra

`PlayerShip` in `scenes/player/player_ship.tscn` is wired and needs nothing new. What changed for you:

- The root node now carries real exported values instead of `metadata/base_speed` and `metadata/focus_multiplier`, which were removed. Tune `base_speed`, `focus_multiplier`, `edge_margin`, `max_bank_angle_degrees` and `bank_smoothing` in the Inspector under **Flight values**; they take effect on the next run, and the contract test pins 12.0 and 0.45 as the authored pair, so tell Claude if you change those two.
- Under **Scene references**, `visual_root`, `camera_rig`, `damage_core` and `graze_volume` point at `VisualRoot`, `CameraRig`, `DamageCore` and `GrazeVolume`. Renaming or moving one of those nodes breaks the reference; the game then prints `PlayerShip: required export '<field>' is not set` and the ship does not move at all.
- Keep `DamageCore`, `GrazeVolume` and `Muzzle` outside `VisualRoot`. Banking rolls `VisualRoot`, and anything under it rolls with it.
- The root also carries `motion_mode = 1` (floating) with collision layer 2 and mask 1. Those are Claude's wiring; ask instead of editing them.
- `scenes/dev/arena_harness.tscn` is Claude's dev scene. It instances your `combat_arena.tscn` untouched and adds a debug readout on top. Run that scene, not the arena, when you want to fly.
- `tools/build_scene_handoff.py` no longer reproduces the integrated `player_ship.tscn`: it still writes the two retired `metadata/*` entries and none of the exports, the `node_paths` marker or `motion_mode`. Reconcile it before any rerun (GUIDE Section 9 step 0), or the ship loses its wiring.

## Open issues

- `edge_margin` 4.0 and `max_bank_angle_degrees` 25.0 are still Claude's proposals; no design document fixes them. They are now visible: the feedback reads 0.75 one unit from a face and the roll is 24.5 degrees at full lateral speed. Astra tunes them.
- The Flight Volume is the rectangular `AABB` Astra authored, but the Stage 1 platform is a circle of radius 39 centered at (0, 0, -6), so the rectangle's corners are open void inside the playable volume. Measured: past the rim the clamp is the only floor and holds the ship at y 0 over nothing, with the edge feedback at 1.0 ([screenshot](../validation/player-flight-clamp.png)). It is consistent, not pretty. Whether the volume should become a cylinder, or the scenery should fill the corners, is Astra's call.
- A three-axis diagonal is bounded by its speed but not split evenly between the axes: `Input.get_vector` normalizes the horizontal pair before the model clamps the whole 3D vector, so holding forward, right and ascend gives (0.5, 0.707, -0.5) × `base_speed` — the vertical axis keeps the larger share. Total speed is exactly 12.0, which is the invariant the brief fixes. If the ascent should not dominate, the input layer has to read the two horizontal axes separately and let the 3D clamp do all the work; that is a feel decision, not a bug.
- F1-03 must keep the camera rig's yaw in the rig node's own rotation, because `PlayerController._camera_yaw()` reads `camera_rig.global_rotation.y`. A rig that stores its yaw elsewhere has to change that one line, and the export's type becomes the `CameraRig` class then.
- `damage_core` and `graze_volume` are validated but unread until F5 and F7 use them. They are required now so the scene fails loudly at the handoff rather than in a later ticket.
- No physical gamepad on this host: the pad bindings are proven only by `tests/unit/project/test_input_map.gd` and by simulated actions, which ENGINEERING_BRIEF Section 8 explicitly says is not the same thing. A controller pass is still owed.
- The clamp does not cancel the velocity that pushed into a face, and measurement found no jitter: the ship rests at exactly x -38.000 against the west wall, y 0.400 on the platform and y 0.000 on the clamped floor. Because floating mode leaves `velocity` alone, a blocked ship still reports the commanded speed; if a HUD ever needs ground speed it should measure position change instead.
