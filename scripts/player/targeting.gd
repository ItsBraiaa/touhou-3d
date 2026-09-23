class_name Targeting
extends Node
## Adapter for Target Lock: describes every `targetable` node to [TargetSelector] each
## physics tick, drives it with the `lock_target` and `next_target` actions, and reports
## the locked node through [signal target_changed].
##
## It owns no selection rule. Which target a press picks, where `next_target` steps to and
## when a held lock is invalidated all come from the core (ADR-0001); this script is the
## part that needs the scene: the group, the camera projection and the occlusion ray.
##
## A target is a [Node3D] in [member group_name] with a `HitVolume` child (GUIDE Section
## 13). Its id is its instance id, resolved back with [method @GlobalScope.instance_from_id],
## so a target freed between two ticks reads as null instead of a dangling reference.
## Distance is measured from this node's parent, the ship; screen position and occlusion
## from [member camera].


## Emitted when the lock changes: [param target] is the newly locked node, or null when
## the lock was released by the player, by range, or because the target disappeared. The
## ship connects it to [method CameraRig.set_lock_target]; the HUD and the weapon follow.
signal target_changed(target: Node3D)

## Child every target must have: the point screen position, distance and the occlusion
## ray are measured to.
const HIT_VOLUME_PATH := ^"HitVolume"

@export_group("Scene references")
## Camera the screen position and the occlusion ray are measured from. Required; the
## ship's own `CameraRig/Camera3D`.
@export var camera: Camera3D

@export_group("Selection")
## Farthest a target may be from the ship, in world units, to be acquired or kept.
@export var max_distance: float = 60.0
## How far from the screen center a target may be to be acquired, in the per-axis
## normalized units of [member TargetSelector.Candidate.screen_offset]: 1.0 reaches the
## screen edges, 0.85 keeps acquisition off the outer margin. A held lock ignores it.
@export var max_screen_radius: float = 0.85
## Layers that hide a target. Layer 1 is scenery and closed Gate barriers (CONVENTIONS
## "Collision"); a target's own volumes must not be on it, or it would hide itself.
@export_flags_3d_physics var occlusion_mask: int = 1
## Group the targets are in.
@export var group_name: StringName = &"targetable"

var _selector: TargetSelector
## The ship: this node's parent, resolved once in [method _ready].
var _ship: Node3D
## Instance ids of group members already reported for lacking a `HitVolume`, so each is
## reported once and not every tick.
var _reported_ids: Dictionary[int, bool] = {}


func _ready() -> void:
	_ship = get_parent() as Node3D
	_selector = TargetSelector.new()
	_selector.configure(max_distance, max_screen_radius)
	_selector.target_changed.connect(_on_selector_target_changed)
	if not _validate_setup():
		process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(_delta: float) -> void:
	var lock_pressed := Input.is_action_just_pressed(&"lock_target")
	var next_pressed := Input.is_action_just_pressed(&"next_target")
	var current := _selector.get_current_id()
	# Nothing is locked and nothing was asked for: no rays to cast this tick.
	if current == TargetSelector.NO_TARGET and not lock_pressed and not next_pressed:
		return
	var candidates := build_candidates()
	if current != TargetSelector.NO_TARGET and not _selector.validate(candidates, current):
		_selector.set_current(TargetSelector.NO_TARGET)
		current = TargetSelector.NO_TARGET
	if lock_pressed:
		# A toggle: acquire when free, release when locked.
		if current == TargetSelector.NO_TARGET:
			_selector.set_current(_selector.select_best(candidates))
		else:
			_selector.set_current(TargetSelector.NO_TARGET)
	elif next_pressed:
		var next := _selector.select_next(candidates, current)
		# A switch with nowhere to go keeps the lock it has.
		if next != TargetSelector.NO_TARGET:
			_selector.set_current(next)


## The locked target, or null. A target freed since the last tick is already null here,
## one tick before [signal target_changed] reports the release.
func get_current_target() -> Node3D:
	var id := _selector.get_current_id()
	if id == TargetSelector.NO_TARGET:
		return null
	return instance_from_id(id) as Node3D


## Describes every node in [member group_name] as the camera sees it now: one
## [TargetSelector.Candidate] per target with a `HitVolume`, in group order. Casts one
## ray per target in front of the camera, so it is only valid during a physics step.
func build_candidates() -> Array[TargetSelector.Candidate]:
	var candidates: Array[TargetSelector.Candidate] = []
	var space := camera.get_world_3d().direct_space_state
	var eye := camera.global_position
	var half_size := camera.get_viewport().get_visible_rect().size * 0.5
	for node: Node in get_tree().get_nodes_in_group(group_name):
		var hit_volume := _hit_volume_of(node)
		if hit_volume == null:
			continue
		var point := hit_volume.global_position
		var screen_offset := (camera.unproject_position(point) - half_size) / half_size
		var visible := not camera.is_position_behind(point) and _is_clear(space, eye, point)
		var distance := _ship.global_position.distance_to(point)
		candidates.append(TargetSelector.Candidate.new(node.get_instance_id(), screen_offset, distance, visible))
	return candidates


## The `HitVolume` of a group member, or null for a member that is not a [Node3D] or has
## none, which is reported once and then skipped silently.
func _hit_volume_of(node: Node) -> Node3D:
	var hit_volume := node.get_node_or_null(HIT_VOLUME_PATH) as Node3D
	if node is Node3D and hit_volume != null:
		return hit_volume
	var id := node.get_instance_id()
	if not _reported_ids.has(id):
		_reported_ids[id] = true
		push_warning("%s: %s is in group '%s' but is not a Node3D with a HitVolume child; it cannot be targeted" % [
			get_path(), node.get_path(), group_name,
		])
	return null


func _is_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, occlusion_mask)
	return space.intersect_ray(query).is_empty()


func _on_selector_target_changed(_id: int) -> void:
	target_changed.emit(get_current_target())


## Reports what is missing with this node's path (CONVENTIONS "Setup errors are loud")
## and returns whether the adapter may run at all.
func _validate_setup() -> bool:
	var configured := true
	if camera == null:
		push_error("%s: required export 'camera' is not set" % get_path())
		configured = false
	if _ship == null:
		push_error("%s: Targeting must be a child of the Node3D ship it measures distance from" % get_path())
		configured = false
	return configured
