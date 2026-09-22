# F1-02 Player controller adapter

Status: done
Type: adapter
parallel-safe: no
Depends on: F0-03, F1-01

## Goal

`player_controller.gd` reads the input actions, drives `FlightModel`, moves the `CharacterBody3D` against scenery, banks `VisualRoot` only, and exposes control enable, reset, and edge feedback to its owners. The ship flies in `combat_arena.tscn` on keyboard and gamepad.

## Read first

- `docs/engineering/CONVENTIONS.md`: "Architecture rules", "Collision", "Input actions", "Setup errors"
- `docs/GUIDE.md` Section 5 "Player", Section 6 row `player_controller.gd`, Section 13 (tree, values, layers, FlightBounds metadata)
- `scenes/player/player_ship.tscn` and `scenes/tests/combat_arena.tscn` (read the `FlightBounds` node metadata)
- `.scratch/player-flight/issues/01-flight-model-core.md` (the core contract)

## Deliverables

`scripts/player/player_controller.gd`, `class_name PlayerController extends CharacterBody3D`, replacing the placeholder.

### Exports

`base_speed: float = 12.0`, `focus_multiplier: float = 0.45`, `edge_margin: float = 4.0`, `max_bank_angle_degrees: float = 25.0`, `bank_smoothing: float = 8.0`, `visual_root: Node3D` (required), `camera_rig: Node3D` (required; yaw source, typed as the F1-03 class once it exists), `damage_core: Area3D` (required), `graze_volume: Area3D` (required).

Remove the `metadata/base_speed` and `metadata/focus_multiplier` handoff entries from `player_ship.tscn` when the exports are wired (`[shared]`).

### Behavior

- `_ready`: validate required exports (push_error with path and field, disable processing). Create `FlightModel`, configure, connect `edge_proximity_changed`.
- `setup(bounds: AABB) -> void`: sets the Flight Volume on the model. In the arena, the owner (for now a small `scenes/dev/arena_harness.gd` on the arena root, or the F2-04 session later) reads `FlightBounds` metadata `min`/`max` and calls `setup`. Without bounds the ship is only limited by collision.
- `_physics_process`: read `Input.get_vector("move_left", "move_right", "move_back", "move_forward")` and `Input.get_axis("descend", "ascend")`, `Input.is_action_pressed("focus")`, ask `camera_rig` for its yaw, set `velocity` from the model, `move_and_slide()` (collision mask layer 1 only, `motion_mode = MOTION_MODE_FLOATING`, no gravity), then `global_position = model.clamp_position(global_position)` and `model.edge_proximity(global_position)`.
- `_process`: lerp `visual_root.rotation.z` toward `model.bank_angle(...)`. Never rotate the body or the camera from banking. `DamageCore`, `GrazeVolume`, `Muzzle` are outside `VisualRoot` by contract; add a test that their global positions do not change when the bank angle changes.
- `set_controls_enabled(enabled: bool)`: when false, velocity is zero, input ignored, bank returns to zero.
- `reset_to(transform: Transform3D)`: teleports, zeroes velocity and bank.
- Signals: `edge_proximity_changed(value: float)` (re-emitted from the model), `focus_changed(active: bool)`.

### Dev harness

`scenes/dev/arena_harness.tscn` (owned by Claude, marked dev): instances `combat_arena.tscn`, reads FlightBounds, calls `setup`, and is the F6-runnable scene for this Feature. Keep it out of the main scene.

## Tests required

- `tests/scene/test_player_ship_contract.gd`: instances `player_ship.tscn` headless; asserts the exports resolve, that processing is disabled with a pushed error when `visual_root` is null (use a duplicate with the export cleared), and that `DamageCore`, `GrazeVolume`, and `Muzzle` global positions are unchanged after forcing `visual_root.rotation.z = 0.4`.
- Manual (record in `docs/validation/player-flight.md`): keyboard WASD, Space, Ctrl, Shift; gamepad left stick, RB, LB, LT; diagonal speed feels bounded; the ship stops at the arena walls and the platform; edge feedback value visible in a debug label on the dev harness.

## Out of scope

Camera behavior (F1-03), targeting (F1-04), HUD, weapon.

## Definition of Done

- Tests green; manual checks recorded.
- `player_ship.tscn` exports wired, metadata removed, GUIDE Section 13 table and Section 6 row updated.
- `docs/engineering/player-flight.md` adapter section filled.
- Handoff log `[shared]`; commit `player: [shared] implement PlayerController adapter and arena harness`.

## Handoff notes for Astra

`PlayerShip` now has real exports; the Inspector values replace the old metadata. The dev harness scene is Claude's and is not part of the game.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/player-flight/issues/02-player-controller-adapter.md, then implement that ticket. Use /run to fly the dev harness. Finish with its Definition of Done and commit.
```

## Result — 2026-09-22

Done. 57 tests green (`tools/test.ps1`), ten of them the new
`tests/scene/test_player_ship_contract.gd`. Measured flight and four screenshots are in
`docs/validation/player-flight.md`; the adapter contract is in
`docs/engineering/player-flight.md`.

Five notes for the next session:

- The `FlightBounds` metadata keys are `min_corner` and `max_corner`, not `min`/`max` as
  written above. The harness reads the real keys and passes `AABB(min, max - min)`.
- `reset_to` takes `p_transform`, since a parameter named `transform` shadows
  `Node3D.transform`. Behavior is the ticket's.
- The root node needed `node_paths=PackedStringArray(...)` on its `[node]` line for the
  four exported node references to resolve; without it Godot assigns the raw `NodePath`
  and every reference reads as unset. `tools/build_scene_handoff.py` still lacks that
  line plus the exports and `motion_mode`, so it no longer reproduces the integrated
  scene — five lines to reconcile before any rerun. It was left unchanged because this
  host has no Python to verify a rerun with.
- The manual list is only partly discharged: `tools/validate_player_flight.gd` drives
  every case with `Input.action_press`, which ENGINEERING_BRIEF Section 8 says does not
  replace a physical device. A human pass on keyboard and on a controller is still owed
  and is recorded as unverified in the validation page.
- The harness script is on the harness root, not "on the arena root" as the `setup`
  bullet says: `arena_harness.tscn` instances `combat_arena.tscn` as a child and drives
  it from outside, which is what the Dev harness section describes and leaves Astra's
  scene file untouched.
