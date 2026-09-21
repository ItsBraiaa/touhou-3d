extends TestCase
## Behavior of the [FlightModel] Rules Core: velocity from input axes and camera yaw,
## Flight Volume clamping, edge proximity feedback, and the visual bank angle.
##
## Expected values come from the design documents, not from the implementation:
## `base_speed` 12.0 and `focus_multiplier` 0.45 are GUIDE Section 13 "Authored player
## values", and the bounds are the same section's FlightBounds, min (-39, 0, -45) to
## max (39, 30, 33). `EDGE_MARGIN` is a fixture of these tests: no design document fixes
## one, and 4.0 is the default the F1-02 adapter ticket proposes to export.

const BASE_SPEED := 12.0
const FOCUS_MULTIPLIER := 0.45
const EDGE_MARGIN := 4.0

var _model: FlightModel


func before_each() -> void:
	_model = FlightModel.new()
	_model.configure(BASE_SPEED, FOCUS_MULTIPLIER, EDGE_MARGIN)


func test_configure_values_are_the_ones_the_model_uses() -> void:
	# Every other test configures the authored values, so a model that ignored
	# configure() and hardcoded 12.0, 0.45 and 4.0 would still pass them all. This one
	# configures values that appear nowhere in the design documents.
	var tuned := FlightModel.new()
	tuned.configure(7.0, 0.25, 10.0)
	tuned.set_bounds(_flight_bounds())
	assert_almost_eq(tuned.compute_velocity(Vector2(1.0, 0.0), 0.0, false, 0.0).x, 7.0)
	assert_almost_eq(tuned.compute_velocity(Vector2(1.0, 0.0), 0.0, true, 0.0).x, 1.75, 0.0001, "7.0 * 0.25")
	assert_almost_eq(tuned.bank_angle(Vector3(7.0, 0.0, 0.0), 0.0, 0.6), -0.6, 0.0001, "7.0 is now full lateral speed")
	# Five units from the +X face is half of a ten-unit margin.
	assert_almost_eq(tuned.edge_proximity(Vector3(34.0, 15.0, -6.0)), 0.5, 0.0001)


func test_zero_input_gives_zero_velocity() -> void:
	assert_eq(_model.compute_velocity(Vector2.ZERO, 0.0, false, 0.0), Vector3.ZERO)
	assert_eq(_model.compute_velocity(Vector2.ZERO, 0.0, true, 0.0), Vector3.ZERO,
		"Focus does not move the ship on its own")


func test_single_axis_full_input_moves_at_base_speed() -> void:
	# Forward is -Z, strafe right is +X, ascend is +Y (GUIDE Section 13, world up is +Y).
	assert_eq(_model.compute_velocity(Vector2(0.0, 1.0), 0.0, false, 0.0), Vector3(0.0, 0.0, -BASE_SPEED))
	assert_eq(_model.compute_velocity(Vector2(1.0, 0.0), 0.0, false, 0.0), Vector3(BASE_SPEED, 0.0, 0.0))
	assert_eq(_model.compute_velocity(Vector2.ZERO, 1.0, false, 0.0), Vector3(0.0, BASE_SPEED, 0.0))
	assert_eq(_model.compute_velocity(Vector2.ZERO, -1.0, false, 0.0), Vector3(0.0, -BASE_SPEED, 0.0))


func test_full_diagonal_on_three_axes_is_bounded_to_base_speed() -> void:
	# Unclamped this would be BASE_SPEED * sqrt(3) = 20.7846, which is the bug the
	# ticket names: the 3D input vector is clamped to length 1 before it is scaled.
	var velocity := _model.compute_velocity(Vector2(1.0, 1.0), 1.0, false, 0.0)
	assert_almost_eq(velocity.length(), BASE_SPEED)
	assert_almost_eq(velocity.x, BASE_SPEED / sqrt(3.0))
	assert_almost_eq(velocity.y, BASE_SPEED / sqrt(3.0))
	assert_almost_eq(velocity.z, -BASE_SPEED / sqrt(3.0))


func test_partial_input_keeps_its_magnitude() -> void:
	# The clamp only shortens: half-deflected input must stay at half speed, not be
	# normalized up to the full one.
	var velocity := _model.compute_velocity(Vector2(0.0, 0.5), 0.0, false, 0.0)
	assert_almost_eq(velocity.length(), BASE_SPEED * 0.5)


func test_focus_scales_every_axis_by_the_focus_multiplier() -> void:
	# PLANEJAMENTO Section 4 "Focus and vulnerable core": 45 % of the movement speed.
	var focus_speed := BASE_SPEED * FOCUS_MULTIPLIER
	assert_almost_eq(_model.compute_velocity(Vector2(1.0, 0.0), 0.0, true, 0.0).x, focus_speed)
	assert_almost_eq(_model.compute_velocity(Vector2(0.0, 1.0), 0.0, true, 0.0).z, -focus_speed)
	assert_almost_eq(_model.compute_velocity(Vector2.ZERO, 1.0, true, 0.0).y, focus_speed)
	var diagonal := _model.compute_velocity(Vector2(1.0, 1.0), 1.0, true, 0.0)
	assert_almost_eq(diagonal.length(), focus_speed, 0.0001,
		"Focus scales the bounded diagonal, it does not lift the bound")


func test_camera_yaw_rotates_the_horizontal_plane_only() -> void:
	# A quarter turn left of the camera sends forward input to world -X, and the same
	# quarter turn the other way sends it to +X: one consistent convention, matching
	# Godot's Vector3.rotated(Vector3.UP, yaw) with forward at -Z.
	var forward_left := _model.compute_velocity(Vector2(0.0, 1.0), 0.0, false, PI * 0.5)
	assert_almost_eq(forward_left.x, -BASE_SPEED)
	assert_almost_eq(forward_left.y, 0.0)
	assert_almost_eq(forward_left.z, 0.0)
	var forward_right := _model.compute_velocity(Vector2(0.0, 1.0), 0.0, false, -PI * 0.5)
	assert_almost_eq(forward_right.x, BASE_SPEED)
	# Strafe stays a quarter turn ahead of forward under the same yaw.
	var strafe_left := _model.compute_velocity(Vector2(1.0, 0.0), 0.0, false, PI * 0.5)
	assert_almost_eq(strafe_left.z, -BASE_SPEED)
	assert_almost_eq(strafe_left.x, 0.0)


func test_vertical_input_ignores_camera_yaw() -> void:
	# PLANEJAMENTO Section 3: ascent and descent follow the world's vertical axis.
	for yaw: float in [0.0, PI * 0.5, PI, -PI * 0.25, 2.0]:
		var velocity := _model.compute_velocity(Vector2.ZERO, 1.0, false, yaw)
		assert_almost_eq(velocity.y, BASE_SPEED, 0.0001, "yaw %f must not tilt the ascent" % yaw)
		assert_almost_eq(Vector2(velocity.x, velocity.z).length(), 0.0, 0.0001, "yaw %f must not push the ship sideways" % yaw)


func test_integration_is_frame_rate_independent() -> void:
	# The adapter integrates velocity * delta, so one second of flight must cover the
	# same distance at 60 Hz and at 30 Hz. CONVENTIONS "Time and randomness": the core
	# never sees a delta.
	assert_almost_eq(_travelled(60, 1.0 / 60.0), BASE_SPEED, 0.0001)
	assert_almost_eq(_travelled(30, 1.0 / 30.0), BASE_SPEED, 0.0001)
	assert_almost_eq(_travelled(60, 1.0 / 60.0), _travelled(30, 1.0 / 30.0), 0.0001)


## Distance a ship flying full forward covers over [param ticks] steps of [param delta],
## integrated the way the adapter does it.
func _travelled(ticks: int, delta: float) -> float:
	var position := Vector3.ZERO
	for _tick: int in range(ticks):
		position += _model.compute_velocity(Vector2(0.0, 1.0), 0.0, false, 0.0) * delta
	return position.length()


func test_clamp_position_is_identity_before_bounds_are_set() -> void:
	assert_eq(_model.clamp_position(Vector3(1000.0, -50.0, 7.0)), Vector3(1000.0, -50.0, 7.0))


func test_clamp_position_keeps_points_inside_and_pulls_points_outside_to_the_nearest_face() -> void:
	_model.set_bounds(_flight_bounds())
	assert_eq(_model.clamp_position(Vector3(0.0, 10.0, 0.0)), Vector3(0.0, 10.0, 0.0), "a point well inside is untouched")
	assert_eq(_model.clamp_position(Vector3(39.0, 30.0, 33.0)), Vector3(39.0, 30.0, 33.0),
		"a point exactly on the max corner is still inside")
	assert_eq(_model.clamp_position(Vector3(50.0, 10.0, 0.0)), Vector3(39.0, 10.0, 0.0),
		"only the axis that left is pulled back")
	assert_eq(_model.clamp_position(Vector3(0.0, -8.0, 0.0)), Vector3(0.0, 0.0, 0.0), "the floor is y = 0")
	assert_eq(_model.clamp_position(Vector3(1000.0, 1000.0, 1000.0)), Vector3(39.0, 30.0, 33.0))
	assert_eq(_model.clamp_position(Vector3(-1000.0, -1000.0, -1000.0)), Vector3(-39.0, 0.0, -45.0))


## The Flight Volume authored in GUIDE Section 13: min (-39, 0, -45), max (39, 30, 33).
func _flight_bounds() -> AABB:
	return AABB(Vector3(-39.0, 0.0, -45.0), Vector3(78.0, 30.0, 78.0))


func test_edge_proximity_is_zero_at_the_center_and_one_at_a_face() -> void:
	_model.set_bounds(_flight_bounds())
	# The volume spans x -39..39, y 0..30, z -45..33, so its center is (0, 15, -6) and
	# the nearest face there is 15 units away, far beyond the 4-unit margin.
	assert_almost_eq(_model.edge_proximity(Vector3(0.0, 15.0, -6.0)), 0.0, 0.0001, "the center is free")
	assert_almost_eq(_model.edge_proximity(Vector3(35.0, 15.0, -6.0)), 0.0, 0.0001,
		"exactly one margin from the +X face is still free")
	assert_almost_eq(_model.edge_proximity(Vector3(37.0, 15.0, -6.0)), 0.5, 0.0001, "half a margin from the +X face")
	assert_almost_eq(_model.edge_proximity(Vector3(39.0, 15.0, -6.0)), 1.0, 0.0001, "on the +X face")
	assert_almost_eq(_model.edge_proximity(Vector3(0.0, 0.0, -6.0)), 1.0, 0.0001, "on the floor")
	assert_almost_eq(_model.edge_proximity(Vector3(0.0, 15.0, -45.0)), 1.0, 0.0001, "on the -Z face")
	assert_almost_eq(_model.edge_proximity(Vector3(200.0, 15.0, -6.0)), 1.0, 0.0001,
		"outside stays at the maximum, it does not wrap")
	# The nearest face wins: one unit from the ceiling and far from every other face.
	assert_almost_eq(_model.edge_proximity(Vector3(0.0, 29.0, -6.0)), 0.75, 0.0001)


func test_edge_proximity_is_zero_without_bounds() -> void:
	assert_almost_eq(FlightModel.new().edge_proximity(Vector3(1000.0, 1000.0, 1000.0)), 0.0)


func test_edge_proximity_changed_fires_once_per_real_change() -> void:
	_model.set_bounds(_flight_bounds())
	var recorder := signal_recorder(_model, &"edge_proximity_changed")
	_model.edge_proximity(Vector3(0.0, 15.0, -6.0))
	assert_eq(recorder.count(), 0, "the center reads 0, which is where the model already is")
	_model.edge_proximity(Vector3(39.0, 15.0, -6.0))
	assert_eq(recorder.count(), 1)
	assert_almost_eq(recorder.last()[0], 1.0)
	_model.edge_proximity(Vector3(39.0, 15.0, -6.0))
	assert_eq(recorder.count(), 1, "a repeated value is not an event")
	_model.edge_proximity(Vector3(0.0, 15.0, -6.0))
	assert_eq(recorder.count(), 2)
	assert_almost_eq(recorder.last()[0], 0.0)


func test_edge_proximity_changed_measures_drift_from_the_last_value_emitted() -> void:
	# A ship creeping towards a face in steps too small to report must still be
	# reported once the steps add up, which is why the remembered value moves only
	# when the signal fires. Every position here is exact in binary: a 1/32 unit of
	# travel is 1/128 = 0.0078125 of proximity against the 4-unit margin, so one step
	# is under the 0.01 threshold and two steps are over it.
	_model.set_bounds(_flight_bounds())
	var recorder := signal_recorder(_model, &"edge_proximity_changed")
	_model.edge_proximity(Vector3(35.0, 15.0, -6.0))
	_model.edge_proximity(Vector3(35.03125, 15.0, -6.0))
	assert_eq(recorder.count(), 0, "one step of 0.0078 is not worth an event")
	_model.edge_proximity(Vector3(35.0625, 15.0, -6.0))
	assert_eq(recorder.count(), 1, "two of them, measured from the last value emitted, are")
	assert_almost_eq(recorder.last()[0], 0.015625, 0.0000001)


func test_bank_angle_is_level_in_forward_flight_and_leans_with_lateral_motion() -> void:
	var max_angle := 0.6
	assert_almost_eq(_model.bank_angle(Vector3(0.0, 0.0, -BASE_SPEED), 0.0, max_angle), 0.0, 0.0001,
		"pure forward flight is level")
	assert_almost_eq(_model.bank_angle(Vector3.ZERO, 0.0, max_angle), 0.0, 0.0001, "so is standing still")
	assert_almost_eq(_model.bank_angle(Vector3(0.0, BASE_SPEED, 0.0), 0.0, max_angle), 0.0, 0.0001, "and so is climbing")
	var right := _model.bank_angle(Vector3(BASE_SPEED, 0.0, 0.0), 0.0, max_angle)
	var left := _model.bank_angle(Vector3(-BASE_SPEED, 0.0, 0.0), 0.0, max_angle)
	assert_almost_eq(right, -max_angle, 0.0001, "full lateral speed reaches the maximum lean")
	assert_almost_eq(left, max_angle, 0.0001, "the other way leans the other way")
	assert_almost_eq(_model.bank_angle(Vector3(BASE_SPEED * 0.5, 0.0, 0.0), 0.0, max_angle), -max_angle * 0.5, 0.0001,
		"half the lateral speed, half the lean")


func test_bank_angle_is_clamped_and_follows_the_camera() -> void:
	var max_angle := 0.6
	assert_almost_eq(_model.bank_angle(Vector3(1000.0, 0.0, 0.0), 0.0, max_angle), -max_angle, 0.0001,
		"an overspeeding ship cannot roll past the maximum")
	assert_almost_eq(_model.bank_angle(Vector3(-1000.0, 0.0, 0.0), 0.0, max_angle), max_angle, 0.0001)
	# Lateral means lateral to the camera: the same strafe input under a quarter turn
	# produces the same lean, even though the world velocity now points along -Z.
	var yaw := PI * 0.5
	var strafe := _model.compute_velocity(Vector2(1.0, 0.0), 0.0, false, yaw)
	assert_almost_eq(_model.bank_angle(strafe, yaw, max_angle), -max_angle, 0.0001)
	var forward := _model.compute_velocity(Vector2(0.0, 1.0), 0.0, false, yaw)
	assert_almost_eq(_model.bank_angle(forward, yaw, max_angle), 0.0, 0.0001)


func test_the_model_holds_no_position_state() -> void:
	# ENGINEERING_BRIEF Section 4.B: visual banking cannot move the damage core. The
	# model cannot move anything, because it never stores where the ship is: the only
	# spatial value it keeps is the authored Flight Volume, which is an AABB.
	_model.set_bounds(_flight_bounds())
	_model.bank_angle(Vector3(BASE_SPEED, 0.0, 0.0), 0.0, 0.6)
	_model.edge_proximity(Vector3(39.0, 15.0, -6.0))
	var forbidden: Array[int] = [TYPE_VECTOR3, TYPE_VECTOR2, TYPE_TRANSFORM3D, TYPE_TRANSFORM2D]
	var checked := 0
	for property: Dictionary in _model.get_property_list():
		var usage: int = property["usage"]
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		checked += 1
		var name_and_type := "%s is a %s" % [property["name"], type_string(property["type"])]
		assert_false(forbidden.has(int(property["type"])), name_and_type)
	assert_true(checked > 0, "the property filter must actually see the model's own variables")
	# And behaviorally: drive it through a long, varied sequence, then ask the same
	# three questions again. A model that remembered a position could not answer the
	# same way twice.
	var velocity_before := _model.compute_velocity(Vector2(0.3, 0.7), -0.2, false, 1.1)
	var clamped_before := _model.clamp_position(Vector3(1000.0, -5.0, 12.0))
	var bank_before := _model.bank_angle(Vector3(3.0, 0.0, -4.0), 1.1, 0.6)
	for x: float in [-200.0, -39.0, 0.0, 38.0, 500.0]:
		_model.clamp_position(Vector3(x, 15.0, -6.0))
		_model.edge_proximity(Vector3(x, 15.0, -6.0))
		_model.bank_angle(Vector3(x, 0.0, 0.0), 0.0, 0.6)
	assert_eq(_model.compute_velocity(Vector2(0.3, 0.7), -0.2, false, 1.1), velocity_before)
	assert_eq(_model.clamp_position(Vector3(1000.0, -5.0, 12.0)), clamped_before)
	assert_eq(_model.bank_angle(Vector3(3.0, 0.0, -4.0), 1.1, 0.6), bank_before)
