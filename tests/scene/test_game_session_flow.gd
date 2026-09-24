extends TestCase
## Flow smoke test of [GameSession] on `Main` in `scenes/main.tscn`: menu actions start a
## Run by loading the stage and the ship under `WorldRoot`, `pause` freezes the tree, the
## ship and Active Time under the Pause overlay, Options from Pause keeps the game paused,
## Restart reloads the stage from its entry values, Return to Menu unloads everything, and
## a stage with no scene is refused without leaving the menu.
##
## Expected behaviour comes from the F2-04 ticket, GUIDE Sections 5, 7 and 14, the
## handoffs' spatial contracts (Stage 1 flight interior X -45..45, Stage 2 X -55..55) and
## CONVENTIONS "Time and randomness".


## Counts `bomb` presses that reach gameplay, in both input passes. Added under
## `WorldRoot`, which pauses with the stage.
class BombProbe:
	extends Node

	var input_bombs: int = 0
	var unhandled_bombs: int = 0

	func _input(event: InputEvent) -> void:
		if event.is_action_pressed(&"bomb"):
			input_bombs += 1

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"bomb"):
			unhandled_bombs += 1


const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const STAGE_01_PATH := "res://scenes/stages/stage_01.tscn"
const STAGE_02_PATH := "res://scenes/stages/stage_02.tscn"
## Physics frames awaited before reading a result. `physics_frame` fires at the start of
## a step, so two awaits put one whole step in between.
const SETTLE_FRAMES := 2
## Ticks observed while paused, from the ticket.
const PAUSED_TICKS := 30

var _main: GameSession
var _interface: Interface
var _world_root: Node3D
var _projectile_system: ProjectileSystem


func before_each() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return
	_main = packed.instantiate() as GameSession
	tree.root.add_child(_main)
	_interface = _main.interface
	_world_root = _main.world_root
	_projectile_system = _main.projectile_system
	await tree.process_frame


func after_each() -> void:
	tree.paused = false
	for action: StringName in [&"move_forward", &"focus"]:
		Input.action_release(action)
	if _main == null:
		return
	tree.root.remove_child(_main)
	_main.free()
	_main = null
	# Unloaded stages are queued for deletion; let them go before the next test.
	await tree.process_frame


func test_startup_shows_the_main_menu_over_an_empty_world() -> void:
	if not assert_not_null(_main, "%s has a GameSession root" % MAIN_SCENE_PATH):
		return
	assert_eq(_interface.current_screen(), ScreenRouter.MAIN_MENU)
	assert_eq(_visible_screens(), ["MainMenu"])
	assert_eq(_world_root.get_child_count(), 0, "nothing loaded")
	assert_eq(_main.get_run_state().get_phase(), RunState.Phase.IDLE)


func test_open_actions_show_their_screen() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	for pair: Array in [
		[&"open_stage_select", ScreenRouter.STAGE_SELECT],
		[&"open_options", ScreenRouter.OPTIONS],
		[&"open_controls", ScreenRouter.CONTROLS],
		[&"open_credits", ScreenRouter.CREDITS],
	]:
		_request(pair[0])
		assert_eq(_interface.current_screen(), pair[1], "%s" % pair[0])
	assert_true(_interface.back(), "each opened over the previous one, so Back unwinds")
	assert_eq(_interface.current_screen(), ScreenRouter.CONTROLS)


func test_a_direct_stage_loads_the_stage_and_the_ship_at_player_start() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	var stage := _stage()
	var ship := _ship()
	if not assert_not_null(stage, "a Stage under WorldRoot") or not assert_not_null(ship, "a PlayerShip under WorldRoot"):
		return
	assert_eq(stage.scene_file_path, STAGE_01_PATH)
	assert_eq(_world_root.get_child_count(), 2, "the stage and the ship, nothing else")
	var start := stage.get_node("PlayerStart") as Node3D
	assert_true(ship.global_position.is_equal_approx(start.global_position), "ship at PlayerStart, %s vs %s" % [ship.global_position, start.global_position])
	assert_eq(_interface.current_screen(), ScreenRouter.HUD)
	assert_eq(_visible_screens(), ["HUD"], "menus hidden")
	var run := _main.get_run_state()
	assert_eq(run.get_phase(), RunState.Phase.IN_STAGE)
	assert_eq(run.get_attempt_index(), 1, "an Attempt has begun")
	assert_eq(run.stage_result()["mode"], RunState.RunMode.DIRECT_STAGE)
	assert_eq(run.stage_result()["stage"], &"stage_01")
	assert_true(run.stage_result()["is_final"], "a Direct Stage is one stage")
	assert_false(tree.paused)


func test_start_campaign_plays_stage_1_of_the_campaign() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_campaign")
	if not assert_not_null(_stage(), "a Stage under WorldRoot"):
		return
	assert_eq(_stage().scene_file_path, STAGE_01_PATH)
	var result := _main.get_run_state().stage_result()
	assert_eq(result["mode"], RunState.RunMode.CAMPAIGN)
	assert_eq(result["stage"], &"stage_01")
	assert_false(result["is_final"], "Stage 2 follows")
	assert_eq(_interface.current_screen(), ScreenRouter.HUD)


## Stage 1 records no bounds of its own, so they come from the Session's export: the
## handoff's flight interior, X -45..45 and Y up to 75.
func test_stage_1_keeps_the_ship_inside_its_flight_interior() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	var ship := _ship()
	if not assert_not_null(ship, "PlayerShip"):
		return
	ship.reset_to(Transform3D(Basis(), Vector3(200.0, 300.0, 20.0)))
	await _settle()
	assert_almost_eq(ship.global_position.x, 45.0, 0.001, "clamped to the east face")
	assert_almost_eq(ship.global_position.y, 75.0, 0.001, "clamped to the ceiling")


## Stage 2 records its flight interior on `FlightBounds/Limits`: X -55..55.
func test_stage_2_takes_its_flight_interior_from_the_scene() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_02"})
	var ship := _ship()
	if not assert_not_null(ship, "PlayerShip in Stage 2"):
		return
	assert_eq(_stage().scene_file_path, STAGE_02_PATH)
	assert_eq(_main.get_run_state().starting_power_level(), 2, "Direct Stage 2 starts at Power Level 2")
	ship.reset_to(Transform3D(Basis(), Vector3(-200.0, 40.0, 25.0)))
	await _settle()
	assert_almost_eq(ship.global_position.x, -55.0, 0.001, "clamped to the west face")


func test_pause_freezes_the_tree_and_active_time_until_resume() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	await _settle()
	var run := _main.get_run_state()
	assert_true(run.clear_time() > 0.0, "Active Time runs in play")
	_press_pause()
	assert_true(tree.paused, "tree paused")
	assert_true(run.is_paused(), "RunState paused")
	assert_eq(_interface.current_screen(), ScreenRouter.PAUSE)
	assert_eq(_visible_screens(), ["HUD", "PauseMenu"], "Pause over the HUD")
	var frozen := run.clear_time()
	for _tick: int in PAUSED_TICKS:
		await tree.physics_frame
	assert_eq(run.clear_time(), frozen, "no Active Time over %d paused ticks" % PAUSED_TICKS)
	_request(&"resume")
	assert_false(tree.paused, "resume unpauses the tree")
	assert_false(run.is_paused(), "and RunState")
	assert_eq(_visible_screens(), ["HUD"], "and removes Pause")
	await _settle()
	assert_true(run.clear_time() > frozen, "Active Time runs again")


## `Main` processes while paused, so its own tick must check the tree: a tree paused by
## anything adds no Active Time, even with RunState's own flag clear.
func test_a_paused_tree_adds_no_active_time_even_with_the_run_unpaused() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	await _settle()
	var run := _main.get_run_state()
	tree.paused = true
	var frozen := run.clear_time()
	for _tick: int in 10:
		await tree.physics_frame
	assert_false(run.is_paused(), "only the tree is paused")
	assert_eq(run.clear_time(), frozen)


func test_pausing_mid_flight_freezes_the_ship_and_resuming_hands_it_back() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	var ship := _ship()
	if not assert_not_null(ship, "PlayerShip"):
		return
	var start_z := ship.global_position.z
	Input.action_press(&"move_forward")
	await _settle()
	assert_true(ship.global_position.z < start_z, "flies forward (-Z) before the pause")
	_press_pause()
	var frozen := ship.global_position
	for _tick: int in 10:
		await tree.physics_frame
	assert_eq(ship.global_position, frozen, "the ship holds still while paused, input held")
	_press_pause()
	assert_false(tree.paused, "a second pause press resumes")
	assert_eq(_visible_screens(), ["HUD"])
	await _settle()
	assert_true(ship.global_position.z < frozen.z, "flies again after resuming")


## Pause takes the controls away, which releases a held Focus (PlayerController), and
## resuming hands them back.
func test_pausing_releases_focus_and_resuming_restores_the_controls() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	var ship := _ship()
	if not assert_not_null(ship, "PlayerShip"):
		return
	Input.action_press(&"focus")
	await _settle()
	var recorder := signal_recorder(ship, &"focus_changed")
	_press_pause()
	assert_eq(recorder.emissions, [[false]], "Focus released on pause")
	_press_pause()
	await _settle()
	assert_eq(recorder.last(), [true], "the held Focus is read again after resuming")


## GUIDE Section 14: "Open Options without unpausing combat", and Back returns to Pause.
## Start (`pause`) under Options is ignored, so it cannot resume behind Options.
func test_options_from_pause_keeps_the_game_paused() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	_press_pause()
	_request(&"open_options")
	assert_eq(_interface.current_screen(), ScreenRouter.OPTIONS)
	assert_true(tree.paused, "still paused under Options")
	_press_pause()
	assert_eq(_interface.current_screen(), ScreenRouter.OPTIONS, "pause under Options is ignored")
	assert_true(tree.paused, "and does not resume")
	assert_true(_interface.back())
	assert_eq(_visible_screens(), ["HUD", "PauseMenu"], "back on Pause over the HUD")
	assert_true(tree.paused, "and still paused")


## Escape on Pause is `ui_cancel`: Interface turns it into `resume` with Pause still up,
## and the Session removes it.
func test_cancel_on_pause_resumes_and_removes_pause() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	_press_pause()
	_push_action(&"ui_cancel")
	assert_false(tree.paused)
	assert_eq(_visible_screens(), ["HUD"])


## Gamepad B is `ui_cancel` and `bomb`. The press that resumes is consumed on its way,
## so gameplay that reads `bomb` as an event, in `_input` or `_unhandled_input`, never
## sees it: the contract F7's Bomb request relies on (menus-session.md Open issues).
func test_the_b_press_that_resumes_never_reaches_gameplay_as_a_bomb() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	var probe := BombProbe.new()
	_world_root.add_child(probe)
	_press_pause()
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_B
		event.pressed = pressed
		tree.root.push_input(event)
	assert_false(tree.paused, "B on Pause resumed")
	assert_eq(_visible_screens(), ["HUD"])
	assert_eq(probe.input_bombs, 0, "the press did not reach gameplay in _input")
	assert_eq(probe.unhandled_bombs, 0, "nor in _unhandled_input")
	var bomb := InputEventJoypadButton.new()
	bomb.button_index = JOY_BUTTON_B
	bomb.pressed = true
	tree.root.push_input(bomb)
	assert_eq([probe.input_bombs, probe.unhandled_bombs], [1, 1], "the next press reaches both")


func test_restart_reloads_the_stage_with_a_new_ship_at_player_start() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	var old_stage := _stage()
	var old_ship := _ship()
	if not assert_not_null(old_ship, "PlayerShip"):
		return
	old_ship.reset_to(Transform3D(Basis(), Vector3(10.0, 20.0, -30.0)))
	await _settle()
	var run := _main.get_run_state()
	# As the Stage Director will on a Checkpoint: Restart, unlike Retry, drops committed time too.
	run.commit_checkpoint()
	await _settle()
	assert_true(run.clear_time() > 0.0)
	_press_pause()
	_request(&"restart_stage")
	var ship := _ship()
	if not assert_not_null(ship, "a PlayerShip after the restart"):
		return
	assert_ne(ship.get_instance_id(), old_ship.get_instance_id(), "a new ship")
	assert_ne(_stage().get_instance_id(), old_stage.get_instance_id(), "a new stage")
	assert_false(old_ship.is_inside_tree(), "the old ship left the tree")
	assert_eq(_world_root.get_child_count(), 2, "only the new stage and ship")
	var start := _stage().get_node("PlayerStart") as Node3D
	assert_true(ship.global_position.is_equal_approx(start.global_position), "new ship at PlayerStart")
	assert_eq(run.clear_time(), 0.0, "Clear Time back to the stage entry")
	assert_eq(run.get_attempt_index(), 2, "a new Attempt")
	assert_false(tree.paused, "unpaused")
	assert_eq(_visible_screens(), ["HUD"], "Pause removed")


func test_return_to_menu_unloads_everything_and_shows_the_main_menu() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	var ahead := _ship().global_position + Vector3(0.0, 0.0, -10.0)
	_projectile_system.spawn(ProjectileSpawn.new(ahead, Vector3.ZERO, ProjectileSpawn.Faction.HOSTILE, 5.0))
	assert_eq(_projectile_system.count(ProjectileSpawn.Faction.HOSTILE), 1, "a hostile Projectile in flight")
	_press_pause()
	_request(&"return_to_menu")
	assert_eq(_world_root.get_child_count(), 0, "WorldRoot empty")
	assert_eq(_projectile_system.count(ProjectileSpawn.Faction.HOSTILE), 0, "every Projectile removed")
	assert_eq(_interface.current_screen(), ScreenRouter.MAIN_MENU)
	assert_eq(_visible_screens(), ["MainMenu"])
	assert_false(tree.paused, "unpaused")
	assert_eq(_main.get_run_state().get_phase(), RunState.Phase.RUN_ENDED)


func test_a_stage_without_a_scene_is_refused_and_the_menu_stays() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	var scenes: Dictionary[StringName, PackedScene] = {&"stage_01": _main.stage_scenes[&"stage_01"], &"stage_02": null}
	_main.stage_scenes = scenes
	_request(&"start_direct_stage", {"stage": &"stage_02"})
	assert_eq(_world_root.get_child_count(), 0, "nothing loaded")
	assert_eq(_interface.current_screen(), ScreenRouter.MAIN_MENU, "still on the menu")
	assert_eq(_main.get_run_state().get_phase(), RunState.Phase.IDLE, "no Run started")
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	assert_eq(_interface.current_screen(), ScreenRouter.HUD, "the other stage still plays")


## GUIDE Section 5: every stage root has `PlayerStart`, and the ship needs a Flight Volume.
## A stage missing either is refused like a missing scene, instead of spawning the ship
## at the origin or clamping it into an empty box.
func test_a_stage_without_player_start_or_flight_volume_is_refused() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	var no_bounds: Dictionary[StringName, AABB] = {}
	_main.stage_flight_bounds = no_bounds
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	assert_eq(_world_root.get_child_count(), 0, "Stage 1 without its bounds entry is not loaded")
	assert_eq(_interface.current_screen(), ScreenRouter.MAIN_MENU)
	var bare := Node3D.new()
	bare.name = "Stage"
	var packed := PackedScene.new()
	packed.pack(bare)
	bare.free()
	var scenes: Dictionary[StringName, PackedScene] = {&"bare": packed}
	var bounds: Dictionary[StringName, AABB] = {&"bare": AABB(Vector3(-10, 0, -10), Vector3(20, 20, 20))}
	_main.stage_scenes = scenes
	_main.stage_flight_bounds = bounds
	_request(&"start_direct_stage", {"stage": &"bare"})
	assert_eq(_world_root.get_child_count(), 0, "a stage without PlayerStart is not loaded")
	assert_eq(_main.get_run_state().get_phase(), RunState.Phase.IDLE, "and no Run started")


## Since F11-01 a completed stage freezes under Results; a Direct Stage is the last of its
## order, so the Run ends with its victory. Since F15-01 Results follows the victory beat.
func test_a_completed_stage_shows_results() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	_main.get_run_state().complete_stage()
	# Always processing: the beat's end pauses the tree before this wait ends.
	await tree.create_timer(GameSession.VICTORY_BEAT_SECONDS + 0.1).timeout
	assert_true(_world_root.get_child_count() > 0, "the stage stays loaded under Results")
	assert_eq(_interface.current_screen(), ScreenRouter.RESULTS)
	assert_true(tree.paused, "the world is frozen under Results")
	assert_eq(_main.get_run_state().get_phase(), RunState.Phase.RUN_ENDED)


## Pause and resume only act on a stage in play: over a HUD with no Run they do nothing.
func test_pause_and_resume_need_a_stage_in_play() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_interface.show_home(ScreenRouter.HUD)
	_press_pause()
	assert_false(tree.paused, "no Run, no pause")
	assert_eq(_interface.current_screen(), ScreenRouter.HUD)
	_interface.push_overlay(ScreenRouter.PAUSE)
	_request(&"resume")
	assert_eq(_interface.current_screen(), ScreenRouter.PAUSE, "a Pause the Session did not open stays")


## F4-02: a Run starts the Session's CombatState at the stage's entry Power Level, and the
## HUD shows it. Direct Stage 2 enters at Power Level 2 (PLANEJAMENTO Section 4).
func test_a_run_starts_the_combat_state_and_binds_the_hud() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	var combat := _main.get_combat_state()
	_request(&"start_direct_stage", {"stage": &"stage_02"})
	if not assert_not_null(_ship(), "PlayerShip in Stage 2"):
		return
	assert_eq(combat.get_power_level(), 2, "Direct Stage 2 starts at Power Level 2")
	assert_eq([combat.get_health(), combat.has_shield(), combat.get_bombs()], [CombatState.MAX_HEALTH, true, CombatState.MAX_BOMBS])
	var hud := _interface.get_hud()
	assert_eq((hud.get_node(^"PlayerStatus/PowerValue") as Label).text, "2", "the HUD shows Power Level 2")
	assert_eq((hud.get_node(^"PlayerStatus/HealthValue") as Label).text, "100%")
	assert_eq(_connections(combat, &"power_changed", hud), 1, "the HUD observes the CombatState")
	assert_eq(_connections(_ship().targeting, &"target_changed", hud), 1, "and the ship's Targeting")


func test_pause_pauses_the_combat_state() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	var combat := _main.get_combat_state()
	assert_false(combat.is_paused())
	_press_pause()
	assert_true(combat.is_paused(), "paused with the tree")
	_request(&"resume")
	assert_false(combat.is_paused(), "and resumed with it")


## Restart gives a new ship and the stage's entry resources, and the HUD follows the new
## ship's Targeting only.
func test_restart_rebinds_the_hud_to_the_new_ship() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	var old_ship := _ship()
	if not assert_not_null(old_ship, "PlayerShip"):
		return
	var combat := _main.get_combat_state()
	combat.take_hit()
	var hud := _interface.get_hud()
	var shield := hud.get_node(^"PlayerStatus/Shield") as CanvasItem
	assert_eq(shield.modulate, hud.dim_modulate, "the hit broke the Shield on the HUD")
	_press_pause()
	_request(&"restart_stage")
	var ship := _ship()
	if not assert_not_null(ship, "a PlayerShip after the restart"):
		return
	assert_eq(_connections(old_ship.targeting, &"target_changed", hud), 0, "the old ship is let go")
	assert_eq(_connections(ship.targeting, &"target_changed", hud), 1, "the new one is followed once")
	assert_eq(_connections(combat, &"shield_changed", hud), 1, "the CombatState still once")
	assert_true(combat.has_shield(), "the stage's entry resources again")
	assert_false(combat.is_paused())
	assert_eq(shield.modulate, hud.lit_modulate, "and on the HUD")


func test_return_to_menu_unbinds_the_hud() -> void:
	if not assert_not_null(_main, "GameSession"):
		return
	_request(&"start_direct_stage", {"stage": &"stage_01"})
	var hud := _interface.get_hud()
	var combat := _main.get_combat_state()
	_press_pause()
	_request(&"return_to_menu")
	for signal_name: StringName in [&"health_changed", &"shield_changed", &"bombs_changed", &"power_changed"]:
		assert_eq(_connections(combat, signal_name, hud), 0, "%s disconnected" % signal_name)
	assert_false((hud.get_node(^"TargetMarker") as CanvasItem).visible, "no marker left on screen")
	assert_false(combat.is_paused(), "unpaused with the tree")


func _request(action: StringName, payload: Dictionary = {}) -> void:
	_interface.action_requested.emit(action, payload)


## Sends the `pause` action through the root viewport, as Escape or Start would.
func _press_pause() -> void:
	_push_action(&"pause")


func _push_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		tree.root.push_input(event)


func _settle() -> void:
	for _frame: int in SETTLE_FRAMES:
		await tree.physics_frame


func _stage() -> Node3D:
	return _world_root.get_node_or_null(^"Stage") as Node3D


func _ship() -> PlayerController:
	return _world_root.get_node_or_null(^"PlayerShip") as PlayerController


## How many connections of [param source]'s [param signal_name] reach [param target].
func _connections(source: Object, signal_name: StringName, target: Object) -> int:
	var count := 0
	for connection: Dictionary in source.get_signal_connection_list(signal_name):
		if (connection["callable"] as Callable).get_object() == target:
			count += 1
	return count


## The names of the visible screens under `Interface`, in child order.
func _visible_screens() -> Array[String]:
	var names: Array[String] = []
	for child: Node in _interface.get_children():
		if (child as CanvasItem).visible:
			names.append(String(child.name))
	return names
