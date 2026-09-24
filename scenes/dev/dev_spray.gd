class_name DevSpray
extends Node3D
## Dev only: sprays horizontal rings of hostile Projectiles from this node's position on
## a timer, through [member projectile_system], with no pattern core behind it. Stands in
## for enemy fire in the arena harness before any enemy exists (F6-02); never in
## `scenes/main.tscn`.


## The system the rings are spawned into. Required.
@export var projectile_system: ProjectileSystem
## Seconds between rings. 0 stops the timer; [method spawn_ring] still works.
@export var interval: float = 1.5
## Projectiles per ring, evenly spread around the vertical axis.
@export var ring_size: int = 24
## Speed of each Projectile, in units per second.
@export var speed: float = 6.0
## Seconds each Projectile lives if no wall stops it first.
@export var lifetime: float = 10.0

var _elapsed: float = 0.0
var _request := ProjectileSpawn.new()
## Rotates each ring by half a gap, so consecutive rings do not overlap.
var _ring_index: int = 0


func _ready() -> void:
	if projectile_system == null:
		push_error("%s: required export 'projectile_system' is not set" % get_path())
		process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	if interval <= 0.0:
		return
	_elapsed += delta
	if _elapsed >= interval:
		_elapsed -= interval
		spawn_ring()


## Spawns one ring now and returns how many Projectiles the field accepted.
func spawn_ring() -> int:
	var accepted := 0
	var offset := PI / ring_size * (_ring_index % 2)
	_ring_index += 1
	_request.position = global_position
	_request.faction = ProjectileSpawn.Faction.HOSTILE
	_request.lifetime = lifetime
	for index: int in ring_size:
		var angle := TAU * index / ring_size + offset
		_request.velocity = Vector3(cos(angle), 0.0, sin(angle)) * speed
		if projectile_system.spawn(_request) != ProjectileField.NO_PROJECTILE:
			accepted += 1
	return accepted
