extends TestCase
## Contract smoke test of [Interface] on `Main/Interface` in `scenes/main.tscn`: the eight
## menus and the HUD instanced once, the Session's startup main menu shown alone, one
## screen per `show_home`, button presses passed up as action requests, Back returning
## to the caller with its focus, and `ui_cancel` resolved as the Session needs it: back,
## `resume` on Pause, `back_refused` when there is nowhere to go, and left alone over
## running gameplay so the same Escape press reaches the Session as `pause`.
##
## Expected behaviour comes from GUIDE Section 14 (the registry's "Return to caller"
## rows, "initial focus on screen entry, preserve focus on return") and the F2-02 ticket.


## Records `ui_cancel` events that reach it unhandled. Added under `WorldRoot`, which
## unhandled input reaches after `Interface`, so it sees what `Interface` left alone.
class CancelProbe:
	extends Node

	var cancels: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_cancel"):
			cancels += 1


const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"
## Screen id to the name of its root under `Interface`.
const SCREEN_NODES: Dictionary[StringName, String] = {
	ScreenRouter.MAIN_MENU: "MainMenu",
	ScreenRouter.STAGE_SELECT: "StageSelect",
	ScreenRouter.OPTIONS: "Options",
	ScreenRouter.CONTROLS: "Controls",
	ScreenRouter.CREDITS: "Credits",
	ScreenRouter.PAUSE: "PauseMenu",
	ScreenRouter.DEFEAT: "Defeat",
	ScreenRouter.RESULTS: "Results",
	ScreenRouter.HUD: "HUD",
}
const HOME_SCREENS: Array[StringName] = [
	ScreenRouter.MAIN_MENU,
	ScreenRouter.STAGE_SELECT,
	ScreenRouter.OPTIONS,
	ScreenRouter.CONTROLS,
	ScreenRouter.CREDITS,
	ScreenRouter.HUD,
]

var _main: Node
var _interface: Interface


func before_each() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return
	_main = packed.instantiate()
	IsolatedSettings.isolate(_main)
	tree.root.add_child(_main)
	_interface = _main.get_node_or_null(^"Interface") as Interface
	await tree.process_frame


func after_each() -> void:
	if _main == null:
		return
	tree.root.remove_child(_main)
	_main.free()
	_main = null
	IsolatedSettings.clean()
	_interface = null


func test_interface_instances_the_eight_menus_and_the_hud_once() -> void:
	if not assert_not_null(_interface, "%s has Interface with the Interface script" % MAIN_SCENE_PATH):
		return
	var screens: Array[StringName] = []
	for child: Node in _interface.get_children():
		if child is MenuController:
			screens.append((child as MenuController).get_screen_id())
	screens.sort()
	var expected: Array[StringName] = []
	expected.assign(MenuController.SCREEN_IDS.values())
	expected.sort()
	assert_eq(screens, expected, "one MenuController per menu screen")
	var hud := _interface.get_hud()
	if not assert_not_null(hud, "get_hud()"):
		return
	assert_eq(hud.get_parent(), _interface, "the HUD is a child of Interface")
	assert_eq(hud.scene_file_path, HUD_SCENE_PATH)
	assert_eq(_interface.get_child_count(), 9, "eight menus and the HUD, nothing else")
	assert_eq(_interface.get_child(0), hud, "the HUD draws below every menu")


func test_startup_shows_only_the_main_menu_with_its_first_button_focused() -> void:
	if not assert_not_null(_interface, "Interface"):
		return
	assert_eq(_visible_screens(), ["MainMenu"])
	assert_eq(_interface.current_screen(), ScreenRouter.MAIN_MENU)
	assert_eq(_focused_path(), "MainMenu/Layout/StartButton")


func test_show_home_shows_exactly_that_screen() -> void:
	if not assert_not_null(_interface, "Interface"):
		return
	for id: StringName in HOME_SCREENS:
		_interface.show_home(id)
		assert_eq(_visible_screens(), [SCREEN_NODES[id]], "show_home(%s)" % id)
	_interface.show_home(ScreenRouter.MAIN_MENU)
	assert_eq(_visible_screens(), ["MainMenu"], "back to exactly one")



## Returning to the menu from the menu itself is an entry, not a return: the first button,
## not the one last used.
func test_show_home_of_the_shown_menu_starts_on_its_first_button() -> void:
	if not assert_not_null(_interface, "Interface"):
		return
	(_main.get_node("Interface/MainMenu/Layout/QuitButton") as Control).grab_focus()
	_interface.show_home(ScreenRouter.MAIN_MENU)
	assert_eq(_focused_path(), "MainMenu/Layout/StartButton")

func test_a_button_press_is_passed_up_as_an_action_request() -> void:
	if not assert_not_null(_interface, "Interface"):
		return
	var recorder := signal_recorder(_interface, &"action_requested")
	_press("MainMenu/Layout/OptionsButton")
	assert_eq(recorder.emissions, [[&"open_options", {}]])
	recorder.clear()
	_press("StageSelect/Layout/MountainCard/SelectButton")
	assert_eq(recorder.emissions, [[&"start_direct_stage", {"stage": &"stage_02"}]], "payload passed through")


func test_a_back_button_returns_to_the_caller_with_its_focus() -> void:
	if not assert_not_null(_interface, "Interface"):
		return
	var recorder := signal_recorder(_interface, &"action_requested")
	(_main.get_node("Interface/MainMenu/Layout/OptionsButton") as Control).grab_focus()
	_interface.show_screen(ScreenRouter.OPTIONS)
	assert_eq(_visible_screens(), ["Options"])
	assert_eq(_focused_path(), "Options/Layout/Audio/MasterVolume", "Options is entered, not returned to")
	_press("Options/Layout/BackButton")
	assert_eq(_visible_screens(), ["MainMenu"])
	assert_eq(_focused_path(), "MainMenu/Layout/OptionsButton", "focus restored on return")
	assert_eq(recorder.count(), 0, "Back is handled here, not passed up")


## Options -> Controls -> Back -> Back, the nested case of "preserve focus on return".
func test_nested_screens_restore_each_callers_focus() -> void:
	if not assert_not_null(_interface, "Interface"):
		return
	_interface.show_screen(ScreenRouter.OPTIONS)
	(_main.get_node("Interface/Options/Layout/Controls/BindingsButton") as Control).grab_focus()
	_interface.show_screen(ScreenRouter.CONTROLS)
	assert_eq(_focused_path(), "Controls/Layout/BackButton")
	_cancel()
	assert_eq(_visible_screens(), ["Options"])
	assert_eq(_focused_path(), "Options/Layout/Controls/BindingsButton")
	_cancel()
	assert_eq(_visible_screens(), ["MainMenu"])
	assert_eq(_focused_path(), "MainMenu/Layout/StartButton", "the main menu kept its own focus")


## "Open Options without unpausing combat" and "retain pause if caller is PauseMenu".
func test_options_opened_from_pause_returns_to_pause_with_the_hud_underneath() -> void:
	if not assert_not_null(_interface, "Interface"):
		return
	_interface.show_home(ScreenRouter.HUD)
	assert_false(_interface.is_gameplay_covered(), "nothing over gameplay")
	_interface.push_overlay(ScreenRouter.PAUSE, {"score": 10, "graze": 2})
	assert_eq(_visible_screens(), ["HUD", "PauseMenu"])
	assert_eq(_focused_path(), "PauseMenu/Layout/ResumeButton")
	(_main.get_node("Interface/PauseMenu/Layout/OptionsButton") as Control).grab_focus()
	_interface.show_screen(ScreenRouter.OPTIONS)
	assert_eq(_visible_screens(), ["Options"])
	assert_true(_interface.is_gameplay_covered())
	_cancel()
	assert_eq(_visible_screens(), ["HUD", "PauseMenu"])
	assert_eq(_focused_path(), "PauseMenu/Layout/OptionsButton")
	assert_eq((_main.get_node("Interface/PauseMenu/Layout/Score") as Label).text, "Pontos  10     Graze  2", "Pause params survive the return")


## Back on Pause cannot unpause the tree, so it asks the Session to resume instead, and
## Pause stays up until the Session answers.
func test_cancel_on_pause_requests_resume() -> void:
	if not assert_not_null(_interface, "Interface"):
		return
	_interface.show_home(ScreenRouter.HUD)
	_interface.push_overlay(ScreenRouter.PAUSE)
	var recorder := signal_recorder(_interface, &"action_requested")
	var probe := _add_cancel_probe()
	_cancel()
	assert_eq(recorder.emissions, [[&"resume", {}]])
	assert_eq(_interface.current_screen(), ScreenRouter.PAUSE, "Pause is still shown")
	assert_eq(probe.cancels, 0, "the Escape press is consumed, so it cannot also toggle pause")


func test_cancel_with_nowhere_to_go_back_is_refused() -> void:
	if not assert_not_null(_interface, "Interface"):
		return
	var recorder := signal_recorder(_interface, &"action_requested")
	var probe := _add_cancel_probe()
	_cancel()
	assert_eq(recorder.emissions, [[&"back_refused", {}]], "on the main menu")
	assert_eq(_visible_screens(), ["MainMenu"])
	recorder.clear()
	_interface.show_home(ScreenRouter.HUD)
	_interface.push_overlay(ScreenRouter.DEFEAT)
	_cancel()
	assert_eq(recorder.emissions, [[&"back_refused", {}]], "on Defeat")
	assert_eq(_visible_screens(), ["HUD", "Defeat"])
	assert_eq(probe.cancels, 0, "consumed while a menu is on top")


## Over running gameplay Escape is the Session's `pause`; Interface must not eat it.
func test_cancel_over_running_gameplay_is_left_to_the_session() -> void:
	if not assert_not_null(_interface, "Interface"):
		return
	_interface.show_home(ScreenRouter.HUD)
	var recorder := signal_recorder(_interface, &"action_requested")
	var probe := _add_cancel_probe()
	_cancel()
	assert_eq(recorder.count(), 0)
	assert_eq(probe.cancels, 1, "the event is left unhandled")
	assert_eq(_visible_screens(), ["HUD"])


## The names of the visible screens under `Interface`, in child order.
func _visible_screens() -> Array[String]:
	var names: Array[String] = []
	for child: Node in _interface.get_children():
		if (child as CanvasItem).visible:
			names.append(String(child.name))
	return names


## The focused control's path relative to `Interface`.
func _focused_path() -> String:
	var focused := _interface.get_viewport().gui_get_focus_owner()
	if focused == null or not _interface.is_ancestor_of(focused):
		return "<nothing under Interface>"
	return String(_interface.get_path_to(focused))


func _press(path_under_interface: String) -> void:
	(_interface.get_node(path_under_interface) as BaseButton).emit_signal("pressed")


func _cancel() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = &"ui_cancel"
		event.pressed = pressed
		tree.root.push_input(event)


func _add_cancel_probe() -> CancelProbe:
	var probe := CancelProbe.new()
	_main.get_node("WorldRoot").add_child(probe)
	return probe
