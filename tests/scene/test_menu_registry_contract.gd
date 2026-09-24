extends TestCase
## Contract smoke test of [MenuController] on each of the eight menu scenes of GUIDE
## Section 14, each instanced on its own: every registry button exists and requests its
## action, entering a screen gives focus to a control and returning restores it, the
## runtime text is written, Results shows Continue or Replay per run mode with a focus
## loop that skips the hidden buttons, and the keyboard footer follows set_keyboard_prompts.
##
## Expected paths, actions and texts come from GUIDE Section 14 "Scene and action
## registry" and "Runtime text and presentation"; action names are the ones F2-04's
## Session reacts to. `test_a_missing_button_is_reported_and_the_rest_of_the_screen_works`
## deliberately triggers `push_error`, so one ERROR line in the run output is its own.


## Scene path to the screen id its root name maps to.
const SCENES: Dictionary[String, StringName] = {
	"res://scenes/ui/main_menu.tscn": ScreenRouter.MAIN_MENU,
	"res://scenes/ui/stage_select.tscn": ScreenRouter.STAGE_SELECT,
	"res://scenes/ui/options.tscn": ScreenRouter.OPTIONS,
	"res://scenes/ui/controls.tscn": ScreenRouter.CONTROLS,
	"res://scenes/ui/credits.tscn": ScreenRouter.CREDITS,
	"res://scenes/ui/pause_menu.tscn": ScreenRouter.PAUSE,
	"res://scenes/ui/defeat.tscn": ScreenRouter.DEFEAT,
	"res://scenes/ui/results.tscn": ScreenRouter.RESULTS,
}
## GUIDE Section 14, one row per button: screen, path, then `[action, payload]`.
const EXPECTED_ACTIONS: Dictionary[StringName, Dictionary] = {
	ScreenRouter.MAIN_MENU: {
		"Layout/StartButton": [&"start_campaign", {}],
		"Layout/StageSelectButton": [&"open_stage_select", {}],
		"Layout/OptionsButton": [&"open_options", {}],
		"Layout/QuitButton": [&"quit", {}],
	},
	ScreenRouter.STAGE_SELECT: {
		"Layout/ForestCard/SelectButton": [&"start_direct_stage", {"stage": &"stage_01"}],
		"Layout/MountainCard/SelectButton": [&"start_direct_stage", {"stage": &"stage_02"}],
		"Layout/BackButton": [&"back", {}],
	},
	ScreenRouter.OPTIONS: {
		"Layout/Controls/BindingsButton": [&"open_controls", {}],
		"Layout/DefaultsButton": [&"restore_defaults", {}],
		"Layout/CreditsButton": [&"open_credits", {}],
		"Layout/BackButton": [&"back", {}],
	},
	ScreenRouter.CONTROLS: {
		"Layout/BackButton": [&"back", {}],
	},
	ScreenRouter.PAUSE: {
		"Layout/ResumeButton": [&"resume", {}],
		"Layout/RestartButton": [&"restart_stage", {}],
		"Layout/OptionsButton": [&"open_options", {}],
		"Layout/MenuButton": [&"return_to_menu", {}],
	},
	ScreenRouter.DEFEAT: {
		"Layout/RetryButton": [&"retry", {}],
		"Layout/MenuButton": [&"return_to_menu", {}],
	},
	ScreenRouter.RESULTS: {
		"Layout/ContinueButton": [&"continue_campaign", {}],
		"Layout/ReplayButton": [&"replay_stage", {}],
		"Layout/MenuButton": [&"return_to_menu", {}],
		"Layout/CreditsButton": [&"open_credits", {}],
	},
	ScreenRouter.CREDITS: {
		"Layout/BackButton": [&"back", {}],
	},
}
## The control each screen focuses when entered rather than returned to: the top of its
## authored focus order. Results is entered here without a mode, its authored layout.
const INITIAL_FOCUS: Dictionary[StringName, String] = {
	ScreenRouter.MAIN_MENU: "Layout/StartButton",
	ScreenRouter.STAGE_SELECT: "Layout/ForestCard/SelectButton",
	ScreenRouter.OPTIONS: "Layout/Audio/MasterVolume",
	ScreenRouter.CONTROLS: "Layout/BackButton",
	ScreenRouter.CREDITS: "Layout/BackButton",
	ScreenRouter.PAUSE: "Layout/ResumeButton",
	ScreenRouter.DEFEAT: "Layout/RetryButton",
	ScreenRouter.RESULTS: "Layout/ContinueButton",
}
const FULL_SCREEN_SCENES: Array[String] = [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/stage_select.tscn",
	"res://scenes/ui/options.tscn",
	"res://scenes/ui/controls.tscn",
	"res://scenes/ui/credits.tscn",
]
const FOOTER_PATH := "Layout/NavigationHint"
const CONTINUE := "Layout/ContinueButton"
const REPLAY := "Layout/ReplayButton"
const MENU := "Layout/MenuButton"
const CREDITS := "Layout/CreditsButton"
const HEADING := "Layout/Heading"

var _menu: MenuController


func after_each() -> void:
	if _menu != null and is_instance_valid(_menu):
		if _menu.get_parent() != null:
			_menu.get_parent().remove_child(_menu)
		_menu.free()
	_menu = null


func test_every_registry_row_is_a_button_on_its_screen() -> void:
	for scene_path: String in SCENES:
		if not _open(scene_path):
			continue
		var screen: StringName = SCENES[scene_path]
		assert_eq(_menu.get_screen_id(), screen, "%s root maps to its screen" % scene_path)
		assert_eq(MenuController.ACTIONS_BY_SCREEN[screen].keys(), EXPECTED_ACTIONS[screen].keys(), "%s registry rows" % screen)
		for path: String in EXPECTED_ACTIONS[screen]:
			assert_true(_menu.get_node_or_null(path) is BaseButton, "%s has a BaseButton at %s" % [screen, path])
		after_each()


func test_each_button_requests_its_registry_action() -> void:
	for scene_path: String in SCENES:
		if not _open(scene_path):
			continue
		var screen: StringName = SCENES[scene_path]
		var recorder := signal_recorder(_menu, &"action_requested")
		for path: String in EXPECTED_ACTIONS[screen]:
			var button := _menu.get_node_or_null(path) as BaseButton
			if not assert_not_null(button, "%s %s" % [screen, path]):
				continue
			recorder.clear()
			button.emit_signal("pressed")
			assert_eq(recorder.emissions, [EXPECTED_ACTIONS[screen][path]], "%s %s" % [screen, path])
		after_each()


## A payload is a copy: a Session that edits it cannot change what the next press sends.
func test_a_payload_is_a_new_dictionary_on_each_press() -> void:
	if not _open("res://scenes/ui/stage_select.tscn"):
		return
	var recorder := signal_recorder(_menu, &"action_requested")
	var button := _menu.get_node("Layout/MountainCard/SelectButton") as BaseButton
	button.emit_signal("pressed")
	var payload: Dictionary = recorder.last()[1]
	if not assert_false(payload.is_read_only(), "the Session may edit its payload"):
		return
	payload["stage"] = &"edited"
	button.emit_signal("pressed")
	assert_eq(recorder.last(), [&"start_direct_stage", {"stage": &"stage_02"}])


func test_entering_a_screen_focuses_its_first_control() -> void:
	for scene_path: String in SCENES:
		if not _open(scene_path):
			continue
		var screen: StringName = SCENES[scene_path]
		_menu.hide()
		_menu.enter({}, NodePath())
		assert_true(_menu.visible, "%s is shown" % screen)
		assert_eq(_focused_path(), INITIAL_FOCUS[screen], "%s initial focus" % screen)
		after_each()


func test_returning_restores_the_remembered_focus_and_leaving_reports_it() -> void:
	if not _open("res://scenes/ui/main_menu.tscn"):
		return
	_menu.enter({}, ^"Layout/OptionsButton")
	assert_eq(_focused_path(), "Layout/OptionsButton", "remembered focus")
	assert_eq(_menu.leave(), ^"Layout/OptionsButton", "leave reports the focused control")
	assert_false(_menu.visible, "leave hides the screen")
	_menu.enter({}, ^"Layout/NoSuchButton")
	assert_eq(_focused_path(), "Layout/StartButton", "a stale path falls back to the initial focus")
	_menu.enter({}, ^"Layout/NavigationHint")
	assert_eq(_focused_path(), "Layout/StartButton", "a control that cannot take focus falls back too")


func test_leaving_without_focus_inside_the_screen_reports_nothing() -> void:
	if not _open("res://scenes/ui/main_menu.tscn"):
		return
	_menu.enter({}, NodePath())
	_menu.get_viewport().gui_release_focus()
	assert_eq(_menu.leave(), NodePath())


func test_results_after_campaign_stage_1_shows_continue_and_skips_replay() -> void:
	if not _open("res://scenes/ui/results.tscn"):
		return
	_menu.enter({"mode": "campaign_stage_1"}, NodePath())
	assert_true(_button(CONTINUE).visible, "Continue shown")
	assert_false(_button(REPLAY).visible, "Replay hidden")
	assert_eq(_label(HEADING).text, "Fase concluída")
	assert_eq(_focused_path(), CONTINUE)
	_assert_focus_loop([CONTINUE, MENU, CREDITS])


func test_results_after_a_direct_stage_shows_replay_in_place_of_continue() -> void:
	if not _open("res://scenes/ui/results.tscn"):
		return
	_menu.enter({"mode": MenuController.RESULTS_DIRECT_STAGE}, NodePath())
	assert_false(_button(CONTINUE).visible, "Continue hidden")
	assert_true(_button(REPLAY).visible, "Replay shown")
	assert_eq(_label(HEADING).text, "Fase concluída")
	assert_eq(_focused_path(), REPLAY)
	_assert_focus_loop([REPLAY, MENU, CREDITS])


## GUIDE: "For final campaign victory, change Layout/Heading to Jornada concluída, hide
## both ContinueButton and ReplayButton, and focus MenuButton or CreditsButton". The
## instance lives for the whole session, so the next Results must get the authored
## heading and Continue back.
func test_results_final_victory_hides_both_and_names_the_journey() -> void:
	if not _open("res://scenes/ui/results.tscn"):
		return
	_menu.enter({"mode": "final_victory"}, NodePath())
	assert_false(_button(CONTINUE).visible, "Continue hidden")
	assert_false(_button(REPLAY).visible, "Replay hidden")
	assert_eq(_label(HEADING).text, "Jornada concluída")
	assert_eq(_focused_path(), MENU)
	_assert_focus_loop([MENU, CREDITS])
	_menu.leave()
	_menu.enter({"mode": "campaign_stage_1"}, NodePath())
	assert_eq(_label(HEADING).text, "Fase concluída", "authored heading restored")
	assert_true(_button(CONTINUE).visible, "Continue shown again")
	_assert_focus_loop([CONTINUE, MENU, CREDITS])


## A remembered Replay is hidden in the Campaign layout, so focus falls back.
func test_a_remembered_button_hidden_by_the_run_mode_is_not_focused() -> void:
	if not _open("res://scenes/ui/results.tscn"):
		return
	_menu.enter({"mode": "campaign_stage_1"}, NodePath(REPLAY))
	assert_eq(_focused_path(), CONTINUE)


func test_defeat_names_the_retry_location() -> void:
	if not _open("res://scenes/ui/defeat.tscn"):
		return
	_menu.enter({}, NodePath())
	assert_eq(_label("Layout/RetryLocation").text, "Início da fase", "no Checkpoint yet")
	_menu.enter({"checkpoint": &"CP1-A"}, NodePath())
	assert_eq(_label("Layout/RetryLocation").text, "Último checkpoint · CP1-A")
	_menu.enter({"checkpoint": &""}, NodePath())
	assert_eq(_label("Layout/RetryLocation").text, "Início da fase", "an empty id is no Checkpoint")


func test_pause_shows_the_score_and_graze_it_is_given() -> void:
	if not _open("res://scenes/ui/pause_menu.tscn"):
		return
	_menu.enter({"score": 1200, "graze": 35}, NodePath())
	assert_eq(_label("Layout/Score").text, "Pontos  1200     Graze  35")
	_menu.enter({}, NodePath())
	assert_eq(_label("Layout/Score").text, "Pontos  —     Graze  —", "no values: the authored dashes")


## "Missing paths produce a push_error naming screen and path, and that button is
## skipped; the rest of the screen still works."
func test_a_missing_button_is_reported_and_the_rest_of_the_screen_works() -> void:
	var packed := load("res://scenes/ui/main_menu.tscn") as PackedScene
	_menu = packed.instantiate() as MenuController
	var start := _menu.get_node("Layout/StartButton")
	start.get_parent().remove_child(start)
	start.free()
	tree.root.add_child(_menu)
	var recorder := signal_recorder(_menu, &"action_requested")
	(_menu.get_node("Layout/OptionsButton") as BaseButton).emit_signal("pressed")
	assert_eq(recorder.emissions, [[&"open_options", {}]])
	_menu.enter({}, NodePath())
	assert_eq(_focused_path(), "Layout/StageSelectButton", "focus goes to the first button left")


## The footer is found by path and absent from the overlays by design, so a renamed
## footer would silently stop hiding; this pins it on the five full screens.
func test_the_five_full_screens_carry_the_keyboard_footer() -> void:
	for scene_path: String in FULL_SCREEN_SCENES:
		if not _open(scene_path):
			continue
		assert_true(_menu.get_node_or_null(FOOTER_PATH) is Control, "%s has %s" % [scene_path, FOOTER_PATH])
		after_each()


## Which prompts to show is decided by Interface's InputDeviceState since F3-03; the menu
## only shows or hides its footer when told.
func test_set_keyboard_prompts_shows_and_hides_the_footer() -> void:
	if not _open("res://scenes/ui/main_menu.tscn"):
		return
	var footer := _menu.get_node(FOOTER_PATH) as Control
	_menu.enter({}, NodePath())
	assert_true(footer.visible, "keyboard hint shown by default")
	_menu.set_keyboard_prompts(false)
	assert_false(footer.visible, "hidden for gamepad prompts")
	_menu.set_keyboard_prompts(true)
	assert_true(footer.visible, "shown again for keyboard prompts")
	assert_eq(_focused_path(), "Layout/StartButton", "none of this moved focus")


func _open(scene_path: String) -> bool:
	var packed := load(scene_path) as PackedScene
	if not assert_not_null(packed, "%s loads" % scene_path):
		return false
	_menu = packed.instantiate() as MenuController
	if not assert_not_null(_menu, "%s root is a MenuController" % scene_path):
		return false
	tree.root.add_child(_menu)
	return true


func _focused_path() -> String:
	var focused := _menu.get_viewport().gui_get_focus_owner()
	if focused == null or not _menu.is_ancestor_of(focused):
		return "<nothing in %s>" % _menu.name
	return String(_menu.get_path_to(focused))


func _button(path: String) -> BaseButton:
	return _menu.get_node(path) as BaseButton


func _label(path: String) -> Label:
	return _menu.get_node(path) as Label


## Each of [param paths]' `focus_next` is the one after it and `focus_previous` the one
## before it, wrapping at both ends.
func _assert_focus_loop(paths: Array[String]) -> void:
	for index: int in paths.size():
		var button := _button(paths[index])
		var next := button.get_node_or_null(button.focus_next)
		var previous := button.get_node_or_null(button.focus_previous)
		var expected_next := _button(paths[(index + 1) % paths.size()])
		var expected_previous := _button(paths[index - 1])
		assert_eq(next, expected_next, "%s focus_next" % paths[index])
		assert_eq(previous, expected_previous, "%s focus_previous" % paths[index])
