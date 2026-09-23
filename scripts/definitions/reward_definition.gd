class_name RewardDefinition
extends Resource

## A one-time pickup bundle granted when its Encounter completes.

enum Kind {
	POWER,
	SHIELD,
}

@export var kind: Kind = Kind.POWER
@export var count: int = 1
@export var origin_marker: NodePath

## Returns validation errors; the owning Encounter prefixes them with its ID.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if count < 1:
		errors.append("reward count must be at least one")
	if origin_marker.is_empty():
		errors.append("reward origin marker must not be empty")
	return errors
