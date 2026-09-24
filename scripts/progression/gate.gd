class_name Gate
extends Node3D
## Adapter on a Gate root (`Gates/Gate_<encounter>`): closed, its `BarrierBody` blocks the
## ship and Projectiles across the whole route cross-section and `ClosedVisual` glows;
## open, the barrier's collision is off and `ClosedVisual` hidden. `Arch` is scenery and
## never changes. Gates start closed, as authored. It holds no rule: the [StageDirector]
## opens it when the machine reports its Encounter complete, and sets every Gate from
## the machine's state when progress is restored (`docs/STAGE_01_HANDOFF.md` "Gates and
## portal presentation").


const COLLISION_PATH := ^"BarrierBody/Collision"
const CLOSED_VISUAL_PATH := ^"ClosedVisual"

var _open: bool = false
var _collision: CollisionShape3D
var _closed_visual: Node3D


func _ready() -> void:
	_collision = get_node_or_null(COLLISION_PATH) as CollisionShape3D
	_closed_visual = get_node_or_null(CLOSED_VISUAL_PATH) as Node3D
	if _collision == null or _closed_visual == null:
		push_error("%s: a Gate needs a CollisionShape3D at '%s' and a Node3D at '%s'" % [get_path(), COLLISION_PATH, CLOSED_VISUAL_PATH])


## Opens or closes the Gate; nothing happens when it is already in that state, so
## reapplying progress is safe. The collision change is deferred, so it may be called
## from any callback, including a physics one; it takes effect by the next physics step.
func set_open(open: bool) -> void:
	if open == _open or _collision == null or _closed_visual == null:
		return
	_open = open
	_collision.set_deferred(&"disabled", open)
	_closed_visual.visible = not open


## Whether the Gate is open.
func is_open() -> bool:
	return _open
