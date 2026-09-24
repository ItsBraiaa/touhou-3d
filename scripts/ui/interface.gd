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


func _ready() -> void:
	if not _validate_exports():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_settings = Settings.new(settings_path)
	# A bad user file is not a setup error: the defaults are in use and play goes on.
	for message: String in _settings.load_file():
		push_warning("%s: %s" % [get_path(), message])
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
	_router.screen_hidden.connect(_on_screen_hidden)
	_router.screen_shown.connect(_on_screen_shown)


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


func _go_back() -> void:
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
