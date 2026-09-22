class_name CameraRig
extends Node3D
## Adapter for the third-person camera: follows the ship from behind with a level
## horizon, orbits with the `camera_*` actions, frames the ship together with a Target
## Lock, and shortens against scenery.
##
## The rig is `top_level`, so the body's own transform never reaches the camera: every
## physics tick it places itself at the follow target's position with a basis that is a
## pure yaw rotation, and the camera is placed from that yaw and a pitch. Nothing here
## ever writes a roll, which is what keeps the horizon stable (PLANEJAMENTO Section 3).
##
## The yaw lives in this node's own Y rotation, which is the contract GUIDE Section 6
## records: [method get_yaw] returns it, [PlayerController] rotates its camera-relative
## input by it, and anything that turns this node — a test, a future respawn — turns the
## ship's sense of forward with it. The pitch is private, because nothing outside reads it.
##
## There is no Rules Core: every rule here is a question about the scene (where the ship
## is, where the target is, what the ray hit), which ADR-0001 keeps out of a core.


@export_group("Scene references")
## The camera this rig places. Required; its `current` flag is left as authored.
@export var camera: Camera3D

@export_group("Framing")
## Distance behind the ship the camera rests at, before the pitch rotates the offset.
@export var follow_distance: float = 8.5
## Height above the ship the camera rests at, before the pitch rotates the offset.
@export var follow_height: float = 3.2
## Pitch the rig starts at. Negative lifts the camera and looks down, which is the
## authored rest pose of GUIDE Section 13 (-0.16 rad).
@export var default_pitch_degrees: float = -9.0
## Lowest and highest pitch, in degrees. `x` looks down from above the ship, `y` looks
## up from below it; the framing angle between the view and the ship is the same at
## both ends, because the offset and the view rotate together.
@export var pitch_limits_degrees: Vector2 = Vector2(-60.0, 35.0)

@export_group("Orbit")
## Turn rate of the `camera_*` actions at full deflection, in degrees per second.
@export var orbit_speed_degrees: float = 120.0
## Player's camera sensitivity factor (PLANEJAMENTO Section 7). Scales the turn rate.
@export var sensitivity: float = 1.0
## When true, `camera_up` looks down instead of up (PLANEJAMENTO Section 7).
@export var invert_vertical: bool = false

@export_group("Damping")
## Rate the camera position eases toward its place behind the ship, in reciprocal
## seconds. Frame-rate independent; higher is stiffer and trails less.
@export var position_damping: float = 10.0
## Rate the aim chases the Target Lock framing while locked, in reciprocal seconds.
## Follow mode's angles come straight from the input, so this shapes locked framing only.
@export var rotation_damping: float = 8.0
## Rate the lock framing fades in and out, in reciprocal seconds: at 4.0 a lock takes a
## quarter of a second to take hold and the same to let go.
@export var lock_blend_speed: float = 4.0

@export_group("Obstruction")
## Distance the camera is held short of whatever the ray hit, so the near plane stays
## outside the geometry.
@export var obstruction_margin: float = 0.4
## Layers the obstruction ray tests. Layer 1 is scenery and closed Gate barriers
## (CONVENTIONS "Collision"); the player body is layer 2 and is deliberately not in it.
@export_flags_3d_physics var collision_mask: int = 1

## The node the rig follows: its parent, resolved once in [method _ready].
var _follow_target: Node3D
## Current pitch in radians, always inside [member pitch_limits_degrees].
var _pitch: float = 0.0
## Target being framed, or null in follow mode.
var _lock_target: Node3D
## How much of the lock framing is applied, 0 in follow mode and 1 while fully locked.
var _lock_blend: float = 0.0
## Camera position in world space: the eased one that is rendered.
var _camera_position: Vector3 = Vector3.ZERO
## Where the camera would sit with nothing in the way, recomputed every physics tick.
var _desired_camera_position: Vector3 = Vector3.ZERO
## Farthest the camera may sit from the pivot, from the last obstruction ray. [constant INF]
## while the line is clear.
var _allowed_distance: float = INF


func _ready() -> void:
	_follow_target = get_parent() as Node3D
	if not _validate_setup():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	# The ship banks and an owner may rotate it; neither may reach the camera. Set before
	# reading the yaw, so what is read is this node's own rotation and not the parent's.
	top_level = true
	_pitch = _clamped_pitch(deg_to_rad(default_pitch_degrees))
	var pivot := _follow_target.global_position
	_place_rig(pivot, global_rotation.y)
	# Start at the rest pose instead of easing in from wherever the camera was authored.
	_desired_camera_position = pivot + _follow_offset(global_rotation.y, _pitch)
	_camera_position = _desired_camera_position
	_apply_camera_transform()


func _physics_process(delta: float) -> void:
	var pivot := _follow_target.global_position
	_advance_lock_blend(delta)
	var yaw := _advance_aim(delta, pivot)
	_place_rig(pivot, yaw)
	_desired_camera_position = pivot + _follow_offset(yaw, _pitch)
	_allowed_distance = _clear_distance(pivot, _desired_camera_position)


func _process(delta: float) -> void:
	var pivot := global_position
	_camera_position = _camera_position.lerp(_desired_camera_position, 1.0 - exp(-position_damping * delta))
	# Easing out of an obstruction is smooth; easing into one is not an option, or the
	# camera spends those frames inside the scenery the ray already found.
	var offset := _camera_position - pivot
	if offset.length() > _allowed_distance:
		_camera_position = pivot + offset.normalized() * _allowed_distance
	_apply_camera_transform()


## The yaw the camera faces, in radians around world Y. It is this node's own
## `global_rotation.y`: [PlayerController] rotates its horizontal input by it, so turning
## the rig turns where "forward" flies.
func get_yaw() -> float:
	return global_rotation.y


## Frames [param target] together with the ship: the yaw eases toward the direction from
## the ship to it and the pitch toward their midpoint, fading in over
## [member lock_blend_speed]. Orbit input still moves the camera while locked, so the
## player can look around and the framing eases back when the input stops. A target that
## is freed is dropped as if it had been cleared. Passing null clears the lock.
func set_lock_target(target: Node3D) -> void:
	_lock_target = target


## Returns to follow mode, fading the lock framing out over [member lock_blend_speed] and
## leaving the camera where it is instead of snapping it behind the ship.
func clear_lock_target() -> void:
	_lock_target = null


## Applies the two camera settings of PLANEJAMENTO Section 7. F3 owns reading and
## persisting them; this only stores them.
func apply_settings(p_sensitivity: float, p_invert_vertical: bool) -> void:
	sensitivity = p_sensitivity
	invert_vertical = p_invert_vertical


## Moves the lock blend one tick toward 1 while a live target is set and toward 0
## otherwise, so lock and release both fade instead of snapping.
func _advance_lock_blend(delta: float) -> void:
	if _lock_target != null and not is_instance_valid(_lock_target):
		_lock_target = null
	var goal := 1.0 if _lock_target != null else 0.0
	_lock_blend = move_toward(_lock_blend, goal, lock_blend_speed * delta)


## Advances the aim one tick and returns the new yaw; the pitch is stored, since only the
## yaw is public. The lock framing pulls first, scaled by the blend, and the orbit input
## is added on top: in follow mode it is the whole of the movement, and while locked it
## pushes against the pull, which is what lets the player look around without breaking the
## lock.
func _advance_aim(delta: float, pivot: Vector3) -> float:
	var yaw := global_rotation.y
	if _lock_blend > 0.0 and _lock_target != null:
		var pull := (1.0 - exp(-rotation_damping * delta)) * _lock_blend
		var target_position := _lock_target.global_position
		yaw = lerp_angle(yaw, _framing_yaw(pivot, target_position), pull)
		_pitch = lerpf(_pitch, _framing_pitch(pivot, target_position), pull)
	var look := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	var rate := deg_to_rad(orbit_speed_degrees) * sensitivity * delta
	# The actions name where the view turns, so `camera_up` raises it: the camera orbits
	# below the ship and looks up at it, unless the player inverted the axis.
	var vertical := look.y if invert_vertical else -look.y
	_pitch = _clamped_pitch(_pitch + vertical * rate)
	return yaw - look.x * rate


## Yaw that looks from the ship along the direction to the target, keeping the camera
## behind the ship. The camera faces -Z rotated by the yaw, which is where the signs come
## from. Horizontal only: the pitch is what covers the height difference.
func _framing_yaw(pivot: Vector3, target_position: Vector3) -> float:
	var direction := target_position - pivot
	direction.y = 0.0
	if direction.is_zero_approx():
		return global_rotation.y
	return atan2(-direction.x, -direction.z)


## Pitch that aims the camera at the midpoint between the ship and the target, so both
## stay in view, clamped to the pitch limits. Measured from where the camera actually is,
## which is the point the view is drawn from.
func _framing_pitch(pivot: Vector3, target_position: Vector3) -> float:
	var to_midpoint := (pivot + target_position) * 0.5 - _camera_position
	if to_midpoint.is_zero_approx():
		return _pitch
	# The view direction is (-sin(yaw)cos(pitch), sin(pitch), -cos(yaw)cos(pitch)), so the
	# pitch that points at a direction is the arcsine of its height.
	return _clamped_pitch(asin(clampf(to_midpoint.normalized().y, -1.0, 1.0)))


## Camera offset from the pivot, in world space. The pitch rotates it around the rig's
## right axis and the yaw around world Y, so the view direction and the offset turn
## together and the ship keeps the same place on screen at every pitch.
func _follow_offset(yaw: float, pitch: float) -> Vector3:
	var offset := Vector3(0.0, follow_height, follow_distance)
	return offset.rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)


## How far from [param pivot] the camera may sit along the line to [param desired]: the
## whole way when it is clear, or short of the first hit by [member obstruction_margin].
func _clear_distance(pivot: Vector3, desired: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(pivot, desired, collision_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return INF
	var hit_position: Vector3 = hit["position"]
	return maxf(pivot.distance_to(hit_position) - obstruction_margin, 0.0)


## Places the rig itself: at the ship, turned by the yaw and by nothing else. The basis is
## rebuilt rather than rotated, so no pitch or roll can accumulate in it.
func _place_rig(pivot: Vector3, yaw: float) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, yaw), pivot)


## Writes the camera's world transform. The basis is built from the yaw and the pitch with
## an explicit zero roll, which is the one place the stable horizon is enforced.
func _apply_camera_transform() -> void:
	var basis := Basis.from_euler(Vector3(_pitch, global_rotation.y, 0.0))
	camera.global_transform = Transform3D(basis, _camera_position)


func _clamped_pitch(pitch: float) -> float:
	return clampf(pitch, deg_to_rad(pitch_limits_degrees.x), deg_to_rad(pitch_limits_degrees.y))


## Reports what is missing with this node's path (CONVENTIONS "Setup errors are loud")
## and returns whether the rig may run at all.
func _validate_setup() -> bool:
	var configured := true
	if camera == null:
		push_error("%s: required export 'camera' is not set" % get_path())
		configured = false
	if _follow_target == null:
		push_error("%s: the rig must be a child of the Node3D it follows" % get_path())
		configured = false
	return configured
