extends TestCase
## Contract smoke test of the [CameraRig] authored into `scenes/player/player_ship.tscn`:
## the rest pose, the yaw it publishes, the orbit actions, the Target Lock framing, the
## obstruction ray, and the one rule that holds in every one of those states — the
## horizon never tilts.
##
## Expected values come from the design documents: the camera offset (0, 3.2, 8.5) and
## its -0.16 rad pitch are GUIDE Section 13 "Authored player values", the stable horizon
## and the lock framing are PLANEJAMENTO Section 3, and the camera actions are
## CONVENTIONS "Input actions".
##
## `test_a_missing_camera_is_reported_and_stops_the_rig` deliberately triggers
## `push_error`, so one ERROR line in the run output belongs to it.


const PLAYER_SCENE_PATH := "res://scenes/player/player_ship.tscn"
## Authored camera offset, GUIDE Section 13. Its length is what the rig keeps the camera
## at, whatever the pitch, because pitch rotates the offset instead of stretching it.
const AUTHORED_CAMERA_OFFSET := Vector3(0.0, 3.2, 8.5)
## Authored camera pitch in radians, GUIDE Section 13. `default_pitch_degrees` is the
## export form of it, rounded to -9 degrees.
const AUTHORED_CAMERA_PITCH := -0.16
## Physics ticks awaited for the orbit measurements: a third of a second at 60 Hz.
const ORBIT_TICKS := 20
## Physics ticks awaited for an eased state to settle: lock blend plus convergence.
const SETTLE_TICKS := 40
## Actions a test may hold down; all of them are released after every test.
const SIMULATED_ACTIONS: Array[StringName] = [&"camera_left", &"camera_right", &"camera_up", &"camera_down"]
## Lock target position: straight out along +X, which the camera must turn to face.
const LOCK_TARGET_POSITION := Vector3(20.0, 0.0, 0.0)
## Wall used by the obstruction test: a plate behind the ship, across the camera's line.
const WALL_CENTER := Vector3(0.0, 2.0, 4.0)
const WALL_SIZE := Vector3(10.0, 10.0, 1.0)

var _ship: PlayerController
var _rig: CameraRig
var _camera: Camera3D
## Nodes a single test adds beside the ship, freed with it.
var _dummy: Node3D
var _wall: StaticBody3D
var _spare: PlayerController


func before_each() -> void:
	_ship = _instantiate_ship()
	if _ship == null:
		return
	tree.root.add_child(_ship)
	_rig = _ship.camera_rig
	_camera = _rig.camera
	await tree.process_frame


func after_each() -> void:
	for action: StringName in SIMULATED_ACTIONS:
		Input.action_release(action)
	for node: Node in [_ship, _dummy, _wall, _spare]:
		if node == null or not is_instance_valid(node):
			continue
		tree.root.remove_child(node)
		node.free()
	_ship = null
	_rig = null
	_camera = null
	_dummy = null
	_wall = null
	_spare = null


func test_the_authored_rig_places_the_authored_camera() -> void:
	if not assert_not_null(_rig, "%s has a CameraRig child" % PLAYER_SCENE_PATH):
		return
	assert_eq(_rig.name, "CameraRig")
	assert_eq(_rig.camera, _rig.get_node_or_null(^"Camera3D"), "camera")
	assert_true(_camera.current, "the authored camera stays current")
	# GUIDE Section 13: the camera offset is the rig's framing pair.
	assert_almost_eq(_rig.follow_height, AUTHORED_CAMERA_OFFSET.y, 0.0001, "follow_height")
	assert_almost_eq(_rig.follow_distance, AUTHORED_CAMERA_OFFSET.z, 0.0001, "follow_distance")
	# The body banks and an owner may rotate it; top_level is what keeps that out.
	assert_true(_rig.top_level, "top_level")
	assert_eq(_rig.process_mode, Node.PROCESS_MODE_INHERIT, "a wired rig keeps processing")


## The rest pose reproduces the authored camera: the same distance behind and above the
## ship, looking slightly down, with the ship on the near side of the view.
func test_the_rig_rests_behind_and_above_the_ship() -> void:
	if not assert_not_null(_rig, "%s has a CameraRig child" % PLAYER_SCENE_PATH):
		return
	await _await_physics_frames(3)
	var offset := _camera.global_position - _ship.global_position
	assert_almost_eq(offset.length(), AUTHORED_CAMERA_OFFSET.length(), 0.01, "distance from the ship")
	assert_true(offset.z > 0.0, "the camera sits behind the ship at z %f" % offset.z)
	assert_true(offset.y > 0.0, "the camera sits above the ship at y %f" % offset.y)
	# The view direction is (-sin(yaw)cos(pitch), sin(pitch), -cos(yaw)cos(pitch)), so its
	# height is the sine of the pitch: GUIDE Section 13's -0.16 rad, looking down.
	var forward := -_camera.global_transform.basis.z
	assert_almost_eq(forward.y, sin(AUTHORED_CAMERA_PITCH), 0.01, "view pitch")
	assert_almost_eq(forward.x, 0.0, 0.001, "the rest pose looks straight along -Z")


func test_get_yaw_is_finite_and_is_the_rig_node_rotation() -> void:
	if not assert_not_null(_rig, "%s has a CameraRig child" % PLAYER_SCENE_PATH):
		return
	assert_true(is_finite(_rig.get_yaw()), "get_yaw() is finite: %f" % _rig.get_yaw())
	assert_almost_eq(_rig.get_yaw(), _rig.global_rotation.y, 0.0001, "get_yaw() is the node's own yaw")
	# The contract PlayerController depends on: turning the node turns the published yaw.
	_rig.rotation.y = PI / 2.0
	assert_almost_eq(_rig.get_yaw(), PI / 2.0, 0.0001, "get_yaw() after turning the rig")


## CONVENTIONS "Input actions": the four `camera_*` actions turn the view, at
## `orbit_speed_degrees` per second.
func test_the_camera_actions_orbit_the_rig() -> void:
	if not assert_not_null(_rig, "%s has a CameraRig child" % PLAYER_SCENE_PATH):
		return
	var start_yaw := _rig.get_yaw()
	Input.action_press(&"camera_right")
	await _await_physics_frames(ORBIT_TICKS)
	Input.action_release(&"camera_right")
	var turned := _rig.get_yaw() - start_yaw
	# Looking right is a negative rotation around world Y. A third of a second at the
	# authored 120 degrees per second is about 0.7 rad; the bounds allow a tick either way.
	assert_true(turned < 0.0, "camera_right turned the view right: %f rad" % turned)
	assert_true(absf(turned) > 0.5 and absf(turned) < 0.9, "turned %f rad in %d ticks" % [turned, ORBIT_TICKS])

	var start_pitch := _view_pitch()
	Input.action_press(&"camera_up")
	await _await_physics_frames(ORBIT_TICKS)
	Input.action_release(&"camera_up")
	assert_true(_view_pitch() > start_pitch, "camera_up raised the view from %f to %f" % [start_pitch, _view_pitch()])


## PLANEJAMENTO Section 7 lets the player invert the vertical camera axis; F3 applies the
## stored setting through this call.
func test_apply_settings_inverts_the_vertical_orbit() -> void:
	if not assert_not_null(_rig, "%s has a CameraRig child" % PLAYER_SCENE_PATH):
		return
	_rig.apply_settings(1.0, true)
	assert_true(_rig.invert_vertical, "invert_vertical")
	assert_almost_eq(_rig.sensitivity, 1.0, 0.0001, "sensitivity")

	var start_pitch := _view_pitch()
	Input.action_press(&"camera_up")
	await _await_physics_frames(ORBIT_TICKS)
	Input.action_release(&"camera_up")
	assert_true(_view_pitch() < start_pitch, "inverted camera_up lowered the view from %f to %f" % [start_pitch, _view_pitch()])


## PLANEJAMENTO Section 3: while locked, frame the player and the target together.
func test_the_lock_framing_turns_the_yaw_toward_the_target() -> void:
	if not assert_not_null(_rig, "%s has a CameraRig child" % PLAYER_SCENE_PATH):
		return
	_dummy = _add_dummy_target(LOCK_TARGET_POSITION)

	_rig.set_lock_target(_dummy)
	await _await_physics_frames(SETTLE_TICKS)

	# A target at +X is faced at a yaw of -90 degrees: the camera looks along -Z rotated
	# by the yaw, so it must swing a quarter turn to the right.
	assert_almost_eq(_rig.get_yaw(), -PI / 2.0, 0.15, "yaw after locking a target at +X")
	# Both ends of the framing are in front of the camera, which is what the lock is for.
	assert_true(_is_in_view(_ship.global_position), "the ship is in view")
	assert_true(_is_in_view(_dummy.global_position), "the target is in view")


func test_clearing_the_lock_returns_to_follow_mode() -> void:
	if not assert_not_null(_rig, "%s has a CameraRig child" % PLAYER_SCENE_PATH):
		return
	_dummy = _add_dummy_target(LOCK_TARGET_POSITION)
	_rig.set_lock_target(_dummy)
	await _await_physics_frames(SETTLE_TICKS)
	var released_yaw := _rig.get_yaw()

	_rig.clear_lock_target()
	# A target that keeps moving would drag a camera that is still locked.
	_dummy.global_position = -LOCK_TARGET_POSITION
	await _await_physics_frames(SETTLE_TICKS)

	assert_almost_eq(_rig.get_yaw(), released_yaw, 0.02, "the released camera holds its heading")


## ENGINEERING_BRIEF 4.B and PLANEJAMENTO Section 3: a stable horizon, in every state the
## rig can be in. `get_euler().z` is the roll of the rendered camera.
func test_the_horizon_stays_level_in_every_state() -> void:
	if not assert_not_null(_rig, "%s has a CameraRig child" % PLAYER_SCENE_PATH):
		return
	assert_almost_eq(_camera_roll(), 0.0, 0.0001, "at rest")

	# A rolled body must not roll the camera: the rig is top_level for this reason.
	_ship.rotation = Vector3(0.3, 0.7, 0.6)
	await _await_physics_frames(3)
	assert_almost_eq(_camera_roll(), 0.0, 0.0001, "with the body pitched, turned and rolled")

	Input.action_press(&"camera_right")
	Input.action_press(&"camera_up")
	await _await_physics_frames(ORBIT_TICKS)
	Input.action_release(&"camera_right")
	Input.action_release(&"camera_up")
	assert_almost_eq(_camera_roll(), 0.0, 0.0001, "while orbiting")

	_dummy = _add_dummy_target(Vector3(14.0, 9.0, -6.0))
	_rig.set_lock_target(_dummy)
	await _await_physics_frames(SETTLE_TICKS)
	assert_almost_eq(_camera_roll(), 0.0, 0.0001, "while locked on a target above the ship")

	_rig.clear_lock_target()
	await _await_physics_frames(ORBIT_TICKS)
	assert_almost_eq(_camera_roll(), 0.0, 0.0001, "after the lock was released")


## The rig follows the body's position and nothing else: it is a child of the ship, and a
## child inherits a transform unless it is told not to.
func test_the_rig_follows_the_body_position_but_not_its_rotation() -> void:
	if not assert_not_null(_rig, "%s has a CameraRig child" % PLAYER_SCENE_PATH):
		return
	var yaw_before := _rig.get_yaw()

	_ship.global_transform = Transform3D(Basis.from_euler(Vector3(0.4, 1.2, 0.5)), Vector3(12.0, 7.0, -3.0))
	await _await_physics_frames(3)

	assert_true(_rig.global_position.is_equal_approx(_ship.global_position),
		"the rig sits on the ship at %s" % _rig.global_position)
	var rig_euler := _rig.global_transform.basis.get_euler()
	assert_almost_eq(rig_euler.y, yaw_before, 0.0001, "the body's yaw did not reach the rig")
	assert_almost_eq(rig_euler.x, 0.0, 0.0001, "the rig basis carries no pitch")
	assert_almost_eq(rig_euler.z, 0.0, 0.0001, "the rig basis carries no roll")


## PLANEJAMENTO Section 3 and ENGINEERING_BRIEF 4.B "camera behavior near geometry":
## scenery between the ship and the camera shortens the rig, and it eases back out.
func test_scenery_between_the_ship_and_the_camera_shortens_the_rig() -> void:
	if not assert_not_null(_rig, "%s has a CameraRig child" % PLAYER_SCENE_PATH):
		return
	await _await_physics_frames(3)
	var clear_offset := _camera.global_position - _ship.global_position
	var wall_face := WALL_CENTER.z - WALL_SIZE.z * 0.5

	_wall = _add_wall()
	await _await_physics_frames(ORBIT_TICKS)

	# The camera slides down its own line until it is `obstruction_margin` short of the
	# wall, so the distance is the one the uncovered line crossed the wall face at.
	var direction := clear_offset.normalized()
	var expected := (wall_face - _ship.global_position.z) / direction.z - _rig.obstruction_margin
	var shortened := _camera.global_position.distance_to(_ship.global_position)
	assert_almost_eq(shortened, expected, 0.1, "shortened camera distance")
	assert_true(_camera.global_position.z < wall_face, "the camera stays in front of the wall face")

	tree.root.remove_child(_wall)
	_wall.free()
	# A freed Object does not compare equal to null and cannot be assigned to a typed
	# iterator either, so the fixture's own reference goes with it.
	_wall = null
	await _await_physics_frames(SETTLE_TICKS)
	assert_almost_eq(_camera.global_position.distance_to(_ship.global_position), clear_offset.length(), 0.05,
		"the camera eased back out once the wall was gone")


## One ERROR line in the output is this test's own.
func test_a_missing_camera_is_reported_and_stops_the_rig() -> void:
	_spare = _instantiate_ship()
	if not assert_not_null(_spare, "%s loads a second time" % PLAYER_SCENE_PATH):
		return
	var spare_rig := _spare.camera_rig
	if not assert_not_null(spare_rig, "the second ship has its rig"):
		return
	spare_rig.camera = null

	tree.root.add_child(_spare)
	await tree.process_frame

	assert_eq(spare_rig.process_mode, Node.PROCESS_MODE_DISABLED, "process_mode after the error")
	assert_false(spare_rig.can_process(), "can_process() after the error")


func _instantiate_ship() -> PlayerController:
	var packed := load(PLAYER_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as PlayerController


func _add_dummy_target(position: Vector3) -> Node3D:
	var dummy := Node3D.new()
	dummy.name = "LockTarget"
	tree.root.add_child(dummy)
	dummy.global_position = position
	return dummy


## A scenery plate on layer 1, behind the ship and clear of its body box, so it blocks the
## camera without pushing the ship.
func _add_wall() -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "CameraWall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = WALL_SIZE
	shape.shape = box
	wall.add_child(shape)
	# Placed before it enters the tree: a plate that appears on top of the ship, even for
	# the part of a frame before the position is assigned, pushes the body out of it.
	wall.position = WALL_CENTER
	tree.root.add_child(wall)
	return wall


## Roll of the rendered camera, in radians. Zero in every state the rig can reach.
func _camera_roll() -> float:
	return _camera.global_transform.basis.get_euler().z


## Pitch of the rendered camera, in radians. Negative looks down.
func _view_pitch() -> float:
	return _camera.global_transform.basis.get_euler().x


## Whether [param point] is in front of the camera and inside its vertical field of view,
## which is what "framed" means for the lock.
func _is_in_view(point: Vector3) -> bool:
	var local := _camera.global_transform.affine_inverse() * point
	if local.z >= 0.0:
		return false
	var angle := rad_to_deg(atan2(absf(local.y), absf(local.z)))
	return angle <= _camera.fov * 0.5


func _await_physics_frames(count: int) -> void:
	for _frame in range(count):
		await tree.physics_frame
