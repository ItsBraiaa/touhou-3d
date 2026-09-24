class_name BossController
extends Node3D
## Adapter: puts one Boss's [BossMachine] in the world (GUIDE Section 5).
##
## The Director adds the prefab under `RuntimeActors` at its spawn marker and calls
## [method spawn_setup], as for an [EnemyActor]. From then on every physics tick, at the
## default priority 0 so it runs before the [ProjectileSystem] (100), the controller hovers
## the boss around its marker, ticks the machine from `Emitters/Main`, hands its hostile
## spawns to the [ProjectileSystem] and registers the `HitVolume` sphere, whose `on_damage`
## is [method take_damage]. It joins `targetable`, clears every hostile Projectile when a
## Phase is depleted, plays cues only by clip names the assigned [AnimationPlayer] really
## has, warns when a step starts off-screen, and reports the fight through signals shaped
## for the HUD boss panel ([method Hud.show_boss] and its siblings), which the owner
## connects (F12-03). Since F15-03 it turns `VisualRoot` toward the player and, with
## [member ring_cue] on, shows a ring at the height of each coming ring. The score is the
## Director's, through [method get_score].


## The fight began: [param display_name] (Portuguese, from the Definition) and its
## [param phase_count] Phases, 2 or 3. Emitted before the first [signal phase_changed].
## For [method Hud.show_boss].
signal boss_started(display_name: String, phase_count: int)
## Phase [param phase_index] began with the Attack [param attack_name]: Phase 0 right
## after [signal boss_started], each later one when the previous is depleted. For
## [method Hud.show_attack_cue].
signal phase_changed(phase_index: int, attack_name: String)
## Phase [param phase_index] now holds [param ratio] of its health, 0.0 to 1.0. For
## [method Hud.set_phase_health].
signal phase_health_changed(phase_index: int, ratio: float)
## A step's Anticipation began while the hit center was outside the camera's view:
## [param side] is -1 left of the camera, +1 otherwise ([method EnemyActor.threat_side]).
## For [method Hud.show_threat].
signal threat_reported(side: int)
## The last Phase was depleted. Emitted once, after the boss left `targetable`; the boss
## frees itself when [member defeat_clip] ends, or at once without one. For
## [method Hud.hide_boss] and the Director.
signal defeated(enemy_id: StringName, encounter_id: StringName)


## The group Target Lock and Aim Assist read (`Targeting.group_name`).
const TARGETABLE_GROUP := &"targetable"
## The placeholder hover: a vertical bob around the spawn marker, in world units and
## seconds per cycle.
const HOVER_AMPLITUDE := 0.6
const HOVER_PERIOD := 4.0
## How fast `VisualRoot` turns toward the player, per second (exponential ease; slower
## than a common Enemy's, for the bigger body). The visuals face their local +Z.
const TURN_RATE := 4.0
## The ring cue: its radius as a multiple of the hit radius, the scale it grows from over
## the Anticipation, its tube thickness in world units and its additive colour.
const RING_CUE_RADIUS_FACTOR := 1.5
const RING_CUE_START_SCALE := 0.3
const RING_CUE_THICKNESS := 0.3
const RING_CUE_COLOR := Color(0.55, 0.8, 1.0)

@export_group("Scene references")
## The presentation: Astra's boss visual (the dev prefab uses a primitive mesh), turned
## (yaw only) toward the player.
@export var visual_root: Node3D
## The hit volume: an [Area3D] on layer 5 (bit 16) with monitoring off, whose first
## [CollisionShape3D] child holds a [SphereShape3D]. Its node position is the hit center
## and the sphere's radius is the hit radius; node scale is ignored.
@export var hit_volume: Area3D
## Where every Pattern leaves from (`Emitters/Main`), before a step's height offset.
@export var emitter: Marker3D

@export_group("Animation")
## The player the clips below belong to, usually `VisualRoot/Model/AnimationPlayer`.
## Optional: without it no clip plays.
@export var animation_player: AnimationPlayer
## Looping idle, played at spawn and after every other cue. Empty means no cue.
@export var idle_clip: StringName
## Played when each step's Anticipation begins. Empty means no cue.
@export var step_clip: StringName
## Played when a Phase after the first begins. Empty means no cue.
@export var phase_clip: StringName
## Played on defeat; the boss is freed when it ends. Empty means freed at once.
@export var defeat_clip: StringName

@export_group("Cues")
## Círculos do Trovão's cue (STAGE_DESIGN, Stage 2 final boss): before each step whose
## Pattern is a RING at a fixed height (not [member AttackStepDefinition.follow_player_height]),
## a code-built ring appears at the height the rings will leave from and grows over the
## step's Anticipation. It is a child of this node, so it is freed with the boss. Only the
## Storm Guardian sets it.
@export var ring_cue: bool = false

var _machine: BossMachine
var _definition: BossDefinition
var _projectile_system: ProjectileSystem
var _player: Node3D
var _player_position := Vector3.ZERO
var _hit_radius: float = 0.0
var _anchor := Vector3.ZERO
var _bounds: AABB
var _hover_time: float = 0.0
## The clips that passed the check in [method spawn_setup]; empty for a skipped one.
var _idle: StringName = &""
var _step: StringName = &""
var _phase_cue: StringName = &""
var _defeat: StringName = &""
## Built in [method spawn_setup] when [member ring_cue] is on; hidden between cues.
var _ring_cue: MeshInstance3D
var _ring_cue_tween: Tween


func _ready() -> void:
	# Inert until spawn_setup: no physics, not in `targetable`, nothing registered.
	set_physics_process(false)
	if not _validate_scene():
		process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	if is_instance_valid(_player) and _player.is_inside_tree():
		_player_position = _player.global_position
	_hover_time += delta
	var bob := Vector3.UP * HOVER_AMPLITUDE * sin(TAU * _hover_time / HOVER_PERIOD)
	global_position = (_anchor + bob).clamp(_bounds.position, _bounds.end)
	for request: ProjectileSpawn in _machine.tick(delta, emitter.global_position, _player_position):
		_projectile_system.spawn(request)
	_turn_visual(1.0 - exp(-TURN_RATE * delta))
	_projectile_system.register_target(get_instance_id(), hit_volume.global_position, _hit_radius, take_damage)


## Starts the fight. Same call, order and meaning as [method EnemyActor.spawn_setup]:
## once, after `add_child` under `RuntimeActors`, with the boss at its spawn marker, which
## becomes the hover anchor (clamped into [param bounds]). Checks the clips (a configured
## clip the [member animation_player] lacks is reported once with
## [method @GlobalScope.push_warning] and skipped), joins `targetable`, emits
## [signal boss_started], then starts the machine, which emits [signal phase_changed] for
## Phase 0. Returns true when the boss started. A missing or invalid argument is reported
## with [method @GlobalScope.push_error], the boss stays inert and it returns false; the
## caller frees it.
func spawn_setup(
		definition: BossDefinition, enemy_id: StringName, encounter_id: StringName,
		rng: RandomNumberGenerator, projectile_system: ProjectileSystem, player: Node3D,
		bounds: AABB) -> bool:
	if not is_inside_tree():
		push_error("BossController '%s': spawn_setup refused: add_child it before spawn_setup" % name)
		return false
	var errors := _setup_errors(definition, enemy_id, encounter_id, rng, projectile_system, player, bounds)
	if not errors.is_empty():
		for message: String in errors:
			push_error("%s: spawn_setup refused: %s" % [get_path(), message])
		return false
	_projectile_system = projectile_system
	_player = player
	_player_position = player.global_position
	_bounds = bounds
	_anchor = global_position.clamp(bounds.position, bounds.end)
	global_position = _anchor
	_idle = _checked_clip(idle_clip, "idle_clip")
	_step = _checked_clip(step_clip, "step_clip")
	_phase_cue = _checked_clip(phase_clip, "phase_clip")
	_defeat = _checked_clip(defeat_clip, "defeat_clip")
	_turn_visual(1.0)
	if ring_cue:
		_ring_cue = _build_ring_cue()
	_definition = definition
	_machine = BossMachine.new()
	_machine.setup(definition, enemy_id, encounter_id, rng)
	_machine.phase_changed.connect(_on_machine_phase_changed)
	_machine.phase_health_changed.connect(phase_health_changed.emit)
	_machine.step_started.connect(_on_machine_step_started)
	_machine.hostile_clear_requested.connect(_on_machine_hostile_clear_requested)
	_machine.defeated.connect(_on_machine_defeated)
	add_to_group(TARGETABLE_GROUP)
	set_physics_process(true)
	_play(_idle)
	boss_started.emit(definition.display_name, _machine.get_phase_count())
	_machine.start()
	return true


## The `on_damage` callback registered with the [ProjectileSystem]: player shots and the
## Bomb. The machine caps each hit at the current Phase and refuses it during a
## transition. Ignored before [method spawn_setup], after defeat, outside the tree (a
## stage being unloaded), while the tree is paused, and for a non-positive amount.
func take_damage(damage: int) -> void:
	if _machine == null or damage <= 0 or not is_inside_tree() or not can_process():
		return
	_machine.take_damage(damage)


## The score the Director awards on [signal defeated], from the Definition; 0 before
## [method spawn_setup].
func get_score() -> int:
	return 0 if _machine == null else _machine.get_score()


func _on_machine_phase_changed(phase_index: int, attack_name: String) -> void:
	if phase_index > 0:
		_play(_phase_cue)
	phase_changed.emit(phase_index, attack_name)


func _on_machine_step_started(step_index: int) -> void:
	_play(_step)
	_show_ring_cue(_definition.phases[_machine.get_phase_index()].attack.steps[step_index])
	var camera := get_viewport().get_camera_3d()
	var center := hit_volume.global_position
	if camera != null and not camera.is_position_in_frustum(center):
		threat_reported.emit(EnemyActor.threat_side(camera.global_transform, center))


## A depleted Phase: its coming ring is cancelled with the hostile fire.
func _on_machine_hostile_clear_requested() -> void:
	_hide_ring_cue()
	_projectile_system.clear_hostile_all()


func _on_machine_defeated(enemy_id: StringName, encounter_id: StringName) -> void:
	remove_from_group(TARGETABLE_GROUP)
	set_physics_process(false)
	defeated.emit(enemy_id, encounter_id)
	if _defeat == &"":
		queue_free()
		return
	animation_player.clear_queue()
	animation_player.play(_defeat)
	# A Tween of this node, so the wait stops while the tree is paused.
	create_tween().tween_callback(queue_free).set_delay(animation_player.get_animation(_defeat).length)


## Plays [param clip] once and returns to the idle clip; an empty (unset or skipped)
## [param clip] plays nothing.
func _play(clip: StringName) -> void:
	if clip == &"":
		return
	animation_player.clear_queue()
	animation_player.play(clip)
	if clip != _idle and _idle != &"":
		animation_player.queue(_idle)


## Turns `VisualRoot` about the boss's up axis toward the player by [param weight] of
## the remaining angle (1.0 snaps). Yaw only: the visual never tilts. A defeated boss,
## which stops physics, stops turning.
func _turn_visual(weight: float) -> void:
	var local_offset := global_transform.basis.inverse() * (_player_position - global_position)
	if is_zero_approx(local_offset.x) and is_zero_approx(local_offset.z):
		return
	var target_yaw := atan2(local_offset.x, local_offset.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, weight)


## The hidden ring cue: a flat [TorusMesh] around the boss's vertical axis, additive,
## unshaded and fog-free so it reads through the storm, casting no shadow.
func _build_ring_cue() -> MeshInstance3D:
	var radius := _hit_radius * RING_CUE_RADIUS_FACTOR
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = RING_CUE_COLOR
	material.disable_fog = true
	var torus := TorusMesh.new()
	torus.inner_radius = radius - RING_CUE_THICKNESS
	torus.outer_radius = radius
	torus.rings = 64
	torus.ring_segments = 8
	torus.material = material
	var cue := MeshInstance3D.new()
	cue.name = "RingCue"
	cue.mesh = torus
	cue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cue.visible = false
	add_child(cue)
	return cue


## Shows the ring cue for [param step] when it is a RING at a fixed height: at
## `Emitters/Main` raised by the step's `height_offset`, where the machine will emit it
## (the Pattern's own per-volley `height_offsets` are not shown), growing to full size
## over the Anticipation and hidden when it ends. A child of this node, so it rides the
## hover with the emission origin. Any other step hides a cue still showing.
func _show_ring_cue(step: AttackStepDefinition) -> void:
	if _ring_cue == null:
		return
	_hide_ring_cue()
	if step.pattern.shape != PatternDefinition.Shape.RING or step.follow_player_height:
		return
	_ring_cue.global_position = emitter.global_position + Vector3.UP * step.height_offset
	_ring_cue.scale = Vector3.ONE * RING_CUE_START_SCALE
	_ring_cue.visible = true
	# A Tween of this node on the physics clock, so it keeps pace with the machine and
	# stops while the tree is paused.
	_ring_cue_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_ring_cue_tween.tween_property(_ring_cue, ^"scale", Vector3.ONE, step.anticipation_seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_ring_cue_tween.tween_callback(_ring_cue.hide)


func _hide_ring_cue() -> void:
	if _ring_cue == null:
		return
	if _ring_cue_tween != null:
		_ring_cue_tween.kill()
	_ring_cue.hide()


## [param clip] when it can be played, otherwise &"" after one warning naming
## [param field].
func _checked_clip(clip: StringName, field: String) -> StringName:
	if clip == &"":
		return &""
	if animation_player == null:
		push_warning("%s: %s '%s' is set but animation_player is not; the cue is skipped" % [get_path(), field, clip])
		return &""
	if not animation_player.has_animation(clip):
		push_warning("%s: %s '%s' is not an animation of %s; the cue is skipped" % [
			get_path(), field, clip, animation_player.get_path(),
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
		definition: BossDefinition, enemy_id: StringName, encounter_id: StringName,
		rng: RandomNumberGenerator, projectile_system: ProjectileSystem, player: Node3D,
		bounds: AABB) -> PackedStringArray:
	var errors: PackedStringArray = []
	if _hit_radius <= 0.0:
		errors.append("the scene failed its own setup check")
	if _machine != null:
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
