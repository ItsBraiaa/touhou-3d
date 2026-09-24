class_name Hud
extends Control
## Adapter on the combat HUD root, `scenes/ui/hud.tscn` (GUIDE Section 15): renders the
## player panel from a [CombatState] and keeps the target marker on the locked target
## that [Targeting] reports. It also shows what bosses and encounters tell it: the
## segmented boss bar with a short name, a brief attack-name cue, and the left and right
## threat indicators. Since F16-05 it shows the ship's dash cooldown on Astra's `Impulso`
## indicator, `DashCooldown`, which never looks ready while the dash cannot start.
##
## It observes and never decides: the panel is redrawn from the core's change signals
## and read-only getters, and no [CombatState] method other than a getter is ever called
## here (ENGINEERING_BRIEF 4.I). It owns no boss or threat rule either; the caller says
## which bar is which and for how long a cue or a threat shows. The Session calls
## [method bind] for every new ship and [method unbind] before freeing it. The HUD lives
## under `Interface`, which processes while the tree is paused, so the marker keeps
## following a paused camera; the cue and threat timers stand still while the tree is
## paused (PLANEJAMENTO Section 7).


## GUIDE Section 15 paths, relative to this root. Each one is load-bearing.
const HEALTH_BAR_PATH := ^"PlayerStatus/HealthBar"
const HEALTH_VALUE_PATH := ^"PlayerStatus/HealthValue"
const SHIELD_PATH := ^"PlayerStatus/Shield"
const BOMB_1_PATH := ^"PlayerStatus/Bomb1"
const BOMB_2_PATH := ^"PlayerStatus/Bomb2"
const POWER_VALUE_PATH := ^"PlayerStatus/PowerValue"
const POWER_PROGRESS_PATH := ^"PlayerStatus/PowerProgress"
const TARGET_MARKER_PATH := ^"TargetMarker"
const BOSS_STATUS_PATH := ^"BossStatus"
const BOSS_NAME_PATH := ^"BossStatus/BossName"
## One bar per Phase, in Phase order.
const PHASE_BAR_PATHS: Array[NodePath] = [^"BossStatus/Phase1", ^"BossStatus/Phase2", ^"BossStatus/Phase3"]
const ATTACK_NAME_PATH := ^"AttackName"
const THREAT_LEFT_PATH := ^"ThreatLeft"
const THREAT_RIGHT_PATH := ^"ThreatRight"
## The Impulso indicator, an instance of `scenes/ui/components/dash_cooldown.tscn`
## (F16-05).
const DASH_COOLDOWN_PATH := ^"DashCooldown"
const DASH_LABEL_PATH := ^"DashCooldown/Label"
const DASH_PROGRESS_PATH := ^"DashCooldown/Progress"
const DASH_READY_ACCENT_PATH := ^"DashCooldown/ReadyAccent"
## Phases a boss bar shows: two for the Tempest Sentinel, three for a final boss
## (STAGE_DESIGN).
const MIN_PHASES := 2
const MAX_PHASES := 3
## The Impulso label while the dash is ready, while it cools down (with the seconds left,
## a decimal comma, rounded up), and while the ship's controls are off. Astra's F16-01
## copy for the first two.
const DASH_READY_TEXT := "IMPULSO  ·  PRONTO"
const DASH_COOLDOWN_TEXT := "IMPULSO  ·  %s s"
const DASH_DISABLED_TEXT := "IMPULSO"

@export_group("Presentation")
## Modulate of the Shield, a Bomb icon or a boss Phase bar while it is available.
@export var lit_modulate: Color = Color(1, 1, 1, 1)
## Modulate of the Shield and a Bomb icon while it is spent, and of the whole Impulso
## indicator while the ship's controls are off. Claude's proposal; Astra tunes it.
@export var dim_modulate: Color = Color(1, 1, 1, 0.25)
## Modulate of a boss Phase bar once that Phase is at 0. Claude's proposal; Astra tunes it.
@export var completed_phase_modulate: Color = Color(1, 1, 1, 0.3)

## Null while unbound.
var _combat_state: CombatState
var _targeting: Targeting
var _camera: Camera3D
var _player: PlayerController
## Node the marker projects: the locked target's `HitVolume`, as [Targeting] measures
## it, or the target itself when it has none. Null while nothing is locked; a freed
## target leaves it invalid, never null.
var _marker_point: Node3D
## Phases the boss bar shows; 0 while it is hidden.
var _phase_count: int = 0
## Seconds left on the attack cue, and on the left and right threats, while each shows.
var _cue_remaining: float = 0.0
var _threat_remaining: Array[float] = [0.0, 0.0]

var _health_bar: ProgressBar
var _health_value: Label
var _shield: CanvasItem
var _bomb_1: CanvasItem
var _bomb_2: CanvasItem
var _power_value: Label
var _power_progress: ProgressBar
var _target_marker: Control
var _boundary_vignette: ColorRect
var _vignette_tween: Tween
var _boss_status: CanvasItem
var _boss_name: Label
var _phase_bars: Array[ProgressBar] = []
var _authored_phase_offsets: Array[Vector2] = []
var _attack_name: Label
## Left, then right, as the `side` of [method show_threat] picks them.
var _threats: Array[CanvasItem] = []
var _dash_cooldown: CanvasItem
var _dash_label: Label
var _dash_progress: ProgressBar
var _dash_ready_accent: CanvasItem
## What the Impulso indicator shows: the ship's cooldown left and total, in seconds, and
## whether it can dash, that is its controls are on and it has a dash
## ([method PlayerController.has_dash]). Unbound, it cannot.
var _dash_cooldown_left: float = 0.0
var _dash_cooldown_total: float = 0.0
var _dash_enabled: bool = false
## False when a Section 15 path is missing: every method then does nothing.
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
	_create_boundary_vignette()
	_boss_status = _require(BOSS_STATUS_PATH) as CanvasItem
	_boss_name = _require(BOSS_NAME_PATH) as Label
	for path: NodePath in PHASE_BAR_PATHS:
		var bar: ProgressBar = _require(path) as ProgressBar
		_phase_bars.append(bar)
		if bar != null:
			_authored_phase_offsets.append(Vector2(bar.offset_left, bar.offset_right))
	_attack_name = _require(ATTACK_NAME_PATH) as Label
	_threats.append(_require(THREAT_LEFT_PATH) as CanvasItem)
	_threats.append(_require(THREAT_RIGHT_PATH) as CanvasItem)
	_dash_cooldown = _require(DASH_COOLDOWN_PATH) as CanvasItem
	_dash_label = _require(DASH_LABEL_PATH) as Label
	_dash_progress = _require(DASH_PROGRESS_PATH) as ProgressBar
	_dash_ready_accent = _require(DASH_READY_ACCENT_PATH) as CanvasItem
	var nodes: Array[Object] = [
		_health_bar, _health_value, _shield, _bomb_1, _bomb_2, _power_value, _power_progress,
		_target_marker, _boss_status, _boss_name, _attack_name,
		_dash_cooldown, _dash_label, _dash_progress, _dash_ready_accent,
	]
	nodes.append_array(_phase_bars)
	nodes.append_array(_threats)
	_configured = not nodes.has(null)
	if not _configured:
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_render_dash()


func _process(delta: float) -> void:
	_update_target_marker()
	if get_tree().paused:
		return
	if _attack_name.visible:
		_cue_remaining -= delta
		if _cue_remaining <= 0.0:
			_hide_attack_cue()
	for index: int in _threats.size():
		if _threats[index].visible:
			_threat_remaining[index] -= delta
			if _threat_remaining[index] <= 0.0:
				_hide_threat(index)


## Shows [param combat_state] on the player panel and follows the lock of
## [param targeting], projecting through [param camera]. Replaces any earlier binding,
## so binding again never connects twice, and clears the boss panel and the threats.
## Renders the current values at once. When [param targeting]'s parent is the
## [PlayerController], its edge proximity and its dash cooldown and controls are shown
## too; without one the Impulso indicator stays unavailable.
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
	_player = _targeting.get_parent() as PlayerController
	if _player != null:
		_player.edge_proximity_changed.connect(_on_edge_proximity_changed)
		_player.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
		_player.controls_enabled_changed.connect(_on_controls_enabled_changed)
		_dash_cooldown_left = _player.get_dash_cooldown_left()
		_dash_cooldown_total = _player.dash_cooldown
		_dash_enabled = _player.are_controls_enabled() and _player.has_dash()
	_render_dash()
	_on_health_changed(_combat_state.get_health())
	_on_shield_changed(_combat_state.has_shield())
	_on_bombs_changed(_combat_state.get_bombs())
	_on_power_changed(_combat_state.get_power_level(), _combat_state.get_power_progress())
	_on_target_changed(_targeting.get_current_target())


## Disconnects everything [method bind] connected, forgets the three collaborators and
## hides the target marker, the boss panel, the cue and both threats, so a stage unload
## leaves nothing on screen. Safe while unbound, and after the ship has been freed.
func unbind() -> void:
	if _combat_state != null:
		_combat_state.health_changed.disconnect(_on_health_changed)
		_combat_state.shield_changed.disconnect(_on_shield_changed)
		_combat_state.bombs_changed.disconnect(_on_bombs_changed)
		_combat_state.power_changed.disconnect(_on_power_changed)
	# The HUD outlives every ship; a freed Targeting has already dropped its connections.
	if is_instance_valid(_targeting):
		_targeting.target_changed.disconnect(_on_target_changed)
	if is_instance_valid(_player):
		_player.edge_proximity_changed.disconnect(_on_edge_proximity_changed)
		_player.dash_cooldown_changed.disconnect(_on_dash_cooldown_changed)
		_player.controls_enabled_changed.disconnect(_on_controls_enabled_changed)
	_combat_state = null
	_targeting = null
	_camera = null
	_player = null
	_marker_point = null
	_dash_cooldown_left = 0.0
	_dash_enabled = false
	if not _configured:
		return
	_target_marker.hide()
	hide_boss()
	for index: int in _threats.size():
		_hide_threat(index)
	_set_vignette_strength(0.0)
	_render_dash()


## Shows the boss bar named [param display_name] (already in Portuguese, from the boss
## Definition) with [param phase_count] Phase bars, each full and lit; the other bars are
## hidden and keep their authored positions. A [param phase_count] outside
## [constant MIN_PHASES]..[constant MAX_PHASES] is reported and clamped. Calling it again
## replaces the boss shown.
func show_boss(display_name: String, phase_count: int) -> void:
	if not _configured:
		return
	if phase_count < MIN_PHASES or phase_count > MAX_PHASES:
		push_error("%s: show_boss('%s', %d): a boss has %d or %d Phases; clamped" % [
			get_path(), display_name, phase_count, MIN_PHASES, MAX_PHASES,
		])
	_phase_count = clampi(phase_count, MIN_PHASES, MAX_PHASES)
	_boss_name.text = display_name
	for index: int in _phase_bars.size():
		_reset_phase_bar(index)
		_phase_bars[index].visible = index < _phase_count
		if index < 2 and _phase_count == 2:
			_phase_bars[index].offset_left = float(_phase_bars[index].get_meta(&"two_phase_offset_left"))
			_phase_bars[index].offset_right = float(_phase_bars[index].get_meta(&"two_phase_offset_right"))
		else:
			_phase_bars[index].offset_left = _authored_phase_offsets[index].x
			_phase_bars[index].offset_right = _authored_phase_offsets[index].y
	_boss_status.show()


## Sets Phase [param phase_index] (0-based) to [param ratio] of its health, clamped to
## 0..1. A Phase at 0 is dimmed with [member completed_phase_modulate], and lit again if
## the boss raises it. The boss says what each bar holds; the HUD infers no Phase order.
## An index outside the Phases shown is reported and ignored.
func set_phase_health(phase_index: int, ratio: float) -> void:
	if not _configured:
		return
	if phase_index < 0 or phase_index >= _phase_count:
		push_error("%s: set_phase_health(%d): the boss bar shows %d Phases; ignored" % [
			get_path(), phase_index, _phase_count,
		])
		return
	var bar := _phase_bars[phase_index]
	bar.value = clampf(ratio, 0.0, 1.0) * bar.max_value
	bar.modulate = completed_phase_modulate if is_zero_approx(bar.value) else lit_modulate


## Shows [param text] (a Portuguese attack name from the caller) as the attack cue for
## [param seconds] of unpaused time. A new cue replaces the text and restarts the timer.
func show_attack_cue(text: String, seconds: float) -> void:
	if not _configured:
		return
	_attack_name.text = text
	_attack_name.show()
	_cue_remaining = seconds


## Hides the boss bar and the attack cue, and resets every Phase bar to full and lit.
func hide_boss() -> void:
	if not _configured:
		return
	_phase_count = 0
	_boss_status.hide()
	for index: int in _phase_bars.size():
		_reset_phase_bar(index)
	_hide_attack_cue()


## Shows the threat indicator on [param side], -1 for left and +1 for right, for
## [param seconds] of unpaused time. A repeated report while it shows extends its timer
## to the longer of the two; each side has its own. Any other side is reported and
## ignored.
func show_threat(side: int, seconds: float) -> void:
	if not _configured:
		return
	if side != -1 and side != 1:
		push_error("%s: show_threat(%d): side is -1 (left) or +1 (right); ignored" % [get_path(), side])
		return
	var index := 0 if side < 0 else 1
	_threat_remaining[index] = maxf(_threat_remaining[index], seconds)
	_threats[index].show()


## The marker follows an on-screen target, or clamps to the nearest screen edge and points
## toward a locked target that is off-screen or behind the camera.
func _update_target_marker() -> void:
	if not is_instance_valid(_marker_point) or not is_instance_valid(_camera):
		_target_marker.hide()
		return
	var point := _marker_point.global_position
	var projected := _camera.unproject_position(point)
	var viewport_size := get_viewport_rect().size
	var center := viewport_size * 0.5
	var direction := projected - center
	var margin := maxf(_target_marker.size.x, _target_marker.size.y) * 0.5 + 12.0
	var bounds := Rect2(Vector2(margin, margin), viewport_size - Vector2.ONE * margin * 2.0)
	var on_screen := not _camera.is_position_behind(point) and bounds.has_point(projected)
	if on_screen:
		_target_marker.position = projected - _target_marker.size * 0.5
		_target_marker.rotation = 0.0
	else:
		if direction.length_squared() < 0.01:
			direction = Vector2.UP
		var scale := minf(bounds.size.x / (absf(direction.x) * 2.0), bounds.size.y / (absf(direction.y) * 2.0))
		if is_inf(scale) or is_nan(scale):
			scale = 1.0
		var edge := center + direction * scale
		edge.x = clampf(edge.x, bounds.position.x, bounds.end.x)
		edge.y = clampf(edge.y, bounds.position.y, bounds.end.y)
		_target_marker.position = edge - _target_marker.size * 0.5
		_target_marker.rotation = direction.angle() + PI * 0.5
	_target_marker.show()


func _create_boundary_vignette() -> void:
	_boundary_vignette = ColorRect.new()
	_boundary_vignette.name = "BoundaryVignette"
	_boundary_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boundary_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boundary_vignette.modulate.a = 0.0
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\n" + \
		"void fragment() { vec2 edge = min(UV, vec2(1.0) - UV); " + \
		"float amount = 1.0 - smoothstep(0.0, 0.2, min(edge.x, edge.y)); " + \
		"COLOR = vec4(0.12, 0.62, 0.68, amount * 0.42); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	_boundary_vignette.material = material
	add_child(_boundary_vignette)
	move_child(_boundary_vignette, 0)


func _on_edge_proximity_changed(value: float) -> void:
	_set_vignette_strength(clampf(value, 0.0, 1.0))


func _on_dash_cooldown_changed(remaining: float, total: float) -> void:
	_dash_cooldown_left = remaining
	_dash_cooldown_total = total
	_render_dash()


func _on_controls_enabled_changed(enabled: bool) -> void:
	_dash_enabled = enabled and _player.has_dash()
	_render_dash()


## Draws the Impulso indicator in one of three states. Ready (controls on, a dash, no
## cooldown left): `PRONTO`, `Progress` full, `ReadyAccent` shown, lit. Cooling down: the
## seconds left, `Progress` filling from empty at activation to full, no accent.
## Unavailable (controls off, a ship without a dash, or no ship bound): the bare label, no
## accent, the whole indicator at [member dim_modulate], `Progress` held where the cooldown
## froze. Only the first can read as ready.
func _render_dash() -> void:
	var dash_ready := _dash_enabled and _dash_cooldown_left <= 0.0
	var filled := 1.0
	if _dash_cooldown_total > 0.0:
		filled = 1.0 - clampf(_dash_cooldown_left / _dash_cooldown_total, 0.0, 1.0)
	_dash_progress.value = filled * _dash_progress.max_value
	_dash_ready_accent.visible = dash_ready
	_dash_cooldown.modulate = lit_modulate if _dash_enabled else dim_modulate
	if not _dash_enabled:
		_dash_label.text = DASH_DISABLED_TEXT
	elif dash_ready:
		_dash_label.text = DASH_READY_TEXT
	else:
		_dash_label.text = DASH_COOLDOWN_TEXT % _format_tenths(_dash_cooldown_left)


## [param seconds] rounded up to a tenth with a decimal comma, "0,8" for 0.8, so a
## cooldown still running never reads "0,0". The small offset keeps a float residue from
## rounding a whole tenth up (0.30000000000000004 reads "0,3").
static func _format_tenths(seconds: float) -> String:
	var tenths := maxi(ceili(seconds * 10.0 - 0.001), 1)
	return ("%.1f" % (tenths / 10.0)).replace(".", ",")


func _set_vignette_strength(value: float) -> void:
	if _boundary_vignette == null:
		return
	if _vignette_tween != null:
		_vignette_tween.kill()
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_boundary_vignette, ^"modulate:a", value, 0.18)


func _reset_phase_bar(index: int) -> void:
	var bar := _phase_bars[index]
	bar.value = bar.max_value
	bar.modulate = lit_modulate


func _hide_attack_cue() -> void:
	_cue_remaining = 0.0
	_attack_name.hide()


func _hide_threat(index: int) -> void:
	_threat_remaining[index] = 0.0
	_threats[index].hide()


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
