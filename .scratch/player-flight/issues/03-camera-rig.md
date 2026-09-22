# F1-03 Camera rig

Status: done
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
- `docs/engineering/player-flight.md`: the `PlayerController` contract this rig plugs into, and its open issues
- `docs/validation/player-flight.md`: how F1-02 was measured; this ticket's manual checklist extends that page
- `scenes/dev/arena_harness.tscn`: the scene to run while flying, not `combat_arena.tscn` directly

## Deliverables

`scripts/player/camera_rig.gd`, `class_name CameraRig extends Node3D`.

### Exports

`camera: Camera3D` (required), `follow_distance: float = 8.5`, `follow_height: float = 3.2`, `default_pitch_degrees: float = -9.0`, `pitch_limits_degrees: Vector2 = Vector2(-60, 35)`, `orbit_speed_degrees: float = 120.0`, `sensitivity: float = 1.0`, `invert_vertical: bool = false`, `position_damping: float = 10.0`, `rotation_damping: float = 8.0`, `lock_blend_speed: float = 4.0`, `obstruction_margin: float = 0.4`, `collision_mask: int = 1`.

### Behavior

- The rig is a child of `PlayerShip` but must not inherit the body's rotation: set `top_level = true` in `_ready` and follow `get_parent()` position explicitly. Never roll: the camera basis is rebuilt from yaw and pitch each frame.
- Follow mode: yaw and pitch change only from `camera_*` actions (times sensitivity, with `invert_vertical` on pitch). Target position is ship position plus the offset rotated by yaw/pitch; smooth with `position_damping`.
- Lock mode (`set_lock_target(target: Node3D)` / `clear_lock_target()`): the yaw eases toward the direction from ship to target; pitch eases so both ship and target stay in view (aim at the midpoint, clamped by pitch limits). Orbit input is still honored as an offset while locked so the player can look around. Blend in and out over `lock_blend_speed`.
- Obstruction: each physics tick cast a ray (or `PhysicsDirectSpaceState3D.intersect_ray`) from the ship toward the desired camera position on `collision_mask`; if hit, place the camera at the hit point minus `obstruction_margin`. Ease back out.
- `func get_yaw() -> float` used by `PlayerController` — see the yaw contract below, which F1-02 left in a different shape.
- `apply_settings(sensitivity: float, invert_vertical: bool)` for F3.
- Camera stays `current = true` as authored.

No Rules Core: the behavior is engine-bound. Keep math in small private functions so it is readable.

### Yaw contract with PlayerController (reconciled 2026-09-22, after F1-02)

F1-02 shipped `PlayerController._camera_yaw()` returning `camera_rig.global_rotation.y`, not a `get_yaw()` call, because no `CameraRig` class existed yet. Camera-relative movement depends on that one number, and the failure mode is silent: a rig that keeps its yaw in a private variable and rebuilds only the `Camera3D` basis leaves the rig node unrotated, `global_rotation.y` reads 0 forever, and the ship keeps flying along world axes while the camera turns. Nothing errors.

Pick one and make it explicit:

- **Keep the yaw in the rig node's own Y rotation** (`top_level = true` still allows this) and leave `_camera_yaw()` alone. Add `get_yaw()` anyway for the F1-04 and HUD callers, returning the same value.
- **Or own the yaw privately** and change `_camera_yaw()` to `return camera_rig.get_yaw()`, which means retyping the export and updating the one line plus its comment.

Either way, this ticket also:

- Retypes `PlayerController.camera_rig` from `Node3D` to `CameraRig` (F1-02 typed it `Node3D` because the class did not exist), which changes the export type in `scenes/player/player_ship.tscn` — the `node_paths` marker on the root `[node]` line already lists `camera_rig` and must stay.
- Adds a test that closes the loop: with the rig turned 90°, `PlayerController` flies forward along the rig's facing rather than world -Z. That is the assertion that would have caught the silent failure above, and it belongs in `tests/scene/test_player_ship_contract.gd` or the new camera test, not in a core test.
- Updates GUIDE Section 6, whose `camera_rig.gd` row currently states the `global_rotation.y` contract, and the `player-flight.md` open issue that records it.

## Tests required

- `tests/scene/test_camera_rig_contract.gd`: rig instantiates headless; `get_yaw()` returns a finite value; after `set_lock_target` with a dummy Node3D placed at +X, several `_physics_process` calls move the yaw toward that direction; `clear_lock_target` restores follow mode. Roll (`camera.global_transform.basis.get_euler().z`) stays 0 in every state.
- The round trip named in the yaw contract above: turn the rig 90° and assert the ship's forward input follows the camera instead of world -Z.
- Manual checklist recorded in `docs/validation/player-flight.md`: orbit each arena target at low, middle, and high altitude on keyboard and gamepad; fly under the shrine gate and confirm the camera shortens without popping; lock and release feel smooth; no horizon tilt at any time. `tools/validate_player_flight.gd` is the pattern for driving the harness with simulated actions and capturing screenshots; extend it rather than starting a second utility. Simulated actions are not a device: F1-02 already owes a physical keyboard and controller pass, so record what was actually pressed instead of inheriting the claim.

## Out of scope

Target selection (F1-04), HUD marker, settings persistence.

## Definition of Done

- Tests green; manual checklist recorded, naming the devices actually used and anything left unverified.
- The yaw contract decided, implemented on both sides, and covered by the round-trip test.
- `PlayerController.camera_rig` retyped to `CameraRig` and still resolving in `scenes/player/player_ship.tscn` — the stored `NodePath` should not need editing, so check whether the scene file changed at all before deciding the commit needs `[shared]` and a handoff entry.
- GUIDE Section 6 rows (`camera_rig.gd` and `player_controller.gd` if the yaw source moved) and Section 13 camera values updated to the exports.
- `docs/engineering/player-flight.md` camera section filled, and its yaw open issue closed.
- Handoff log entry; commit `player: implement CameraRig follow, orbit, lock framing, obstruction`, with `[shared]` in the summary only if an Astra-owned file actually changed.

## Handoff notes for Astra

Framing defaults are exports on `CameraRig`; tune them in the Inspector. If an authored space makes the camera clip, prefer adjusting `obstruction_margin` or the geometry over changing the code.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/player-flight/issues/03-camera-rig.md, then implement that ticket. Use /run to test in the dev harness on keyboard and gamepad. Finish with its Definition of Done and commit.
```

## Result — 2026-09-22

Done. `scripts/player/camera_rig.gd` is `class_name CameraRig extends Node3D`, wired to
`PlayerShip/CameraRig` with `camera` → `Camera3D` and the authored framing pair.

The yaw contract went to the first option: **the yaw lives in the rig node's own
`global_rotation.y`**, read at the start of every tick, modified, and written back, so
an external turn of the node is picked up rather than overwritten. `get_yaw()` publishes
it and `PlayerController._camera_yaw()` calls `get_yaw()` instead of reading the property
directly — an explicit contract on both sides, with both readings the same number.
`PlayerController.camera_rig` is typed `CameraRig`; the stored `NodePath` did not need
editing, but `scenes/player/player_ship.tscn` still changed because the rig's own
`camera` export had to be authored, so the commit carries `[shared]`.

Verified: 69 tests green (11 new camera contract tests, 1 new round-trip test on the ship
contract), and `tools/validate_player_flight.gd` printing `FLIGHT_OK` over 24 camera
measurements in a real window, reproducible across runs. Mutation-checked both ways:
`_camera_yaw()` returning 0 fails only the round-trip test, and an obstruction ray on
mask 0 fails only the shortening test.

Not done, and recorded rather than silently accepted:

- No physical key or pad button was pressed. The run does now report the host's devices
  (`0:DualSense Wireless Controller`, standard mapping), which is an inventory, not a
  test. The human pass is listed in the roadmap's requests to Astra.
- Turned into a wall the camera collapses to 0.75 units from the ship; there is no
  minimum distance, because the ticket's rule is "hit point minus margin".
- Entering an obstruction is a snap: 6.5 units in one frame under the shrine gate.
  Easing in would put the camera inside the beam; a swept sphere would trade the pop for
  some clipping. Left as a feel decision with the numbers measured.
- A teleport (`reset_to`) sweeps the camera across the arena, because only the pivot
  snaps. Nothing calls it in anger before F7/F10.
