extends SceneTree
## Offline flight QA for `scenes/dev/arena_harness.tscn` (Claude, F1-02, extended by
## F1-03 and F1-04). Not gameplay code and not attached to any node: it drives the harness
## with simulated input, measures what the ship, the camera and the Target Lock actually
## did, and captures the screenshots recorded in `docs/validation/player-flight.md`. Exits
## non-zero when a measurement is off.
##
## Run it with `tools/godot.ps1 --path . --script res://tools/validate_player_flight.gd`.
## With a display it also writes the PNGs; headless it skips them.
##
## A simulated action is not a physical controller (ENGINEERING_BRIEF Section 8), so the
## gamepad rows of the validation page stay unverified until someone flies it with a pad.
## The tool prints the joypads the host actually has, so that claim stays checkable.


const HARNESS_PATH := "res://scenes/dev/arena_harness.tscn"
const SHOT_PREFIX := "res://docs/validation/player-flight-"
## Where every measured case starts: over the platform, clear of the shrine gate at
## z -27, of the three targets, and of the ceiling.
const OPEN_AIR := Vector3(0.0, 8.0, 20.0)
## Inside the Flight Volume but past the circular platform's rim, where the only floor
## is the clamp: 43 units from the platform center, which has radius 39.
const BEYOND_THE_RIM := Vector3(30.0, 8.0, 25.0)
## Physics ticks each measured case is flown for, and the travel tolerance in units
## per second of flight.
const MEASURE_TICKS := 30
const SPEED_TOLERANCE := 0.05
## Ticks long enough to cross the arena and settle against a surface.
const TRAVEL_TICKS := 300
## Authored Flight Volume, GUIDE Section 13. The west wall's inner face is also at -39.
const BOUNDS_MIN_X := -39.0
## Half the authored body box (2 x 0.8 x 2.1), so the resting distances below are
## derived from the scene instead of recorded from a run.
const BODY_HALF_WIDTH := 1.0
const BODY_HALF_HEIGHT := 0.4
## Resting tolerance: `move_and_slide` keeps its own safe margin off a surface.
const SURFACE_TOLERANCE := 0.1
## Bank tolerance in radians, about 3 degrees of the eased roll.
const BANK_TOLERANCE := 0.05
## Ticks the eased camera needs to settle after the ship is teleported, at
## `position_damping` 10: half a second is five time constants.
const SETTLE_TICKS := 30
## Ticks of held camera input per orbit measurement, and the quarter turn used by the
## camera-relative case: 45 ticks of 120 degrees per second is 90 degrees.
const ORBIT_TICKS := 30
const QUARTER_TURN_TICKS := 45
## Ticks of held pitch input per measurement: 30 degrees, which fits between the rest
## pose at -9 and the +35 ceiling, so the rate is measured and not the clamp.
const PITCH_TICKS := 15
## Ticks of held camera input long enough to reach a pitch limit from anywhere in range.
const PITCH_LIMIT_TICKS := 200
## Ticks awaited for the lock framing to take hold: the blend plus the chase.
const LOCK_TICKS := 60
## The arena's three targets, at the three heights of GUIDE Section 13. The screenshot is
## taken on the highest one, the widest framing.
const LOCK_TARGET_NAMES: Array[String] = ["Low", "Middle", "High"]
const LOCK_SHOT_TARGET := "High"
## The target a fresh lock takes from [constant OPEN_AIR] at the rest pose, worked by hand
## from GUIDE Section 13's positions and camera: Middle is 0.13 of the half-screen from
## the center, Low 0.24 and High 0.42, in the normalized units of the core.
const FIRST_LOCK := "Middle"
## Longest flight allowed for the range case: ten seconds, twice what the arena needs.
const RANGE_TICKS := 600
## Travel in one physics tick at full speed, the resolution the range release is
## measured with.
const RANGE_TOLERANCE := 0.25
## Camera tolerances: degrees for the aim, units for the distances, and a tight one for
## the roll, which is the invariant that must not move at all.
const ANGLE_TOLERANCE := 2.0
const DISTANCE_TOLERANCE := 0.1
const ROLL_TOLERANCE := 0.01
## The shrine gate pass: start short of the gate at z -27, fly forward for two seconds,
## and end up where the beam is between the ship and the camera. The altitude clears the
## beam's underside at y 9.95 and the posts stand at x +-8, so the ship flies between them.
const GATE_APPROACH := Vector3(0.0, 8.0, -12.0)
const GATE_PAST := Vector3(0.0, 8.0, -31.0)
const GATE_TICKS := 120
## Past the gate and lower than [constant GATE_PAST], for the occlusion case: framing
## Middle from here pitches the camera to about -22 degrees, which puts it near
## (0, 12.6, -37.7) and its line to Middle through the beam's 9.95 to 11.05 band at z -27.
## From GATE_PAST the steeper framing lifts that line over the beam.
const BEHIND_THE_BEAM := Vector3(0.0, 6.5, -31.0)

var _player: PlayerController
var _rig: CameraRig
var _targeting: Targeting
var _arena: Node3D
var _readout: Label
var _base_speed: float = 0.0
var _failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var packed := load(HARNESS_PATH) as PackedScene
	if packed == null:
		push_error("Harness could not be loaded: " + HARNESS_PATH)
		quit(1)
		return
	var harness := packed.instantiate()
	root.add_child(harness)
	current_scene = harness
	_arena = harness.get_node_or_null(^"CombatArena") as Node3D
	_player = harness.get_node_or_null(^"CombatArena/PlayerShip") as PlayerController
	_readout = harness.get_node_or_null(^"DebugLayer/Readout") as Label
	if _player == null or _readout == null:
		push_error("Harness is missing CombatArena/PlayerShip or DebugLayer/Readout")
		quit(1)
		return
	_rig = _player.camera_rig
	_targeting = _player.targeting
	if _rig == null or _targeting == null:
		push_error("Harness PlayerShip has no CameraRig or no Targeting")
		quit(1)
		return
	_base_speed = _player.base_speed
	_print_input_devices()
	await _ticks(4)

	await _measure_axis_speeds()
	await _measure_bounded_diagonal()
	await _measure_focus()
	await _stop_against_the_platform()
	await _stop_against_the_flight_volume_floor()
	await _stop_against_the_west_wall()
	await _bank_into_a_strafe()
	await _camera_rests_behind_the_ship()
	await _orbit_with_the_camera_actions()
	await _orbit_stops_at_the_pitch_limits()
	await _fly_where_the_camera_looks()
	await _lock_frames_the_ship_and_the_target()
	await _lock_is_released_out_of_range()
	await _lock_holds_behind_the_shrine_gate()
	await _camera_shortens_against_the_west_wall()
	await _camera_under_the_shrine_gate()

	if _failures > 0:
		print("FLIGHT_FAILED %d" % _failures)
	else:
		print("FLIGHT_OK")
	quit(1 if _failures > 0 else 0)


## One axis at a time: the authored top speed, on the axis the action names, with the
## camera rig unrotated so forward is world -Z.
func _measure_axis_speeds() -> void:
	var cases: Dictionary[StringName, Vector3] = {
		&"move_forward": Vector3.FORWARD,
		&"move_back": Vector3.BACK,
		&"move_right": Vector3.RIGHT,
		&"move_left": Vector3.LEFT,
		&"ascend": Vector3.UP,
		&"descend": Vector3.DOWN,
	}
	for action: StringName in cases:
		var travel: Vector3 = await _fly([action], MEASURE_TICKS)
		var expected: Vector3 = cases[action] * _base_speed * _measured_seconds()
		_report_travel(String(action), travel, expected)


## ENGINEERING_BRIEF 4.B: three full axes at once still fly at the top speed, not at
## `base_speed * sqrt(3)`.
func _measure_bounded_diagonal() -> void:
	var travel: Vector3 = await _fly([&"move_forward", &"move_right", &"ascend"], MEASURE_TICKS)
	_report_diagonal("three-axis diagonal", travel, _base_speed, Vector3(1.0, 1.0, -1.0))
	print("FLIGHT note: unbounded diagonal travel would have been %.3f units" % (
		_base_speed * sqrt(3.0) * _measured_seconds()
	))


## PLANEJAMENTO Section 4: Focus flies at 45 % of the top speed, diagonals included.
func _measure_focus() -> void:
	var travel: Vector3 = await _fly([&"move_forward", &"move_right", &"ascend", &"focus"], MEASURE_TICKS)
	_report_diagonal("focus diagonal", travel, _base_speed * _player.focus_multiplier, Vector3(1.0, 1.0, -1.0))


## The platform surface is at y 0 and stops the body there, above the Flight Volume floor.
func _stop_against_the_platform() -> void:
	_player.reset_to(Transform3D(Basis(), Vector3(0.0, 8.0, 0.0)))
	await _hold([&"descend"], TRAVEL_TICKS)
	_report_value("platform stop y", _player.global_position.y, BODY_HALF_HEIGHT, SURFACE_TOLERANCE)
	await _capture("floor")
	_release([&"descend"])


## GUIDE Section 13: the platform is a circle of radius 39 centered at (0, 0, -6), so the
## rectangular Flight Volume has corners the scenery does not fill. Out there the clamp
## is the only floor, and it holds the ship at y 0 with nothing underneath.
func _stop_against_the_flight_volume_floor() -> void:
	_player.reset_to(Transform3D(Basis(), BEYOND_THE_RIM))
	await _hold([&"descend"], TRAVEL_TICKS)
	_report_value("clamped floor y", _player.global_position.y, 0.0, 0.001)
	_report_value("readout edge", _readout_edge(), 1.0, 0.01)
	await _capture("clamp")
	_release([&"descend"])


## The west wall's inner face is at x -39 and stops the body one half-width short of it,
## just inside the Flight Volume, with the edge feedback risen on the harness readout.
func _stop_against_the_west_wall() -> void:
	_player.reset_to(Transform3D(Basis(), OPEN_AIR))
	await _hold([&"move_left"], TRAVEL_TICKS)
	var resting_x := _player.global_position.x
	_report_value("west wall stop x", resting_x, BOUNDS_MIN_X + BODY_HALF_WIDTH, SURFACE_TOLERANCE)
	var expected_edge := clampf(1.0 - (resting_x - BOUNDS_MIN_X) / _player.edge_margin, 0.0, 1.0)
	_report_value("readout edge", _readout_edge(), expected_edge, 0.01)
	await _capture("edge")
	_release([&"move_left"])


## The roll is eased, so it reaches the authored maximum a few ticks into a held strafe.
## Negative leans into a turn to the ship's right.
func _bank_into_a_strafe() -> void:
	_player.reset_to(Transform3D(Basis(), OPEN_AIR))
	await _hold([&"move_right"], MEASURE_TICKS)
	var target := -deg_to_rad(_player.max_bank_angle_degrees)
	_report_value("bank strafing right", _player.visual_root.rotation.z, target, BANK_TOLERANCE)
	await _capture("bank")
	_release([&"move_right"])


## The rest pose: the authored offset behind and above the ship, level, looking down by
## `default_pitch_degrees` — GUIDE Section 13's camera at (0, 3.2, 8.5), -0.16 rad.
func _camera_rests_behind_the_ship() -> void:
	_player.reset_to(Transform3D(Basis(), OPEN_AIR))
	await _ticks(SETTLE_TICKS)
	var offset := _rig.camera.global_position - _player.global_position
	_report_vector("camera rest offset", offset, _offset_for(_rig.get_yaw(), _rig.default_pitch_degrees), DISTANCE_TOLERANCE)
	_report_value("camera rest pitch", _camera_degrees().x, _rig.default_pitch_degrees, ANGLE_TOLERANCE)
	_report_value("camera rest roll", _camera_degrees().z, 0.0, ROLL_TOLERANCE)


## CONVENTIONS "Input actions": the four `camera_*` actions turn the view at
## `orbit_speed_degrees` per second, opposite directions undo each other exactly, and
## none of it rolls the camera (PLANEJAMENTO Section 3, "stable horizon").
func _orbit_with_the_camera_actions() -> void:
	var start_yaw := _rig.get_yaw()
	var start_pitch := _camera_degrees().x
	await _press_for([&"camera_right"], ORBIT_TICKS)
	# Looking right is a negative rotation around world Y.
	_report_value("orbit yaw, camera_right", rad_to_deg(angle_difference(start_yaw, _rig.get_yaw())),
		-_orbit_degrees(ORBIT_TICKS), ANGLE_TOLERANCE)
	await _press_for([&"camera_up"], PITCH_TICKS)
	_report_value("orbit pitch, camera_up", _camera_degrees().x - start_pitch, _orbit_degrees(PITCH_TICKS), ANGLE_TOLERANCE)
	_report_value("orbit roll", _camera_degrees().z, 0.0, ROLL_TOLERANCE)
	await _capture("camera-orbit")

	await _press_for([&"camera_left"], ORBIT_TICKS)
	await _press_for([&"camera_down"], PITCH_TICKS)
	_report_value("orbit yaw returns", rad_to_deg(angle_difference(start_yaw, _rig.get_yaw())), 0.0, ANGLE_TOLERANCE)
	_report_value("orbit pitch returns", _camera_degrees().x, start_pitch, ANGLE_TOLERANCE)


## The pitch stops at the authored limits instead of tumbling over the ship.
func _orbit_stops_at_the_pitch_limits() -> void:
	await _press_for([&"camera_up"], PITCH_LIMIT_TICKS)
	_report_value("pitch ceiling", _camera_degrees().x, _rig.pitch_limits_degrees.y, ANGLE_TOLERANCE)
	_report_value("pitch ceiling roll", _camera_degrees().z, 0.0, ROLL_TOLERANCE)
	await _press_for([&"camera_down"], PITCH_LIMIT_TICKS)
	_report_value("pitch floor", _camera_degrees().x, _rig.pitch_limits_degrees.x, ANGLE_TOLERANCE)
	_report_value("pitch floor roll", _camera_degrees().z, 0.0, ROLL_TOLERANCE)
	await _press_for([&"camera_up"], _orbit_ticks_for(_rig.default_pitch_degrees - _camera_degrees().x))
	_report_value("pitch back at the rest pose", _camera_degrees().x, _rig.default_pitch_degrees, ANGLE_TOLERANCE)


## The yaw contract in the running game (PLANEJAMENTO Section 3, "horizontal movement is
## camera-relative"): after a quarter turn, forward flies where the camera looks. A rig
## that kept its yaw outside its own node rotation would still turn the camera here while
## the travel stayed on world -Z, which is the silent failure this case exists for.
func _fly_where_the_camera_looks() -> void:
	var start_yaw := _rig.get_yaw()
	await _press_for([&"camera_left"], QUARTER_TURN_TICKS)
	var yaw := _rig.get_yaw()
	_report_value("quarter turn", rad_to_deg(angle_difference(start_yaw, yaw)), _orbit_degrees(QUARTER_TURN_TICKS), ANGLE_TOLERANCE)
	var travel: Vector3 = await _fly([&"move_forward"], MEASURE_TICKS)
	_report_travel("camera-relative forward", travel, Vector3.FORWARD.rotated(Vector3.UP, yaw) * _base_speed * _measured_seconds())
	await _press_for([&"camera_right"], QUARTER_TURN_TICKS)


## PLANEJAMENTO Section 3: a fresh lock takes the target nearest the screen center, the
## camera frames the player and the target together, `next_target` switches, and a
## release returns smoothly to follow mode. The actions go through the real [Targeting]
## and reach the rig through the ship's own connection.
func _lock_frames_the_ship_and_the_target() -> void:
	_player.reset_to(Transform3D(Basis(), OPEN_AIR))
	await _ticks(SETTLE_TICKS)
	await _tap(&"lock_target")
	var first := _targeting.get_current_target()
	_report_bool("lock_target acquires %s, the target nearest the screen center (got %s)" % [
		FIRST_LOCK, _name_of(first),
	], first != null and first.name == FIRST_LOCK)
	# The arena's three targets are at three heights (GUIDE Section 13), which is the
	# "orbit targets at different heights" the brief asks for evidence of.
	var visited: PackedStringArray = []
	for step: int in LOCK_TARGET_NAMES.size():
		if step > 0:
			await _tap(&"next_target")
		await _ticks(LOCK_TICKS)
		var target := _targeting.get_current_target()
		if target == null:
			_failures += 1
			print("FLIGHT FAIL lock: step %d left no target locked" % step)
			return
		var target_name := String(target.name)
		visited.append(target_name)
		_report_bool("lock %s reached the rig and the readout" % target_name, _readout_lock() == target_name)
		var aim := -_rig.camera.global_transform.basis.z
		aim.y = 0.0
		var to_target := target.global_position - _player.global_position
		to_target.y = 0.0
		_report_value("lock %s aims along the ship-to-target line" % target_name,
			rad_to_deg(aim.angle_to(to_target)), 0.0, ANGLE_TOLERANCE)
		_report_bool("lock %s keeps the ship in view" % target_name, _in_view(_player.global_position))
		_report_bool("lock %s keeps the target in view" % target_name, _in_view(target.global_position))
		_report_value("lock %s roll" % target_name, _camera_degrees().z, 0.0, ROLL_TOLERANCE)
		if target_name == LOCK_SHOT_TARGET:
			await _capture("camera-lock")
	await _tap(&"next_target")
	await _ticks(LOCK_TICKS)
	var wrapped := _targeting.get_current_target()
	var distinct := {}
	for target_name: String in visited:
		distinct[target_name] = true
	_report_bool("next_target visits all three once (%s) before wrapping to %s" % [
		" -> ".join(visited), _name_of(wrapped),
	], distinct.size() == LOCK_TARGET_NAMES.size() and wrapped == first)

	var held := _rig.get_yaw()
	await _tap(&"lock_target")
	await _ticks(LOCK_TICKS)
	_report_bool("the release reached the rig", _readout_lock().is_empty() and _targeting.get_current_target() == null)
	_report_value("released camera holds its heading", rad_to_deg(angle_difference(held, _rig.get_yaw())), 0.0, ANGLE_TOLERANCE)


## PLANEJAMENTO Section 3: the lock is "invalidated by ... range". Flies away from a locked
## target with the camera-relative actions — back is away from the target while the
## camera frames it — and records the distance at the tick the lock let go.
func _lock_is_released_out_of_range() -> void:
	await _recentre_camera()
	_player.reset_to(Transform3D(Basis(), OPEN_AIR))
	await _ticks(SETTLE_TICKS)
	await _tap(&"lock_target")
	var target := _targeting.get_current_target()
	if target == null:
		_failures += 1
		print("FLIGHT FAIL range: nothing was locked from the open-air start")
		return
	var flight: Array[StringName] = [&"move_back", &"move_right", &"ascend"]
	for action: StringName in flight:
		Input.action_press(action)
	var last_held := 0.0
	var released_at := -1.0
	for _tick: int in RANGE_TICKS:
		await physics_frame
		var distance := target.global_position.distance_to(_player.global_position)
		if _targeting.get_current_target() == null:
			released_at = distance
			break
		last_held = distance
	_release(flight)
	if released_at < 0.0:
		_failures += 1
		print("FLIGHT FAIL range: the lock on %s held for %d ticks, farthest %.2f of %.1f" % [
			target.name, RANGE_TICKS, last_held, _targeting.max_distance,
		])
		return
	_report_value("lock on %s released out of range at" % target.name, released_at, _targeting.max_distance, RANGE_TOLERANCE)
	_report_bool("lock on %s held while in range (last held at %.3f)" % [target.name, last_held], last_held <= _targeting.max_distance)
	print("FLIGHT note: range release at ship %s" % _player.global_position)


## ENGINEERING_BRIEF 4.B "scenery occlusion": a locked target that passes behind scenery
## keeps the lock, and cannot be freshly acquired from there. The shrine gate's beam at
## z -27 is the only overhead scenery with collision in the arena — the trees are meshes
## only — so the ship is put past the gate with the camera looking back through it.
func _lock_holds_behind_the_shrine_gate() -> void:
	await _recentre_camera()
	_player.reset_to(Transform3D(Basis(), OPEN_AIR))
	await _ticks(SETTLE_TICKS)
	await _tap(&"lock_target")
	var target := _targeting.get_current_target()
	if target == null or target.name != FIRST_LOCK:
		_failures += 1
		print("FLIGHT FAIL occlusion: expected a lock on %s, got %s" % [FIRST_LOCK, _name_of(target)])
		return
	_player.reset_to(Transform3D(Basis(), BEHIND_THE_BEAM))
	await _ticks(LOCK_TICKS)
	var candidate := _candidate_for(target)
	# The same ray the adapter casts, repeated to name what is in the way.
	var query := PhysicsRayQueryParameters3D.create(_rig.camera.global_position, target.global_position, _targeting.occlusion_mask)
	var hit := _rig.camera.get_world_3d().direct_space_state.intersect_ray(query)
	print("FLIGHT note: camera at %s, pitch %.1f; the line to %s hits %s" % [
		_rig.camera.global_position, _camera_degrees().x, target.name,
		"nothing" if hit.is_empty() else "%s at %s" % [(hit["collider"] as Node).name, hit["position"]],
	])
	_report_bool("%s is hidden behind the gate beam" % target.name, candidate != null and not candidate.visible)
	_report_bool("the lock on %s holds behind scenery" % target.name, _targeting.get_current_target() == target)
	await _capture("targeting-occluded")
	await _tap(&"lock_target")
	await _tap(&"lock_target")
	var reacquired := _targeting.get_current_target()
	_report_bool("a fresh lock behind the gate does not take the hidden %s (got %s)" % [
		target.name, _name_of(reacquired),
	], reacquired != target)
	if reacquired != null:
		await _tap(&"lock_target")
	await _ticks(LOCK_TICKS)


## ENGINEERING_BRIEF 4.B "camera behavior near geometry": turned into the west wall, the
## rig shortens against it instead of letting the view pass through.
func _camera_shortens_against_the_west_wall() -> void:
	await _recentre_camera()
	_player.reset_to(Transform3D(Basis(), OPEN_AIR))
	await _hold([&"move_left"], TRAVEL_TICKS)
	_release([&"move_left"])
	# A quarter turn to the right swings the camera onto the wall side of the ship.
	await _press_for([&"camera_right"], QUARTER_TURN_TICKS)
	await _ticks(SETTLE_TICKS)

	var ship := _player.global_position
	var direction := _offset_for(_rig.get_yaw(), _camera_degrees().x).normalized()
	var expected := (BOUNDS_MIN_X - ship.x) / direction.x - _rig.obstruction_margin
	_report_value("camera distance against the west wall", _camera_distance(), expected, DISTANCE_TOLERANCE)
	_report_bool("the camera stays inside the wall", _rig.camera.global_position.x >= BOUNDS_MIN_X)
	_report_value("obstructed roll", _camera_degrees().z, 0.0, ROLL_TOLERANCE)
	await _capture("camera-obstruction")

	await _press_for([&"camera_left"], QUARTER_TURN_TICKS)


## The shrine gate's beam at z -27 is the arena's only overhead scenery. Flying under it
## measures both halves of the obstruction rule: how short the rig gets, and the largest
## single-frame change on the way in and out, which is what a pop would look like.
func _camera_under_the_shrine_gate() -> void:
	await _recentre_camera()
	_player.reset_to(Transform3D(Basis(), GATE_APPROACH))
	await _ticks(SETTLE_TICKS)
	_report_value("camera recentred before the gate", rad_to_deg(_rig.get_yaw()), 0.0, ANGLE_TOLERANCE)
	var shortest := _camera_distance()
	var largest_step := 0.0
	var previous := shortest
	var rolled := 0.0
	Input.action_press(&"move_forward")
	for _tick: int in range(GATE_TICKS):
		await physics_frame
		var current := _camera_distance()
		shortest = minf(shortest, current)
		largest_step = maxf(largest_step, absf(current - previous))
		rolled = maxf(rolled, absf(_camera_degrees().z))
		previous = current
	_release([&"move_forward"])

	_report_bool("the gate shortens the camera", shortest < _offset_for(0.0, _rig.default_pitch_degrees).length() - 1.0)
	_report_value("roll while passing the gate", rolled, 0.0, ROLL_TOLERANCE)
	print("FLIGHT note: shortest camera distance under the gate %.3f, largest single-frame change %.3f" % [
		shortest, largest_step,
	])
	_player.reset_to(Transform3D(Basis(), GATE_PAST))
	await _ticks(SETTLE_TICKS)
	await _capture("camera-gate")


## Travel over [param ticks] physics frames while [param actions] are held, always from
## [constant OPEN_AIR] so every case starts from the same clear spot.
func _fly(actions: Array[StringName], ticks: int) -> Vector3:
	_player.reset_to(Transform3D(Basis(), OPEN_AIR))
	await _ticks(2)
	for action: StringName in actions:
		Input.action_press(action)
	# One tick for the press to reach a physics step, so the whole window is full speed.
	await _ticks(1)
	var start := _player.global_position
	await _ticks(ticks)
	var travel := _player.global_position - start
	_release(actions)
	return travel


## Holds [param actions] down for [param ticks] without measuring and leaves them held,
## so a screenshot taken afterwards shows the ship under power.
func _hold(actions: Array[StringName], ticks: int) -> void:
	for action: StringName in actions:
		Input.action_press(action)
	await _ticks(ticks)


## Holds [param actions] for exactly [param ticks] physics steps: the leading await lands
## at the start of a step, before the nodes run, so the count is not off by one.
func _press_for(actions: Array[StringName], ticks: int) -> void:
	await physics_frame
	for action: StringName in actions:
		Input.action_press(action)
	await _ticks(ticks)
	_release(actions)


## Turns the camera back to its rest heading. A released lock deliberately leaves the
## camera where it let go, so a case that must be reproducible starts by undoing that.
func _recentre_camera() -> void:
	var yaw_degrees := rad_to_deg(angle_difference(0.0, _rig.get_yaw()))
	var yaw_actions: Array[StringName] = [&"camera_right" if yaw_degrees > 0.0 else &"camera_left"]
	await _press_for(yaw_actions, _orbit_ticks_for(yaw_degrees))
	var pitch_degrees := _rig.default_pitch_degrees - _camera_degrees().x
	var pitch_actions: Array[StringName] = [&"camera_up" if pitch_degrees > 0.0 else &"camera_down"]
	await _press_for(pitch_actions, _orbit_ticks_for(pitch_degrees))


## One press and release of an action [Targeting] reads with `is_action_just_pressed` in
## `_physics_process`. The press is held across two physics ticks, so it lands on a step
## however many render frames fall between them.
func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _ticks(2)
	Input.action_release(action)
	await _ticks(1)


func _release(actions: Array[StringName]) -> void:
	for action: StringName in actions:
		Input.action_release(action)


func _ticks(count: int) -> void:
	for _tick in range(count):
		await physics_frame


func _measured_seconds() -> float:
	return float(MEASURE_TICKS) / float(Engine.physics_ticks_per_second)


## The edge-proximity value as the harness label shows it, or -1 when the line is absent.
func _readout_edge() -> float:
	for line: String in _readout.text.split("\n"):
		if line.begins_with("edge "):
			return line.trim_prefix("edge ").to_float()
	return -1.0


## The locked target's name as the harness label shows it, or an empty string while
## nothing is locked. Reading the readout is how the action path is checked end to end.
func _readout_lock() -> String:
	for line: String in _readout.text.split("\n"):
		if not line.begins_with("lock "):
			continue
		var value := line.trim_prefix("lock ").get_slice(" ", 0)
		return "" if value == "none" else value
	return ""


func _name_of(node: Node) -> String:
	return "nothing" if node == null else String(node.name)


## The candidate [Targeting] builds for [param target] right now, or null when it builds
## none. Only valid during a physics step, which is where the awaits above resume.
func _candidate_for(target: Node3D) -> TargetSelector.Candidate:
	for candidate: TargetSelector.Candidate in _targeting.build_candidates():
		if candidate.id == target.get_instance_id():
			return candidate
	return null


## Camera offset from the ship for a yaw and a pitch, from the geometry the rig documents:
## the authored height and distance, rotated by the pitch and then around world Y.
func _offset_for(yaw: float, pitch_degrees: float) -> Vector3:
	var offset := Vector3(0.0, _rig.follow_height, _rig.follow_distance)
	return offset.rotated(Vector3.RIGHT, deg_to_rad(pitch_degrees)).rotated(Vector3.UP, yaw)


## Pitch, yaw and roll of the rendered camera, in degrees.
func _camera_degrees() -> Vector3:
	var euler := _rig.camera.global_transform.basis.get_euler()
	return Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z))


func _camera_distance() -> float:
	return _rig.camera.global_position.distance_to(_player.global_position)


## How far the view turns while an orbit action is held for [param ticks] physics steps.
func _orbit_degrees(ticks: int) -> float:
	return _rig.orbit_speed_degrees * _rig.sensitivity * float(ticks) / float(Engine.physics_ticks_per_second)


func _orbit_ticks_for(degrees: float) -> int:
	return roundi(absf(degrees) * float(Engine.physics_ticks_per_second) / (_rig.orbit_speed_degrees * _rig.sensitivity))


## Whether [param point] is in front of the camera and inside its vertical field of view,
## which is what "framed" means for a Target Lock. Measured from the camera basis rather
## than from the frustum, so the answer does not depend on the window size.
func _in_view(point: Vector3) -> bool:
	var local := _rig.camera.global_transform.affine_inverse() * point
	if local.z >= 0.0:
		return false
	return rad_to_deg(atan2(absf(local.y), absf(local.z))) <= _rig.camera.fov * 0.5


## The devices this host actually has. A simulated action proves nothing about a pad
## (ENGINEERING_BRIEF Section 8), so the validation page quotes this line instead of
## inheriting a controller claim.
func _print_input_devices() -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		print("FLIGHT note: no joypad connected on this host; every case below is simulated input")
		return
	var names: PackedStringArray = []
	for pad: int in pads:
		# A "known" pad is one Godot has a standard mapping for, which is what makes the
		# Xbox-named bindings of CONVENTIONS "Input actions" land on the right buttons.
		names.append("%d:%s (standard mapping: %s)" % [pad, Input.get_joy_name(pad), Input.is_joy_known(pad)])
	print("FLIGHT note: joypads connected: %s; cases below are still simulated input" % ", ".join(names))


func _report_travel(label: String, travel: Vector3, expected: Vector3) -> void:
	var seconds := _measured_seconds()
	var passed := travel.distance_to(expected) <= SPEED_TOLERANCE * seconds
	if not passed:
		_failures += 1
	print("FLIGHT %s %s: speed %.3f of %.1f, travel %s, expected %s" % [
		"ok  " if passed else "FAIL", label, travel.length() / seconds, _base_speed, travel, expected,
	])


## A diagonal is pinned by its speed, not by a fixed split between the axes: the input
## layer normalizes the horizontal pair before the model clamps the whole 3D vector, so
## the vertical axis keeps the larger share of a three-axis diagonal. What the design
## fixes (PLANEJAMENTO Section 3, ENGINEERING_BRIEF 4.B) is the total speed and that
## every pressed axis moves the way it was pressed.
func _report_diagonal(label: String, travel: Vector3, expected_speed: float, pressed: Vector3) -> void:
	var speed := travel.length() / _measured_seconds()
	var passed := absf(speed - expected_speed) <= SPEED_TOLERANCE
	for axis: int in 3:
		if not is_equal_approx(signf(travel[axis]), signf(pressed[axis])):
			passed = false
	if not passed:
		_failures += 1
	print("FLIGHT %s %s: speed %.3f, expected %.3f +- %.3f, travel %s" % [
		"ok  " if passed else "FAIL", label, speed, expected_speed, SPEED_TOLERANCE, travel,
	])


func _report_vector(label: String, actual: Vector3, expected: Vector3, tolerance: float) -> void:
	var passed := actual.distance_to(expected) <= tolerance
	if not passed:
		_failures += 1
	print("FLIGHT %s %s: %s, expected %s +- %.3f" % [
		"ok  " if passed else "FAIL", label, actual, expected, tolerance,
	])


## For the checks that are a yes or a no: in view, inside the wall, the action arrived.
func _report_bool(label: String, passed: bool) -> void:
	if not passed:
		_failures += 1
	print("FLIGHT %s %s" % ["ok  " if passed else "FAIL", label])


func _report_value(label: String, actual: float, expected: float, tolerance: float) -> void:
	var passed := absf(actual - expected) <= tolerance
	if not passed:
		_failures += 1
	print("FLIGHT %s %s: %.3f, expected %.3f +- %.3f" % [
		"ok  " if passed else "FAIL", label, actual, expected, tolerance,
	])


func _capture(name_suffix: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := SHOT_PREFIX + name_suffix + ".png"
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		_failures += 1
		print("FLIGHT FAIL screenshot %s: %s" % [path, error_string(result)])
		return
	print("FLIGHT ok   screenshot %s" % path)
