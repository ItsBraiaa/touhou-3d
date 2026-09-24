class_name Interface
extends CanvasLayer
## Adapter on `Main/Interface`: instances the eight menu scenes and the HUD once, shows,
## hides and focuses them as its [ScreenRouter] reports, and passes the menus' action
## requests up to the Session. Processes while the tree is paused (`scenes/main.tscn`
## sets it to always), so the menus work over a paused game.
##
## Back is handled here and never reaches the Session: a Back button and `ui_cancel` both
## return to the caller, except on Pause, where they request `resume`, because only the
## Session can unpause the tree.
##
## It also owns the one [Settings] (F3-02): read from [member settings_path] once in
## `_ready`, bound to the Options widgets through an [OptionsScreen] it creates under the
## Options root, and handed to the rest of the game by [method get_settings]. Defaults
## (`restore_defaults`) is resolved here and never reaches the Session.
##
## And it owns the one [InputDeviceState] (F3-03): every input event and joypad
## connection change is noted there, every menu's navigation hint names the live bindings
## in its prompt family (F16-03), and a controller leaving while the HUD is on top pauses
## the game through the ordinary `pause` action. The saved Ícones do controle choice is its
## glyph override.
##
## And the one [InputBindingAdapter] (F16-02), the only [InputMap] writer for the
## catalog actions: the saved binding profiles are installed right after the settings
## load, before any menu exists, and again whenever [Settings] changes them. On leaving
## the tree the catalog actions go back to their `project.godot` events.
##
## And the Controls screen's [ControlsScreen] (F16-03), created under the Controls root
## like the [OptionsScreen]: its open dialogs see every input event first
## ([method ControlsScreen.consume_modal_input]), and Back from Controls asks it first
## ([method ControlsScreen.request_leave]), so an unapplied draft is never lost silently.
##
## The mouse pointer is not this node's: [GameSession] captures it for mouse look only while
## the player flies with the HUD on top, so every menu, Controls and its capture dialog
## included, has a free cursor (F16-06).


## The Session should act on [param action]: every [signal MenuController.action_requested]
## except `back`, plus `resume` when Back is pressed on Pause and `back_refused` when a
## menu has nothing to go back to (the main menu, Defeat, Results).
signal action_requested(action: StringName, payload: Dictionary)

## The eight scenes of GUIDE Section 14, each with a [MenuController] root. Order does
## not matter: each is identified by its root node name.
@export var menu_scenes: Array[PackedScene] = []
## GUIDE Section 15's combat HUD, drawn below every menu. Its root must be a [Hud].
@export var hud_scene: PackedScene
## The settings file, read once in `_ready` and written after each explicit Options change.
## Only the real game uses the default; tests inject their own path.
@export var settings_path: String = Settings.DEFAULT_PATH

var _router := ScreenRouter.new()
var _menus: Dictionary[StringName, MenuController] = {}
var _hud: Hud
var _settings: Settings
## Null when the Options screen is missing (already reported).
var _options_screen: OptionsScreen
## Null when the Controls screen is missing (already reported).
var _controls_screen: ControlsScreen
var _device_state := InputDeviceState.new()
var _binding_adapter := InputBindingAdapter.new()


func _ready() -> void:
	if not _validate_exports():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_settings = Settings.new(settings_path)
	# A bad user file is not a setup error: the defaults are in use and play goes on.
	for message: String in _settings.load_file():
		push_warning("%s: %s" % [get_path(), message])
	_install_bindings()
	var hud_node := hud_scene.instantiate()
	_hud = hud_node as Hud
	if _hud == null:
		push_error("%s: 'hud_scene' %s does not have a Hud root" % [get_path(), hud_scene.resource_path])
		hud_node.free()
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	# Added first, so every menu, overlays included, draws above it.
	add_child(_hud)
	_hud.hide()
	for scene: PackedScene in menu_scenes:
		_add_menu(scene)
	for id: StringName in MenuController.SCREEN_IDS.values():
		if id not in _menus:
			push_error("%s: no scene in 'menu_scenes' has the %s screen" % [get_path(), id])
	_bind_options()
	_bind_controls()
	_start_device_tracking()
	_router.screen_hidden.connect(_on_screen_hidden)
	_router.screen_shown.connect(_on_screen_shown)


## The [InputMap] outlives this node (a test builds `main.tscn` again and again), so the
## saved profiles leave with it.
func _exit_tree() -> void:
	_binding_adapter.apply_defaults()


## Notes the device behind every event for the prompts. [method _input] rather than
## unhandled input, because a focused button consumes the gamepad's accept press. The
## event is handled here only when a Controls dialog consumes it, before the GUI and every
## other handler see it (F16-03).
func _input(event: InputEvent) -> void:
	_device_state.note_event(event)
	if _controls_screen != null and _controls_screen.consume_modal_input(event):
		get_viewport().set_input_as_handled()


## `ui_cancel` belongs to the menus only while one is on top. Over running gameplay the
## same Escape press is the Session's `pause` action, so it is left unhandled there.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	var current := _router.current()
	if current.is_empty() or current == ScreenRouter.HUD:
		return
	get_viewport().set_input_as_handled()
	_go_back()


## Clears every screen and shows the full screen [param id] with its initial focus:
## [constant ScreenRouter.MAIN_MENU] when entering the menus, [constant ScreenRouter.HUD]
## when an Attempt starts.
func show_home(id: StringName) -> void:
	_router.home(id)


## Shows the full screen [param id] over the current one, which Back returns to with its
## focus restored. [param params] reach [method MenuController.enter].
func show_screen(id: StringName, params: Dictionary = {}) -> void:
	_router.replace(id, params)


## Shows the overlay [param id] (Pause, Defeat, Results) above the current screen, which
## stays visible under it.
func push_overlay(id: StringName, params: Dictionary = {}) -> void:
	_router.push(id, params)


## Removes the top screen and returns to its caller. False when there is nothing to
## return to. Removing Pause this way does not unpause the tree; the Session does that.
func back() -> bool:
	return _router.back()


## The screen on top, which has focus. Empty before the first [method show_home].
func current_screen() -> StringName:
	return _router.current()


## Whether a menu or overlay is shown over running gameplay.
func is_gameplay_covered() -> bool:
	return _router.is_gameplay_covered()


## The HUD instance, for the Session to bind. Null when [member hud_scene] is unset or
## its root is not a [Hud].
func get_hud() -> Hud:
	return _hud


## The one [Settings], loaded at boot: camera sensitivity and invert vertical for F3-04,
## the input device for F3-03. Null only when the exports failed validation.
func get_settings() -> Settings:
	return _settings


## The one [InputBindingAdapter], for F16-03's capture ([method
## InputBindingAdapter.describe_event]). Profiles reach the [InputMap] through
## [method Settings.apply_input_bindings], which this node installs; nothing else applies
## them.
func get_input_binding_adapter() -> InputBindingAdapter:
	return _binding_adapter


## Reports each unset export with this node's path (CONVENTIONS "Setup errors are loud").
## A missing menu screen is reported later, once the scenes are identified.
func _validate_exports() -> bool:
	var valid := true
	if hud_scene == null:
		push_error("%s: required export 'hud_scene' is not set" % get_path())
		valid = false
	if menu_scenes.has(null):
		push_error("%s: 'menu_scenes' has an empty slot" % get_path())
		valid = false
	return valid


## Instances [param scene] hidden and connects its requests, unless its root is not a
## [MenuController] or its screen is already taken.
func _add_menu(scene: PackedScene) -> void:
	var node := scene.instantiate()
	var menu := node as MenuController
	var problem := ""
	if menu == null:
		problem = "does not have a MenuController root"
	elif menu.get_screen_id().is_empty():
		problem = "has a root named '%s', which is not a menu screen" % node.name
	elif menu.get_screen_id() in _menus:
		problem = "repeats the %s screen" % menu.get_screen_id()
	if not problem.is_empty():
		push_error("%s: 'menu_scenes' entry %s %s; skipped" % [get_path(), scene.resource_path, problem])
		node.free()
		return
	add_child(menu)
	menu.hide()
	menu.action_requested.connect(_on_action_requested)
	_menus[menu.get_screen_id()] = menu


## Back from Controls waits while [ControlsScreen] settles an unapplied draft; it emits
## [signal ControlsScreen.leave_requested] once the player chose.
func _go_back() -> void:
	if _router.current() == ScreenRouter.CONTROLS and _controls_screen != null and not _controls_screen.request_leave():
		return
	if _router.current() == ScreenRouter.PAUSE:
		action_requested.emit(&"resume", {})
	elif not _router.back():
		action_requested.emit(&"back_refused", {})


## The Options root gets an [OptionsScreen] child (under it, not under this node, whose
## children are the HUD and the eight menus), which binds and applies the settings.
func _bind_options() -> void:
	var options: MenuController = _menus.get(ScreenRouter.OPTIONS)
	if options == null:
		return
	_options_screen = OptionsScreen.new()
	_options_screen.name = &"OptionsScreen"
	options.add_child(_options_screen)
	_options_screen.setup(options, _settings)


## The Controls root gets a [ControlsScreen] child the same way (F16-03), bound to the live
## bindings and the adapter that names captured events.
func _bind_controls() -> void:
	var controls: MenuController = _menus.get(ScreenRouter.CONTROLS)
	if controls == null:
		return
	_controls_screen = ControlsScreen.new()
	_controls_screen.name = &"ControlsScreen"
	controls.add_child(_controls_screen)
	_controls_screen.setup(controls, _settings, _settings.get_input_bindings(), _binding_adapter)
	_controls_screen.leave_requested.connect(_go_back)


## Seeds the [InputDeviceState] with the saved mode, the saved glyph override and the pads
## already connected, connects its sources once, and pushes the first prompts to every menu.
func _start_device_tracking() -> void:
	_device_state.set_mode(_settings.get_input_device())
	_device_state.set_glyph_override(_settings.get_controller_glyph_family())
	for device: int in Input.get_connected_joypads():
		_device_state.note_joypad(device, true)
	_device_state.prompt_family_changed.connect(_on_prompt_family_changed)
	_device_state.controller_family_changed.connect(_on_prompt_family_changed)
	_settings.changed.connect(_on_settings_changed)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_push_prompts()


func _on_prompt_family_changed(_family: StringName) -> void:
	_push_prompts()


## Every menu's footer and the Controls screen follow the live bindings and families.
func _push_prompts() -> void:
	var family := _device_state.get_prompt_family()
	var bindings := _settings.get_input_bindings()
	for menu: MenuController in _menus.values():
		menu.set_prompts(family, bindings)
	if _controls_screen != null:
		_controls_screen.set_prompt_families(family, _device_state.get_controller_family())


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == Settings.INPUT_DEVICE:
		_device_state.set_mode(value)
	elif key == Settings.CONTROLLER_GLYPH_FAMILY:
		_device_state.set_glyph_override(value)
	elif key == Settings.BINDING_PROFILES:
		_apply_bindings()
		_push_prompts()


## Installs the saved binding profiles (F16-02), before any menu exists, so the first
## screen already answers to them. An editor build first checks the catalog defaults
## against `project.godot`: a drift means Restaurar would not restore the project's keys.
func _install_bindings() -> void:
	if OS.has_feature("editor"):
		for message: String in _binding_adapter.find_default_drift():
			push_error("%s: %s" % [get_path(), message])
	_apply_bindings()


## [Settings] only holds validated profiles, so a refusal here is a programming error.
func _apply_bindings() -> void:
	for message: String in _binding_adapter.apply_bindings(_settings.get_input_bindings()):
		push_error("%s: %s" % [get_path(), message])


## A controller leaving while the HUD is on top pauses (PLANEJAMENTO Section 7), unless
## the mode is Teclado. Pause, Options from Pause, Defeat, Results and the menus are left
## alone, so nothing is ever resumed or toggled by an unplug.
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_device_state.note_joypad(device, connected)
	if _controls_screen != null:
		_controls_screen.note_joypad_connection(connected)
	if not connected and _device_state.pauses_on_disconnect() and _router.current() == ScreenRouter.HUD:
		_request_pause()


## Sends a `pause` press and release through [Input], so it reaches
## [method GameSession._unhandled_input] like Start or Escape: the Session pauses only
## while a stage is in play, and the keyboard can then drive Pause.
func _request_pause() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = &"pause"
		event.pressed = pressed
		Input.parse_input_event(event)


func _on_action_requested(action: StringName, payload: Dictionary) -> void:
	if action == &"back":
		_go_back()
	elif action == &"restore_defaults":
		if _options_screen != null:
			_options_screen.restore_defaults()
	else:
		action_requested.emit(action, payload)


## A menu leaving the screen hands its focus to the router first. A covered screen is
## still on the stack, so the router keeps it; a screen Back removed is not, so it is
## dropped (menus-session.md "Focus memory").
func _on_screen_hidden(id: StringName) -> void:
	if id in _menus:
		_router.remember_focus(id, _menus[id].leave())
	elif id == ScreenRouter.HUD:
		_hud.hide()


func _on_screen_shown(id: StringName, params: Dictionary) -> void:
	if id in _menus:
		_menus[id].enter(params, _router.focus_for(id))
	elif id == ScreenRouter.HUD:
		_hud.show()
