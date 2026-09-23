extends TestCase
## Contract smoke test of the [Hud] adapter on `scenes/ui/hud.tscn`: the GUIDE Section 15
## player panel shows a bound [CombatState] and follows its changes, binding twice never
## connects twice, unbinding lets go of everything, the HUD never changes a combat value,
## and the target marker sits on the projected target and hides when there is no lock, the
## target is freed, or it is behind the camera.
##
## Expected values come from GUIDE Section 15 (paths and binding duties), the CombatState
## contract in `docs/engineering/combat-hud.md` (entry values, hit and Bomb rules) and the
## F4-02 ticket (dim Shield and Bomb icons, the full Power bar at the top level). A
## [Targeting] is driven by emitting its `target_changed` directly, as the ticket asks.


const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"
const PANEL_PATHS: Array[NodePath] = [
	^"PlayerStatus/HealthBar",
	^"PlayerStatus/HealthValue",
	^"PlayerStatus/Shield",
	^"PlayerStatus/Bomb1",
	^"PlayerStatus/Bomb2",
	^"PlayerStatus/PowerValue",
	^"PlayerStatus/PowerProgress",
	^"TargetMarker",
]
## Where the target's HitVolume sits relative to its root, so a marker on the root's
## position instead of the HitVolume's would be caught.
const HIT_VOLUME_OFFSET := Vector3(0.0, 1.5, 0.0)
## In front of the camera (which looks down -Z from the origin), off center on both axes.
const TARGET_IN_FRONT := Vector3(2.0, -1.0, -12.0)
## Behind the camera.
const TARGET_BEHIND := Vector3(0.0, 0.0, 12.0)
const MARKER_EPSILON := 0.01

var _hud: Hud
var _state: CombatState
var _world: Node3D
var _camera: Camera3D
var _targeting: Targeting
var _target: Node3D


func before_each() -> void:
	var packed := load(HUD_SCENE_PATH) as PackedScene
	if packed == null:
		return
	_hud = packed.instantiate() as Hud
	if _hud == null:
		return
	tree.root.add_child(_hud)
	_state = CombatState.new()
	_world = Node3D.new()
	_camera = Camera3D.new()
	_world.add_child(_camera)
	# The ship stand-in: Targeting measures distance from its parent.
	var ship := Node3D.new()
	_world.add_child(ship)
	_targeting = Targeting.new()
	_targeting.camera = _camera
	ship.add_child(_targeting)
	_target = Node3D.new()
	var hit_volume := Node3D.new()
	hit_volume.name = "HitVolume"
	hit_volume.position = HIT_VOLUME_OFFSET
	_target.add_child(hit_volume)
	_target.position = TARGET_IN_FRONT
	_world.add_child(_target)
	tree.root.add_child(_world)
	_camera.current = true
	await tree.process_frame


func after_each() -> void:
	for node: Node in [_hud, _world]:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.free()
	_hud = null
	_world = null
	_state = null


func test_hud_root_is_a_hud_with_every_section_15_path() -> void:
	if not assert_not_null(_hud, "%s has a Hud root" % HUD_SCENE_PATH):
		return
	assert_eq(String(_hud.name), "HUD")
	for path: NodePath in PANEL_PATHS:
		assert_not_null(_hud.get_node_or_null(path), "%s exists" % path)
	assert_false(_marker().visible, "the marker starts hidden")


func test_bind_renders_the_current_values() -> void:
	if not assert_not_null(_hud, "Hud"):
		return
	_state.start(2)
	_bind()
	assert_eq(_label(^"PlayerStatus/PowerValue").text, "2")
	assert_almost_eq(_bar(^"PlayerStatus/HealthBar").value, 100.0)
	assert_eq(_label(^"PlayerStatus/HealthValue").text, "100%")
	assert_almost_eq(_bar(^"PlayerStatus/PowerProgress").value, 0.0)
	for path: NodePath in [^"PlayerStatus/Shield", ^"PlayerStatus/Bomb1", ^"PlayerStatus/Bomb2"]:
		assert_eq(_icon(path).modulate, _hud.lit_modulate, "%s lit" % path)


## The panel shows what the state has before the HUD is bound, not the authored examples.
func test_bind_renders_values_that_differ_from_the_authored_ones() -> void:
	if not assert_not_null(_hud, "Hud"):
		return
	_state.start(1)
	_state.take_hit()
	_state.tick(CombatState.HIT_INVULNERABILITY)
	_state.take_hit()
	_state.update_bomb_input(false)
	_state.update_bomb_input(true)
	_bind()
	assert_eq(_label(^"PlayerStatus/HealthValue").text, "90%")
	assert_eq(_icon(^"PlayerStatus/Shield").modulate, _hud.dim_modulate, "Shield spent")
	assert_eq(_icon(^"PlayerStatus/Bomb1").modulate, _hud.lit_modulate, "one Bomb left")
	assert_eq(_icon(^"PlayerStatus/Bomb2").modulate, _hud.dim_modulate, "the second spent")


func test_hits_and_bombs_update_the_panel() -> void:
	if not assert_not_null(_hud, "Hud"):
		return
	_state.start(1)
	_bind()
	_state.take_hit()
	assert_eq(_icon(^"PlayerStatus/Shield").modulate, _hud.dim_modulate, "the Shield took the hit")
	assert_eq(_label(^"PlayerStatus/HealthValue").text, "100%", "Health untouched by a shielded hit")
	_state.tick(CombatState.HIT_INVULNERABILITY)
	_state.take_hit()
	assert_almost_eq(_bar(^"PlayerStatus/HealthBar").value, 90.0)
	assert_eq(_label(^"PlayerStatus/HealthValue").text, "90%")
	_state.update_bomb_input(false)
	assert_true(_state.update_bomb_input(true), "a Bomb went off")
	assert_eq(_icon(^"PlayerStatus/Bomb1").modulate, _hud.lit_modulate, "one Bomb left")
	assert_eq(_icon(^"PlayerStatus/Bomb2").modulate, _hud.dim_modulate, "the second slot spent")
	_state.update_bomb_input(false)
	assert_true(_state.update_bomb_input(true), "the second Bomb went off")
	assert_eq(_icon(^"PlayerStatus/Bomb1").modulate, _hud.dim_modulate, "no Bombs left")


func test_power_progress_and_the_full_bar_at_max_level() -> void:
	if not assert_not_null(_hud, "Hud"):
		return
	_state.start(1)
	_bind()
	for _pickup: int in 3:
		_state.collect_power_pickup()
	assert_eq(_label(^"PlayerStatus/PowerValue").text, "1")
	assert_almost_eq(_bar(^"PlayerStatus/PowerProgress").value, 3.0, 0.0001, "three of five")
	for _pickup: int in 2:
		_state.collect_power_pickup()
	assert_eq(_label(^"PlayerStatus/PowerValue").text, "2", "five Pickups raise the level")
	assert_almost_eq(_bar(^"PlayerStatus/PowerProgress").value, 0.0, 0.0001, "progress starts over")
	for _pickup: int in CombatState.PICKUPS_PER_LEVEL:
		_state.collect_power_pickup()
	var progress := _bar(^"PlayerStatus/PowerProgress")
	assert_eq(_label(^"PlayerStatus/PowerValue").text, "3")
	assert_eq(_state.get_power_progress(), 0, "the core holds no progress at the top level")
	assert_almost_eq(progress.value, progress.max_value, 0.0001, "the bar is full at Power Level 3")
	_hud.unbind()
	_bind()
	assert_almost_eq(progress.value, progress.max_value, 0.0001, "and full when bound at Power Level 3")


func test_rebinding_never_double_connects() -> void:
	if not assert_not_null(_hud, "Hud"):
		return
	_bind()
	_bind()
	for signal_name: StringName in [&"health_changed", &"shield_changed", &"bombs_changed", &"power_changed"]:
		assert_eq(_connections_to_hud(_state, signal_name), 1, "%s connected once" % signal_name)
	assert_eq(_connections_to_hud(_targeting, &"target_changed"), 1, "target_changed connected once")


func test_unbind_disconnects_and_hides_the_marker() -> void:
	if not assert_not_null(_hud, "Hud"):
		return
	_bind()
	_targeting.target_changed.emit(_target)
	assert_true(_marker().visible, "a lock shows the marker")
	_hud.unbind()
	for signal_name: StringName in [&"health_changed", &"shield_changed", &"bombs_changed", &"power_changed"]:
		assert_eq(_connections_to_hud(_state, signal_name), 0, "%s disconnected" % signal_name)
	assert_eq(_connections_to_hud(_targeting, &"target_changed"), 0, "target_changed disconnected")
	assert_false(_marker().visible, "the marker is hidden")
	_state.start(1)
	_state.take_hit()
	assert_eq(_icon(^"PlayerStatus/Shield").modulate, _hud.lit_modulate, "later changes are not shown")
	await tree.process_frame
	assert_false(_marker().visible, "and stays hidden")
	_hud.unbind()
	assert_false(_marker().visible, "a second unbind is safe")


## ENGINEERING_BRIEF 4.I: the HUD observes and never mutates.
func test_hud_never_changes_the_combat_state() -> void:
	if not assert_not_null(_hud, "Hud"):
		return
	_state.start(2)
	_state.take_hit()
	var before := _state.capture()
	var getters_before := _getters()
	_bind()
	_state.health_changed.emit(40)
	_state.shield_changed.emit(true)
	_state.bombs_changed.emit(0)
	_state.power_changed.emit(3, 0)
	_targeting.target_changed.emit(_target)
	for _frame: int in 10:
		await tree.process_frame
	assert_eq(_state.capture(), before, "the Snapshot slice is unchanged")
	assert_eq(_getters(), getters_before, "every getter is unchanged")


func test_marker_centers_on_the_projected_target() -> void:
	if not assert_not_null(_hud, "Hud"):
		return
	_bind()
	_targeting.target_changed.emit(_target)
	var marker := _marker()
	assert_true(marker.visible, "a target in front of the camera is marked")
	var point := _target.get_node("HitVolume") as Node3D
	var expected := _camera.unproject_position(point.global_position)
	var center := marker.position + marker.size * 0.5
	assert_true(center.distance_to(expected) < MARKER_EPSILON, "centered on the HitVolume, %s vs %s" % [center, expected])
	var off_center := expected - _hud.get_viewport_rect().size * 0.5
	assert_true(off_center.x > 0.0 and off_center.y < 0.0, "right of and above the screen center, %s" % off_center)
	var root_point := _camera.unproject_position(_target.global_position)
	assert_true(center.distance_to(root_point) > 1.0, "on the HitVolume, not on the target's root")
	_target.position = TARGET_IN_FRONT + Vector3(-4.0, 0.0, 0.0)
	await tree.process_frame
	expected = _camera.unproject_position(point.global_position)
	center = marker.position + marker.size * 0.5
	assert_true(center.distance_to(expected) < MARKER_EPSILON, "follows a moving target, %s vs %s" % [center, expected])


func test_marker_hides_behind_the_camera() -> void:
	if not assert_not_null(_hud, "Hud"):
		return
	_bind()
	_targeting.target_changed.emit(_target)
	assert_true(_marker().visible)
	_target.position = TARGET_BEHIND
	await tree.process_frame
	assert_false(_marker().visible, "a target behind the camera is not marked")
	_target.position = TARGET_IN_FRONT
	await tree.process_frame
	assert_true(_marker().visible, "and is marked again in front of it")


func test_marker_hides_on_release_and_when_the_target_is_freed() -> void:
	if not assert_not_null(_hud, "Hud"):
		return
	_bind()
	_targeting.target_changed.emit(_target)
	assert_true(_marker().visible)
	_targeting.target_changed.emit(null)
	assert_false(_marker().visible, "a release hides the marker at once")
	_targeting.target_changed.emit(_target)
	assert_true(_marker().visible)
	_target.free()
	await tree.process_frame
	assert_false(_marker().visible, "a freed target is not marked")


func _bind() -> void:
	_hud.bind(_state, _targeting, _camera)


func _marker() -> Control:
	return _hud.get_node(^"TargetMarker") as Control


func _label(path: NodePath) -> Label:
	return _hud.get_node(path) as Label


func _bar(path: NodePath) -> ProgressBar:
	return _hud.get_node(path) as ProgressBar


func _icon(path: NodePath) -> CanvasItem:
	return _hud.get_node(path) as CanvasItem


## How many connections of [param source]'s [param signal_name] reach the HUD.
func _connections_to_hud(source: Object, signal_name: StringName) -> int:
	var count := 0
	for connection: Dictionary in source.get_signal_connection_list(signal_name):
		if (connection["callable"] as Callable).get_object() == _hud:
			count += 1
	return count


func _getters() -> Array:
	return [
		_state.get_health(), _state.has_shield(), _state.get_bombs(), _state.get_power_level(),
		_state.get_power_progress(), _state.is_invulnerable(), _state.is_defeated(), _state.is_paused(),
	]
