# F1-03 Camera rig

Status: todo
Type: adapter
parallel-safe: no
Depends on: F1-02

## Goal

`camera_rig.gd` follows behind the ship with a stable horizon, lets the player orbit with the camera actions, frames both ship and Target Lock while locked, shortens against scenery, and returns smoothly to follow mode on release. It exposes its yaw to `PlayerController`.

## Read first

- `docs/PLANEJAMENTO.md` Section 3 (camera rules), Section 7 settings (sensitivity, invert vertical)
- `docs/ENGINEERING_BRIEF.md` Section 4.B ("stable horizon", "camera behavior near geometry", "should not require continuously correcting an unstable camera")
- `docs/GUIDE.md` Section 5 "Player" (CameraRig owns Camera3D), Section 6 row `camera_rig.gd`, Section 13 camera values (0, 3.2, 8.5), pitch -0.16 rad, FOV 68
- `docs/engineering/CONVENTIONS.md`: "Setup errors", "Time and randomness" (`_process` interpolates visuals)

## Deliverables

`scripts/player/camera_rig.gd`, `class_name CameraRig extends Node3D`.

### Exports

`camera: Camera3D` (required), `follow_distance: float = 8.5`, `follow_height: float = 3.2`, `default_pitch_degrees: float = -9.0`, `pitch_limits_degrees: Vector2 = Vector2(-60, 35)`, `orbit_speed_degrees: float = 120.0`, `sensitivity: float = 1.0`, `invert_vertical: bool = false`, `position_damping: float = 10.0`, `rotation_damping: float = 8.0`, `lock_blend_speed: float = 4.0`, `obstruction_margin: float = 0.4`, `collision_mask: int = 1`.

### Behavior

- The rig is a child of `PlayerShip` but must not inherit the body's rotation: set `top_level = true` in `_ready` and follow `get_parent()` position explicitly. Never roll: the camera basis is rebuilt from yaw and pitch each frame.
- Follow mode: yaw and pitch change only from `camera_*` actions (times sensitivity, with `invert_vertical` on pitch). Target position is ship position plus the offset rotated by yaw/pitch; smooth with `position_damping`.
- Lock mode (`set_lock_target(target: Node3D)` / `clear_lock_target()`): the yaw eases toward the direction from ship to target; pitch eases so both ship and target stay in view (aim at the midpoint, clamped by pitch limits). Orbit input is still honored as an offset while locked so the player can look around. Blend in and out over `lock_blend_speed`.
- Obstruction: each physics tick cast a ray (or `PhysicsDirectSpaceState3D.intersect_ray`) from the ship toward the desired camera position on `collision_mask`; if hit, place the camera at the hit point minus `obstruction_margin`. Ease back out.
- `func get_yaw() -> float` used by `PlayerController`.
- `apply_settings(sensitivity: float, invert_vertical: bool)` for F3.
- Camera stays `current = true` as authored.

No Rules Core: the behavior is engine-bound. Keep math in small private functions so it is readable.

## Tests required

- `tests/scene/test_camera_rig_contract.gd`: rig instantiates headless; `get_yaw()` returns a finite value; after `set_lock_target` with a dummy Node3D placed at +X, several `_physics_process` calls move the yaw toward that direction; `clear_lock_target` restores follow mode. Roll (`camera.global_transform.basis.get_euler().z`) stays 0 in every state.
- Manual checklist recorded in `docs/validation/player-flight.md`: orbit each arena target at low, middle, and high altitude on keyboard and gamepad; fly under the shrine gate and confirm the camera shortens without popping; lock and release feel smooth; no horizon tilt at any time.

## Out of scope

Target selection (F1-04), HUD marker, settings persistence.

## Definition of Done

- Tests green; manual checklist recorded with both input devices.
- GUIDE Section 6 row and Section 13 camera values updated to the exports.
- `docs/engineering/player-flight.md` camera section filled.
- Handoff log entry; commit `player: implement CameraRig follow, orbit, lock framing, obstruction`.

## Handoff notes for Astra

Framing defaults are exports on `CameraRig`; tune them in the Inspector. If an authored space makes the camera clip, prefer adjusting `obstruction_margin` or the geometry over changing the code.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/player-flight/issues/03-camera-rig.md, then implement that ticket. Use /run to test in the dev harness on keyboard and gamepad. Finish with its Definition of Done and commit.
```
