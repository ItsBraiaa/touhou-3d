class_name EncounterMachine
extends RefCounted
## Rules Core for Encounter progression on one loaded Stage (STAGE_DESIGN "Agent
## implementation contract"): each Encounter is inactive, active or completed, entry is
## accepted only in route order and behind its Checkpoint, Waves are scheduled and
## requested, completion conditions are checked, and Gate opening and one-time rewards
## are reported. Enemies report outcomes here and this core decides progression
## (ENGINEERING_BRIEF 4.G); the Stage Director (F10-01) turns the signals into spawns,
## Gates and Pickups.
##
## Node-free (ADR-0001). Nothing in progression is random, so there is no RNG here. The
## Director calls [method setup] first, ticks the core from `_physics_process` only
## while the tree runs, reports the entry and exit volumes, enemy defeats, Objectives
## and Checkpoint entry, and connects the signals once in its own `setup()`.
##
## Completion is idempotent: an Encounter completes exactly once whatever the order or
## the duplication of the reports. Completion emits, in order, [signal gate_opened],
## [signal rewards_requested], [signal encounter_completed] and, after the last
## Encounter, [signal stage_cleared] — each at most once per Encounter until a
## [method restore] or [method reset].


## The Encounter [param id] was accepted for play: it is the next route entry and its
## Checkpoint, when it has one, is activated. Emitted before its Waves are scheduled.
signal encounter_activated(id: StringName)

## The Wave [param wave_index] of Encounter [param id] is due: the Director spawns its
## enemies. Emitted inside the call that schedules it when its delay is 0, otherwise
## when [method tick] counts the delay down.
signal wave_requested(id: StringName, wave_index: int)

## The Gate [param gate_id] of a completing Encounter must open. Always the first
## completion signal.
signal gate_opened(gate_id: StringName)

## The one-time rewards of Encounter [param id] must be granted. Never repeated for the
## same Encounter.
signal rewards_requested(id: StringName)

## Encounter [param id] completed. Re-entering its volumes changes nothing.
signal encounter_completed(id: StringName)

## The last Encounter of the Stage completed.
signal stage_cleared

## The lifecycle of one Encounter (STAGE_DESIGN "Agent implementation contract").
enum State {
	## Not entered; its entry volume is refused while it is not the next route entry.
	INACTIVE,
	## Entered and playing; its reports are counted.
	ACTIVE,
	## Finished; re-entering never spawns or rewards again.
	COMPLETED,
}


## The loaded Stage; set by [method setup].
var _stage: StageDefinition = null
## Encounter id -> [enum State]; every Encounter of the Stage has an entry after setup.
var _states: Dictionary[StringName, int] = {}
## The one ACTIVE Encounter, or an empty id when none is.
var _active_id: StringName = &""
## Encounters whose rewards were already requested.
var _rewarded: Dictionary[StringName, bool] = {}
## Objective ids recorded once, in any order.
var _objectives: Dictionary[StringName, bool] = {}
## Checkpoints activated on their first entry.
var _checkpoints: Dictionary[StringName, bool] = {}
## Enemy ids counted once for the ACTIVE Encounter.
var _counted: Dictionary[StringName, bool] = {}
## Wave indexes of the ACTIVE Encounter whose request already went out.
var _requested_waves: Dictionary[int, bool] = {}
## Wave indexes of the ACTIVE Encounter still counting their delay, and the seconds
## left.
var _pending_waves: Dictionary[int, float] = {}
## Whether the ExitVolume of the ACTIVE Encounter was reached (`requires_exit`).
var _exit_latched: bool = false


## Loads [param stage] with every Encounter [constant State.INACTIVE] and no Checkpoint
## activated. Asserts the Stage validates (CONVENTIONS "Data and content"); the
## Director refuses invalid content before it reaches this core.
func setup(stage: StageDefinition) -> void:
	assert(stage != null, "EncounterMachine: setup needs a StageDefinition")
	var errors: PackedStringArray = stage.validate()
	assert(errors.is_empty(),
			"EncounterMachine: invalid StageDefinition: %s" % ", ".join(errors))
	_stage = stage
	_clear_all()


## Accepts entry into Encounter [param encounter_id] and returns whether it played.
## Only the next route Encounter is accepted — the first one not completed, so every
## earlier one is — and only while it is [constant State.INACTIVE] and its Checkpoint,
## when it has one, is activated. Emits [signal encounter_activated] and then requests
## every ON_ENTRY Wave, the delay-0 ones inside this call. Everything else (out of
## order, behind an inactive Checkpoint, already ACTIVE or COMPLETED, unknown) is
## refused with no signal: re-entering a trigger never spawns again.
func notify_entered(encounter_id: StringName) -> bool:
	var index: int = _stage.encounter_index(encounter_id)
	if index < 0:
		return false
	var next_index: int = _first_incomplete_index()
	if next_index < 0 or index != next_index:
		return false
	var encounter: EncounterDefinition = _stage.encounters[index]
	if _states[encounter_id] != State.INACTIVE:
		return false
	if not encounter.checkpoint_id.is_empty() and not _checkpoints.has(encounter.checkpoint_id):
		return false
	_states[encounter_id] = State.ACTIVE
	_active_id = encounter_id
	_clear_transient()
	encounter_activated.emit(encounter_id)
	for wave_index: int in range(encounter.waves.size()):
		if _active_id != encounter_id:
			break
		if encounter.waves[wave_index].activation == WaveDefinition.Activation.ON_ENTRY:
			_schedule_wave(encounter, wave_index)
	return true


## Reports the ExitVolume of Encounter [param encounter_id], ignored unless it is the
## ACTIVE one. A TRAVERSAL Encounter completes. With `requires_exit` the exit latches
## and the Encounter completes when its enemy or Objective condition already holds;
## otherwise the exit of a combat Encounter changes nothing, so the boss ExitVolume
## never completes the boss.
func notify_exited(encounter_id: StringName) -> void:
	if _active_id != encounter_id:
		return
	var encounter: EncounterDefinition = _stage.find_encounter(encounter_id)
	if encounter == null:
		return
	match encounter.completion:
		EncounterDefinition.Completion.TRAVERSAL:
			_complete(encounter)
		_:
			if encounter.requires_exit:
				_exit_latched = true
				if _condition_holds(encounter):
					_complete(encounter)


## Counts the enemy [param defeated_id] of Encounter [param encounter_id] once, only while
## that Encounter is ACTIVE and the enemy belongs to an already-requested Wave.
## Duplicates and strangers are ignored. When the last enemy of a Wave falls, the next
## AFTER_PREVIOUS_WAVE Wave is scheduled after its delay. An ALL_REQUIRED_ENEMIES
## Encounter completes when every Wave was requested and every enemy counted, so three
## Bomb deaths in one tick with repeated reports complete it exactly once.
func notify_enemy_defeated(defeated_id: StringName, encounter_id: StringName) -> void:
	if _active_id != encounter_id:
		return
	var encounter: EncounterDefinition = _stage.find_encounter(encounter_id)
	if encounter == null:
		return
	var wave_index: int = _owning_requested_wave_index(encounter, defeated_id)
	if wave_index < 0 or _counted.has(defeated_id):
		return
	_counted[defeated_id] = true
	if _is_wave_defeated(encounter, wave_index):
		var next_index: int = wave_index + 1
		if next_index < encounter.waves.size():
			var next_wave: WaveDefinition = encounter.waves[next_index]
			if next_wave.activation == WaveDefinition.Activation.AFTER_PREVIOUS_WAVE:
				_schedule_wave(encounter, next_index)
	if encounter.completion == EncounterDefinition.Completion.ALL_REQUIRED_ENEMIES:
		if _condition_holds(encounter):
			_complete(encounter)


## Records the Objective [param objective_id] and returns whether this call recorded
## it: only an id the ACTIVE Encounter lists counts, and each id counts once, in any
## order (every seal order completes its Encounter). An OBJECTIVES Encounter completes
## when every listed id is recorded.
func notify_objective(objective_id: StringName) -> bool:
	if _active_id.is_empty():
		return false
	var encounter: EncounterDefinition = _stage.find_encounter(_active_id)
	if encounter == null:
		return false
	if not encounter.required_objective_ids.has(objective_id):
		return false
	if _objectives.has(objective_id):
		return false
	_objectives[objective_id] = true
	if encounter.completion == EncounterDefinition.Completion.OBJECTIVES:
		if _condition_holds(encounter):
			_complete(encounter)
	return true


## Activates the Checkpoint [param checkpoint_id] and returns whether this call did it:
## only the first entry counts, and only once its `after_encounter_id` is COMPLETED.
## Refill and the Snapshot belong to CheckpointStore (F8-03), which calls this first.
func notify_checkpoint_entered(checkpoint_id: StringName) -> bool:
	var checkpoint: CheckpointDefinition = _stage.find_checkpoint(checkpoint_id)
	if checkpoint == null or _checkpoints.has(checkpoint_id):
		return false
	if _states.get(checkpoint.after_encounter_id, State.INACTIVE) != State.COMPLETED:
		return false
	_checkpoints[checkpoint_id] = true
	return true


## Counts the scheduled Waves of the ACTIVE Encounter down by [param delta] seconds and
## requests each one when due. The Director calls it only while the tree runs.
func tick(delta: float) -> void:
	if _active_id.is_empty():
		return
	var active_id: StringName = _active_id
	var due: Array[int] = []
	for wave_index: int in _pending_waves:
		var remaining: float = _pending_waves[wave_index] - delta
		if remaining <= 0.0:
			due.append(wave_index)
		else:
			_pending_waves[wave_index] = remaining
	due.sort()
	for wave_index: int in due:
		if _active_id != active_id:
			break
		_pending_waves.erase(wave_index)
		_requested_waves[wave_index] = true
		wave_requested.emit(active_id, wave_index)


## The progression state as a new Dictionary of primitives that shares nothing with this
## core (CONVENTIONS "Snapshots"): `completed`, `rewarded`, `objectives` and
## `checkpoints` (each a PackedStringArray of ids, in route order where they are
## Encounter ids) and `resume_encounter_id` (String) — the resume Encounter of the
## latest activated Checkpoint in route order, or the first Encounter. Scheduled Waves,
## counted enemies and exit latches are transient and not in it.
func capture() -> Dictionary:
	var completed: PackedStringArray = PackedStringArray()
	var rewarded: PackedStringArray = PackedStringArray()
	for encounter: EncounterDefinition in _stage.encounters:
		if encounter == null:
			continue
		if _states.get(encounter.id, State.INACTIVE) == State.COMPLETED:
			completed.append(String(encounter.id))
			if _rewarded.has(encounter.id):
				rewarded.append(String(encounter.id))
	var objectives: PackedStringArray = PackedStringArray()
	for objective_id: StringName in _objectives:
		objectives.append(String(objective_id))
	var checkpoints: PackedStringArray = PackedStringArray()
	for checkpoint_id: StringName in _checkpoints:
		checkpoints.append(String(checkpoint_id))
	return {
		"completed": completed,
		"rewarded": rewarded,
		"objectives": objectives,
		"checkpoints": checkpoints,
		"resume_encounter_id": String(_resume_encounter_id()),
	}


## Rebuilds the progression state from what [method capture] returned, emitting no
## signal. Every Encounter before the `resume_encounter_id` of [param data] becomes
## COMPLETED and rewarded — including one still ACTIVE at capture, such as S1-06 at
## CP1-B — and every other Encounter INACTIVE. The Objective and Checkpoint flags come
## back from the capture. Scheduled Waves, counted enemies and exit latches are
## cleared, which is the core side of queued-spawn cancellation. [param data] is read,
## not kept.
func restore(data: Dictionary) -> void:
	assert(_stage != null, "EncounterMachine: restore needs a setup stage")
	var resume_id: StringName = StringName(String(data.get("resume_encounter_id", "")))
	var resume_index: int = _stage.encounter_index(resume_id)
	assert(resume_index >= 0,
			"EncounterMachine: resume Encounter '%s' is not in this stage" % resume_id)
	_active_id = &""
	_states.clear()
	_rewarded.clear()
	for index: int in range(_stage.encounters.size()):
		var encounter: EncounterDefinition = _stage.encounters[index]
		if encounter == null:
			continue
		if index < resume_index:
			_states[encounter.id] = State.COMPLETED
			if not encounter.rewards.is_empty():
				_rewarded[encounter.id] = true
		else:
			_states[encounter.id] = State.INACTIVE
	_objectives.clear()
	var objective_flags: PackedStringArray = data.get("objectives", PackedStringArray())
	for objective_id: String in objective_flags:
		_objectives[StringName(objective_id)] = true
	_checkpoints.clear()
	var checkpoint_flags: PackedStringArray = data.get("checkpoints", PackedStringArray())
	for checkpoint_id: String in checkpoint_flags:
		_checkpoints[StringName(checkpoint_id)] = true
	_clear_transient()


## Back to the [method setup] state: every Encounter INACTIVE, no Checkpoint
## activated, no Objective recorded, nothing rewarded. This is Restart; Retry uses
## [method restore].
func reset() -> void:
	assert(_stage != null, "EncounterMachine: reset needs a setup stage")
	_clear_all()


## The stable enemy id of the marker [param marker] in Encounter [param encounter_id]:
## `"<encounter_id>/<last name of the marker>"`, for example `S1-02/Wave1_Spirit1`.
static func enemy_id(encounter_id: StringName, marker: NodePath) -> StringName:
	var names: int = marker.get_name_count()
	var last: String = ""
	if names > 0:
		last = String(marker.get_name(names - 1))
	return StringName("%s/%s" % [String(encounter_id), last])


## The one ACTIVE Encounter, or an empty id when none is.
func get_active_encounter_id() -> StringName:
	return _active_id


## The [enum State] of Encounter [param id]; [constant State.INACTIVE] when unknown.
func get_state(id: StringName) -> State:
	if not _states.has(id):
		return State.INACTIVE
	match _states[id]:
		State.ACTIVE:
			return State.ACTIVE
		State.COMPLETED:
			return State.COMPLETED
		_:
			return State.INACTIVE


## Whether Encounter [param id] completed.
func is_completed(id: StringName) -> bool:
	return _states.get(id, State.INACTIVE) == State.COMPLETED


## Whether the Checkpoint [param id] was activated in this Attempt.
func is_checkpoint_activated(id: StringName) -> bool:
	return _checkpoints.has(id)


## The enemy ids of Wave [param wave_index] of Encounter [param encounter_id], in
## marker order; empty when the Encounter or the Wave does not exist.
func get_wave_enemy_ids(encounter_id: StringName, wave_index: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	var encounter: EncounterDefinition = _stage.find_encounter(encounter_id)
	if encounter == null or wave_index < 0 or wave_index >= encounter.waves.size():
		return ids
	var wave: WaveDefinition = encounter.waves[wave_index]
	for marker: NodePath in wave.spawn_markers:
		ids.append(enemy_id(encounter_id, marker))
	return ids


## The Gates of the COMPLETED Encounters, in route order, for rebuilding the Gates
## after a restore.
func get_open_gate_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for encounter: EncounterDefinition in _stage.encounters:
		if encounter == null or encounter.gate_id.is_empty():
			continue
		if _states.get(encounter.id, State.INACTIVE) == State.COMPLETED:
			ids.append(encounter.gate_id)
	return ids


## The route index of the first Encounter that is not COMPLETED, or -1 when all are.
func _first_incomplete_index() -> int:
	for index: int in range(_stage.encounters.size()):
		var encounter: EncounterDefinition = _stage.encounters[index]
		if encounter != null and _states[encounter.id] != State.COMPLETED:
			return index
	return -1


## Wipes every state and flag, as [method setup] and [method reset] leave the core.
func _clear_all() -> void:
	_states.clear()
	for encounter: EncounterDefinition in _stage.encounters:
		if encounter != null:
			_states[encounter.id] = State.INACTIVE
	_rewarded.clear()
	_objectives.clear()
	_checkpoints.clear()
	_active_id = &""
	_clear_transient()


## Clears the per-Attempt data of the ACTIVE Encounter: counted enemies, requested and
## scheduled Waves, and the exit latch.
func _clear_transient() -> void:
	_counted.clear()
	_requested_waves.clear()
	_pending_waves.clear()
	_exit_latched = false


## Schedules [param wave_index] of [param encounter]: a Wave with no delay is requested
## inside this call; a delayed one counts down in [method tick].
func _schedule_wave(encounter: EncounterDefinition, wave_index: int) -> void:
	var wave: WaveDefinition = encounter.waves[wave_index]
	if wave.delay <= 0.0:
		_requested_waves[wave_index] = true
		wave_requested.emit(encounter.id, wave_index)
	else:
		_pending_waves[wave_index] = wave.delay


## The Wave of [param encounter] that already had its request and owns
## [param candidate_id], or -1 when the enemy belongs to no requested Wave.
func _owning_requested_wave_index(encounter: EncounterDefinition,
		candidate_id: StringName) -> int:
	for wave_index: int in range(encounter.waves.size()):
		if not _requested_waves.has(wave_index):
			continue
		for marker: NodePath in encounter.waves[wave_index].spawn_markers:
			if enemy_id(encounter.id, marker) == candidate_id:
				return wave_index
	return -1


## Whether every enemy of Wave [param wave_index] of [param encounter] was counted.
func _is_wave_defeated(encounter: EncounterDefinition, wave_index: int) -> bool:
	for marker: NodePath in encounter.waves[wave_index].spawn_markers:
		if not _counted.has(enemy_id(encounter.id, marker)):
			return false
	return true


## Whether [param encounter]'s completion condition holds: every Wave requested and
## every enemy counted, or every listed Objective recorded, plus the exit latch when
## `requires_exit`.
func _condition_holds(encounter: EncounterDefinition) -> bool:
	var satisfied: bool = false
	match encounter.completion:
		EncounterDefinition.Completion.ALL_REQUIRED_ENEMIES:
			satisfied = true
			for wave_index: int in range(encounter.waves.size()):
				if not _requested_waves.has(wave_index) \
						or not _is_wave_defeated(encounter, wave_index):
					satisfied = false
					break
		EncounterDefinition.Completion.OBJECTIVES:
			satisfied = true
			for objective_id: StringName in encounter.required_objective_ids:
				if not _objectives.has(objective_id):
					satisfied = false
					break
	if encounter.requires_exit and not _exit_latched:
		satisfied = false
	return satisfied


## Completes [param encounter], at most once: Gate, rewards, completion and, after the
## last Encounter, stage cleared, in that order.
func _complete(encounter: EncounterDefinition) -> void:
	if _states.get(encounter.id, State.INACTIVE) != State.ACTIVE:
		return
	_states[encounter.id] = State.COMPLETED
	_active_id = &""
	_clear_transient()
	if not encounter.gate_id.is_empty():
		gate_opened.emit(encounter.gate_id)
	if not encounter.rewards.is_empty() and not _rewarded.has(encounter.id):
		_rewarded[encounter.id] = true
		rewards_requested.emit(encounter.id)
	encounter_completed.emit(encounter.id)
	if _stage.encounter_index(encounter.id) == _stage.encounters.size() - 1:
		stage_cleared.emit()


## The resume Encounter of the latest activated Checkpoint in route order, or the
## first Encounter when no Checkpoint is activated.
func _resume_encounter_id() -> StringName:
	var best: StringName = &""
	var best_index: int = -1
	for checkpoint: CheckpointDefinition in _stage.checkpoints:
		if checkpoint == null or not _checkpoints.has(checkpoint.id):
			continue
		var resume_index: int = _stage.encounter_index(checkpoint.resume_encounter_id)
		if resume_index > best_index:
			best_index = resume_index
			best = checkpoint.resume_encounter_id
	if best.is_empty() and not _stage.encounters.is_empty() \
			and _stage.encounters[0] != null:
		best = _stage.encounters[0].id
	return best
