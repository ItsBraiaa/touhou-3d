class_name PlayerController
extends CharacterBody3D
## Adapter for player flight: reads the input actions and the camera yaw, drives
## [FlightModel], moves the body against scenery, and banks `VisualRoot` only.
##
## It owns no movement rule. Speed, bounded diagonals, Focus, the Flight Volume clamp,
## the edge-proximity value and the bank angle all come from the core (ADR-0001); this
## script is the part that needs a Node: [Input], `move_and_slide()` and the visuals.
## Its owner — the dev harness today, `GameSession` from F2-04 — injects the Flight
## Volume through [method setup] and controls it through [method set_controls_enabled],
## [method reset_to] and [method set_invulnerable_visual].
##
## Since F16-05 it also flies the lateral dash: [DashModel] decides which press starts a
## burst and times it, and this adapter captures the camera's horizontal left or right,
## replaces the ordinary velocity for the burst, stops it on contact, and shows Astra's
## `DashVisual`. The ship grants itself no protection: its owner answers
## [signal dash_started] with [method CombatState.grant_invulnerability].


## Re-emitted from [FlightModel] when the distance to the Flight Volume boundary has
## changed enough to show. [param value] is 0 away from every face and 1 at a face.
signal edge_proximity_changed(value: float)

## Emitted when Focus starts or stops, never repeated per tick. [param active] is the
## new state. Focus is released when the controls are disabled.
signal focus_changed(active: bool)

## A dash started, inside this physics tick and before the ship moved in it.
## [param direction] is -1 for the camera's left and +1 for its right; [param duration] is
## [member dash_duration], the seconds of Invulnerability the owner grants. Connect it
## without deferral, or the grant misses the field's sweep of the activation tick.
signal dash_started(direction: int, duration: float)

## A dash's active window ended: on time, or cancelled with the controls or by
## [method reset_to]. A dash stopped early by scenery still runs its window to the end.
signal dash_ended

## The dash cooldown changed: [param remaining] seconds of [param total] until the next
## dash is accepted, 0 when ready. Emitted when a dash starts, on every physics tick of the
## cooldown, and when a cancel clears it. [param total] is [member dash_cooldown].
signal dash_cooldown_changed(remaining: float, total: float)

## [method set_controls_enabled] changed the controls. [param enabled] is false while the
## ship is paused, frozen for a beat or taken away, when no dash can start.
signal controls_enabled_changed(enabled: bool)

## Casts one dash step may take along surfaces it meets side-on, such as the floor the
## ship skims, before the rest of the step is dropped.
const MAX_DASH_CASTS := 4
## Largest share of a contact normal against the dash direction that still counts as a
## surface along the travel rather than an obstacle across it: about one degree.
const DASH_GLANCE_TOLERANCE := 0.02

@export_group("Flight values")
## Top speed in world units per second, on any axis and on any diagonal.
@export var base_speed: float = 12.0
## Factor applied to [member base_speed] while Focus is held.
@export var focus_multiplier: float = 0.45
## Distance from a Flight Volume face at which the edge feedback starts to rise.
@export var edge_margin: float = 4.0
## Largest roll of `VisualRoot`, in degrees, at full lateral speed.
@export var max_bank_angle_degrees: float = 25.0
## Rate the bank eases toward its target, in reciprocal seconds; higher is snappier
## and 0 leaves the ship level. Frame-rate independent.
@export var bank_smoothing: float = 8.0

@export_group("Dash")
## Unobstructed travel of one dash, in world units. The burst flies it at
## [member dash_distance] / [member dash_duration] units per second, which Focus does not
## scale.
@export var dash_distance: float = 3.0
## Seconds a dash is active, and the seconds of Invulnerability its owner grants for it.
## 0 disables the dash, and the HUD then shows it as unavailable.
@export var dash_duration: float = 0.15
## Seconds from a dash's activation until the next one, in either direction, is accepted.
@export var dash_cooldown: float = 0.8

@export_group("Feedback")
## Blinks per second of `VisualRoot` while the ship is Invulnerable, each one half shown
## and half hidden. The Core, under `DamageCore`, never blinks. Claude's proposal; Astra
## tunes it.
@export var invulnerability_flicker_hz: float = 12.0
## Strength of the idle Core pulse, as a fraction of the idle emission energy.
@export var core_idle_pulse_strength: float = 0.12
## Pulses per second of the Core while it is idle.
@export var core_idle_pulse_hz: float = 1.2
## Emission energy multiplier while Focus is active.
@export var core_focus_energy_multiplier: float = 3.0

@export_group("Scene references")
## Node the bank is applied to. It holds the ship model and cosmetic effects only:
## the damage Core, the Graze Volume and the Muzzle are siblings, so banking cannot
## move them (ENGINEERING_BRIEF 4.B "Key boundary").
@export var visual_root: Node3D
## Yaw source for camera-relative movement. The rig owns where the camera looks; this
## adapter only asks it for one number every tick, and for its basis when a dash starts.
@export var camera_rig: CameraRig
## Projectile damage volume. Not read here — F7 owns damage — but required so a scene
## missing it fails loudly now, and the contract test can check that banking spares it.
@export var damage_core: Area3D
## Near-miss volume, on the same terms as [member damage_core]; F5 owns graze.
@export var graze_volume: Area3D
## Target Lock selection. Not driven from here — it reads its own actions — but the ship
## owns it and its camera, so this is where the two connections between them are made.
@export var targeting: Targeting
## The ship's weapon. Not driven from here, but [method set_controls_enabled] stops and
## restarts its fire with the controls, so pause, defeat and transitions need one call.
@export var weapon: PlayerWeapon
## Astra's cosmetic `scenes/player/visuals/dash_visual.tscn`, under `VisualRoot` so it banks
## and blinks with the ship. Its `TrailLeft`, `TrailRight` and `ProtectionAccent` show only
## during a dash.
@export var dash_visual: Node3D

var _model: FlightModel
var _dash := DashModel.new()
var _controls_enabled: bool = true
var _focus_active: bool = false
## Whether `VisualRoot` blinks. The owner mirrors [method CombatState.is_invulnerable] into
## it, so it is also what "protected" means for the dash visual.
var _invulnerable_visual: bool = false
## Seconds since the blink started, which place it in its cycle.
var _flicker_time: float = 0.0
var _core_visual: MeshInstance3D
var _core_material: StandardMaterial3D
var _core_idle_energy: float = 1.0
var _core_time: float = 0.0
var _core_focus_active: bool = false
## World direction of the dash in progress: the camera's horizontal right or left, unit
## length, captured when it started.
var _dash_direction := Vector3.ZERO
## True from a dash's start until its window ends or a contact stops its travel.
var _dash_travelling: bool = false
## The three `DashVisual` parts; null when the scene lacks one, which leaves the dash
## without visuals.
var _trail_left: Node3D
var _trail_right: Node3D
var _protection_accent: Node3D
## False from the moment the ship gets its controls (it enters play, or a Resume gives them
## back) until a tick after it with both dash actions released (F16-06). The press that
## resumed play can share its input with a dash: a dash remapped to B resumes from Pause as
## `ui_cancel`, on the press, and `Input.is_action_just_pressed` still reports that press on
## the first tick the ship runs, so it must not dash.
var _dash_input_armed: bool = false


func _ready() -> void:
	_model = FlightModel.new()
	_model.configure(base_speed, focus_multiplier, edge_margin)
	_model.edge_proximity_changed.connect(_on_model_edge_proximity_changed)
	_dash.configure(dash_duration, dash_cooldown)
	if not _validate_exports():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_setup_core_feedback()
	_setup_dash_visual()
	focus_changed.connect(_on_focus_changed)
	# The camera frames whatever the targeting locks, null included, which clears it, and
	# recenters when a defeat ends the lock with no target left (F16-11). Made here rather
	# than in setup(), because an owner calls setup() again every time the Flight Volume
	# changes and _ready runs once.
	targeting.target_changed.connect(camera_rig.set_lock_target)
	targeting.lock_lost_to_defeat.connect(_on_lock_lost_to_defeat)


## One tick: the dash timers first, so a window that ran out ends before this tick's
## input; then the input; then the burst or the ordinary velocity; then the clamp.
func _physics_process(delta: float) -> void:
	if not _controls_enabled:
		return
	_advance_dash(delta)
	var move := Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	var vertical := Input.get_axis(&"descend", &"ascend")
	var focus := Input.is_action_pressed(&"focus")
	_set_focus_active(focus)
	_try_start_dash()
	if _dash_travelling:
		_move_dash(delta)
	else:
		velocity = _model.compute_velocity(move, vertical, focus, _camera_yaw())
		move_and_slide()
	# The authored walls stop the body; the clamp is the rule, and it also covers the
	# Flight Volume faces an Encounter narrows to without scenery (CONVENTIONS "Collision").
	# A dash has already stopped at a face it crossed, so for it this is only a safeguard.
	global_position = _model.clamp_position(global_position)
	_model.edge_proximity(global_position)


## `_process` stops while the tree is paused, so a ship paused mid-blink is shown for the
## pause (Pause, Defeat) instead of staying hidden under it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and visual_root != null:
		visual_root.visible = true


func _process(delta: float) -> void:
	var target := _model.bank_angle(velocity, _camera_yaw(), deg_to_rad(max_bank_angle_degrees))
	var weight := 1.0 - exp(-bank_smoothing * delta)
	visual_root.rotation.z = lerpf(visual_root.rotation.z, target, weight)
	if _invulnerable_visual:
		_flicker_time += delta
		visual_root.visible = fmod(_flicker_time * invulnerability_flicker_hz, 1.0) < 0.5
	_update_core_feedback(delta)


## Sets the Flight Volume the ship is kept inside, as a position and a size. An owner
## holding a min and a max corner passes `AABB(min, max - min)`. Until it is called the
## ship is limited by scenery collision alone and the edge feedback stays at 0.
func setup(bounds: AABB) -> void:
	_model.set_bounds(bounds)


## Hands the ship back to the player, or takes it away: while [param enabled] is false
## the input is not read, the velocity is zero, Focus is released and the bank eases
## back to level, and [member weapon] stops firing. Used by pause, defeat and stage
## transitions. Taking the controls away while the tree is paused freezes a dash with the
## ship, its cooldown included, and it resumes with the controls; taking them away with
## the tree running (a beat, defeat, a stage clear) cancels the dash and clears its
## cooldown. Giving them back ignores the dash and targeting actions until they are
## released, so the press that resumed play can reach neither (F16-06, F16-09). Emits
## [signal controls_enabled_changed] on a change.
func set_controls_enabled(enabled: bool) -> void:
	if weapon != null:
		weapon.set_fire_enabled(enabled)
	if _controls_enabled == enabled:
		return
	_controls_enabled = enabled
	controls_enabled_changed.emit(enabled)
	if enabled:
		_dash_input_armed = false
		if targeting != null:
			targeting.require_release()
		return
	velocity = Vector3.ZERO
	_set_focus_active(false)
	# The Session pauses the tree before it disables the controls, so a paused ship is
	# already unable to process here.
	var frozen_by_pause := is_inside_tree() and not can_process()
	if not frozen_by_pause:
		_cancel_dash()


## Whether the controls are on: false after [method set_controls_enabled] took them away.
func are_controls_enabled() -> bool:
	return _controls_enabled


## Seconds until the next dash is accepted, or 0 when ready.
func get_dash_cooldown_left() -> float:
	return _dash.get_cooldown_left()


## Whether this ship dashes at all: false when [member dash_duration] is 0, which refuses
## every dash, so the HUD never shows one as ready.
func has_dash() -> bool:
	return _dash.is_enabled()


## Starts or stops the Invulnerability blink of `VisualRoot` at
## [member invulnerability_flicker_hz]. Stopping shows it again. Its owner calls it on
## [signal CombatState.invulnerability_changed]; a new ship starts shown and still. It also
## gates the dash visual, which shows only while the ship is Invulnerable.
func set_invulnerable_visual(active: bool) -> void:
	_invulnerable_visual = active
	_flicker_time = 0.0
	if visual_root != null:
		visual_root.visible = true
	_refresh_dash_visual()


## Teleports the ship to [param p_transform] and clears its motion: no carried
## velocity, no carried bank and no dash, its cooldown cleared. Used by respawn and
## checkpoint restore.
func reset_to(p_transform: Transform3D) -> void:
	global_transform = p_transform
	velocity = Vector3.ZERO
	if visual_root != null:
		visual_root.rotation.z = 0.0
	_cancel_dash()


## Yaw the horizontal input is rotated by, in radians. World-space, because the model
## rotates around world Y: the body itself is never rotated, so the rig's own turn is
## the whole of it. [method CameraRig.get_yaw] returns the rig's own `global_rotation.y`,
## so turning that node by any means turns where forward flies.
func _camera_yaw() -> float:
	return camera_rig.get_yaw()


func _set_focus_active(active: bool) -> void:
	if _focus_active == active:
		return
	_focus_active = active
	focus_changed.emit(active)


## Ticks the dash core: ends a burst whose window ran out and reports the cooldown while
## it runs.
func _advance_dash(delta: float) -> void:
	var was_active := _dash.is_active()
	var was_cooling := _dash.get_cooldown_left() > 0.0
	_dash.tick(delta)
	if was_active and not _dash.is_active():
		_end_dash()
	if was_cooling:
		dash_cooldown_changed.emit(_dash.get_cooldown_left(), dash_cooldown)


## Reads this tick's dash presses and starts a burst when the core accepts one: one press
## makes one dash, both directions together make none, and a press during the cooldown is
## dropped. [signal dash_started] goes out before the ship moves, so the owner's grant is
## in place for the rest of this physics tick. Until [member _dash_input_armed], a tick only
## waits for both actions to be released, and reads no press: a tap shorter than a frame is
## released already, yet still "just pressed" on that tick.
func _try_start_dash() -> void:
	var left_held := Input.is_action_pressed(&"dash_left")
	var right_held := Input.is_action_pressed(&"dash_right")
	if not _dash_input_armed:
		_dash_input_armed = not left_held and not right_held
		return
	var direction := DashModel.resolve_direction(
			Input.is_action_just_pressed(&"dash_left"), Input.is_action_just_pressed(&"dash_right"),
			left_held, right_held)
	if not _dash.try_start(direction):
		return
	# The rig's basis is a pure yaw, so its X axis is the camera's horizontal right. It is
	# flattened anyway: a dash never climbs or dives.
	var camera_right := camera_rig.global_basis.x
	camera_right.y = 0.0
	_dash_direction = camera_right.normalized() * float(direction)
	_dash_travelling = true
	dash_started.emit(direction, dash_duration)
	dash_cooldown_changed.emit(_dash.get_cooldown_left(), dash_cooldown)
	_refresh_dash_visual()


## Flies this tick's share of the burst along the captured direction, replacing the
## ordinary velocity. The share is one step, or what is left of the active window when
## that is shorter, so the burst covers [member dash_distance] exactly at any tick rate.
## The motion goes through the body's own collision: a contact that faces the travel
## stops the burst where the body touched it, with nothing slid along the obstacle, and
## the body never passes through it. A Flight Volume face stops it the same way.
func _move_dash(delta: float) -> void:
	var start := global_position
	velocity = _dash_direction * (dash_distance / dash_duration)
	var motion := velocity * minf(delta, _dash.get_active_time_left())
	for _cast: int in MAX_DASH_CASTS:
		var collision := move_and_collide(motion)
		if collision == null:
			break
		if _blocks_dash(collision):
			_stop_dash_travel()
			break
		# A surface along the travel, such as the floor the ship skims: the rest of the
		# motion goes on in the same direction, never deflected.
		motion = collision.get_remainder()
	_stop_dash_at_flight_volume(start)


## Ends the burst where this tick's step from [param start] first met a Flight Volume face,
## when it crossed one. The clamp works axis by axis, so on its own it would keep the part
## of the step along the face, a one-tick slide; instead the ship goes back along its own
## step to the face. A start outside a Flight Volume that has just narrowed gives a
## fraction outside 0..1, which is held to it, and the clamp after the move does the rest.
func _stop_dash_at_flight_volume(start: Vector3) -> void:
	var clamped := _model.clamp_position(global_position)
	if clamped.is_equal_approx(global_position):
		return
	var moved := global_position - start
	var fraction := 1.0
	for axis: int in 3:
		if not is_equal_approx(clamped[axis], global_position[axis]) and not is_zero_approx(moved[axis]):
			fraction = minf(fraction, (clamped[axis] - start[axis]) / moved[axis])
	global_position = start + moved * clampf(fraction, 0.0, 1.0)
	_stop_dash_travel()


## Whether any contact of [param collision] faces the dash, however glancing. A normal
## square to the travel (a floor, a ceiling, a wall alongside) does not stop it.
func _blocks_dash(collision: KinematicCollision3D) -> bool:
	for index: int in collision.get_collision_count():
		if collision.get_normal(index).dot(_dash_direction) < -DASH_GLANCE_TOLERANCE:
			return true
	return false


## Ends the travel of the burst in progress, for good: its window, and the protection
## granted for it, still run to the end, and ordinary flight resumes on the next tick.
func _stop_dash_travel() -> void:
	_dash_travelling = false
	velocity = Vector3.ZERO
	_refresh_dash_visual()


## A burst's window ended or was cancelled.
func _end_dash() -> void:
	_dash_travelling = false
	_refresh_dash_visual()
	dash_ended.emit()


## Ends a burst in progress and clears the cooldown, reporting both, so the ship is ready
## to dash again and nothing of the old dash shows.
func _cancel_dash() -> void:
	var was_active := _dash.is_active()
	var was_cooling := _dash.get_cooldown_left() > 0.0
	_dash.cancel()
	if was_active:
		_end_dash()
	if was_cooling:
		dash_cooldown_changed.emit(0.0, dash_cooldown)


## Shows `DashVisual` only while a dash is active and the ship is Invulnerable, so no part
## of it can outlive the protection: the trail on the dash's side while the burst still
## travels, and `ProtectionAccent` for the whole protected window. Under `VisualRoot`, it
## blinks with the ship. The Core draws over it (no depth test, render priority 10).
func _refresh_dash_visual() -> void:
	if _protection_accent == null:
		return
	var shown := _dash.is_active() and _invulnerable_visual
	dash_visual.visible = shown
	_protection_accent.visible = shown
	_trail_left.visible = shown and _dash_travelling and _dash.get_direction() < 0
	_trail_right.visible = shown and _dash_travelling and _dash.get_direction() > 0


func _setup_core_feedback() -> void:
	_core_visual = damage_core.get_node_or_null(^"CoreVisual") as MeshInstance3D
	if _core_visual == null:
		push_error("%s: DamageCore has no MeshInstance3D child named 'CoreVisual'" % get_path())
		return
	var authored_material := _core_visual.get_active_material(0) as StandardMaterial3D
	if authored_material == null:
		push_error("%s: CoreVisual surface 0 has no StandardMaterial3D" % get_path())
		return
	_core_material = authored_material.duplicate() as StandardMaterial3D
	_core_visual.set_surface_override_material(0, _core_material)
	_core_material.emission_enabled = true
	_core_material.emission = _core_material.albedo_color
	_core_idle_energy = maxf(_core_material.emission_energy_multiplier, 1.0)
	_core_material.emission_energy_multiplier = _core_idle_energy


## Resolves the three `DashVisual` parts and hides the whole of it. A missing part is
## reported and leaves the dash without visuals; the dash itself still works.
func _setup_dash_visual() -> void:
	var trail_left := dash_visual.get_node_or_null(^"TrailLeft") as Node3D
	var trail_right := dash_visual.get_node_or_null(^"TrailRight") as Node3D
	var protection_accent := dash_visual.get_node_or_null(^"ProtectionAccent") as Node3D
	if trail_left == null or trail_right == null or protection_accent == null:
		push_error("%s: DashVisual needs Node3D children 'TrailLeft', 'TrailRight' and 'ProtectionAccent'" % get_path())
		return
	_trail_left = trail_left
	_trail_right = trail_right
	_protection_accent = protection_accent
	_refresh_dash_visual()


func _update_core_feedback(delta: float) -> void:
	if _core_material == null:
		return
	_core_time += delta
	var pulse := 1.0 + maxf(core_idle_pulse_strength, 0.0) * sin(_core_time * TAU * core_idle_pulse_hz)
	var focus_energy := _core_idle_energy * maxf(core_focus_energy_multiplier, 1.0)
	_core_material.emission_energy_multiplier = focus_energy if _core_focus_active else _core_idle_energy * pulse


func _on_focus_changed(active: bool) -> void:
	_core_focus_active = active


## A defeat ended the lock with no target left (F16-11). The camera recenters only while
## the ship has its controls, as a pressed `camera_recenter` is refused in a beat, and
## without the grace a pressed recenter has, since no press asked for this one.
func _on_lock_lost_to_defeat() -> void:
	if _controls_enabled:
		camera_rig.request_recenter(false)


func _on_model_edge_proximity_changed(value: float) -> void:
	edge_proximity_changed.emit(value)


## Reports every unset reference with this node's path (CONVENTIONS "Setup errors are
## loud") and returns whether the adapter may run at all.
func _validate_exports() -> bool:
	var missing: PackedStringArray = []
	if visual_root == null:
		missing.append("visual_root")
	if camera_rig == null:
		missing.append("camera_rig")
	if damage_core == null:
		missing.append("damage_core")
	if graze_volume == null:
		missing.append("graze_volume")
	if targeting == null:
		missing.append("targeting")
	if weapon == null:
		missing.append("weapon")
	if dash_visual == null:
		missing.append("dash_visual")
	for field: String in missing:
		push_error("%s: required export '%s' is not set" % [get_path(), field])
	return missing.is_empty()
