class_name AttackStepDefinition
extends Resource
## Authored values for one step of a Boss Attack: a Pattern fired after its own
## Anticipation, at a height relative to the Boss or at the player's sampled altitude.


## Pattern fired once the Anticipation ends.
@export var pattern: PatternDefinition
## Seconds of visible charge before this step fires; the aim is sampled when it ends.
@export var anticipation_seconds: float = 1.0
## Emission height in world units relative to the Boss origin. Ignored when
## [member follow_player_height] is set.
@export var height_offset: float = 0.0
## Emit at the player's altitude sampled when the Anticipation ends, as in Fios de Luz's
## paired fans and the Tempest Sentinel's altitude tracking.
@export var follow_player_height: bool = false
## Seconds of quiet after the Pattern finishes, before the next step's Anticipation.
@export var pause_after: float = 0.0


## Returns one message for each invalid value; the owning [AttackDefinition] adds which
## step it is.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if pattern == null:
		errors.append("pattern is required")
	else:
		for pattern_error: String in pattern.validate():
			errors.append("pattern: %s" % pattern_error)
	if anticipation_seconds < 0.0:
		errors.append("anticipation_seconds must not be negative")
	if pause_after < 0.0:
		errors.append("pause_after must not be negative")
	return errors


## Seconds this step takes when played once: its Anticipation, the span of its volleys
## and its pause. 0 when the Pattern is missing.
func get_duration() -> float:
	if pattern == null:
		return 0.0
	var firing := float(pattern.volley_count - 1) * pattern.volley_interval
	return anticipation_seconds + firing + pause_after
