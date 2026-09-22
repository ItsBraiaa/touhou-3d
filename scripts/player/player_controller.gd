class_name PlayerController
extends CharacterBody3D
## Adapter for player flight: reads the input actions and the camera yaw, drives
## [FlightModel], moves the body against scenery, and banks `VisualRoot` only.
##
## It owns no movement rule. Speed, bounded diagonals, Focus, the Flight Volume clamp,
## the edge-proximity value and the bank angle all come from the core (ADR-0001); this
## script is the part that needs a Node: [Input], `move_and_slide()` and the visuals.
## Its owner — the dev harness today, `GameSession` from F2-04 — injects the Flight
## Volume through [method setup] and controls it through [method set_controls_enabled]
## and [method reset_to].


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

var _model: FlightModel
var _controls_enabled: bool = true
var _focus_active: bool = false


func _ready() -> void:
	_model = FlightModel.new()
	_model.configure(base_speed, focus_multiplier, edge_margin)
	_model.edge_proximity_changed.connect(_on_model_edge_proximity_changed)
	if not _validate_exports():
		process_mode = Node.PROCESS_MODE_DISABLED


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


func _process(delta: float) -> void:
	var target := _model.bank_angle(velocity, _camera_yaw(), deg_to_rad(max_bank_angle_degrees))
	var weight := 1.0 - exp(-bank_smoothing * delta)
	visual_root.rotation.z = lerpf(visual_root.rotation.z, target, weight)


## Sets the Flight Volume the ship is kept inside, as a position and a size. An owner
## holding a min and a max corner passes `AABB(min, max - min)`. Until it is called the
## ship is limited by scenery collision alone and the edge feedback stays at 0.
func setup(bounds: AABB) -> void:
	_model.set_bounds(bounds)


## Hands the ship back to the player, or takes it away: while [param enabled] is false
## the input is not read, the velocity is zero, Focus is released and the bank eases
## back to level. Used by pause, defeat and stage transitions.
func set_controls_enabled(enabled: bool) -> void:
	if _controls_enabled == enabled:
		return
	_controls_enabled = enabled
	if enabled:
		return
	velocity = Vector3.ZERO
	_set_focus_active(false)


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
	for field: String in missing:
		push_error("%s: required export '%s' is not set" % [get_path(), field])
	return missing.is_empty()
