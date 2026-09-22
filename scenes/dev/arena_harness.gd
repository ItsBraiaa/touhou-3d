extends Node3D
## Dev harness for Feature F1: the scene to run (F6) while flying the combat arena.
##
## It stands in for the owner `GameSession` becomes in F2-04: it reads the authored
## `FlightBounds` metadata, hands the Flight Volume to [PlayerController] through
## [method PlayerController.setup], and shows the live position, speed, Focus state,
## edge-proximity value and camera framing so a manual flight check has numbers to read.
## Since F1-03 it also drives [CameraRig] with the `lock_target` and `next_target`
## actions, cycling the arena's three `targetable` markers — a stand-in for the real
## target selection, which is F1-04's and lives in `scripts/player/targeting.gd`.
## Dev only: it is never loaded by `scenes/main.tscn` and holds no gameplay rule.


## Metadata keys Astra authors on `FlightBounds` (GUIDE Section 13).
const MIN_CORNER_META := &"min_corner"
const MAX_CORNER_META := &"max_corner"
## Group the arena's static targets are in (GUIDE Section 13).
const TARGETABLE_GROUP := &"targetable"

## The instanced `combat_arena.tscn`, holding `PlayerShip`, `FlightBounds` and `Targets`.
@export var arena: Node3D
## Label the live flight values are written to.
@export var readout: Label

var _player: PlayerController
var _rig: CameraRig
var _edge_proximity: float = 0.0
## The arena's `targetable` markers, in the order the scene lists them.
var _targets: Array[Node3D] = []
## Index into [member _targets] of the marker `lock_target` would frame.
var _selected_index: int = 0
## Whether the rig is currently framing [member _selected_index].
var _locked: bool = false


func _ready() -> void:
	if not _resolve_scene():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_player.edge_proximity_changed.connect(_on_edge_proximity_changed)
	var bounds := _read_flight_volume()
	if bounds.size == Vector3.ZERO:
		# Documented fallback: without bounds the ship is limited by collision alone.
		push_warning("%s: FlightBounds metadata is missing; flying without a Flight Volume" % get_path())
	else:
		_player.setup(bounds)


func _process(_delta: float) -> void:
	_read_target_actions()
	readout.text = "\n".join(PackedStringArray([_flight_line(), _camera_line(), _lock_line()]))


## Finds the nodes this harness drives, reporting what is missing instead of failing on a
## null later (CONVENTIONS "Setup errors are loud").
func _resolve_scene() -> bool:
	var missing: PackedStringArray = []
	if arena == null:
		missing.append("arena")
	if readout == null:
		missing.append("readout")
	for field: String in missing:
		push_error("%s: required export '%s' is not set" % [get_path(), field])
	if not missing.is_empty():
		return false
	_player = arena.get_node_or_null(^"PlayerShip") as PlayerController
	if _player == null:
		push_error("%s: %s has no PlayerShip with a PlayerController attached" % [get_path(), arena.get_path()])
		return false
	_rig = _player.camera_rig
	if _rig == null:
		push_error("%s: the PlayerShip has no CameraRig" % get_path())
		return false
	_collect_targets()
	return true


## The authored Flight Volume, or an empty [AABB] when `FlightBounds` or one of its
## metadata keys is absent. `min_corner` and `max_corner` are corners; an [AABB] is a
## position and a size.
func _read_flight_volume() -> AABB:
	var bounds_node := arena.get_node_or_null(^"FlightBounds")
	if bounds_node == null:
		return AABB()
	if not bounds_node.has_meta(MIN_CORNER_META) or not bounds_node.has_meta(MAX_CORNER_META):
		return AABB()
	var minimum: Vector3 = bounds_node.get_meta(MIN_CORNER_META)
	var maximum: Vector3 = bounds_node.get_meta(MAX_CORNER_META)
	return AABB(minimum, maximum - minimum)


## Reads the arena's targets once. Order comes from the scene, so `next_target` walks
## `Low`, `Middle`, `High` the way GUIDE Section 13 lists them.
func _collect_targets() -> void:
	var targets_root := arena.get_node_or_null(^"Targets")
	if targets_root == null:
		push_warning("%s: the arena has no Targets node; the lock actions do nothing" % get_path())
		return
	for child: Node in targets_root.get_children():
		var target := child as Node3D
		if target != null and target.is_in_group(TARGETABLE_GROUP):
			_targets.append(target)


## `lock_target` toggles the lock and `next_target` steps to the next marker, which is
## enough to check how the rig frames and releases a target by hand.
func _read_target_actions() -> void:
	if _targets.is_empty():
		return
	if Input.is_action_just_pressed(&"lock_target"):
		_locked = not _locked
	elif Input.is_action_just_pressed(&"next_target"):
		_selected_index = (_selected_index + 1) % _targets.size()
		_locked = true
	else:
		return
	if _locked:
		_rig.set_lock_target(_targets[_selected_index])
	else:
		_rig.clear_lock_target()


func _flight_line() -> String:
	var ship_position := _player.global_position
	return "pos %+.1f %+.1f %+.1f\nspeed %5.2f of %.1f\nedge %.2f" % [
		ship_position.x, ship_position.y, ship_position.z,
		_player.velocity.length(), _player.base_speed,
		_edge_proximity,
	]


## Yaw, pitch and roll of the rendered camera, and how far it actually sits from the ship
## — which is the number that drops when scenery shortens the rig.
func _camera_line() -> String:
	var euler := _rig.camera.global_transform.basis.get_euler()
	return "cam yaw %+.0f pitch %+.0f roll %+.2f\ncam dist %5.2f of %.1f" % [
		rad_to_deg(euler.y), rad_to_deg(euler.x), rad_to_deg(euler.z),
		_rig.camera.global_position.distance_to(_player.global_position),
		Vector3(0.0, _rig.follow_height, _rig.follow_distance).length(),
	]


func _lock_line() -> String:
	if _targets.is_empty():
		return "lock unavailable: no targets in this arena"
	if not _locked:
		return "lock none, %s selected (K/Y locks, Tab/X cycles)" % _targets[_selected_index].name
	return "lock %s" % _targets[_selected_index].name


func _on_edge_proximity_changed(value: float) -> void:
	_edge_proximity = value
