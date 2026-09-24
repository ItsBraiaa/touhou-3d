class_name BindingLabels
extends RefCounted
## Node-free label table for the F16 binding descriptor
## `{kind, code, axis_sign, physical, modifiers}`, where `kind` is `"key"`,
## `"mouse_button"`, `"joy_button"` or `"joy_axis"`, and for the controller glyph family
## `&"keyboard_mouse"`, `&"xbox"` or `&"playstation"` (F16-08).
##
## [method describe] is the readable text a controls row shows; [method glyph_id] is the
## stable file id Astra names her glyphs by, and [method glyph_path] is the file convention
## F16-03 checks with [method ResourceLoader.exists] before falling back to the text.
## Everything here is static: the table holds no state and never asserts on malformed data.

## The layout's unbound label: a malformed or unknown descriptor describes as this.
const UNBOUND := "—"

## Names Godot gives in English that the controls screen shows in Portuguese. Enter, Tab,
## Shift, Ctrl and Alt are left as Godot gives them.
const PORTUGUESE_KEY_LABELS: Dictionary[String, String] = {
	"Space": "Espaço",
	"Escape": "Esc",
	"Left": "Seta ←",
	"Right": "Seta →",
	"Up": "Seta ↑",
	"Down": "Seta ↓",
}

## Xbox text names by Godot [enum JoyButton] index (GUIDE Section 14).
const XBOX_BUTTONS: Dictionary[int, String] = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View",
	JOY_BUTTON_GUIDE: "Xbox",
	JOY_BUTTON_START: "Menu",
	JOY_BUTTON_LEFT_STICK: "LS",
	JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
}

## PlayStation text names by Godot [enum JoyButton] index.
const PLAYSTATION_BUTTONS: Dictionary[int, String] = {
	JOY_BUTTON_A: "✕",
	JOY_BUTTON_B: "○",
	JOY_BUTTON_X: "□",
	JOY_BUTTON_Y: "△",
	JOY_BUTTON_BACK: "Create",
	JOY_BUTTON_GUIDE: "PS",
	JOY_BUTTON_START: "Options",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "L1",
	JOY_BUTTON_RIGHT_SHOULDER: "R1",
}

## Xbox glyph ids by Godot [enum JoyButton] index. The Guide button has none.
const XBOX_BUTTON_GLYPHS: Dictionary[int, StringName] = {
	JOY_BUTTON_A: &"xbox_a",
	JOY_BUTTON_B: &"xbox_b",
	JOY_BUTTON_X: &"xbox_x",
	JOY_BUTTON_Y: &"xbox_y",
	JOY_BUTTON_BACK: &"xbox_view",
	JOY_BUTTON_START: &"xbox_menu",
	JOY_BUTTON_LEFT_STICK: &"xbox_ls",
	JOY_BUTTON_RIGHT_STICK: &"xbox_rs",
	JOY_BUTTON_LEFT_SHOULDER: &"xbox_lb",
	JOY_BUTTON_RIGHT_SHOULDER: &"xbox_rb",
}

## PlayStation glyph ids by Godot [enum JoyButton] index. The PS button has none.
const PLAYSTATION_BUTTON_GLYPHS: Dictionary[int, StringName] = {
	JOY_BUTTON_A: &"ps_cross",
	JOY_BUTTON_B: &"ps_circle",
	JOY_BUTTON_X: &"ps_square",
	JOY_BUTTON_Y: &"ps_triangle",
	JOY_BUTTON_BACK: &"ps_create",
	JOY_BUTTON_START: &"ps_options",
	JOY_BUTTON_LEFT_STICK: &"ps_l3",
	JOY_BUTTON_RIGHT_STICK: &"ps_r3",
	JOY_BUTTON_LEFT_SHOULDER: &"ps_l1",
	JOY_BUTTON_RIGHT_SHOULDER: &"ps_r1",
}


## The readable text for one descriptor under the prompt [param family]. Never errors:
## a malformed or unknown descriptor describes as [constant UNBOUND].
static func describe(binding: Dictionary, family: StringName) -> String:
	var parsed := _parse(binding)
	if parsed.is_empty():
		return UNBOUND
	var kind: StringName = parsed[0]
	var code: int = parsed[1]
	match kind:
		&"key":
			return _describe_key(binding, code)
		&"mouse_button":
			return _describe_mouse_button(binding, code)
		&"joy_button":
			return _describe_joy_button(code, family)
		&"joy_axis":
			return _describe_joy_axis(binding, code, family)
	return UNBOUND


## The stable glyph id for one descriptor under the prompt [param family], or `&""` when
## there is none: keys and mouse buttons use text caps, and the Guide/PS button has no
## glyph. A malformed or unknown descriptor also gives `&""`.
static func glyph_id(binding: Dictionary, family: StringName) -> StringName:
	if family == &"keyboard_mouse":
		return &""
	var parsed := _parse(binding)
	if parsed.is_empty():
		return &""
	var kind: StringName = parsed[0]
	var code: int = parsed[1]
	match kind:
		&"joy_button":
			return _joy_button_glyph(code, family)
		&"joy_axis":
			return _joy_axis_glyph(binding, code, family)
	return &""


## The file convention for [param id]: `res://assets/ui/controls/glyphs/<id>.png`. An empty
## id gives an empty path, so a caller never probes the glyphs folder for a missing one.
static func glyph_path(id: StringName) -> String:
	if id.is_empty():
		return ""
	return "res://assets/ui/controls/glyphs/%s.png" % id


## The descriptor's `kind` and `code`, or an empty Array when either is missing or of the
## wrong type. The parser keeps [method describe] and [method glyph_id] from trusting bad
## data: no cast, no assert, no error.
static func _parse(binding: Dictionary) -> Array:
	if not binding.has("kind") or not binding.has("code"):
		return []
	var code_value: Variant = binding["code"]
	if code_value is int:
		return [StringName(str(binding["kind"])), int(code_value)]
	if code_value is float and is_finite(code_value):
		return [StringName(str(binding["kind"])), int(code_value)]
	return []


static func _describe_key(binding: Dictionary, code: int) -> String:
	if code == 0:
		return UNBOUND
	var label_code := code
	if _bool_field(binding, "physical", false):
		label_code = int(DisplayServer.keyboard_get_label_from_physical(code))
	var label := OS.get_keycode_string(label_code)
	if label.is_empty():
		return UNBOUND
	return _modifier_prefix(binding, code) + PORTUGUESE_KEY_LABELS.get(label, label)


static func _describe_mouse_button(binding: Dictionary, code: int) -> String:
	var label := ""
	match code:
		MOUSE_BUTTON_LEFT:
			label = "Mouse 1"
		MOUSE_BUTTON_RIGHT:
			label = "Mouse 2"
		MOUSE_BUTTON_MIDDLE:
			label = "Mouse 3"
		MOUSE_BUTTON_WHEEL_UP:
			label = "Roda ↑"
		MOUSE_BUTTON_WHEEL_DOWN:
			label = "Roda ↓"
		MOUSE_BUTTON_WHEEL_LEFT:
			label = "Roda ←"
		MOUSE_BUTTON_WHEEL_RIGHT:
			label = "Roda →"
		MOUSE_BUTTON_XBUTTON1:
			label = "Mouse 4"
		MOUSE_BUTTON_XBUTTON2:
			label = "Mouse 5"
		_:
			return UNBOUND
	return _modifier_prefix(binding, code) + label


static func _describe_joy_button(code: int, family: StringName) -> String:
	if code < 0:
		return UNBOUND
	match code:
		JOY_BUTTON_DPAD_UP:
			return "D-pad ↑"
		JOY_BUTTON_DPAD_DOWN:
			return "D-pad ↓"
		JOY_BUTTON_DPAD_LEFT:
			return "D-pad ←"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-pad →"
	if family == &"playstation":
		return PLAYSTATION_BUTTONS.get(code, "Botão %d" % code)
	return XBOX_BUTTONS.get(code, "Botão %d" % code)


static func _describe_joy_axis(binding: Dictionary, code: int, family: StringName) -> String:
	if code >= 0 and code <= 3:
		var arrow := _stick_arrow(code, _int_field(binding, "axis_sign", 0))
		if arrow.is_empty():
			return UNBOUND
		var base := "Analógico esq." if code <= 1 else "Analógico dir."
		return "%s %s" % [base, arrow]
	if code == JOY_AXIS_TRIGGER_LEFT:
		return "L2" if family == &"playstation" else "LT"
	if code == JOY_AXIS_TRIGGER_RIGHT:
		return "R2" if family == &"playstation" else "RT"
	return UNBOUND


## The arrow for a stick axis and a definite sign, or an empty String for any other sign
## (a malformed descriptor).
static func _stick_arrow(axis: int, sign: int) -> String:
	if sign != -1 and sign != 1:
		return ""
	if axis == 0 or axis == 2:
		return "←" if sign < 0 else "→"
	return "↑" if sign < 0 else "↓"


## `Shift+`, `Ctrl+`, `Alt+` and `Meta+` for the descriptor's modifier mask, in that order.
## A standalone modifier key is its own label: pressing Left Shift alone never gives
## `Shift+Shift`.
static func _modifier_prefix(binding: Dictionary, code: int) -> String:
	var modifiers := _int_field(binding, "modifiers", 0)
	var prefix := ""
	if (modifiers & KEY_MASK_SHIFT) != 0 and code != KEY_SHIFT:
		prefix += "Shift+"
	if (modifiers & KEY_MASK_CTRL) != 0 and code != KEY_CTRL:
		prefix += "Ctrl+"
	if (modifiers & KEY_MASK_ALT) != 0 and code != KEY_ALT:
		prefix += "Alt+"
	if (modifiers & KEY_MASK_META) != 0 and code != KEY_META:
		prefix += "Meta+"
	return prefix


static func _joy_button_glyph(code: int, family: StringName) -> StringName:
	match code:
		JOY_BUTTON_DPAD_UP:
			return &"dpad_up"
		JOY_BUTTON_DPAD_DOWN:
			return &"dpad_down"
		JOY_BUTTON_DPAD_LEFT:
			return &"dpad_left"
		JOY_BUTTON_DPAD_RIGHT:
			return &"dpad_right"
	if family == &"playstation":
		return PLAYSTATION_BUTTON_GLYPHS.get(code, &"")
	return XBOX_BUTTON_GLYPHS.get(code, &"")


static func _joy_axis_glyph(binding: Dictionary, code: int, family: StringName) -> StringName:
	if code == JOY_AXIS_TRIGGER_LEFT:
		return &"ps_l2" if family == &"playstation" else &"xbox_lt"
	if code == JOY_AXIS_TRIGGER_RIGHT:
		return &"ps_r2" if family == &"playstation" else &"xbox_rt"
	var sign := _int_field(binding, "axis_sign", 0)
	if sign != -1 and sign != 1:
		return &""
	match code:
		0:
			return &"stick_left_left" if sign < 0 else &"stick_left_right"
		1:
			return &"stick_left_up" if sign < 0 else &"stick_left_down"
		2:
			return &"stick_right_left" if sign < 0 else &"stick_right_right"
		3:
			return &"stick_right_up" if sign < 0 else &"stick_right_down"
	return &""


static func _int_field(binding: Dictionary, key: String, fallback: int) -> int:
	if not binding.has(key):
		return fallback
	var value: Variant = binding[key]
	if value is int:
		return value
	if value is float and is_finite(value):
		return int(value)
	return fallback


static func _bool_field(binding: Dictionary, key: String, fallback: bool) -> bool:
	if not binding.has(key):
		return fallback
	var value: Variant = binding[key]
	if value is bool:
		return value
	return fallback
