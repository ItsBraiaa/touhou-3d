# F1-01 FlightModel core

Status: done
Type: core
parallel-safe: yes
Depends on: F0-02

## Goal

A Node-free `FlightModel` that turns input axes and a camera yaw into a velocity, clamps the ship inside the Flight Volume, reports edge proximity for feedback, and computes a visual bank angle that has no effect on position.

## Read first

- `CONTEXT.md`: Focus, Flight Volume, Core
- `docs/engineering/CONVENTIONS.md`: "Architecture rules", "Time and randomness", "Tests"
- `docs/adr/0001-gameplay-rules-in-node-free-cores.md`
- `docs/PLANEJAMENTO.md` Section 3 (camera-relative horizontal, world-vertical ascent, no roll control) and Section 4 "Focus and vulnerable core" (45 % speed)
- `docs/ENGINEERING_BRIEF.md` Section 4.B "Must solve" and "Key boundary"
- `docs/GUIDE.md` Section 13 "Authored player values" (base_speed 12.0, focus_multiplier 0.45, FlightBounds min (-39, 0, -45) max (39, 30, 33))

## Deliverables

`scripts/player/flight_model.gd`, `class_name FlightModel extends RefCounted`.

### Contract

- `func configure(base_speed: float, focus_multiplier: float, edge_margin: float) -> void`
- `func set_bounds(bounds: AABB) -> void`
- `func compute_velocity(move: Vector2, vertical: float, focus: bool, camera_yaw: float) -> Vector3`
  - `move.x` is strafe (right positive), `move.y` is forward (positive = forward). `vertical` is ascend positive, descend negative. All inputs already dead-zoned by the adapter, each in [-1, 1].
  - Horizontal direction is rotated by `camera_yaw` around world Y only (stable horizon). Vertical is world Y.
  - The combined 3D input vector is clamped to length 1 before scaling (bounded diagonal speed), then multiplied by `base_speed`, and by `focus_multiplier` when `focus` is true.
  - Pure function: same inputs, same output; no delta involved.
- `func clamp_position(position: Vector3) -> Vector3` clamps into the bounds (identity when no bounds set).
- `func edge_proximity(position: Vector3) -> float` returns 0 when farther than `edge_margin` from every face, rising linearly to 1 at a face. Also emits `edge_proximity_changed(value: float)` only when the value changes by more than 0.01.
- `func bank_angle(velocity: Vector3, camera_yaw: float, max_angle: float) -> float` returns the roll to apply to `VisualRoot` from lateral velocity, in radians, clamped to `± max_angle`. Documented as visual-only.

### Tests

`tests/unit/player/test_flight_model.gd`:

- Zero input gives zero velocity, with and without Focus.
- Single-axis full input gives speed exactly `base_speed` on that axis.
- Full diagonal input on three axes gives a velocity of length `base_speed`, not `base_speed * sqrt(3)`.
- Focus scales every axis by `focus_multiplier`.
- Camera yaw of 90 degrees turns forward input into world -X or +X consistently; vertical input is unaffected by yaw.
- Integration over 60 ticks of 1/60 covers the same distance as 30 ticks of 1/30 (frame-rate independence when the adapter integrates `velocity * delta`).
- `clamp_position` returns the input inside bounds and the nearest face point outside.
- `edge_proximity` is 0 at the center, 1 on a face, 0.5 at half the margin; the signal fires once for a change and not for a repeated value.
- `bank_angle` is 0 for pure forward flight, positive or negative for lateral motion, clamped at the maximum, and never changes any position (test that the model has no position state at all).

## Out of scope

Input reading, `CharacterBody3D`, camera, targeting.

## Definition of Done

- Tests green through `tools/test.ps1`.
- `docs/engineering/player-flight.md` started (Purpose, contract for `FlightModel`; the adapter section is filled by F1-02).
- Roadmap row updated, handoff log entry, commit `player: add FlightModel core`.

## Handoff notes for Astra

None yet. Exports arrive with F1-02.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/player-flight/issues/01-flight-model-core.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
