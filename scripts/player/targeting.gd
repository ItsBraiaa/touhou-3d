class_name Targeting
extends Node
## Adapter for Target Lock: describes every `targetable` node to [TargetSelector] each
## physics tick, drives it with the `lock_target` and `next_target` actions, and reports
## the locked node through [signal target_changed].
##
## It owns no selection rule. Which target a press picks, where `next_target` steps to,
## when a held lock is invalidated and which target takes over from a defeated one all come
## from the core (ADR-0001); this script is the part that needs the scene: the group, the
## camera projection, the occlusion ray and the locked target's defeat.
##
## A target is a [Node3D] in [member group_name] with a `HitVolume` child (GUIDE Section
## 13). Its id is its instance id, resolved back with [method @GlobalScope.instance_from_id],
## so a target freed between two ticks reads as null instead of a dangling reference.
## Distance is measured from this node's parent, the ship; screen position and occlusion
## from [member camera].
##
## Since F16-11 it also watches the locked target, and only that one, for its
## [constant DEFEATED_SIGNAL]. When a lock is lost because its target was defeated, the
## lock hands off to [method TargetSelector.select_successor]'s choice instead of being
## released, or, with none left, is released with [signal lock_lost_to_defeat].


## Emitted when the lock changes: [param target] is the newly locked node, or null when
## the lock was released by the player, by range, because the target disappeared, or
## because it was defeated with no target left to take the lock. A defeat that hands the
## lock off emits once, with the successor. The ship connects it to
## [method CameraRig.set_lock_target]; the HUD and the weapon follow.
signal target_changed(target: Node3D)

## The locked target was defeated and no other target could take the lock (F16-11).
## Emitted right after [signal target_changed] reported null, in the same tick. The ship
## answers it with [method CameraRig.request_recenter] while it has its controls, so the
## camera returns to the authored follow view rather than staying turned toward the defeat. Never emitted for a
## release by the player, by range, or by a target that disappeared without a defeat, nor
## for a boss whose `Death` clip is playing.
signal lock_lost_to_defeat

## Child every target must have: the point screen position, distance and the occlusion
## ray are measured to.
const HIT_VOLUME_PATH := ^"HitVolume"
## Signal a target reports its defeat with, as `defeated(enemy_id: StringName,
## encounter_id: StringName)`: [EnemyActor] and [BossController] have it and emit it after
## leaving the group, then stay in the tree while their `Death` clip plays. A target
## without it, such as a [Seal], is never handed off.
const DEFEATED_SIGNAL := &"defeated"

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
## False from the moment the ship gets its controls (it enters play, or a Resume gives them
## back) until a tick after it with both targeting actions released (F16-09). The press that
## resumed play can share its input with a lock or a switch: either action remapped to B
## resumes from Pause as `ui_cancel`, on the press, and `Input.is_action_just_pressed` still
## reports that press on the first tick the ship runs, so it must not lock or switch.
var _input_armed: bool = false
## Instance id of the locked target whose [constant DEFEATED_SIGNAL] is connected, or
## [constant TargetSelector.NO_TARGET]. It moves with the lock, so no other target's defeat
## is ever heard, and a release or a switch stops listening at once.
var _watched_id: int = TargetSelector.NO_TARGET
## Instance id of the locked target that reported its defeat, or
## [constant TargetSelector.NO_TARGET]. Recorded by the signal and spent by the next tick
## that finds the lock invalid: every kill (the weapon's Bomb at physics priority 50, the
## field's hits at 100) lands after this node's own tick (priority 0), and the handoff
## needs that tick's candidates. Every lock change forgets it.
var _defeated_id: int = TargetSelector.NO_TARGET


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
	if not _input_armed:
		_input_armed = not Input.is_action_pressed(&"lock_target") and not Input.is_action_pressed(&"next_target")
		lock_pressed = false
		next_pressed = false
	var current := _selector.get_current_id()
	# Nothing is locked and nothing was asked for: no rays to cast this tick.
	if current == TargetSelector.NO_TARGET and not lock_pressed and not next_pressed:
		return
	var candidates := build_candidates()
	if current != TargetSelector.NO_TARGET and not _selector.validate(candidates, current):
		# A lock lost to its target's defeat hands off, unless a press this tick asks for
		# something else: then it is released and the press acts, as for any other loss.
		if current == _defeated_id and not lock_pressed and not next_pressed:
			_hand_off(candidates)
			return
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
	return _node_of(_selector.get_current_id()) as Node3D


## Disarms the targeting actions until both are released, called by the ship's owner when
## the controls come back. The press that resumed play, or started the stage, is then not
## read as a lock or a switch (F16-09).
func require_release() -> void:
	_input_armed = false


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


## Moves the lock off a defeated target, to [method TargetSelector.select_successor]'s
## choice, which emits [signal target_changed] once; with none, the lock is released the
## same way and [signal lock_lost_to_defeat] follows, except for a [BossController] still
## in the tree: it stays only while its `Death` clip plays, and the camera keeps its view
## of that clip instead of turning away (the user's call).
func _hand_off(candidates: Array[TargetSelector.Candidate]) -> void:
	var defeated := _node_of(_selector.get_current_id())
	var successor := _selector.select_successor(candidates)
	_selector.set_current(successor)
	if successor == TargetSelector.NO_TARGET and not (defeated is BossController):
		lock_lost_to_defeat.emit()


## Listens for [param id]'s defeat instead of the previous lock's, and forgets a defeat the
## previous lock reported. A target freed since, or one without [constant DEFEATED_SIGNAL],
## has nothing to connect or disconnect.
func _watch(id: int) -> void:
	_defeated_id = TargetSelector.NO_TARGET
	var previous := _node_of(_watched_id)
	if previous != null and previous.is_connected(DEFEATED_SIGNAL, _on_watched_target_defeated):
		previous.disconnect(DEFEATED_SIGNAL, _on_watched_target_defeated)
	_watched_id = TargetSelector.NO_TARGET
	var target := _node_of(id)
	if target != null and target.has_signal(DEFEATED_SIGNAL):
		target.connect(DEFEATED_SIGNAL, _on_watched_target_defeated)
		_watched_id = id


## The live node with instance id [param id], or null for [constant TargetSelector.NO_TARGET]
## and for a node already freed.
func _node_of(id: int) -> Node:
	if id == TargetSelector.NO_TARGET:
		return null
	return instance_from_id(id) as Node


func _on_selector_target_changed(id: int) -> void:
	_watch(id)
	target_changed.emit(get_current_target())


## Only the locked target is connected, so this is always the lock's defeat. The handoff
## waits for the next tick, which will find the lock invalid: the target left the group
## before it emitted this.
func _on_watched_target_defeated(_enemy_id: StringName, _encounter_id: StringName) -> void:
	_defeated_id = _watched_id


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
