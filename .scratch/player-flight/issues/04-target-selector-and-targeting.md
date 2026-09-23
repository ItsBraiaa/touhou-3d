# F1-04 TargetSelector core and targeting adapter

Status: done (2026-09-22; the physical keyboard and pad pass is still owed, as for 02 and 03)
Type: core+adapter
parallel-safe: no
Depends on: F1-03

## Goal

Target Lock works against the three arena targets: acquire the best visible candidate near the screen center, cycle to the next, release, and lose the lock when the target disappears or leaves range. The selection rules are a Node-free core; the adapter supplies candidates from the scene and emits `target_changed` to the camera (and later HUD and weapon).

## Read first

- `CONTEXT.md`: Target Lock, Aim Assist
- `docs/PLANEJAMENTO.md` Section 3 ("Aim assist prioritizes visible targets near the screen center. Lock remains stable until explicitly switched, released, or invalidated by target death/range")
- `docs/ENGINEERING_BRIEF.md` Section 4.B ("target disappearance, scenery occlusion")
- `docs/GUIDE.md` Section 7 "Target changed" row, Section 13 (targets are Node3D in group `targetable` with `HitVolume/Collision`, IDs in metadata)
- `docs/engineering/CONVENTIONS.md`

## Deliverables

### `scripts/player/target_selector.gd`, `class_name TargetSelector extends RefCounted`

- `class Candidate` (inner `RefCounted`): `id: int`, `screen_offset: Vector2` (normalized, 0,0 = center, magnitude 1 = edge), `distance: float`, `visible: bool` (not occluded and in front of the camera).
- `configure(max_distance: float, max_screen_radius: float)`.
- `select_best(candidates: Array[Candidate]) -> int` returns the id of the visible candidate with the smallest weighted score (`screen_offset.length()` first, distance as tie-break), or -1 when none qualifies (invisible, beyond `max_distance`, or outside `max_screen_radius`).
- `select_next(candidates: Array[Candidate], current_id: int) -> int` cycles among qualifying candidates ordered by screen angle, returning the one after `current_id`, wrapping; returns `select_best` if `current_id` is not present.
- `validate(candidates: Array[Candidate], current_id: int) -> bool` is false when the current target is absent or beyond `max_distance`. Occlusion alone does not drop a lock (a locked target may pass behind a tree); absence or range does.
- Signal `target_changed(id: int)` emitted by `set_current(id)` only when the id changes.

### `scripts/player/targeting.gd`, `class_name Targeting extends Node`

- Exports: `camera: Camera3D` (required), `max_distance: float = 60.0`, `max_screen_radius: float = 0.85`, `occlusion_mask: int = 1`, `group_name: StringName = &"targetable"`.
- Each physics tick: gather nodes in `group_name`, build candidates (`camera.unproject_position` normalized to the viewport, `camera.is_position_behind`, occlusion ray from camera to the node's `HitVolume` global position on `occlusion_mask`, distance from the ship). Node ids are `get_instance_id()`; keep a dictionary id to node.
- `lock_target` action: toggles; when no lock, `select_best`; when locked, release. `next_target` action: `select_next`. Every tick: `validate`, and release when false.
- Signal `target_changed(target: Node3D)` (null on release). Connect to `CameraRig.set_lock_target` / `clear_lock_target` in the owner (`PlayerController.setup` or the dev harness), following the one-place connection rule.
- Public `get_current_target() -> Node3D`.

## Tests required

`tests/unit/player/test_target_selector.gd`:

- Best pick is the visible candidate nearest the screen center, not the nearest in distance.
- Invisible candidates never get selected; beyond-range candidates never get selected; outside the screen radius never gets selected.
- `select_next` visits every qualifying candidate exactly once before wrapping, in a stable order; with one candidate it returns the same id.
- `validate` is false when the current id is missing or beyond range, true when merely occluded.
- `target_changed` fires once per change and not for the same id.

`tests/scene/test_targeting_contract.gd`: in `combat_arena.tscn` headless with a camera, the adapter builds three candidates and `lock_target` selects one of the three group members; freeing that node releases the lock within one tick.

Manual (append to `docs/validation/player-flight.md`): lock, cycle through the three targets, release, fly out of range and confirm release, put a tree between camera and target and confirm the lock holds.

## Out of scope

HUD marker (F4-02), Aim Assist shots (F6-03), enemy targets.

## Definition of Done

- Tests green; manual checks recorded.
- GUIDE Section 6 row for `targeting.gd` and Section 7 "Target changed" signature updated.
- `docs/engineering/player-flight.md` targeting section filled; F1 spec "Done when" satisfied.
- Handoff log entry; commit `player: add TargetSelector core and Targeting adapter`.

## Handoff notes for Astra

Any future enemy prefab must join the `targetable` group and expose a `HitVolume` child for the occlusion ray to aim at. Targets without a `HitVolume` are skipped and logged once.

## Outcome (2026-09-22)

Delivered as specified, test-first for the core, with these differences:

- **`select_next` orders the ring left to right on screen, not by screen angle.** The camera turns to frame every new lock; that turn slides every target sideways by the same amount and keeps their left-to-right order, while the locked target's own angle around the center is noise (a hair above center "next" goes right, a hair below it goes left).
- **The screen radius gates a fresh lock only; the switch ring is every visible target in range.** Found by `test_next_target_visits_all_three_before_wrapping_while_the_camera_follows`: locked on High, the camera turns right and Low slides to x -0.965, on screen but outside the 0.85 radius, so a ring that kept the radius cycled Middle, High, Middle, High and never reached Low. `test_select_next_reaches_visible_targets_outside_the_screen_radius` pins the fix in the core.
- Ids are resolved with `instance_from_id` instead of a stored id-to-node dictionary, so a target freed between two ticks reads as null rather than a dangling reference.
- `build_candidates()` is public (the contract test and the validation tool call it; F6-03's Aim Assist is expected to).
- `PlayerController` gains a required `targeting` export and makes the one `target_changed → CameraRig.set_lock_target` connection in `_ready`, not `setup()`, because owners call `setup()` again whenever the Flight Volume changes.
- The harness's F1-03 lock stand-in is removed; its readout shows the real lock and its distance.
- Manual checks were flown with simulated actions by `tools/validate_player_flight.gd`, not by a human. The arena's trees have no collision, so "a tree between camera and target" was measured with the shrine gate's beam, the only collidable scenery that can come between them.

Tests: 14 in `tests/unit/player/test_target_selector.gd`, 10 in `tests/scene/test_targeting_contract.gd`, one reference added to `test_player_ship_contract.gd`; suite 93 green; 11 mutations each caught. F1 spec "Done when": all F1 tests pass, the three player scripts have complete registry rows, weapon untouched; the physical keyboard and gamepad half of the manual checklist is still open, and cannot be closed by an agent.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/player-flight/issues/04-target-selector-and-targeting.md, then implement that ticket with /mattpocock-skills:tdd for the core. Finish with its Definition of Done and commit.
```
