class_name EnemyActor
extends Node3D
## Adapter: puts one common Enemy's [EnemyModel] in the world (GUIDE Section 5).
##
## The Director adds the prefab under `RuntimeActors` at its spawn marker and calls
## [method spawn_setup]. From then on every physics tick, at the default priority 0 so it
## runs before the [ProjectileSystem] (100), the actor ticks the model with the player's
## position, copies the model's position, hands its hostile spawns to the
## [ProjectileSystem] and registers the `HitVolume` sphere, whose `on_damage` is
## [method take_damage]. It joins `targetable` for Target Lock and Aim Assist and turns
## `VisualRoot` toward the player. Presentation (F15-02): the visual's
## `metadata/anticipation_clip` plays over each Anticipation, every accepted hit flashes the
## visual, and on defeat the actor reports at once, then plays `Death` and frees itself.
## It warns once, on the first Anticipation that starts off-screen. The score is the
## Director's (F10-01), from the same [EnemyDefinition].


## The first Anticipation that started while this Enemy was outside the camera's view:
## [param side] is -1 when it is left of the camera and +1 otherwise. At most once per
## Enemy, so a threat is announced when it is new, not on every attack. The owner forwards
## it to [method Hud.show_threat].
signal threat_reported(side: int)
## The Enemy was defeated. Emitted once, after it left `targetable` and stopped
## registering its hit sphere, and before its `Death` clip; it frees itself when the clip
## ends.
signal defeated(enemy_id: StringName, encounter_id: StringName)
## An accepted hit reached this enemy, including a lethal hit, before defeat is reported.
signal damaged(enemy_id: StringName)


## The group Target Lock and Aim Assist read (`Targeting.group_name`).
const TARGETABLE_GROUP := &"targetable"
## Where every visual scene keeps its player (ENEMY_VISUAL_HANDOFF), relative to
## `VisualRoot`, and the clip played on defeat.
const ANIMATION_PLAYER_PATH := ^"Model/AnimationPlayer"
const DEATH_CLIP := &"Death"
## The visual's metadata naming its Anticipation clip (D-05: `Yes` for Spirits, `Punch`
## for Sentries).
const ANTICIPATION_CLIP_META := &"anticipation_clip"
## The hit flash: an additive overlay on every mesh of `VisualRoot`, starting at this
## colour and fading to black (adds nothing) over this many seconds.
const HIT_FLASH_COLOR := Color(0.85, 0.85, 0.85)
const HIT_FLASH_SECONDS := 0.12
## How fast `VisualRoot` turns toward the player, per second (exponential ease; about
## 0.17 s to close most of a turn). The visuals face their local +Z.
const TURN_RATE := 6.0

@export_group("Scene references")
## The presentation: Astra's visual scene instance, turned toward the player.
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
var _anticipation_seconds: float = 0.0
var _engaged: bool = true
var _enemy_id: StringName = &""
var _threat_warned: bool = false
## Null when the visual has none; then no clip plays and defeat frees at once.
var _animation_player: AnimationPlayer
## The clips that passed the check in [method _validate_scene]; empty for a missing one.
var _idle_clip: StringName = &""
var _anticipation_clip: StringName = &""
var _death_clip: StringName = &""
var _flash_meshes: Array[MeshInstance3D] = []
var _flash_material: StandardMaterial3D
var _flash: Tween


func _ready() -> void:
	# Inert until spawn_setup: no physics, not in `targetable`, nothing registered.
	set_physics_process(false)
	if not _validate_scene():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_bind_visual()


func _physics_process(delta: float) -> void:
	if is_instance_valid(_player) and _player.is_inside_tree():
		_player_position = _player.global_position
	if _engaged:
		var spawns := _model.tick(delta, _player_position, emitter.global_position - global_position)
		global_position = _model.get_position()
		for request: ProjectileSpawn in spawns:
			_projectile_system.spawn(request)
	_turn_visual(1.0 - exp(-TURN_RATE * delta))
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
	_turn_visual(1.0)
	add_to_group(TARGETABLE_GROUP)
	set_physics_process(true)
	return true


## The `on_damage` callback registered with the [ProjectileSystem]: player shots and the
## Bomb. Ignored before [method spawn_setup], after defeat, outside the tree (a stage
## being unloaded), while the tree is paused, and for a non-positive amount. An accepted
## hit flashes the visual.
func take_damage(damage: int) -> void:
	if _model == null or damage <= 0 or not is_inside_tree() or not can_process() or _model.get_health() <= 0:
		return
	damaged.emit(_enemy_id)
	_flash_visual()
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
	_play_anticipation()
	if _threat_warned:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null and not camera.is_position_in_frustum(global_position):
		_threat_warned = true
		threat_reported.emit(threat_side(camera.global_transform, global_position))


## Reports at once, so the Director scores and the Encounter advances on the lethal hit;
## only the `Death` clip waits. A Retry that removes the actor meanwhile frees it early,
## which also drops its Tween.
func _on_model_defeated(enemy_id: StringName, encounter_id: StringName) -> void:
	remove_from_group(TARGETABLE_GROUP)
	set_physics_process(false)
	defeated.emit(enemy_id, encounter_id)
	if _death_clip == &"":
		queue_free()
		return
	_animation_player.clear_queue()
	_animation_player.play(_death_clip)
	# A Tween of this node, so the wait stops while the tree is paused.
	create_tween().tween_callback(queue_free).set_delay(_animation_player.get_animation(_death_clip).length)


## Plays the Anticipation clip once, stretched to last exactly the Anticipation, then
## returns to the idle clip.
func _play_anticipation() -> void:
	if _anticipation_clip == &"" or _anticipation_seconds <= 0.0:
		return
	var length := _animation_player.get_animation(_anticipation_clip).length
	_animation_player.clear_queue()
	_animation_player.play(_anticipation_clip, -1.0, length / _anticipation_seconds)
	if _idle_clip != &"":
		_animation_player.queue(_idle_clip)


## Restarts the fade of the additive overlay; the overlay is removed once it is black, so
## an Enemy nobody is shooting draws no extra pass. The Tween belongs to this node, so it
## stops while the tree is paused.
func _flash_visual() -> void:
	if _flash_meshes.is_empty():
		return
	if _flash != null:
		_flash.kill()
	_set_flash_overlay(_flash_material)
	_flash_material.albedo_color = HIT_FLASH_COLOR
	_flash = create_tween()
	_flash.tween_property(_flash_material, ^"albedo_color", Color.BLACK, HIT_FLASH_SECONDS)
	_flash.tween_callback(_set_flash_overlay.bind(null))


func _set_flash_overlay(material: Material) -> void:
	for mesh: MeshInstance3D in _flash_meshes:
		mesh.material_overlay = material


## Turns `VisualRoot` about the actor's up axis toward the player by [param weight] of the
## remaining angle (1.0 snaps). Yaw only: the visual never tilts.
func _turn_visual(weight: float) -> void:
	var local_offset := global_transform.basis.inverse() * (_player_position - global_position)
	if is_zero_approx(local_offset.x) and is_zero_approx(local_offset.z):
		return
	var target_yaw := atan2(local_offset.x, local_offset.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, weight)


## Finds the visual's [AnimationPlayer] and clips (a named clip the player lacks is warned
## once and skipped) and builds this actor's own flash material, so one Enemy's flash
## never lights another sharing the same visual resources.
func _bind_visual() -> void:
	_animation_player = visual_root.get_node_or_null(ANIMATION_PLAYER_PATH) as AnimationPlayer
	if _animation_player == null:
		push_warning("%s: no AnimationPlayer at VisualRoot/%s; no Anticipation or Death clip plays" % [
			get_path(), ANIMATION_PLAYER_PATH,
		])
	else:
		_idle_clip = _checked_clip(_animation_player.autoplay, "autoplay")
		var anticipation_meta := str(visual_root.get_meta(ANTICIPATION_CLIP_META, ""))
		_anticipation_clip = _checked_clip(StringName(anticipation_meta), "metadata/anticipation_clip")
		_death_clip = _checked_clip(DEATH_CLIP, "the defeat clip")
	for node: Node in visual_root.find_children("*", "MeshInstance3D", true, false):
		_flash_meshes.append(node as MeshInstance3D)
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# Fog would tint the additive pass even while it is black.
	_flash_material.disable_fog = true


## [param clip] when the visual's player has it, otherwise &"" after one warning naming
## [param field]. An empty [param clip] means no cue and is not warned.
func _checked_clip(clip: StringName, field: String) -> StringName:
	if clip == &"":
		return &""
	if not _animation_player.has_animation(clip):
		push_warning("%s: %s '%s' is not an animation of %s; the cue is skipped" % [
			get_path(), field, clip, _animation_player.get_path(),
		])
		return &""
	return clip


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
