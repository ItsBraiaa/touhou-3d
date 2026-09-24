class_name Settings
extends RefCounted
## Node-free Rules Core for the Options values: the eight of GUIDE Section 14, the five F16
## camera and prompt values, and the two [InputBindings] profiles (F16-02). Values are
## sanitised on every write and persisted through an injected ConfigFile path. This core
## never touches a bus, window, Node or the [InputMap]; F3-02, F3-03, F3-04 and
## [InputBindingAdapter] apply its values.
##
## Loading never writes, so an old or corrupt file stays as it is until the next save (the
## file is shared with every boot of the game). Saving is atomic: a temporary file is
## written and read back, the old file is moved aside, and the temporary one takes its
## place, so a failed save leaves the old file. A binding change that waits for the
## player's confirmation is saved with the confirmed profiles beside it, so a crash
## before the confirmation comes back to them at the next boot.


## A stored value changed to [param value]. For [constant BINDING_PROFILES] the value is
## the new [method InputBindings.capture].
signal changed(key: StringName, value: Variant)

## Window mode, matching the Options widget item ids.
enum WindowMode { WINDOWED, FULLSCREEN }

## Input-device preference, matching the Options widget item ids.
enum InputDevice { AUTOMATIC, KEYBOARD, GAMEPAD }

const DEFAULT_PATH := "user://settings.cfg"
## The `[controls]` schema version this core writes. A file without one predates F16-02.
const CONTROLS_VERSION := 1
const MASTER_VOLUME := &"master_volume"
const MUSIC_VOLUME := &"music_volume"
const SFX_VOLUME := &"sfx_volume"
const WINDOW_MODE := &"window_mode"
const RESOLUTION := &"resolution"
const INPUT_DEVICE := &"input_device"
const CAMERA_SENSITIVITY := &"camera_sensitivity"
const INVERT_VERTICAL := &"invert_vertical"
const CAMERA_INPUT_MODE := &"camera_input_mode"
const MOUSE_SENSITIVITY := &"mouse_sensitivity"
const MOUSE_INVERT_VERTICAL := &"mouse_invert_vertical"
const CAMERA_DEADZONE := &"camera_deadzone"
const CONTROLLER_GLYPH_FAMILY := &"controller_glyph_family"
## The binding profiles' `[controls]` key, and the [signal changed] key when they change.
## They are read through [method get_input_bindings], not [method get_value].
const BINDING_PROFILES := &"binding_profiles"
## The eight Options screen values of GUIDE Section 14, in widget order.
const KEYS: Array[StringName] = [
	MASTER_VOLUME, MUSIC_VOLUME, SFX_VOLUME, WINDOW_MODE,
	RESOLUTION, INPUT_DEVICE, CAMERA_SENSITIVITY, INVERT_VERTICAL,
]
## The F16 values, stored and saved like [constant KEYS] (F16-03 binds their widgets on
## the Controls screen's Câmera tab).
const CONTROL_KEYS: Array[StringName] = [
	CAMERA_INPUT_MODE, MOUSE_SENSITIVITY, MOUSE_INVERT_VERTICAL, CAMERA_DEADZONE, CONTROLLER_GLYPH_FAMILY,
]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const VOLUME_MIN := 0
const VOLUME_MAX := 100
const SENSITIVITY_MIN := 0.2
const SENSITIVITY_MAX := 2.0
const SENSITIVITY_STEP := 0.05
## Teclas: the keyboard orbits the camera, as before F16. The right stick orbits in both.
const CAMERA_MODE_KEYS := &"keys"
## Mouse: relative mouse motion orbits the camera during gameplay (F16-04).
const CAMERA_MODE_MOUSE := &"mouse"
const CAMERA_INPUT_MODES: Array[StringName] = [CAMERA_MODE_KEYS, CAMERA_MODE_MOUSE]
## Mouse orbit, in degrees per pixel of relative motion.
const MOUSE_SENSITIVITY_MIN := 0.02
const MOUSE_SENSITIVITY_MAX := 0.5
## Gamepad camera stick deadzone.
const DEADZONE_MIN := 0.05
const DEADZONE_MAX := 0.5
## Ícones do controle: follow the detected pad, or force a family.
const GLYPHS_AUTO := &"auto"
const GLYPHS_XBOX := &"xbox"
const GLYPHS_PLAYSTATION := &"playstation"
const GLYPH_FAMILIES: Array[StringName] = [GLYPHS_AUTO, GLYPHS_XBOX, GLYPHS_PLAYSTATION]
const DEFAULTS: Dictionary = {
	MASTER_VOLUME: 80,
	MUSIC_VOLUME: 65,
	SFX_VOLUME: 80,
	WINDOW_MODE: WindowMode.WINDOWED,
	RESOLUTION: Vector2i(1280, 720),
	INPUT_DEVICE: InputDevice.AUTOMATIC,
	CAMERA_SENSITIVITY: 1.0,
	INVERT_VERTICAL: false,
	CAMERA_INPUT_MODE: CAMERA_MODE_KEYS,
	MOUSE_SENSITIVITY: 0.12,
	MOUSE_INVERT_VERTICAL: false,
	CAMERA_DEADZONE: 0.2,
	CONTROLLER_GLYPH_FAMILY: GLYPHS_AUTO,
}

const _SECTION_AUDIO := "audio"
const _SECTION_DISPLAY := "display"
const _SECTION_CONTROLS := "controls"
const _VERSION_KEY := "controls_version"
## Present, true, only while a binding change waits for its confirmation.
const _PENDING_KEY := "bindings_pending_confirmation"
## The confirmed profiles to return to, saved beside [constant _PENDING_KEY].
const _CONFIRMED_KEY := "confirmed_binding_profiles"
const _TEMP_SUFFIX := ".tmp"
const _BACKUP_SUFFIX := ".bak"
const _WINDOW_MODES: Array = [WindowMode.WINDOWED, WindowMode.FULLSCREEN]
const _INPUT_DEVICES: Array = [InputDevice.AUTOMATIC, InputDevice.KEYBOARD, InputDevice.GAMEPAD]
## [constant KEYS] then [constant CONTROL_KEYS]: every value in [constant DEFAULTS].
const _VALUE_KEYS: Array[StringName] = [
	MASTER_VOLUME, MUSIC_VOLUME, SFX_VOLUME, WINDOW_MODE,
	RESOLUTION, INPUT_DEVICE, CAMERA_SENSITIVITY, INVERT_VERTICAL,
	CAMERA_INPUT_MODE, MOUSE_SENSITIVITY, MOUSE_INVERT_VERTICAL, CAMERA_DEADZONE, CONTROLLER_GLYPH_FAMILY,
]

var _path: String = DEFAULT_PATH
var _values: Dictionary = {}
var _bindings := InputBindings.new()
## True from [method apply_input_bindings] with a confirmation until it is confirmed or
## reverted.
var _bindings_pending: bool = false
## The confirmed profiles to return to while [member _bindings_pending].
var _confirmed_profiles: Dictionary = {}


## Starts with [constant DEFAULTS] and the default profiles, and does no file I/O.
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


## Keyboard and stick orbit sensitivity, from [constant SENSITIVITY_MIN] to
## [constant SENSITIVITY_MAX].
func get_camera_sensitivity() -> float:
	return _values[CAMERA_SENSITIVITY]


## Whether vertical keyboard and stick orbit is inverted.
func get_invert_vertical() -> bool:
	return _values[INVERT_VERTICAL]


## [constant CAMERA_MODE_KEYS] or [constant CAMERA_MODE_MOUSE].
func get_camera_input_mode() -> StringName:
	return _values[CAMERA_INPUT_MODE]


## Mouse orbit in degrees per pixel, from [constant MOUSE_SENSITIVITY_MIN] to
## [constant MOUSE_SENSITIVITY_MAX].
func get_mouse_sensitivity() -> float:
	return _values[MOUSE_SENSITIVITY]


## Whether vertical mouse orbit is inverted, independently of [method get_invert_vertical].
func get_mouse_invert_vertical() -> bool:
	return _values[MOUSE_INVERT_VERTICAL]


## The gamepad camera deadzone, from [constant DEADZONE_MIN] to [constant DEADZONE_MAX].
func get_camera_deadzone() -> float:
	return _values[CAMERA_DEADZONE]


## [constant GLYPHS_AUTO], [constant GLYPHS_XBOX] or [constant GLYPHS_PLAYSTATION].
func get_controller_glyph_family() -> StringName:
	return _values[CONTROLLER_GLYPH_FAMILY]


## The live binding profiles. Read them freely, but edit a copy (`InputBindings.new()`,
## then [method InputBindings.restore] of this one's [method InputBindings.capture]) and
## make it live with [method apply_input_bindings], which saves before anything changes.
func get_input_bindings() -> InputBindings:
	return _bindings


## Whether an applied binding change waits for [method confirm_input_bindings] or
## [method revert_input_bindings].
func is_input_bindings_pending() -> bool:
	return _bindings_pending


## Restores every value and both binding profiles to their defaults without saving
## (Options' global Defaults). A pending binding confirmation is left as it is.
func restore_defaults() -> void:
	for key: StringName in _VALUE_KEYS:
		_store(key, DEFAULTS[key])
	_set_bindings(InputBindings.default_profiles())


## Returns a deep copy of every stored value, plus [constant BINDING_PROFILES].
func capture() -> Dictionary:
	var data: Dictionary = _values.duplicate(true)
	data[BINDING_PROFILES] = _bindings.capture()
	return data


## Sanitises every known field from [param data], using defaults for missing fields, and
## restores the profiles from its [constant BINDING_PROFILES]. Unknown keys are ignored.
## Returns one diagnostic for each missing or adjusted field.
func restore(data: Dictionary) -> PackedStringArray:
	var messages := _restore_values(data, _VALUE_KEYS)
	var profiles: Variant = data.get(BINDING_PROFILES)
	if typeof(profiles) == TYPE_DICTIONARY:
		messages.append_array(_set_bindings(profiles))
	else:
		_set_bindings({})
		messages.append("Settings: '%s' is missing or malformed; the default controls are in use" % BINDING_PROFILES)
	return messages


## Loads the injected ConfigFile. Missing files use defaults silently; parse errors use
## defaults and leave the corrupt file untouched. A file from before F16-02 (no
## `controls_version`) keeps its eight values and gets the new values and profiles at
## their defaults, silently. When a binding change was left unconfirmed, its confirmed
## profiles are the ones in use. Nothing is written.
func load_file() -> PackedStringArray:
	var messages := PackedStringArray()
	_bindings_pending = false
	_confirmed_profiles = {}
	var source := _path
	if not FileAccess.file_exists(source):
		# A save stops between its two renames only by a crash; the backup is complete.
		source = _path + _BACKUP_SUFFIX
		if not FileAccess.file_exists(source):
			restore_defaults()
			return messages
		messages.append("Settings: '%s' is missing; its backup '%s' is in use" % [_path, source])
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(source)
	if error != OK:
		restore_defaults()
		messages.append("Settings: '%s' could not be read (%s); defaults are in use" % [
			source, error_string(error),
		])
		return messages
	var version: Variant = config.get_value(_SECTION_CONTROLS, _VERSION_KEY, 0)
	if typeof(version) != TYPE_INT:
		messages.append("Settings: '%s' is %s, not an integer; read as version %d" % [_VERSION_KEY, version, CONTROLS_VERSION])
		version = CONTROLS_VERSION
	elif version > CONTROLS_VERSION:
		messages.append("Settings: '%s' is %d, newer than %d; only known values are read" % [_VERSION_KEY, version, CONTROLS_VERSION])
	var migrating: bool = version == 0
	var data: Dictionary = {}
	for key: StringName in _VALUE_KEYS:
		var section: String = _section_of(key)
		if config.has_section_key(section, key):
			data[key] = config.get_value(section, key)
	messages.append_array(_restore_values(data, KEYS if migrating else _VALUE_KEYS))
	messages.append_array(_load_bindings(config, migrating))
	return messages


## Writes every value and both profiles through a temporary file (see the class notes)
## and returns its Error result. On failure the old file is kept.
func save_file() -> Error:
	return _write(_bindings.capture(), _bindings_pending, _confirmed_profiles)


## F16-03's Aplicar. Validates both profiles of [param draft], saves them, and only then
## makes them live: [signal changed] with [constant BINDING_PROFILES], which [Interface]
## installs in the [InputMap]. With [param needs_confirmation] (a menu binding changed)
## the file also keeps the confirmed profiles and a pending marker, until
## [method confirm_input_bindings] or [method revert_input_bindings]; a crash before then
## comes back to the confirmed profiles at the next boot. Returns
## [constant ERR_INVALID_DATA] for an invalid draft, or the save's Error; on any failure
## nothing changes, neither the live profiles nor the file.
func apply_input_bindings(draft: InputBindings, needs_confirmation: bool = false) -> Error:
	for profile: StringName in InputBindings.PROFILES:
		if not draft.validate_profile(profile).is_empty():
			return ERR_INVALID_DATA
	var profiles := draft.capture()
	var confirmed: Dictionary = _confirmed_profiles if _bindings_pending else _bindings.capture()
	var error := _write(profiles, needs_confirmation, confirmed)
	if error != OK:
		return error
	_bindings_pending = needs_confirmation
	_confirmed_profiles = confirmed if needs_confirmation else {}
	_set_bindings(profiles)
	return OK


## Manter controles: the pending profiles become the confirmed ones, and the marker is
## saved away. When that save fails the live profiles stay, but the file keeps its marker,
## so the next boot returns to the previous controls; report the Error.
func confirm_input_bindings() -> Error:
	if not _bindings_pending:
		return OK
	_bindings_pending = false
	_confirmed_profiles = {}
	return save_file()


## Reverter, the confirmation timeout, a disconnect or a focus loss: the confirmed
## profiles are live again at once, then saved. When that save fails they stay live, and
## the file's marker brings them back at the next boot too.
func revert_input_bindings() -> Error:
	if not _bindings_pending:
		return OK
	var confirmed := _confirmed_profiles
	_bindings_pending = false
	_confirmed_profiles = {}
	_set_bindings(confirmed)
	return save_file()


## Converts a volume percentage to the Godot linear-amplitude decibel value.
static func volume_db(percent: int) -> float:
	return linear_to_db(percent / 100.0)


## Whether a volume percentage represents mute.
static func is_muted(percent: int) -> bool:
	return percent <= 0


func _store(key: StringName, value: Variant) -> bool:
	if _same(value, _values[key]):
		return false
	_values[key] = value
	changed.emit(key, value)
	return true


## Sanitises each of [constant _VALUE_KEYS] from [param data]. A missing key takes its
## default, with a diagnostic only when it is in [param reported].
func _restore_values(data: Dictionary, reported: Array[StringName]) -> PackedStringArray:
	var messages := PackedStringArray()
	for key: StringName in _VALUE_KEYS:
		if not data.has(key):
			_store(key, DEFAULTS[key])
			if reported.has(key):
				messages.append("Settings: '%s' is missing; used default %s" % [key, DEFAULTS[key]])
			continue
		var found: Variant = data[key]
		var used: Variant = _sanitise(key, found)
		_store(key, used)
		if not _same(used, found):
			messages.append("Settings: '%s' used %s (found %s)" % [key, used, found])
	return messages


## The profiles in [param config]: the defaults for a file from before F16-02, the
## confirmed ones when a change was left pending, otherwise the saved ones.
func _load_bindings(config: ConfigFile, migrating: bool) -> PackedStringArray:
	if migrating:
		return _set_bindings({})
	var messages := PackedStringArray()
	var key: String = BINDING_PROFILES
	var pending: Variant = config.get_value(_SECTION_CONTROLS, _PENDING_KEY, false)
	if typeof(pending) != TYPE_BOOL:
		messages.append("Settings: '%s' is %s, not a bool; ignored" % [_PENDING_KEY, pending])
	elif pending:
		key = _CONFIRMED_KEY
		messages.append("Settings: a controls change was left unconfirmed; the previous controls are in use")
	var profiles: Variant = config.get_value(_SECTION_CONTROLS, key, null)
	if typeof(profiles) != TYPE_DICTIONARY:
		messages.append("Settings: '%s' is missing or malformed; the default controls are in use" % key)
		profiles = {}
	messages.append_array(_set_bindings(profiles))
	return messages


## Restores the live profiles from [param profiles] ([method InputBindings.restore]) and
## emits [signal changed] once when they differ.
func _set_bindings(profiles: Dictionary) -> PackedStringArray:
	var before := _bindings.capture()
	var messages := _bindings.restore(profiles)
	var after := _bindings.capture()
	if after != before:
		changed.emit(BINDING_PROFILES, after)
	return messages


## Writes every value and [param profiles] to a temporary file, with the pending marker
## and [param confirmed] when [param pending], reads it back, then puts it in place.
func _write(profiles: Dictionary, pending: bool, confirmed: Dictionary) -> Error:
	var config: ConfigFile = ConfigFile.new()
	for key: StringName in _VALUE_KEYS:
		config.set_value(_section_of(key), key, _values[key])
	config.set_value(_SECTION_CONTROLS, BINDING_PROFILES, profiles)
	if pending:
		config.set_value(_SECTION_CONTROLS, _PENDING_KEY, true)
		config.set_value(_SECTION_CONTROLS, _CONFIRMED_KEY, confirmed)
	# Written last, so finding it on the read-back shows the whole file reached the disk.
	config.set_value(_SECTION_CONTROLS, _VERSION_KEY, CONTROLS_VERSION)
	var temp := _path + _TEMP_SUFFIX
	var error := config.save(temp)
	if error == OK:
		var check: ConfigFile = ConfigFile.new()
		error = check.load(temp)
		if error == OK and not check.has_section_key(_SECTION_CONTROLS, _VERSION_KEY):
			error = ERR_FILE_CORRUPT
	if error != OK:
		DirAccess.remove_absolute(temp)
		return error
	return _replace_with(temp)


## Moves the old file to the backup, [param temp] to the path, then drops the backup. A
## failure puts the old file back. Two renames, because a rename onto an existing file is
## not atomic on every platform; [method load_file] reads the backup if a crash leaves only
## it.
func _replace_with(temp: String) -> Error:
	var backup := _path + _BACKUP_SUFFIX
	var had_file := FileAccess.file_exists(_path)
	if had_file:
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		var moved := DirAccess.rename_absolute(_path, backup)
		if moved != OK:
			DirAccess.remove_absolute(temp)
			return moved
	var error := DirAccess.rename_absolute(temp, _path)
	if error != OK:
		DirAccess.remove_absolute(temp)
		if had_file:
			DirAccess.rename_absolute(backup, _path)
		return error
	if had_file:
		DirAccess.remove_absolute(backup)
	return OK


## Whether two stored values are equal: the same type, and for floats approximately.
static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if typeof(a) == TYPE_FLOAT:
		return is_equal_approx(a, b)
	return a == b


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
			return _sanitise_range(value, SENSITIVITY_MIN, SENSITIVITY_MAX, SENSITIVITY_STEP, DEFAULTS[key])
		MOUSE_SENSITIVITY:
			return _sanitise_range(value, MOUSE_SENSITIVITY_MIN, MOUSE_SENSITIVITY_MAX, 0.0, DEFAULTS[key])
		CAMERA_DEADZONE:
			return _sanitise_range(value, DEADZONE_MIN, DEADZONE_MAX, 0.0, DEFAULTS[key])
		CAMERA_INPUT_MODE:
			return _sanitise_name(value, CAMERA_INPUT_MODES, DEFAULTS[key])
		CONTROLLER_GLYPH_FAMILY:
			return _sanitise_name(value, GLYPH_FAMILIES, DEFAULTS[key])
		_:
			return _sanitise_bool(key, value)


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


## A finite number clamped to [param low]..[param high], then snapped to [param step]
## when it is positive; anything else is [param default_value].
static func _sanitise_range(value: Variant, low: float, high: float, step: float, default_value: Variant) -> Variant:
	if (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(value):
		var clamped: float = clampf(float(value), low, high)
		return snappedf(clamped, step) if step > 0.0 else clamped
	return default_value


## A String or StringName in [param valid_values], as a StringName; anything else is
## [param default_value].
static func _sanitise_name(value: Variant, valid_values: Array[StringName], default_value: Variant) -> Variant:
	if (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME) and valid_values.has(StringName(value)):
		return StringName(value)
	return default_value


static func _sanitise_bool(key: StringName, value: Variant) -> Variant:
	if typeof(value) == TYPE_BOOL:
		return value
	return DEFAULTS[key]


static func _section_of(key: StringName) -> String:
	match key:
		MASTER_VOLUME, MUSIC_VOLUME, SFX_VOLUME:
			return _SECTION_AUDIO
		WINDOW_MODE, RESOLUTION:
			return _SECTION_DISPLAY
		_:
			return _SECTION_CONTROLS
