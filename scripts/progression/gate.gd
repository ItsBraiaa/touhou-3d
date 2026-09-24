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
var _open_visual: Node3D
var _closed_geometry: GeometryInstance3D
var _fade_tween: Tween


func _ready() -> void:
	_collision = get_node_or_null(COLLISION_PATH) as CollisionShape3D
	_closed_visual = get_node_or_null(CLOSED_VISUAL_PATH) as Node3D
	_open_visual = get_node_or_null(^"OpenVisual") as Node3D
	_closed_geometry = _closed_visual as GeometryInstance3D
	if _open_visual != null:
		_open_visual.visible = _open
	if _closed_geometry != null:
		_closed_geometry.transparency = 0.0
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
	_fade_closed_visual(open)
	if _open_visual != null:
		_open_visual.visible = open


## Restores a Gate from progression instantly; safe to call repeatedly.
func restore_open(open: bool) -> void:
	_open = open
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	if _collision != null:
		_collision.disabled = open
	if _closed_visual != null:
		_closed_visual.visible = not open
	if _closed_geometry != null:
		_closed_geometry.transparency = 1.0 if open else 0.0
	if _open_visual != null:
		_open_visual.visible = open


func _fade_closed_visual(open: bool) -> void:
	if _closed_visual == null:
		return
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	if _closed_geometry == null:
		_closed_visual.visible = not open
		return
	_closed_visual.visible = true
	_closed_geometry.transparency = 0.0
	if open:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_closed_geometry, ^"transparency", 1.0, 0.35)
		_fade_tween.tween_callback(_closed_visual.hide)
	else:
		_closed_geometry.transparency = 0.0


## Whether the Gate is open.
func is_open() -> bool:
	return _open
