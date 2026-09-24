class_name RunState
extends RefCounted
## Rules Core for the Run: Run Mode, stage order, the current Attempt, Active Time and
## Clear Time accounting, committed statistics, and the lifecycle signals the Session
## reacts to.
##
## Node-free (ADR-0001). The Session owns one, ticks it from `_physics_process` and
## drives it with direct calls; the Stage Director reports Checkpoints and stage
## completion through the Session. Each stage accounts for its own Clear Time, Graze and
## bombs used; score is a Run result (PLANEJAMENTO Section 5) and a Campaign carries it,
## with the Power Level and, since F15-11, the Power Progress, into the next stage. Only
## those stage-entry values are held here: the live combat resources and Encounter flags
## are not; F8-03 adds them to the Snapshot.
##
## Every call that changes the Attempt is ignored unless a stage is in play
## ([constant Phase.IN_STAGE]), so a completed stage's result is final and a duplicate
## callback cannot report a transition twice.


## A stage of the order was entered, by [method start] or [method advance]. Not emitted
## by [method restart_stage] or [method restore], which stay in the same stage.
signal stage_started(stage: StringName)
## [method complete_stage] ended the stage in play. [param result] is
## [method stage_result] at that moment, and it no longer changes afterwards.
signal stage_completed(result: Dictionary)
## The Run is over: [param victory] is true after the last stage of the order, false when
## the player left it through [method end_run].
signal run_ended(victory: bool)
## The pause flag changed, through [method set_paused], [method begin_attempt] or
## [method start]. Never emitted when the flag already had that value.
signal paused_changed(paused: bool)

## How the Run was started (CONTEXT "Run Mode").
enum RunMode { CAMPAIGN, DIRECT_STAGE }
## Where the Run is. Only [constant IN_STAGE] accepts changes to the Attempt.
enum Phase { IDLE, IN_STAGE, STAGE_COMPLETE, RUN_ENDED }

## Stage order of a Campaign (PLANEJAMENTO Section 6).
const CAMPAIGN_ORDER: Array[StringName] = [&"stage_01", &"stage_02"]
## Power Level a stage starts at when it is not reached from the previous stage of a
## Campaign (PLANEJAMENTO Section 6). A stage missing here starts at 1.
const ENTRY_POWER_LEVEL: Dictionary[StringName, int] = {&"stage_01": 1, &"stage_02": 2}


## The statistics one stage accounts for. Internal: held once for the committed values
## and once for the current Attempt, and replaced rather than shared.
class Tally:
	extends RefCounted

	## Active Time in seconds.
	var active_time: float = 0.0
	var score: int = 0
	var graze: int = 0
	var bombs_used: int = 0

	## A new Tally holding this one plus [param other], field by field.
	func plus(other: Tally) -> Tally:
		var sum := Tally.new()
		sum.active_time = active_time + other.active_time
		sum.score = score + other.score
		sum.graze = graze + other.graze
		sum.bombs_used = bombs_used + other.bombs_used
		return sum


var _mode: RunMode = RunMode.CAMPAIGN
var _order: Array[StringName] = []
var _stage_index: int = 0
var _phase: Phase = Phase.IDLE
var _entry_power_level: int = 1
var _entry_power_progress: int = 0
var _entry_score: int = 0
var _attempt_index: int = 0
var _paused: bool = false
var _committed := Tally.new()
var _attempt := Tally.new()


## Begins a new Run and enters its first stage, discarding any Run in progress without
## emitting [signal run_ended]. A Campaign plays [constant CAMPAIGN_ORDER] from
## [param first_stage] on; a Direct Stage plays [param first_stage] alone. Everything
## starts from zero, unpaused, with no Attempt begun: call [method begin_attempt] next.
func start(mode: RunMode, first_stage: StringName) -> void:
	_mode = mode
	if mode == RunMode.CAMPAIGN:
		assert(first_stage in CAMPAIGN_ORDER, "RunState: %s is not a Campaign stage" % first_stage)
		_order = CAMPAIGN_ORDER.slice(CAMPAIGN_ORDER.find(first_stage))
	else:
		_order = [first_stage]
	_stage_index = 0
	set_paused(false)
	_enter_stage(ENTRY_POWER_LEVEL.get(first_stage, 1), 0, 0)


## Begins a new Attempt in the stage in play: counts it, discards whatever the previous
## Attempt had not committed, and unpauses. The Session calls it after [method start],
## [method advance], [method rollback_attempt] (Retry) and [method restart_stage].
func begin_attempt() -> void:
	if not _is_in_stage():
		return
	_attempt_index += 1
	rollback_attempt()
	set_paused(false)


## Sets the pause flag. While it is set [method tick_active] adds nothing.
func set_paused(paused: bool) -> void:
	if paused == _paused:
		return
	_paused = paused
	paused_changed.emit(paused)


## Adds one physics step of [param delta] seconds to the current Attempt's Active Time.
## Ignored unless a stage is in play and the pause flag is clear; the Session also stops
## calling it while the tree is paused (CONVENTIONS "Time and randomness").
func tick_active(delta: float) -> void:
	if not _is_in_stage() or _paused:
		return
	_attempt.active_time += delta


## Adds [param points] to the current Attempt's score.
func add_score(points: int) -> void:
	if _is_in_stage():
		_attempt.score += points


## Adds [param count] Grazes to the current Attempt.
func add_graze(count: int = 1) -> void:
	if _is_in_stage():
		_attempt.graze += count


## Counts one Bomb used in the current Attempt. A Checkpoint refill does not undo it.
func note_bomb_used() -> void:
	if _is_in_stage():
		_attempt.bombs_used += 1


## Folds the current Attempt's Active Time, score, Graze and bombs used into the
## committed values of the stage in play, which a Retry returns to. The Attempt goes on
## from zero; it is not a new Attempt. The Stage Director calls it on a Checkpoint's
## first activation only.
func commit_checkpoint() -> void:
	if not _is_in_stage():
		return
	_committed = _committed.plus(_attempt)
	_attempt = Tally.new()


## Discards the current Attempt's uncommitted values, leaving the committed ones (Retry).
func rollback_attempt() -> void:
	if _is_in_stage():
		_attempt = Tally.new()


## Discards the committed values of the stage in play as well and returns to its
## stage-entry values: nothing but the score a Campaign carried in (Restart).
func restart_stage() -> void:
	if not _is_in_stage():
		return
	_committed = _entry_tally()
	rollback_attempt()


## Ends the stage in play and emits [signal stage_completed] with its result. Ignored
## unless a stage is in play, so a second call reports nothing.
func complete_stage() -> void:
	if not _is_in_stage():
		return
	_phase = Phase.STAGE_COMPLETE
	stage_completed.emit(stage_result())


## Leaves a completed stage: enters the next stage of the order, or ends the Run with a
## victory after the last one. [param power_level] and [param power_progress] are the
## player's Power Level and Power Progress at the end of the completed stage, which the
## next stage of a Campaign starts at (F15-11); both are unused when the Run ends.
## Ignored unless a stage has just completed.
func advance(power_level: int, power_progress: int = 0) -> void:
	if _phase != Phase.STAGE_COMPLETE:
		return
	if _stage_index + 1 < _order.size():
		_stage_index += 1
		_enter_stage(power_level, power_progress, _committed.score + _attempt.score)
	else:
		end_run(true)


## Ends the Run and emits [signal run_ended]. Ignored when no Run is in progress, so a
## second call reports nothing.
func end_run(victory: bool = false) -> void:
	if _phase == Phase.IDLE or _phase == Phase.RUN_ENDED:
		return
	_phase = Phase.RUN_ENDED
	run_ended.emit(victory)


## Clear Time of the current stage, in seconds: the committed Active Time plus the
## current Attempt's (CONTEXT "Clear Time").
func clear_time() -> float:
	return _committed.active_time + _attempt.active_time


## Result of the current stage, committed plus current Attempt: `clear_time` (float,
## seconds), `score`, `graze`, `bombs_used` (int), `mode` ([enum RunMode]), `stage`
## (StringName) and `is_final` (bool, true when this is the last stage of the order, so
## its completion ends the Run). A new Dictionary on every call. Only valid after
## [method start].
func stage_result() -> Dictionary:
	var total := _committed.plus(_attempt)
	return {
		"clear_time": total.active_time,
		"score": total.score,
		"graze": total.graze,
		"bombs_used": total.bombs_used,
		"mode": _mode,
		"stage": _order[_stage_index],
		"is_final": _stage_index == _order.size() - 1,
	}


## The committed values, the stage-entry values and the stage position, as a Dictionary
## of primitives that shares nothing with this core (CONVENTIONS "Snapshots"): `mode`,
## `stage_order`, `stage_index`, `entry_power_level`, `entry_power_progress`, `entry_score`,
## `committed_active_time`, `committed_score`, `committed_graze`,
## `committed_bombs_used`. The current Attempt's uncommitted values are not in it.
func capture() -> Dictionary:
	return {
		"mode": _mode,
		"stage_order": _order.duplicate(),
		"stage_index": _stage_index,
		"entry_power_level": _entry_power_level,
		"entry_power_progress": _entry_power_progress,
		"entry_score": _entry_score,
		"committed_active_time": _committed.active_time,
		"committed_score": _committed.score,
		"committed_graze": _committed.graze,
		"committed_bombs_used": _committed.bombs_used,
	}


## Puts back what [method capture] returned: the stage in play, its entry values and its
## committed values, with nothing uncommitted and the stage in play. [param data] is
## copied, not kept. The Attempt count and the pause flag are left alone, and no signal
## is emitted.
func restore(data: Dictionary) -> void:
	_mode = data["mode"]
	_order.assign(data["stage_order"])
	_stage_index = data["stage_index"]
	_entry_power_level = data["entry_power_level"]
	_entry_power_progress = data["entry_power_progress"]
	_entry_score = data["entry_score"]
	_committed = Tally.new()
	_committed.active_time = data["committed_active_time"]
	_committed.score = data["committed_score"]
	_committed.graze = data["committed_graze"]
	_committed.bombs_used = data["committed_bombs_used"]
	_attempt = Tally.new()
	_phase = Phase.IN_STAGE


## Where the Run is.
func get_phase() -> Phase:
	return _phase


## Attempts begun in the current stage: 0 at its entry, 1 during the first Attempt.
## Counted per stage, so a stage cleared on Attempt 1 was cleared without a Retry or a
## Restart.
func get_attempt_index() -> int:
	return _attempt_index


## Whether the pause flag is set.
func is_paused() -> bool:
	return _paused


## Power Level the player starts the current stage at: 1 for Stage 1 in either mode, 2
## for a Direct Stage 2, and what [method advance] passed for Campaign Stage 2. Restart
## and Retry use it too.
func starting_power_level() -> int:
	return _entry_power_level


## Power Progress the player starts the current stage at, beside
## [method starting_power_level]: 0 for a stage entered by [method start], and what
## [method advance] passed for Campaign Stage 2 (F15-11). Restart uses it too.
func starting_power_progress() -> int:
	return _entry_power_progress


func _is_in_stage() -> bool:
	return _phase == Phase.IN_STAGE


## Records the stage-entry values of the stage at [member _stage_index] and puts it in
## play with nothing committed beyond them and no Attempt begun.
func _enter_stage(power_level: int, power_progress: int, score: int) -> void:
	_entry_power_level = power_level
	_entry_power_progress = power_progress
	_entry_score = score
	_attempt_index = 0
	_committed = _entry_tally()
	_attempt = Tally.new()
	_phase = Phase.IN_STAGE
	stage_started.emit(_order[_stage_index])


## The committed values of the current stage at its entry: the carried score and nothing
## else, since Clear Time, Graze and bombs used belong to one stage.
func _entry_tally() -> Tally:
	var entry := Tally.new()
	entry.score = _entry_score
	return entry
