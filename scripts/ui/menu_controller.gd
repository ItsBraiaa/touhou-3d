class_name MenuController
extends Control
## Adapter shared by the eight menu scenes of GUIDE Section 14. Knows its screen from
## the root node name, turns the registry's buttons into [signal action_requested],
## takes focus in [method enter] and hands it back in [method leave], writes the
## runtime text a screen is opened with, and writes the navigation footer from the current
## bindings in the prompt family [Interface] gives it ([method set_prompts], F16-03).
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
## Results' four statistics (GUIDE Section 14 "Runtime text and presentation"): each
## [method enter] param, by name, and the Label it fills. Load-bearing since F11-01.
const RESULTS_VALUE_PATHS: Dictionary[String, String] = {
	"clear_time": "Layout/TimeValue",
	"score": "Layout/ScoreValue",
	"graze": "Layout/GrazeValue",
	"bombs_used": "Layout/BombsValue",
}
## The navigation hint at the bottom of the five full screens. Pause, Defeat and Results
## are authored without one.
const FOOTER_PATH := ^"Layout/NavigationHint"
## The prompt family of the keyboard and mouse ([method InputDeviceState.get_prompt_family]).
const KEYBOARD_FAMILY := &"keyboard_mouse"
## Results `mode` param: Campaign Stage 1 cleared, so Continue leads to Stage 2. Also the
## layout when `mode` is absent, which is how the scene is authored.
const RESULTS_CAMPAIGN_STAGE := &"campaign_stage_1"
## Results `mode` param: a Direct Stage cleared; Replay takes Continue's place.
const RESULTS_DIRECT_STAGE := &"direct_stage"
## Results `mode` param: the Campaign's last stage cleared; neither Continue nor Replay.
const RESULTS_FINAL_VICTORY := &"final_victory"
## The footers of a menu that was never given its bindings (one instanced on its own, as
## the menu contract test does): F15-07's texts for the default bindings. [Interface] gives
## every menu the live bindings at boot, so the game never shows these.
const KEYBOARD_NAVIGATION_HINT := "↑ ↓  Navegar     Enter  Confirmar"
const GAMEPAD_NAVIGATION_HINT := "Analógico  Navegar     A  Confirmar     B  Voltar"

var _screen: StringName = &""
## The registry buttons found in the scene, by path, in table order.
var _buttons: Dictionary[String, BaseButton] = {}
var _label: Label
## [member _label]'s authored text, restored when a screen is entered without the
## param that replaces it.
var _authored_label_text: String = ""
## Results' value Labels found in the scene, by param name; a missing one was reported.
var _results_values: Dictionary[String, Label] = {}
var _footer: Control
var _prompt_family: StringName = KEYBOARD_FAMILY
## The live bindings the footer names, from [method set_prompts]; null until then.
var _prompt_bindings: InputBindings


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
	if _screen == ScreenRouter.RESULTS:
		_find_results_values()
	_footer = get_node_or_null(FOOTER_PATH) as Control


## Writes the footer from [param bindings] (the live [InputBindings]) in the prompt
## [param family] (`&"keyboard_mouse"`, `&"xbox"` or `&"playstation"`): the first bound slot
## of `ui_up` and `ui_down` to navigate, `ui_accept` to confirm and, except on the main menu,
## which has nothing to go back to, `ui_cancel` to go back. [Interface] calls it on every
## menu at boot and whenever the family or the bindings change (F16-03), so the menus never
## disagree and no shortcut is fixed text. Does nothing on Pause, Defeat and Results, which
## are authored without a footer.
func set_prompts(family: StringName, bindings: InputBindings) -> void:
	_prompt_family = family
	_prompt_bindings = bindings
	_write_footer()


## The keyboard's prompts when [param shown], else the gamepad's (F3-03's call, kept for a
## menu on its own): the Xbox family, from the bindings [method set_prompts] gave, or
## F15-07's default texts before it did.
func set_keyboard_prompts(shown: bool) -> void:
	_prompt_family = KEYBOARD_FAMILY if shown else &"xbox"
	_write_footer()


## The first bound slot of [param action] in the profile [param family] reads (the
## keyboard's for `&"keyboard_mouse"`, else the gamepad's), named by
## [method describe_binding] in [param family]; [constant BindingLabels.UNBOUND] when every
## slot is blank. The fixed Numpad Enter is never named.
static func prompt_for(action: StringName, family: StringName, bindings: InputBindings) -> String:
	var profile := InputBindings.KEYBOARD_MOUSE if family == KEYBOARD_FAMILY else InputBindings.GAMEPAD
	for binding: Dictionary in bindings.get_bindings(profile, action):
		if not binding.is_empty():
			return describe_binding(binding, family)
	return BindingLabels.UNBOUND


## [method BindingLabels.describe], except on the headless display server, which has no
## keyboard layout and reports an error for every physical-key lookup (the suite and the
## boot smoke run there): a physical key is named by its own code. Every prompt goes
## through it.
static func describe_binding(binding: Dictionary, family: StringName) -> String:
	if binding.get("physical", false) and DisplayServer.get_name() == "headless":
		var by_code := binding.duplicate()
		by_code["physical"] = false
		return BindingLabels.describe(by_code, family)
	return BindingLabels.describe(binding, family)


## The [ScreenRouter] id of this screen, from the root node name, or an empty
## StringName when the name is not one of [constant SCREEN_IDS]. Valid before
## [method Node._ready], so [Interface] can read it before adding the scene.
func get_screen_id() -> StringName:
	return SCREEN_IDS.get(name, &"")


## Shows the screen, writes the text [param params] carry, and gives focus to the
## control at [param focus_path] (relative to this root) when it can take it, else to
## the first visible focusable control in tree order. Params by screen:
## [br]- Pause: `score` and `graze` (ints) fill `Layout/Score`; a missing one shows a dash.
## [br]- Defeat: `checkpoint` (the latest Checkpoint's `display_name`) names the retry
## location; absent or empty means the stage entry.
## [br]- Results: `mode`, one of [constant RESULTS_CAMPAIGN_STAGE],
## [constant RESULTS_DIRECT_STAGE] or [constant RESULTS_FINAL_VICTORY], picks which of
## Continue and Replay is shown and the heading, and rebuilds the focus loop without
## the hidden buttons. `clear_time` (seconds) shows as `M:SS`, seconds floored, and
## `score`, `graze` and `bombs_used` as integers; a missing one shows a dash.
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
		_write_results_values(params)
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


## Finds Results' four value Labels, reporting each missing one once, here.
func _find_results_values() -> void:
	for key: String in RESULTS_VALUE_PATHS:
		var value_label := get_node_or_null(RESULTS_VALUE_PATHS[key]) as Label
		if value_label == null:
			push_error("%s: screen %s has no Label at '%s'; its '%s' value is skipped" % [get_path(), _screen, RESULTS_VALUE_PATHS[key], key])
			continue
		_results_values[key] = value_label


func _write_results_values(params: Dictionary) -> void:
	for key: String in _results_values:
		var text := "—"
		if key in params:
			text = _format_clear_time(float(params[key])) if key == "clear_time" else str(int(params[key]))
		_results_values[key].text = text


## [param seconds] as `M:SS`, the seconds floored: 125.9 is `2:05`. Claude's proposal.
## Snapped to the millisecond first, so 180 ticks of 1/60 s, which sum to 2.99999, read
## `0:03`.
static func _format_clear_time(seconds: float) -> String:
	var whole := floori(snappedf(maxf(seconds, 0.0), 0.001))
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]


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


func _write_footer() -> void:
	if _footer == null:
		return
	var footer_label := _footer as Label
	if footer_label != null:
		footer_label.text = _footer_text()
	_footer.visible = true


func _footer_text() -> String:
	if _prompt_bindings == null:
		return KEYBOARD_NAVIGATION_HINT if _prompt_family == KEYBOARD_FAMILY else GAMEPAD_NAVIGATION_HINT
	var up := prompt_for(&"ui_up", _prompt_family, _prompt_bindings)
	var down := prompt_for(&"ui_down", _prompt_family, _prompt_bindings)
	var parts := PackedStringArray([
		"%s  Navegar" % _pair_label(up, down),
		"%s  Confirmar" % prompt_for(&"ui_accept", _prompt_family, _prompt_bindings),
	])
	if _screen != ScreenRouter.MAIN_MENU:
		parts.append("%s  Voltar" % prompt_for(&"ui_cancel", _prompt_family, _prompt_bindings))
	return "     ".join(parts)


## Two prompts as one: `Seta ↑` and `Seta ↓` share their first word and read `Seta ↑/↓`;
## any other pair reads `W/S`.
static func _pair_label(first: String, second: String) -> String:
	var split := first.rfind(" ")
	if split > 0 and split == second.rfind(" ") and first.left(split) == second.left(split):
		return "%s/%s" % [first, second.substr(split + 1)]
	return "%s/%s" % [first, second]


func _on_button_pressed(action: StringName, payload: Dictionary) -> void:
	action_requested.emit(action, payload.duplicate(true))
