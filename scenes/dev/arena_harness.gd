extends Node3D
## Dev harness for Feature F1: the scene to run (F6) while flying the combat arena.
##
## It stands in for the owner `GameSession` becomes in F2-04: it reads the authored
## `FlightBounds` metadata, hands the Flight Volume to [PlayerController] through
## [method PlayerController.setup], and shows the live position, speed, Focus state,
## edge-proximity value, camera framing and Target Lock so a manual flight check has
## numbers to read. The lock itself is the ship's own: [Targeting] reads `lock_target` and
## `next_target`, and the ship hands the result to its [CameraRig] (F1-04). The combat HUD
## shows a harness-owned [CombatState] and marks the locked target (F4-02). A
## [ProjectileSystem] of its own carries the rings a [DevSpray] fires, and the readout
## counts them, with the hits and Grazes on the ship (F6-02). Dev only: it
## is never loaded by `scenes/main.tscn` and holds no gameplay rule.


## Metadata keys Astra authors on `FlightBounds` (GUIDE Section 13).
const MIN_CORNER_META := &"min_corner"
const MAX_CORNER_META := &"max_corner"

## The instanced `combat_arena.tscn`, holding `PlayerShip`, `FlightBounds` and `Targets`.
@export var arena: Node3D
## Label the live flight values are written to.
@export var readout: Label
## The combat HUD instance under `HudLayer`.
@export var hud: Hud
## The harness's own ProjectileSystem, set up with the arena's Flight Volume.
@export var projectile_system: ProjectileSystem

var _player: PlayerController
var _rig: CameraRig
var _edge_proximity: float = 0.0
## Stands in for the Session's: started at Power Level 1, and reused by the weapon (F6-03).
var _combat_state := CombatState.new()
var _hits: int = 0
var _grazes: int = 0


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
		projectile_system.setup(bounds, _player)
	projectile_system.player_hit.connect(_on_player_hit)
	projectile_system.grazed.connect(_on_grazed)
	_combat_state.start(CombatState.MIN_POWER_LEVEL)
	hud.bind(_combat_state, _player.targeting, _rig.camera)


func _process(_delta: float) -> void:
	readout.text = "\n".join(PackedStringArray([_flight_line(), _camera_line(), _lock_line(), _projectile_line()]))


## Finds the nodes this harness drives, reporting what is missing instead of failing on a
## null later (CONVENTIONS "Setup errors are loud").
func _resolve_scene() -> bool:
	var missing: PackedStringArray = []
	if arena == null:
		missing.append("arena")
	if readout == null:
		missing.append("readout")
	if hud == null:
		missing.append("hud")
	if projectile_system == null:
		missing.append("projectile_system")
	for field: String in missing:
		push_error("%s: required export '%s' is not set" % [get_path(), field])
	if not missing.is_empty():
		return false
	_player = arena.get_node_or_null(^"PlayerShip") as PlayerController
	if _player == null:
		push_error("%s: %s has no PlayerShip with a PlayerController attached" % [get_path(), arena.get_path()])
		return false
	_rig = _player.camera_rig
	if _rig == null or _player.targeting == null:
		push_error("%s: the PlayerShip is missing its CameraRig or its Targeting" % get_path())
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


## The locked target's name and its distance against the release range, which is the
## number to watch while flying out of range.
func _lock_line() -> String:
	var targeting := _player.targeting
	var target := targeting.get_current_target()
	if target == null:
		return "lock none (K/Y locks, Tab/X cycles)"
	return "lock %s at %.1f of %.1f" % [
		target.name, target.global_position.distance_to(_player.global_position), targeting.max_distance,
	]


## Projectiles in flight, the hits and Grazes on the ship, and the spawns a full field
## refused.
func _projectile_line() -> String:
	return "bullets hostile %d player %d\nhits %d grazes %d refused %d" % [
		projectile_system.count(ProjectileSpawn.Faction.HOSTILE),
		projectile_system.count(ProjectileSpawn.Faction.PLAYER),
		_hits, _grazes, projectile_system.get_field().get_refused_count(),
	]


func _on_edge_proximity_changed(value: float) -> void:
	_edge_proximity = value


func _on_player_hit(_projectile_id: int, _damage: int) -> void:
	_hits += 1


func _on_grazed(_projectile_id: int) -> void:
	_grazes += 1
