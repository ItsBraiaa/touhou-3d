# Player flight

The player's movement rules, started with ticket F1-01 on 2026-09-21. `FlightModel` is CODE_READY; the adapter, the camera rig and targeting arrive with F1-02, F1-03 and F1-04, and this page grows with them.

## Purpose

Owns how input axes and a camera yaw become a velocity: camera-relative horizontal movement with a world-vertical axis, bounded diagonal speed, the Focus speed factor, the Flight Volume limit, the edge-proximity value used for boundary feedback, and the visual bank angle.

It deliberately does not own reading the input map, `CharacterBody3D` and `move_and_slide`, the camera, Target Lock, or anything about the damage Core. It never integrates: the adapter multiplies the returned velocity by its own `delta`.

## Files

- `scripts/player/flight_model.gd` (Rules Core, `class_name FlightModel extends RefCounted`).
- `tests/unit/player/test_flight_model.gd` (18 tests).
- `scripts/player/player_controller.gd` (Adapter, attached to `PlayerShip` in `scenes/player/player_ship.tscn`): still Astra's placeholder, filled by F1-02.

## Public contract

### Exports (Adapter)

F1-02. The values the adapter will pass to `configure()` and `set_bounds()` are authored in GUIDE.md Section 13: `base_speed` 12.0, `focus_multiplier` 0.45, and the FlightBounds min (-39, 0, -45) to max (39, 30, 33). The ticket for that adapter proposes `edge_margin` 4.0 and `max_bank_angle_degrees` 25.0, which no design document has fixed yet.

### Signals

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `edge_proximity_changed` | `value: float` | `edge_proximity()` computes a value more than `EDGE_PROXIMITY_EPSILON` (0.01) away from the last one that was emitted. The remembered value moves only on an emission, so a drift below the threshold still reports once it adds up to one. It starts at 0.0, so a ship that spawns away from every face is silent on its first tick. |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `configure(base_speed: float, focus_multiplier: float, edge_margin: float) -> void` | Adapter `_ready` | Stores the authored flight values. Until it is called `base_speed` is 0.0, so the model reports no movement. |
| `set_bounds(bounds: AABB) -> void` | Adapter `_ready`, and the Stage Director when the active Encounter changes | Sets the Flight Volume. An `AABB` is a position and a size, not two corners: a caller holding a min and a max passes `AABB(min, max - min)`. |
| `compute_velocity(move: Vector2, vertical: float, focus: bool, camera_yaw: float) -> Vector3` | Adapter `_physics_process` | World velocity in units per second. `move.x` is strafe (right positive), `move.y` is forward (positive forward), `vertical` is ascend positive; all three are already dead-zoned and in [-1, 1]. The 3D input vector is clamped to length 1 before being scaled, so a full three-axis diagonal still flies at `base_speed`. The horizontal part is rotated by `camera_yaw` around world Y and the vertical part is world Y, which keeps the horizon stable. Pure: no delta, no stored state. |
| `clamp_position(position: Vector3) -> Vector3` | Adapter `_physics_process`, after `move_and_slide` | The nearest point inside the Flight Volume, or `position` unchanged while no bounds have been set. |
| `edge_proximity(position: Vector3) -> float` | Adapter `_physics_process` | 0 while farther than `edge_margin` from every face, rising linearly to 1 at the nearest face, and 1 outside. 0 while no bounds or no margin have been configured. Emits `edge_proximity_changed` as described above. |
| `bank_angle(velocity: Vector3, camera_yaw: float, max_angle: float) -> float` | Adapter `_process` | Roll for `VisualRoot`, in radians, from the part of `velocity` that is lateral to the camera, clamped to ± `max_angle`. Negative leans into a turn to the ship's right, which is the sign `VisualRoot.rotation.z` needs for the right wing to dip while the nose points at -Z. Visual only: nothing in the model can move the ship, and Focus leans less because it flies slower. |

## Dependencies

None. The core imports nothing, holds no Node, and is constructed with `FlightModel.new()` by the adapter, which injects the authored values through `configure()` and the Flight Volume through `set_bounds()`.

## Invariants and tests

| Invariant | Test |
| --- | --- |
| The authored values reach the model, rather than being hardcoded in it | `test_configure_values_are_the_ones_the_model_uses` |
| Frame-rate-independent movement (ENGINEERING_BRIEF 4.B, Section 8 "Movement normalization") | `test_integration_is_frame_rate_independent` |
| Bounded diagonal speed: three full axes still fly at `base_speed`, not `base_speed * sqrt(3)` (4.B) | `test_full_diagonal_on_three_axes_is_bounded_to_base_speed`, and `test_partial_input_keeps_its_magnitude` for the other direction |
| Focus scales every axis by 45 % (PLANEJAMENTO Section 4) | `test_focus_scales_every_axis_by_the_focus_multiplier` |
| Stable horizon: yaw rotates the horizontal plane only, ascent is world-vertical (PLANEJAMENTO Section 3) | `test_camera_yaw_rotates_the_horizontal_plane_only`, `test_vertical_input_ignores_camera_yaw` |
| The ship stays inside the Flight Volume (CONVENTIONS "Collision") | `test_clamp_position_keeps_points_inside_and_pulls_points_outside_to_the_nearest_face`, `test_clamp_position_is_identity_before_bounds_are_set` |
| Boundary feedback rises only near a face and reports events, not every tick (PLANEJAMENTO Section 3) | `test_edge_proximity_is_zero_at_the_center_and_one_at_a_face`, `test_edge_proximity_is_zero_without_bounds`, `test_edge_proximity_changed_fires_once_per_real_change`, `test_edge_proximity_changed_measures_drift_from_the_last_value_emitted` |
| Visual banking cannot move the damage Core (ENGINEERING_BRIEF 4.B "Key boundary") | `test_the_model_holds_no_position_state`, which walks `get_property_list()` and rejects any script variable of a position type, plus `test_bank_angle_is_level_in_forward_flight_and_leans_with_lateral_motion` and `test_bank_angle_is_clamped_and_follows_the_camera` |

## Setup for Astra

Nothing yet. `FlightModel` is code-only and is never attached to a node. The exported values and the scene wiring arrive with F1-02, and this section is filled then.

## Open issues

- `edge_margin` and `max_angle` are proposals, not authored values: F1-02 exports 4.0 units and 25 degrees, the tests use 4.0 and 0.6 rad as their own fixtures, and neither number appears in PLANEJAMENTO or GUIDE. Astra tunes them once the feedback is on screen.
- The Flight Volume is a rectangular `AABB`, but the Stage 1 platform is a circle of radius 39 centered at (0, 0, -6), so the clamp allows the four corners the scenery does not fill (GUIDE Section 13). Whether that matters is an F1-02 question, decided against the real arena.
- The core clamps a position; it does not cancel the velocity that pushed into the face. If `move_and_slide` plus the clamp jitters against a wall, the fix belongs to the adapter or to a follow-up on this core.
- The bank sign is derived from "nose faces -Z, bank `VisualRoot` only" (GUIDE Section 13) and has not been seen on screen yet. F1-02 confirms it visually.
