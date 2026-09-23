class_name WeaponModel
extends RefCounted
## Node-free cadence and Aim Assist rules for the player's main shot and Familiars.


## Which independently cooled firing source produced a Shot.
enum Source { MAIN, FAMILIAR_LEFT, FAMILIAR_RIGHT }


## One shot opportunity emitted by [method tick].
class Shot:
	extends RefCounted

	## Firing source, one of [enum WeaponModel.Source].
	var source: int = WeaponModel.Source.MAIN
	## Aim Assist cone to apply to this shot, in degrees.
	var assist_degrees: float = 0.0


## Proposed per-source cadences and Aim Assist cones, ready for design tuning.
class Tuning:
	extends RefCounted

	## Main-shot interval in seconds.
	var main_interval: float = 0.1
	## Familiar interval at Power Level 2, in seconds.
	var familiar_interval_level_2: float = 0.25
	## Familiar interval at Power Level 3, in seconds.
	var familiar_interval_level_3: float = 0.15
	## Main-shot Aim Assist cone at all Power Levels, in degrees.
	var main_assist_degrees: float = 10.0
	## Familiar Aim Assist cone at Power Level 2, in degrees.
	var familiar_assist_degrees_level_2: float = 10.0
	## Familiar Aim Assist cone at Power Level 3, in degrees.
	var familiar_assist_degrees_level_3: float = 20.0


const _EPSILON_SQUARED: float = 0.000001


var _main_interval: float = 0.1
var _familiar_interval_level_2: float = 0.25
var _familiar_interval_level_3: float = 0.15
var _main_assist_degrees: float = 10.0
var _familiar_assist_degrees_level_2: float = 10.0
var _familiar_assist_degrees_level_3: float = 20.0
var _main_cooldown: float = 0.0
var _familiar_left_cooldown: float = 0.0
var _familiar_right_cooldown: float = 0.0


## Copies one tuning set. Fire intervals must be positive to keep cadence bounded.
func configure(tuning: Tuning) -> void:
	assert(tuning != null, "WeaponModel: tuning is required")
	assert(tuning.main_interval > 0.0, "WeaponModel: main_interval must be positive")
	assert(tuning.familiar_interval_level_2 > 0.0, "WeaponModel: level-2 familiar interval must be positive")
	assert(tuning.familiar_interval_level_3 > 0.0, "WeaponModel: level-3 familiar interval must be positive")
	_main_interval = tuning.main_interval
	_familiar_interval_level_2 = tuning.familiar_interval_level_2
	_familiar_interval_level_3 = tuning.familiar_interval_level_3
	_main_assist_degrees = tuning.main_assist_degrees
	_familiar_assist_degrees_level_2 = tuning.familiar_assist_degrees_level_2
	_familiar_assist_degrees_level_3 = tuning.familiar_assist_degrees_level_3


## Advances every source cooldown and emits all shots due while fire is held.
func tick(delta: float, fire_held: bool, power_level: int) -> Array[Shot]:
	assert(delta >= 0.0, "WeaponModel: delta must not be negative")
	assert(power_level >= 1 and power_level <= 3, "WeaponModel: power_level must be in 1..3")
	var shots: Array[Shot] = []
	_main_cooldown = _tick_source(
		delta, fire_held, true, Source.MAIN, _main_cooldown,
		_main_interval, _main_assist_degrees, shots
	)
	var familiar_interval: float = _familiar_interval_level_2
	var familiar_assist: float = _familiar_assist_degrees_level_2
	if power_level == 3:
		familiar_interval = _familiar_interval_level_3
		familiar_assist = _familiar_assist_degrees_level_3
	var familiars_active: bool = familiar_count(power_level) > 0
	_familiar_left_cooldown = _tick_source(
		delta, fire_held, familiars_active, Source.FAMILIAR_LEFT, _familiar_left_cooldown,
		familiar_interval, familiar_assist, shots
	)
	_familiar_right_cooldown = _tick_source(
		delta, fire_held, familiars_active, Source.FAMILIAR_RIGHT, _familiar_right_cooldown,
		familiar_interval, familiar_assist, shots
	)
	return shots


## Returns the number of active Familiars for [param power_level].
func familiar_count(power_level: int) -> int:
	assert(power_level >= 1 and power_level <= 3, "WeaponModel: power_level must be in 1..3")
	return 0 if power_level == 1 else 2


## Returns the normalized target direction when it lies in the cone; otherwise returns normalized forward.
static func assist_direction(
		origin: Vector3, forward: Vector3, target_point: Vector3, max_degrees: float) -> Vector3:
	var forward_direction: Vector3 = _normalized_or_forward(forward)
	var target_offset: Vector3 = target_point - origin
	if target_offset.length_squared() <= _EPSILON_SQUARED:
		return forward_direction
	var target_direction: Vector3 = target_offset.normalized()
	var dot_product: float = clampf(forward_direction.dot(target_direction), -1.0, 1.0)
	var angle_degrees: float = rad_to_deg(acos(dot_product))
	if angle_degrees <= max_degrees:
		return target_direction
	return forward_direction


## Resets every source so the next held-fire tick can fire immediately.
func reset() -> void:
	_main_cooldown = 0.0
	_familiar_left_cooldown = 0.0
	_familiar_right_cooldown = 0.0


func _tick_source(
		delta: float, fire_held: bool, source_active: bool, source: int,
		cooldown: float, interval: float, assist_degrees: float, shots: Array[Shot]) -> float:
	var next_cooldown: float = cooldown - delta
	if not fire_held or not source_active:
		return maxf(0.0, next_cooldown)
	while next_cooldown <= 0.0:
		var shot: Shot = Shot.new()
		shot.source = source
		shot.assist_degrees = assist_degrees
		shots.append(shot)
		next_cooldown += interval
	return next_cooldown


static func _normalized_or_forward(direction: Vector3) -> Vector3:
	if direction.length_squared() <= _EPSILON_SQUARED:
		return Vector3.FORWARD
	return direction.normalized()
