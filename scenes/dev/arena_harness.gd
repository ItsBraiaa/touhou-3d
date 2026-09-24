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
## that Power Level (F6-03). A dev Spirit and Sentry spawn at the `EnemySpawns` markers
## under the arena's `RuntimeActors`, as the Director will spawn them, and the dev key R
## respawns the defeated ones (F9-02). Dev only: it is never loaded by `scenes/main.tscn`
## and holds no gameplay rule.


## Metadata keys Astra authors on `FlightBounds` (GUIDE Section 13).
const MIN_CORNER_META := &"min_corner"
const MAX_CORNER_META := &"max_corner"
## F9-02: the dev enemies, the harness's own Attempt seed and encounter id, and how long an
## off-screen warning shows on the HUD.
const SPIRIT_SCENE := preload("res://scenes/dev/spirit.tscn")
const SENTRY_SCENE := preload("res://scenes/dev/sentry.tscn")
const SPIRIT_DEFINITION: EnemyDefinition = preload("res://content/enemies/spirit.tres")
const SENTRY_DEFINITION: EnemyDefinition = preload("res://content/enemies/sentry.tres")
const ENEMY_SEED := 902
const ENEMY_ENCOUNTER_ID := &"arena"
const THREAT_SECONDS := 1.0

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

var _player: PlayerController
var _rig: CameraRig
var _edge_proximity: float = 0.0
## Stands in for the Session's: started at Power Level 1, and reused by the weapon (F6-03).
var _combat_state := CombatState.new()
var _hits: int = 0
var _grazes: int = 0
## F9-02: the live dev enemy of each `EnemySpawns` marker, by marker name.
var _enemies: Dictionary[StringName, EnemyActor] = {}
var _enemy_rng := RandomNumberGenerator.new()
var _enemy_bounds: AABB
var _enemy_spawn_count: int = 0
var _enemy_defeats: int = 0
var _last_threat: String = "none"

@onready var _enemy_spawns: Node3D = $EnemySpawns


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
	_player.weapon.setup(_combat_state, projectile_system, _player.targeting)
	for dummy: TargetDummy in _dummies():
		dummy.setup(projectile_system)
	_start_enemies(bounds)


## Dev keys 1, 2 and 3 restart the combat state at that Power Level, standing in for the
## Pickups of F7-03. R respawns the defeated dev enemies (F9-02).
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_R:
		_spawn_missing_enemies()
		get_viewport().set_input_as_handled()
		return
	var level := key.keycode - KEY_0
	if level >= CombatState.MIN_POWER_LEVEL and level <= CombatState.MAX_POWER_LEVEL:
		_combat_state.start(level)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	readout.text = "\n".join(PackedStringArray([_flight_line(), _camera_line(), _lock_line(), _projectile_line(), _weapon_line(), _enemy_line()]))


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


## F9-02: seeds the harness's Attempt RNG and spawns both dev enemies, which need the
## Flight Volume as their movement bounds.
func _start_enemies(bounds: AABB) -> void:
	if not bounds.has_volume():
		push_warning("%s: no Flight Volume, so no dev enemies" % get_path())
		return
	_enemy_rng.seed = ENEMY_SEED
	_enemy_bounds = bounds
	_spawn_missing_enemies()


## Spawns the Spirit and the Sentry at their markers, each only if its last one is gone.
func _spawn_missing_enemies() -> void:
	_spawn_enemy_if_missing(&"Spirit", SPIRIT_SCENE, SPIRIT_DEFINITION)
	_spawn_enemy_if_missing(&"Sentry", SENTRY_SCENE, SENTRY_DEFINITION)


## What the Director does for one spawn: instance under `RuntimeActors`, place at the
## marker, then [method EnemyActor.spawn_setup] with a unique id.
func _spawn_enemy_if_missing(marker_name: StringName, scene: PackedScene, definition: EnemyDefinition) -> void:
	if _enemies.has(marker_name):
		return
	var marker := _enemy_spawns.get_node_or_null(NodePath(marker_name)) as Marker3D
	var actors_root := arena.get_node_or_null(^"RuntimeActors")
	if marker == null or actors_root == null:
		push_error("%s: needs EnemySpawns/%s and %s/RuntimeActors" % [get_path(), marker_name, arena.get_path()])
		return
	var actor := scene.instantiate() as EnemyActor
	actor.name = marker_name
	actors_root.add_child(actor)
	actor.global_transform = marker.global_transform
	_enemy_spawn_count += 1
	var enemy_id := StringName("%s_%d" % [marker_name, _enemy_spawn_count])
	if not actor.spawn_setup(definition, enemy_id, ENEMY_ENCOUNTER_ID, _enemy_rng, projectile_system, _player, _enemy_bounds):
		actor.queue_free()
		return
	actor.defeated.connect(_on_enemy_defeated.bind(marker_name))
	actor.threat_reported.connect(_on_enemy_threat_reported.bind(marker_name))
	_enemies[marker_name] = actor


## Each dev enemy's health, the defeats reported and the last off-screen warning.
func _enemy_line() -> String:
	var states: PackedStringArray = []
	for marker_name: StringName in [&"Spirit", &"Sentry"]:
		var state := "hp %d" % _enemies[marker_name].get_health() if _enemies.has(marker_name) else "down"
		states.append("%s %s" % [marker_name, state])
	return "enemies %s (R respawns)\ndefeats %d threat %s" % [" ".join(states), _enemy_defeats, _last_threat]


## A defeated actor frees itself, so it leaves [member _enemies] now, before it is freed.
func _on_enemy_defeated(_enemy_id: StringName, _encounter_id: StringName, marker_name: StringName) -> void:
	_enemies.erase(marker_name)
	_enemy_defeats += 1


func _on_enemy_threat_reported(side: int, marker_name: StringName) -> void:
	_last_threat = "%s %s" % [marker_name, "left" if side < 0 else "right"]
	hud.show_threat(side, THREAT_SECONDS)
