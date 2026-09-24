class_name InputBindings
extends RefCounted
## Node-free Rules Core (ADR-0001) for the F16 action catalog and its two editable binding
## profiles: every gameplay action, `camera_recenter`, the two dashes, and the `ui_*`
## actions the menus use (focus navigation, buttons and [Interface]'s `ui_cancel`).
##
## A binding is a primitive descriptor, never a serialized [InputEvent]:
## `{kind, code, axis_sign, physical, modifiers, location}` (see [method key_binding] and
## its siblings). A profile holds [constant SLOT_COUNT] slots per action, bound slots
## first; a blank slot is an empty Dictionary. [constant KEYBOARD_MOUSE] takes keys and
## mouse buttons, [constant GAMEPAD] joypad buttons and axes, and both are live at once:
## [InputBindingAdapter] turns them into [InputMap] events.
##
## Conflicts are checked within one profile, between actions whose contexts overlap.
## [constant CONTEXT_GAMEPLAY] actions are read in play and [constant CONTEXT_MENU] ones
## while a menu has focus, so movement and menu navigation share the stick, the D-pad and
## the arrows freely. `pause` is read in both (it also resumes from Pause); its sharing
## of Escape with `ui_cancel`, which on Pause means resume too, is the one permitted
## overlap.
##
## [Settings] owns the live instance and persists it. Consumers read it; an editor works
## on a copy (`InputBindings.new()`, then [method restore] of the live [method capture])
## that [method Settings.apply_input_bindings] validates, saves and makes live.


const KEYBOARD_MOUSE := &"keyboard_mouse"
const GAMEPAD := &"gamepad"
const PROFILES: Array[StringName] = [KEYBOARD_MOUSE, GAMEPAD]
## Slots per action per profile: Principal and Alternativo.
const SLOT_COUNT := 2

const KIND_KEY := "key"
const KIND_MOUSE_BUTTON := "mouse_button"
const KIND_JOY_BUTTON := "joy_button"
const KIND_JOY_AXIS := "joy_axis"

## Read while a stage runs with the HUD on top.
const CONTEXT_GAMEPLAY := 1
## Read while a menu or overlay has focus.
const CONTEXT_MENU := 2

## [method assign] only when nothing conflicts.
const RESOLUTION_NONE := &""
## Trocar: each conflicting action takes the slot's previous binding.
const RESOLUTION_SWAP := &"swap"
## Substituir: the binding is removed from each conflicting action.
const RESOLUTION_REPLACE := &"replace"
## Cancelar: nothing changes.
const RESOLUTION_CANCEL := &"cancel"

const CATEGORY_MOVEMENT := &"movement"
const CATEGORY_COMBAT := &"combat"
const CATEGORY_CAMERA := &"camera"
const CATEGORY_MENUS := &"menus"
## The Controls screen's groups, in display order.
const CATEGORIES: Array[StringName] = [CATEGORY_MOVEMENT, CATEGORY_COMBAT, CATEGORY_CAMERA, CATEGORY_MENUS]
const CATEGORY_LABELS: Dictionary[StringName, String] = {
	CATEGORY_MOVEMENT: "Movimento",
	CATEGORY_COMBAT: "Combate",
	CATEGORY_CAMERA: "Câmera",
	CATEGORY_MENUS: "Menus",
}

## Every rebindable action, in display order: its Portuguese label, its category, the
## contexts it is read in (a mask), and whether each profile must keep it bound, so that
## nobody can lose the way to play, to pause or to drive the menus.
const CATALOG: Dictionary[StringName, Dictionary] = {
	&"move_forward": {"label": "Avançar", "category": CATEGORY_MOVEMENT, "contexts": CONTEXT_GAMEPLAY, "required": true},
	&"move_back": {"label": "Recuar", "category": CATEGORY_MOVEMENT, "contexts": CONTEXT_GAMEPLAY, "required": true},
	&"move_left": {"label": "Mover à esquerda", "category": CATEGORY_MOVEMENT, "contexts": CONTEXT_GAMEPLAY, "required": true},
	&"move_right": {"label": "Mover à direita", "category": CATEGORY_MOVEMENT, "contexts": CONTEXT_GAMEPLAY, "required": true},
	&"ascend": {"label": "Subir", "category": CATEGORY_MOVEMENT, "contexts": CONTEXT_GAMEPLAY, "required": true},
	&"descend": {"label": "Descer", "category": CATEGORY_MOVEMENT, "contexts": CONTEXT_GAMEPLAY, "required": true},
	&"dash_left": {"label": "Impulso à esquerda", "category": CATEGORY_MOVEMENT, "contexts": CONTEXT_GAMEPLAY, "required": false},
	&"dash_right": {"label": "Impulso à direita", "category": CATEGORY_MOVEMENT, "contexts": CONTEXT_GAMEPLAY, "required": false},
	&"fire": {"label": "Disparar", "category": CATEGORY_COMBAT, "contexts": CONTEXT_GAMEPLAY, "required": true},
	&"focus": {"label": "Foco", "category": CATEGORY_COMBAT, "contexts": CONTEXT_GAMEPLAY, "required": false},
	&"lock_target": {"label": "Fixar alvo", "category": CATEGORY_COMBAT, "contexts": CONTEXT_GAMEPLAY, "required": false},
	&"next_target": {"label": "Trocar alvo", "category": CATEGORY_COMBAT, "contexts": CONTEXT_GAMEPLAY, "required": false},
	&"bomb": {"label": "Bomba", "category": CATEGORY_COMBAT, "contexts": CONTEXT_GAMEPLAY, "required": false},
	&"camera_left": {"label": "Câmera à esquerda", "category": CATEGORY_CAMERA, "contexts": CONTEXT_GAMEPLAY, "required": false},
	&"camera_right": {"label": "Câmera à direita", "category": CATEGORY_CAMERA, "contexts": CONTEXT_GAMEPLAY, "required": false},
	&"camera_up": {"label": "Câmera para cima", "category": CATEGORY_CAMERA, "contexts": CONTEXT_GAMEPLAY, "required": false},
	&"camera_down": {"label": "Câmera para baixo", "category": CATEGORY_CAMERA, "contexts": CONTEXT_GAMEPLAY, "required": false},
	&"camera_recenter": {"label": "Centralizar câmera", "category": CATEGORY_CAMERA, "contexts": CONTEXT_GAMEPLAY, "required": false},
	&"pause": {"label": "Pausa", "category": CATEGORY_MENUS, "contexts": CONTEXT_GAMEPLAY | CONTEXT_MENU, "required": true},
	&"ui_up": {"label": "Navegar para cima", "category": CATEGORY_MENUS, "contexts": CONTEXT_MENU, "required": true},
	&"ui_down": {"label": "Navegar para baixo", "category": CATEGORY_MENUS, "contexts": CONTEXT_MENU, "required": true},
	&"ui_left": {"label": "Navegar à esquerda", "category": CATEGORY_MENUS, "contexts": CONTEXT_MENU, "required": true},
	&"ui_right": {"label": "Navegar à direita", "category": CATEGORY_MENUS, "contexts": CONTEXT_MENU, "required": true},
	&"ui_accept": {"label": "Confirmar", "category": CATEGORY_MENUS, "contexts": CONTEXT_MENU, "required": true},
	&"ui_cancel": {"label": "Voltar", "category": CATEGORY_MENUS, "contexts": CONTEXT_MENU, "required": true},
	&"ui_focus_next": {"label": "Próximo item", "category": CATEGORY_MENUS, "contexts": CONTEXT_MENU, "required": false},
	&"ui_focus_prev": {"label": "Item anterior", "category": CATEGORY_MENUS, "contexts": CONTEXT_MENU, "required": false},
}

## The modifier bits a key or mouse-button chord may carry (Shift+Tab is `ui_focus_prev`).
const MODIFIER_MASK := KEY_MASK_SHIFT | KEY_MASK_CTRL | KEY_MASK_ALT | KEY_MASK_META

const _FIELDS: Array[String] = ["kind", "code", "axis_sign", "physical", "modifiers", "location"]
const _KINDS: Dictionary[StringName, Array] = {
	KEYBOARD_MOUSE: [KIND_KEY, KIND_MOUSE_BUTTON],
	GAMEPAD: [KIND_JOY_BUTTON, KIND_JOY_AXIS],
}
const _RESOLUTIONS: Array[StringName] = [RESOLUTION_NONE, RESOLUTION_SWAP, RESOLUTION_REPLACE, RESOLUTION_CANCEL]
## Action pairs whose contexts overlap but may still share an input. Escape is `pause`
## and `ui_cancel`: on Pause both mean resume ([Interface] takes `ui_cancel` first).
const _SHARES: Dictionary[StringName, StringName] = {&"pause": &"ui_cancel"}
## A standalone modifier key reports its own bit as pressed; the descriptor drops it, so
## Left Shift is `{code: KEY_SHIFT, modifiers: 0}` as in `project.godot`.
const _SELF_MODIFIER := {KEY_SHIFT: KEY_MASK_SHIFT, KEY_CTRL: KEY_MASK_CTRL, KEY_ALT: KEY_MASK_ALT, KEY_META: KEY_MASK_META}
## The special keys Godot 4.7 names in [enum Key], as inclusive ranges; the codes between
## them are unassigned. [constant KEY_UNKNOWN] is not a key one can bind.
const _SPECIAL_KEY_RANGES: Array[Vector2i] = [
	Vector2i(KEY_ESCAPE, KEY_F35),
	Vector2i(KEY_MENU, KEY_HYPER),
	Vector2i(KEY_HELP, KEY_HELP),
	Vector2i(KEY_BACK, KEY_VOLUMEUP),
	Vector2i(KEY_MEDIAPLAY, KEY_JIS_KANA),
	Vector2i(KEY_KP_MULTIPLY, KEY_KP_9),
]
## The highest Unicode code point. Below [constant KEY_SPECIAL] any printable character is
## taken, not only the [enum Key] ones, since a platform may report a layout key's own
## character as its keycode.
const _UNICODE_MAX := 0x10FFFF

## Profile id -> action -> [constant SLOT_COUNT] normalized slots, bound ones first.
var _profiles: Dictionary = {}


## Starts at [method default_profiles].
func _init() -> void:
	_profiles = default_profiles()


## A key. [param code] is a physical keycode when [param physical] (the key's position, as
## gameplay uses), else a keycode on the active layout (as the menus use).
## [param modifiers] is a [constant MODIFIER_MASK] chord; [param location] tells a left
## modifier key from a right one ([enum KeyLocation], physical keys only).
static func key_binding(code: int, physical: bool = true, modifiers: int = 0, location: int = KEY_LOCATION_UNSPECIFIED) -> Dictionary:
	return {"kind": KIND_KEY, "code": code, "axis_sign": 0, "physical": physical, "modifiers": modifiers, "location": location}


## A mouse button or wheel direction ([enum MouseButton] 1 to 9), with an optional chord.
static func mouse_button_binding(button: int, modifiers: int = 0) -> Dictionary:
	return {"kind": KIND_MOUSE_BUTTON, "code": button, "axis_sign": 0, "physical": false, "modifiers": modifiers, "location": 0}


## A joypad button ([enum JoyButton]), for every pad.
static func joy_button_binding(button: int) -> Dictionary:
	return {"kind": KIND_JOY_BUTTON, "code": button, "axis_sign": 0, "physical": false, "modifiers": 0, "location": 0}


## One direction of a joypad axis ([enum JoyAxis]): [param axis_sign] is -1 or +1, and a
## trigger only has +1. The action keeps the axis' analog strength.
static func joy_axis_binding(axis: int, axis_sign: int) -> Dictionary:
	return {"kind": KIND_JOY_AXIS, "code": axis, "axis_sign": axis_sign, "physical": false, "modifiers": 0, "location": 0}


## [param value] as a normalized descriptor (every field present, a modifier key's own bit
## dropped), or an empty Dictionary when it is blank or invalid. With [param profile], a
## descriptor of the other device is invalid too. Rejected: an unknown field or kind, a
## field of the wrong type, a code outside its kind's range (for a key, a code no key
## reports), a sign on anything but an axis, a negative trigger, and modifier bits
## outside [constant MODIFIER_MASK].
static func parse_binding(value: Variant, profile: StringName = &"") -> Dictionary:
	if not _binding_problem(value, profile).is_empty():
		return {}
	return _normalized(value)


## The profile a valid descriptor belongs to, or `&""` for a blank or invalid one.
static func profile_for(binding: Dictionary) -> StringName:
	var parsed := parse_binding(binding)
	if parsed.is_empty():
		return &""
	return KEYBOARD_MOUSE if (_KINDS[KEYBOARD_MOUSE] as Array).has(parsed["kind"]) else GAMEPAD


## Whether two descriptors are the same physical input: same kind and code, the same
## chord, the same axis direction (opposite signs are distinct), and compatible key
## locations. The physical flag is ignored, so a physical key and a layout key with the
## same code count as one key. That is exact for the special keys (Escape, Enter, Tab,
## the arrows) on any layout, and for every key on US QWERTY. On another layout a physical
## and a layout character key are compared by code, not by key, since this Node-free core
## does not know the layout: only `pause` (physical) and the menu-only actions (layout)
## meet this way, and F16-03's capture resolves it with the layout. A blank or invalid
## descriptor matches nothing.
static func same_input(a: Dictionary, b: Dictionary) -> bool:
	return _same_input(parse_binding(a), parse_binding(b))


## The actions of [param category] in display order, or every catalog action.
static func get_actions(category: StringName = &"") -> Array[StringName]:
	var result: Array[StringName] = []
	for action: StringName in CATALOG:
		if category.is_empty() or CATALOG[action]["category"] == category:
			result.append(action)
	return result


## The Portuguese label of [param action], or "" when it is not in the catalog.
static func get_label(action: StringName) -> String:
	return CATALOG[action]["label"] if CATALOG.has(action) else ""


## The category of [param action], or `&""` when it is not in the catalog.
static func get_category(action: StringName) -> StringName:
	return CATALOG[action]["category"] if CATALOG.has(action) else &""


## The [constant CONTEXT_GAMEPLAY] / [constant CONTEXT_MENU] mask of [param action], 0
## when it is not in the catalog.
static func get_contexts(action: StringName) -> int:
	return CATALOG[action]["contexts"] if CATALOG.has(action) else 0


## Whether every profile must keep [param action] bound.
static func is_required(action: StringName) -> bool:
	return CATALOG.has(action) and CATALOG[action]["required"]


## Whether [param action] takes physical keys (gameplay, by position) rather than keys
## of the active layout (menu-only actions, so Enter and the arrows follow the layout).
static func uses_physical_keys(action: StringName) -> bool:
	return (get_contexts(action) & CONTEXT_GAMEPLAY) != 0


## Whether actions [param a] and [param b] may hold the same input in one profile: their
## contexts do not overlap, or they are a permitted pair (`pause` and `ui_cancel`).
static func can_share(a: StringName, b: StringName) -> bool:
	if (get_contexts(a) & get_contexts(b)) == 0:
		return true
	return (_SHARES.has(a) and _SHARES[a] == b) or (_SHARES.has(b) and _SHARES[b] == a)


## A fresh copy of both default profiles, equal to `project.godot`'s `[input]` and to
## Godot's built-in `ui_*` events ([method InputBindingAdapter.find_default_drift] checks
## it in editor builds). Profile id -> action -> [constant SLOT_COUNT] slots.
static func default_profiles() -> Dictionary:
	var keyboard_mouse: Dictionary = {
		&"move_forward": [key_binding(KEY_W)],
		&"move_back": [key_binding(KEY_S)],
		&"move_left": [key_binding(KEY_A)],
		&"move_right": [key_binding(KEY_D)],
		&"ascend": [key_binding(KEY_SPACE)],
		&"descend": [key_binding(KEY_CTRL, true, 0, KEY_LOCATION_LEFT)],
		&"dash_left": [key_binding(KEY_Q)],
		&"dash_right": [key_binding(KEY_E)],
		&"fire": [key_binding(KEY_J)],
		&"focus": [key_binding(KEY_SHIFT, true, 0, KEY_LOCATION_LEFT)],
		&"lock_target": [key_binding(KEY_K)],
		&"next_target": [key_binding(KEY_TAB)],
		&"bomb": [key_binding(KEY_L)],
		&"camera_left": [key_binding(KEY_LEFT)],
		&"camera_right": [key_binding(KEY_RIGHT)],
		&"camera_up": [key_binding(KEY_UP)],
		&"camera_down": [key_binding(KEY_DOWN)],
		&"camera_recenter": [key_binding(KEY_R), mouse_button_binding(MOUSE_BUTTON_MIDDLE)],
		&"pause": [key_binding(KEY_ESCAPE)],
		&"ui_up": [key_binding(KEY_UP, false)],
		&"ui_down": [key_binding(KEY_DOWN, false)],
		&"ui_left": [key_binding(KEY_LEFT, false)],
		&"ui_right": [key_binding(KEY_RIGHT, false)],
		&"ui_accept": [key_binding(KEY_ENTER, false), key_binding(KEY_SPACE, false)],
		&"ui_cancel": [key_binding(KEY_ESCAPE, false)],
		&"ui_focus_next": [key_binding(KEY_TAB, false)],
		&"ui_focus_prev": [key_binding(KEY_TAB, false, KEY_MASK_SHIFT)],
	}
	var gamepad: Dictionary = {
		&"move_forward": [joy_axis_binding(JOY_AXIS_LEFT_Y, -1)],
		&"move_back": [joy_axis_binding(JOY_AXIS_LEFT_Y, 1)],
		&"move_left": [joy_axis_binding(JOY_AXIS_LEFT_X, -1)],
		&"move_right": [joy_axis_binding(JOY_AXIS_LEFT_X, 1)],
		&"ascend": [joy_button_binding(JOY_BUTTON_RIGHT_SHOULDER)],
		&"descend": [joy_button_binding(JOY_BUTTON_LEFT_SHOULDER)],
		&"dash_left": [joy_button_binding(JOY_BUTTON_DPAD_LEFT)],
		&"dash_right": [joy_button_binding(JOY_BUTTON_DPAD_RIGHT)],
		&"fire": [joy_axis_binding(JOY_AXIS_TRIGGER_RIGHT, 1)],
		&"focus": [joy_axis_binding(JOY_AXIS_TRIGGER_LEFT, 1)],
		&"lock_target": [joy_button_binding(JOY_BUTTON_Y)],
		&"next_target": [joy_button_binding(JOY_BUTTON_X)],
		&"bomb": [joy_button_binding(JOY_BUTTON_B)],
		&"camera_left": [joy_axis_binding(JOY_AXIS_RIGHT_X, -1)],
		&"camera_right": [joy_axis_binding(JOY_AXIS_RIGHT_X, 1)],
		&"camera_up": [joy_axis_binding(JOY_AXIS_RIGHT_Y, -1)],
		&"camera_down": [joy_axis_binding(JOY_AXIS_RIGHT_Y, 1)],
		&"camera_recenter": [joy_button_binding(JOY_BUTTON_RIGHT_STICK)],
		&"pause": [joy_button_binding(JOY_BUTTON_START)],
		&"ui_up": [joy_button_binding(JOY_BUTTON_DPAD_UP), joy_axis_binding(JOY_AXIS_LEFT_Y, -1)],
		&"ui_down": [joy_button_binding(JOY_BUTTON_DPAD_DOWN), joy_axis_binding(JOY_AXIS_LEFT_Y, 1)],
		&"ui_left": [joy_button_binding(JOY_BUTTON_DPAD_LEFT), joy_axis_binding(JOY_AXIS_LEFT_X, -1)],
		&"ui_right": [joy_button_binding(JOY_BUTTON_DPAD_RIGHT), joy_axis_binding(JOY_AXIS_LEFT_X, 1)],
		&"ui_accept": [joy_button_binding(JOY_BUTTON_A)],
		&"ui_cancel": [joy_button_binding(JOY_BUTTON_B)],
	}
	return {KEYBOARD_MOUSE: _padded(keyboard_mouse), GAMEPAD: _padded(gamepad)}


## The default slots of [param action] in [param profile] (for a row's Redefinir).
static func get_default_bindings(profile: StringName, action: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if PROFILES.has(profile) and CATALOG.has(action):
		for binding: Dictionary in default_profiles()[profile][action]:
			result.append(binding)
	return result


## Bindings of [param action] that are installed with [param profile] but never shown in
## a slot, edited or saved. The only one is Numpad Enter on `ui_accept`, the third key
## Godot gives it, kept so no default is lost to the two slots. They count as conflicts
## for other actions, but not towards a required action's binding.
static func get_fixed_bindings(profile: StringName, action: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if profile == KEYBOARD_MOUSE and action == &"ui_accept":
		result.append(key_binding(KEY_KP_ENTER, false))
	return result


## Every reason [param data] is not a complete, valid [param profile] (action -> slots,
## as in [method capture]): unknown or missing actions, malformed slots, a required
## action left unbound, one input on two actions that cannot share it. Empty when valid.
static func check_profile_data(profile: StringName, data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not PROFILES.has(profile):
		errors.append("InputBindings: unknown profile '%s'" % profile)
		return errors
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("InputBindings: the %s profile is not a Dictionary" % profile)
		return errors
	var source: Dictionary = data
	for key: Variant in source:
		if not _is_catalog_action(key):
			errors.append("InputBindings: %s has the unknown action %s" % [profile, key])
	var parsed: Dictionary = {}
	for action: StringName in CATALOG:
		if not source.has(action):
			errors.append("InputBindings: %s/%s is missing" % [profile, action])
			continue
		var problem := _slots_problem(profile, source[action])
		if problem.is_empty():
			parsed[action] = _normalized_slots(source[action])
		else:
			errors.append("InputBindings: %s/%s %s" % [profile, action, problem])
	if errors.is_empty():
		errors = _profile_errors(profile, parsed)
	return errors


## [param data] (which passed [method check_profile_data]) with every slot normalized
## and packed, bound slots first.
static func normalize_profile(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for action: StringName in CATALOG:
		result[action] = _normalized_slots(data[action])
	return result


## A deep copy of both profiles: profile id -> action -> [constant SLOT_COUNT] slots.
func capture() -> Dictionary:
	return _profiles.duplicate(true)


## Restores both profiles from [param data] (as from [method capture], or a settings
## file). A missing profile or action takes its default silently, so actions added to the
## catalog later get their defaults. Malformed slots fall back to that action's default.
## A fallen-back action leaves out each default input that an action kept from
## [param data] holds and cannot share, so the player's remaps survive it; a required one
## that would be left unbound takes those inputs back from their holders instead. A
## profile left inconsistent (the kept bindings conflict, or a take-back leaves a
## required holder unbound) falls back to that profile's defaults. Each fallback, each
## default left out or taken back and each unknown key is one diagnostic.
func restore(data: Dictionary) -> PackedStringArray:
	var messages := PackedStringArray()
	for key: Variant in data:
		if not _is_profile(key):
			messages.append("InputBindings: unknown profile %s ignored" % [key])
	var defaults := default_profiles()
	for profile: StringName in PROFILES:
		if data.has(profile):
			messages.append_array(_restore_profile(profile, data[profile], defaults[profile]))
		else:
			_profiles[profile] = defaults[profile]
	return messages


## Copies of the [constant SLOT_COUNT] slots of [param action] in [param profile], bound
## slots first, a blank slot empty.
func get_bindings(profile: StringName, action: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _profiles.has(profile) or not CATALOG.has(action):
		push_error("InputBindings: unknown profile or action '%s/%s'" % [profile, action])
		return result
	for binding: Dictionary in _profiles[profile][action]:
		result.append(binding.duplicate())
	return result


## The other actions of [param profile] that already hold [param binding] and whose
## contexts overlap [param action]'s ([method can_share]), fixed bindings included, in
## catalog order. Empty for a blank or invalid binding.
func find_conflicts(profile: StringName, action: StringName, binding: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var wanted := parse_binding(binding, profile)
	if wanted.is_empty() or not _profiles.has(profile) or not CATALOG.has(action):
		return result
	var data: Dictionary = _profiles[profile]
	for other: StringName in CATALOG:
		if other == action or can_share(action, other):
			continue
		for bound: Dictionary in _bound(profile, other, data[other]):
			if _same_input(bound, wanted):
				result.append(other)
				break
	return result


## Puts [param binding] in [param slot] of [param action] in [param profile], as one
## transaction: empty result, everything applied; otherwise the reasons, and nothing
## changed. An empty [param binding] clears the slot. With conflicts ([method
## find_conflicts]) [param resolution] decides: [constant RESOLUTION_SWAP] gives each
## conflicting action the slot's previous binding, [constant RESOLUTION_REPLACE] removes
## the binding from them, and [constant RESOLUTION_NONE] refuses. The result must pass
## [method validate_profile], so a swap or a replacement that leaves a required action
## unbound, or moves a binding into a new conflict, is refused. A fixed binding never
## moves. [constant RESOLUTION_CANCEL] always refuses. Slots stay packed, bound first.
func assign(profile: StringName, action: StringName, slot: int, binding: Dictionary, resolution: StringName = RESOLUTION_NONE) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _profiles.has(profile):
		errors.append("InputBindings: unknown profile '%s'" % profile)
	if not CATALOG.has(action):
		errors.append("InputBindings: unknown action '%s'" % action)
	if slot < 0 or slot >= SLOT_COUNT:
		errors.append("InputBindings: slot %d is not 0 to %d" % [slot, SLOT_COUNT - 1])
	if not _RESOLUTIONS.has(resolution):
		errors.append("InputBindings: unknown resolution '%s'" % resolution)
	var wanted: Dictionary = {}
	if not binding.is_empty():
		var problem := _binding_problem(binding, profile)
		if problem.is_empty():
			wanted = _normalized(binding)
		else:
			errors.append("InputBindings: the binding %s" % problem)
	if errors.is_empty() and resolution == RESOLUTION_CANCEL:
		errors.append("InputBindings: the assignment was cancelled")
	if not errors.is_empty():
		return errors
	var draft: Dictionary = _profiles[profile].duplicate(true)
	var slots: Array = draft[action]
	var previous: Dictionary = slots[slot]
	for index: int in SLOT_COUNT:
		if index != slot and _same_input(slots[index], wanted):
			errors.append("InputBindings: %s/%s already has that binding in slot %d" % [profile, action, index])
	for fixed: Dictionary in get_fixed_bindings(profile, action):
		if _same_input(fixed, wanted):
			errors.append("InputBindings: %s/%s already has that binding as a fixed one" % [profile, action])
	var conflicts := find_conflicts(profile, action, wanted)
	if not conflicts.is_empty() and resolution == RESOLUTION_NONE:
		errors.append("InputBindings: %s/%s conflicts with %s" % [profile, action, ", ".join(PackedStringArray(conflicts))])
	if not errors.is_empty():
		return errors
	slots[slot] = wanted
	draft[action] = _packed(slots)
	for other: StringName in conflicts:
		for fixed: Dictionary in get_fixed_bindings(profile, other):
			if _same_input(fixed, wanted):
				errors.append("InputBindings: that binding is fixed on %s/%s and cannot move" % [profile, other])
		var other_slots: Array = draft[other]
		for index: int in SLOT_COUNT:
			if _same_input(other_slots[index], wanted):
				other_slots[index] = previous.duplicate() if resolution == RESOLUTION_SWAP else {}
		draft[other] = _packed(other_slots)
	if errors.is_empty():
		errors = _profile_errors(profile, draft)
	if errors.is_empty():
		_profiles[profile] = draft
	return errors


## Every reason [param profile] is invalid: a required action unbound, or one input on two
## actions that cannot share it ([method can_share]). Empty when valid.
func validate_profile(profile: StringName) -> PackedStringArray:
	if not _profiles.has(profile):
		var errors := PackedStringArray()
		errors.append("InputBindings: unknown profile '%s'" % profile)
		return errors
	return _profile_errors(profile, _profiles[profile])


## Puts every action of [param profile] back at its default (Restaurar esta aba). The
## defaults are always valid.
func restore_profile_defaults(profile: StringName) -> void:
	if not _profiles.has(profile):
		push_error("InputBindings: unknown profile '%s'" % profile)
		return
	_profiles[profile] = default_profiles()[profile]


## Puts [param action] of [param profile] back at its default slots (a row's Redefinir),
## as one transaction: refused, with the reasons, when a default is now held by an action
## it conflicts with. Empty result when applied.
func restore_action_defaults(profile: StringName, action: StringName) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _profiles.has(profile) or not CATALOG.has(action):
		errors.append("InputBindings: unknown profile or action '%s/%s'" % [profile, action])
		return errors
	var draft: Dictionary = _profiles[profile].duplicate(true)
	draft[action] = default_profiles()[profile][action]
	errors = _profile_errors(profile, draft)
	if errors.is_empty():
		_profiles[profile] = draft
	return errors


## Stores [param value] as [param profile], or [param fallback] when it is not a
## Dictionary or the result is inconsistent; each missing or malformed action falls back
## to its own default first, settled against the kept actions ([method
## _settle_defaults]). Returns one diagnostic per fallback, default left out or taken
## back, or unknown action.
func _restore_profile(profile: StringName, value: Variant, fallback: Dictionary) -> PackedStringArray:
	var messages := PackedStringArray()
	_profiles[profile] = fallback
	if typeof(value) != TYPE_DICTIONARY:
		messages.append("InputBindings: the %s profile is not a Dictionary; its defaults are in use" % profile)
		return messages
	var source: Dictionary = value
	for key: Variant in source:
		if not _is_catalog_action(key):
			messages.append("InputBindings: %s has the unknown action %s; ignored" % [profile, key])
	var result: Dictionary = {}
	var kept: Array[StringName] = []
	for action: StringName in CATALOG:
		result[action] = fallback[action]
		if not source.has(action):
			continue
		var problem := _slots_problem(profile, source[action])
		var slots: Array = [] if not problem.is_empty() else _normalized_slots(source[action])
		if problem.is_empty() and is_required(action) and (slots[0] as Dictionary).is_empty():
			problem = "leaves a required action unbound"
		if problem.is_empty():
			result[action] = slots
			kept.append(action)
		else:
			messages.append("InputBindings: %s/%s %s; its default is in use" % [profile, action, problem])
	for action: StringName in CATALOG:
		if not kept.has(action):
			messages.append_array(_settle_defaults(profile, action, result, kept))
	var errors := _profile_errors(profile, result)
	if errors.is_empty():
		_profiles[profile] = result
	else:
		messages.append_array(errors)
		messages.append("InputBindings: the %s profile is inconsistent; its defaults are in use" % profile)
	return messages


## Settles the default slots of [param action] in [param result] against the actions of
## [param kept] (read from the file), so a fallback undoes as few remaps as it can: each
## default input that a kept action holds and cannot share is left out. A required action
## left with no binding that way takes those inputs back from their holders instead; a
## holder then left without its own required binding makes the profile inconsistent. The
## defaults never conflict among themselves, so only kept actions are checked. Returns
## one diagnostic per input left out or taken back.
static func _settle_defaults(profile: StringName, action: StringName, result: Dictionary, kept: Array[StringName]) -> PackedStringArray:
	var messages := PackedStringArray()
	var unheld: Array = []
	var taken: Array[Dictionary] = []
	var holders: Array[StringName] = []
	for binding: Dictionary in result[action]:
		var holder: StringName = &""
		for other: StringName in kept:
			if not holder.is_empty() or can_share(action, other):
				continue
			for bound: Dictionary in _bound(profile, other, result[other]):
				if _same_input(bound, binding):
					holder = other
		if holder.is_empty():
			unheld.append(binding)
		else:
			taken.append(binding)
			holders.append(holder)
	if taken.is_empty():
		return messages
	var slots := _packed(unheld)
	if not is_required(action) or not (slots[0] as Dictionary).is_empty():
		result[action] = slots
		for index: int in taken.size():
			messages.append("InputBindings: %s/%s leaves out its default %s, which %s holds" % [profile, action, taken[index], holders[index]])
		return messages
	for other: StringName in kept:
		if can_share(action, other):
			continue
		var other_slots: Array = []
		for bound: Dictionary in result[other]:
			var reclaimed := false
			for binding: Dictionary in taken:
				reclaimed = reclaimed or _same_input(bound, binding)
			if reclaimed:
				messages.append("InputBindings: %s/%s is required, so it takes its default %s back from %s" % [profile, action, bound, other])
			else:
				other_slots.append(bound)
		result[other] = _packed(other_slots)
	return messages


## Required actions unbound and forbidden sharing in [param data], a normalized profile.
static func _profile_errors(profile: StringName, data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var owners: Array[StringName] = []
	var inputs: Array[Dictionary] = []
	for action: StringName in CATALOG:
		var slots: Array = data[action]
		if is_required(action) and (slots[0] as Dictionary).is_empty():
			errors.append("InputBindings: %s/%s is required but has no binding" % [profile, action])
		for binding: Dictionary in _bound(profile, action, slots):
			for index: int in inputs.size():
				if not _same_input(inputs[index], binding):
					continue
				if owners[index] == action:
					errors.append("InputBindings: %s/%s has the same binding twice" % [profile, action])
				elif not can_share(owners[index], action):
					errors.append("InputBindings: %s/%s and %s share %s" % [profile, owners[index], action, binding])
			owners.append(action)
			inputs.append(binding)
	return errors


## The bound slots of [param action] plus its fixed bindings.
static func _bound(profile: StringName, action: StringName, slots: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for binding: Dictionary in slots:
		if not binding.is_empty():
			result.append(binding)
	result.append_array(get_fixed_bindings(profile, action))
	return result


## Each action of [param source] padded to [constant SLOT_COUNT] slots, missing ones blank.
static func _padded(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for action: StringName in CATALOG:
		result[action] = _packed(source.get(action, []))
	return result


## [param bindings] with blanks and repeats dropped, then padded with blanks.
static func _packed(bindings: Array) -> Array:
	var result: Array = []
	for binding: Dictionary in bindings:
		if binding.is_empty():
			continue
		var seen := false
		for kept: Dictionary in result:
			seen = seen or _same_input(kept, binding)
		if not seen:
			result.append(binding)
	while result.size() < SLOT_COUNT:
		result.append({})
	return result


## Why [param value] cannot be the slots of one action in [param profile], or "".
static func _slots_problem(profile: StringName, value: Variant) -> String:
	if typeof(value) != TYPE_ARRAY:
		return "is not an Array"
	var slots: Array = value
	if slots.size() > SLOT_COUNT:
		return "has %d slots, more than %d" % [slots.size(), SLOT_COUNT]
	for index: int in slots.size():
		var entry: Variant = slots[index]
		if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).is_empty():
			continue
		var problem := _binding_problem(entry, profile)
		if not problem.is_empty():
			return "slot %d %s" % [index, problem]
	return ""


## [param value], which passed [method _slots_problem], normalized and packed.
static func _normalized_slots(value: Array) -> Array:
	var bindings: Array = []
	for entry: Variant in value:
		bindings.append(parse_binding(entry))
	return _packed(bindings)


## Why [param value] is not a valid descriptor (for [param profile] when given), or "".
static func _binding_problem(value: Variant, profile: StringName) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return "is not a Dictionary"
	var binding: Dictionary = value
	for field: Variant in binding:
		if not _FIELDS.has(str(field)):
			return "has the unknown field %s" % [field]
	var kind: Variant = binding.get("kind")
	if typeof(kind) != TYPE_STRING and typeof(kind) != TYPE_STRING_NAME:
		return "has no kind"
	if not (_KINDS[KEYBOARD_MOUSE] + _KINDS[GAMEPAD]).has(String(kind)):
		return "has the unknown kind '%s'" % kind
	if not profile.is_empty() and not (_KINDS.get(profile, []) as Array).has(String(kind)):
		return "is a %s, which the %s profile does not take" % [kind, profile]
	if typeof(binding.get("code")) != TYPE_INT:
		return "has no integer code"
	for int_field: String in ["axis_sign", "modifiers", "location"]:
		if binding.has(int_field) and typeof(binding[int_field]) != TYPE_INT:
			return "has a non-integer %s" % int_field
	if binding.has("physical") and typeof(binding["physical"]) != TYPE_BOOL:
		return "has a non-boolean physical"
	var code: int = binding["code"]
	var axis_sign: int = binding.get("axis_sign", 0)
	var modifiers: int = binding.get("modifiers", 0)
	var location: int = binding.get("location", KEY_LOCATION_UNSPECIFIED)
	var physical: bool = binding.get("physical", false)
	if (modifiers & ~MODIFIER_MASK) != 0:
		return "has unknown modifier bits %d" % modifiers
	match String(kind):
		KIND_KEY:
			if not _is_key_code(code):
				return "has the key code %d, which no key reports" % code
			if location < KEY_LOCATION_UNSPECIFIED or location > KEY_LOCATION_RIGHT:
				return "has the invalid key location %d" % location
			if axis_sign != 0:
				return "is a key with an axis sign"
			return ""
		KIND_MOUSE_BUTTON:
			if code < MOUSE_BUTTON_LEFT or code > MOUSE_BUTTON_XBUTTON2:
				return "has the invalid mouse button %d" % code
		KIND_JOY_BUTTON:
			if code < 0 or code >= JOY_BUTTON_MAX:
				return "has the invalid joypad button %d" % code
		KIND_JOY_AXIS:
			if code < 0 or code >= JOY_AXIS_MAX:
				return "has the invalid joypad axis %d" % code
			if axis_sign != -1 and axis_sign != 1:
				return "has the axis sign %d, not -1 or +1" % axis_sign
			if axis_sign == -1 and (code == JOY_AXIS_TRIGGER_LEFT or code == JOY_AXIS_TRIGGER_RIGHT):
				return "is a trigger with a negative direction"
	if physical or location != KEY_LOCATION_UNSPECIFIED:
		return "is a %s with a key's physical flag or location" % kind
	if String(kind) != KIND_JOY_AXIS and axis_sign != 0:
		return "is a %s with an axis sign" % kind
	if String(kind) != KIND_MOUSE_BUTTON and modifiers != 0:
		return "is a %s with modifiers" % kind
	return ""


## Whether a key can report [param code] (without modifier bits): a printable character
## (control characters and surrogates excluded), or a special key Godot names.
static func _is_key_code(code: int) -> bool:
	if code >= KEY_SPECIAL:
		for named: Vector2i in _SPECIAL_KEY_RANGES:
			if code >= named.x and code <= named.y:
				return true
		return false
	if code < KEY_SPACE or code > _UNICODE_MAX:
		return false
	return not (code >= 0x7F and code <= 0x9F) and not (code >= 0xD800 and code <= 0xDFFF)


## A valid descriptor with every field present and a modifier key's own bit dropped.
static func _normalized(binding: Dictionary) -> Dictionary:
	var kind := String(binding["kind"])
	var code: int = binding["code"]
	var modifiers: int = binding.get("modifiers", 0)
	if kind == KIND_KEY:
		modifiers &= ~int(_SELF_MODIFIER.get(code, 0))
	return {
		"kind": kind,
		"code": code,
		"axis_sign": int(binding.get("axis_sign", 0)),
		"physical": bool(binding.get("physical", false)),
		"modifiers": modifiers,
		"location": int(binding.get("location", KEY_LOCATION_UNSPECIFIED)),
	}


## [method same_input] for two normalized descriptors.
static func _same_input(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty() or a["kind"] != b["kind"] or a["code"] != b["code"]:
		return false
	match String(a["kind"]):
		KIND_KEY:
			var location_a: int = a["location"]
			var location_b: int = b["location"]
			var locations_match := location_a == location_b or location_a == KEY_LOCATION_UNSPECIFIED or location_b == KEY_LOCATION_UNSPECIFIED
			return a["modifiers"] == b["modifiers"] and locations_match
		KIND_MOUSE_BUTTON:
			return a["modifiers"] == b["modifiers"]
		KIND_JOY_AXIS:
			return a["axis_sign"] == b["axis_sign"]
	return true


static func _is_profile(key: Variant) -> bool:
	return (typeof(key) == TYPE_STRING or typeof(key) == TYPE_STRING_NAME) and PROFILES.has(StringName(key))


static func _is_catalog_action(key: Variant) -> bool:
	return (typeof(key) == TYPE_STRING or typeof(key) == TYPE_STRING_NAME) and CATALOG.has(StringName(key))
