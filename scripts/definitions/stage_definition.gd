class_name StageDefinition
extends Resource

## Ordered authored route of Encounters and Checkpoints for one Stage.

@export var id: StringName
@export var encounters: Array[EncounterDefinition] = []
@export var checkpoints: Array[CheckpointDefinition] = []

## Finds an Encounter by stable ID, or returns null when it is absent.
func find_encounter(encounter_id: StringName) -> EncounterDefinition:
	for encounter: EncounterDefinition in encounters:
		if encounter != null and encounter.id == encounter_id:
			return encounter
	return null

## Returns an Encounter's route index, or -1 when it is absent.
func encounter_index(encounter_id: StringName) -> int:
	for index: int in range(encounters.size()):
		var encounter: EncounterDefinition = encounters[index]
		if encounter != null and encounter.id == encounter_id:
			return index
	return -1

## Finds a Checkpoint by stable ID, or returns null when it is absent.
func find_checkpoint(checkpoint_id: StringName) -> CheckpointDefinition:
	for checkpoint: CheckpointDefinition in checkpoints:
		if checkpoint != null and checkpoint.id == checkpoint_id:
			return checkpoint
	return null

## Validates child Definitions and route ordering and reference integrity.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var definition_id: String = String(id)
	if id.is_empty():
		definition_id = "<empty>"
		errors.append(_error(definition_id, "stage id must not be empty"))
	if encounters.is_empty():
		errors.append(_error(definition_id, "stage must have at least one Encounter"))

	var seen_encounter_ids: Array[StringName] = []
	var seen_gate_ids: Array[StringName] = []
	for encounter_index_value: int in range(encounters.size()):
		var encounter: EncounterDefinition = encounters[encounter_index_value]
		if encounter == null:
			errors.append(_error(definition_id, "Encounter %d must not be null" % (encounter_index_value + 1)))
			continue
		for child_error: String in encounter.validate():
			errors.append(child_error)
		if not encounter.id.is_empty():
			if encounter.id in seen_encounter_ids:
				errors.append(_error(definition_id, "Encounter id %s is duplicated" % encounter.id))
			else:
				seen_encounter_ids.append(encounter.id)
		if not encounter.gate_id.is_empty():
			if encounter.gate_id in seen_gate_ids:
				errors.append(_error(definition_id, "gate id %s is duplicated" % encounter.gate_id))
			else:
				seen_gate_ids.append(encounter.gate_id)

		var expected_next_id: StringName = &""
		if encounter_index_value + 1 < encounters.size():
			var next_encounter: EncounterDefinition = encounters[encounter_index_value + 1]
			if next_encounter != null:
				expected_next_id = next_encounter.id
		if encounter.next_id != expected_next_id:
			errors.append(_error(String(encounter.id), "next id must match the following Encounter (%s)" % expected_next_id))

	var seen_checkpoint_ids: Array[StringName] = []
	for checkpoint_index_value: int in range(checkpoints.size()):
		var checkpoint: CheckpointDefinition = checkpoints[checkpoint_index_value]
		if checkpoint == null:
			errors.append(_error(definition_id, "Checkpoint %d must not be null" % (checkpoint_index_value + 1)))
			continue
		for child_error: String in checkpoint.validate():
			errors.append(child_error)
		if not checkpoint.id.is_empty():
			if checkpoint.id in seen_checkpoint_ids:
				errors.append(_error(definition_id, "Checkpoint id %s is duplicated" % checkpoint.id))
			else:
				seen_checkpoint_ids.append(checkpoint.id)

		var after_index: int = encounter_index(checkpoint.after_encounter_id)
		var resume_index: int = encounter_index(checkpoint.resume_encounter_id)
		if after_index < 0:
			errors.append(_error(String(checkpoint.id), "after Encounter %s does not exist in this Stage" % checkpoint.after_encounter_id))
		if resume_index < 0:
			errors.append(_error(String(checkpoint.id), "resume Encounter %s does not exist in this Stage" % checkpoint.resume_encounter_id))
		if after_index >= 0 and resume_index >= 0 and after_index >= resume_index:
			errors.append(_error(String(checkpoint.id), "resume Encounter must follow the after Encounter"))
		if resume_index >= 0:
			var resume_encounter: EncounterDefinition = encounters[resume_index]
			if resume_encounter.checkpoint_id != checkpoint.id:
				errors.append(_error(String(checkpoint.id), "resume Encounter %s must name this Checkpoint" % resume_encounter.id))

	for encounter: EncounterDefinition in encounters:
		if encounter != null and not encounter.checkpoint_id.is_empty() and find_checkpoint(encounter.checkpoint_id) == null:
			errors.append(_error(String(encounter.id), "checkpoint id %s does not exist in this Stage" % encounter.checkpoint_id))
	return errors

func _error(error_id: String, message: String) -> String:
	var prefix: String = error_id
	if prefix.is_empty():
		prefix = "<empty>"
	return "%s: %s" % [prefix, message]
