class_name CheckpointDefinition
extends Resource

## Authored location and resume contract for one Stage checkpoint.

@export var id: StringName
@export var after_encounter_id: StringName
@export var resume_encounter_id: StringName
@export var node_path: NodePath
@export var display_name: String = ""

## Returns all missing identity, route, marker, and display fields.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var definition_id: String = String(id)
	if id.is_empty():
		definition_id = "<empty>"
		errors.append(_error(definition_id, "checkpoint id must not be empty"))
	if after_encounter_id.is_empty():
		errors.append(_error(definition_id, "after encounter id must not be empty"))
	if resume_encounter_id.is_empty():
		errors.append(_error(definition_id, "resume encounter id must not be empty"))
	if node_path.is_empty():
		errors.append(_error(definition_id, "checkpoint node path must not be empty"))
	if display_name.strip_edges().is_empty():
		errors.append(_error(definition_id, "checkpoint display name must not be empty"))
	return errors

func _error(definition_id: String, message: String) -> String:
	return "%s: %s" % [definition_id, message]
