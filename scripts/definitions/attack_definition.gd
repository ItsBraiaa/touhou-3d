class_name AttackDefinition
extends Resource
## Authored named Attack for one Boss Phase: an ordered sequence of steps that cycles,
## with a quiet repositioning window after the last step.


## Portuguese name announced when the Phase starts, for example "Ritual das Lanternas".
@export var display_name: String = ""
## Steps played in order; after the last one and [member reposition_seconds], step 0
## plays again.
@export var steps: Array[AttackStepDefinition] = []
## Seconds of quiet after the last step before the cycle repeats.
@export var reposition_seconds: float = 1.0


## Returns one message naming [member display_name] for each invalid value, including
## every invalid step. A cycle must take some time, or the Boss would fire it endlessly
## within one tick.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if display_name.is_empty():
		errors.append(_error("display_name must not be empty"))
	if steps.is_empty():
		errors.append(_error("steps must have at least one step"))
	if reposition_seconds < 0.0:
		errors.append(_error("reposition_seconds must not be negative"))
	var cycle_seconds := maxf(0.0, reposition_seconds)
	for step_index: int in steps.size():
		var step: AttackStepDefinition = steps[step_index]
		if step == null:
			errors.append(_error("step %d must not be null" % (step_index + 1)))
			continue
		for step_error: String in step.validate():
			errors.append(_error("step %d: %s" % [step_index + 1, step_error]))
		cycle_seconds += maxf(0.0, step.get_duration())
	if not steps.is_empty() and cycle_seconds <= 0.0:
		errors.append(_error("one cycle of the steps and reposition_seconds must take time"))
	return errors


func _error(message: String) -> String:
	return "AttackDefinition '%s': %s" % [display_name, message]
