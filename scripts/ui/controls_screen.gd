class_name ControlsScreen
extends Node
## Adapter between the Controls screen (Astra's F16-01 layout, spec "Astra screen and layout
## contract") and the rebinding workflow (F16-03). [Interface] creates it in code under the
## Controls root and calls [method setup] once; no scene attaches it.
##
## The two binding tabs edit one draft [InputBindings], a copy of the live profiles taken each
## time the screen is entered. Every edit is an [method InputBindings.assign] transaction on
## the draft, so the draft is always a valid pair of profiles, and nothing reaches the file or
## the [InputMap] before Aplicar hands it to [method Settings.apply_input_bindings]. A change
## to a menu binding then waits ten seconds for Manter controles, on the new bindings, before
## it is kept. The Câmera tab and Ícones do controle are ordinary settings: each edit is stored
## and saved at once, as on the Options screen, and [GameSession] gives the camera values to
## the ship in play at once, under Pause too (F16-06).
##
## The four dialogs are modal. [Interface] offers every input event to
## [method consume_modal_input] before the GUI sees it. The capture dialog consumes all of
## them until its candidate has been reviewed, and every dialog consumes all of them until
## each key and button held when it opened is released, so the press that opened a dialog,
## or a captured key's own release, never acts in it. After that the GUI drives the dialog's
## buttons with the live menu bindings, focus trapped among them, and `ui_cancel` is the
## dialog's cancel. A full-window blocker stops the mouse reaching anything behind it.


## The draft is settled (Descartar, or an Aplicar that was kept) and the player asked to
## leave: [Interface] goes back to the caller.
signal leave_requested

enum _Modal { NONE, CAPTURE, CONFLICT, DIRTY, CONFIRM }
## The capture dialog's steps (spec "Capture, conflicts and recovery").
enum _Capture { WAITING_RELEASE, LISTENING, REVIEW_RELEASE, REVIEWING }

## The binding tabs are named by the profile they edit.
const TAB_KEYBOARD_MOUSE := InputBindings.KEYBOARD_MOUSE
const TAB_GAMEPAD := InputBindings.GAMEPAD
const TAB_CAMERA := &"camera"
## Each tab button, relative to the Controls root, in focus order.
const TAB_PATHS: Dictionary[StringName, NodePath] = {
	TAB_KEYBOARD_MOUSE: ^"Layout/ControlsPanel/Tabs/KeyboardMouse",
	TAB_GAMEPAD: ^"Layout/ControlsPanel/Tabs/Gamepad",
	TAB_CAMERA: ^"Layout/ControlsPanel/Tabs/Camera",
}
## The Câmera tab's widget of each [Settings] key, in focus order.
const CAMERA_WIDGET_PATHS: Dictionary[StringName, NodePath] = {
	Settings.CAMERA_INPUT_MODE: ^"Layout/ControlsPanel/CameraSettings/Mode",
	Settings.MOUSE_SENSITIVITY: ^"Layout/ControlsPanel/CameraSettings/MouseSensitivity",
	Settings.CAMERA_SENSITIVITY: ^"Layout/ControlsPanel/CameraSettings/OrbitSensitivity",
	Settings.MOUSE_INVERT_VERTICAL: ^"Layout/ControlsPanel/CameraSettings/MouseInvert",
	Settings.INVERT_VERTICAL: ^"Layout/ControlsPanel/CameraSettings/OrbitInvert",
	Settings.CAMERA_DEADZONE: ^"Layout/ControlsPanel/CameraSettings/Deadzone",
}
## A capture, and each of its reviews, gives up after this long and changes nothing.
const CAPTURE_MSEC := 10000
## A change to a menu binding reverts after this long without Manter controles.
const CONFIRM_MSEC := 10000
## An axis reads as centred below this pull. It has to be seen centred during a capture
## before it can be captured, so a stick held from the menus, or drifting, never binds.
const AXIS_NEUTRAL := 0.2
## An armed axis past this pull is a deliberate candidate.
const AXIS_DELIBERATE := 0.6
## The largest glyph width on a slot button, in pixels (the files are 64 × 64).
const GLYPH_SIZE := 32
const SAVE_FAILED_TEXT := "Não foi possível salvar os controles."

const _ROW_SCENE: PackedScene = preload("res://scenes/ui/components/binding_row.tscn")
const _SLOT_NAMES: Array[String] = ["Principal", "Alternativo"]
const _NO_AXIS := Vector2i(-1, -1)
const _MODIFIER_KEYS: Array[int] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
const _TAB_HELP: Dictionary[StringName, String] = {
	TAB_KEYBOARD_MOUSE: "Comandos do teclado e do mouse.",
	TAB_GAMEPAD: "Comandos do controle, os mesmos para Xbox e PlayStation.",
	TAB_CAMERA: "Modo, sensibilidade, inversão e zona morta da câmera.",
}
const _CAMERA_TITLE := "AJUSTES DA CÂMERA"


## One catalog action's row, instanced from `binding_row.tscn`.
class _Row:
	extends RefCounted

	var action: StringName
	var root: Control
	var label: Label
	## Principal, then Alternativo.
	var slots: Array[Button] = []
	var reset: Button
	## The category heading right above the row, or null.
	var heading: Label


var _root: Control
var _settings: Settings
## The live profiles, read only: they seed each draft and tell what the draft changed.
var _live: InputBindings
var _adapter: InputBindingAdapter
## False until [method setup] found every widget; the screen then stays inert.
var _bound: bool = false
var _draft := InputBindings.new()
## Whether the draft differs from the live profiles, refreshed by [method _render_rows].
var _dirty: bool = false
var _tab: StringName = TAB_KEYBOARD_MOUSE
var _prompt_family: StringName = &"keyboard_mouse"
var _controller_family: StringName = &"xbox"
## The last content control focused on each tab, where moving down from the tabs returns.
var _last_focus: Dictionary[StringName, Control] = {}
## The outcome of the last operation, shown above the focused control's help until the next.
var _status: String = ""
var _glyphs: Dictionary[StringName, Texture2D] = {}

var _tabs: Dictionary[StringName, Button] = {}
var _device_family: OptionButton
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _rows: Array[_Row] = []
var _column_headings: Control
var _section_title: Label
var _authored_section_title: String = ""
var _action_help: Label
var _authored_help: String = ""
var _camera_settings: Control
var _camera_widgets: Dictionary[StringName, Control] = {}
var _restore_tab: Button
var _apply: Button
var _back: Button
## Astra's tooltip of each slot column, kept to follow the binding's name.
var _slot_tooltips: Array[String] = ["", ""]

var _overlays: Control
var _capture_dialog: Control
var _capture_message: Label
var _capture_cancel: Button
var _capture_use: Button
var _conflict_dialog: Control
var _conflict_message: Label
var _conflict_cancel: Button
var _conflict_swap: Button
var _conflict_replace: Button
var _dirty_dialog: Control
var _dirty_cancel: Button
var _dirty_discard: Button
var _dirty_apply: Button
var _confirm_dialog: Control
var _confirm_message: Label
var _confirm_revert: Button
var _confirm_keep: Button

var _modal: _Modal = _Modal.NONE
## The control that had focus when the first dialog of a chain opened; it gets focus back.
var _modal_return: Control
## True from a dialog's opening until every key and button is released.
var _gated: bool = false
## The capture dialog's or the confirmation's deadline, in [method Time.get_ticks_msec].
var _deadline_msec: int = 0
## The Dirty dialog's Aplicar leaves once the confirmation, if any, is kept.
var _leave_after_confirm: bool = false

var _capture_state: _Capture = _Capture.WAITING_RELEASE
var _capture_row: _Row
var _capture_slot: int = 0
var _candidate: Dictionary = {}
## The device and axis of an axis candidate, or [constant _NO_AXIS].
var _candidate_axis: Vector2i = _NO_AXIS
## A line under the capture prompt, such as a press on the other tab's device.
var _capture_hint: String = ""
## A modifier pressed while listening: bound alone on its release, or as the chord of the
## next key or button.
var _pending_modifier: InputEventKey
## Device and axis -> whether the axis was seen centred during this capture.
var _armed_axes: Dictionary[Vector2i, bool] = {}
## Trigger axes whose backend reports -1 at rest rather than 0.
var _signed_triggers: Dictionary[Vector2i, bool] = {}
## Keys held while the screen is shown: code -> whether it is a physical code.
var _held_keys: Dictionary[int, bool] = {}


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	match _modal:
		_Modal.CAPTURE:
			_tick_capture(now)
		_Modal.CONFIRM:
			if now >= _deadline_msec:
				_revert_bindings(": o tempo acabou")
				return
			_open_gate_once_released()
			_write_confirm_message(now)
		_:
			_open_gate_once_released()


## Losing the window drops the releases of every key held, so a capture could bind a key
## the player let go of elsewhere; an unconfirmed binding change reverts (spec).
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT:
		return
	_held_keys.clear()
	_pending_modifier = null
	if _modal == _Modal.CAPTURE:
		_finish_capture("")
	elif _modal == _Modal.CONFIRM:
		_revert_bindings(": a janela perdeu o foco")


## Binds the widgets under [param root] (Astra's paths, spec "Astra-authored widget paths"),
## once. [param bindings] is the live [InputBindings] of [param settings], read only: drafts
## are copied from it, and only [method Settings.apply_input_bindings] changes it.
## [param adapter] names captured events ([method InputBindingAdapter.describe_event]). A
## missing or mistyped widget is reported with its path and leaves the whole screen inert,
## since its focus loop and dialogs need every one. Astra's `Preview*` rows are replaced by
## one `binding_row.tscn` row per catalog action, under a heading per category.
func setup(root: Control, settings: Settings, bindings: InputBindings, adapter: InputBindingAdapter) -> void:
	if _settings != null:
		push_error("%s: setup was already called; ignored" % get_path())
		return
	# Only an open dialog needs the frame: its deadline and its release gate.
	set_process(false)
	_root = root
	_settings = settings
	_live = bindings
	_adapter = adapter
	if not _find_widgets() or not _build_rows():
		return
	_bind_camera_widgets()
	_connect_controls()
	_settings.changed.connect(_on_settings_changed)
	_root.visibility_changed.connect(_on_root_visibility_changed)
	_bound = true
	_reset_draft()
	_select_tab(TAB_KEYBOARD_MOUSE)


## [Interface]'s prompt families: [param prompt_family] is what the menus show
## (`&"keyboard_mouse"`, `&"xbox"` or `&"playstation"`), [param controller_family] the glyph
## family of the Controle tab, whichever device is in use.
func set_prompt_families(prompt_family: StringName, controller_family: StringName) -> void:
	_prompt_family = prompt_family
	_controller_family = controller_family
	if _bound:
		_render_rows()
		_show_help(_focused())


## Offered every input event by [method Interface._input], before the GUI. True when a
## dialog consumed it, and the caller marks it handled: while listening for a capture, and
## while a dialog waits for the keys and buttons held at its opening to be released. After
## that the dialog's own buttons take the GUI's navigation and presses, and `ui_cancel` is
## the dialog's cancel.
func consume_modal_input(event: InputEvent) -> bool:
	if not _bound:
		return false
	_note_key(event)
	if _modal == _Modal.NONE:
		return false
	if _modal == _Modal.CAPTURE and _capture_state != _Capture.REVIEWING:
		if _clicks(_capture_cancel, event):
			_finish_capture("")
		elif _capture_state == _Capture.LISTENING:
			_listen(event)
		return true
	if _gated:
		return true
	if event.is_action_pressed(&"ui_cancel"):
		_cancel_modal()
		return true
	return false


## Called by [Interface] before it goes back from Controls. True when the screen may be
## left now. With an unapplied draft it opens the Dirty dialog (Aplicar, Descartar,
## Continuar editando) instead and returns false; a settled choice then emits
## [signal leave_requested]. Always false while a dialog is open.
func request_leave() -> bool:
	if not _bound:
		return true
	if _modal != _Modal.NONE:
		return false
	if not _dirty:
		return true
	_open_modal(_Modal.DIRTY, _dirty_dialog, _dirty_cancel)
	_trap_focus([_dirty_cancel, _dirty_discard, _dirty_apply])
	return false


## A controller connected or left ([signal Input.joy_connection_changed], through
## [Interface]). A controller leaving during the confirmation reverts the change (spec).
func note_joypad_connection(connected: bool) -> void:
	if not connected and _modal == _Modal.CONFIRM:
		_revert_bindings(": um controle foi desconectado")


## Resolves every authored widget, reporting each one missing or mistyped. False when any is.
func _find_widgets() -> bool:
	var problems: Array[String] = []
	for tab: StringName in TAB_PATHS:
		_tabs[tab] = _widget(TAB_PATHS[tab], "Button", problems) as Button
	_device_family = _widget(^"Layout/ControlsPanel/DeviceFamily", "OptionButton", problems) as OptionButton
	_scroll = _widget(^"Layout/ControlsPanel/BindingScroll", "ScrollContainer", problems) as ScrollContainer
	_rows_box = _widget(^"Layout/ControlsPanel/BindingScroll/Rows", "VBoxContainer", problems) as VBoxContainer
	_column_headings = _widget(^"Layout/ControlsPanel/ColumnHeadings", "Control", problems)
	_section_title = _widget(^"Layout/ControlsPanel/SectionTitle", "Label", problems) as Label
	_action_help = _widget(^"Layout/ControlsPanel/ActionHelp", "Label", problems) as Label
	_camera_settings = _widget(^"Layout/ControlsPanel/CameraSettings", "Control", problems)
	for key: StringName in CAMERA_WIDGET_PATHS:
		var type := "Range"
		if key == Settings.CAMERA_INPUT_MODE:
			type = "OptionButton"
		elif key == Settings.MOUSE_INVERT_VERTICAL or key == Settings.INVERT_VERTICAL:
			type = "BaseButton"
		_camera_widgets[key] = _widget(CAMERA_WIDGET_PATHS[key], type, problems)
	_restore_tab = _widget(^"Layout/RestoreTabButton", "Button", problems) as Button
	_apply = _widget(^"Layout/ApplyButton", "Button", problems) as Button
	_back = _widget(^"Layout/BackButton", "Button", problems) as Button
	_overlays = _widget(^"Overlays", "Control", problems)
	_capture_dialog = _widget(^"Overlays/CaptureDialog", "Control", problems)
	_capture_message = _widget(^"Overlays/CaptureDialog/Message", "Label", problems) as Label
	_capture_cancel = _widget(^"Overlays/CaptureDialog/Buttons/CancelButton", "Button", problems) as Button
	_capture_use = _widget(^"Overlays/CaptureDialog/Buttons/UseButton", "Button", problems) as Button
	_conflict_dialog = _widget(^"Overlays/ConflictDialog", "Control", problems)
	_conflict_message = _widget(^"Overlays/ConflictDialog/Message", "Label", problems) as Label
	_conflict_cancel = _widget(^"Overlays/ConflictDialog/Buttons/CancelButton", "Button", problems) as Button
	_conflict_swap = _widget(^"Overlays/ConflictDialog/Buttons/SwapButton", "Button", problems) as Button
	_conflict_replace = _widget(^"Overlays/ConflictDialog/Buttons/ReplaceButton", "Button", problems) as Button
	_dirty_dialog = _widget(^"Overlays/DirtyDialog", "Control", problems)
	_dirty_cancel = _widget(^"Overlays/DirtyDialog/Buttons/CancelButton", "Button", problems) as Button
	_dirty_discard = _widget(^"Overlays/DirtyDialog/Buttons/DiscardButton", "Button", problems) as Button
	_dirty_apply = _widget(^"Overlays/DirtyDialog/Buttons/ApplyButton", "Button", problems) as Button
	_confirm_dialog = _widget(^"Overlays/ConfirmBindingsDialog", "Control", problems)
	_confirm_message = _widget(^"Overlays/ConfirmBindingsDialog/Message", "Label", problems) as Label
	_confirm_revert = _widget(^"Overlays/ConfirmBindingsDialog/Buttons/RevertButton", "Button", problems) as Button
	_confirm_keep = _widget(^"Overlays/ConfirmBindingsDialog/Buttons/ConfirmButton", "Button", problems) as Button
	if _device_family != null and _device_family.item_count != Settings.GLYPH_FAMILIES.size():
		problems.append("DeviceFamily has %d items, not %d" % [_device_family.item_count, Settings.GLYPH_FAMILIES.size()])
	var mode := _camera_widgets.get(Settings.CAMERA_INPUT_MODE) as OptionButton
	if mode != null and mode.item_count != Settings.CAMERA_INPUT_MODES.size():
		problems.append("CameraSettings/Mode has %d items, not %d" % [mode.item_count, Settings.CAMERA_INPUT_MODES.size()])
	for problem: String in problems:
		push_error("%s: Controls widget %s; the Controls screen is not bound" % [get_path(), problem])
	return problems.is_empty()


## The node at [param path] under the root when it is a [param type], else null after
## noting the problem.
func _widget(path: NodePath, type: String, problems: Array[String]) -> Control:
	var node := _root.get_node_or_null(path)
	if node != null and node.is_class(type):
		return node as Control
	problems.append("%s/%s is missing or not a %s" % [_root.get_path(), path, type])
	return null


## Fills `BindingScroll/Rows` with a heading per category and a row per catalog action. False,
## after an error, when the row template lacks one of its four nodes.
func _build_rows() -> bool:
	# Rows only ever holds the catalog; authored preview rows show the layout alone.
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	var heading_color := _section_title.get_theme_color(&"font_color")
	for category: StringName in InputBindings.CATEGORIES:
		var heading := Label.new()
		heading.name = "%sHeading" % String(category).to_pascal_case()
		heading.text = InputBindings.CATEGORY_LABELS[category].to_upper()
		heading.add_theme_font_size_override(&"font_size", 16)
		heading.add_theme_color_override(&"font_color", heading_color)
		_rows_box.add_child(heading)
		var first := true
		for action: StringName in InputBindings.get_actions(category):
			var row := _add_row(action)
			if row == null:
				return false
			row.heading = heading if first else null
			first = false
	return true


func _add_row(action: StringName) -> _Row:
	var node := _ROW_SCENE.instantiate() as Control
	node.name = "%sRow" % String(action).to_pascal_case()
	node.set_meta(&"action_id", String(action))
	_rows_box.add_child(node)
	var row := _Row.new()
	row.action = action
	row.root = node
	row.label = node.get_node_or_null(^"ActionLabel") as Label
	var primary := node.get_node_or_null(^"PrimaryButton") as Button
	var secondary := node.get_node_or_null(^"SecondaryButton") as Button
	row.reset = node.get_node_or_null(^"ResetButton") as Button
	if row.label == null or primary == null or secondary == null or row.reset == null:
		push_error("%s: %s lacks ActionLabel, PrimaryButton, SecondaryButton or ResetButton; the Controls screen is not bound" % [get_path(), _ROW_SCENE.resource_path])
		return null
	row.slots = [primary, secondary]
	if _rows.is_empty():
		_slot_tooltips = [primary.tooltip_text, secondary.tooltip_text]
	for slot: int in InputBindings.SLOT_COUNT:
		var button := row.slots[slot]
		button.add_theme_constant_override(&"icon_max_width", GLYPH_SIZE)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(_on_slot_pressed.bind(row, slot))
	row.reset.pressed.connect(_on_reset_pressed.bind(row))
	_rows.append(row)
	return row


## Gives the Câmera tab's sliders the [Settings] ranges (they win over the authored ones),
## shows the stored values, then connects the edits.
func _bind_camera_widgets() -> void:
	_configure_range(Settings.MOUSE_SENSITIVITY, Settings.MOUSE_SENSITIVITY_MIN, Settings.MOUSE_SENSITIVITY_MAX, 0.01)
	_configure_range(Settings.CAMERA_SENSITIVITY, Settings.SENSITIVITY_MIN, Settings.SENSITIVITY_MAX, Settings.SENSITIVITY_STEP)
	_configure_range(Settings.CAMERA_DEADZONE, Settings.DEADZONE_MIN, Settings.DEADZONE_MAX, 0.01)
	for key: StringName in _camera_widgets:
		_write_camera_widget(key)
		var widget := _camera_widgets[key]
		if widget is OptionButton:
			(widget as OptionButton).item_selected.connect(_on_camera_mode_selected)
		elif widget is BaseButton:
			(widget as BaseButton).toggled.connect(_on_camera_toggled.bind(key))
		else:
			(widget as Range).value_changed.connect(_on_camera_range_changed.bind(key))
	_write_device_family()
	_device_family.item_selected.connect(_on_device_family_selected)


func _configure_range(key: StringName, low: float, high: float, step: float) -> void:
	var slider := _camera_widgets[key] as Range
	slider.min_value = low
	slider.max_value = high
	slider.step = step


## Connects the tabs, the footer, the dialogs and every focus change, once.
func _connect_controls() -> void:
	_authored_section_title = _section_title.text
	_authored_help = _action_help.text
	for tab: StringName in _tabs:
		_tabs[tab].toggle_mode = true
		_tabs[tab].pressed.connect(_select_tab.bind(tab))
	_restore_tab.pressed.connect(_on_restore_tab_pressed)
	_apply.pressed.connect(_on_apply_pressed)
	_capture_cancel.pressed.connect(_finish_capture.bind(""))
	_capture_use.pressed.connect(_on_capture_use_pressed)
	_conflict_cancel.pressed.connect(_finish_capture.bind(""))
	_conflict_swap.pressed.connect(_resolve_conflict.bind(InputBindings.RESOLUTION_SWAP))
	_conflict_replace.pressed.connect(_resolve_conflict.bind(InputBindings.RESOLUTION_REPLACE))
	_dirty_cancel.pressed.connect(_close_modal)
	_dirty_discard.pressed.connect(_on_dirty_discard_pressed)
	_dirty_apply.pressed.connect(_on_dirty_apply_pressed)
	_confirm_revert.pressed.connect(_revert_bindings.bind(""))
	_confirm_keep.pressed.connect(_on_confirm_keep_pressed)
	# Only the rows and the footer take focus: the scroll bar never holds it.
	_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	var focusable: Array[Control] = _header_controls()
	for row: _Row in _rows:
		focusable.append_array([row.slots[0], row.slots[1], row.reset])
	focusable.append_array(_camera_widgets.values())
	focusable.append_array([_restore_tab, _apply, _back])
	for control: Control in focusable:
		control.focus_entered.connect(_on_control_focused.bind(control))


## A fresh visit: the draft is the live profiles again, and the tab follows the device in use.
func _enter() -> void:
	_close_modal(false)
	_status = ""
	_last_focus.clear()
	_reset_draft()
	_select_tab(TAB_KEYBOARD_MOUSE if _prompt_family == &"keyboard_mouse" else TAB_GAMEPAD)


func _reset_draft() -> void:
	_draft = InputBindings.new()
	_draft.restore(_live.capture())
	_render_rows()


func _select_tab(tab: StringName) -> void:
	_tab = tab
	for id: StringName in _tabs:
		_tabs[id].set_pressed_no_signal(id == tab)
	var binding_tab := tab != TAB_CAMERA
	_scroll.visible = binding_tab
	_column_headings.visible = binding_tab
	_camera_settings.visible = not binding_tab
	_section_title.text = _authored_section_title if binding_tab else _CAMERA_TITLE
	_render_rows()
	_link_focus()
	_show_help(_focused())


## Refreshes [member _dirty] and Aplicar, then, while the screen is shown, writes every row
## from the draft for the current binding tab and marks the rows the draft changed. A hidden
## screen is written when it is entered.
func _render_rows() -> void:
	_dirty = _draft.capture() != _live.capture()
	_apply.disabled = not _dirty
	if _tab == TAB_CAMERA or not _root.is_visible_in_tree():
		return
	var family := _slot_family()
	for row: _Row in _rows:
		var slots := _draft.get_bindings(_tab, row.action)
		var changed := slots != _live.get_bindings(_tab, row.action)
		row.label.text = ("• " if changed else "") + InputBindings.get_label(row.action)
		row.root.set_meta(&"state", "changed" if changed else "idle")
		for slot: int in InputBindings.SLOT_COUNT:
			_render_slot(row.slots[slot], slots[slot], family, _slot_tooltips[slot])


## A glyph when the family has one and its file exists, otherwise the binding's text.
func _render_slot(button: Button, binding: Dictionary, family: StringName, tooltip: String) -> void:
	var text := MenuController.describe_binding(binding, family)
	var glyph := _glyph(BindingLabels.glyph_id(binding, family))
	button.icon = glyph
	button.text = text if glyph == null else ""
	button.tooltip_text = "%s · %s" % [text, tooltip]


func _glyph(id: StringName) -> Texture2D:
	if id.is_empty():
		return null
	if not _glyphs.has(id):
		var path := BindingLabels.glyph_path(id)
		_glyphs[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _glyphs[id]


## The label family of the current binding tab's slots: text caps for the keyboard, the
## controller family's names and glyphs for the gamepad.
func _slot_family() -> StringName:
	return &"keyboard_mouse" if _tab == TAB_KEYBOARD_MOUSE else _controller_family


func _header_controls() -> Array[Control]:
	var header: Array[Control] = []
	for tab: StringName in TAB_PATHS:
		header.append(_tabs[tab])
	header.append(_device_family)
	return header


## The current tab's focusable content, row by row: a binding row is Principal,
## Alternativo, Redefinir; the Câmera tab is one widget per row.
func _content_rows() -> Array[Array]:
	var grid: Array[Array] = []
	if _tab == TAB_CAMERA:
		for key: StringName in CAMERA_WIDGET_PATHS:
			grid.append([_camera_widgets[key]])
	else:
		for row: _Row in _rows:
			grid.append([row.slots[0], row.slots[1], row.reset])
	return grid


## Links the spec's focus order for the current tab: tabs and Ícones → rows → Restaurar esta
## aba → Aplicar → Voltar, then back to the tabs (`focus_next`, `focus_previous`). Up and
## down move by row, keeping the column, left and right within a row, and the ends of the
## grid lead to the tabs and to the footer. No hidden control is in any link.
func _link_focus() -> void:
	var header := _header_controls()
	var footer: Array[Control] = [_restore_tab, _apply, _back]
	var grid := _content_rows()
	var chain: Array[Control] = header.duplicate()
	for line: Array in grid:
		for control: Control in line:
			chain.append(control)
	chain.append_array(footer)
	for index: int in chain.size():
		_link(chain[index], &"focus_next", chain[(index + 1) % chain.size()])
		_link(chain[index], &"focus_previous", chain[index - 1])
	for index: int in header.size():
		_link(header[index], &"focus_neighbor_left", header[index - 1])
		_link(header[index], &"focus_neighbor_right", header[(index + 1) % header.size()])
		_link(header[index], &"focus_neighbor_top", _back)
	for index: int in footer.size():
		_link(footer[index], &"focus_neighbor_left", footer[maxi(index - 1, 0)])
		_link(footer[index], &"focus_neighbor_right", footer[mini(index + 1, footer.size() - 1)])
		_link(footer[index], &"focus_neighbor_bottom", _tabs[_tab])
	for row_index: int in grid.size():
		var line: Array = grid[row_index]
		for column: int in line.size():
			var control: Control = line[column]
			_link(control, &"focus_neighbor_left", line[maxi(column - 1, 0)])
			_link(control, &"focus_neighbor_right", line[mini(column + 1, line.size() - 1)])
			var above: Control = _tabs[_tab] if row_index == 0 else _cell(grid[row_index - 1], column)
			var below: Control = _restore_tab if row_index == grid.size() - 1 else _cell(grid[row_index + 1], column)
			_link(control, &"focus_neighbor_top", above)
			_link(control, &"focus_neighbor_bottom", below)
	_link_entries(grid)


## Moving down from the tabs, or up from the footer, enters the content at the tab's last
## focused control, or at its first (from the tabs) or last row (from the footer).
func _link_entries(grid: Array[Array]) -> void:
	if grid.is_empty():
		return
	var remembered: Control = _last_focus.get(_tab)
	var known := false
	for line: Array in grid:
		known = known or line.has(remembered)
	var from_top: Control = remembered if known else grid[0][0]
	var from_bottom: Control = remembered if known else grid[-1][0]
	for control: Control in _header_controls():
		_link(control, &"focus_neighbor_bottom", from_top)
	for control: Control in [_restore_tab, _apply, _back]:
		_link(control, &"focus_neighbor_top", from_bottom)


static func _link(control: Control, property: StringName, target: Control) -> void:
	control.set(property, control.get_path_to(target))


static func _cell(line: Array, column: int) -> Control:
	return line[mini(column, line.size() - 1)]


func _focused() -> Control:
	var control := _root.get_viewport().gui_get_focus_owner()
	return control if control != null and _root.is_ancestor_of(control) else null


func _on_control_focused(control: Control) -> void:
	for line: Array in _content_rows():
		if line.has(control):
			_last_focus[_tab] = control
			_link_entries(_content_rows())
			_scroll_to(control)
			break
	_show_help(control)


## Keeps a focused row inside the scroll area, with its category heading when it is the
## category's first row.
func _scroll_to(control: Control) -> void:
	if _tab == TAB_CAMERA:
		return
	for row: _Row in _rows:
		if row.heading != null and (row.slots.has(control) or row.reset == control):
			_scroll.ensure_control_visible(row.heading)
	_scroll.ensure_control_visible(control)


## ActionHelp: the last operation's outcome (or the unapplied-draft note) above the help of
## [param control].
func _show_help(control: Control) -> void:
	var status := _status
	if status.is_empty() and _dirty:
		status = "Há alterações não aplicadas."
	var help := _help_for(control)
	_action_help.text = help if status.is_empty() else "%s\n%s" % [status, help]


func _help_for(control: Control) -> String:
	if control == null:
		return _authored_help
	for tab: StringName in _tabs:
		if control == _tabs[tab]:
			return _TAB_HELP[tab]
	if control == _device_family:
		return "Ícones do controle. Automático segue o último controle usado."
	if control == _restore_tab:
		return "Restaura os padrões da câmera." if _tab == TAB_CAMERA else "Restaura os padrões desta aba; aplique para salvar."
	if control == _apply:
		return "Aplica e salva os comandos alterados."
	for key: StringName in _camera_widgets:
		if control == _camera_widgets[key]:
			return _camera_help(key)
	for row: _Row in _rows:
		for slot: int in InputBindings.SLOT_COUNT:
			if control == row.slots[slot]:
				return _slot_help(row, slot)
		if control == row.reset:
			return _reset_help(row)
	return _authored_help


func _slot_help(row: _Row, slot: int) -> String:
	var binding: Dictionary = _draft.get_bindings(_tab, row.action)[slot]
	var text := "%s · %s: %s" % [InputBindings.get_label(row.action), _SLOT_NAMES[slot], MenuController.describe_binding(binding, _slot_family())]
	if InputBindings.is_required(row.action):
		text += " · obrigatória"
	return "%s.     %s  Alterar" % [text, MenuController.prompt_for(&"ui_accept", _prompt_family, _live)]


func _reset_help(row: _Row) -> String:
	var names := PackedStringArray()
	for binding: Dictionary in InputBindings.get_default_bindings(_tab, row.action):
		if not binding.is_empty():
			names.append(MenuController.describe_binding(binding, _slot_family()))
	return "Restaurar o padrão de %s: %s." % [InputBindings.get_label(row.action), " / ".join(names) if not names.is_empty() else BindingLabels.UNBOUND]


func _camera_help(key: StringName) -> String:
	match key:
		Settings.CAMERA_INPUT_MODE:
			return "Teclas: as teclas e o analógico giram a câmera. Mouse: o mouse também gira a câmera durante o jogo."
		Settings.MOUSE_SENSITIVITY:
			return "Sensibilidade do mouse: %s grau por pixel." % _decimal(_settings.get_mouse_sensitivity())
		Settings.CAMERA_SENSITIVITY:
			return "Sensibilidade das teclas e do controle: %s." % _decimal(_settings.get_camera_sensitivity())
		Settings.MOUSE_INVERT_VERTICAL:
			return "Inverte o eixo vertical da câmera no mouse."
		Settings.INVERT_VERTICAL:
			return "Inverte o eixo vertical da câmera nas teclas e no controle."
	return "Zona morta do analógico da câmera: %s." % _decimal(_settings.get_camera_deadzone())


static func _decimal(value: float) -> String:
	return ("%.2f" % value).replace(".", ",")


func _on_root_visibility_changed() -> void:
	if _root.visible:
		_enter()
		return
	# Leaving never keeps an unconfirmed change: only Manter controles does.
	if _modal == _Modal.CONFIRM:
		_revert_bindings("")
	_close_modal(false)
	_held_keys.clear()


func _on_settings_changed(key: StringName, _value: Variant) -> void:
	if _camera_widgets.has(key):
		_write_camera_widget(key)
	elif key == Settings.CONTROLLER_GLYPH_FAMILY:
		_write_device_family()
	elif key != Settings.BINDING_PROFILES:
		return
	_render_rows()
	_show_help(_focused())


func _write_camera_widget(key: StringName) -> void:
	var widget := _camera_widgets[key]
	var value: Variant = _settings.get_value(key)
	if widget is OptionButton:
		(widget as OptionButton).select(Settings.CAMERA_INPUT_MODES.find(value))
	elif widget is BaseButton:
		(widget as BaseButton).set_pressed_no_signal(value)
	else:
		(widget as Range).set_value_no_signal(value)


func _write_device_family() -> void:
	_device_family.select(Settings.GLYPH_FAMILIES.find(_settings.get_controller_glyph_family()))


func _on_camera_mode_selected(index: int) -> void:
	if index >= 0 and index < Settings.CAMERA_INPUT_MODES.size():
		_commit(Settings.CAMERA_INPUT_MODE, Settings.CAMERA_INPUT_MODES[index])


func _on_camera_toggled(pressed: bool, key: StringName) -> void:
	_commit(key, pressed)


func _on_camera_range_changed(value: float, key: StringName) -> void:
	_commit(key, value)


func _on_device_family_selected(index: int) -> void:
	if index >= 0 and index < Settings.GLYPH_FAMILIES.size():
		_commit(Settings.CONTROLLER_GLYPH_FAMILY, Settings.GLYPH_FAMILIES[index])


## A settings edit: stored and saved at once, as on the Options screen. [signal
## Settings.changed] rewrites the widget and [Interface] applies the glyph family; the widget
## is rewritten here too when sanitising left the stored value as it was.
func _commit(key: StringName, value: Variant) -> void:
	if _settings.set_value(key, value):
		_save()
	elif key == Settings.CONTROLLER_GLYPH_FAMILY:
		_write_device_family()
	else:
		_write_camera_widget(key)
	_show_help(_focused())


func _save() -> void:
	var error := _settings.save_file()
	if error != OK:
		push_warning("%s: settings could not be saved to '%s' (%s); play goes on" % [get_path(), _settings.get_file_path(), error_string(error)])
		_status = SAVE_FAILED_TEXT


## Restaurar esta aba: a binding tab's profile defaults go into the draft; the Câmera tab's
## values are restored and saved at once.
func _on_restore_tab_pressed() -> void:
	if _tab == TAB_CAMERA:
		_status = "Padrões da câmera restaurados."
		var changed := false
		for key: StringName in _camera_widgets:
			changed = _settings.set_value(key, Settings.DEFAULTS[key]) or changed
		if changed:
			_save()
	else:
		_draft.restore_profile_defaults(_tab)
		_status = "Padrões desta aba restaurados. Aplique para salvar."
	_render_rows()
	_show_help(_restore_tab)


## Redefinir: the row's default slots go into the draft, unless another action now holds
## one of them (the core refuses it then; the help names the holder).
func _on_reset_pressed(row: _Row) -> void:
	_status = ""
	if not _draft.restore_action_defaults(_tab, row.action).is_empty():
		_status = "Não foi possível restaurar %s." % InputBindings.get_label(row.action)
		for binding: Dictionary in InputBindings.get_default_bindings(_tab, row.action):
			var holders := _draft.find_conflicts(_tab, row.action, binding)
			if not holders.is_empty():
				_status = "Não foi possível restaurar %s: %s está em %s." % [
					InputBindings.get_label(row.action), MenuController.describe_binding(binding, _slot_family()), InputBindings.get_label(holders[0]),
				]
				break
	_render_rows()
	_show_help(row.reset)


func _on_apply_pressed() -> void:
	_apply_draft()


## Aplicar: validates and saves the draft through [method Settings.apply_input_bindings],
## which makes it live only after the save; a changed menu binding asks for the
## confirmation. True when the draft is live now, confirmed or waiting for Manter
## controles; false, with the draft and the live map kept, when the save failed.
func _apply_draft() -> bool:
	if not _dirty:
		return true
	var confirm := _menu_bindings_changed()
	var error := _settings.apply_input_bindings(_draft, confirm)
	if error != OK:
		if error == ERR_INVALID_DATA:
			# Every edit is a validated transaction, so an invalid draft is a programming error.
			for profile: StringName in InputBindings.PROFILES:
				for message: String in _draft.validate_profile(profile):
					push_error("%s: %s" % [get_path(), message])
		else:
			push_warning("%s: the controls could not be saved to '%s' (%s); the live controls are kept" % [get_path(), _settings.get_file_path(), error_string(error)])
		_status = SAVE_FAILED_TEXT
		_render_rows()
		_show_help(_focused())
		return false
	_status = "Controles aplicados."
	_render_rows()
	if confirm:
		_deadline_msec = Time.get_ticks_msec() + CONFIRM_MSEC
		_open_modal(_Modal.CONFIRM, _confirm_dialog, _confirm_revert)
		_trap_focus([_confirm_revert, _confirm_keep])
		_write_confirm_message(Time.get_ticks_msec())
	else:
		_show_help(_focused())
	return true


## Whether the draft changes an action read by the menus (`pause` and the `ui_*` actions),
## in either profile: those are the ones that could lock the player out of the menus.
func _menu_bindings_changed() -> bool:
	for profile: StringName in InputBindings.PROFILES:
		for action: StringName in InputBindings.CATALOG:
			if (InputBindings.get_contexts(action) & InputBindings.CONTEXT_MENU) == 0:
				continue
			if _draft.get_bindings(profile, action) != _live.get_bindings(profile, action):
				return true
	return false


## Focus starts on Reverter, so keeping the change proves the new bindings can move focus
## and confirm.
func _write_confirm_message(now: int) -> void:
	var seconds := ceili(maxi(_deadline_msec - now, 0) / 1000.0)
	_set_text(_confirm_message, "Os novos comandos já estão valendo. Mantê-los?\nReversão automática em %d s." % seconds)


func _on_confirm_keep_pressed() -> void:
	var error := _settings.confirm_input_bindings()
	if error == OK:
		_status = "Controles aplicados."
	else:
		# The change stays live; the file's marker brings the previous one back at the next boot.
		push_warning("%s: the confirmed controls could not be saved to '%s' (%s)" % [get_path(), _settings.get_file_path(), error_string(error)])
		_status = SAVE_FAILED_TEXT
	var leave := _leave_after_confirm and error == OK
	_leave_after_confirm = false
	_close_modal()
	_render_rows()
	_show_help(_focused())
	if leave:
		_emit_leave_requested.call_deferred()


## Reverter, the timeout, a controller leaving or the window losing focus: the confirmed
## profiles are live again at once. The draft keeps the reverted change, so it can be fixed
## and applied again.
func _revert_bindings(reason: String) -> void:
	var error := _settings.revert_input_bindings()
	if error != OK:
		# The previous controls are live; the file's marker brings them back at boot too.
		push_warning("%s: the reverted controls could not be saved to '%s' (%s)" % [get_path(), _settings.get_file_path(), error_string(error)])
	_status = "Controles revertidos%s." % reason
	_leave_after_confirm = false
	_close_modal()
	_render_rows()
	_show_help(_focused())


func _on_dirty_discard_pressed() -> void:
	_reset_draft()
	_close_modal()
	_emit_leave_requested.call_deferred()


func _on_dirty_apply_pressed() -> void:
	_leave_after_confirm = true
	if not _apply_draft():
		_leave_after_confirm = false
		_close_modal()
		return
	if _modal == _Modal.CONFIRM:
		return
	_leave_after_confirm = false
	_close_modal()
	_emit_leave_requested.call_deferred()


## Deferred, so the screen is not left in the middle of the button press that settled it.
func _emit_leave_requested() -> void:
	leave_requested.emit()


## Starts a capture for [param slot] of [param row] in the current binding tab.
func _on_slot_pressed(row: _Row, slot: int) -> void:
	if _modal != _Modal.NONE:
		return
	_capture_row = row
	_capture_slot = slot
	_capture_state = _Capture.WAITING_RELEASE
	_candidate = {}
	_candidate_axis = _NO_AXIS
	_capture_hint = ""
	_pending_modifier = null
	_armed_axes.clear()
	_deadline_msec = Time.get_ticks_msec() + CAPTURE_MSEC
	_capture_use.hide()
	_open_modal(_Modal.CAPTURE, _capture_dialog, _capture_cancel)
	_trap_focus([_capture_cancel])
	_write_capture_message(Time.get_ticks_msec())


func _tick_capture(now: int) -> void:
	if now >= _deadline_msec:
		_finish_capture("O tempo acabou; nada mudou.")
		return
	if _capture_state == _Capture.WAITING_RELEASE and _nothing_held():
		_arm_axes()
		_capture_state = _Capture.LISTENING
	elif _capture_state == _Capture.REVIEW_RELEASE and _nothing_held() and _candidate_axis_centred():
		# Only now may the old menu bindings confirm or cancel: the candidate's own release is past.
		_capture_state = _Capture.REVIEWING
		_deadline_msec = now + CAPTURE_MSEC
		_capture_use.show()
		_trap_focus([_capture_cancel, _capture_use])
		_capture_use.grab_focus()
	_write_capture_message(now)


func _write_capture_message(now: int) -> void:
	var target := "%s · %s" % [InputBindings.get_label(_capture_row.action), _SLOT_NAMES[_capture_slot]]
	var candidate := "Novo comando: %s" % MenuController.describe_binding(_candidate, _slot_family())
	var seconds := ceili(maxi(_deadline_msec - now, 0) / 1000.0)
	var step := ""
	var countdown := "Tempo restante: %d s" % seconds
	match _capture_state:
		_Capture.WAITING_RELEASE:
			step = "Solte todas as teclas e botões."
		_Capture.LISTENING:
			step = _capture_hint if not _capture_hint.is_empty() else "Pressione a nova tecla ou botão."
		_Capture.REVIEW_RELEASE:
			step = candidate
			countdown = "Solte para continuar · %d s" % seconds
		_Capture.REVIEWING:
			step = candidate
			countdown = "Usar este comando? · %d s" % seconds
	_set_text(_capture_message, "%s\n%s\n%s" % [target, step, countdown])


## Arms each axis of each connected pad that reads centred now; the others arm once they
## are seen centred.
func _arm_axes() -> void:
	_armed_axes.clear()
	for device: int in Input.get_connected_joypads():
		for axis: int in int(JOY_AXIS_SDL_MAX):
			var id := Vector2i(device, axis)
			_armed_axes[id] = absf(_axis_pull(id, Input.get_joy_axis(device, axis as JoyAxis))) < AXIS_NEUTRAL


## One listening event: a deliberate press becomes the candidate for review. Echoes,
## releases, [InputEventAction], mouse motion and undeliberate axis motion are dropped. A
## press of the other tab's device is refused, except that device's `ui_cancel`, which
## cancels: it can never be this tab's candidate.
func _listen(event: InputEvent) -> void:
	var binding := _candidate_from(event)
	if binding.is_empty():
		return
	if InputBindings.profile_for(binding) != _tab:
		# A refused axis is no candidate: the review must not wait for that stick to centre.
		_candidate_axis = _NO_AXIS
		if event.is_action_pressed(&"ui_cancel"):
			_finish_capture("")
		else:
			_capture_hint = "Esta aba só aceita o controle." if _tab == TAB_GAMEPAD else "Esta aba só aceita teclado e mouse."
		return
	_candidate = binding
	_capture_hint = ""
	_capture_state = _Capture.REVIEW_RELEASE


## The descriptor [param event] proposes, or an empty Dictionary. A modifier pressed alone
## waits: the next key or button takes it as a chord (Shift+Tab), and its own release
## without one makes it the binding (Left Shift). An axis proposes only past
## [constant AXIS_DELIBERATE] after it was seen centred, with its direction.
func _candidate_from(event: InputEvent) -> Dictionary:
	var action := _capture_row.action
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.echo:
			return {}
		if _MODIFIER_KEYS.has(key.keycode):
			if key.pressed:
				_pending_modifier = key
				return {}
			if _pending_modifier == null or _pending_modifier.keycode != key.keycode or _pending_modifier.location != key.location:
				return {}
			key = _pending_modifier
		elif not key.pressed:
			return {}
		_pending_modifier = null
		return _adapter.describe_event(key, action)
	if event is InputEventMouseButton or event is InputEventJoypadButton:
		if not event.is_pressed():
			return {}
		_pending_modifier = null
		return _adapter.describe_event(event, action)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var id := Vector2i(motion.device, motion.axis)
		var pull := _axis_pull(id, motion.axis_value)
		if absf(pull) < AXIS_NEUTRAL:
			_armed_axes[id] = true
			return {}
		if absf(pull) <= AXIS_DELIBERATE or not _armed_axes.get(id, false):
			return {}
		_armed_axes[id] = false
		_candidate_axis = id
		return InputBindings.parse_binding(InputBindings.joy_axis_binding(motion.axis, 1 if pull > 0.0 else -1))
	return {}


## A stick's value as reported; a trigger's pull from 0 to 1. Godot reports triggers from 0
## to 1, but a backend that reports -1 at rest is recognised by its first reading below the
## neutral band, and rescaled.
func _axis_pull(id: Vector2i, value: float) -> float:
	if id.y != JOY_AXIS_TRIGGER_LEFT and id.y != JOY_AXIS_TRIGGER_RIGHT:
		return value
	if value < -AXIS_NEUTRAL:
		_signed_triggers[id] = true
	return (value + 1.0) * 0.5 if _signed_triggers.has(id) else maxf(value, 0.0)


func _candidate_axis_centred() -> bool:
	if _candidate_axis == _NO_AXIS:
		return true
	var value := Input.get_joy_axis(_candidate_axis.x, _candidate_axis.y as JoyAxis)
	return absf(_axis_pull(_candidate_axis, value)) < AXIS_NEUTRAL


## Usar: a candidate that conflicts with nothing goes into the draft; one that does asks
## Trocar, Substituir or Cancelar.
func _on_capture_use_pressed() -> void:
	var conflicts := _candidate_conflicts()
	if not conflicts.is_empty():
		_open_conflict(conflicts)
		return
	var refused := not _try_assign(InputBindings.RESOLUTION_NONE, true).is_empty()
	_finish_capture(_refusal_text() if refused else "")


## The actions of the draft that hold the candidate: the core's conflicts, plus the ones
## only the active keyboard layout reveals.
func _candidate_conflicts() -> Array[StringName]:
	var conflicts := _draft.find_conflicts(_tab, _capture_row.action, _candidate)
	for other: StringName in _layout_conflicts(_capture_row.action, _candidate):
		if not conflicts.has(other):
			conflicts.append(other)
	return conflicts


## F16-02's known limit: `pause` takes physical keys and the menu-only actions layout keys,
## and [InputBindings] compares the two by code, which is exact for the special keys and on
## US QWERTY only. Here a character key is compared in the active layout's space too
## ([method DisplayServer.keyboard_get_keycode_from_physical]), so AZERTY's physical Q on
## `pause` meets layout A on `ui_accept`. Returns the actions the core does not already
## report. (The core's own same-code matches stay: they are conservative, never unsafe.)
func _layout_conflicts(action: StringName, binding: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	if _tab != TAB_KEYBOARD_MOUSE or binding["kind"] != InputBindings.KIND_KEY or int(binding["code"]) >= KEY_SPECIAL:
		return result
	var code := _layout_code(binding)
	for other: StringName in InputBindings.CATALOG:
		if other == action or InputBindings.can_share(action, other):
			continue
		if InputBindings.uses_physical_keys(other) == InputBindings.uses_physical_keys(action):
			continue
		for bound: Dictionary in _draft.get_bindings(_tab, other):
			if _same_layout_key(bound, binding, code):
				result.append(other)
				break
	return result


static func _same_layout_key(bound: Dictionary, binding: Dictionary, code: int) -> bool:
	if bound.is_empty() or bound["kind"] != InputBindings.KIND_KEY or bound["modifiers"] != binding["modifiers"]:
		return false
	return _layout_code(bound) == code and not InputBindings.same_input(bound, binding)


## The keycode [param binding] types on the active layout. The headless display server has no
## layout, so there a physical code is its own keycode.
static func _layout_code(binding: Dictionary) -> int:
	var code: int = binding["code"]
	if not binding["physical"] or DisplayServer.get_name() == "headless":
		return code
	return int(DisplayServer.keyboard_get_keycode_from_physical(code as Key))


## Assigns the candidate on a copy of the draft with [param resolution], and makes the copy
## the draft when it succeeded and [param commit]. Returns the refusal reasons; empty when it
## succeeded. A conflict only the layout reveals ([method _layout_conflicts]) can only be
## replaced: the matching slots are cleared first, which fails for a required action's last
## binding.
func _try_assign(resolution: StringName, commit: bool) -> PackedStringArray:
	var trial := InputBindings.new()
	trial.restore(_draft.capture())
	var errors := PackedStringArray()
	var layout_only := _layout_conflicts(_capture_row.action, _candidate)
	if not layout_only.is_empty() and resolution != InputBindings.RESOLUTION_REPLACE:
		errors.append("ControlsScreen: the binding shares a key with %s on the active layout" % ", ".join(PackedStringArray(layout_only)))
		return errors
	var code := _layout_code(_candidate) if not layout_only.is_empty() else 0
	for other: StringName in layout_only:
		var slots := trial.get_bindings(_tab, other)
		for slot: int in range(slots.size() - 1, -1, -1):
			if _same_layout_key(slots[slot], _candidate, code):
				errors.append_array(trial.assign(_tab, other, slot, {}))
	if errors.is_empty():
		errors = trial.assign(_tab, _capture_row.action, _capture_slot, _candidate, resolution)
	if errors.is_empty() and commit:
		_draft = trial
	return errors


## The Portuguese reason a conflict-free candidate was refused.
func _refusal_text() -> String:
	var own: Array[Dictionary] = _draft.get_bindings(_tab, _capture_row.action)
	own.append_array(InputBindings.get_fixed_bindings(_tab, _capture_row.action))
	for binding: Dictionary in own:
		if InputBindings.same_input(binding, _candidate):
			return "%s já está em %s." % [MenuController.describe_binding(_candidate, _slot_family()), InputBindings.get_label(_capture_row.action)]
	return "Não foi possível usar este comando."


func _open_conflict(conflicts: Array[StringName]) -> void:
	var labels := PackedStringArray()
	for action: StringName in conflicts:
		labels.append(InputBindings.get_label(action))
	var can_swap := _try_assign(InputBindings.RESOLUTION_SWAP, false).is_empty()
	var replace_errors := _try_assign(InputBindings.RESOLUTION_REPLACE, false)
	var can_replace := replace_errors.is_empty()
	_set_enabled(_conflict_swap, can_swap)
	_set_enabled(_conflict_replace, can_replace)
	var text := "%s já está em %s.\nTrocar os comandos, substituir ou cancelar?" % [MenuController.describe_binding(_candidate, _slot_family()), ", ".join(labels)]
	if not can_replace:
		text += "\n" + _replace_refusal_text(conflicts, replace_errors)
	_conflict_message.text = text
	_open_modal(_Modal.CONFLICT, _conflict_dialog, _conflict_swap if can_swap else _conflict_cancel)
	_trap_focus([_conflict_cancel, _conflict_swap, _conflict_replace])


## The Portuguese reason Substituir is disabled for [param conflicts], from the trial's
## [param errors]: the candidate is fixed on one of them (Numpad Enter on `ui_accept`), a
## required action would lose its last binding, or another refusal.
func _replace_refusal_text(conflicts: Array[StringName], errors: PackedStringArray) -> String:
	for other: StringName in conflicts:
		for fixed: Dictionary in InputBindings.get_fixed_bindings(_tab, other):
			if InputBindings.same_input(fixed, _candidate):
				return "Substituir não é possível: este comando é fixo em %s." % InputBindings.get_label(other)
	for error: String in errors:
		if error.contains("is required but has no binding"):
			return "Substituir deixaria uma ação obrigatória sem comando."
	return "Substituir não é possível para este comando."


func _resolve_conflict(resolution: StringName) -> void:
	var refused := not _try_assign(resolution, true).is_empty()
	_finish_capture("Não foi possível usar este comando." if refused else "")


## Ends a capture, a review or a conflict, with [param status] as the outcome ("" when it
## just closed), and gives focus back to the slot that started it.
func _finish_capture(status: String) -> void:
	_status = status
	_pending_modifier = null
	_close_modal()
	_render_rows()
	_show_help(_focused())


func _cancel_modal() -> void:
	match _modal:
		_Modal.CAPTURE, _Modal.CONFLICT:
			_finish_capture("")
		_Modal.DIRTY:
			_close_modal()
		_Modal.CONFIRM:
			_revert_bindings("")


## Shows [param dialog] alone, blocks the mouse behind it, and focuses [param focus]. The
## first dialog of a chain remembers the control to give focus back to.
func _open_modal(kind: _Modal, dialog: Control, focus: Button) -> void:
	if _modal == _Modal.NONE:
		_modal_return = _focused()
	for each: Control in [_capture_dialog, _conflict_dialog, _dirty_dialog, _confirm_dialog]:
		each.visible = each == dialog
	_overlays.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal = kind
	_gated = kind != _Modal.CAPTURE
	set_process(true)
	focus.grab_focus()


## Hides every dialog and, when [param restore_focus] and the screen is shown, gives focus
## back to the control that opened the first one (the current tab when it is gone).
func _close_modal(restore_focus: bool = true) -> void:
	for each: Control in [_capture_dialog, _conflict_dialog, _dirty_dialog, _confirm_dialog]:
		each.hide()
	_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal = _Modal.NONE
	_gated = false
	set_process(false)
	var target := _modal_return
	_modal_return = null
	if not restore_focus or not _root.is_visible_in_tree():
		return
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		target = _tabs[_tab]
	target.grab_focus()


## Traps focus among the shown, enabled [param buttons]: Tab, Shift+Tab and left/right
## cycle them, up and down stay put.
func _trap_focus(buttons: Array[Button]) -> void:
	var loop: Array[Button] = []
	for button: Button in buttons:
		if button.visible and not button.disabled:
			loop.append(button)
	for index: int in loop.size():
		var button := loop[index]
		_link(button, &"focus_next", loop[(index + 1) % loop.size()])
		_link(button, &"focus_previous", loop[index - 1])
		_link(button, &"focus_neighbor_right", loop[(index + 1) % loop.size()])
		_link(button, &"focus_neighbor_left", loop[index - 1])
		_link(button, &"focus_neighbor_top", button)
		_link(button, &"focus_neighbor_bottom", button)


## A disabled dialog button cannot take focus either, so nothing lands on it.
static func _set_enabled(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _open_gate_once_released() -> void:
	if _gated and _nothing_held():
		_gated = false


## Whether no key, mouse button or joypad button is held. Sticks and triggers are left to
## the capture's own axis rules.
func _nothing_held() -> bool:
	if Input.get_mouse_button_mask() != 0:
		return false
	for code: int in _held_keys.keys():
		var held := Input.is_physical_key_pressed(code as Key) if _held_keys[code] else Input.is_key_pressed(code as Key)
		if held:
			return false
		_held_keys.erase(code)
	for device: int in Input.get_connected_joypads():
		for button: int in int(JOY_BUTTON_SDL_MAX):
			if Input.is_joy_button_pressed(device, button as JoyButton):
				return false
	return true


## Tracks the keys held while the screen is shown, since [Input] cannot list them.
func _note_key(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo or not _root.is_visible_in_tree():
		return
	var physical := key.physical_keycode != KEY_NONE
	var code: int = key.physical_keycode if physical else key.keycode
	if key.pressed:
		_held_keys[code] = physical
	else:
		_held_keys.erase(code)


## Whether [param event] is a left click on [param button].
static func _clicks(button: Control, event: InputEvent) -> bool:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT or not button.is_visible_in_tree():
		return false
	var local := button.make_input_local(click) as InputEventMouseButton
	return Rect2(Vector2.ZERO, button.size).has_point(local.position)


## Writes [param text] only when it changed, so a per-frame countdown does not relayout.
static func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text
