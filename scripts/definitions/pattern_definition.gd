class_name PatternDefinition
extends Resource
## Authored values for a reusable hostile projectile pattern.


## The geometry used for each volley.
enum Shape { RING, FAN, SPIRAL, BURST, AIMED }


## Stable authored identifier used in validation messages and content.
@export var id: StringName
## Shape emitted by this definition.
@export var shape: Shape = Shape.RING
## Number of projectiles emitted by each volley.
@export var projectiles_per_volley: int = 12
## Number of volleys emitted by one run.
@export var volley_count: int = 1
## Seconds between successive volleys.
@export var volley_interval: float = 0.2
## Projectile speed in world units per second.
@export var speed: float = 8.0
## Projectile lifetime in seconds.
@export var lifetime: float = 6.0
## Projectile collision radius in world units.
@export var projectile_radius: float = 0.25
## Damage carried by every projectile.
@export var damage: int = 10
## Fan and aimed arc width, or the full burst cone width, in degrees.
@export var spread_degrees: float = 60.0
## Empty arc centered on the base direction for a ring, in degrees.
@export var gap_degrees: float = 0.0
## World-up rotation added for every volley after the first, in degrees.
@export var rotation_step_degrees: float = 0.0
## Additional elevation applied to every emitted direction, in degrees.
@export var pitch_degrees: float = 0.0
## World-up emission offsets cycled once per volley; empty means zero.
@export var height_offsets: PackedFloat32Array = PackedFloat32Array()
## Random speed variation as a fraction, used by BURST only.
@export var speed_variance: float = 0.0


## Returns one validation message for each invalid field or shape-specific combination.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if projectiles_per_volley < 1:
		errors.append(_error("projectiles_per_volley must be at least 1"))
	if volley_count < 1:
		errors.append(_error("volley_count must be at least 1"))
	if volley_interval < 0.0:
		errors.append(_error("volley_interval must not be negative"))
	if volley_count > 1 and volley_interval <= 0.0:
		errors.append(_error("volley_interval must be above 0 when volley_count is above 1"))
	if speed <= 0.0:
		errors.append(_error("speed must be above 0"))
	if lifetime <= 0.0:
		errors.append(_error("lifetime must be above 0"))
	if projectile_radius <= 0.0:
		errors.append(_error("projectile_radius must be above 0"))
	if damage < 1:
		errors.append(_error("damage must be at least 1"))
	if spread_degrees < 0.0 or spread_degrees > 360.0:
		errors.append(_error("spread_degrees must be in 0..360"))
	elif shape == Shape.BURST and spread_degrees <= 0.0:
		errors.append(_error("BURST spread_degrees must be above 0"))
	if gap_degrees < 0.0 or gap_degrees > 360.0:
		errors.append(_error("gap_degrees must be in 0..360"))
	elif shape == Shape.RING and _ring_count_outside_gap() < 1:
		errors.append(_error("RING gap_degrees must leave at least one projectile"))
	if speed_variance < 0.0 or speed_variance > 1.0:
		errors.append(_error("speed_variance must be in 0..1"))
	if shape == Shape.SPIRAL and rotation_step_degrees == 0.0:
		errors.append(_error("SPIRAL rotation_step_degrees must not be 0"))
	return errors


func _ring_count_outside_gap() -> int:
	if projectiles_per_volley < 1:
		return 0
	var remaining: int = 0
	for projectile_index: int in range(projectiles_per_volley):
		var angle_degrees: float = 360.0 * float(projectile_index) / float(projectiles_per_volley)
		var distance_from_center: float = minf(angle_degrees, 360.0 - angle_degrees)
		if gap_degrees > 0.0 and distance_from_center <= gap_degrees * 0.5 + 0.000001:
			continue
		remaining += 1
	return remaining


func _error(message: String) -> String:
	return "PatternDefinition '%s': %s" % [id, message]
