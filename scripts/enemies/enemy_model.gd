class_name EnemyModel
extends RefCounted
## Node-free rules core for a common Enemy's health, movement and attack cadence.


## The visible cue for the next attack began.
signal anticipation_started
## The Enemy was snapped back to its spawn anchor clamped into its bounds.
signal repositioned(position: Vector3)
## The Enemy was defeated. The ids identify its authored encounter instance.
signal defeated(enemy_id: StringName, encounter_id: StringName)


enum _Phase { ANTICIPATION, FIRING, COOLDOWN, DEFEATED }


var _definition: EnemyDefinition
var _enemy_id: StringName = &""
var _encounter_id: StringName = &""
var _emitter: PatternEmitter
var _bounds: AABB
var _anchor: Vector3 = Vector3.ZERO
var _position: Vector3 = Vector3.ZERO
var _health: int = 0
var _movement_phase: float = 0.0
var _phase: int = _Phase.ANTICIPATION
var _phase_elapsed: float = 0.0
var _fire_elapsed: float = 0.0
var _fire_duration: float = 0.0
var _sampled_aim_point: Vector3 = Vector3.ZERO
var _anticipation_announced: bool = false
var _is_setup: bool = false


## Validates and injects the definition, ids, Attempt RNG, spawn anchor and movement bounds.
func setup(
		definition: EnemyDefinition, enemy_id: StringName, encounter_id: StringName,
		rng: RandomNumberGenerator, spawn_position: Vector3, bounds: AABB) -> void:
	assert(definition != null, "EnemyModel: definition is required")
	assert(rng != null, "EnemyModel: rng is required")
	var errors: PackedStringArray = definition.validate()
	assert(errors.is_empty(), "EnemyModel: invalid definition: %s" % ", ".join(errors))
	_definition = definition
	_enemy_id = enemy_id
	_encounter_id = encounter_id
	_bounds = bounds
	_anchor = _clamp_to_bounds(spawn_position, _bounds)
	_position = _anchor
	_health = definition.health
	_movement_phase = rng.randf_range(0.0, TAU)
	_phase = _Phase.ANTICIPATION
	_phase_elapsed = 0.0
	_fire_elapsed = 0.0
	_fire_duration = float(definition.pattern.volley_count - 1) * definition.pattern.volley_interval
	_sampled_aim_point = Vector3.ZERO
	_anticipation_announced = false
	_emitter = PatternEmitter.new()
	_emitter.setup(definition.pattern, rng)
	_is_setup = true


## Advances bounded movement and the Anticipation / Firing / Cooldown cycle.
func tick(
		delta: float, player_position: Vector3,
		emitter_offset: Vector3 = Vector3.ZERO) -> Array[ProjectileSpawn]:
	assert(_is_setup, "EnemyModel: setup must be called before tick")
	assert(delta >= 0.0, "EnemyModel: delta must not be negative")
	var spawns: Array[ProjectileSpawn] = []
	if _phase == _Phase.DEFEATED:
		return spawns
	_reposition_if_outside_bounds()
	_advance_movement(delta)
	if not _anticipation_announced:
		anticipation_started.emit()
		_anticipation_announced = true
	var remaining_time: float = delta
	while true:
		match _phase:
			_Phase.ANTICIPATION:
				var anticipation_left: float = maxf(0.0, _definition.anticipation_seconds - _phase_elapsed)
				if anticipation_left > remaining_time:
					_phase_elapsed += remaining_time
					break
				remaining_time -= anticipation_left
				_phase_elapsed = 0.0
				_begin_firing(player_position)
			_Phase.FIRING:
				var fire_time_left: float = maxf(0.0, _fire_duration - _fire_elapsed)
				var emitter_delta: float = minf(remaining_time, fire_time_left)
				var emission_origin: Vector3 = _position + emitter_offset
				var forward: Vector3 = _sampled_aim_point - emission_origin
				var volley_spawns: Array[ProjectileSpawn] = _emitter.tick(
					emitter_delta, emission_origin, forward, _sampled_aim_point
				)
				spawns.append_array(volley_spawns)
				_fire_elapsed += emitter_delta
				remaining_time -= emitter_delta
				if _emitter.is_finished():
					_phase = _Phase.COOLDOWN
					_phase_elapsed = 0.0
				else:
					break
			_Phase.COOLDOWN:
				var cooldown_left: float = maxf(0.0, _definition.attack_interval - _phase_elapsed)
				if cooldown_left > remaining_time:
					_phase_elapsed += remaining_time
					break
				remaining_time -= cooldown_left
				_phase = _Phase.ANTICIPATION
				_phase_elapsed = 0.0
				anticipation_started.emit()
			_Phase.DEFEATED:
				break
	return spawns


## Replaces the movement bounds and repositions immediately if the current point is outside.
func set_bounds(bounds: AABB) -> void:
	assert(_is_setup, "EnemyModel: setup must be called before set_bounds")
	_bounds = bounds
	_anchor = _clamp_to_bounds(_anchor, _bounds)
	_reposition_if_outside_bounds()


## Applies positive damage; defeat and its signal occur only once.
func take_damage(amount: int) -> void:
	assert(_is_setup, "EnemyModel: setup must be called before take_damage")
	assert(amount > 0, "EnemyModel: damage amount must be positive")
	if _phase == _Phase.DEFEATED:
		return
	_health = maxi(0, _health - amount)
	if _health == 0:
		_phase = _Phase.DEFEATED
		_emitter.reset()
		defeated.emit(_enemy_id, _encounter_id)


## Returns the current world position.
func get_position() -> Vector3:
	return _position


## Returns remaining health points.
func get_health() -> int:
	return _health


## Reports whether this Enemy has been defeated.
func is_defeated() -> bool:
	return _phase == _Phase.DEFEATED


## Reports whether the Enemy is currently in Anticipation.
func is_anticipating() -> bool:
	return _phase == _Phase.ANTICIPATION


## Returns the stable id supplied to [method setup].
func get_enemy_id() -> StringName:
	return _enemy_id


## Returns the encounter id supplied to [method setup].
func get_encounter_id() -> StringName:
	return _encounter_id


## Returns the configured score reward; the Director owns awarding it.
func get_score() -> int:
	return _definition.score


func _begin_firing(player_position: Vector3) -> void:
	_sampled_aim_point = player_position
	_fire_elapsed = 0.0
	_emitter.start()
	_phase = _Phase.FIRING


func _advance_movement(delta: float) -> void:
	if _definition.move_range <= 0.0 or _definition.move_speed <= 0.0:
		_position = _anchor
		return
	_movement_phase += delta * _definition.move_speed / _definition.move_range
	var candidate: Vector3 = _anchor
	if _definition.movement == EnemyDefinition.Movement.DRIFT:
		var amplitude: float = _definition.move_range * sqrt(0.5)
		candidate += Vector3(
			sin(_movement_phase) * amplitude,
			0.0,
			sin(_movement_phase * 2.0) * amplitude
		)
	else:
		candidate.y += sin(_movement_phase) * _definition.move_range
	_position = _clamp_to_bounds(candidate, _bounds)


func _reposition_if_outside_bounds() -> void:
	if _is_inside_bounds(_position, _bounds):
		return
	_anchor = _clamp_to_bounds(_anchor, _bounds)
	_position = _anchor
	repositioned.emit(_position)


func _is_inside_bounds(position: Vector3, bounds: AABB) -> bool:
	var bounds_end: Vector3 = bounds.position + bounds.size
	return (
		position.x >= bounds.position.x and position.x <= bounds_end.x
		and position.y >= bounds.position.y and position.y <= bounds_end.y
		and position.z >= bounds.position.z and position.z <= bounds_end.z
	)


func _clamp_to_bounds(position: Vector3, bounds: AABB) -> Vector3:
	return position.clamp(bounds.position, bounds.position + bounds.size)
