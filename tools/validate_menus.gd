extends SceneTree
## Offline menu navigation QA for `scenes/main.tscn` (Claude, F2-02). Not gameplay code
## and not attached to any node: it sends keyboard and gamepad events through the root
## viewport, checks which screen is shown and which control has focus after each one,
## and captures the screenshots recorded in `docs/validation/menus.md`. Exits non-zero
## when a check fails.
##
## Run it with `tools/godot.ps1 --path . --script res://tools/validate_menus.gd`.
## With a display it also writes the PNGs; headless it skips them.
##
## Since F2-04 the Session acts on every request, so the tool only records them. Two
## passes play the menu-to-flight flow through the real Session: start a stage, fly it,
## pause, open Options from Pause, resume, and return to the main menu, once on the
## keyboard and once on the gamepad. The events are synthetic: they go through the real
## bindings, the real focus search and the real ship, but no key or button is pressed by
## a person.


const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SHOT_PREFIX := "res://docs/validation/menus-"
## One entry per direction: the action, its arrow key, and its D-pad button.
const DIRECTIONS: Array[Array] = [
	[&"ui_up", KEY_UP, JOY_BUTTON_DPAD_UP],
	[&"ui_down", KEY_DOWN, JOY_BUTTON_DPAD_DOWN],
	[&"ui_left", KEY_LEFT, JOY_BUTTON_DPAD_LEFT],
	[&"ui_right", KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT],
]
const KEYS: Dictionary[StringName, int] = {
	&"ui_up": KEY_UP,
	&"ui_down": KEY_DOWN,
	&"ui_accept": KEY_ENTER,
	&"ui_cancel": KEY_ESCAPE,
	&"ui_focus_next": KEY_TAB,
}
const PAD_BUTTONS: Dictionary[StringName, int] = {
	&"ui_up": JOY_BUTTON_DPAD_UP,
	&"ui_down": JOY_BUTTON_DPAD_DOWN,
	&"ui_accept": JOY_BUTTON_A,
	&"ui_cancel": JOY_BUTTON_B,
}
const STAGE_01_PATH := "res://scenes/stages/stage_01.tscn"
## Physics ticks of held movement input in each flight pass: one second.
const FLIGHT_TICKS := 60
## Physics ticks observed while paused, as in the F2-04 ticket.
const PAUSED_TICKS := 30

var _session: GameSession
var _interface: Interface
## Every action the menus requested, in order, for the checks to read.
var _requested: Array[StringName] = []
var _failures: int = 0
var _use_pad: bool = false


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Main scene could not be loaded: " + MAIN_SCENE_PATH)
		quit(1)
		return
	var main := packed.instantiate()
	root.add_child(main)
	current_scene = main
	_session = main as GameSession
	_interface = main.get_node_or_null(^"Interface") as Interface
	if _session == null or _interface == null:
		push_error("Main needs the GameSession script and an Interface node with the Interface script")
		quit(1)
		return
	_interface.action_requested.connect(_on_action_requested)
	_print_input_devices()
	await process_frame

	await _every_control_is_reachable()
	await _walk_the_menus_with_the_keyboard()
	await _walk_the_menus_with_the_gamepad()
	await _fly_pause_and_return_with_the_keyboard()
	await _fly_pause_and_return_with_the_gamepad()
	await _defeat_refuses_back()
	await _results_credits_and_back()

	if _failures > 0:
		print("MENUS_FAILED %d" % _failures)
	else:
		print("MENUS_OK")
	quit(1 if _failures > 0 else 0)


## From each screen's initial focus, arrows (then the D-pad) reach every visible
## focusable control: no dead ends, nothing only a mouse could reach.
func _every_control_is_reachable() -> void:
	var cases: Array[Array] = [
		[ScreenRouter.MAIN_MENU, {}],
		[ScreenRouter.STAGE_SELECT, {}],
		[ScreenRouter.OPTIONS, {}],
		[ScreenRouter.CONTROLS, {}],
		[ScreenRouter.CREDITS, {}],
		[ScreenRouter.PAUSE, {}],
		[ScreenRouter.DEFEAT, {}],
		[ScreenRouter.RESULTS, {"mode": MenuController.RESULTS_CAMPAIGN_STAGE}],
		[ScreenRouter.RESULTS, {"mode": MenuController.RESULTS_DIRECT_STAGE}],
		[ScreenRouter.RESULTS, {"mode": MenuController.RESULTS_FINAL_VICTORY}],
	]
	for pad: bool in [false, true]:
		_use_pad = pad
		for entry: Array in cases:
			var id: StringName = entry[0]
			_open(id, entry[1])
			var menu := _top_menu()
			var expected := _focusable(menu)
			var reached := await _reachable(menu)
			var missing: Array[String] = []
			for control: Control in expected:
				if control not in reached:
					missing.append(String(menu.get_path_to(control)))
			var screen := "%s%s" % [id, " " + str(entry[1]["mode"]) if entry[1].has("mode") else ""]
			if missing.is_empty():
				_report(true, "%s reaches all %d controls of %s from %s" % [_device(), expected.size(), screen, _focus_name()])
			else:
				_report(false, "%s cannot reach %s on %s" % [_device(), ", ".join(missing), screen])
	_use_pad = false


func _walk_the_menus_with_the_keyboard() -> void:
	_use_pad = false
	_interface.show_home(ScreenRouter.MAIN_MENU)
	await _send(&"ui_up")
	await _send(&"ui_down")
	_expect(ScreenRouter.MAIN_MENU, "Layout/StageSelectButton", "keyboard: arrows move through the main menu")
	_expect_footer(true, "keyboard: footer shown")
	await _send(&"ui_down")
	await _capture("main-keyboard")
	await _send(&"ui_accept")
	_expect(ScreenRouter.OPTIONS, "Layout/Audio/MasterVolume", "keyboard: Enter on Opções opens Options at its first control")
	await _capture("options-entry")
	_focus("Layout/Controls/BindingsButton")
	await _send(&"ui_accept")
	_expect(ScreenRouter.CONTROLS, "Layout/BackButton", "keyboard: Enter on Ver comandos opens Controls")
	await _send(&"ui_cancel")
	_expect(ScreenRouter.OPTIONS, "Layout/Controls/BindingsButton", "keyboard: Escape returns to Options on Ver comandos")
	await _send(&"ui_cancel")
	_expect(ScreenRouter.MAIN_MENU, "Layout/OptionsButton", "keyboard: Escape returns to the main menu on Opções")
	_requested.clear()
	await _send(&"ui_cancel")
	_expect(ScreenRouter.MAIN_MENU, "Layout/OptionsButton", "keyboard: Escape on the main menu stays put")
	_report(_requested == [&"back_refused"], "keyboard: and requests back_refused (%s)" % [_requested])
	await _send(&"ui_up")
	await _send(&"ui_accept")
	_expect(ScreenRouter.STAGE_SELECT, "Layout/ForestCard/SelectButton", "keyboard: Selecionar fase opens StageSelect on the forest card")
	await _send(&"ui_cancel")
	_expect(ScreenRouter.MAIN_MENU, "Layout/StageSelectButton", "keyboard: Escape returns on Selecionar fase")


func _walk_the_menus_with_the_gamepad() -> void:
	_use_pad = true
	_interface.show_home(ScreenRouter.MAIN_MENU)
	await _send(&"ui_down")
	_expect_footer(false, "gamepad: footer hidden after a D-pad press")
	_expect(ScreenRouter.MAIN_MENU, "Layout/StageSelectButton", "gamepad: D-pad moves through the main menu")
	await _send(&"ui_accept")
	_expect(ScreenRouter.STAGE_SELECT, "Layout/ForestCard/SelectButton", "gamepad: A opens StageSelect")
	_expect_footer(false, "gamepad: footer stays hidden on the next screen")
	await _send(&"ui_cancel")
	_expect(ScreenRouter.MAIN_MENU, "Layout/StageSelectButton", "gamepad: B returns on Selecionar fase")
	await _capture("main-gamepad")
	_use_pad = false
	await _send(&"ui_down")
	_expect_footer(true, "keyboard again: footer shown")


## The menu-to-flight flow on the keyboard: Iniciar starts the Campaign on Stage 1, W
## flies the ship, Escape pauses it and freezes the ship and Active Time with W still
## held, Options from Pause keeps the game paused ("Open Options without unpausing
## combat"), Escape resumes, and Menu principal ends the Run.
func _fly_pause_and_return_with_the_keyboard() -> void:
	_use_pad = false
	_interface.show_home(ScreenRouter.MAIN_MENU)
	await _send(&"ui_accept")
	_expect(ScreenRouter.HUD, "<none>", "keyboard: Enter on Iniciar starts the Campaign on the HUD")
	var ship := _ship()
	_report(ship != null and _stage_path() == STAGE_01_PATH, "keyboard: Stage 1 and the ship are under WorldRoot (%s)" % _stage_path())
	if ship == null:
		return
	_report(_session.get_run_state().stage_result()["mode"] == RunState.RunMode.CAMPAIGN, "keyboard: and the Run is a Campaign")
	await _fly(ship, _key_event(KEY_W, true), _key_event(KEY_W, false), "keyboard: W")
	await _send(&"ui_down")
	await _send(&"ui_down")
	await _send(&"ui_accept")
	_expect(ScreenRouter.OPTIONS, "Layout/Audio/MasterVolume", "pause: Opções opens Options")
	_report(paused, "pause: the game stays paused under Options")
	await _send(&"ui_cancel")
	_expect(ScreenRouter.PAUSE, "Layout/OptionsButton", "pause: Escape returns to Pause on Opções")
	_report(paused, "pause: and it is still paused")
	await _capture("pause-return")
	await _send(&"ui_cancel")
	_expect(ScreenRouter.HUD, "<none>", "pause: Escape on Pause resumes on the HUD")
	_report(not paused, "pause: and unpauses the tree")
	await _return_to_menu_from_pause("keyboard")


## The same flow on the gamepad through Stage Select: A on the forest card starts Direct
## Stage 1, the left stick flies, Start pauses, B resumes, and Start under Options opened
## from Pause is ignored, so it cannot resume behind Options.
func _fly_pause_and_return_with_the_gamepad() -> void:
	_use_pad = true
	_interface.show_home(ScreenRouter.MAIN_MENU)
	await _send(&"ui_down")
	await _send(&"ui_accept")
	_requested.clear()
	await _send(&"ui_accept")
	_report(_requested == [&"start_direct_stage"], "gamepad: A on the forest card requests start_direct_stage (%s)" % [_requested])
	_expect(ScreenRouter.HUD, "<none>", "gamepad: and the Session starts it on the HUD")
	var ship := _ship()
	_report(ship != null and _stage_path() == STAGE_01_PATH, "gamepad: Stage 1 and the ship are under WorldRoot (%s)" % _stage_path())
	if ship == null:
		return
	_report(_session.get_run_state().stage_result()["mode"] == RunState.RunMode.DIRECT_STAGE, "gamepad: and the Run is a Direct Stage")
	await _fly(ship, _stick_event(-1.0), _stick_event(0.0), "gamepad: left stick up")
	await _send(&"ui_cancel")
	_expect(ScreenRouter.HUD, "<none>", "gamepad: B on Pause resumes on the HUD")
	_report(not paused, "gamepad: and unpauses the tree")
	await _send_button(JOY_BUTTON_START)
	await _send(&"ui_down")
	await _send(&"ui_down")
	await _send(&"ui_accept")
	_expect(ScreenRouter.OPTIONS, "Layout/Audio/MasterVolume", "gamepad: Opções from Pause opens Options")
	await _send_button(JOY_BUTTON_START)
	_expect(ScreenRouter.OPTIONS, "Layout/Audio/MasterVolume", "gamepad: Start under Options is ignored")
	_report(paused, "gamepad: and the game stays paused")
	await _send(&"ui_cancel")
	_expect(ScreenRouter.PAUSE, "Layout/OptionsButton", "gamepad: B returns to Pause on Opções")
	await _send(&"ui_up")
	await _send(&"ui_up")
	await _return_to_menu_from_pause("gamepad")


## Holds [param press] for [constant FLIGHT_TICKS] and checks the ship flew toward -Z,
## then pauses with the `pause` binding of the device in use and checks that the ship
## and Active Time hold still for [constant PAUSED_TICKS] with the input still held.
## Leaves the game paused on Pause, input released.
func _fly(ship: PlayerController, press: InputEvent, release: InputEvent, label: String) -> void:
	var start := ship.global_position
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await _physics_ticks(FLIGHT_TICKS)
	var flown := start.z - ship.global_position.z
	_report(flown > 1.0, "%s flies the ship %.2f units along -Z in %d ticks" % [label, flown, FLIGHT_TICKS])
	if not _use_pad:
		await _capture("flight")
	await _send_pause()
	_expect(ScreenRouter.PAUSE, "Layout/ResumeButton", "%s: %s pauses on Continuar" % [_device(), "Start" if _use_pad else "Escape"])
	var frozen := ship.global_position
	var time := _session.get_run_state().clear_time()
	await _physics_ticks(PAUSED_TICKS)
	var still := ship.global_position == frozen and _session.get_run_state().clear_time() == time
	_report(paused and still, "%s: input still held, the ship and Active Time (%.3f s) hold still for %d paused ticks" % [_device(), time, PAUSED_TICKS])
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame


## From Pause on Continuar, Down three times to Menu principal and accept: the Run ends,
## the world is empty, the tree runs, and the main menu opens on Iniciar.
func _return_to_menu_from_pause(device: String) -> void:
	if _interface.current_screen() == ScreenRouter.HUD:
		await _send_pause()
	_expect(ScreenRouter.PAUSE, "Layout/ResumeButton", "%s: Pause again, on Continuar" % device)
	for _step: int in 3:
		await _send(&"ui_down")
	_expect(ScreenRouter.PAUSE, "Layout/MenuButton", "%s: Down three times reaches Menu principal" % device)
	await _send(&"ui_accept")
	_expect(ScreenRouter.MAIN_MENU, "Layout/StartButton", "%s: Menu principal returns to the main menu on Iniciar" % device)
	var emptied := _session.world_root.get_child_count() == 0
	_report(emptied and not paused, "%s: with WorldRoot empty and the tree running" % device)


func _defeat_refuses_back() -> void:
	_use_pad = true
	_interface.show_home(ScreenRouter.HUD)
	_interface.push_overlay(ScreenRouter.DEFEAT)
	_expect(ScreenRouter.DEFEAT, "Layout/RetryButton", "defeat: opens on Tentar novamente")
	_requested.clear()
	await _send(&"ui_cancel")
	_expect(ScreenRouter.DEFEAT, "Layout/RetryButton", "defeat: B does not dismiss it")
	_report(_requested == [&"back_refused"], "defeat: and requests back_refused (%s)" % [_requested])
	_use_pad = false


## GUIDE: final victory hides Continue and Replay and focuses Menu or Credits; Credits
## returns to Results with the same layout.
func _results_credits_and_back() -> void:
	_use_pad = false
	_interface.show_home(ScreenRouter.HUD)
	_interface.push_overlay(ScreenRouter.RESULTS, {"mode": MenuController.RESULTS_FINAL_VICTORY})
	_expect(ScreenRouter.RESULTS, "Layout/MenuButton", "results: final victory opens on Menu principal")
	await _send(&"ui_down")
	await _send(&"ui_accept")
	_expect(ScreenRouter.CREDITS, "Layout/BackButton", "results: Créditos opens Credits")
	await _send(&"ui_cancel")
	_expect(ScreenRouter.RESULTS, "Layout/CreditsButton", "results: Escape returns to Results on Créditos")
	var heading := (_top_menu().get_node("Layout/Heading") as Label).text
	_report(heading == "Jornada concluída", "results: heading still '%s'" % heading)
	await _send(&"ui_focus_next")
	_expect(ScreenRouter.RESULTS, "Layout/MenuButton", "results: Tab skips the hidden Continue and Replay")
	await _capture("results-final")


## Every control reachable from the focused one by the four directions, breadth first.
func _reachable(menu: MenuController) -> Array[Control]:
	var start := root.gui_get_focus_owner()
	var reached: Array[Control] = [start]
	var queue: Array[Control] = [start]
	while not queue.is_empty():
		var from: Control = queue.pop_front()
		for direction: Array in DIRECTIONS:
			from.grab_focus()
			await _send_direction(direction)
			var to := root.gui_get_focus_owner()
			if to != null and menu.is_ancestor_of(to) and to not in reached:
				reached.append(to)
				queue.append(to)
	(reached[0] as Control).grab_focus()
	return reached


func _focusable(menu: MenuController) -> Array[Control]:
	var controls: Array[Control] = []
	for node: Node in menu.find_children("*", "Control", true, false):
		var control := node as Control
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree():
			controls.append(control)
	return controls


func _open(id: StringName, params: Dictionary) -> void:
	if id in ScreenRouter.OVERLAYS:
		_interface.show_home(ScreenRouter.HUD)
		_interface.push_overlay(id, params)
	else:
		_interface.show_home(id)


func _top_menu() -> MenuController:
	for child: Node in _interface.get_children():
		var menu := child as MenuController
		if menu != null and menu.get_screen_id() == _interface.current_screen():
			return menu
	return null


func _focus(path: String) -> void:
	(_top_menu().get_node(path) as Control).grab_focus()


func _focus_name() -> String:
	var focused := root.gui_get_focus_owner()
	var menu := _top_menu()
	if focused == null or menu == null or not menu.is_ancestor_of(focused):
		return "<none>"
	return String(menu.get_path_to(focused))


func _send(action: StringName) -> void:
	for pressed: bool in [true, false]:
		if _use_pad:
			var button := InputEventJoypadButton.new()
			button.button_index = PAD_BUTTONS[action] as JoyButton
			button.pressed = pressed
			root.push_input(button)
		else:
			root.push_input(_key_event(KEYS[action], pressed))
	await process_frame


func _send_direction(direction: Array) -> void:
	for pressed: bool in [true, false]:
		if _use_pad:
			var button := InputEventJoypadButton.new()
			button.button_index = direction[2] as JoyButton
			button.pressed = pressed
			root.push_input(button)
		else:
			root.push_input(_key_event(direction[1], pressed))
	await process_frame


static func _key_event(keycode: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode as Key
	event.physical_keycode = keycode as Key
	event.pressed = pressed
	return event


## The left stick's vertical axis at [param value]: -1 is fully up, which is `move_forward`.
static func _stick_event(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = value
	return event


## Presses and releases [param button] through the root viewport, like [method _send].
func _send_button(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		root.push_input(event)
	await process_frame


## The `pause` binding of the device in use: Start, or Escape, which is `ui_cancel` too.
func _send_pause() -> void:
	if _use_pad:
		await _send_button(JOY_BUTTON_START)
	else:
		await _send(&"ui_cancel")


func _physics_ticks(count: int) -> void:
	for _tick: int in count:
		await physics_frame


func _ship() -> PlayerController:
	return _session.world_root.get_node_or_null(^"PlayerShip") as PlayerController


func _stage_path() -> String:
	var stage := _session.world_root.get_node_or_null(^"Stage")
	return stage.scene_file_path if stage != null else "<no Stage>"


func _device() -> String:
	return "gamepad" if _use_pad else "keyboard"


func _expect(screen: StringName, focus_path: String, label: String) -> void:
	var passed := _interface.current_screen() == screen and _focus_name() == focus_path
	_report(passed, "%s: on %s at %s" % [label, _interface.current_screen(), _focus_name()])


func _expect_footer(shown: bool, label: String) -> void:
	var footer := _top_menu().get_node_or_null(MenuController.FOOTER_PATH) as Control
	_report(footer != null and footer.visible == shown, "%s: footer visible %s" % [label, footer != null and footer.visible])


func _report(passed: bool, label: String) -> void:
	if not passed:
		_failures += 1
	print("MENUS %s %s" % ["ok  " if passed else "FAIL", label])


## Records only: the Session connected first, so it has already acted.
func _on_action_requested(action: StringName, _payload: Dictionary) -> void:
	_requested.append(action)


## A synthetic event proves nothing about a pad (ENGINEERING_BRIEF Section 8), so the
## validation page quotes this line instead of inheriting a controller claim.
func _print_input_devices() -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		print("MENUS note: no joypad connected on this host; every gamepad case below is synthetic")
		return
	var names: PackedStringArray = []
	for pad: int in pads:
		names.append("%d:%s" % [pad, Input.get_joy_name(pad)])
	print("MENUS note: joypads connected: %s; cases below are still synthetic events" % ", ".join(names))


func _capture(name_suffix: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := SHOT_PREFIX + name_suffix + ".png"
	var result := root.get_texture().get_image().save_png(path)
	_report(result == OK, "screenshot %s %s" % [path, error_string(result)])
