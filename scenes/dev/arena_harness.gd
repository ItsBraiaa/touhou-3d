extends Node3D
## Dev harness for Feature F1: the scene to run (F6) while flying the combat arena.
##
## It stands in for the owner `GameSession` becomes in F2-04: it reads the authored
## `FlightBounds` metadata, hands the Flight Volume to [PlayerController] through
## [method PlayerController.setup], and shows the live position, speed, Focus state and
## edge-proximity value so a manual flight check has numbers to read. Dev only: it is
## never loaded by `scenes/main.tscn` and holds no gameplay rule.


## Metadata keys Astra authors on `FlightBounds` (GUIDE Section 13).
const MIN_CORNER_META := &"min_corner"
const MAX_CORNER_META := &"max_corner"

## The instanced `combat_arena.tscn`, holding `PlayerShip` and `FlightBounds`.
@export var arena: Node3D
## Label the live flight values are written to.
@export var readout: Label

var _player: PlayerController
var _edge_proximity: float = 0.0


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
	var ship_position := _player.global_position
	readout.text = "pos %+.1f %+.1f %+.1f\nspeed %5.2f of %.1f\nedge %.2f" % [
		ship_position.x, ship_position.y, ship_position.z,
		_player.velocity.length(), _player.base_speed,
		_edge_proximity,
	]


## Finds the two arena nodes this harness drives, reporting what is missing instead of
## failing on a null later (CONVENTIONS "Setup errors are loud").
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


func _on_edge_proximity_changed(value: float) -> void:
	_edge_proximity = value
