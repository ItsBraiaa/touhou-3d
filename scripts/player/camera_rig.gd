class_name CameraRig
extends Node3D
## Adapter for the third-person camera: follows the ship from behind with a level
## horizon, orbits with the `camera_*` actions and, in mouse mode, with the captured mouse,
## frames the ship together with a Target Lock, recenters on request, and shortens against
## scenery.
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
## Every aim source — the lock framing, a recenter, the `camera_*` actions and the mouse —
## is folded into that one yaw and pitch in [method _advance_aim], once per physics tick,
## and the camera transform is written in one place. There is no tween and no second writer.
##
## There is no Rules Core: every rule here is a question about the scene (where the ship
## is, where the target is, what the ray hit), which ADR-0001 keeps out of a core.


## Camera input mode of the keyboard-and-mouse player: the `camera_*` actions only, which
## is the behaviour before F16 and the default.
const MODE_KEYS := &"keys"
## Camera input mode that adds mouse look while [method set_mouse_capture_active] is on.
const MODE_MOUSE := &"mouse"

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
## Player's camera sensitivity factor (PLANEJAMENTO Section 7). Scales the turn rate of the
## `camera_*` actions, keys and right stick alike; the mouse has [member mouse_sensitivity].
@export var sensitivity: float = 1.0
## When true, `camera_up` looks down instead of up (PLANEJAMENTO Section 7). The mouse has
## its own [member mouse_invert_vertical].
@export var invert_vertical: bool = false
## Radial deadzone of the `camera_*` actions, from 0 to 1. A deflection inside it does not
## orbit and the rest is rescaled to start from zero, so it filters right-stick drift; a key
## is always a full deflection. 0.2 is the actions' own deadzone, so the default orbits
## exactly as before F16.
@export var stick_deadzone: float = 0.2

@export_group("Mouse look")
## [constant MODE_KEYS] or [constant MODE_MOUSE]. The `camera_*` actions orbit in either
## mode; mouse mode adds the mouse on top of them.
@export var camera_input_mode: StringName = MODE_KEYS
## Mouse look turn, in degrees per screen pixel of motion. Not a rate: the pixels are
## already the motion of the tick, so nothing multiplies them by the frame time.
@export var mouse_sensitivity: float = 0.12
## When true, moving the mouse up looks down. Independent of [member invert_vertical].
@export var mouse_invert_vertical: bool = false
## Fastest mouse motion, in screen pixels per second, that counts as jitter rather than
## deliberate look; 60 is one pixel per tick at 60 Hz. It is measured over real time, so the
## split does not move with the frame rate. Jitter still turns the camera, but it neither
## holds the lock framing off nor interrupts a recenter, and a recenter drops it. Claude's
## proposal.
@export var mouse_jitter_speed: float = 60.0
## Seconds the lock framing stays off after the last deliberate mouse motion, before it
## fades back in at [member lock_blend_speed].
@export var mouse_look_hold_seconds: float = 0.25

@export_group("Recenter")
## Duration of a recenter, in seconds, eased in and out. 0 recenters on the next tick.
@export var recenter_seconds: float = 0.25
## Seconds at the start of a recenter during which camera input is dropped instead of
## interrupting it, so the press that asked for it cannot cancel it: a wheel click nudges the
## mouse and a stick click tilts the stick. Claude's proposal.
@export var recenter_grace_seconds: float = 0.1

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
## Whether the owner has the pointer captured for gameplay; see [method set_mouse_capture_active].
var _mouse_capture_active: bool = false
## Mouse motion in screen pixels collected since the last physics tick, which spends it.
var _pending_look: Vector2 = Vector2.ZERO
## Real time of the last physics tick, in microseconds: the motion a tick spends arrived
## after it.
var _last_aim_usec: int = 0
## Seconds left before the lock framing may fade back in after deliberate mouse look.
var _look_hold_left: float = 0.0
## How much of the lock framing mouse look holds off: 1 while the mouse aims, fading to 0.
var _look_override: float = 0.0
## Whether a recenter is in progress; see [method request_recenter].
var _recentering: bool = false
## Seconds since the recenter in progress started or last restarted.
var _recenter_elapsed: float = 0.0


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


## Collects mouse look for the next physics tick, only while mouse mode is on and the owner
## has the pointer captured. [method _input] rather than unhandled input, so no Control under
## the hidden cursor can take the motion first: the capture gate decides, not the GUI. The
## event is never handled here, because [Interface]'s device tracking reads the same motion.
## A paused tree does not call this, so nothing collects under Pause either.
func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or not _mouse_look_active():
		return
	# `screen_relative`, not `relative`: `relative` is scaled by the canvas_items stretch, so
	# the same hand movement would turn the camera less in a larger window.
	_pending_look += motion.screen_relative


## The yaw the camera faces, in radians around world Y. It is this node's own
## `global_rotation.y`: [PlayerController] rotates its horizontal input by it, so turning
## the rig turns where "forward" flies.
func get_yaw() -> float:
	return global_rotation.y


## Frames [param target] together with the ship: the yaw eases toward the direction from
## the ship to it and the pitch toward their midpoint, fading in over
## [member lock_blend_speed]. Orbit input still moves the camera while locked, so the
## player can look around and the framing eases back when the input stops; deliberate mouse
## look holds the framing off instead, and it fades back in [member mouse_look_hold_seconds]
## after the mouse stops. Neither releases the lock. A target that is freed is dropped as if
## it had been cleared. Passing null clears the lock.
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


## Applies the F16 camera-input settings: [param p_mode] is [constant MODE_KEYS] or
## [constant MODE_MOUSE], and anything else reads as keys; [param p_mouse_sensitivity] is
## degrees per screen pixel; [param p_mouse_invert] inverts the mouse's vertical axis only;
## [param p_deadzone] is the radial deadzone of the `camera_*` actions. F16-06 owns reading
## them from [Settings]; like [method apply_settings] this only stores them. It also drops
## the mouse motion not yet applied, so a mode change never replays it.
func apply_control_settings(
		p_mode: StringName, p_mouse_sensitivity: float, p_mouse_invert: bool, p_deadzone: float) -> void:
	camera_input_mode = MODE_MOUSE if p_mode == MODE_MOUSE else MODE_KEYS
	mouse_sensitivity = p_mouse_sensitivity
	mouse_invert_vertical = p_mouse_invert
	stick_deadzone = p_deadzone
	clear_pending_look()


## Opens or closes the gate on mouse look. The owner that captures and releases the pointer
## calls it (F16-06: Session and Interface); the rig never changes `Input.mouse_mode` and
## cannot tell by itself whether gameplay is active. Motion is collected only while this is
## on and the mode is [constant MODE_MOUSE]. Every call drops the motion not yet applied, so
## neither a capture nor a release replays it.
func set_mouse_capture_active(active: bool) -> void:
	_mouse_capture_active = active
	clear_pending_look()


## Drops the mouse motion collected since the last physics tick, for the transitions the
## capture gate does not cover: a focus change, a Resume, the warp that capturing the pointer
## can report as one large motion.
func clear_pending_look() -> void:
	_pending_look = Vector2.ZERO


## Turns the camera back over [member recenter_seconds], eased and along the shorter way
## round. Without a lock it faces the ship's authored forward (its own -Z, not the last
## movement direction) at [member default_pitch_degrees] and the normal follow offset; with
## one it returns to the normal ship-and-target framing and keeps the lock. Camera input
## interrupts it once [member recenter_grace_seconds] have passed. A request during a
## recenter restarts it from the current pose; nothing queues. The pitch limits and the obstruction ray apply throughout. F16-06 calls this on
## the `camera_recenter` action, which the rig does not read.
func request_recenter() -> void:
	_recentering = true
	_recenter_elapsed = 0.0
	# A recenter is a return to the framing, so it ends a mouse-look hold instead of
	# waiting it out, and the framing is live again the tick the recenter ends.
	_look_hold_left = 0.0
	_look_override = 0.0


## Moves the lock blend one tick toward 1 while a live target is set and toward 0
## otherwise, so lock and release both fade instead of snapping.
func _advance_lock_blend(delta: float) -> void:
	if _lock_target != null and not is_instance_valid(_lock_target):
		_lock_target = null
	var goal := 1.0 if _lock_target != null else 0.0
	_lock_blend = move_toward(_lock_blend, goal, lock_blend_speed * delta)


## Advances the aim one tick and returns the new yaw; the pitch is stored, since only the
## yaw is public. This is the one place any source turns the camera.
##
## A recenter in progress is the whole of the tick, unless camera input interrupts it after
## the grace time; until then the input is dropped. Otherwise the lock framing pulls first,
## scaled by the blend and held off by mouse look, and the input is added on top: in follow
## mode it is the whole of the movement, and while locked the `camera_*` actions push against
## the pull, which is what lets the player look around without breaking the lock. The actions
## turn at a rate, times the tick; the mouse turns by the pixels it moved, once, whatever the
## tick or frame rate.
func _advance_aim(delta: float, pivot: Vector3) -> float:
	var yaw := global_rotation.y
	var orbit := Input.get_vector(
			&"camera_left", &"camera_right", &"camera_up", &"camera_down", stick_deadzone)
	var mouse := _pending_look
	_pending_look = Vector2.ZERO
	var mouse_deliberate := mouse.length() > mouse_jitter_speed * _advance_look_clock()
	if _recentering:
		var in_grace := _recenter_elapsed < recenter_grace_seconds
		if in_grace or (orbit.is_zero_approx() and not mouse_deliberate):
			return _advance_recenter(delta, pivot, yaw)
		_recentering = false
	# After the recenter check, so motion a recenter dropped never arms the look hold that
	# [method request_recenter] cleared.
	_advance_look_override(delta, mouse_deliberate)
	if _lock_blend > 0.0 and _lock_target != null:
		var pull := (1.0 - exp(-rotation_damping * delta)) * _lock_blend * (1.0 - _look_override)
		var target_position := _lock_target.global_position
		yaw = lerp_angle(yaw, _framing_yaw(pivot, target_position), pull)
		_pitch = lerpf(_pitch, _framing_pitch(pivot, target_position), pull)
	var rate := deg_to_rad(orbit_speed_degrees) * sensitivity * delta
	# The actions name where the view turns, so `camera_up` raises it: the camera orbits
	# below the ship and looks up at it, unless the player inverted the axis.
	var vertical := orbit.y if invert_vertical else -orbit.y
	# Screen y grows downward, so moving the mouse up is a negative y that raises the view,
	# and moving it right turns the view right, which is a negative rotation around world Y.
	var mouse_turn := mouse * deg_to_rad(mouse_sensitivity)
	var mouse_vertical := mouse_turn.y if mouse_invert_vertical else -mouse_turn.y
	_pitch = _clamped_pitch(_pitch + vertical * rate + mouse_vertical)
	return yaw - orbit.x * rate - mouse_turn.x


## Returns the real seconds since the previous physics tick and starts the next interval.
## That interval is what the tick's mouse motion was collected over, at any frame rate:
## input arrives once per rendered frame, so below the tick rate the first tick of a frame
## spends the whole frame's motion and the next one none, and above it one tick spends
## several frames. Measuring by the tick's own delta instead would make the jitter split
## depend on the frame rate. The clamp keeps a first tick, or the first after a pause, from
## reading every motion as a crawl, and a zero interval from reading it all as deliberate.
func _advance_look_clock() -> float:
	var now_usec := Time.get_ticks_usec()
	var elapsed := float(now_usec - _last_aim_usec) / 1000000.0
	_last_aim_usec = now_usec
	return clampf(elapsed, 0.001, 0.1)


## Holds the lock framing off while the mouse aims deliberately, for
## [member mouse_look_hold_seconds] after the last such motion, then fades it back in at
## [member lock_blend_speed], the same fade a fresh lock takes, so the return is eased and
## not a snap. Runs in follow mode too, so a lock taken mid-look does not yank the view.
func _advance_look_override(delta: float, mouse_deliberate: bool) -> void:
	if mouse_deliberate:
		_look_hold_left = mouse_look_hold_seconds
		_look_override = 1.0
		return
	_look_hold_left = maxf(_look_hold_left - delta, 0.0)
	if _look_hold_left <= 0.0:
		_look_override = move_toward(_look_override, 0.0, lock_blend_speed * delta)


## Moves the aim one step of the recenter and returns the new yaw. Each step covers the
## share of what is left that the eased curve gives this tick, measured from wherever the
## camera is now: a goal that moves, such as a locked target, is still met exactly when the
## time runs out, and a repeated request simply starts the curve again from the current
## pose. [method @GlobalScope.lerp_angle] takes the shorter way round from either side of
## ±PI. Both ends of the pitch are inside the limits, so every step between them is too.
func _advance_recenter(delta: float, pivot: Vector3, yaw: float) -> float:
	var goal := _recenter_goal(pivot)
	var before := _recenter_curve(_recenter_elapsed)
	_recenter_elapsed += delta
	var after := _recenter_curve(_recenter_elapsed)
	var weight := 1.0
	if after < 1.0:
		weight = (after - before) / (1.0 - before)
	else:
		_recentering = false
	_pitch = lerpf(_pitch, goal.y, weight)
	return lerp_angle(yaw, goal.x, weight)


## Share of a recenter covered after [param elapsed] seconds, eased in and out: 0 at the
## start and exactly 1 from [member recenter_seconds] on.
func _recenter_curve(elapsed: float) -> float:
	if recenter_seconds <= 0.0:
		return 1.0
	return smoothstep(0.0, 1.0, elapsed / recenter_seconds)


## Where a recenter ends, as (yaw, pitch) in radians. With a live lock it is the normal
## ship-and-target framing. Without one it is the ship's own -Z flattened onto the
## horizontal plane, at the default pitch: the authored forward and not the last movement
## direction, because the ship model does not turn with the camera and its nose is the
## heading the player can see.
func _recenter_goal(pivot: Vector3) -> Vector2:
	if _lock_target != null:
		var target_position := _lock_target.global_position
		return Vector2(_framing_yaw(pivot, target_position), _framing_pitch(pivot, target_position))
	var ahead := pivot - _follow_target.global_basis.z
	return Vector2(_framing_yaw(pivot, ahead), _clamped_pitch(deg_to_rad(default_pitch_degrees)))


func _mouse_look_active() -> bool:
	return _mouse_capture_active and camera_input_mode == MODE_MOUSE


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
