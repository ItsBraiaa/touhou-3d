extends TestCase
## Behavior of the [TargetSelector] Rules Core: which candidate a Target Lock acquires,
## the order `next_target` cycles in, when a lock is invalidated, and when the change is
## reported.
##
## Expected values come from the design documents, not from the implementation.
## PLANEJAMENTO Section 3: "Aim assist prioritizes visible targets near the screen
## center. Lock remains stable until explicitly switched, released, or invalidated by
## target death/range." `MAX_DISTANCE` 60.0 and `MAX_SCREEN_RADIUS` 0.85 are the defaults
## the F1-04 ticket proposes for the adapter's exports; no design document fixes them.
##
## Screen offsets are normalized per axis: (0, 0) is the screen center, x = 1 the right
## edge, y = 1 the bottom edge, as in viewport pixels.

const MAX_DISTANCE := 60.0
const MAX_SCREEN_RADIUS := 0.85

var _selector: TargetSelector


func before_each() -> void:
	_selector = TargetSelector.new()
	_selector.configure(MAX_DISTANCE, MAX_SCREEN_RADIUS)


func test_best_pick_is_the_candidate_nearest_the_screen_center_not_the_nearest_in_distance() -> void:
	var candidates: Array[TargetSelector.Candidate] = [
		_candidate(1, Vector2(0.6, 0.0), 5.0),
		_candidate(2, Vector2(0.1, -0.1), 40.0),
		_candidate(3, Vector2(-0.3, 0.2), 12.0),
	]
	assert_eq(_selector.select_best(candidates), 2, "the far one near the center beats the near one at the side")


## Each disqualified candidate sits dead center, where it would win if it qualified.
func test_invisible_candidates_are_never_selected() -> void:
	var candidates: Array[TargetSelector.Candidate] = [
		_candidate(1, Vector2.ZERO, 10.0, false),
		_candidate(2, Vector2(0.5, 0.5), 30.0),
	]
	assert_eq(_selector.select_best(candidates), 2, "occluded or behind the camera")
	var only_hidden: Array[TargetSelector.Candidate] = [_candidate(1, Vector2.ZERO, 10.0, false)]
	assert_eq(_selector.select_best(only_hidden), TargetSelector.NO_TARGET, "nothing visible, nothing selected")


func test_candidates_beyond_range_are_never_selected() -> void:
	var candidates: Array[TargetSelector.Candidate] = [
		_candidate(1, Vector2.ZERO, MAX_DISTANCE + 0.5),
		_candidate(2, Vector2(0.5, 0.5), MAX_DISTANCE),
	]
	assert_eq(_selector.select_best(candidates), 2, "just beyond range loses; exactly at range still qualifies")
	candidates.remove_at(1)
	assert_eq(_selector.select_best(candidates), TargetSelector.NO_TARGET)


## A candidate past the radius is farther from the center than any candidate inside it,
## so it could never beat one anyway: the filter shows only when it is the sole option.
func test_a_fresh_lock_never_lands_outside_the_screen_radius() -> void:
	# (0.6, 0.6) has length 0.849, just inside the 0.85 radius; (0.61, 0.61) is 0.863.
	var inside: Array[TargetSelector.Candidate] = [_candidate(1, Vector2(0.6, 0.6), 1.0)]
	assert_eq(_selector.select_best(inside), 1, "just inside")
	var outside: Array[TargetSelector.Candidate] = [_candidate(1, Vector2(0.61, 0.61), 1.0)]
	assert_eq(_selector.select_best(outside), TargetSelector.NO_TARGET, "just outside, on the diagonal")
	var past_the_side: Array[TargetSelector.Candidate] = [_candidate(1, Vector2(-0.9, 0.0), 1.0)]
	assert_eq(_selector.select_best(past_the_side), TargetSelector.NO_TARGET, "past the left side")


func test_distance_breaks_a_tie_in_screen_offset() -> void:
	# Mirror images across the center are exactly as far from it; the farther one is
	# listed first so input order cannot decide in its favor.
	var candidates: Array[TargetSelector.Candidate] = [
		_candidate(1, Vector2(0.3, 0.0), 25.0),
		_candidate(2, Vector2(-0.3, 0.0), 15.0),
		_candidate(3, Vector2(0.0, 0.3), 20.0),
	]
	assert_eq(_selector.select_best(candidates), 2)


func test_configure_values_are_the_ones_the_selector_uses() -> void:
	# Every other test configures the ticket's defaults, so a selector that hardcoded 60
	# and 0.85 would pass them all. These two values appear in no document.
	var tuned := TargetSelector.new()
	tuned.configure(20.0, 0.4)
	var far: Array[TargetSelector.Candidate] = [_candidate(1, Vector2.ZERO, 25.0)]
	assert_eq(tuned.select_best(far), TargetSelector.NO_TARGET, "25 units is beyond a 20-unit range")
	var wide: Array[TargetSelector.Candidate] = [_candidate(1, Vector2(0.5, 0.0), 5.0)]
	assert_eq(tuned.select_best(wide), TargetSelector.NO_TARGET, "0.5 is outside a 0.4 radius")
	var inside: Array[TargetSelector.Candidate] = [_candidate(1, Vector2(0.35, 0.0), 19.0)]
	assert_eq(tuned.select_best(inside), 1)


## `next_target` steps to the right and wraps to the leftmost: screen x first, top before
## bottom at the same x. Left to right survives the camera turning toward each new lock,
## which only slides every target sideways by the same amount.
func test_select_next_visits_every_visible_candidate_in_range_once_left_to_right_before_wrapping() -> void:
	var candidates: Array[TargetSelector.Candidate] = [
		_candidate(7, Vector2(0.4, -0.2), 30.0),
		_candidate(3, Vector2(-0.5, 0.3), 30.0),
		_candidate(9, Vector2(0.0, 0.0), 30.0),
		_candidate(5, Vector2(0.2, 0.5), 30.0, false),
		_candidate(2, Vector2(0.4, 0.4), 30.0),
		_candidate(4, Vector2(-0.1, -0.6), 30.0),
	]
	# Left to right: 3 at -0.5, 4 at -0.1, 9 at 0.0, then 7 above 2 at 0.4. 5 is hidden.
	var expected: Array[int] = [7, 2, 3, 4, 9]
	assert_eq(_cycle_from(9, candidates, expected.size()), expected, "from the center target")

	var reversed := candidates.duplicate()
	reversed.reverse()
	assert_eq(_cycle_from(9, reversed, expected.size()), expected, "the order does not depend on the input order")


## The screen radius is for a fresh lock, which should land near the center. A switch is
## an explicit request, and the camera turning toward the lock pushes the other targets
## toward the edges: a visible target in range stays reachable wherever it is in front of
## the camera, or the one on the far side of a wide spread could never be reached.
func test_select_next_reaches_visible_targets_outside_the_screen_radius() -> void:
	var candidates: Array[TargetSelector.Candidate] = [
		_candidate(1, Vector2(-0.97, 0.3), 28.0),
		_candidate(2, Vector2(-0.47, 0.1), 38.0),
		_candidate(3, Vector2(0.0, -0.13), 31.0),
		_candidate(4, Vector2(1.6, 0.0), 20.0),
		_candidate(5, Vector2(-1.8, 0.0), MAX_DISTANCE + 1.0),
	]
	# Locked on 3: to its right is 4, past the screen edge; wrapping lands on 1, outside the
	# radius but on screen. 5 is beyond range and never joins.
	var expected: Array[int] = [4, 1, 2, 3]
	assert_eq(_cycle_from(3, candidates, expected.size()), expected)
	assert_eq(_selector.select_best(candidates), 3, "a fresh lock still keeps to the radius")


func test_select_next_with_one_candidate_returns_the_same_id() -> void:
	var candidates: Array[TargetSelector.Candidate] = [_candidate(4, Vector2(0.3, 0.1), 20.0)]
	assert_eq(_selector.select_next(candidates, 4), 4)


func test_select_next_falls_back_to_the_best_pick_when_the_current_target_is_not_in_the_ring() -> void:
	var candidates: Array[TargetSelector.Candidate] = [
		_candidate(1, Vector2(-0.5, 0.0), 20.0),
		_candidate(2, Vector2(0.1, 0.0), 20.0),
		_candidate(3, Vector2(0.6, 0.0), 20.0, false),
	]
	assert_eq(_selector.select_next(candidates, TargetSelector.NO_TARGET), 2, "no lock yet: next acquires")
	assert_eq(_selector.select_next(candidates, 42), 2, "a lock that is no longer listed")
	# A lock may be held on a target behind scenery; stepping away from it cannot use its
	# place in a ring it is not in, so it starts over from the best visible one.
	assert_eq(_selector.select_next(candidates, 3), 2, "the locked target is occluded")
	var hidden: Array[TargetSelector.Candidate] = [_candidate(3, Vector2(0.6, 0.0), 20.0, false)]
	assert_eq(_selector.select_next(hidden, 3), TargetSelector.NO_TARGET, "nothing to step to")


## PLANEJAMENTO Section 3: the lock is "invalidated by target death/range". A target
## that is gone is absent from the list; one that flew off is beyond range.
func test_validate_is_false_when_the_current_target_is_missing_or_beyond_range() -> void:
	var candidates: Array[TargetSelector.Candidate] = [
		_candidate(1, Vector2(0.1, 0.0), 20.0),
		_candidate(2, Vector2(0.2, 0.0), MAX_DISTANCE + 0.5),
	]
	assert_true(_selector.validate(candidates, 1), "listed and in range")
	assert_false(_selector.validate(candidates, 3), "absent: destroyed or removed from the group")
	assert_false(_selector.validate(candidates, 2), "beyond range")
	assert_false(_selector.validate(candidates, TargetSelector.NO_TARGET), "no lock is not a valid lock")


## PLANEJAMENTO Section 3: the lock "remains stable until explicitly switched, released,
## or invalidated". Passing behind a tree, or off the edge of the screen while the camera
## catches up, is none of those.
func test_validate_holds_a_lock_that_is_merely_occluded_or_off_screen() -> void:
	var candidates: Array[TargetSelector.Candidate] = [
		_candidate(1, Vector2(0.1, 0.0), 20.0, false),
		_candidate(2, Vector2(1.4, 0.0), 20.0),
	]
	assert_true(_selector.validate(candidates, 1), "occluded")
	assert_true(_selector.validate(candidates, 2), "outside the screen radius")


func test_target_changed_fires_once_per_change_and_not_for_the_same_id() -> void:
	assert_eq(_selector.get_current_id(), TargetSelector.NO_TARGET, "a new selector holds no lock")
	var changes := signal_recorder(_selector, &"target_changed")

	_selector.set_current(5)
	_selector.set_current(5)
	assert_eq(changes.emissions, [[5]], "locking, then locking the same target again")
	_selector.set_current(8)
	assert_eq(changes.emissions, [[5], [8]], "switching")
	_selector.set_current(TargetSelector.NO_TARGET)
	_selector.set_current(TargetSelector.NO_TARGET)
	assert_eq(changes.emissions, [[5], [8], [TargetSelector.NO_TARGET]], "releasing, then releasing again")
	assert_eq(_selector.get_current_id(), TargetSelector.NO_TARGET)


func test_an_empty_list_selects_nothing() -> void:
	var candidates: Array[TargetSelector.Candidate] = []
	assert_eq(_selector.select_best(candidates), TargetSelector.NO_TARGET)


func _candidate(id: int, screen_offset: Vector2, distance: float, visible: bool = true) -> TargetSelector.Candidate:
	return TargetSelector.Candidate.new(id, screen_offset, distance, visible)


## The ids [method TargetSelector.select_next] steps through in [param steps] presses,
## starting from [param start_id].
func _cycle_from(start_id: int, candidates: Array[TargetSelector.Candidate], steps: int) -> Array[int]:
	var visited: Array[int] = []
	var current := start_id
	for _step: int in steps:
		current = _selector.select_next(candidates, current)
		visited.append(current)
	return visited
