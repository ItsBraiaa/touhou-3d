class_name ScreenRouter
extends RefCounted
## Rules Core for menu navigation: which screen is shown, which overlays sit above
## gameplay, where Back returns to, and which control had focus on each screen, so the
## [Interface] adapter only has to show, hide and focus.
##
## Node-free (ADR-0001). Everything shown is one stack of entries, bottom to top. A
## full screen covers every entry below it; an overlay leaves the entries below it
## visible. [method replace] and [method push] add an entry, [method back] removes the
## top one, and [method home] starts a new stack. So Options opened from Pause covers
## both the HUD and Pause, and Back uncovers them with the game still paused.
## Transitions are reported through [signal screen_hidden] and [signal screen_shown].


## [param id] stopped being visible: covered by a full screen, removed by
## [method back], or cleared by [method home]. Within one transition every hide comes
## before any show, top of the stack first.
signal screen_hidden(id: StringName)
## [param id] became visible, bottom of the stack first, with the params it was opened
## with, which Back passes again when it uncovers the screen. A screen that stays
## visible through a transition, such as the HUD under a new overlay, is not shown again.
signal screen_shown(id: StringName, params: Dictionary)

const MAIN_MENU := &"main_menu"
const STAGE_SELECT := &"stage_select"
const OPTIONS := &"options"
const CONTROLS := &"controls"
const CREDITS := &"credits"
const HUD := &"hud"
const PAUSE := &"pause"
const DEFEAT := &"defeat"
const RESULTS := &"results"

## Screens that cover everything below them. Opened with [method home] or, except the
## HUD, with [method replace].
const FULL_SCREENS: Array[StringName] = [MAIN_MENU, STAGE_SELECT, OPTIONS, CONTROLS, CREDITS, HUD]
## Screens drawn above the current one without hiding it. Opened with [method push].
const OVERLAYS: Array[StringName] = [PAUSE, DEFEAT, RESULTS]
## Outcomes the player did not open and cannot go back from: GUIDE Section 14 gives
## them no Back row, and the gameplay under them has ended.
const _OUTCOMES: Array[StringName] = [DEFEAT, RESULTS]


## One screen on the stack. The focus lives here, so it is forgotten with the entry.
class _Entry:
	extends RefCounted

	var id: StringName
	var params: Dictionary
	var focus: NodePath

	func _init(p_id: StringName, p_params: Dictionary) -> void:
		id = p_id
		params = p_params


var _stack: Array[_Entry] = []


## Clears the history, the overlays and every remembered focus, and shows the full
## screen [param id]. Used when entering the main menu and when starting an Attempt on
## the HUD. [param id] is shown anew even when it was already visible.
func home(id: StringName) -> void:
	assert(id in FULL_SCREENS, "home() takes a full screen, got %s" % id)
	var before := _visible_entries()
	_stack = [_Entry.new(id, {})]
	_announce(before)


## Shows the full screen [param id] over the current stack, which [method back] returns
## to: Options from the main menu returns to the main menu, Credits from Results to
## Results, Options from Pause to Pause. [param params] reach [signal screen_shown] as
## given, now and whenever Back uncovers [param id] again; the router does not copy them.
## Not for the HUD, which only [method home] opens: a HUD above the menus' history would
## let Back leave a running stage for the menu.
func replace(id: StringName, params: Dictionary = {}) -> void:
	assert(id in FULL_SCREENS and id != HUD, "replace() takes a full screen other than the HUD, got %s" % id)
	var before := _visible_entries()
	_stack.append(_Entry.new(id, params))
	_announce(before)


## Shows the overlay [param id] above the current stack, which stays visible under it.
## [param params] are handled as in [method replace].
func push(id: StringName, params: Dictionary = {}) -> void:
	assert(id in OVERLAYS, "push() takes an overlay, got %s" % id)
	var before := _visible_entries()
	_stack.append(_Entry.new(id, params))
	_announce(before)


## Removes the top entry and uncovers what it covered. Back from Pause removes Pause,
## leaving the HUD. Returns false, and emits nothing, when there is nothing to return
## to: a single screen on the stack, or Defeat or Results on top.
func back() -> bool:
	if _stack.size() < 2 or current() in _OUTCOMES:
		return false
	var before := _visible_entries()
	_stack.pop_back()
	_announce(before)
	return true


## The top of the stack, which is what has focus. Empty before the first [method home].
func current() -> StringName:
	return _stack[-1].id if not _stack.is_empty() else &""


## The screens visible now, bottom to top: the topmost full screen and every overlay
## above it.
func visible_stack() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: _Entry in _visible_entries():
		ids.append(entry.id)
	return ids


## Whether the overlay [param id] is on the stack, visible or covered by a full screen.
## Pause stays on the stack while Options is open from it.
func has_overlay(id: StringName) -> bool:
	return _on_stack(id)


## Whether anything is shown over running gameplay: an overlay, or a full screen above
## the HUD. False without the HUD on the stack, because then there is no Run to cover.
func is_gameplay_covered() -> bool:
	return _on_stack(HUD) and current() != HUD


## Records which control had focus on [param screen], as a path relative to the screen
## root. Kept only while [param screen] is on the stack: a call for a screen that is
## not on it does nothing, and a screen that leaves the stack forgets its focus. Called
## by the adapter from [signal screen_hidden], which reaches a covered screen while it
## is still on the stack and a removed one after it has left.
func remember_focus(screen: StringName, control_path: NodePath) -> void:
	var entry := _topmost(screen)
	if entry != null:
		entry.focus = control_path


## The focus remembered for [param screen], or an empty path when there is none: the
## screen is being entered rather than returned to, and takes its initial focus.
func focus_for(screen: StringName) -> NodePath:
	var entry := _topmost(screen)
	return entry.focus if entry != null else NodePath()


func _on_stack(id: StringName) -> bool:
	return _topmost(id) != null


func _topmost(id: StringName) -> _Entry:
	for index: int in range(_stack.size() - 1, -1, -1):
		if _stack[index].id == id:
			return _stack[index]
	return null


## The topmost full screen and the overlays above it, bottom to top.
func _visible_entries() -> Array[_Entry]:
	var shown: Array[_Entry] = []
	for index: int in range(_stack.size() - 1, -1, -1):
		shown.push_front(_stack[index])
		if _stack[index].id not in OVERLAYS:
			break
	return shown


## Emits the difference between [param before] and what is visible now. Entries are
## compared by identity, so a screen [method home] opens anew is hidden and shown again.
func _announce(before: Array[_Entry]) -> void:
	var after := _visible_entries()
	for index: int in range(before.size() - 1, -1, -1):
		if before[index] not in after:
			screen_hidden.emit(before[index].id)
	for entry: _Entry in after:
		if entry not in before:
			screen_shown.emit(entry.id, entry.params)
