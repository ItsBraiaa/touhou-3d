class_name BombBlast
extends Node3D
## Dev only: the Bomb's blast visual, a translucent unshaded sphere of the Bomb's radius
## that fades out over [constant FADE_SECONDS] and frees itself. It has no collision and
## decides nothing: the Session clears and damages before it appears. It pauses with the
## tree, under `WorldRoot`. The final effect is D-02's; it must keep later attacks readable
## (PLANEJAMENTO Section 4 "Spiritual bomb").


## Seconds from full to invisible.
const FADE_SECONDS := 0.4

## The sphere, a mesh of radius 1 scaled to the Bomb radius. Required.
@export var sphere: MeshInstance3D

var _material: StandardMaterial3D
var _start_alpha: float = 0.0
var _elapsed: float = 0.0


func _ready() -> void:
	var source: StandardMaterial3D = null
	if sphere != null and sphere.mesh != null:
		source = sphere.mesh.surface_get_material(0) as StandardMaterial3D
	if source == null:
		push_error("%s: 'sphere' needs a mesh with a StandardMaterial3D" % get_path())
		set_process(false)
		queue_free()
		return
	# Its own copy, so two blasts fade independently.
	_material = source.duplicate() as StandardMaterial3D
	sphere.material_override = _material
	_start_alpha = _material.albedo_color.a


func _process(delta: float) -> void:
	_elapsed += delta
	var remaining := 1.0 - _elapsed / FADE_SECONDS
	if remaining <= 0.0:
		queue_free()
		return
	_material.albedo_color.a = _start_alpha * remaining


## Scales the unit sphere to [param radius], the Bomb radius in world units.
func setup(radius: float) -> void:
	scale = Vector3.ONE * radius
