class_name FlightModel
extends RefCounted
## Rules Core for player flight: turns input axes and a camera yaw into a velocity.
##
## Node-free and stateless about position (ADR-0001). The adapter reads the input,
## calls [method compute_velocity] every physics tick, integrates the result itself,
## and renders what the model reports.


## Emitted when the distance to the Flight Volume boundary has changed enough to be
## worth showing, that is by more than [constant EDGE_PROXIMITY_EPSILON]. [param value]
## is the new [method edge_proximity].
signal edge_proximity_changed(value: float)

## Smallest change in edge proximity that is reported as an event.
const EDGE_PROXIMITY_EPSILON := 0.01

var _base_speed: float = 0.0
var _focus_multiplier: float = 1.0
var _edge_margin: float = 0.0
var _bounds: AABB = AABB()
var _has_bounds: bool = false
var _last_edge_proximity: float = 0.0


## Sets the authored flight values: top speed in units per second, the factor applied
## to it while Focus is held, and the distance from a Flight Volume face at which
## [method edge_proximity] starts to rise.
func configure(base_speed: float, focus_multiplier: float, edge_margin: float) -> void:
	_base_speed = base_speed
	_focus_multiplier = focus_multiplier
	_edge_margin = edge_margin


## Sets the Flight Volume the ship is kept inside. Until it is called the model clamps
## nothing. An [AABB] is a position and a size, not two corners: a caller holding a min
## and a max passes `AABB(min, max - min)`.
func set_bounds(bounds: AABB) -> void:
	_bounds = bounds
	_has_bounds = true


## Velocity in world units per second for the given input. [param move].x is strafe
## (right positive), [param move].y is forward (positive forward), [param vertical] is
## ascend positive; all three are already dead-zoned and in [-1, 1]. Pure: no delta and
## no stored state, so the same arguments always give the same vector.
func compute_velocity(move: Vector2, vertical: float, focus: bool, camera_yaw: float) -> Vector3:
	var direction := Vector3(move.x, vertical, -move.y).limit_length(1.0)
	if focus:
		direction *= _focus_multiplier
	return direction.rotated(Vector3.UP, camera_yaw) * _base_speed


## [param position] moved to the nearest point inside the Flight Volume, or returned
## unchanged while no bounds have been set.
func clamp_position(position: Vector3) -> Vector3:
	if not _has_bounds:
		return position
	var maximum: Vector3 = _bounds.end
	return Vector3(
		clampf(position.x, _bounds.position.x, maximum.x),
		clampf(position.y, _bounds.position.y, maximum.y),
		clampf(position.z, _bounds.position.z, maximum.z),
	)


## How close [param position] is to the Flight Volume boundary, for edge feedback:
## 0 while farther than the configured margin from every face, rising linearly to 1 at
## the nearest face, and staying at 1 outside. Always 0 while no bounds or no margin
## have been configured.
func edge_proximity(position: Vector3) -> float:
	var value := 0.0
	if _has_bounds and _edge_margin > 0.0:
		var gaps := (position - _bounds.position).min(_bounds.end - position)
		var distance := minf(minf(gaps.x, gaps.y), gaps.z)
		value = clampf(1.0 - distance / _edge_margin, 0.0, 1.0)
	# The remembered value only moves when an event is emitted, so a drift smaller than
	# the threshold still reports once it adds up to one.
	if absf(value - _last_edge_proximity) > EDGE_PROXIMITY_EPSILON:
		_last_edge_proximity = value
		edge_proximity_changed.emit(value)
	return value


## Roll to apply to `VisualRoot`, in radians, from the part of [param velocity] that is
## lateral to the camera, clamped to ± [param max_angle]. Negative leans the ship into a
## turn to its right, which is the sign `VisualRoot.rotation.z` needs for the right wing
## to dip while the nose points at -Z. Purely visual: the damage Core, the hit volumes
## and the position are not affected, and Focus leans less because it flies slower.
func bank_angle(velocity: Vector3, camera_yaw: float, max_angle: float) -> float:
	if _base_speed <= 0.0:
		return 0.0
	var lateral := velocity.dot(Vector3.RIGHT.rotated(Vector3.UP, camera_yaw)) / _base_speed
	return -clampf(lateral, -1.0, 1.0) * max_angle
