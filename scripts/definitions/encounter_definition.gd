class_name EncounterDefinition
extends Resource

## Plain authored data describing one route unit and its completion rules.

enum Completion {
	TRAVERSAL,
	ALL_REQUIRED_ENEMIES,
	OBJECTIVES,
}

@export var id: StringName
@export var next_id: StringName
@export var completion: Completion = Completion.TRAVERSAL
@export var requires_exit: bool = false
@export var waves: Array[WaveDefinition] = []
@export var rewards: Array[RewardDefinition] = []
@export var gate_id: StringName
@export var checkpoint_id: StringName
@export var required_objective_ids: Array[StringName] = []

## Returns errors for this Encounter and all its authored child Definitions.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var definition_id: String = String(id)
	if id.is_empty():
		definition_id = "<empty>"
		errors.append(_error(definition_id, "encounter id must not be empty"))

	match completion:
		Completion.TRAVERSAL:
			if not waves.is_empty():
				errors.append(_error(definition_id, "traversal Encounter must not have waves"))
			if not required_objective_ids.is_empty():
				errors.append(_error(definition_id, "traversal Encounter must not have objectives"))
		Completion.ALL_REQUIRED_ENEMIES:
			if waves.is_empty():
				errors.append(_error(definition_id, "enemy-completion Encounter must have at least one wave"))
		Completion.OBJECTIVES:
			if required_objective_ids.is_empty():
				errors.append(_error(definition_id, "objective-completion Encounter must have objective ids"))

	if not waves.is_empty() and waves[0].activation != WaveDefinition.Activation.ON_ENTRY:
		errors.append(_error(definition_id, "first wave must activate on Encounter entry"))

	var seen_markers: Array[NodePath] = []
	for wave_index: int in range(waves.size()):
		var wave: WaveDefinition = waves[wave_index]
		if wave == null:
			errors.append(_error(definition_id, "wave %d must not be null" % (wave_index + 1)))
			continue
		for child_error: String in wave.validate():
			errors.append(_error(definition_id, "wave %d: %s" % [wave_index + 1, child_error]))
		for marker: NodePath in wave.spawn_markers:
			if marker in seen_markers:
				errors.append(_error(definition_id, "spawn marker %s is repeated across waves" % marker))
			else:
				seen_markers.append(marker)

	for reward_index: int in range(rewards.size()):
		var reward: RewardDefinition = rewards[reward_index]
		if reward == null:
			errors.append(_error(definition_id, "reward %d must not be null" % (reward_index + 1)))
			continue
		for child_error: String in reward.validate():
			errors.append(_error(definition_id, "reward %d: %s" % [reward_index + 1, child_error]))
	return errors

func _error(definition_id: String, message: String) -> String:
	return "%s: %s" % [definition_id, message]
