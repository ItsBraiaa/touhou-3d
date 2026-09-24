class_name Settings
extends RefCounted
## Node-free Rules Core for the eight Options values in GUIDE Section 14.
## Values are sanitised on every write and persisted through an injected ConfigFile
## path. This core never touches a bus, window or Node; F3-02 applies its values.


## A stored value changed to [param value].
signal changed(key: StringName, value: Variant)

## Window mode, matching the Options widget item ids.
enum WindowMode { WINDOWED, FULLSCREEN }

## Input-device preference, matching the Options widget item ids.
enum InputDevice { AUTOMATIC, KEYBOARD, GAMEPAD }

const DEFAULT_PATH := "user://settings.cfg"
const MASTER_VOLUME := &"master_volume"
const MUSIC_VOLUME := &"music_volume"
const SFX_VOLUME := &"sfx_volume"
const WINDOW_MODE := &"window_mode"
const RESOLUTION := &"resolution"
const INPUT_DEVICE := &"input_device"
const CAMERA_SENSITIVITY := &"camera_sensitivity"
const INVERT_VERTICAL := &"invert_vertical"
const KEYS: Array[StringName] = [
	MASTER_VOLUME, MUSIC_VOLUME, SFX_VOLUME, WINDOW_MODE,
	RESOLUTION, INPUT_DEVICE, CAMERA_SENSITIVITY, INVERT_VERTICAL,
]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const VOLUME_MIN := 0
const VOLUME_MAX := 100
const SENSITIVITY_MIN := 0.2
const SENSITIVITY_MAX := 2.0
const SENSITIVITY_STEP := 0.05
const DEFAULTS: Dictionary = {
	MASTER_VOLUME: 80,
	MUSIC_VOLUME: 65,
	SFX_VOLUME: 80,
	WINDOW_MODE: WindowMode.WINDOWED,
	RESOLUTION: Vector2i(1280, 720),
	INPUT_DEVICE: InputDevice.AUTOMATIC,
	CAMERA_SENSITIVITY: 1.0,
	INVERT_VERTICAL: false,
}

const _SECTION_AUDIO := "audio"
const _SECTION_DISPLAY := "display"
const _SECTION_CONTROLS := "controls"
const _WINDOW_MODES: Array = [WindowMode.WINDOWED, WindowMode.FULLSCREEN]
const _INPUT_DEVICES: Array = [InputDevice.AUTOMATIC, InputDevice.KEYBOARD, InputDevice.GAMEPAD]

var _path: String = DEFAULT_PATH
var _values: Dictionary = {}


## Starts with [constant DEFAULTS] and does no file I/O.
func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	_values = DEFAULTS.duplicate(true)


## The ConfigFile path injected into this core.
func get_file_path() -> String:
	return _path


## Returns a stored value, or reports an unknown key and returns null.
func get_value(key: StringName) -> Variant:
	if not _values.has(key):
		push_error("Settings: unknown key '%s'" % key)
		return null
	return _values[key]


## Sanitises and stores a value without saving. Returns true only when storage changed.
func set_value(key: StringName, value: Variant) -> bool:
	if not _values.has(key):
		push_error("Settings: unknown key '%s'" % key)
		return false
	return _store(key, _sanitise(key, value))


## The Master volume percentage.
func get_master_volume() -> int:
	return _values[MASTER_VOLUME]


## The Music volume percentage.
func get_music_volume() -> int:
	return _values[MUSIC_VOLUME]


## The SFX volume percentage.
func get_sfx_volume() -> int:
	return _values[SFX_VOLUME]


## The validated window mode.
func get_window_mode() -> WindowMode:
	return _values[WINDOW_MODE]


## The validated resolution.
func get_resolution() -> Vector2i:
	return _values[RESOLUTION]


## The validated input-device preference.
func get_input_device() -> InputDevice:
	return _values[INPUT_DEVICE]


## Camera sensitivity, from [constant SENSITIVITY_MIN] to [constant SENSITIVITY_MAX].
func get_camera_sensitivity() -> float:
	return _values[CAMERA_SENSITIVITY]


## Whether vertical camera input is inverted.
func get_invert_vertical() -> bool:
	return _values[INVERT_VERTICAL]


## Restores every field to its authored default without saving.
func restore_defaults() -> void:
	for key: StringName in KEYS:
		_store(key, DEFAULTS[key])


## Returns a deep copy of all eight stored values.
func capture() -> Dictionary:
	return _values.duplicate(true)


## Sanitises every known field from [param data], using defaults for missing fields.
## Unknown keys are ignored. Returns one diagnostic for each missing or adjusted field.
func restore(data: Dictionary) -> PackedStringArray:
	var messages: PackedStringArray = PackedStringArray()
	for key: StringName in KEYS:
		if not data.has(key):
			_store(key, DEFAULTS[key])
			messages.append("Settings: '%s' is missing; used default %s" % [key, DEFAULTS[key]])
			continue
		var found: Variant = data[key]
		var used: Variant = _sanitise(key, found)
		_store(key, used)
		if used != found:
			messages.append("Settings: '%s' used %s (found %s)" % [key, used, found])
	return messages


## Loads the injected ConfigFile. Missing files use defaults silently; parse errors
## use defaults and leave the corrupt file untouched.
func load_file() -> PackedStringArray:
	if not FileAccess.file_exists(_path):
		restore_defaults()
		return PackedStringArray()
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(_path)
	if error != OK:
		restore_defaults()
		var messages: PackedStringArray = PackedStringArray()
		messages.append("Settings: '%s' could not be read (%s); defaults are in use" % [
			_path, error_string(error),
		])
		return messages
	var data: Dictionary = {}
	for key: StringName in KEYS:
		var section: String = _section_of(key)
		if config.has_section_key(section, key):
			data[key] = config.get_value(section, key)
	return restore(data)


## Writes all eight fields to a fresh ConfigFile and returns its Error result.
func save_file() -> Error:
	var config: ConfigFile = ConfigFile.new()
	for key: StringName in KEYS:
		config.set_value(_section_of(key), key, _values[key])
	return config.save(_path)


## Converts a volume percentage to the Godot linear-amplitude decibel value.
static func volume_db(percent: int) -> float:
	return linear_to_db(percent / 100.0)


## Whether a volume percentage represents mute.
static func is_muted(percent: int) -> bool:
	return percent <= 0


func _store(key: StringName, value: Variant) -> bool:
	if value == _values[key]:
		return false
	_values[key] = value
	changed.emit(key, value)
	return true


static func _sanitise(key: StringName, value: Variant) -> Variant:
	match key:
		MASTER_VOLUME, MUSIC_VOLUME, SFX_VOLUME:
			return _sanitise_volume(key, value)
		WINDOW_MODE:
			return _sanitise_option(value, _WINDOW_MODES, DEFAULTS[WINDOW_MODE])
		RESOLUTION:
			return _sanitise_resolution(value)
		INPUT_DEVICE:
			return _sanitise_option(value, _INPUT_DEVICES, DEFAULTS[INPUT_DEVICE])
		CAMERA_SENSITIVITY:
			return _sanitise_sensitivity(value)
		_:
			return _sanitise_invert_vertical(value)


static func _sanitise_volume(key: StringName, value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return clampi(value, VOLUME_MIN, VOLUME_MAX)
	if typeof(value) == TYPE_FLOAT and is_finite(value):
		return clampi(roundi(value), VOLUME_MIN, VOLUME_MAX)
	return DEFAULTS[key]


static func _sanitise_option(value: Variant, valid_values: Array, default_value: Variant) -> Variant:
	if typeof(value) == TYPE_INT and valid_values.has(value):
		return value
	return default_value


static func _sanitise_resolution(value: Variant) -> Variant:
	if typeof(value) == TYPE_VECTOR2I and RESOLUTIONS.has(value):
		return value
	return DEFAULTS[RESOLUTION]


static func _sanitise_sensitivity(value: Variant) -> Variant:
	if (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(value):
		var clamped: float = clampf(float(value), SENSITIVITY_MIN, SENSITIVITY_MAX)
		return snappedf(clamped, SENSITIVITY_STEP)
	return DEFAULTS[CAMERA_SENSITIVITY]


static func _sanitise_invert_vertical(value: Variant) -> Variant:
	if typeof(value) == TYPE_BOOL:
		return value
	return DEFAULTS[INVERT_VERTICAL]


static func _section_of(key: StringName) -> String:
	match key:
		MASTER_VOLUME, MUSIC_VOLUME, SFX_VOLUME:
			return _SECTION_AUDIO
		WINDOW_MODE, RESOLUTION:
			return _SECTION_DISPLAY
		_:
			return _SECTION_CONTROLS
