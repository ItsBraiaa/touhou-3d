class_name InputBindingAdapter
extends RefCounted
## Adapter between [InputBindings] descriptors and Godot's [InputMap] (F16-02), owned once
## by [Interface]. It is the only writer of the catalog actions' events, and it never
## touches an action outside [constant InputBindings.CATALOG] (`ui_select`, the text
## editing `ui_*` actions and the rest keep their engine events).
##
## Both profiles are live at once: each catalog action's events are its keyboard-and-mouse
## slots, its gamepad slots and its fixed bindings, so any device drives the game. Every
## event is installed for device -1 (all devices): a controller that reconnects with a
## new index keeps its bindings, and no device index is ever saved. A joypad axis keeps
## its analog strength through the action's deadzone, which is never changed here.


## Profile id -> the profile installed for it, normalized. It starts at the defaults,
## which equal `project.godot` ([method find_default_drift]), so applying one profile
## keeps the other one's events.
var _installed: Dictionary = InputBindings.default_profiles()


## Installs [param data] for [param profile] and keeps the other profile's events.
## [param data] is one profile as in [method InputBindings.capture] (action -> slots).
## Returns the reasons it was refused ([method InputBindings.check_profile_data]), in
## which case [InputMap] is unchanged.
func apply_profile(profile: StringName, data: Dictionary) -> PackedStringArray:
	var errors := InputBindings.check_profile_data(profile, data)
	if errors.is_empty():
		_installed[profile] = InputBindings.normalize_profile(data)
		_install()
	return errors


## Installs both profiles of [param bindings] at once, or neither: returns the reasons
## one was refused, in which case [InputMap] is unchanged.
func apply_bindings(bindings: InputBindings) -> PackedStringArray:
	var profiles := bindings.capture()
	var errors := PackedStringArray()
	for profile: StringName in InputBindings.PROFILES:
		errors.append_array(InputBindings.check_profile_data(profile, profiles[profile]))
	if errors.is_empty():
		for profile: StringName in InputBindings.PROFILES:
			_installed[profile] = InputBindings.normalize_profile(profiles[profile])
		_install()
	return errors


## Puts every catalog action back at its default events, which are `project.godot`'s.
func apply_defaults() -> void:
	_installed = InputBindings.default_profiles()
	_install()


## [param event] as a normalized [InputBindings] descriptor, or an empty Dictionary for an
## event no binding can hold (mouse motion, an [InputEventAction], a centred axis, a
## negative trigger). A key is physical (its position) or a keycode of the active layout
## as [param action] takes it ([method InputBindings.uses_physical_keys]); with no action,
## as the event itself is written. A modifier key's own bit is dropped, so Left Shift
## stays a standalone key, and a chord such as Shift+Tab keeps its mask. An axis keeps
## only its direction. The event's device is ignored. Repeats and deliberate-press rules
## are the caller's (F16-03's capture).
func describe_event(event: InputEvent, action: StringName = &"") -> Dictionary:
	var binding: Dictionary = {}
	if event is InputEventKey:
		var key := event as InputEventKey
		var physical := key.physical_keycode != KEY_NONE
		if InputBindings.CATALOG.has(action):
			physical = InputBindings.uses_physical_keys(action)
		var code: int = key.physical_keycode if physical else key.keycode
		if code == KEY_NONE:
			# A synthetic event may carry only one of the two codes: use the one it has.
			physical = not physical
			code = key.physical_keycode if physical else key.keycode
		var location: int = key.location if physical else KEY_LOCATION_UNSPECIFIED
		binding = InputBindings.key_binding(code, physical, _modifiers(key), location)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		binding = InputBindings.mouse_button_binding(button.button_index, _modifiers(button))
	elif event is InputEventJoypadButton:
		binding = InputBindings.joy_button_binding((event as InputEventJoypadButton).button_index)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if not is_zero_approx(motion.axis_value):
			binding = InputBindings.joy_axis_binding(motion.axis, 1 if motion.axis_value > 0.0 else -1)
	return InputBindings.parse_binding(binding)


## One message per catalog action whose [method InputBindings.default_profiles] events
## (slots and fixed bindings of both profiles) differ from `project.godot`'s `[input]`,
## or from Godot's built-in events for a `ui_*` action it does not override. It reads
## [ProjectSettings], which a runtime remap never changes. Empty when they agree.
func find_default_drift() -> PackedStringArray:
	var messages := PackedStringArray()
	var defaults := InputBindings.default_profiles()
	for action: StringName in InputBindings.CATALOG:
		var setting: Variant = ProjectSettings.get_setting("input/%s" % action)
		if typeof(setting) != TYPE_DICTIONARY or typeof((setting as Dictionary).get("events")) != TYPE_ARRAY:
			messages.append("InputBindingAdapter: the project has no '%s' action" % action)
			continue
		var found: Array[Dictionary] = []
		for event: Variant in setting["events"]:
			if event is InputEvent:
				found.append(describe_event(event))
		var expected := _events_of(defaults, action)
		if not _same_bindings(found, expected):
			messages.append("InputBindingAdapter: the '%s' defaults %s differ from the project's %s" % [action, expected, found])
	return messages


## Rewrites the events of every catalog action whose bindings changed, or that has an
## event tied to one device. Such an action is released, because a key held through the
## change would stay pressed: its release no longer matches the action.
func _install() -> void:
	for action: StringName in InputBindings.CATALOG:
		var wanted := _events_of(_installed, action)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			var current: Array[Dictionary] = []
			var every_device := true
			for event: InputEvent in InputMap.action_get_events(action):
				current.append(describe_event(event))
				every_device = every_device and event.device == -1
			if every_device and _same_bindings(current, wanted):
				continue
		InputMap.action_erase_events(action)
		for binding: Dictionary in wanted:
			InputMap.action_add_event(action, _to_event(binding))
		Input.action_release(action)


## Every binding [param profiles] gives [param action]: both profiles' bound slots and
## fixed bindings.
static func _events_of(profiles: Dictionary, action: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile: StringName in InputBindings.PROFILES:
		for binding: Dictionary in profiles[profile][action]:
			if not binding.is_empty():
				result.append(binding)
		result.append_array(InputBindings.get_fixed_bindings(profile, action))
	return result


## Whether [param a] and [param b] hold the same descriptors, in any order.
static func _same_bindings(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	var unmatched := b.duplicate()
	for binding: Dictionary in a:
		var index := unmatched.find(binding)
		if index == -1:
			return false
		unmatched.remove_at(index)
	return true


## The [InputMap] event for a normalized descriptor, for every device (-1).
static func _to_event(binding: Dictionary) -> InputEvent:
	var kind: String = binding["kind"]
	var code: int = binding["code"]
	var modifiers: int = binding["modifiers"]
	var event: InputEvent
	if kind == InputBindings.KIND_KEY:
		var key := InputEventKey.new()
		if binding["physical"]:
			key.physical_keycode = code as Key
		else:
			key.keycode = code as Key
		key.location = int(binding["location"]) as KeyLocation
		_set_modifiers(key, modifiers)
		event = key
	elif kind == InputBindings.KIND_MOUSE_BUTTON:
		var button := InputEventMouseButton.new()
		button.button_index = code as MouseButton
		_set_modifiers(button, modifiers)
		event = button
	elif kind == InputBindings.KIND_JOY_BUTTON:
		var pad_button := InputEventJoypadButton.new()
		pad_button.button_index = code as JoyButton
		event = pad_button
	else:
		var motion := InputEventJoypadMotion.new()
		motion.axis = code as JoyAxis
		motion.axis_value = float(binding["axis_sign"])
		event = motion
	event.device = -1
	return event


## The Shift, Ctrl, Alt and Meta bits held in [param event].
static func _modifiers(event: InputEventWithModifiers) -> int:
	var mask := 0
	if event.shift_pressed:
		mask |= KEY_MASK_SHIFT
	if event.ctrl_pressed:
		mask |= KEY_MASK_CTRL
	if event.alt_pressed:
		mask |= KEY_MASK_ALT
	if event.meta_pressed:
		mask |= KEY_MASK_META
	return mask


static func _set_modifiers(event: InputEventWithModifiers, modifiers: int) -> void:
	event.shift_pressed = (modifiers & KEY_MASK_SHIFT) != 0
	event.ctrl_pressed = (modifiers & KEY_MASK_CTRL) != 0
	event.alt_pressed = (modifiers & KEY_MASK_ALT) != 0
	event.meta_pressed = (modifiers & KEY_MASK_META) != 0
