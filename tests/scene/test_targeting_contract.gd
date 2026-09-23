extends TestCase
## Contract smoke test of the [Targeting] adapter inside `scenes/tests/combat_arena.tscn`:
## it sees the arena's three `targetable` markers, `lock_target` and `next_target` drive
## the lock, a target that disappears or leaves range releases it, scenery hides targets
## from acquisition without dropping a held lock, and the ship's camera frames whatever
## is locked.
##
## Expected values come from the design documents: the three target positions and the
## ship start are GUIDE Section 13, the lock rules are PLANEJAMENTO Section 3, and the
## actions are CONVENTIONS "Input actions". Which of the three a lock picks is measured in
## `docs/validation/player-flight.md`, not pinned here, because it moves with the camera
## framing values Astra tunes.
##
## `test_a_missing_camera_is_reported_and_stops_the_adapter` deliberately triggers
## `push_error`, and `test_a_target_without_a_hit_volume_is_skipped` `push_warning`, so
## one ERROR and one WARNING line in the run output are theirs.


const ARENA_PATH := "res://scenes/tests/combat_arena.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player/player_ship.tscn"
const TARGET_NAMES: Array[String] = ["Low", "Middle", "High"]
## GUIDE Section 13: the ship starts at (0, 6, 18) and Middle is at (0, 9, -20).
const SHIP_START := Vector3(0.0, 6.0, 18.0)
const MIDDLE_POSITION := Vector3(0.0, 9.0, -20.0)
## Physics ticks for the camera to settle after a teleport or a lock: the blend plus the
## chase, as in the camera rig contract.
const SETTLE_TICKS := 40
## A spot off the arena's center line, where every target is at a clearly different
## heading from the camera's rest heading, so a lock that reaches the rig is visible.
const OFF_AXIS_START := Vector3(20.0, 6.0, 18.0)
const SIMULATED_ACTIONS: Array[StringName] = [&"lock_target", &"next_target"]

var _arena: Node3D
var _ship: PlayerController
var _targeting: Targeting
var _targets: Array[Node3D] = []
## Nodes a single test adds, freed after it.
var _extras: Array[Node] = []


func before_each() -> void:
	var packed := load(ARENA_PATH) as PackedScene
	if packed == null:
		return
	_arena = packed.instantiate() as Node3D
	tree.root.add_child(_arena)
	_ship = _arena.get_node_or_null(^"PlayerShip") as PlayerController
	_targeting = _arena.get_node_or_null(^"PlayerShip/Targeting") as Targeting
	_targets.clear()
	for target_name: String in TARGET_NAMES:
		var target := _arena.get_node_or_null(NodePath("Targets/" + target_name)) as Node3D
		if target != null:
			_targets.append(target)
	await _ticks(3)


func after_each() -> void:
	for action: StringName in SIMULATED_ACTIONS:
		Input.action_release(action)
	_extras.append(_arena)
	for node: Node in _extras:
		if node == null or not is_instance_valid(node):
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
	_extras.clear()
	_arena = null
	_ship = null
	_targeting = null
	_targets.clear()


func test_the_ship_carries_a_wired_targeting_adapter() -> void:
	if not assert_not_null(_targeting, "%s has PlayerShip/Targeting with the Targeting script" % ARENA_PATH):
		return
	assert_eq(_targeting.camera, _ship.camera_rig.camera, "camera is the rig's camera")
	assert_eq(_ship.targeting, _targeting, "the ship holds its own targeting")
	assert_eq(_targeting.process_mode, Node.PROCESS_MODE_INHERIT, "a wired adapter keeps processing")
	assert_eq(_targets.size(), TARGET_NAMES.size(), "the arena's three targets")


## One candidate per `targetable` marker, keyed by instance id, with the distance measured
## from the ship and the screen offset in the normalized convention of the core.
func test_the_adapter_builds_one_candidate_per_arena_target() -> void:
	if not assert_not_null(_targeting, "%s has PlayerShip/Targeting" % ARENA_PATH):
		return
	var candidates := _targeting.build_candidates()
	assert_eq(candidates.size(), 3, "three candidates")
	var by_id := {}
	for candidate: TargetSelector.Candidate in candidates:
		by_id[candidate.id] = candidate
	for target: Node3D in _targets:
		if not assert_in(target.get_instance_id(), by_id, "a candidate for %s" % target.name):
			continue
		var candidate: TargetSelector.Candidate = by_id[target.get_instance_id()]
		assert_true(candidate.visible, "%s is in front of the camera with nothing in between" % target.name)
	if _targets.size() != 3:
		return
	var low: TargetSelector.Candidate = by_id.get(_targets[0].get_instance_id())
	var middle: TargetSelector.Candidate = by_id.get(_targets[1].get_instance_id())
	var high: TargetSelector.Candidate = by_id.get(_targets[2].get_instance_id())
	if low == null or middle == null or high == null:
		return
	# (0, 9, -20) from (0, 6, 18): sqrt(3^2 + 38^2).
	assert_almost_eq(middle.distance, SHIP_START.distance_to(MIDDLE_POSITION), 0.01, "Middle's distance from the ship")
	# The camera rests looking along -Z from x 0: Middle is straight ahead, Low (x -10) to
	# the left, High (x 11, y 15) to the right and above, which is negative y on screen.
	assert_almost_eq(middle.screen_offset.x, 0.0, 0.01, "Middle is centered horizontally")
	assert_true(low.screen_offset.x < 0.0, "Low is left of center: %s" % low.screen_offset)
	assert_true(high.screen_offset.x > 0.0, "High is right of center: %s" % high.screen_offset)
	assert_true(high.screen_offset.y < 0.0, "High is above center: %s" % high.screen_offset)


func test_lock_target_acquires_one_of_the_three_and_freeing_it_releases_within_one_tick() -> void:
	if not assert_not_null(_targeting, "%s has PlayerShip/Targeting" % ARENA_PATH):
		return
	var changes := signal_recorder(_targeting, &"target_changed")
	await _tap(&"lock_target")
	var locked := _targeting.get_current_target()
	if not assert_in(locked, _targets, "lock_target picked one of the arena targets"):
		return
	assert_eq(changes.emissions, [[locked]], "one target_changed carrying the target")

	locked.get_parent().remove_child(locked)
	locked.free()
	await _ticks(1)

	assert_null(_targeting.get_current_target(), "the lock is released")
	assert_eq(changes.count(), 2, "one release")
	assert_eq(changes.last(), [null], "the release carries null")


func test_lock_target_again_releases_the_lock() -> void:
	if not assert_not_null(_targeting, "%s has PlayerShip/Targeting" % ARENA_PATH):
		return
	await _tap(&"lock_target")
	assert_not_null(_targeting.get_current_target(), "locked")
	await _tap(&"lock_target")
	assert_null(_targeting.get_current_target(), "released by the second press")


## Each press steps to a different target; with the camera turning to frame each new
## lock in between, three presses come back to the first after visiting the other two.
func test_next_target_visits_all_three_before_wrapping_while_the_camera_follows() -> void:
	if not assert_not_null(_targeting, "%s has PlayerShip/Targeting" % ARENA_PATH):
		return
	await _tap(&"lock_target")
	await _ticks(SETTLE_TICKS)
	var visited: Array[Node3D] = [_targeting.get_current_target()]
	for _press: int in 3:
		await _tap(&"next_target")
		await _ticks(SETTLE_TICKS)
		visited.append(_targeting.get_current_target())
	var names := visited.map(func(target: Node3D) -> String: return "null" if target == null else String(target.name))
	for index: int in 3:
		assert_in(visited[index], _targets, "press %d locked an arena target: %s" % [index, names])
	assert_ne(visited[1], visited[0], "the first press moved the lock: %s" % [names])
	assert_true(visited[2] != visited[0] and visited[2] != visited[1], "the second press reached the third target: %s" % [names])
	assert_eq(visited[3], visited[0], "the third press wrapped to the first: %s" % [names])


## PLANEJAMENTO Section 3: the lock is invalidated by range. Measured against the export,
## so a retuned range moves the boundary with it.
func test_a_target_that_leaves_range_releases_the_lock() -> void:
	if not assert_not_null(_targeting, "%s has PlayerShip/Targeting" % ARENA_PATH):
		return
	await _tap(&"lock_target")
	var locked := _targeting.get_current_target()
	if not assert_not_null(locked, "locked"):
		return
	var away := Vector3(0.0, 0.0, -1.0)
	locked.global_position = _ship.global_position + away * (_targeting.max_distance - 2.0)
	await _ticks(1)
	assert_eq(_targeting.get_current_target(), locked, "still inside range")
	locked.global_position = _ship.global_position + away * (_targeting.max_distance + 2.0)
	await _ticks(1)
	assert_null(_targeting.get_current_target(), "released beyond range")


## ENGINEERING_BRIEF 4.B "scenery occlusion": a target behind scenery cannot be acquired,
## but a lock already held survives it passing behind scenery.
func test_scenery_hides_targets_from_acquisition_but_does_not_drop_a_held_lock() -> void:
	if not assert_not_null(_targeting, "%s has PlayerShip/Targeting" % ARENA_PATH):
		return
	await _tap(&"lock_target")
	var locked := _targeting.get_current_target()
	if not assert_not_null(locked, "locked before the wall"):
		return

	_add_wall_in_front_of_the_ship()
	await _ticks(3)
	for candidate: TargetSelector.Candidate in _targeting.build_candidates():
		assert_false(candidate.visible, "the wall hides candidate %d" % candidate.id)
	assert_eq(_targeting.get_current_target(), locked, "the held lock survives the wall")

	await _tap(&"lock_target")
	assert_null(_targeting.get_current_target(), "released")
	await _tap(&"lock_target")
	assert_null(_targeting.get_current_target(), "nothing visible to acquire behind the wall")


## The ship wires its own targeting to its own camera: whatever is locked, the rig turns
## toward it (PLANEJAMENTO Section 3, "frame the player and target").
func test_the_ship_frames_the_target_its_targeting_locks() -> void:
	if not assert_not_null(_targeting, "%s has PlayerShip/Targeting" % ARENA_PATH):
		return
	_ship.reset_to(Transform3D(Basis(), OFF_AXIS_START))
	await _ticks(SETTLE_TICKS)
	await _tap(&"lock_target")
	var locked := _targeting.get_current_target()
	if not assert_not_null(locked, "locked from off the center line"):
		return
	await _ticks(SETTLE_TICKS)
	var direction := locked.global_position - _ship.global_position
	# The camera faces -Z rotated by the yaw, so facing a direction takes atan2(-x, -z).
	var framing_yaw := atan2(-direction.x, -direction.z)
	assert_true(absf(framing_yaw) > 0.2, "the geometry makes the turn observable: %f rad" % framing_yaw)
	assert_almost_eq(angle_difference(_ship.camera_rig.get_yaw(), framing_yaw), 0.0, 0.1, "the camera turned toward %s" % locked.name)


## Handoff contract with Astra: a `targetable` node needs a `HitVolume` child, the point
## the occlusion ray aims at. One WARNING line in the output is this test's own.
func test_a_target_without_a_hit_volume_is_skipped() -> void:
	if not assert_not_null(_targeting, "%s has PlayerShip/Targeting" % ARENA_PATH):
		return
	var bare := Node3D.new()
	bare.name = "BareTarget"
	bare.position = Vector3(0.0, 8.0, 0.0)
	bare.add_to_group(_targeting.group_name)
	_arena.add_child(bare)
	_extras.append(bare)

	var candidates := _targeting.build_candidates()
	assert_eq(candidates.size(), 3, "still only the three arena targets")
	for candidate: TargetSelector.Candidate in candidates:
		assert_ne(candidate.id, bare.get_instance_id(), "the bare node is not a candidate")


## One ERROR line in the output is this test's own.
func test_a_missing_camera_is_reported_and_stops_the_adapter() -> void:
	var packed := load(PLAYER_SCENE_PATH) as PackedScene
	if not assert_not_null(packed, "%s loads" % PLAYER_SCENE_PATH):
		return
	var spare := packed.instantiate() as PlayerController
	_extras.append(spare)
	var spare_targeting := spare.get_node_or_null(^"Targeting") as Targeting
	if not assert_not_null(spare_targeting, "the spare ship has its Targeting"):
		return
	spare_targeting.camera = null

	tree.root.add_child(spare)
	await tree.process_frame

	assert_eq(spare_targeting.process_mode, Node.PROCESS_MODE_DISABLED, "process_mode after the error")
	assert_false(spare_targeting.can_process(), "can_process() after the error")


## A scenery plate on layer 1 across the whole arena, between the ship and every target
## and clear of the ship's body box. Placed before it enters the tree, so it never
## overlaps the ship for part of a frame.
func _add_wall_in_front_of_the_ship() -> void:
	var wall := StaticBody3D.new()
	wall.name = "OcclusionWall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 80.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0.0, 10.0, SHIP_START.z - 6.0)
	_arena.add_child(wall)
	_extras.append(wall)


## One press and release of [param action]. The press is held across two ticks so it lands
## on a physics step whichever part of the frame it was made in.
func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _ticks(2)
	Input.action_release(action)
	await _ticks(1)


## Returns once [param count] physics ticks have run their nodes. `physics_frame` fires
## before the nodes of that tick run, so the final `process_frame` is what guarantees the
## last tick has been processed.
func _ticks(count: int) -> void:
	for _tick: int in count:
		await tree.physics_frame
	await tree.process_frame
