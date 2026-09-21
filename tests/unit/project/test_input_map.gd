extends TestCase
## Checks the `[input]` section of `project.godot` against CONVENTIONS "Input actions"
## and PLANEJAMENTO Section 8: sixteen gameplay actions with deadzone 0.2, exactly one
## keyboard and one joypad binding each, no mouse bindings.


const DEADZONE := 0.2

## Action -> physical keycode of its keyboard binding.
const KEYBOARD: Dictionary = {
	&"move_forward": KEY_W,
	&"move_back": KEY_S,
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"ascend": KEY_SPACE,
	&"descend": KEY_CTRL,
	&"camera_left": KEY_LEFT,
	&"camera_right": KEY_RIGHT,
	&"camera_up": KEY_UP,
	&"camera_down": KEY_DOWN,
	&"fire": KEY_J,
	&"focus": KEY_SHIFT,
	&"lock_target": KEY_K,
	&"next_target": KEY_TAB,
	&"bomb": KEY_L,
	&"pause": KEY_ESCAPE,
}

## Actions bound to the left-hand modifier key only.
const LEFT_LOCATION: Array[StringName] = [&"descend", &"focus"]

## Action -> joypad button index.
const JOYPAD_BUTTONS: Dictionary = {
	&"ascend": JOY_BUTTON_RIGHT_SHOULDER,
	&"descend": JOY_BUTTON_LEFT_SHOULDER,
	&"lock_target": JOY_BUTTON_Y,
	&"next_target": JOY_BUTTON_X,
	&"bomb": JOY_BUTTON_B,
	&"pause": JOY_BUTTON_START,
}

## Action -> [axis, direction] of its joypad motion binding.
const JOYPAD_AXES: Dictionary = {
	&"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"camera_left": [JOY_AXIS_RIGHT_X, -1.0],
	&"camera_right": [JOY_AXIS_RIGHT_X, 1.0],
	&"camera_up": [JOY_AXIS_RIGHT_Y, -1.0],
	&"camera_down": [JOY_AXIS_RIGHT_Y, 1.0],
	&"fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	&"focus": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}


func test_every_action_exists_with_deadzone() -> void:
	for action: StringName in KEYBOARD:
		if not assert_true(InputMap.has_action(action), "action %s is missing" % action):
			continue
		assert_almost_eq(InputMap.action_get_deadzone(action), DEADZONE, 0.0001, "%s deadzone" % action)


func test_every_action_has_one_keyboard_and_one_joypad_event() -> void:
	for action: StringName in KEYBOARD:
		if not InputMap.has_action(action):
			fail("action %s is missing" % action)
			continue
		var keys := 0
		var joypad := 0
		var mouse := 0
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys += 1
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				joypad += 1
			elif event is InputEventMouse:
				mouse += 1
		assert_eq(keys, 1, "%s keyboard events" % action)
		assert_eq(joypad, 1, "%s joypad events" % action)
		assert_eq(mouse, 0, "%s must have no mouse binding" % action)


func test_keyboard_bindings_match_the_table() -> void:
	for action: StringName in KEYBOARD:
		var key: Key = KEYBOARD[action]
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = true
		if action in LEFT_LOCATION:
			event.location = KEY_LOCATION_LEFT
		assert_true(event.is_action_pressed(action), "%s should press %s" % [OS.get_keycode_string(key), action])


func test_joypad_buttons_match_the_table() -> void:
	for action: StringName in JOYPAD_BUTTONS:
		var button: JoyButton = JOYPAD_BUTTONS[action]
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = true
		assert_true(event.is_action_pressed(action), "joypad button %d should press %s" % [button, action])


func test_joypad_axes_match_the_table() -> void:
	for action: StringName in JOYPAD_AXES:
		var binding: Array = JOYPAD_AXES[action]
		var axis: JoyAxis = binding[0]
		var direction: float = binding[1]
		var event := InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = direction
		assert_true(event.is_action_pressed(action), "joypad axis %d towards %.0f should press %s" % [axis, direction, action])
		event.axis_value = -direction
		assert_false(event.is_action_pressed(action), "the opposite direction of axis %d must not press %s" % [axis, action])
