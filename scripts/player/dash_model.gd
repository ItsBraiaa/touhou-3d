class_name DashModel
extends RefCounted
## Rules Core for the lateral dash (F16-05): which press starts a burst, how long the burst
## is active, and the cooldown both directions share.
##
## Node-free (ADR-0001). [PlayerController] reads `dash_left` and `dash_right` every
## physics tick, ticks this core with the physics delta, and turns an accepted request into
## a camera-relative burst of its own. The direction, the collision stop and the visuals
## are the adapter's. Nothing here knows about Invulnerability: the Session grants it from
## the adapter's `dash_started` for the same duration, and [CombatState] counts it down with
## the same deltas and the same [constant TIME_EPSILON], so the active window here and the
## protection window there end on the same physics tick.
##
## A request is accepted only while no burst is active and the cooldown is over. A refused
## request is dropped, never buffered. The cooldown starts with the burst, not after it.
## Before [method configure] the duration is 0 and every request is refused.


## Seconds at or below which a countdown counts as over. A window of whole physics ticks
## leaves a rounding residue after its last tick (0.15 s at 60 Hz leaves 2e-17 s), which
## would keep it open one tick longer than it lasts. Taken from
## [constant CombatState.TIME_EPSILON], never a copy of it: the burst ends on the tick its
## protection does only while both cores count down with the same value.
const TIME_EPSILON := CombatState.TIME_EPSILON

var _duration: float = 0.0
var _cooldown: float = 0.0
var _active_left: float = 0.0
var _cooldown_left: float = 0.0
## -1 or +1 for the burst in progress or the last one, 0 before any.
var _direction: int = 0


## Sets the seconds a burst is active and the seconds from its activation until the next
## one is accepted. A negative value counts as 0, and a duration of 0 refuses every
## request.
func configure(duration: float, cooldown: float) -> void:
	_duration = maxf(duration, 0.0)
	_cooldown = maxf(cooldown, 0.0)


## Starts a burst toward [param direction], -1 for left and +1 for right, and returns true.
## Returns false and changes nothing for any other direction (0 is what both directions
## down together give, see [method resolve_direction]), while a burst is active, while the
## cooldown runs, or before [method configure]. An accepted burst is active for the
## configured duration, and its cooldown starts at once.
func try_start(direction: int) -> bool:
	if absi(direction) != 1 or not is_enabled() or is_active() or _cooldown_left > 0.0:
		return false
	_direction = direction
	_active_left = _duration
	_cooldown_left = _cooldown
	return true


## Counts the active window and the cooldown down by one physics step of [param delta]
## seconds. A countdown left at [constant TIME_EPSILON] or less becomes exactly 0.
func tick(delta: float) -> void:
	_active_left = _count_down(_active_left, delta)
	_cooldown_left = _count_down(_cooldown_left, delta)


## Ends a burst in progress and clears the cooldown, so the next request is accepted. The
## adapter calls it when its controls are taken away with the tree running, and on a
## teleport.
func cancel() -> void:
	_active_left = 0.0
	_cooldown_left = 0.0


## Whether any request can be accepted at all: false before [method configure], and after
## it set a duration of 0, when [method try_start] refuses every direction.
func is_enabled() -> bool:
	return _duration > 0.0


## Whether a burst is active: from the tick [method try_start] accepted it until its
## duration has been ticked away or [method cancel] ended it.
func is_active() -> bool:
	return _active_left > 0.0


## Seconds left in the active burst, or 0.
func get_active_time_left() -> float:
	return _active_left


## Seconds until a request is accepted again, or 0 when ready.
func get_cooldown_left() -> float:
	return _cooldown_left


## -1 or +1: the direction of the burst in progress, or of the last one. 0 before any.
func get_direction() -> int:
	return _direction


## The direction one physics tick's dash input asks for: -1 for a `dash_left` press, +1
## for a `dash_right` press, and 0 for no press or when both directions are down together,
## pressed in the same tick or one pressed while the other is held. [param left_pressed]
## and [param right_pressed] are the presses that began this tick; [param left_held] and
## [param right_held] are the actions' current state. [method try_start] refuses the 0,
## so it costs no cooldown.
static func resolve_direction(left_pressed: bool, right_pressed: bool, left_held: bool, right_held: bool) -> int:
	if (left_pressed or left_held) and (right_pressed or right_held):
		return 0
	return int(right_pressed) - int(left_pressed)


static func _count_down(seconds: float, delta: float) -> float:
	var left := seconds - delta
	return left if left > TIME_EPSILON else 0.0
