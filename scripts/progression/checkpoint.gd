class_name Checkpoint
extends Area3D
## Adapter on a Checkpoint root (`Checkpoints/<id>`): reports the ship entering its
## activation volume, and gives the `Respawn` marker's transform for Retry. It holds no
## rule: the [StageDirector] decides whether an entry activates it, and refills, commits
## and records through its [CheckpointStore] (STAGE_DESIGN "Checkpoint contract"). It stays
## silent until armed, as authored with `monitoring` off.


## The ship's body entered the volume while armed. Emitted for a [PlayerController] body
## only, on every entry: the Director ignores a revisit.
signal entered(checkpoint_id: StringName)

const RESPAWN_PATH := ^"Respawn"

## This Checkpoint's id, as in its `CheckpointDefinition` (`&"CP1-A"`). Required.
@export var checkpoint_id: StringName = &""

var _respawn: Node3D


func _ready() -> void:
	_respawn = get_node_or_null(RESPAWN_PATH) as Node3D
	if checkpoint_id.is_empty() or _respawn == null:
		push_error("%s: a Checkpoint needs a 'checkpoint_id' and a Node3D at '%s'" % [get_path(), RESPAWN_PATH])
	body_entered.connect(_on_body_entered)


## Starts or stops reporting entries. Deferred, so it may be called from any callback.
func set_armed(armed: bool) -> void:
	set_deferred(&"monitoring", armed)


## The global transform of `Respawn`, where Retry puts the ship (facing -Z on Stage 1).
func get_respawn_transform() -> Transform3D:
	return _respawn.global_transform if _respawn != null else global_transform


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		entered.emit(checkpoint_id)
