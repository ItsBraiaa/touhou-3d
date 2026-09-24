class_name PlayerWeapon
extends Node
## Adapter on `PlayerShip/Weapon`: turns the [WeaponModel]'s shots into player
## Projectiles through the [ProjectileSystem], shows the two Familiars from Power Level 2,
## and feeds the Bomb button to [CombatState] once per physics tick.
##
## Shots leave from `Muzzle` and the Familiar anchors, rotated by the camera yaw (the body
## never yaws, F1-02), fly where the view looks, and turn toward the locked target's
## `HitVolume` when it is inside the shot's Aim Assist cone, measured from the camera
## (F6-04). A shot flies straight: there is no homing, and the field kills it on scenery
## for its whole travel (ADR-0004). The
## Bomb button is tracked from `bomb` events, never from `Input.is_action_just_pressed`,
## because gamepad B is also `ui_cancel` (F2-04); a Bomb shows up as
## [signal CombatState.bomb_activated]; the Session reacts to it with this weapon's
## [member bomb_radius], [member bomb_damage] and [member bomb_visual_scene] (F7-02).


## [param count] shots entered the field this physics tick; at most once per tick, and
## never for a tick whose every spawn the field refused. For audio (F13-03).
signal shots_fired(count: int)

## Radius of a Familiar's small visual orbit around its anchor, in world units. The shot
## leaves from the anchor, not the orbiting visual, so it stays deterministic.
const FAMILIAR_ORBIT_RADIUS := 0.3
## Turns per second of that orbit.
const FAMILIAR_ORBIT_TURNS_PER_SECOND := 1.0
## Children of [member familiar_anchors], in [enum WeaponModel.Source] order.
const ANCHOR_NAMES: Array[StringName] = [&"Left", &"Right"]
## Least distance, along the view, the aim point keeps ahead of a shot's origin, so a close
## target never turns "forward" up or back.
const MIN_AIM_AHEAD := 8.0
## Physics priority: after every actor (default 0), so this tick's lock, yaw and enemy
## registrations are what a shot or a Bomb sees, and before the [ProjectileSystem]
## ([constant ProjectileSystem.TICK_PRIORITY]), which moves this tick's shots.
const PHYSICS_PRIORITY := 50

@export_group("Scene references")
## Where the main shot leaves, in ship coordinates (`PlayerShip/Muzzle`). Required.
@export var muzzle: Marker3D
## Holds the `Left` and `Right` anchor markers the Familiars sit on and fire from.
## Required.
@export var familiar_anchors: Node3D
## The yaw shots and Familiars are rotated by, and the camera whose view they follow.
## Required.
@export var camera_rig: CameraRig
## One Familiar's visuals: a [Node3D] root with no [CollisionObject3D] anywhere
## (ENGINEERING_BRIEF 4.E). Required; a dev placeholder until D-02.
@export var familiar_scene: PackedScene

@export_group("Shots")
## Speed of every shot, in units per second.
@export var shot_speed: float = 60.0
## Seconds a shot lives: 1.2 at 60 units per second reaches 72, beyond the 60-unit lock
## range.
@export var shot_lifetime: float = 1.2
## Collision radius of a shot, in world units.
@export var shot_radius: float = 0.15
## Damage of a main shot.
@export var shot_damage: int = 1
## Damage of a Familiar shot.
@export var familiar_shot_damage: int = 1

@export_group("Cadence and Aim Assist")
## Seconds between main shots while fire is held.
@export var main_interval: float = 0.1
## Seconds between each Familiar's shots at Power Level 2.
@export var familiar_interval_level_2: float = 0.25
## Seconds between each Familiar's shots at Power Level 3.
@export var familiar_interval_level_3: float = 0.15
## Aim Assist cone of the main shot, in degrees from the view direction.
@export var main_assist_degrees: float = 10.0
## Aim Assist cone of a Familiar shot at Power Level 2, in degrees.
@export var familiar_assist_degrees_level_2: float = 10.0
## Aim Assist cone of a Familiar shot at Power Level 3, in degrees.
@export var familiar_assist_degrees_level_3: float = 20.0
## Aim Assist cone of the main shot under a Target Lock, in degrees, measured from the
## camera between the view direction and the locked target: wide enough to cover the lock
## framing, which keeps the target off the view center (F6-04). Familiar cones widen by the
## same margin over [member main_assist_degrees]. Claude's proposal; Astra tunes it.
@export var lock_assist_degrees: float = 25.0

@export_group("Bomb")
## Radius around the Core, in world units, of a Bomb's hostile clear and enemy damage.
## Claude's proposal; Astra tunes it.
@export var bomb_radius: float = 10.0
## Damage a Bomb deals to every enemy in range. Claude's proposal; it must stay below
## the smallest boss Phase health (F12).
@export var bomb_damage: int = 20
## The blast visual, a [BombBlast] scene the Session instances at the Core for each Bomb;
## `scenes/dev/bomb_blast.tscn`, which wraps D-02's blast. Optional: unset shows nothing.
@export var bomb_visual_scene: PackedScene

var _model := WeaponModel.new()
## Null until [method setup].
var _combat_state: CombatState
var _projectile_system: ProjectileSystem
var _targeting: Targeting
## The locked target's `HitVolume`, or the target itself when it has none; null when
## nothing is locked, invalid once the target is freed.
var _target_point: Node3D
var _fire_enabled: bool = false
## Whether the `bomb` button is down, from its events.
var _bomb_held: bool = false
## The ship this node belongs to: the origin of every shot.
var _ship: Node3D
## `Left` and `Right`, in [enum WeaponModel.Source] order after MAIN.
var _anchors: Array[Marker3D] = []
var _familiars: Array[Node3D] = []
var _orbit_time: float = 0.0
## Reused for every shot; the field copies it.
var _request := ProjectileSpawn.new()


func _ready() -> void:
	_ship = get_parent() as Node3D
	process_physics_priority = PHYSICS_PRIORITY
	if not _validate_setup():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	var tuning := WeaponModel.Tuning.new()
	tuning.main_interval = main_interval
	tuning.familiar_interval_level_2 = familiar_interval_level_2
	tuning.familiar_interval_level_3 = familiar_interval_level_3
	tuning.main_assist_degrees = main_assist_degrees
	tuning.familiar_assist_degrees_level_2 = familiar_assist_degrees_level_2
	tuning.familiar_assist_degrees_level_3 = familiar_assist_degrees_level_3
	_model.configure(tuning)
	for anchor: Marker3D in _anchors:
		var familiar := familiar_scene.instantiate() as Node3D
		# Placed in code every frame, so the ship's own transform must not move it too.
		familiar.top_level = true
		familiar.hide()
		anchor.add_child(familiar)
		_familiars.append(familiar)
	_request.faction = ProjectileSpawn.Faction.PLAYER


func _unhandled_input(event: InputEvent) -> void:
	if not _fire_enabled:
		return
	if event.is_action_pressed(&"bomb"):
		_bomb_held = true
	elif event.is_action_released(&"bomb"):
		_bomb_held = false


func _physics_process(delta: float) -> void:
	if _combat_state == null or not _fire_enabled:
		return
	var shots := _model.tick(delta, Input.is_action_pressed(&"fire"), _combat_state.get_power_level())
	if not shots.is_empty():
		_fire(shots)
	_combat_state.update_bomb_input(_bomb_held)


## A ship leaving the tree lets go of the Session-lifetime [CombatState] and of its
## [Targeting] at once, before it is freed; the next [method setup] connects again.
func _exit_tree() -> void:
	_disconnect()


func _process(delta: float) -> void:
	if _familiars.is_empty() or not _familiars[0].visible:
		return
	_orbit_time += delta
	_place_familiars()


## Arms the weapon for a new ship: shots through [param projectile_system] at
## [param combat_state]'s Power Level, Aim Assist toward [param targeting]'s lock, and the
## Bomb button fed to [param combat_state]. Replaces any earlier setup without connecting
## twice, resets the cadence, shows the Familiars for the current level and enables fire.
func setup(combat_state: CombatState, projectile_system: ProjectileSystem, targeting: Targeting) -> void:
	_disconnect()
	_combat_state = combat_state
	_projectile_system = projectile_system
	_targeting = targeting
	_combat_state.power_changed.connect(_on_power_changed)
	_targeting.target_changed.connect(_on_target_changed)
	_on_target_changed(_targeting.get_current_target())
	_model.reset()
	_show_familiars(_combat_state.get_power_level())
	set_fire_enabled(true)


## Lets the weapon fire and feed the Bomb button, or stops both. Disabling forgets the
## held Bomb button, so a press must be seen again. [PlayerController] calls it with its
## controls, so pause, defeat and transitions stop firing too.
func set_fire_enabled(enabled: bool) -> void:
	_fire_enabled = enabled
	if not enabled:
		_bomb_held = false


## The single fire path: every shot of this tick becomes one player Projectile, and
## [signal shots_fired] reports how many the field took.
##
## "Forward" is toward the point the view's center ray reaches at the locked target's
## depth along the view, or at the shot's range with no lock, rather than the camera's
## own axis: the camera sits behind and above the Muzzle. The point always stays at least
## [constant MIN_AIM_AHEAD] ahead of the shot's origin.
##
## Aim Assist under a Target Lock (F6-04) is measured from the camera, not from the shot:
## the angle between the view direction and the locked target, against the shot's cone
## widened by `lock_assist_degrees - main_assist_degrees`. `CameraRig` frames the ship and
## the target together, so the target sits off the view center, and seen from the Muzzle a
## close target was outside a 10-degree cone. Inside the widened cone the shot flies from
## its origin straight at the target; outside it, along "forward". With no lock there is
## no assist.
func _fire(shots: Array[WeaponModel.Shot]) -> void:
	var yaw := Basis(Vector3.UP, camera_rig.get_yaw())
	var eye := camera_rig.camera.global_position
	var view := -camera_rig.camera.global_basis.z
	# A target leaving the tree before it is freed has no global position to read.
	var aiming := is_instance_valid(_target_point) and _target_point.is_inside_tree()
	var target := _target_point.global_position if aiming else Vector3.ZERO
	var depth := (target - eye).dot(view) if aiming else shot_speed * shot_lifetime
	var lock_degrees := rad_to_deg(view.angle_to(target - eye)) if aiming else INF
	var lock_widening := lock_assist_degrees - main_assist_degrees
	var spawned := 0
	for shot: WeaponModel.Shot in shots:
		var offset := muzzle.position
		var damage := shot_damage
		if shot.source != WeaponModel.Source.MAIN:
			offset = _anchor_offset(shot.source - WeaponModel.Source.FAMILIAR_LEFT)
			damage = familiar_shot_damage
		var origin := _ship.global_position + yaw * offset
		var shot_depth := maxf(depth, (origin - eye).dot(view) + MIN_AIM_AHEAD)
		var direction := (eye + view * shot_depth - origin).normalized()
		var to_target := target - origin
		if lock_degrees <= shot.assist_degrees + lock_widening and not to_target.is_zero_approx():
			direction = to_target.normalized()
		_request.position = origin
		_request.velocity = direction * shot_speed
		_request.lifetime = shot_lifetime
		_request.radius = shot_radius
		_request.damage = damage
		if _projectile_system.spawn(_request) != ProjectileField.NO_PROJECTILE:
			spawned += 1
	if spawned > 0:
		shots_fired.emit(spawned)


## Anchor [param index] (0 left, 1 right) in ship coordinates, before the yaw.
func _anchor_offset(index: int) -> Vector3:
	return familiar_anchors.transform * _anchors[index].position


func _show_familiars(power_level: int) -> void:
	var shown := _model.familiar_count(power_level) > 0
	for familiar: Node3D in _familiars:
		familiar.visible = shown
	# Placed at once, so a Familiar never shows a frame at its unplaced transform.
	if shown:
		_place_familiars()


## Each Familiar at its yaw-rotated anchor, on a small orbit around it.
func _place_familiars() -> void:
	var yaw := Basis(Vector3.UP, camera_rig.get_yaw())
	for index: int in _familiars.size():
		var angle := TAU * FAMILIAR_ORBIT_TURNS_PER_SECOND * _orbit_time + PI * index
		var orbit := Vector3(cos(angle), sin(angle), 0.0) * FAMILIAR_ORBIT_RADIUS
		var point := _ship.global_position + yaw * (_anchor_offset(index) + orbit)
		_familiars[index].global_transform = Transform3D(yaw, point)


func _disconnect() -> void:
	if _combat_state != null and _combat_state.power_changed.is_connected(_on_power_changed):
		_combat_state.power_changed.disconnect(_on_power_changed)
	# The weapon may outlive a Targeting that was freed; a freed one has no connections.
	if is_instance_valid(_targeting) and _targeting.target_changed.is_connected(_on_target_changed):
		_targeting.target_changed.disconnect(_on_target_changed)


func _on_power_changed(level: int, _progress: int) -> void:
	_show_familiars(level)


func _on_target_changed(target: Node3D) -> void:
	if target == null:
		_target_point = null
		return
	var hit_volume := target.get_node_or_null(Targeting.HIT_VOLUME_PATH) as Node3D
	_target_point = hit_volume if hit_volume != null else target


## Reports what is missing with this node's path (CONVENTIONS "Setup errors are loud")
## and returns whether the adapter may run at all.
func _validate_setup() -> bool:
	var missing: PackedStringArray = []
	if muzzle == null:
		missing.append("muzzle")
	if familiar_anchors == null:
		missing.append("familiar_anchors")
	if camera_rig == null:
		missing.append("camera_rig")
	if familiar_scene == null:
		missing.append("familiar_scene")
	for field: String in missing:
		push_error("%s: required export '%s' is not set" % [get_path(), field])
	var configured := missing.is_empty()
	if _ship == null:
		push_error("%s: PlayerWeapon must be a child of the Node3D ship it fires from" % get_path())
		configured = false
	if familiar_anchors != null:
		for anchor_name: StringName in ANCHOR_NAMES:
			var anchor := familiar_anchors.get_node_or_null(NodePath(String(anchor_name))) as Marker3D
			if anchor == null:
				push_error("%s: %s has no Marker3D '%s'" % [get_path(), familiar_anchors.get_path(), anchor_name])
				configured = false
			else:
				_anchors.append(anchor)
	if familiar_scene != null and configured:
		var probe := familiar_scene.instantiate()
		if not probe is Node3D or probe is CollisionObject3D or not probe.find_children("*", "CollisionObject3D", true, false).is_empty():
			push_error("%s: 'familiar_scene' %s must have a Node3D root and no CollisionObject3D (ENGINEERING_BRIEF 4.E)" % [
				get_path(), familiar_scene.resource_path,
			])
			configured = false
		probe.free()
	return configured
