class_name EnemyDefinition
extends Resource
## Authored health, attack and movement values for a common Enemy.


## The Enemy's movement style.
enum Movement { DRIFT, HOVER }


## Enemy kind identifier, such as Spirit or Sentry.
@export var kind: StringName = &""
## Health points before defeat.
@export var health: int = 100
## Score awarded by the owning Director on defeat.
@export var score: int = 100
## Visible cue duration before each attack.
@export var anticipation_seconds: float = 1.0
## Reusable projectile pattern fired by this Enemy.
@export var pattern: PatternDefinition
## Seconds after a pattern finishes before the next Anticipation begins.
@export var attack_interval: float = 1.0
## Movement style used around the spawn anchor.
@export var movement: Movement = Movement.DRIFT
## Movement speed in world units per second.
@export var move_speed: float = 1.0
## Maximum displacement from the spawn anchor in world units.
@export var move_range: float = 2.0


## Returns one message naming [member kind] for each invalid value.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if kind == &"":
		errors.append(_error("kind must not be empty"))
	if health <= 0:
		errors.append(_error("health must be above 0"))
	if score < 0:
		errors.append(_error("score must not be negative"))
	if anticipation_seconds < 0.0:
		errors.append(_error("anticipation_seconds must not be negative"))
	if pattern == null:
		errors.append(_error("pattern is required"))
	else:
		var pattern_errors: PackedStringArray = pattern.validate()
		for pattern_error: String in pattern_errors:
			errors.append(_error("pattern: %s" % pattern_error))
	if attack_interval <= 0.0:
		errors.append(_error("attack_interval must be above 0"))
	if move_speed < 0.0:
		errors.append(_error("move_speed must not be negative"))
	if move_range < 0.0:
		errors.append(_error("move_range must not be negative"))
	return errors


func _error(message: String) -> String:
	return "EnemyDefinition '%s': %s" % [kind, message]
