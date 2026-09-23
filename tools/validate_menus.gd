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
## Until F2-04 the Session reacts to no menu action, so this tool plays its navigation
## part: the `open_*` actions open their screen and `resume` removes Pause. Everything
## else it only records. The events are synthetic: they go through the real `ui_*`
## bindings and the real focus search, but no key or button is pressed by a person.


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
## The Session's navigation part, played here until F2-04 exists.
const OPENS: Dictionary[StringName, StringName] = {
	&"open_stage_select": ScreenRouter.STAGE_SELECT,
	&"open_options": ScreenRouter.OPTIONS,
	&"open_controls": ScreenRouter.CONTROLS,
	&"open_credits": ScreenRouter.CREDITS,
}

var _interface: Interface
## Actions other than the `open_*` ones, in order, for the checks to read.
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
	_interface = main.get_node_or_null(^"Interface") as Interface
	if _interface == null:
		push_error("Main has no Interface node with the Interface script")
		quit(1)
		return
	_interface.action_requested.connect(_on_action_requested)
	_print_input_devices()
	await process_frame

	await _every_control_is_reachable()
	await _walk_the_menus_with_the_keyboard()
	await _walk_the_menus_with_the_gamepad()
	await _pause_options_and_back()
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
	_requested.clear()
	await _send(&"ui_accept")
	_report(_requested == [&"start_direct_stage"], "gamepad: A on the forest card requests start_direct_stage (%s)" % [_requested])
	await _send(&"ui_cancel")
	_expect(ScreenRouter.MAIN_MENU, "Layout/StageSelectButton", "gamepad: B returns on Selecionar fase")
	await _capture("main-gamepad")
	_use_pad = false
	await _send(&"ui_down")
	_expect_footer(true, "keyboard again: footer shown")


## "Open Options without unpausing combat": Options from Pause returns to Pause, and Back
## on Pause asks the Session to resume.
func _pause_options_and_back() -> void:
	_use_pad = false
	_interface.show_home(ScreenRouter.HUD)
	_interface.push_overlay(ScreenRouter.PAUSE, {"score": 4200, "graze": 17})
	_expect(ScreenRouter.PAUSE, "Layout/ResumeButton", "pause: opens on Continuar over the HUD")
	await _send(&"ui_down")
	await _send(&"ui_down")
	await _send(&"ui_accept")
	_expect(ScreenRouter.OPTIONS, "Layout/Audio/MasterVolume", "pause: Opções opens Options")
	await _send(&"ui_cancel")
	_expect(ScreenRouter.PAUSE, "Layout/OptionsButton", "pause: Escape returns to Pause on Opções")
	await _capture("pause-return")
	_requested.clear()
	await _send(&"ui_cancel")
	_report(_requested == [&"resume"], "pause: Escape on Pause requests resume (%s)" % [_requested])
	_report(_interface.current_screen() == ScreenRouter.HUD, "pause: and the HUD is left alone")


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


func _on_action_requested(action: StringName, _payload: Dictionary) -> void:
	if action in OPENS:
		_interface.show_screen(OPENS[action])
		return
	_requested.append(action)
	if action == &"resume":
		_interface.back()


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
