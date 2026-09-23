class_name MenuController
extends Control
## Adapter shared by the eight menu scenes of GUIDE Section 14. Knows its screen from
## the root node name, turns the registry's buttons into [signal action_requested],
## takes focus in [method enter] and hands it back in [method leave], writes the
## runtime text a screen is opened with, and hides the keyboard footer while a gamepad
## is in use.
##
## Navigation is not decided here: [Interface] drives [method enter] and
## [method leave] from its [ScreenRouter], and the Session decides what an action does.


## A registry button was pressed. [param action] is its row in
## [constant ACTIONS_BY_SCREEN]; [param payload] is a new Dictionary, empty except for
## `start_direct_stage`, which carries `{"stage": &"stage_01"}` or `&"stage_02"`.
signal action_requested(action: StringName, payload: Dictionary)

## Router id of each menu scene, by the scene's root node name.
const SCREEN_IDS: Dictionary[StringName, StringName] = {
	&"MainMenu": ScreenRouter.MAIN_MENU,
	&"StageSelect": ScreenRouter.STAGE_SELECT,
	&"Options": ScreenRouter.OPTIONS,
	&"Controls": ScreenRouter.CONTROLS,
	&"Credits": ScreenRouter.CREDITS,
	&"PauseMenu": ScreenRouter.PAUSE,
	&"Defeat": ScreenRouter.DEFEAT,
	&"Results": ScreenRouter.RESULTS,
}
## GUIDE Section 14 "Scene and action registry", one entry per button row: screen id,
## then button path relative to the scene root, then the action it requests. Renaming
## one of these buttons in a scene needs the same change here.
const ACTIONS_BY_SCREEN: Dictionary[StringName, Dictionary] = {
	ScreenRouter.MAIN_MENU: {
		"Layout/StartButton": &"start_campaign",
		"Layout/StageSelectButton": &"open_stage_select",
		"Layout/OptionsButton": &"open_options",
		"Layout/QuitButton": &"quit",
	},
	ScreenRouter.STAGE_SELECT: {
		"Layout/ForestCard/SelectButton": &"start_direct_stage",
		"Layout/MountainCard/SelectButton": &"start_direct_stage",
		"Layout/BackButton": &"back",
	},
	ScreenRouter.OPTIONS: {
		"Layout/Controls/BindingsButton": &"open_controls",
		"Layout/DefaultsButton": &"restore_defaults",
		"Layout/CreditsButton": &"open_credits",
		"Layout/BackButton": &"back",
	},
	ScreenRouter.CONTROLS: {
		"Layout/BackButton": &"back",
	},
	ScreenRouter.PAUSE: {
		"Layout/ResumeButton": &"resume",
		"Layout/RestartButton": &"restart_stage",
		"Layout/OptionsButton": &"open_options",
		"Layout/MenuButton": &"return_to_menu",
	},
	ScreenRouter.DEFEAT: {
		"Layout/RetryButton": &"retry",
		"Layout/MenuButton": &"return_to_menu",
	},
	# In the authored focus order, which the loop rebuilt for each run mode follows.
	ScreenRouter.RESULTS: {
		"Layout/ContinueButton": &"continue_campaign",
		"Layout/ReplayButton": &"replay_stage",
		"Layout/MenuButton": &"return_to_menu",
		"Layout/CreditsButton": &"open_credits",
	},
	ScreenRouter.CREDITS: {
		"Layout/BackButton": &"back",
	},
}
## Payload of the buttons that carry one, by screen and path. The stage ids are
## [constant RunState.CAMPAIGN_ORDER]'s.
const PAYLOADS_BY_SCREEN: Dictionary[StringName, Dictionary] = {
	ScreenRouter.STAGE_SELECT: {
		"Layout/ForestCard/SelectButton": {"stage": &"stage_01"},
		"Layout/MountainCard/SelectButton": {"stage": &"stage_02"},
	},
}
## The one label each screen writes on [method enter]: Pause's score and Graze,
## Defeat's retry location, Results' heading.
const LABEL_BY_SCREEN: Dictionary[StringName, String] = {
	ScreenRouter.PAUSE: "Layout/Score",
	ScreenRouter.DEFEAT: "Layout/RetryLocation",
	ScreenRouter.RESULTS: "Layout/Heading",
}
## The keyboard hint at the bottom of the five full screens. Pause, Defeat and Results
## are authored without one.
const FOOTER_PATH := ^"Layout/NavigationHint"
## Results `mode` param: Campaign Stage 1 cleared, so Continue leads to Stage 2. Also the
## layout when `mode` is absent, which is how the scene is authored.
const RESULTS_CAMPAIGN_STAGE := &"campaign_stage_1"
## Results `mode` param: a Direct Stage cleared; Replay takes Continue's place.
const RESULTS_DIRECT_STAGE := &"direct_stage"
## Results `mode` param: the Campaign's last stage cleared; neither Continue nor Replay.
const RESULTS_FINAL_VICTORY := &"final_victory"
## A stick has to pass this far before it counts as gamepad use, so drift near the
## center does not hide the keyboard hint. Godot's default for the `ui_*` actions.
const JOYPAD_AXIS_THRESHOLD := 0.5

var _screen: StringName = &""
## The registry buttons found in the scene, by path, in table order.
var _buttons: Dictionary[String, BaseButton] = {}
var _label: Label
## [member _label]'s authored text, restored when a screen is entered without the
## param that replaces it.
var _authored_label_text: String = ""
var _footer: Control


func _ready() -> void:
	_screen = get_screen_id()
	if _screen.is_empty():
		push_error("%s: root name '%s' is not a menu screen of GUIDE Section 14" % [get_path(), name])
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_connect_buttons()
	if _screen in LABEL_BY_SCREEN:
		_label = get_node_or_null(LABEL_BY_SCREEN[_screen]) as Label
		if _label == null:
			push_error("%s: screen %s has no Label at '%s'; its runtime text is skipped" % [get_path(), _screen, LABEL_BY_SCREEN[_screen]])
		else:
			_authored_label_text = _label.text
	_footer = get_node_or_null(FOOTER_PATH) as Control
	if _footer == null:
		set_process_input(false)
	else:
		Input.joy_connection_changed.connect(_on_joy_connection_changed)


## Tracks the last device used, for the footer. [method _input] rather than unhandled
## input, because a focused button consumes the gamepad's accept press.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_set_gamepad_active(true)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= JOYPAD_AXIS_THRESHOLD:
		_set_gamepad_active(true)
	elif event is InputEventKey:
		_set_gamepad_active(false)


## The [ScreenRouter] id of this screen, from the root node name, or an empty
## StringName when the name is not one of [constant SCREEN_IDS]. Valid before
## [method Node._ready], so [Interface] can read it before adding the scene.
func get_screen_id() -> StringName:
	return SCREEN_IDS.get(name, &"")


## Shows the screen, writes the text [param params] carry, and gives focus to the
## control at [param focus_path] (relative to this root) when it can take it, else to
## the first visible focusable control in tree order. Params by screen:
## [br]- Pause: `score` and `graze` (ints) fill `Layout/Score`; a missing one shows a dash.
## [br]- Defeat: `checkpoint` (the latest Checkpoint's id) names the retry location;
## absent or empty means the stage entry.
## [br]- Results: `mode`, one of [constant RESULTS_CAMPAIGN_STAGE],
## [constant RESULTS_DIRECT_STAGE] or [constant RESULTS_FINAL_VICTORY], picks which of
## Continue and Replay is shown and the heading, and rebuilds the focus loop without
## the hidden buttons.
func enter(params: Dictionary, focus_path: NodePath) -> void:
	show()
	if _label != null:
		if _screen == ScreenRouter.PAUSE:
			_label.text = "Pontos  %s     Graze  %s" % [_value_or_dash(params, "score"), _value_or_dash(params, "graze")]
		elif _screen == ScreenRouter.DEFEAT:
			var checkpoint := str(params.get("checkpoint", ""))
			_label.text = "Início da fase" if checkpoint.is_empty() else "Último checkpoint · %s" % checkpoint
	if _screen == ScreenRouter.RESULTS:
		_apply_results_mode(StringName(params.get("mode", RESULTS_CAMPAIGN_STAGE)))
	var target: Control = null
	if not focus_path.is_empty():
		target = get_node_or_null(focus_path) as Control
	if not _can_take_focus(target):
		target = _first_focusable()
	if target != null:
		target.grab_focus()


## Hides the screen and returns the path, relative to this root, of the control that
## had focus in it, for the router to hand back to [method enter] on return. Empty
## when nothing inside this screen had focus.
func leave() -> NodePath:
	var focused := get_viewport().gui_get_focus_owner()
	var path := get_path_to(focused) if focused != null and is_ancestor_of(focused) else NodePath()
	hide()
	return path


func _connect_buttons() -> void:
	var actions: Dictionary = ACTIONS_BY_SCREEN[_screen]
	var payloads: Dictionary = PAYLOADS_BY_SCREEN.get(_screen, {})
	for path: String in actions:
		var button := get_node_or_null(path) as BaseButton
		if button == null:
			push_error("%s: screen %s has no button at '%s'; its action '%s' is skipped" % [get_path(), _screen, path, actions[path]])
			continue
		_buttons[path] = button
		button.pressed.connect(_on_button_pressed.bind(actions[path], payloads.get(path, {})))


func _apply_results_mode(mode: StringName) -> void:
	if mode not in [RESULTS_CAMPAIGN_STAGE, RESULTS_DIRECT_STAGE, RESULTS_FINAL_VICTORY]:
		push_error("%s: unknown Results mode '%s'; showing the Campaign layout" % [get_path(), mode])
		mode = RESULTS_CAMPAIGN_STAGE
	_set_button_visible("Layout/ContinueButton", mode == RESULTS_CAMPAIGN_STAGE)
	_set_button_visible("Layout/ReplayButton", mode == RESULTS_DIRECT_STAGE)
	if _label != null:
		_label.text = "Jornada concluída" if mode == RESULTS_FINAL_VICTORY else _authored_label_text
	var loop: Array[BaseButton] = []
	for button: BaseButton in _buttons.values():
		if button.visible:
			loop.append(button)
	_link_focus_loop(loop)


func _set_button_visible(path: String, shown: bool) -> void:
	if path in _buttons:
		_buttons[path].visible = shown


## Chains [param controls] through `focus_next` and `focus_previous`, wrapping at both
## ends, so Tab never lands on a hidden button. Up and down need nothing: Godot's
## directional search already skips hidden controls.
static func _link_focus_loop(controls: Array[BaseButton]) -> void:
	for index: int in controls.size():
		var control := controls[index]
		var next := controls[(index + 1) % controls.size()]
		var previous := controls[index - 1]
		control.focus_next = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)


static func _can_take_focus(control: Control) -> bool:
	return control != null and control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree()


## The first control in tree order that can take focus. Options starts on its first
## slider rather than its first button, which is the top of its authored focus loop.
func _first_focusable() -> Control:
	for node: Node in find_children("*", "Control", true, false):
		var control := node as Control
		if _can_take_focus(control):
			return control
	return null


static func _value_or_dash(params: Dictionary, key: String) -> String:
	return str(params[key]) if key in params else "—"


func _set_gamepad_active(active: bool) -> void:
	_footer.visible = not active


## A gamepad unplugged while it was the last device used would otherwise keep the
## keyboard hint hidden until the next key press.
func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	if Input.get_connected_joypads().is_empty():
		_set_gamepad_active(false)


func _on_button_pressed(action: StringName, payload: Dictionary) -> void:
	action_requested.emit(action, payload.duplicate(true))
