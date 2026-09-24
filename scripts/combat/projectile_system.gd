class_name ProjectileSystem
extends Node3D
## Adapter on `Main/ProjectileRoot` that puts the [ProjectileField] in the running game
## (ADR-0004): it ticks the field every physics step after the actors have moved and
## registered, answers the field's obstacle query with a layer-1 ray, sweeps the ship's
## authored Core and Graze spheres, calls back the targets that registered a hit sphere,
## and draws both factions with one [MultiMeshInstance3D] each.
##
## The Session calls [method setup] on every stage load and [method clear_all] on every
## unload. `ProjectileRoot` is PAUSABLE, so a paused tree freezes every Projectile with no
## code here. What a hit or a Graze does to [CombatState] or [RunState] is F7's: this
## adapter only re-emits the field's [signal player_hit] and [signal grazed].


## A hostile Projectile met the ship's Core while it was not invulnerable, and was
## removed. [param damage] is the Projectile's damage (F7-01 calls
## [method CombatState.take_hit] with it).
signal player_hit(projectile_id: int, damage: int)
## A hostile Projectile passed through the Graze Volume without touching the Core, for
## the first time in its life, while the player was not invulnerable.
signal grazed(projectile_id: int)

## Higher than every actor's default 0, so enemies register their hit spheres and the
## ship moves before this tick reads them.
const TICK_PRIORITY := 100
## Floats per instance in a 3D [MultiMesh] buffer: a 3 × 4 row-major transform.
const FLOATS_PER_INSTANCE := 12
## Flight Volume until the first [method setup]; the field refuses an empty one.
const IDLE_BOUNDS := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)

@export_group("Field")
## Projectiles alive at once, both factions together. A full field refuses new spawns
## (warned once per stage). Claude's proposal from the folded F6-01 measurement.
@export_range(1, 65536) var capacity: int = 2048
## World units added around the Flight Volume before a Projectile is culled, so a
## Projectile leaving the playable space is still seen for a moment.
@export var cull_margin: float = 5.0
## Layers that stop Projectiles: scenery, Flight Volume walls and closed Gate barriers
## (CONVENTIONS "Collision"). Bodies only; areas never block.
@export_flags_3d_physics var obstacle_mask: int = 1

@export_group("Visuals")
## Mesh of radius 1 for player Projectiles, scaled by each Projectile's radius. Required.
@export var player_projectile_mesh: Mesh
## Mesh of radius 1 for hostile Projectiles, scaled by each Projectile's radius. Required.
@export var hostile_projectile_mesh: Mesh

var _field := ProjectileField.new()
## Renderer per [enum ProjectileSpawn.Faction], and the buffer written into each.
var _renderers: Array[MultiMeshInstance3D] = []
var _buffers: Array[PackedFloat32Array] = []
## Instances drawn per faction at the last refresh, so an empty faction is not rewritten.
var _drawn: PackedInt32Array = PackedInt32Array([0, 0])
## The ship of the stage in play, or null.
var _player: PlayerController
var _core_radius: float = 0.0
var _graze_radius: float = 0.0
## False when the ship's Core or Graze shape is unusable: the field then sweeps nothing.
var _sweep_enabled: bool = false
var _previous_center := Vector3.ZERO
var _player_invulnerable: bool = false
## Damage callbacks by target id, for the hit spheres registered for the coming tick.
var _callbacks: Dictionary[int, Callable] = {}
## The callbacks of the tick in progress. Swapped out before the tick, so a sphere a
## listener registers during the tick's events keeps its callback for the next one.
var _tick_callbacks: Dictionary[int, Callable] = {}
## Whether this stage's first refused spawn has been reported.
var _refusal_reported: bool = false
## Reused for every obstacle ray; the space is read at the start of each tick.
var _ray := PhysicsRayQueryParameters3D.new()
var _space: PhysicsDirectSpaceState3D


func _ready() -> void:
	if not _validate_exports():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	process_physics_priority = TICK_PRIORITY
	# Read once: [member obstacle_mask] changed after _ready has no effect.
	_ray.collision_mask = obstacle_mask
	_ray.collide_with_bodies = true
	_ray.collide_with_areas = false
	# A Projectile that starts inside scenery dies there instead of flying out of it.
	_ray.hit_from_inside = true
	_field.setup(capacity, IDLE_BOUNDS, _is_blocked)
	_field.player_hit.connect(_on_field_player_hit)
	_field.grazed.connect(_on_field_grazed)
	_field.enemy_hit.connect(_on_field_enemy_hit)
	for mesh: Mesh in [player_projectile_mesh, hostile_projectile_mesh]:
		_renderers.append(_make_renderer(mesh))
		var buffer := PackedFloat32Array()
		buffer.resize(capacity * FLOATS_PER_INSTANCE)
		_buffers.append(buffer)


func _physics_process(delta: float) -> void:
	if _sweep_enabled and _has_player():
		var center := _player.damage_core.global_position
		_field.set_player(_previous_center, center, _core_radius, _graze_radius, _player_invulnerable)
		_previous_center = center
	else:
		_field.clear_player()
	_space = get_world_3d().direct_space_state
	_tick_callbacks = _callbacks
	_callbacks = {}
	_field.tick(delta)
	_tick_callbacks = {}
	_refresh_renderer(ProjectileSpawn.Faction.PLAYER)
	_refresh_renderer(ProjectileSpawn.Faction.HOSTILE)


## Prepares the field for a new stage: [param bounds] is its Flight Volume (a position and
## a size), grown by [member cull_margin]; [param player] is the new ship, whose
## `DamageCore` and `GrazeVolume` sphere shapes are the Core and Graze sizes. Removes
## every Projectile. A missing or non-sphere shape is reported and disables the sweep.
## Node scale is ignored: the shapes' own radii are used.
func setup(bounds: AABB, player: PlayerController) -> void:
	var grown := bounds.grow(cull_margin)
	# A new setup also restarts the refusal count; the arrays keep their size.
	_field.setup(capacity, grown, _is_blocked)
	for renderer: MultiMeshInstance3D in _renderers:
		renderer.multimesh.custom_aabb = grown
	_player = player
	_player_invulnerable = false
	_core_radius = _sphere_radius(player.damage_core)
	_graze_radius = _sphere_radius(player.graze_volume)
	_sweep_enabled = _core_radius > 0.0 and _graze_radius >= _core_radius
	if not _sweep_enabled:
		push_error("%s: the ship %s needs a SphereShape3D under its DamageCore and its GrazeVolume, the Core no larger than the Graze; it cannot be hit or graze" % [
			get_path(), player.get_path(),
		])
	_refusal_reported = false
	clear_all()


## Spawns a Projectile from [param request] and returns its id, or
## [constant ProjectileField.NO_PROJECTILE] when the field is full. The first refusal of
## a stage is reported once.
func spawn(request: ProjectileSpawn) -> int:
	var id := _field.spawn(request)
	if id == ProjectileField.NO_PROJECTILE and not _refusal_reported:
		_refusal_reported = true
		push_warning("%s: the field is full (%d Projectiles); %d spawn(s) refused so far this stage" % [
			get_path(), capacity, _field.get_refused_count(),
		])
	return id


## Removes every hostile Projectile within [param radius] of [param center] (a Bomb),
## awarding nothing, and returns how many.
func clear_hostile_in_radius(center: Vector3, radius: float) -> int:
	return _field.clear_hostile_in_radius(center, radius)


## Removes every hostile Projectile (a Gate opening, a Checkpoint, a boss Phase),
## awarding nothing, and returns how many.
func clear_hostile_all() -> int:
	return _field.clear_hostile_all()


## Ids of the targets registered for the coming tick whose sphere overlaps
## [param radius] around [param center], in registration order.
func targets_in_radius(center: Vector3, radius: float) -> PackedInt64Array:
	return _field.targets_in_radius(center, radius)


## Deals [param damage] once to every target registered for the coming tick whose sphere
## overlaps [param radius] around [param center] (a Bomb), through its `on_damage`, and
## returns how many were damaged. The field keeps one sphere per id, so a target registered
## twice is damaged once; one that stopped registering is not damaged. Call it after the actors have registered this
## tick: from a physics step whose priority is above theirs, as [PlayerWeapon]'s is.
func damage_targets_in_radius(center: Vector3, radius: float, damage: int) -> int:
	var damaged := 0
	for target_id: int in _field.targets_in_radius(center, radius):
		var on_damage: Callable = _callbacks.get(target_id, Callable())
		if on_damage.is_valid():
			on_damage.call(damage)
			damaged += 1
	return damaged


## Alive Projectiles of [param faction].
func count(faction: ProjectileSpawn.Faction) -> int:
	return _field.count(faction)


## Registers a hit sphere for the coming tick only: an actor calls it every physics tick
## with its `get_instance_id()`, its `HitVolume` center and radius. [param on_damage] is
## `func(damage: int) -> void`, called when a player Projectile hits that sphere.
func register_target(target_id: int, center: Vector3, radius: float, on_damage: Callable) -> void:
	_field.register_target(target_id, center, radius)
	_callbacks[target_id] = on_damage


## Whether the ship is invulnerable: a Core contact then passes through and no Graze is
## awarded. F7-01 mirrors [method CombatState.is_invulnerable] here.
func set_player_invulnerable(active: bool) -> void:
	_player_invulnerable = active


## Removes every Projectile of both factions and every registration, awarding nothing.
## The next sweep starts from the ship's current position, so a teleport (Retry,
## Restart) never sweeps across the stage.
func clear_all() -> void:
	_field.clear_all()
	_callbacks.clear()
	_tick_callbacks.clear()
	if _sweep_enabled and _has_player():
		_previous_center = _player.damage_core.global_position
	_refresh_renderer(ProjectileSpawn.Faction.PLAYER)
	_refresh_renderer(ProjectileSpawn.Faction.HOSTILE)


## The field, for tests and dev tools only.
func get_field() -> ProjectileField:
	return _field


## Whether the ship of [method setup] is still in play. The Session takes it out of the
## tree before freeing it, and a physics tick may fall in between.
func _has_player() -> bool:
	return is_instance_valid(_player) and _player.is_inside_tree()


## True when layer-[member obstacle_mask] bodies block the segment. Only called during
## [method ProjectileField.tick], inside this node's physics step.
func _is_blocked(from: Vector3, to: Vector3) -> bool:
	_ray.from = from
	_ray.to = to
	return not _space.intersect_ray(_ray).is_empty()


func _make_renderer(mesh: Mesh) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0
	var renderer := MultiMeshInstance3D.new()
	renderer.multimesh = multimesh
	# Bullets are small, bright and numerous: shadows would cost more than they show.
	renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(renderer)
	return renderer


## Writes one faction's alive Projectiles into its renderer: each instance is the unit
## mesh scaled by the Projectile's radius at its position. This node stays at the origin,
## so field positions are the renderer's local positions.
func _refresh_renderer(faction: ProjectileSpawn.Faction) -> void:
	var alive := _field.count(faction)
	if alive == 0 and _drawn[faction] == 0:
		return
	var multimesh := _renderers[faction].multimesh
	if alive > 0:
		var positions := _field.get_positions(faction)
		var radii := _field.get_radii(faction)
		var buffer := _buffers[faction]
		for index: int in alive:
			var base := index * FLOATS_PER_INSTANCE
			var point := positions[index]
			var radius := radii[index]
			buffer[base] = radius
			buffer[base + 3] = point.x
			buffer[base + 5] = radius
			buffer[base + 7] = point.y
			buffer[base + 10] = radius
			buffer[base + 11] = point.z
		multimesh.buffer = buffer
	multimesh.visible_instance_count = alive
	_drawn[faction] = alive


## Radius of the first [CollisionShape3D] child's [SphereShape3D] of [param volume], or 0
## when there is none.
static func _sphere_radius(volume: Node) -> float:
	if volume == null:
		return 0.0
	for child: Node in volume.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node != null:
			var sphere := shape_node.shape as SphereShape3D
			return sphere.radius if sphere != null else 0.0
	return 0.0


func _on_field_player_hit(projectile_id: int, damage: int) -> void:
	player_hit.emit(projectile_id, damage)


func _on_field_grazed(projectile_id: int) -> void:
	grazed.emit(projectile_id)


func _on_field_enemy_hit(target_id: int, _projectile_id: int, damage: int) -> void:
	var on_damage: Callable = _tick_callbacks.get(target_id, Callable())
	if on_damage.is_valid():
		on_damage.call(damage)


## Reports every unset export with this node's path (CONVENTIONS "Setup errors are loud").
func _validate_exports() -> bool:
	var missing: PackedStringArray = []
	if player_projectile_mesh == null:
		missing.append("player_projectile_mesh")
	if hostile_projectile_mesh == null:
		missing.append("hostile_projectile_mesh")
	for field: String in missing:
		push_error("%s: required export '%s' is not set" % [get_path(), field])
	return missing.is_empty()
