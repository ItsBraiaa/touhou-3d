extends SceneTree
## Offline flight QA for `scenes/dev/arena_harness.tscn` (Claude, F1-02). Not gameplay
## code and not attached to any node: it drives the harness with simulated input,
## measures what the ship actually did, and captures the screenshots recorded in
## `docs/validation/player-flight.md`. Exits non-zero when a measurement is off.
##
## Run it with `tools/godot.ps1 --path . --script res://tools/validate_player_flight.gd`.
## With a display it also writes the three PNGs; headless it skips them.
##
## A simulated action is not a physical controller (ENGINEERING_BRIEF Section 8), so the
## gamepad rows of the validation page stay unverified until someone flies it with a pad.


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

var _player: PlayerController
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
	_player = harness.get_node_or_null(^"CombatArena/PlayerShip") as PlayerController
	_readout = harness.get_node_or_null(^"DebugLayer/Readout") as Label
	if _player == null or _readout == null:
		push_error("Harness is missing CombatArena/PlayerShip or DebugLayer/Readout")
		quit(1)
		return
	_base_speed = _player.base_speed
	await _ticks(4)

	await _measure_axis_speeds()
	await _measure_bounded_diagonal()
	await _measure_focus()
	await _stop_against_the_platform()
	await _stop_against_the_flight_volume_floor()
	await _stop_against_the_west_wall()
	await _bank_into_a_strafe()

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
