class_name PatternEmitter
extends RefCounted
## Node-free emitter that turns one PatternDefinition run into hostile ProjectileSpawn values.


const _EPSILON: float = 0.000001
const _WORLD_FORWARD: Vector3 = Vector3.FORWARD


var _definition: PatternDefinition
var _rng: RandomNumberGenerator
var _started: bool = false
var _elapsed: float = 0.0
var _next_volley: int = 0
var _sampled_aim_set: bool = false
var _sampled_aim_point: Vector3 = Vector3.ZERO


## Supplies immutable pattern data and the Attempt's random-number generator.
func setup(definition: PatternDefinition, rng: RandomNumberGenerator) -> void:
	assert(definition != null, "PatternEmitter: definition is required")
	assert(rng != null, "PatternEmitter: rng is required")
	_definition = definition
	_rng = rng
	reset()


## Starts or restarts the run; volley zero is due on its first tick.
func start() -> void:
	reset()
	_started = true


## Returns to the pre-start state and forgets elapsed time and sampled aim.
func reset() -> void:
	_started = false
	_elapsed = 0.0
	_next_volley = 0
	_sampled_aim_set = false
	_sampled_aim_point = Vector3.ZERO


## Advances elapsed time and emits every due volley in order without dropping catch-up volleys.
func tick(delta: float, origin: Vector3, forward: Vector3, aim_point: Vector3) -> Array[ProjectileSpawn]:
	assert(delta >= 0.0, "PatternEmitter: delta must not be negative")
	var spawns: Array[ProjectileSpawn] = []
	if not _started or _definition == null:
		return spawns
	_elapsed += delta
	while _next_volley < _definition.volley_count:
		var due_time: float = float(_next_volley) * _definition.volley_interval
		if due_time > _elapsed + _EPSILON:
			break
		if _definition.shape == PatternDefinition.Shape.AIMED and not _sampled_aim_set:
			_sampled_aim_point = aim_point
			_sampled_aim_set = true
		var height_offset: float = _height_offset(_next_volley)
		var volley_origin: Vector3 = origin + Vector3.UP * height_offset
		_emit_volley(spawns, _next_volley, volley_origin, forward, origin)
		_next_volley += 1
	return spawns


## Reports whether every configured volley has fired.
func is_finished() -> bool:
	return _started and _definition != null and _next_volley >= _definition.volley_count


func _height_offset(volley_index: int) -> float:
	if _definition.height_offsets.is_empty():
		return 0.0
	return _definition.height_offsets[volley_index % _definition.height_offsets.size()]


func _emit_volley(
		spawns: Array[ProjectileSpawn], volley_index: int, volley_origin: Vector3,
		forward: Vector3, base_origin: Vector3) -> void:
	var rotation_degrees: float = float(volley_index) * _definition.rotation_step_degrees
	match _definition.shape:
		PatternDefinition.Shape.RING, PatternDefinition.Shape.SPIRAL:
			_emit_ring(spawns, volley_origin, forward, rotation_degrees)
		PatternDefinition.Shape.FAN:
			_emit_fan(spawns, volley_origin, forward, rotation_degrees)
		PatternDefinition.Shape.BURST:
			_emit_burst(spawns, volley_origin, forward, rotation_degrees)
		PatternDefinition.Shape.AIMED:
			var aim_direction: Vector3 = _sampled_aim_point - base_origin
			_emit_fan(spawns, volley_origin, aim_direction, rotation_degrees)


func _emit_ring(
		spawns: Array[ProjectileSpawn], volley_origin: Vector3,
		forward: Vector3, rotation_degrees: float) -> void:
	var base_direction: Vector3 = _horizontal_forward(forward).rotated(Vector3.UP, deg_to_rad(rotation_degrees))
	var count: int = _definition.projectiles_per_volley
	for projectile_index: int in range(count):
		var angle_degrees: float = 360.0 * float(projectile_index) / float(count)
		var distance_from_gap_center: float = minf(angle_degrees, 360.0 - angle_degrees)
		if (
			_definition.shape == PatternDefinition.Shape.RING
			and _definition.gap_degrees > 0.0
			and distance_from_gap_center <= _definition.gap_degrees * 0.5 + _EPSILON
		):
			continue
		var direction: Vector3 = base_direction.rotated(Vector3.UP, deg_to_rad(angle_degrees))
		direction = _apply_pitch(direction, _definition.pitch_degrees)
		_append_spawn(spawns, volley_origin, direction, 1.0)


func _emit_fan(
		spawns: Array[ProjectileSpawn], volley_origin: Vector3,
		forward: Vector3, rotation_degrees: float) -> void:
	var horizontal_forward: Vector3 = _horizontal_forward(forward)
	var center_direction: Vector3 = _forward_with_pitch(forward)
	center_direction = center_direction.rotated(Vector3.UP, deg_to_rad(rotation_degrees))
	var right: Vector3 = horizontal_forward.cross(Vector3.UP).normalized()
	right = right.rotated(Vector3.UP, deg_to_rad(rotation_degrees))
	var count: int = _definition.projectiles_per_volley
	for projectile_index: int in range(count):
		var angle_degrees: float = 0.0
		if count > 1:
			var fraction: float = float(projectile_index) / float(count - 1)
			angle_degrees = lerpf(-_definition.spread_degrees * 0.5, _definition.spread_degrees * 0.5, fraction)
		var direction: Vector3 = (
			center_direction * cos(deg_to_rad(angle_degrees))
			+ right * sin(deg_to_rad(angle_degrees))
		).normalized()
		direction = _apply_pitch(direction, _definition.pitch_degrees)
		_append_spawn(spawns, volley_origin, direction, 1.0)


func _emit_burst(
		spawns: Array[ProjectileSpawn], volley_origin: Vector3,
		forward: Vector3, rotation_degrees: float) -> void:
	var axis: Vector3 = _forward_with_pitch(forward)
	axis = axis.rotated(Vector3.UP, deg_to_rad(rotation_degrees))
	axis = _apply_pitch(axis, _definition.pitch_degrees)
	var right: Vector3 = axis.cross(Vector3.UP)
	if right.length_squared() <= _EPSILON:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var up: Vector3 = right.cross(axis).normalized()
	var half_spread_radians: float = deg_to_rad(_definition.spread_degrees * 0.5)
	var minimum_cosine: float = cos(half_spread_radians)
	for _projectile_index: int in range(_definition.projectiles_per_volley):
		var cosine: float = _rng.randf_range(minimum_cosine, 1.0)
		var sine: float = sqrt(maxf(0.0, 1.0 - cosine * cosine))
		var azimuth: float = _rng.randf_range(0.0, TAU)
		var direction: Vector3 = (
			axis * cosine
			+ right * (cos(azimuth) * sine)
			+ up * (sin(azimuth) * sine)
		).normalized()
		var speed_factor: float = _rng.randf_range(
			1.0 - _definition.speed_variance, 1.0 + _definition.speed_variance
		)
		_append_spawn(spawns, volley_origin, direction, speed_factor)


func _append_spawn(
		spawns: Array[ProjectileSpawn], volley_origin: Vector3,
		direction: Vector3, speed_factor: float) -> void:
	var velocity: Vector3 = direction * _definition.speed * speed_factor
	var spawn: ProjectileSpawn = ProjectileSpawn.new(
		volley_origin,
		velocity,
		ProjectileSpawn.Faction.HOSTILE,
		_definition.lifetime,
		_definition.projectile_radius,
		_definition.damage
	)
	spawns.append(spawn)


func _forward_with_pitch(forward: Vector3) -> Vector3:
	if forward.length_squared() <= _EPSILON:
		return _WORLD_FORWARD
	var horizontal: Vector3 = Vector3(forward.x, 0.0, forward.z)
	if horizontal.length_squared() <= _EPSILON:
		return _WORLD_FORWARD
	return forward.normalized()


func _horizontal_forward(forward: Vector3) -> Vector3:
	var horizontal: Vector3 = Vector3(forward.x, 0.0, forward.z)
	if horizontal.length_squared() <= _EPSILON:
		return _WORLD_FORWARD
	return horizontal.normalized()


func _apply_pitch(direction: Vector3, pitch_degrees: float) -> Vector3:
	var right: Vector3 = direction.cross(Vector3.UP)
	if right.length_squared() <= _EPSILON:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	return direction.rotated(right, deg_to_rad(pitch_degrees)).normalized()
