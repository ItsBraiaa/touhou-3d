class_name CheckpointStore
extends RefCounted
## Rules Core for the STAGE_DESIGN "Checkpoint contract": a Checkpoint's first
## activation refills the player's resources, commits the Attempt and records a
## [Snapshot]; a revisit does nothing; Retry restores the latest Snapshot; Restart
## discards every Checkpoint and returns to the stage-entry values. The
## ENGINEERING_BRIEF 4.H invariants live here: failed Attempts cannot farm score or
## inflate the Clear Time, restarting a stage differs from retrying a Checkpoint,
## and replaying a trigger does not refill resources.
##
## Node-free (ADR-0001). The Stage Director (F10-01) owns one of these, created in
## its [code]setup()[/code], and it survives Retry; Restart keeps F2-04's full stage
## reload, so F10 never calls [method restart_into] — it stays as the core-level
## proof that Restart differs from Retry, and for a reload-free Restart later. The
## Director reports a Checkpoint Area's entry through [method activate], answers
## Defeat's Retry offer with [method retry_into] (Restart when that returns false)
## and reads [method latest_checkpoint_id] for the retry location.


## The [Snapshot] of the latest activated Checkpoint of this stage, or null at Stage
## Entry, before any Checkpoint activated.
var _latest: Snapshot = null


## Activates the Checkpoint [param checkpoint_id] and returns whether this call did
## it. A false return changes nothing: while [param combat] is defeated or paused (a
## refill would be silently ignored), or when [param encounters] refuses the
## activation — the preceding Encounter is not complete, or the Checkpoint was
## already activated, so revisiting never refills again (STAGE_DESIGN). On the first
## activation it asks [param encounters] first, then refills [param combat] — full
## Health, the Shield and two Bombs, before anything is recorded — then commits the
## Attempt into [param run]'s committed statistics, then records
## [method Snapshot.capture_from] of all three cores as the latest. The bombs-used
## statistic survives the refill: it is committed before the record, and
## [method CombatState.refill] never touches it.
func activate(checkpoint_id: StringName, combat: CombatState, run: RunState,
		encounters: EncounterMachine) -> bool:
	if combat.is_defeated() or combat.is_paused():
		return false
	if not encounters.notify_checkpoint_entered(checkpoint_id):
		return false
	combat.refill()
	run.commit_checkpoint()
	_latest = Snapshot.capture_from(combat, run, encounters, checkpoint_id)
	return true


## The [Snapshot] of the latest activated Checkpoint of this stage, or null at Stage
## Entry, before any Checkpoint activated: Retry then means Restart.
func latest() -> Snapshot:
	return _latest


## The Checkpoint the latest [Snapshot] was recorded at, for Defeat's retry
## location; [code]&""[/code] before any Checkpoint activated.
func latest_checkpoint_id() -> StringName:
	if _latest == null:
		return &""
	return _latest.get_checkpoint_id()


## Restores the latest [Snapshot] into the three cores and returns true. Returns
## false and changes nothing while no Checkpoint has been activated in this stage:
## the caller Restarts instead (PLANEJAMENTO Section 6 — a death before the first
## intermediate Checkpoint restarts the stage). Never calls
## [method CombatState.refill]: the Snapshot was recorded after its Checkpoint's
## refill, so the restore already brings back full Health, the Shield and two Bombs,
## and a refill on a still-defeated or still-paused core would be dropped silently.
## The caller (F10-03) then calls [method RunState.begin_attempt] and
## [method CombatState.set_paused] with false, and removes the failed Attempt's
## actors, Projectiles, Pickups, locks and queued spawns on the scene side.
func retry_into(combat: CombatState, run: RunState, encounters: EncounterMachine) -> bool:
	if _latest == null:
		return false
	_latest.restore_into(combat, run, encounters)
	return true


## Begins the Restart flow from the stage-entry values, with no Checkpoint left:
## forgets every [Snapshot] with [method reset], returns [param run]'s statistics to
## the stage entry with [method RunState.restart_stage], restarts [param combat] at
## the stage's entry Power Level with [method CombatState.start], and returns
## [param encounters] to its setup state with [method EncounterMachine.reset]. F10
## never calls this: Restart keeps F2-04's full stage reload. It is the core-level
## proof that Restart differs from Retry, and the reload-free Restart for later.
func restart_into(combat: CombatState, run: RunState, encounters: EncounterMachine) -> void:
	reset()
	run.restart_stage()
	combat.start(run.starting_power_level())
	encounters.reset()


## Forgets every recorded [Snapshot] (Restart, stage load): a later Retry then means
## Restart.
func reset() -> void:
	_latest = null
