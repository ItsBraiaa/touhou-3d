class_name InputDeviceState
extends RefCounted
## Node-free Rules Core for the Options input-device preference (PLANEJAMENTO Section 7):
## which prompts the menus show, and whether unplugging a controller pauses.
##
## The mode is a prompt preference and a disconnect rule only: it never filters input,
## so a wrong choice cannot lock anyone out. [constant Settings.InputDevice.AUTOMATIC]
## follows the last device used, [constant Settings.InputDevice.KEYBOARD] always shows the
## keyboard's prompts, and [constant Settings.InputDevice.GAMEPAD] shows the gamepad's
## while a pad is connected. [Interface] feeds it every input event and joypad
## connection change, and pushes [signal prompts_changed] to the menus.


## The prompts to show changed: the keyboard's when [param keyboard], else the gamepad's.
## Emitted only on a change.
signal prompts_changed(keyboard: bool)

## A stick has to pass this far before it counts as gamepad use, so drift near the center
## does not switch the prompts. Godot's default for the `ui_*` actions.
const JOYPAD_AXIS_THRESHOLD := 0.5

var _mode: Settings.InputDevice = Settings.InputDevice.AUTOMATIC
var _last_was_gamepad: bool = false
## Ids of the pads known to be connected, from connection changes and from their events.
var _pads: Dictionary[int, bool] = {}
var _keyboard_prompts: bool = true


## Sets the preference from Options. The last device used is kept.
func set_mode(mode: Settings.InputDevice) -> void:
	_mode = mode
	_refresh()


## The current preference.
func get_mode() -> Settings.InputDevice:
	return _mode


## Notes the device behind [param event]: a key makes the keyboard the last device; a
## joypad button, or a stick at or past [constant JOYPAD_AXIS_THRESHOLD], makes the
## gamepad the last device and marks its pad connected. Anything else (the mouse, an
## [InputEventAction] such as an injected `pause`, stick drift) is ignored.
func note_event(event: InputEvent) -> void:
	if event is InputEventKey:
		_last_was_gamepad = false
	elif event is InputEventJoypadButton or (
			event is InputEventJoypadMotion
			and absf((event as InputEventJoypadMotion).axis_value) >= JOYPAD_AXIS_THRESHOLD):
		_last_was_gamepad = true
		_pads[event.device] = true
	else:
		return
	_refresh()


## Notes pad [param device] connecting or leaving. When the last pad leaves, the keyboard
## becomes the last device, so its prompts return.
func note_joypad(device: int, connected: bool) -> void:
	if connected:
		_pads[device] = true
	else:
		_pads.erase(device)
		if _pads.is_empty():
			_last_was_gamepad = false
	_refresh()


## Whether the menus show the keyboard's prompts: always in KEYBOARD, while no pad is
## connected in GAMEPAD, and while the last device is the keyboard in AUTOMATIC.
func shows_keyboard_prompts() -> bool:
	match _mode:
		Settings.InputDevice.KEYBOARD:
			return true
		Settings.InputDevice.GAMEPAD:
			return _pads.is_empty()
		_:
			return not _last_was_gamepad


## Whether a controller leaving pauses the game: in every mode but KEYBOARD, where nobody
## is playing on the pad (Claude's proposal).
func pauses_on_disconnect() -> bool:
	return _mode != Settings.InputDevice.KEYBOARD


func _refresh() -> void:
	var keyboard := shows_keyboard_prompts()
	if keyboard != _keyboard_prompts:
		_keyboard_prompts = keyboard
		prompts_changed.emit(keyboard)
