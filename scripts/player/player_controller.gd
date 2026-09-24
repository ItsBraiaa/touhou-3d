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


## Re-emitted from [FlightModel] when the distance to the Flight Volume boundary has
## changed enough to show. [param value] is 0 away from every face and 1 at a face.
signal edge_proximity_changed(value: float)

## Emitted when Focus starts or stops, never repeated per tick. [param active] is the
## new state. Focus is released when the controls are disabled.
signal focus_changed(active: bool)

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

@export_group("Feedback")
## Blinks per second of `VisualRoot` while the ship is Invulnerable, each one half shown
## and half hidden. The Core, under `DamageCore`, never blinks. Claude's proposal; Astra
## tunes it.
@export var invulnerability_flicker_hz: float = 12.0

@export_group("Scene references")
## Node the bank is applied to. It holds the ship model and cosmetic effects only:
## the damage Core, the Graze Volume and the Muzzle are siblings, so banking cannot
## move them (ENGINEERING_BRIEF 4.B "Key boundary").
@export var visual_root: Node3D
## Yaw source for camera-relative movement. The rig owns where the camera looks; this
## adapter only asks it for one number every tick.
@export var camera_rig: CameraRig
## Projectile damage volume. Not read here — F7 owns damage — but required so a scene
## missing it fails loudly now, and the contract test can check that banking spares it.
@export var damage_core: Area3D
## Near-miss volume, on the same terms as [member damage_core]; F5 owns graze.
@export var graze_volume: Area3D
## Target Lock selection. Not driven from here — it reads its own actions — but the ship
## owns it and its camera, so this is where the one connection between them is made.
@export var targeting: Targeting
## The ship's weapon. Not driven from here, but [method set_controls_enabled] stops and
## restarts its fire with the controls, so pause, defeat and transitions need one call.
@export var weapon: PlayerWeapon

var _model: FlightModel
var _controls_enabled: bool = true
var _focus_active: bool = false
## Whether `VisualRoot` blinks.
var _invulnerable_visual: bool = false
## Seconds since the blink started, which place it in its cycle.
var _flicker_time: float = 0.0


func _ready() -> void:
	_model = FlightModel.new()
	_model.configure(base_speed, focus_multiplier, edge_margin)
	_model.edge_proximity_changed.connect(_on_model_edge_proximity_changed)
	if not _validate_exports():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	# The camera frames whatever the targeting locks, null included, which clears it. Made
	# here rather than in setup(), because an owner calls setup() again every time the
	# Flight Volume changes and _ready runs once.
	targeting.target_changed.connect(camera_rig.set_lock_target)


func _physics_process(_delta: float) -> void:
	if not _controls_enabled:
		return
	var move := Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	var vertical := Input.get_axis(&"descend", &"ascend")
	var focus := Input.is_action_pressed(&"focus")
	_set_focus_active(focus)
	velocity = _model.compute_velocity(move, vertical, focus, _camera_yaw())
	move_and_slide()
	# The authored walls stop the body; the clamp is the rule, and it also covers the
	# Flight Volume faces an Encounter narrows to without scenery (CONVENTIONS "Collision").
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


## Sets the Flight Volume the ship is kept inside, as a position and a size. An owner
## holding a min and a max corner passes `AABB(min, max - min)`. Until it is called the
## ship is limited by scenery collision alone and the edge feedback stays at 0.
func setup(bounds: AABB) -> void:
	_model.set_bounds(bounds)


## Hands the ship back to the player, or takes it away: while [param enabled] is false
## the input is not read, the velocity is zero, Focus is released and the bank eases
## back to level, and [member weapon] stops firing. Used by pause, defeat and stage
## transitions.
func set_controls_enabled(enabled: bool) -> void:
	if weapon != null:
		weapon.set_fire_enabled(enabled)
	if _controls_enabled == enabled:
		return
	_controls_enabled = enabled
	if enabled:
		return
	velocity = Vector3.ZERO
	_set_focus_active(false)


## Starts or stops the Invulnerability blink of `VisualRoot` at
## [member invulnerability_flicker_hz]. Stopping shows it again. Its owner calls it on
## [signal CombatState.invulnerability_changed]; a new ship starts shown and still.
func set_invulnerable_visual(active: bool) -> void:
	_invulnerable_visual = active
	_flicker_time = 0.0
	if visual_root != null:
		visual_root.visible = true


## Teleports the ship to [param p_transform] and clears its motion: no carried
## velocity and no carried bank. Used by respawn and checkpoint restore.
func reset_to(p_transform: Transform3D) -> void:
	global_transform = p_transform
	velocity = Vector3.ZERO
	if visual_root != null:
		visual_root.rotation.z = 0.0


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
	for field: String in missing:
		push_error("%s: required export '%s' is not set" % [get_path(), field])
	return missing.is_empty()
