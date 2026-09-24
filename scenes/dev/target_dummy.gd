class_name TargetDummy
extends Node3D
## Dev only: a lockable target that registers its `HitVolume` sphere with a
## [ProjectileSystem] every physics tick, counts the player shots that reach it and
## flashes for each. It never dies. Stands in for enemies in the arena harness before F9
## exists; never in `scenes/main.tscn`.


## Seconds a hit keeps the flash on.
const FLASH_SECONDS := 0.1
## Emission energy while flashing.
const FLASH_ENERGY := 4.0

## The sphere shots are swept against: an [Area3D] on layer 5 with monitoring off and a
## [SphereShape3D] child. Required.
@export var hit_volume: Area3D
## The mesh that flashes. Its first surface material is copied, so dummies flash alone.
## Required.
@export var visual: MeshInstance3D

## Player shots that reached this dummy.
var hit_count: int = 0
## The damage those shots carried.
var damage_taken: int = 0

var _projectile_system: ProjectileSystem
var _radius: float = 0.0
var _material: StandardMaterial3D
var _rest_energy: float = 0.0
var _flash_left: float = 0.0


func _ready() -> void:
	if not _validate_setup():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_material = (visual.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	visual.material_override = _material
	_rest_energy = _material.emission_energy_multiplier


func _physics_process(_delta: float) -> void:
	if _projectile_system != null:
		_projectile_system.register_target(get_instance_id(), hit_volume.global_position, _radius, _on_damage)


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0:
		_material.emission_energy_multiplier = _rest_energy


## Starts registering with [param projectile_system] from the next physics tick.
func setup(projectile_system: ProjectileSystem) -> void:
	_projectile_system = projectile_system


func _on_damage(damage: int) -> void:
	hit_count += 1
	damage_taken += damage
	_flash_left = FLASH_SECONDS
	_material.emission_energy_multiplier = FLASH_ENERGY


## Reports what is missing with this node's path (CONVENTIONS "Setup errors are loud").
func _validate_setup() -> bool:
	if hit_volume == null or visual == null:
		push_error("%s: required exports 'hit_volume' and 'visual' must be set" % get_path())
		return false
	for child: Node in hit_volume.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node != null and shape_node.shape is SphereShape3D:
			_radius = (shape_node.shape as SphereShape3D).radius
	if _radius <= 0.0:
		push_error("%s: %s needs a CollisionShape3D child with a SphereShape3D" % [get_path(), hit_volume.get_path()])
		return false
	if visual.mesh == null or not visual.mesh.surface_get_material(0) is StandardMaterial3D:
		push_error("%s: %s needs a StandardMaterial3D on its mesh to flash" % [get_path(), visual.get_path()])
		return false
	return true
