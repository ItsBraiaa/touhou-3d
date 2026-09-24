class_name WaveDefinition
extends Resource

## The spawn configuration and activation rule for one Encounter wave.

enum Activation {
	ON_ENTRY,
	AFTER_PREVIOUS_WAVE,
}

@export var spawn_markers: Array[NodePath] = []
@export var enemy_kinds: Array[StringName] = []
@export var activation: Activation = Activation.ON_ENTRY
@export var delay: float = 0.0

## Returns the enemy kind assigned to a marker, or an empty name if out of range.
func enemy_kind_at(index: int) -> StringName:
	if index < 0 or index >= enemy_kinds.size():
		return &""
	return enemy_kinds[index]

## Returns validation errors; the owning Encounter prefixes them with its ID.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if spawn_markers.is_empty():
		errors.append("wave must have at least one spawn marker")
	if spawn_markers.size() != enemy_kinds.size():
		errors.append("wave marker and enemy kind counts must match")
	if delay < 0.0:
		errors.append("wave delay must be non-negative")

	var seen_markers: Array[NodePath] = []
	for marker: NodePath in spawn_markers:
		if marker.is_empty():
			errors.append("wave spawn marker must not be empty")
		elif marker in seen_markers:
			errors.append("wave spawn markers must not repeat")
		else:
			seen_markers.append(marker)

	for kind: StringName in enemy_kinds:
		if kind.is_empty():
			errors.append("wave enemy kind must not be empty")
	return errors
