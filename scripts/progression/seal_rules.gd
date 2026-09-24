class_name SealRules
extends RefCounted
## Node-free rules core for one Stage 2 Seal and its linked Guards.


## The Seal's lifecycle state.
enum State {
	DORMANT,
	GUARDED,
	EXPOSED,
	DESTROYED,
}


## The linked Guard group became active.
signal guards_activated(seal_id: StringName)
## A linked Guard was counted as defeated.
signal guard_link_cleared(enemy_id: StringName)
## All linked Guards were defeated and the shield dropped.
signal shield_dropped(seal_id: StringName)
## The exposed Seal was destroyed.
signal destroyed(seal_id: StringName)


var _seal_id: StringName = &""
var _guard_ids: Array[StringName] = []
var _defeated_guards: Dictionary[StringName, bool] = {}
var _health: int = 0
var _state: State = State.DORMANT


## Initializes a Seal with its linked Guard ids and positive health.
func setup(seal_id: StringName, guard_ids: Array[StringName], health: int) -> void:
	assert(not seal_id.is_empty(), "SealRules: seal_id is required")
	assert(not guard_ids.is_empty(), "SealRules: at least one guard is required")
	assert(health > 0, "SealRules: health must be positive")
	_seal_id = seal_id
	_guard_ids = guard_ids.duplicate()
	_defeated_guards.clear()
	_health = health
	_state = State.DORMANT


## Activates the linked Guard group when the player approaches.
func notify_approached() -> bool:
	return _activate_guards()


## Activates the linked Guard group when one of its Guards is shot.
func notify_guard_shot(enemy_id: StringName) -> bool:
	if not _guard_ids.has(enemy_id):
		return false
	return _activate_guards()


## Counts one linked Guard defeat and exposes the Seal when the group is clear.
func notify_guard_defeated(enemy_id: StringName) -> bool:
	if _state == State.EXPOSED or _state == State.DESTROYED:
		return false
	if not _guard_ids.has(enemy_id) or _defeated_guards.has(enemy_id):
		return false
	_activate_guards()
	_defeated_guards[enemy_id] = true
	guard_link_cleared.emit(enemy_id)
	if _defeated_guards.size() == _guard_ids.size():
		_state = State.EXPOSED
		shield_dropped.emit(_seal_id)
	return true


## Applies damage only while the Seal is exposed.
func take_damage(amount: int) -> void:
	assert(amount > 0, "SealRules: damage amount must be positive")
	if _state != State.EXPOSED:
		return
	_health = maxi(0, _health - amount)
	if _health == 0:
		_state = State.DESTROYED
		destroyed.emit(_seal_id)


## Returns whether the Seal is currently shielded.
func is_shielded() -> bool:
	return _state != State.EXPOSED and _state != State.DESTROYED


## Returns whether the exposed Seal can receive damage.
func is_targetable() -> bool:
	return _state == State.EXPOSED


## Returns the current lifecycle state.
func get_state() -> State:
	return _state


## Captures the state as an independent dictionary for Retry snapshots.
func capture() -> Dictionary:
	var defeated_guards: PackedStringArray = PackedStringArray()
	for guard_id: StringName in _guard_ids:
		if _defeated_guards.has(guard_id):
			defeated_guards.append(String(guard_id))
	return {
		"state": int(_state),
		"defeated_guards": defeated_guards,
		"health": _health,
	}


## Restores a captured state without emitting signals.
func restore(data: Dictionary) -> void:
	var restored_state: int = int(data.get("state", State.DORMANT))
	assert(restored_state >= State.DORMANT and restored_state <= State.DESTROYED,
			"SealRules: invalid state in capture")
	var restored_health: int = int(data.get("health", _health))
	assert(restored_health >= 0, "SealRules: invalid health in capture")
	_state = restored_state as State
	_health = restored_health
	_defeated_guards.clear()
	var defeated_guards: PackedStringArray = data.get(
			"defeated_guards", PackedStringArray())
	for guard_name: String in defeated_guards:
		var guard_id: StringName = StringName(guard_name)
		if _guard_ids.has(guard_id):
			_defeated_guards[guard_id] = true


func _activate_guards() -> bool:
	if _state != State.DORMANT:
		return false
	_state = State.GUARDED
	guards_activated.emit(_seal_id)
	return true
