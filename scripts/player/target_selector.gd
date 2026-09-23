class_name TargetSelector
extends RefCounted
## Rules Core for Target Lock: which target a lock acquires, where `next_target` steps to,
## when a held lock is invalidated, and when the lock changes.
##
## Node-free (ADR-0001). The adapter describes every target it can see as a [Candidate]
## each tick and asks the questions below; ids are opaque to the core. The rules come
## from PLANEJAMENTO Section 3: prefer visible targets near the screen center, and keep a
## lock "until explicitly switched, released, or invalidated by target death/range".


## Emitted by [method set_current] when the locked id actually changes. [param id] is the
## new lock, or [constant NO_TARGET] on release. Never emitted for the id already held.
signal target_changed(id: int)

## The id that means "no lock". Node instance ids are always positive, so no target
## ever has it.
const NO_TARGET := -1


## One target as the adapter saw it this tick. A plain value: the core reads it and keeps
## nothing of it.
class Candidate:
	extends RefCounted

	## Opaque to the core; the adapter uses the node's instance id.
	var id: int
	## Where the target is on screen, normalized per axis: (0, 0) is the center, x = ±1 the
	## right and left edges, y = ±1 the bottom and top edges (y grows downward, as viewport
	## pixels do). Meaningless when the target is behind the camera, which is not visible.
	var screen_offset: Vector2
	## World distance from the ship, in units.
	var distance: float
	## In front of the camera with nothing on the occlusion mask in between.
	var visible: bool

	func _init(p_id: int, p_screen_offset: Vector2, p_distance: float, p_visible: bool) -> void:
		id = p_id
		screen_offset = p_screen_offset
		distance = p_distance
		visible = p_visible


var _max_distance: float = 0.0
var _max_screen_radius: float = 0.0
var _current_id: int = NO_TARGET


## Sets the range, in world units from the ship, beyond which a target can be neither
## acquired nor kept, and the radius of the screen area a target must be inside to be
## acquired, in the normalized units of [member Candidate.screen_offset]. Until it is
## called both are 0 and nothing qualifies.
func configure(max_distance: float, max_screen_radius: float) -> void:
	_max_distance = max_distance
	_max_screen_radius = max_screen_radius


## The id of the target a fresh lock takes: among the candidates that are visible, within
## range and inside the screen radius, the one nearest the screen center, with the nearer
## in distance winning a tie. [constant NO_TARGET] when none qualifies.
func select_best(candidates: Array[Candidate]) -> int:
	var best: Candidate = null
	for candidate: Candidate in candidates:
		if not _qualifies(candidate):
			continue
		if best == null or _is_closer_to_center(candidate, best):
			best = candidate
	return NO_TARGET if best == null else best.id


## The id `next_target` steps to from [param current_id]: the next candidate to its right
## on screen among those that are visible and within range, wrapping from the rightmost
## to the leftmost, so repeated presses visit every one of them once before coming back.
## Candidates at the same screen x go top to bottom. When [param current_id] is not among
## them — no lock, a target no longer listed, or a lock held behind scenery — this is
## [method select_best]. With one of them it returns that one.
##
## The screen radius does not apply here, only to a fresh lock: the camera turns toward
## each new lock and pushes the others toward the edges, and a target on the far side of
## a wide spread would otherwise drop out of the ring for good. Left to right rather than
## by angle around the center for the same reason: that turn slides every target
## sideways by the same amount and keeps their left-to-right order, while the locked
## target's own angle around the center is noise.
func select_next(candidates: Array[Candidate], current_id: int) -> int:
	var ring: Array[Candidate] = []
	for candidate: Candidate in candidates:
		if _is_reachable(candidate):
			ring.append(candidate)
	ring.sort_custom(_is_left_of)
	for index: int in ring.size():
		if ring[index].id == current_id:
			return ring[(index + 1) % ring.size()].id
	return select_best(candidates)


## Whether a held lock on [param current_id] survives this tick: false when the target is
## not listed (destroyed, or no longer targetable) or is beyond range, and false for
## [constant NO_TARGET]. Occlusion and the screen radius do not matter here — a locked
## target may pass behind a tree, or off screen while the camera turns toward it.
func validate(candidates: Array[Candidate], current_id: int) -> bool:
	for candidate: Candidate in candidates:
		if candidate.id == current_id:
			return candidate.distance <= _max_distance
	return false


## Records the lock and emits [signal target_changed] if [param id] differs from the one
## held. Pass [constant NO_TARGET] to release.
func set_current(id: int) -> void:
	if id == _current_id:
		return
	_current_id = id
	target_changed.emit(id)


## The locked id, or [constant NO_TARGET].
func get_current_id() -> int:
	return _current_id


## Whether a switch may land on [param candidate]: visible and within range.
func _is_reachable(candidate: Candidate) -> bool:
	return candidate.visible and candidate.distance <= _max_distance


## Whether a fresh lock may land on [param candidate]: reachable and near the center.
func _qualifies(candidate: Candidate) -> bool:
	return _is_reachable(candidate) and candidate.screen_offset.length() <= _max_screen_radius


static func _is_closer_to_center(a: Candidate, b: Candidate) -> bool:
	var a_offset := a.screen_offset.length()
	var b_offset := b.screen_offset.length()
	if not is_equal_approx(a_offset, b_offset):
		return a_offset < b_offset
	return a.distance < b.distance


static func _is_left_of(a: Candidate, b: Candidate) -> bool:
	# Exact comparisons on purpose: a sort needs a strict order, which an approximate
	# equality would break.
	if a.screen_offset.x != b.screen_offset.x:
		return a.screen_offset.x < b.screen_offset.x
	if a.screen_offset.y != b.screen_offset.y:
		return a.screen_offset.y < b.screen_offset.y
	return a.id < b.id
