class_name Seal
extends Node3D
## Adapter that renders one Stage 2 Seal and registers its exposed hit sphere.

signal seal_destroyed(seal_id: StringName)
signal guards_activated(seal_id: StringName)

const TARGETABLE_GROUP := &"targetable"

@export_group("Seal")
@export var seal_id: StringName = &""
@export var health: int = 10

@export_group("Scene references")
@export var shield_visual: Node3D
@export var core_visual: Node3D
@export var hit_volume: Area3D
@export var approach_volume: Area3D
@export var guard_links: Node3D

var _rules: SealRules
var _projectile_system: ProjectileSystem
var _hit_radius: float = 0.0
var _guard_nodes: Dictionary[StringName, Node3D] = {}
var _setup_complete: bool = false


func _ready() -> void:
	set_physics_process(false)
	_validate_scene()


func _physics_process(_delta: float) -> void:
	if _rules == null or not _rules.is_targetable():
		return
	_projectile_system.register_target(
		get_instance_id(), hit_volume.global_position, _hit_radius, take_damage)


## Builds SealRules from each Guard's relative `guard_spawn` metadata and starts the
## approach listener. The Director calls this after the Seal is in the Stage tree.
func setup(projectile_system: ProjectileSystem, encounter_id: StringName) -> void:
	if not _validate_scene() or projectile_system == null or encounter_id.is_empty():
		if projectile_system == null:
			push_error("%s: setup requires a ProjectileSystem" % get_path())
		if encounter_id.is_empty():
			push_error("%s: setup requires an encounter_id" % get_path())
		return
	if _setup_complete:
		push_error("%s: setup called more than once" % get_path())
		return
	var guard_ids: Array[StringName] = []
	_guard_nodes.clear()
	for child: Node in guard_links.get_children():
		var spawn_variant: Variant = child.get_meta("guard_spawn", NodePath())
		if not spawn_variant is NodePath:
			push_error("%s: %s needs NodePath metadata 'guard_spawn'" % [get_path(), child.name])
			return
		var guard_spawn: NodePath = spawn_variant
		if guard_spawn.is_empty():
			push_error("%s: %s has empty 'guard_spawn' metadata" % [get_path(), child.name])
			return
		var guard_id: StringName = EncounterMachine.enemy_id(encounter_id, guard_spawn)
		guard_ids.append(guard_id)
		var guard_node: Node3D = child as Node3D
		if guard_node != null:
			_guard_nodes[guard_id] = guard_node
	if guard_ids.is_empty():
		push_error("%s: guard_links has no Guard children" % get_path())
		return
	_projectile_system = projectile_system
	_rules = SealRules.new()
	_rules.setup(seal_id, guard_ids, health)
	_rules.guards_activated.connect(_on_guards_activated)
	_rules.guard_link_cleared.connect(_on_guard_link_cleared)
	_rules.shield_dropped.connect(_on_shield_dropped)
	_rules.destroyed.connect(_on_destroyed)
	if not approach_volume.body_entered.is_connected(_on_approach_body_entered):
		approach_volume.body_entered.connect(_on_approach_body_entered)
	approach_volume.monitoring = true
	_setup_complete = true
	_apply_visuals()


## Reports that a linked Guard was shot; only the Director should call this.
func notify_guard_shot(enemy_id: StringName) -> bool:
	return false if _rules == null else _rules.notify_guard_shot(enemy_id)


## Reports that a linked Guard was defeated; only the Director should call this.
func notify_guard_defeated(enemy_id: StringName) -> bool:
	return false if _rules == null else _rules.notify_guard_defeated(enemy_id)


## The ProjectileSystem callback for player fire and Bomb damage.
func take_damage(damage: int) -> void:
	if _rules == null or damage <= 0 or not is_inside_tree() or not can_process():
		return
	_rules.take_damage(damage)


## Captures the rules state for Retry.
func capture() -> Dictionary:
	return {} if _rules == null else _rules.capture()


## Restores rules and reapplies every Seal and Guard visual without emitting signals.
func restore(data: Dictionary) -> void:
	if _rules == null:
		return
	_rules.restore(data)
	_apply_visuals()


func _on_approach_body_entered(body: Node3D) -> void:
	if body is PlayerController and _rules != null:
		_rules.notify_approached()


func _on_guards_activated(activated_id: StringName) -> void:
	guards_activated.emit(activated_id)


func _on_guard_link_cleared(enemy_id: StringName) -> void:
	var guard_node: Node3D = _guard_nodes.get(enemy_id)
	if guard_node != null:
		guard_node.visible = false


func _on_shield_dropped(_dropped_id: StringName) -> void:
	_apply_visuals()


func _on_destroyed(destroyed_id: StringName) -> void:
	_apply_visuals()
	seal_destroyed.emit(destroyed_id)


func _apply_visuals() -> void:
	if _rules == null:
		return
	var state: Dictionary = _rules.capture()
	var defeated_guards: PackedStringArray = state["defeated_guards"]
	shield_visual.visible = _rules.is_shielded()
	core_visual.visible = _rules.get_state() != SealRules.State.DESTROYED
	for guard_id: StringName in _guard_nodes:
		var guard_node: Node3D = _guard_nodes[guard_id]
		guard_node.visible = not defeated_guards.has(String(guard_id))
	if _rules.is_targetable():
		add_to_group(TARGETABLE_GROUP)
	else:
		remove_from_group(TARGETABLE_GROUP)
	set_physics_process(_rules.is_targetable())


func _validate_scene() -> bool:
	var valid: bool = true
	var missing: Array[String] = []
	if seal_id.is_empty():
		missing.append("seal_id")
	if health <= 0:
		missing.append("health must be positive")
	if shield_visual == null:
		missing.append("shield_visual")
	if core_visual == null:
		missing.append("core_visual")
	if hit_volume == null:
		missing.append("hit_volume")
	if approach_volume == null:
		missing.append("approach_volume")
	if guard_links == null:
		missing.append("guard_links")
	for field: String in missing:
		push_error("%s: required export '%s' is not set" % [get_path(), field])
		valid = false
	if hit_volume != null:
		_hit_radius = _sphere_radius(hit_volume)
		if _hit_radius <= 0.0:
			push_error("%s: hit_volume needs a positive SphereShape3D" % get_path())
			valid = false
	return valid


func _sphere_radius(area: Area3D) -> float:
	for child: Node in area.get_children():
		var shape_node: CollisionShape3D = child as CollisionShape3D
		if shape_node != null:
			var sphere: SphereShape3D = shape_node.shape as SphereShape3D
			return 0.0 if sphere == null else sphere.radius
	return 0.0
