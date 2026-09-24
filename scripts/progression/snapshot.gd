class_name Snapshot
extends RefCounted
## Value object for one recorded point of the Run (CONVENTIONS "Snapshots"): an
## immutable deep copy of the three core captures — [class CombatState],
## [class RunState] and [class EncounterMachine] — beside the Checkpoint it was
## recorded at ([code]&""[/code] at Stage Entry). It holds only primitives, packed
## arrays and Dictionaries of those, and never references a Node or a live core:
## nothing that happens later can change it, and restoring it never changes it
## either.
##
## [class CheckpointStore] (F8-03) is the only writer. The Session and the Stage
## Director never touch the slices directly: they restore through
## [method restore_into] and read through the getters. [method to_dict] and
## [method Snapshot.from_dict] exist for tests and equality.


## The Checkpoint this Snapshot was recorded at; [code]&""[/code] at Stage Entry.
var _checkpoint_id: StringName = &""
## A [code]duplicate(true)[/code] copy of [method CombatState.capture] at the record
## point: `health`, `has_shield`, `bombs`, `power_level`, `power_progress`.
var _combat: Dictionary = {}
## A [code]duplicate(true)[/code] copy of [method RunState.capture] at the record
## point: the Run Mode, stage order and position, the entry values and the committed
## statistics.
var _run: Dictionary = {}
## A [code]duplicate(true)[/code] copy of [method EncounterMachine.capture] at the
## record point: the completed, rewarded, Objective and Checkpoint flags and the
## resume Encounter.
var _encounters: Dictionary = {}


## Records the three cores as they are right now, at Checkpoint [param checkpoint_id]
## ([code]&""[/code] at Stage Entry), and returns the new Snapshot. Each
## [code]capture()[/code] result is kept as a [code]duplicate(true)[/code] copy, so
## nothing the cores do later changes what was recorded (CONVENTIONS "Snapshots").
static func capture_from(combat: CombatState, run: RunState,
		encounters: EncounterMachine, checkpoint_id: StringName = &"") -> Snapshot:
	var snapshot: Snapshot = Snapshot.new()
	snapshot._checkpoint_id = checkpoint_id
	snapshot._combat = combat.capture().duplicate(true)
	snapshot._run = run.capture().duplicate(true)
	snapshot._encounters = encounters.capture().duplicate(true)
	return snapshot


## Puts the three slices back into the live cores, in the order the Retry flow calls
## them: [method CombatState.restore], then [method RunState.restore], then
## [method EncounterMachine.restore]. Each receives a fresh deep copy of its slice,
## so the same Snapshot can be restored any number of times and restoring never
## changes it. The caller (F10-03) then calls [method RunState.begin_attempt] and
## [method CombatState.set_paused] with false, and removes the failed Attempt's
## actors, Projectiles, Pickups, locks and queued spawns on the scene side.
func restore_into(combat: CombatState, run: RunState, encounters: EncounterMachine) -> void:
	assert(not _run.is_empty(), "Snapshot: restore_into needs a captured Snapshot")
	combat.restore(_combat.duplicate(true))
	run.restore(_run.duplicate(true))
	encounters.restore(_encounters.duplicate(true))


## The Checkpoint this Snapshot was recorded at; [code]&""[/code] at Stage Entry.
func get_checkpoint_id() -> StringName:
	return _checkpoint_id


## The Stage this Snapshot was recorded in, from the Run slice's
## [code]stage_order[stage_index][/code]; [code]&""[/code] when no Stage is in it.
func get_stage_id() -> StringName:
	var order: Array = _run.get("stage_order", [])
	var index: int = _run.get("stage_index", 0)
	if index < 0 or index >= order.size():
		return &""
	return order[index]


## The Encounter the Run resumes at, from the Encounters slice's
## [code]resume_encounter_id[/code]: the resume Encounter of the Checkpoint this
## Snapshot was recorded at, or the first Encounter at Stage Entry.
func get_resume_encounter_id() -> StringName:
	return StringName(String(_encounters.get("resume_encounter_id", "")))


## This Snapshot as a new Dictionary [code]{checkpoint_id, combat, run, encounters}[/code],
## every slice a deep copy: the result shares nothing with this Snapshot in either
## direction. Exists for tests and equality (CONVENTIONS "Snapshots").
func to_dict() -> Dictionary:
	return {
		"checkpoint_id": _checkpoint_id,
		"combat": _combat.duplicate(true),
		"run": _run.duplicate(true),
		"encounters": _encounters.duplicate(true),
	}


## Rebuilds the Snapshot that [method to_dict] returned, deep-copying every slice of
## [param data] so the result shares nothing with it. Exists for tests and equality
## (CONVENTIONS "Snapshots").
static func from_dict(data: Dictionary) -> Snapshot:
	var combat: Dictionary = data["combat"]
	var run: Dictionary = data["run"]
	var encounters: Dictionary = data["encounters"]
	var snapshot: Snapshot = Snapshot.new()
	snapshot._checkpoint_id = StringName(String(data["checkpoint_id"]))
	snapshot._combat = combat.duplicate(true)
	snapshot._run = run.duplicate(true)
	snapshot._encounters = encounters.duplicate(true)
	return snapshot
