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

## The prompt family changed: `&"keyboard_mouse"` while the keyboard's prompts show, else
## `&"xbox"` or `&"playstation"`, from the override or the last pad used (F16-08). Emitted
## only on a change.
signal prompt_family_changed(family: StringName)

## The controller family changed: `&"xbox"` or `&"playstation"`, from the override or the
## last pad used, whichever prompts show (F16-03). Emitted only on a change.
signal controller_family_changed(family: StringName)

## A stick has to pass this far before it counts as gamepad use, so drift near the center
## does not switch the prompts. Godot's default for the `ui_*` actions.
const JOYPAD_AXIS_THRESHOLD := 0.5

## Mouse motion far enough since the last gamepad event to count as keyboard/mouse use, so
## jitter near the center does not switch the prompts (F16-08).
const MOUSE_MOTION_THRESHOLD := 8.0

## The accepted [method set_glyph_override] values; anything else means `&"auto"`.
const GLYPH_OVERRIDES: Array[StringName] = [&"auto", &"xbox", &"playstation"]

## Lowercased [method Input.get_joy_name] fragments that mean a PlayStation-family pad.
const PLAYSTATION_NAME_TOKENS: Array[String] = [
	"playstation", "ps3", "ps4", "ps5", "dualsense", "dualshock", "sony", "wireless controller",
]

var _mode: Settings.InputDevice = Settings.InputDevice.AUTOMATIC
var _last_was_gamepad: bool = false
## Ids of the pads known to be connected, from connection changes and from their events.
var _pads: Dictionary[int, bool] = {}
var _keyboard_prompts: bool = true
## The controller prompt family override from Options: `&"auto"`, `&"xbox"` or `&"playstation"`.
var _glyph_override: StringName = &"auto"
## Device id of the last pad that sent an event; -1 until one does. Memory only, never saved.
var _last_pad_device: int = -1
## Relative mouse motion accumulated since the last gamepad event (F16-08).
var _mouse_motion_accum: float = 0.0
var _prompt_family: StringName = &"keyboard_mouse"
var _controller_family: StringName = &"xbox"


## Sets the preference from Options. The last device used is kept.
func set_mode(mode: Settings.InputDevice) -> void:
	_mode = mode
	_refresh()


## The current preference.
func get_mode() -> Settings.InputDevice:
	return _mode


## Sets the controller prompt family override from Options' "Ícones do controle": `&"auto"`,
## `&"xbox"` or `&"playstation"`. Anything else is treated as `&"auto"`.
func set_glyph_override(family: StringName) -> void:
	_glyph_override = family if family in GLYPH_OVERRIDES else &"auto"
	_refresh()


## The prompt family to show: `&"keyboard_mouse"` while [method shows_keyboard_prompts] is
## true, otherwise [method get_controller_family] (F16-08).
func get_prompt_family() -> StringName:
	if shows_keyboard_prompts():
		return &"keyboard_mouse"
	return get_controller_family()


## The controller glyph family, whichever prompts show, for the Controls screen's Controle
## tab (F16-03): the override when one is set; otherwise, for `&"auto"`, `&"playstation"`
## when the last pad that sent an event reads as one in [method Input.get_joy_name], else
## `&"xbox"`, also before any pad did.
func get_controller_family() -> StringName:
	if _glyph_override != &"auto":
		return _glyph_override
	if _last_pad_device < 0:
		return &"xbox"
	var joy_name := Input.get_joy_name(_last_pad_device).to_lower()
	for token: String in PLAYSTATION_NAME_TOKENS:
		if joy_name.contains(token):
			return &"playstation"
	return &"xbox"


## Notes the device behind [param event]: a key makes the keyboard the last device; a mouse
## button does too at once; mouse motion does once its accumulated relative length since the
## last gamepad event passes [constant MOUSE_MOTION_THRESHOLD]; a joypad button, or a stick
## at or past [constant JOYPAD_AXIS_THRESHOLD], makes the gamepad the last device, marks its
## pad connected and keeps its device id for the prompt family. Anything else (an
## [InputEventAction] such as an injected `pause`, stick drift) is ignored.
func note_event(event: InputEvent) -> void:
	if event is InputEventKey:
		_last_was_gamepad = false
	elif event is InputEventJoypadButton or (
			event is InputEventJoypadMotion
			and absf((event as InputEventJoypadMotion).axis_value) >= JOYPAD_AXIS_THRESHOLD):
		_last_was_gamepad = true
		_pads[event.device] = true
		_last_pad_device = event.device
		_mouse_motion_accum = 0.0
	elif event is InputEventMouseButton:
		_last_was_gamepad = false
	elif event is InputEventMouseMotion:
		_mouse_motion_accum += (event as InputEventMouseMotion).relative.length()
		if _mouse_motion_accum <= MOUSE_MOTION_THRESHOLD:
			return
		_last_was_gamepad = false
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
	var controller := get_controller_family()
	if controller != _controller_family:
		_controller_family = controller
		controller_family_changed.emit(controller)
	var family := get_prompt_family()
	if family != _prompt_family:
		_prompt_family = family
		prompt_family_changed.emit(family)
