class_name EnemyActor
extends Node3D
## Adapter: puts one common Enemy's [EnemyModel] in the world (GUIDE Section 5).
##
## The Director adds the prefab under `RuntimeActors` at its spawn marker and calls
## [method spawn_setup]. From then on every physics tick, at the default priority 0 so it
## runs before the [ProjectileSystem] (100), the actor ticks the model with the player's
## position, copies the model's position, hands its hostile spawns to the
## [ProjectileSystem] and registers the `HitVolume` sphere, whose `on_damage` is
## [method take_damage]. It joins `targetable` for Target Lock and Aim Assist, pulses
## `VisualRoot` during each Anticipation (a dev cue until Astra picks a clip), reports the
## side of an attack that starts off-screen, and on defeat reports once and frees itself.
## The score is the Director's (F10-01), from the same [EnemyDefinition].


## An Anticipation started while this Enemy was outside the camera's view: [param side]
## is -1 when it is left of the camera and +1 otherwise. The owner forwards it to
## [method Hud.show_threat].
signal threat_reported(side: int)
## The Enemy was defeated. Emitted once, just before the actor frees itself.
signal defeated(enemy_id: StringName, encounter_id: StringName)
## An accepted hit reached this enemy, including a lethal hit, before defeat is reported.
signal damaged(enemy_id: StringName)


## The group Target Lock and Aim Assist read (`Targeting.group_name`).
const TARGETABLE_GROUP := &"targetable"
## Pulses of `VisualRoot` spread over one Anticipation, and their peak scale factor.
const ANTICIPATION_PULSES := 2
const ANTICIPATION_PULSE_SCALE := 1.3

@export_group("Scene references")
## The presentation: Astra's visual scene instance. Pulsed during Anticipation.
@export var visual_root: Node3D
## The hit volume: an [Area3D] on layer 5 (bit 16) with monitoring off, whose first
## [CollisionShape3D] child holds a [SphereShape3D]. Its node position is the hit center
## and the sphere's radius is the hit radius; node scale is ignored.
@export var hit_volume: Area3D
## Where the pattern leaves from (`Emitters/Main`).
@export var emitter: Marker3D

var _model: EnemyModel
var _projectile_system: ProjectileSystem
var _player: Node3D
var _player_position := Vector3.ZERO
var _hit_radius: float = 0.0
var _visual_rest_scale := Vector3.ONE
var _anticipation_seconds: float = 0.0
var _pulse: Tween
var _engaged: bool = true
var _enemy_id: StringName = &""


func _ready() -> void:
	# Inert until spawn_setup: no physics, not in `targetable`, nothing registered.
	set_physics_process(false)
	if not _validate_scene():
		process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	if is_instance_valid(_player) and _player.is_inside_tree():
		_player_position = _player.global_position
	if _engaged:
		var spawns := _model.tick(delta, _player_position, emitter.global_position - global_position)
		global_position = _model.get_position()
		for request: ProjectileSpawn in spawns:
			_projectile_system.spawn(request)
	_projectile_system.register_target(get_instance_id(), hit_volume.global_position, _hit_radius, take_damage)


## Brings the Enemy to life. The Director calls it once, after `add_child` under
## `RuntimeActors`, with the actor already at its spawn marker's transform, which becomes the
## model's movement anchor (clamped into [param bounds]). [param rng] is the Attempt's
## shared generator; [param player] is only read for its position. Returns true when the
## Enemy started. A missing or invalid argument is reported with
## [method @GlobalScope.push_error], the actor stays inert and it returns false; the caller
## frees it.
func spawn_setup(
		definition: EnemyDefinition, enemy_id: StringName, encounter_id: StringName,
		rng: RandomNumberGenerator, projectile_system: ProjectileSystem, player: Node3D,
		bounds: AABB) -> bool:
	if not is_inside_tree():
		push_error("EnemyActor '%s': spawn_setup refused: add_child it before spawn_setup" % name)
		return false
	var errors := _setup_errors(definition, enemy_id, encounter_id, rng, projectile_system, player, bounds)
	if not errors.is_empty():
		for message: String in errors:
			push_error("%s: spawn_setup refused: %s" % [get_path(), message])
		return false
	_projectile_system = projectile_system
	_enemy_id = enemy_id
	_player = player
	_player_position = player.global_position
	_anticipation_seconds = definition.anticipation_seconds
	_model = EnemyModel.new()
	_model.setup(definition, enemy_id, encounter_id, rng, global_position, bounds)
	_model.anticipation_started.connect(_on_anticipation_started)
	_model.defeated.connect(_on_model_defeated)
	global_position = _model.get_position()
	add_to_group(TARGETABLE_GROUP)
	set_physics_process(true)
	return true


## The `on_damage` callback registered with the [ProjectileSystem]: player shots and the
## Bomb. Ignored before [method spawn_setup], after defeat, outside the tree (a stage
## being unloaded), while the tree is paused, and for a non-positive amount.
func take_damage(damage: int) -> void:
	if _model == null or damage <= 0 or not is_inside_tree() or not can_process() or _model.get_health() <= 0:
		return
	damaged.emit(_enemy_id)
	_model.take_damage(damage)


## Remaining health, or 0 before [method spawn_setup].
func get_health() -> int:
	return 0 if _model == null else _model.get_health()


## Dormant guards remain targetable and damageable, but their movement and attack clock
## do not advance. Call immediately after spawn_setup, before their first physics tick.
func set_engaged(engaged: bool) -> void:
	_engaged = engaged


## -1 when [param point] is left of the camera (against its local +X) and +1 otherwise,
## including straight ahead or behind. The HUD shows left and right warnings only.
static func threat_side(camera_transform: Transform3D, point: Vector3) -> int:
	var offset := point - camera_transform.origin
	return -1 if offset.dot(camera_transform.basis.x) < 0.0 else 1


func _on_anticipation_started() -> void:
	_pulse_visual()
	var camera := get_viewport().get_camera_3d()
	if camera != null and not camera.is_position_in_frustum(global_position):
		threat_reported.emit(threat_side(camera.global_transform, global_position))


func _on_model_defeated(enemy_id: StringName, encounter_id: StringName) -> void:
	remove_from_group(TARGETABLE_GROUP)
	set_physics_process(false)
	defeated.emit(enemy_id, encounter_id)
	queue_free()


## The dev Anticipation cue: [constant ANTICIPATION_PULSES] swells of `VisualRoot` over
## the Anticipation. The Tween belongs to this node, so it stops while the tree is paused.
func _pulse_visual() -> void:
	if _pulse != null:
		_pulse.kill()
	visual_root.scale = _visual_rest_scale
	if _anticipation_seconds <= 0.0:
		return
	var half_pulse := _anticipation_seconds / (2.0 * ANTICIPATION_PULSES)
	_pulse = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for _pulse_index: int in range(ANTICIPATION_PULSES):
		_pulse.tween_property(visual_root, ^"scale", _visual_rest_scale * ANTICIPATION_PULSE_SCALE, half_pulse)
		_pulse.tween_property(visual_root, ^"scale", _visual_rest_scale, half_pulse)


## Reports each missing reference or unusable hit shape with this node's path
## (CONVENTIONS "Setup errors are loud") and reads the hit radius.
func _validate_scene() -> bool:
	var missing: PackedStringArray = []
	if visual_root == null:
		missing.append("visual_root")
	if hit_volume == null:
		missing.append("hit_volume")
	if emitter == null:
		missing.append("emitter")
	for field: String in missing:
		push_error("%s: required export '%s' is not set" % [get_path(), field])
	if not missing.is_empty():
		return false
	_visual_rest_scale = visual_root.scale
	for child: Node in hit_volume.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node != null:
			var sphere := shape_node.shape as SphereShape3D
			if sphere != null:
				_hit_radius = sphere.radius
			break
	if _hit_radius <= 0.0:
		push_error("%s: %s's first CollisionShape3D child must hold a SphereShape3D with a positive radius" % [
			get_path(), hit_volume.get_path(),
		])
		return false
	return true


func _setup_errors(
		definition: EnemyDefinition, enemy_id: StringName, encounter_id: StringName,
		rng: RandomNumberGenerator, projectile_system: ProjectileSystem, player: Node3D,
		bounds: AABB) -> PackedStringArray:
	var errors: PackedStringArray = []
	if _hit_radius <= 0.0:
		errors.append("the scene failed its own setup check")
	if _model != null:
		errors.append("already set up")
	if definition == null:
		errors.append("definition is null")
	else:
		errors.append_array(definition.validate())
	if enemy_id == &"":
		errors.append("enemy_id is empty")
	if encounter_id == &"":
		errors.append("encounter_id is empty")
	if rng == null:
		errors.append("rng is null")
	if projectile_system == null:
		errors.append("projectile_system is null")
	if player == null or not player.is_inside_tree():
		errors.append("player is null or not in the tree")
	if not bounds.has_volume():
		errors.append("bounds has no volume")
	return errors
