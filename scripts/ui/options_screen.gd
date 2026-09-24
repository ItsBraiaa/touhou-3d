class_name OptionsScreen
extends Node
## Adapter between the Options screen's eight widgets (GUIDE Section 14 "Options values and
## fields") and the one [Settings]. [Interface] creates it in code under the Options root
## and calls [method setup] once; no scene attaches it.
##
## [method setup] writes every widget from the stored values before it connects a single
## callback, then applies the three volume buses and the display: that is the boot
## application. A user edit is sanitised by [method Settings.set_value], saved when it
## changed something, and written back to its widget. [signal Settings.changed] is the one
## place anything is applied, whatever changed the value (a widget, Defaults, or another
## caller). Camera sensitivity, invert vertical and the input device are only stored here:
## F3-04 applies the camera values and F3-03 the input device. The Controls screen's Câmera
## tab ([ControlsScreen]) edits the same two camera values, so either screen shows the
## other's change.


## The display was applied: [param window_mode], and the window size set for Janela, or
## [constant Vector2i.ZERO] in fullscreen. The headless DisplayServer ignores window
## changes, so this is how a caller sees them.
signal display_applied(window_mode: Settings.WindowMode, window_size: Vector2i)


## Each [Settings] key's widget, relative to the Options root (GUIDE Section 14).
const WIDGET_PATHS: Dictionary[StringName, NodePath] = {
	Settings.MASTER_VOLUME: ^"Layout/Audio/MasterVolume",
	Settings.MUSIC_VOLUME: ^"Layout/Audio/MusicVolume",
	Settings.SFX_VOLUME: ^"Layout/Audio/SfxVolume",
	Settings.WINDOW_MODE: ^"Layout/Display/WindowMode",
	Settings.RESOLUTION: ^"Layout/Display/Resolution",
	Settings.INPUT_DEVICE: ^"Layout/Controls/InputDevice",
	Settings.CAMERA_SENSITIVITY: ^"Layout/Controls/Sensitivity",
	Settings.INVERT_VERTICAL: ^"Layout/Controls/InvertVertical",
}
## Each volume key's audio bus (F0-03).
const BUS_BY_KEY: Dictionary[StringName, StringName] = {
	Settings.MASTER_VOLUME: &"Master",
	Settings.MUSIC_VOLUME: &"Music",
	Settings.SFX_VOLUME: &"SFX",
}

var _settings: Settings
## The widgets that passed their check in [method setup], by key.
var _widgets: Dictionary[StringName, Control] = {}
## Buses already reported missing, so each is reported once.
var _missing_buses: Dictionary[StringName, bool] = {}


## Binds the widgets under [param options] to [param settings], once: resolves and checks
## each widget (a missing, mistyped or mismatched one is reported with its path and left
## unbound, and the rest still bind), writes them all without signals, connects their
## callbacks and [signal Settings.changed], then applies the buses and the display.
func setup(options: Control, settings: Settings) -> void:
	if _settings != null:
		push_error("%s: setup was already called; ignored" % get_path())
		return
	_settings = settings
	for key: StringName in Settings.KEYS:
		var widget := _checked_widget(options, key)
		if widget != null:
			_widgets[key] = widget
	for key: StringName in _widgets:
		_write_widget(key)
	for key: StringName in _widgets:
		_connect_widget(key)
	_settings.changed.connect(_on_settings_changed)
	for key: StringName in BUS_BY_KEY:
		_apply_bus(key)
	_apply_display()


## Restores every field to GUIDE Section 14's defaults and saves once. Each field that
## differed is applied and written back through [signal Settings.changed]. That covers the
## F16 values and both binding profiles too ([method Settings.restore_defaults]):
## [Interface] reinstalls the profiles and the glyph family, and the Controls screen's
## widgets follow the same signal, its next draft starting from the defaults.
func restore_defaults() -> void:
	if _settings == null:
		return
	_settings.restore_defaults()
	_save()


## The window size for [param resolution] on a screen whose usable area is
## [param usable]: the resolution itself when it fits, or when [param usable] has no area
## (headless); otherwise the largest [constant Settings.RESOLUTIONS] entry that fits, or
## the smallest when none does.
static func window_size_for(resolution: Vector2i, usable: Vector2i) -> Vector2i:
	if usable.x <= 0 or usable.y <= 0 or _fits(resolution, usable):
		return resolution
	var best := Settings.RESOLUTIONS[0]
	for candidate: Vector2i in Settings.RESOLUTIONS:
		if _fits(candidate, usable) and candidate.x > best.x:
			best = candidate
	return best


static func _fits(size: Vector2i, usable: Vector2i) -> bool:
	return size.x <= usable.x and size.y <= usable.y


func _on_settings_changed(key: StringName, _value: Variant) -> void:
	if BUS_BY_KEY.has(key):
		_apply_bus(key)
	elif key == Settings.WINDOW_MODE or key == Settings.RESOLUTION:
		_apply_display()
	if _widgets.has(key):
		_write_widget(key)


func _on_range_changed(value: float, key: StringName) -> void:
	if key == Settings.CAMERA_SENSITIVITY:
		_commit(key, value)
	else:
		_commit(key, roundi(value))


func _on_item_selected(index: int, key: StringName) -> void:
	if key != Settings.RESOLUTION:
		_commit(key, index)
	elif index >= 0 and index < Settings.RESOLUTIONS.size():
		_commit(key, Settings.RESOLUTIONS[index])


func _on_toggled(pressed: bool, key: StringName) -> void:
	_commit(key, pressed)


## A user edit: store it (applied through [signal Settings.changed]), save when it changed
## something, and show the stored value, which sanitising may have adjusted.
func _commit(key: StringName, value: Variant) -> void:
	if _settings.set_value(key, value):
		_save()
	_write_widget(key)


func _save() -> void:
	var error := _settings.save_file()
	if error != OK:
		push_warning("%s: settings could not be saved to '%s' (%s); play goes on" % [
			get_path(), _settings.get_file_path(), error_string(error),
		])


## Shows the stored value of [param key] on its widget without emitting a signal.
func _write_widget(key: StringName) -> void:
	var widget := _widgets[key]
	var value: Variant = _settings.get_value(key)
	if widget is OptionButton:
		var index: int = Settings.RESOLUTIONS.find(value) if key == Settings.RESOLUTION else value
		(widget as OptionButton).select(index)
	elif widget is BaseButton:
		(widget as BaseButton).set_pressed_no_signal(value)
	else:
		(widget as Range).set_value_no_signal(value)


func _connect_widget(key: StringName) -> void:
	var widget := _widgets[key]
	if widget is OptionButton:
		(widget as OptionButton).item_selected.connect(_on_item_selected.bind(key))
	elif widget is BaseButton:
		(widget as BaseButton).toggled.connect(_on_toggled.bind(key))
	else:
		(widget as Range).value_changed.connect(_on_range_changed.bind(key))


## The widget of [param key] under [param options] when it exists, has the GUIDE type and
## matches the [Settings] range or item count; otherwise null after one error naming it.
func _checked_widget(options: Control, key: StringName) -> Control:
	var path := WIDGET_PATHS[key]
	var node := options.get_node_or_null(path)
	var problem := ""
	match key:
		Settings.WINDOW_MODE, Settings.RESOLUTION, Settings.INPUT_DEVICE:
			var expected_items: int = {
				Settings.WINDOW_MODE: Settings.WindowMode.size(),
				Settings.RESOLUTION: Settings.RESOLUTIONS.size(),
				Settings.INPUT_DEVICE: Settings.InputDevice.size(),
			}[key]
			if not node is OptionButton:
				problem = "is missing or not an OptionButton"
			elif (node as OptionButton).item_count != expected_items:
				problem = "has %d items, not %d" % [(node as OptionButton).item_count, expected_items]
		Settings.INVERT_VERTICAL:
			if not node is BaseButton:
				problem = "is missing or not a toggle button"
		_:
			var low := Settings.SENSITIVITY_MIN if key == Settings.CAMERA_SENSITIVITY else float(Settings.VOLUME_MIN)
			var high := Settings.SENSITIVITY_MAX if key == Settings.CAMERA_SENSITIVITY else float(Settings.VOLUME_MAX)
			if not node is Range:
				problem = "is missing or not a slider"
			elif not is_equal_approx((node as Range).min_value, low) or not is_equal_approx((node as Range).max_value, high):
				problem = "ranges %s to %s, not %s to %s" % [(node as Range).min_value, (node as Range).max_value, low, high]
	if problem.is_empty():
		return node as Control
	push_error("%s: Options widget %s/%s %s; '%s' is not bound" % [get_path(), options.get_path(), path, problem, key])
	return null


## Sets the bus of the volume [param key]: muted at 0, otherwise unmuted at
## [method Settings.volume_db].
func _apply_bus(key: StringName) -> void:
	var bus_name := BUS_BY_KEY[key]
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		if not _missing_buses.has(bus_name):
			_missing_buses[bus_name] = true
			push_error("%s: no audio bus '%s'; '%s' is stored but not applied" % [get_path(), bus_name, key])
		return
	var percent: int = _settings.get_value(key)
	var muted := Settings.is_muted(percent)
	AudioServer.set_bus_mute(bus, muted)
	if not muted:
		AudioServer.set_bus_volume_db(bus, Settings.volume_db(percent))


## Applies the window mode and, in Janela, the resolution to the main window. Fullscreen
## keeps the resolution for the return to Janela: the stretch mode scales the 1280 × 720
## layout to the screen. Nothing here touches the content scale or stretch settings.
func _apply_display() -> void:
	var window := get_tree().root
	if _settings.get_window_mode() == Settings.WindowMode.FULLSCREEN:
		window.mode = Window.MODE_FULLSCREEN
		display_applied.emit(Settings.WindowMode.FULLSCREEN, Vector2i.ZERO)
		return
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen).size
	var size := window_size_for(_settings.get_resolution(), usable)
	window.mode = Window.MODE_WINDOWED
	window.size = size
	window.move_to_center()
	display_applied.emit(Settings.WindowMode.WINDOWED, size)
