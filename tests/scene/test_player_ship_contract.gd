extends TestCase
## Contract smoke test of `scenes/player/player_ship.tscn` and the [PlayerController]
## adapter attached to its root: the body wiring Claude owns, the exports the adapter
## needs, the loud failure when one is missing, and the boundary banking must not cross.
##
## The movement rules themselves belong to the core and are tested in
## `tests/unit/player/test_flight_model.gd`. What is checked here is the adapter's own
## contract: input actions reach the core, the owner can take the controls away and
## teleport the ship, and the Flight Volume handed to [method PlayerController.setup]
## reaches the position clamp and the edge feedback.
##
## `test_a_missing_visual_root_is_reported_and_stops_the_adapter` deliberately triggers
## `push_error`, so one ERROR line in the run output belongs to it.


const PLAYER_SCENE_PATH := "res://scenes/player/player_ship.tscn"
## Authored values, GUIDE Section 13 "Authored player values".
const AUTHORED_BASE_SPEED := 12.0
const AUTHORED_FOCUS_MULTIPLIER := 0.45
## Handoff metadata the exports replaced; it must not linger in the scene.
const RETIRED_METADATA: Array[StringName] = [&"base_speed", &"focus_multiplier"]
## Physics frames awaited before reading a result. `physics_frame` fires at the start of
## a step, so two awaits put one whole step in between.
const OBSERVED_PHYSICS_FRAMES := 3
## Actions a test may hold down; all of them are released after every test.
const SIMULATED_ACTIONS: Array[StringName] = [&"move_forward", &"focus"]
## Bank forced on `VisualRoot` when checking that the combat volumes do not follow it.
const FORCED_BANK_RADIANS := 0.4

var _ship: PlayerController
## Second instance built by a single test, freed with the first one.
var _spare: PlayerController


func before_each() -> void:
	_ship = _instantiate_ship()
	if _ship == null:
		return
	tree.root.add_child(_ship)
	await tree.process_frame


func after_each() -> void:
	for action: StringName in SIMULATED_ACTIONS:
		Input.action_release(action)
	for node: Node in [_ship, _spare]:
		if node == null:
			continue
		tree.root.remove_child(node)
		node.free()
	_ship = null
	_spare = null


func test_root_is_a_player_controller_with_the_authored_body_wiring() -> void:
	if not assert_not_null(_ship, "%s loads with a PlayerController root" % PLAYER_SCENE_PATH):
		return
	assert_eq(_ship.name, "PlayerShip")
	assert_eq(_ship.get_class(), "CharacterBody3D")
	# CONVENTIONS "Collision": the player body is layer 2 and collides with scenery only.
	assert_eq(_ship.collision_layer, 2, "collision_layer")
	assert_eq(_ship.collision_mask, 1, "collision_mask")
	# A flying ship has no floor and no gravity; grounded mode would add both.
	assert_eq(_ship.motion_mode, CharacterBody3D.MOTION_MODE_FLOATING, "motion_mode")


func test_required_exports_resolve_to_the_authored_nodes() -> void:
	if not assert_not_null(_ship, "%s loads with a PlayerController root" % PLAYER_SCENE_PATH):
		return
	assert_eq(_ship.visual_root, _ship.get_node_or_null(^"VisualRoot"), "visual_root")
	assert_eq(_ship.camera_rig, _ship.get_node_or_null(^"CameraRig"), "camera_rig")
	assert_eq(_ship.damage_core, _ship.get_node_or_null(^"DamageCore"), "damage_core")
	assert_eq(_ship.graze_volume, _ship.get_node_or_null(^"GrazeVolume"), "graze_volume")
	assert_eq(_ship.process_mode, Node.PROCESS_MODE_INHERIT, "a valid scene keeps processing")


## The Inspector values replace the `metadata/*` handoff entries; the scene, not the
## script default, is where the authored numbers live from now on.
func test_the_authored_flight_values_arrive_as_exports_not_metadata() -> void:
	if not assert_not_null(_ship, "%s loads with a PlayerController root" % PLAYER_SCENE_PATH):
		return
	assert_almost_eq(_ship.base_speed, AUTHORED_BASE_SPEED, 0.0001, "base_speed")
	assert_almost_eq(_ship.focus_multiplier, AUTHORED_FOCUS_MULTIPLIER, 0.0001, "focus_multiplier")
	for key: StringName in RETIRED_METADATA:
		assert_false(_ship.has_meta(key), "retired metadata/%s" % key)


## One ERROR line in the output is this test's own.
func test_a_missing_visual_root_is_reported_and_stops_the_adapter() -> void:
	_spare = _instantiate_ship()
	if not assert_not_null(_spare, "%s loads a second time" % PLAYER_SCENE_PATH):
		return
	_spare.visual_root = null
	tree.root.add_child(_spare)
	await tree.process_frame
	assert_eq(_spare.process_mode, Node.PROCESS_MODE_DISABLED, "process_mode after the error")
	assert_false(_spare.can_process(), "can_process() after the error")


## ENGINEERING_BRIEF 4.B "Key boundary": banking is visual. `EngineL` lives under
## `VisualRoot` and has to follow the roll, which is what makes the other three
## assertions mean something.
func test_banking_moves_the_visuals_and_leaves_the_combat_volumes_alone() -> void:
	if not assert_not_null(_ship, "%s loads with a PlayerController root" % PLAYER_SCENE_PATH):
		return
	var fixed_paths: Array[NodePath] = [^"DamageCore", ^"GrazeVolume", ^"Muzzle"]
	var before: Dictionary[NodePath, Vector3] = {}
	for path: NodePath in fixed_paths:
		before[path] = (_ship.get_node(path) as Node3D).global_position
	var engine := _ship.get_node(^"VisualRoot/EngineL") as Node3D
	var engine_before := engine.global_position

	_ship.visual_root.rotation.z = FORCED_BANK_RADIANS

	for path: NodePath in fixed_paths:
		var moved := (_ship.get_node(path) as Node3D).global_position
		assert_true(moved.is_equal_approx(before[path]), "%s moved to %s" % [path, moved])
	assert_false(engine.global_position.is_equal_approx(engine_before), "VisualRoot/EngineL banked")


func test_reset_to_teleports_the_ship_and_clears_its_motion() -> void:
	if not assert_not_null(_ship, "%s loads with a PlayerController root" % PLAYER_SCENE_PATH):
		return
	_ship.velocity = Vector3(1.0, 2.0, 3.0)
	_ship.visual_root.rotation.z = FORCED_BANK_RADIANS
	var destination := Transform3D(Basis(), Vector3(4.0, 5.0, 6.0))

	_ship.reset_to(destination)

	assert_true(_ship.global_position.is_equal_approx(destination.origin), "position %s" % _ship.global_position)
	assert_true(_ship.velocity.is_zero_approx(), "velocity %s" % _ship.velocity)
	assert_almost_eq(_ship.visual_root.rotation.z, 0.0, 0.0001, "bank")


## The input actions of CONVENTIONS "Input actions" reach the core: full forward input
## flies at `base_speed` along -Z, the camera rig being unrotated.
func test_the_input_actions_drive_the_body_through_the_core() -> void:
	if not assert_not_null(_ship, "%s loads with a PlayerController root" % PLAYER_SCENE_PATH):
		return
	Input.action_press(&"move_forward")
	await _await_physics_frames()
	assert_almost_eq(_ship.velocity.z, -AUTHORED_BASE_SPEED, 0.001, "forward velocity")
	assert_almost_eq(_ship.velocity.x, 0.0, 0.001, "sideways velocity")
	assert_true(_ship.global_position.z < 0.0, "the ship advanced to z %f" % _ship.global_position.z)


## The yaw contract with [CameraRig]: camera-relative movement is rotated by the rig's
## own `global_rotation.y`, which [method CameraRig.get_yaw] publishes. A rig that kept
## its yaw in a private variable and turned only its `Camera3D` would leave this node
## unrotated, the yaw would read 0 forever, and the ship would keep flying along world
## axes while the camera turned — with nothing raising an error.
func test_forward_input_follows_the_camera_yaw_instead_of_the_world_axis() -> void:
	if not assert_not_null(_ship, "%s loads with a PlayerController root" % PLAYER_SCENE_PATH):
		return
	var parked := _ship.global_position
	# A quarter turn to the left: the camera then faces world -X, and so must forward.
	_ship.camera_rig.rotation.y = PI / 2.0
	assert_almost_eq(_ship.camera_rig.get_yaw(), PI / 2.0, 0.0001, "the rig publishes the turn")

	Input.action_press(&"move_forward")
	await _await_physics_frames()

	assert_almost_eq(_ship.velocity.x, -AUTHORED_BASE_SPEED, 0.001, "forward is now -X")
	assert_almost_eq(_ship.velocity.z, 0.0, 0.001, "and no longer -Z")
	assert_true(_ship.global_position.x < parked.x, "the ship advanced to x %f" % _ship.global_position.x)


func test_disabled_controls_ignore_the_input_and_hold_the_ship_still() -> void:
	if not assert_not_null(_ship, "%s loads with a PlayerController root" % PLAYER_SCENE_PATH):
		return
	var parked := _ship.global_position
	Input.action_press(&"move_forward")

	_ship.set_controls_enabled(false)
	await _await_physics_frames()

	assert_true(_ship.velocity.is_zero_approx(), "velocity %s" % _ship.velocity)
	assert_true(_ship.global_position.is_equal_approx(parked), "position %s" % _ship.global_position)

	_ship.set_controls_enabled(true)
	await _await_physics_frames()
	assert_true(_ship.global_position.z < parked.z, "the ship flies again at z %f" % _ship.global_position.z)


func test_focus_changed_reports_the_edges_of_the_focus_input() -> void:
	if not assert_not_null(_ship, "%s loads with a PlayerController root" % PLAYER_SCENE_PATH):
		return
	var recorder := signal_recorder(_ship, &"focus_changed")

	Input.action_press(&"focus")
	await _await_physics_frames()
	assert_eq(recorder.count(), 1, "one event for pressing focus")
	assert_eq(recorder.last(), [true], "focus_changed payload")

	Input.action_release(&"focus")
	await _await_physics_frames()
	assert_eq(recorder.count(), 2, "one more event for releasing it")
	assert_eq(recorder.last(), [false], "focus_changed payload")


## The Flight Volume an owner injects reaches both the position clamp and the edge
## feedback the HUD will show.
func test_the_injected_flight_volume_clamps_the_ship_and_reports_the_edge() -> void:
	if not assert_not_null(_ship, "%s loads with a PlayerController root" % PLAYER_SCENE_PATH):
		return
	var recorder := signal_recorder(_ship, &"edge_proximity_changed")
	_ship.setup(AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0)))
	_ship.reset_to(Transform3D(Basis(), Vector3(50.0, 0.0, 0.0)))

	await _await_physics_frames()

	assert_almost_eq(_ship.global_position.x, 1.0, 0.001, "clamped to the +X face")
	if not assert_true(recorder.count() > 0, "edge_proximity_changed fired"):
		return
	assert_eq(recorder.last(), [1.0], "sitting on a face reports full proximity")


func _instantiate_ship() -> PlayerController:
	var packed := load(PLAYER_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as PlayerController


func _await_physics_frames() -> void:
	for _frame in range(OBSERVED_PHYSICS_FRAMES):
		await tree.physics_frame
