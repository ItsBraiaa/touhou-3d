class_name Hud
extends Control
## Adapter on the combat HUD root, `scenes/ui/hud.tscn` (GUIDE Section 15): renders the
## player panel from a [CombatState] and keeps the target marker on the locked target
## that [Targeting] reports.
##
## It observes and never decides: the panel is redrawn from the core's change signals
## and read-only getters, and no [CombatState] method other than a getter is ever called
## here (ENGINEERING_BRIEF 4.I). The Session calls [method bind] for every new ship and
## [method unbind] before freeing it. The HUD lives under `Interface`, which processes
## while the tree is paused, so the marker keeps following a paused camera.


## GUIDE Section 15 paths, relative to this root. Each one is load-bearing.
const HEALTH_BAR_PATH := ^"PlayerStatus/HealthBar"
const HEALTH_VALUE_PATH := ^"PlayerStatus/HealthValue"
const SHIELD_PATH := ^"PlayerStatus/Shield"
const BOMB_1_PATH := ^"PlayerStatus/Bomb1"
const BOMB_2_PATH := ^"PlayerStatus/Bomb2"
const POWER_VALUE_PATH := ^"PlayerStatus/PowerValue"
const POWER_PROGRESS_PATH := ^"PlayerStatus/PowerProgress"
const TARGET_MARKER_PATH := ^"TargetMarker"

@export_group("Presentation")
## Modulate of the Shield and a Bomb icon while it is available.
@export var lit_modulate: Color = Color(1, 1, 1, 1)
## Modulate of the Shield and a Bomb icon while it is spent. Claude's proposal; Astra
## tunes it.
@export var dim_modulate: Color = Color(1, 1, 1, 0.25)

## Null while unbound.
var _combat_state: CombatState
var _targeting: Targeting
var _camera: Camera3D
## Node the marker projects: the locked target's `HitVolume`, as [Targeting] measures
## it, or the target itself when it has none. Null while nothing is locked; a freed
## target leaves it invalid, never null.
var _marker_point: Node3D

var _health_bar: ProgressBar
var _health_value: Label
var _shield: CanvasItem
var _bomb_1: CanvasItem
var _bomb_2: CanvasItem
var _power_value: Label
var _power_progress: ProgressBar
var _target_marker: Control
## False when a Section 15 path is missing: [method bind] then does nothing.
var _configured: bool = false


func _ready() -> void:
	_health_bar = _require(HEALTH_BAR_PATH) as ProgressBar
	_health_value = _require(HEALTH_VALUE_PATH) as Label
	_shield = _require(SHIELD_PATH) as CanvasItem
	_bomb_1 = _require(BOMB_1_PATH) as CanvasItem
	_bomb_2 = _require(BOMB_2_PATH) as CanvasItem
	_power_value = _require(POWER_VALUE_PATH) as Label
	_power_progress = _require(POWER_PROGRESS_PATH) as ProgressBar
	_target_marker = _require(TARGET_MARKER_PATH) as Control
	_configured = not [
		_health_bar, _health_value, _shield, _bomb_1, _bomb_2, _power_value, _power_progress, _target_marker,
	].has(null)
	if not _configured:
		process_mode = Node.PROCESS_MODE_DISABLED


func _process(_delta: float) -> void:
	_update_target_marker()


## Shows [param combat_state] on the player panel and follows the lock of
## [param targeting], projecting through [param camera]. Replaces any earlier binding,
## so binding again never connects twice. Renders the current values at once.
func bind(combat_state: CombatState, targeting: Targeting, camera: Camera3D) -> void:
	unbind()
	if not _configured:
		return
	_combat_state = combat_state
	_targeting = targeting
	_camera = camera
	_combat_state.health_changed.connect(_on_health_changed)
	_combat_state.shield_changed.connect(_on_shield_changed)
	_combat_state.bombs_changed.connect(_on_bombs_changed)
	_combat_state.power_changed.connect(_on_power_changed)
	_targeting.target_changed.connect(_on_target_changed)
	_on_health_changed(_combat_state.get_health())
	_on_shield_changed(_combat_state.has_shield())
	_on_bombs_changed(_combat_state.get_bombs())
	_on_power_changed(_combat_state.get_power_level(), _combat_state.get_power_progress())
	_on_target_changed(_targeting.get_current_target())


## Disconnects everything [method bind] connected, forgets the three collaborators and
## hides the target marker. Safe while unbound, and after the ship has been freed.
func unbind() -> void:
	if _combat_state != null:
		_combat_state.health_changed.disconnect(_on_health_changed)
		_combat_state.shield_changed.disconnect(_on_shield_changed)
		_combat_state.bombs_changed.disconnect(_on_bombs_changed)
		_combat_state.power_changed.disconnect(_on_power_changed)
	# The HUD outlives every ship; a freed Targeting has already dropped its connections.
	if is_instance_valid(_targeting):
		_targeting.target_changed.disconnect(_on_target_changed)
	_combat_state = null
	_targeting = null
	_camera = null
	_marker_point = null
	if _target_marker != null:
		_target_marker.hide()


## The marker is centered on the projected point, and hidden unless bound, locked on a
## live target and that target is in front of the camera.
func _update_target_marker() -> void:
	if not is_instance_valid(_marker_point) or not is_instance_valid(_camera):
		_target_marker.hide()
		return
	var point := _marker_point.global_position
	if _camera.is_position_behind(point):
		_target_marker.hide()
		return
	_target_marker.position = _camera.unproject_position(point) - _target_marker.size * 0.5
	_target_marker.show()


func _on_health_changed(health: int) -> void:
	var shown := clampi(health, 0, CombatState.MAX_HEALTH)
	_health_bar.value = shown
	_health_value.text = "%d%%" % shown


func _on_shield_changed(shielded: bool) -> void:
	_shield.modulate = lit_modulate if shielded else dim_modulate


func _on_bombs_changed(bombs: int) -> void:
	_bomb_1.modulate = lit_modulate if bombs >= 1 else dim_modulate
	_bomb_2.modulate = lit_modulate if bombs >= 2 else dim_modulate


## Power Progress is always 0 at the top level, so the bar is shown full there instead
## of empty.
func _on_power_changed(level: int, progress: int) -> void:
	_power_value.text = str(level)
	if level >= CombatState.MAX_POWER_LEVEL:
		_power_progress.value = _power_progress.max_value
	else:
		_power_progress.value = progress


func _on_target_changed(target: Node3D) -> void:
	if target == null:
		_marker_point = null
	else:
		var hit_volume := target.get_node_or_null(Targeting.HIT_VOLUME_PATH) as Node3D
		_marker_point = hit_volume if hit_volume != null else target
	_update_target_marker()


## The node at [param path], or null after reporting it with this node's path
## (CONVENTIONS "Setup errors are loud").
func _require(path: NodePath) -> Node:
	var node := get_node_or_null(path)
	if node == null:
		push_error("%s: required node '%s' (GUIDE Section 15) is missing" % [get_path(), path])
	return node
