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
## counts them, with the hits and Grazes on the ship (F6-02). The ship's [PlayerWeapon]
## fires at three [TargetDummy]s, and the dev keys 1, 2 and 3 restart the [CombatState] at
## that Power Level (F6-03). A row of eleven Power Pickups and one Shield Pickup is spawned
## on `_ready`, and the dev key H breaks the Shield so the Shield Pickup can be taken
## (F7-03). Dev only: it is never loaded by `scenes/main.tscn` and holds no gameplay rule.


## Metadata keys Astra authors on `FlightBounds` (GUIDE Section 13).
const MIN_CORNER_META := &"min_corner"
const MAX_CORNER_META := &"max_corner"
## F7-03: eleven Power Pickups, one every three units along -Z beside the ship's start: ten
## raise Power Level 1 to 3 and the eleventh awards the excess score. The Shield Pickup
## sits across the arena, out of the row's attraction range.
const POWER_PICKUP_COUNT := 11
const POWER_ROW_START := Vector3(-14.0, 6.0, 12.0)
const POWER_ROW_STEP := Vector3(0.0, 0.0, -3.0)
const SHIELD_PICKUP_POSITION := Vector3(14.0, 6.0, 6.0)

## The instanced `combat_arena.tscn`, holding `PlayerShip`, `FlightBounds` and `Targets`.
@export var arena: Node3D
## Label the live flight values are written to.
@export var readout: Label
## The combat HUD instance under `HudLayer`.
@export var hud: Hud
## The harness's own ProjectileSystem, set up with the arena's Flight Volume.
@export var projectile_system: ProjectileSystem
## Holds the [TargetDummy] instances, set up with [member projectile_system].
@export var dummy_root: Node3D
## Where the spawned [Pickup]s are added.
@export var pickup_root: Node3D
## A [Pickup] scene of kind POWER (`scenes/dev/power_pickup.tscn`).
@export var power_pickup_scene: PackedScene
## A [Pickup] scene of kind SHIELD (`scenes/dev/shield_pickup.tscn`).
@export var shield_pickup_scene: PackedScene

var _player: PlayerController
var _rig: CameraRig
var _edge_proximity: float = 0.0
## Stands in for the Session's: started at Power Level 1, and reused by the weapon (F6-03).
var _combat_state := CombatState.new()
var _hits: int = 0
var _grazes: int = 0
var _pickups_taken: int = 0
## Score the [CombatState] awarded for excess Power Pickups.
var _pickup_score: int = 0


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
	_combat_state.score_awarded.connect(_on_score_awarded)
	hud.bind(_combat_state, _player.targeting, _rig.camera)
	_player.weapon.setup(_combat_state, projectile_system, _player.targeting)
	for dummy: TargetDummy in _dummies():
		dummy.setup(projectile_system)
	_spawn_pickups()


## Dev keys 1, 2 and 3 restart the combat state at that Power Level; H hits the ship once,
## which breaks the Shield (the harness never ticks the core, so the Invulnerability that
## follows lasts until the next restart).
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var level := key.keycode - KEY_0
	if level >= CombatState.MIN_POWER_LEVEL and level <= CombatState.MAX_POWER_LEVEL:
		_combat_state.start(level)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_H:
		_combat_state.take_hit()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	readout.text = "\n".join(PackedStringArray([_flight_line(), _camera_line(), _lock_line(), _projectile_line(), _weapon_line(), _pickup_line()]))


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
	if dummy_root == null:
		missing.append("dummy_root")
	if pickup_root == null:
		missing.append("pickup_root")
	if power_pickup_scene == null:
		missing.append("power_pickup_scene")
	if shield_pickup_scene == null:
		missing.append("shield_pickup_scene")
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


## Power Level, Bombs left and the hits each dummy has taken.
func _weapon_line() -> String:
	var counts: PackedStringArray = []
	for dummy: TargetDummy in _dummies():
		counts.append("%s %d" % [dummy.name, dummy.hit_count])
	return "power %d bombs %d (1/2/3 set power, J fires, L bombs)\ndummy hits %s" % [
		_combat_state.get_power_level(), _combat_state.get_bombs(), " ".join(counts),
	]


## Power Progress, the Shield, the Pickups taken and the excess score they awarded.
func _pickup_line() -> String:
	return "progress %d of %d shield %s (H breaks it)\npickups %d excess score +%d" % [
		_combat_state.get_power_progress(), CombatState.PICKUPS_PER_LEVEL,
		"on" if _combat_state.has_shield() else "off",
		_pickups_taken, _pickup_score,
	]


func _spawn_pickups() -> void:
	for index: int in POWER_PICKUP_COUNT:
		var pickup_id := StringName("arena/power_%d" % (index + 1))
		_spawn_pickup(power_pickup_scene, pickup_id, POWER_ROW_START + POWER_ROW_STEP * index)
	_spawn_pickup(shield_pickup_scene, &"arena/shield_1", SHIELD_PICKUP_POSITION)


func _spawn_pickup(scene: PackedScene, pickup_id: StringName, at: Vector3) -> void:
	var node := scene.instantiate()
	var pickup := node as Pickup
	if pickup == null:
		push_error("%s: %s has no Pickup root" % [get_path(), scene.resource_path])
		node.free()
		return
	pickup_root.add_child(pickup)
	pickup.global_position = at
	pickup.setup(pickup_id, _combat_state, _player)
	pickup.accepted.connect(_on_pickup_accepted)


func _dummies() -> Array[TargetDummy]:
	var found: Array[TargetDummy] = []
	for child: Node in dummy_root.get_children():
		if child is TargetDummy:
			found.append(child as TargetDummy)
	return found


func _on_edge_proximity_changed(value: float) -> void:
	_edge_proximity = value


func _on_player_hit(_projectile_id: int, _damage: int) -> void:
	_hits += 1


func _on_grazed(_projectile_id: int) -> void:
	_grazes += 1


func _on_pickup_accepted(_pickup_id: StringName, _kind: Pickup.Kind, _score_awarded: int) -> void:
	_pickups_taken += 1


func _on_score_awarded(points: int) -> void:
	_pickup_score += points
