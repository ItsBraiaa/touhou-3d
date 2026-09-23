extends TestCase
## Behavior of the [RunState] Rules Core: stage order per Run Mode, the Attempt
## lifecycle, Active Time and Clear Time accounting, committed statistics under Retry
## and Restart, the Snapshot slice, and the lifecycle signals.
##
## Expected values come from the design documents, not from the implementation.
## PLANEJAMENTO Section 6: Campaign is Stage 1 then Stage 2 and carries Power and score;
## Direct Stage 2 starts at Power Level 2; score starts at zero in a Direct Stage.
## STAGE_DESIGN "Time and score integrity": Clear Time is the committed time through the
## last Checkpoint plus the Active Time since it, and Retry rolls the failed segment back.

const STEP := 1.0 / 60.0

var _run: RunState


func before_each() -> void:
	_run = RunState.new()


func test_campaign_plays_stage_1_then_stage_2_then_ends_in_victory() -> void:
	var started := signal_recorder(_run, &"stage_started")
	var completed := signal_recorder(_run, &"stage_completed")
	var ended := signal_recorder(_run, &"run_ended")
	_run.start(RunState.RunMode.CAMPAIGN, &"stage_01")
	assert_eq(started.emissions, [[&"stage_01"]])
	assert_eq(_run.get_phase(), RunState.Phase.IN_STAGE)
	_run.begin_attempt()
	_run.complete_stage()
	assert_eq(_run.get_phase(), RunState.Phase.STAGE_COMPLETE)
	assert_eq(completed.count(), 1)
	var first: Dictionary = completed.last()[0]
	assert_eq(first["stage"], &"stage_01")
	assert_eq(first["mode"], RunState.RunMode.CAMPAIGN)
	assert_false(first["is_final"], "Stage 2 still follows")

	_run.advance(1)
	assert_eq(started.emissions, [[&"stage_01"], [&"stage_02"]])
	assert_eq(_run.get_phase(), RunState.Phase.IN_STAGE)
	assert_eq(ended.count(), 0, "advancing into Stage 2 does not end the run")
	_run.begin_attempt()
	_run.complete_stage()
	var second: Dictionary = completed.last()[0]
	assert_eq(second["stage"], &"stage_02")
	assert_true(second["is_final"], "Stage 2 is the last stage of the Campaign")

	_run.advance(1)
	assert_eq(ended.emissions, [[true]])
	assert_eq(_run.get_phase(), RunState.Phase.RUN_ENDED)
	assert_eq(started.count(), 2, "no third stage")


func test_direct_stage_2_is_one_stage_that_starts_at_power_level_2() -> void:
	var started := signal_recorder(_run, &"stage_started")
	var completed := signal_recorder(_run, &"stage_completed")
	var ended := signal_recorder(_run, &"run_ended")
	_run.start(RunState.RunMode.DIRECT_STAGE, &"stage_02")
	assert_eq(started.emissions, [[&"stage_02"]])
	assert_eq(_run.starting_power_level(), 2, "PLANEJAMENTO Section 6: direct Stage 2 starts at power level 2")
	_run.begin_attempt()
	_run.complete_stage()
	var result: Dictionary = completed.last()[0]
	assert_eq(result["mode"], RunState.RunMode.DIRECT_STAGE)
	assert_true(result["is_final"], "the only stage of a Direct Stage run is the last one")
	_run.advance(2)
	assert_eq(ended.emissions, [[true]])
	assert_eq(started.count(), 1, "a Direct Stage never continues into another stage")


func test_stage_1_starts_at_power_level_1_in_either_mode() -> void:
	_run.start(RunState.RunMode.CAMPAIGN, &"stage_01")
	assert_eq(_run.starting_power_level(), 1, "PLANEJAMENTO Section 6: Start begins at power level 1")
	_run.start(RunState.RunMode.DIRECT_STAGE, &"stage_01")
	assert_eq(_run.starting_power_level(), 1, "Direct Stage 1 uses the starting values")


func test_campaign_stage_2_starts_at_the_power_level_stage_1_ended_with() -> void:
	# 3 is not Stage 2's own entry value of 2, so a core that ignored the carried value
	# and used the Direct Stage entry would fail here.
	_run.start(RunState.RunMode.CAMPAIGN, &"stage_01")
	_run.begin_attempt()
	_run.complete_stage()
	_run.advance(3)
	assert_eq(_run.starting_power_level(), 3, "PLANEJAMENTO Section 6: campaign transitions preserve power")


func test_active_time_is_the_sum_of_the_physics_ticks_in_a_stage() -> void:
	_start_direct_attempt()
	_play(120)
	assert_almost_eq(_run.clear_time(), 2.0, 0.0001, "120 ticks of 1/60 s")


func test_paused_ticks_add_no_active_time() -> void:
	# CONTEXT "Active Time": pauses and menus do not count. The adapter stops ticking
	# while the tree is paused, and the core refuses anyway (CONVENTIONS "Time and
	# randomness").
	_start_direct_attempt()
	_play(60)
	_run.set_paused(true)
	_play(90)
	assert_almost_eq(_run.clear_time(), 1.0, 0.0001, "the 90 paused ticks are ignored")
	_run.set_paused(false)
	_play(60)
	assert_almost_eq(_run.clear_time(), 2.0, 0.0001, "time resumes after unpausing")


func test_ticks_before_a_run_starts_add_no_active_time() -> void:
	_play(120)
	_start_direct_attempt()
	assert_almost_eq(_run.clear_time(), 0.0, 0.0001, "ticks in IDLE are not carried into the stage")


func test_clear_time_is_committed_time_plus_the_current_attempt() -> void:
	# CONTEXT "Clear Time", and STAGE_DESIGN "Retry always uses the latest activated
	# checkpoint. Restart Stage explicitly discards checkpoint progress".
	_start_direct_attempt()
	_play(600)
	_run.commit_checkpoint()
	_play(300)
	assert_almost_eq(_run.clear_time(), 15.0, 0.0001, "10 s committed at the Checkpoint plus 5 s since")
	_run.rollback_attempt()
	assert_almost_eq(_run.clear_time(), 10.0, 0.0001, "Retry drops the failed segment's 5 s")
	_run.restart_stage()
	assert_almost_eq(_run.clear_time(), 0.0, 0.0001, "Restart drops the committed 10 s too")


func test_score_and_graze_are_committed_and_rolled_back_like_time() -> void:
	# PLANEJAMENTO Section 6: "Failed attempts do not accumulate points". Two enemies at
	# 100 and three Grazes before the Checkpoint, one enemy and two Grazes after it.
	_start_direct_attempt()
	_run.add_score(100)
	_run.add_score(100)
	_run.add_graze()
	_run.add_graze()
	_run.add_graze()
	_run.commit_checkpoint()
	_run.add_score(100)
	_run.add_graze(2)
	assert_eq(_run.stage_result()["score"], 300)
	assert_eq(_run.stage_result()["graze"], 5)
	_run.rollback_attempt()
	assert_eq(_run.stage_result()["score"], 200, "Retry keeps only what the Checkpoint committed")
	assert_eq(_run.stage_result()["graze"], 3)
	_run.restart_stage()
	assert_eq(_run.stage_result()["score"], 0, "Restart returns to the Direct Stage entry score of zero")
	assert_eq(_run.stage_result()["graze"], 0)


func test_bombs_used_survive_a_checkpoint_and_roll_back_with_a_failed_attempt() -> void:
	# STAGE_DESIGN "Checkpoint contract": the refill at a Checkpoint "does not erase the
	# bombs-used statistic".
	_start_direct_attempt()
	_run.note_bomb_used()
	_run.commit_checkpoint()
	assert_eq(_run.stage_result()["bombs_used"], 1, "committed at the Checkpoint")
	_run.note_bomb_used()
	assert_eq(_run.stage_result()["bombs_used"], 2)
	_run.rollback_attempt()
	assert_eq(_run.stage_result()["bombs_used"], 1, "the failed Attempt's bomb is not counted")
	_run.restart_stage()
	assert_eq(_run.stage_result()["bombs_used"], 0)


func test_campaign_stage_2_carries_the_score_and_starts_its_own_time_graze_and_bombs() -> void:
	# PLANEJAMENTO Section 5, "Score is a run result", and Section 6, "Campaign
	# transitions preserve power and score". Clear Time, Graze and bombs used are
	# results of one stage.
	_run.start(RunState.RunMode.CAMPAIGN, &"stage_01")
	_run.begin_attempt()
	_play(60)
	_run.add_score(1000)
	_run.add_graze(4)
	_run.note_bomb_used()
	_run.complete_stage()
	_run.advance(1)
	_run.begin_attempt()
	var entry := _run.stage_result()
	assert_eq(entry["score"], 1000, "Stage 2 starts with Stage 1's score")
	assert_almost_eq(entry["clear_time"], 0.0)
	assert_eq(entry["graze"], 0)
	assert_eq(entry["bombs_used"], 0)
	_run.add_score(100)
	_run.commit_checkpoint()
	_run.add_score(100)
	_run.restart_stage()
	assert_eq(_run.stage_result()["score"], 1000, "Restart returns to Stage 2's entry score, not to zero")


func test_a_new_run_starts_from_zero() -> void:
	# PLANEJAMENTO Section 6: in a Direct Stage "Score starts at zero".
	_start_direct_attempt()
	_play(60)
	_run.add_score(500)
	_run.add_graze()
	_run.note_bomb_used()
	_run.commit_checkpoint()
	# Pause, then Return to Menu, then a new start from the menu.
	_run.set_paused(true)
	_run.end_run()
	_run.start(RunState.RunMode.DIRECT_STAGE, &"stage_02")
	assert_false(_run.is_paused(), "the old Run's pause does not reach the new one")
	assert_eq(_run.get_attempt_index(), 0)
	_run.begin_attempt()
	var entry := _run.stage_result()
	assert_eq(entry["score"], 0)
	assert_almost_eq(entry["clear_time"], 0.0)
	assert_eq(entry["graze"], 0)
	assert_eq(entry["bombs_used"], 0)


func test_begin_attempt_counts_the_attempt_and_starts_it_clean_and_unpaused() -> void:
	_run.start(RunState.RunMode.CAMPAIGN, &"stage_01")
	assert_eq(_run.get_attempt_index(), 0, "start() has not begun an Attempt yet")
	_run.begin_attempt()
	assert_eq(_run.get_attempt_index(), 1)
	_play(60)
	_run.add_score(100)
	_run.set_paused(true)
	_run.begin_attempt()
	assert_eq(_run.get_attempt_index(), 2, "a Retry is a new Attempt")
	assert_false(_run.is_paused())
	assert_almost_eq(_run.clear_time(), 0.0, 0.0001, "nothing was committed, so nothing is kept")
	assert_eq(_run.stage_result()["score"], 0)
	_play(60)
	assert_almost_eq(_run.clear_time(), 1.0, 0.0001, "the new Attempt accumulates at once")
	# STAGE_DESIGN asks each stage-clear test to record whether Checkpoints were retried,
	# so Attempts are counted per stage.
	_run.complete_stage()
	_run.advance(1)
	assert_eq(_run.get_attempt_index(), 0, "Stage 2 has not begun an Attempt yet")
	_run.begin_attempt()
	assert_eq(_run.get_attempt_index(), 1)


func test_paused_changed_fires_only_when_the_flag_changes() -> void:
	var paused := signal_recorder(_run, &"paused_changed")
	_start_direct_attempt()
	assert_eq(paused.count(), 0, "starting unpaused changes nothing")
	_run.set_paused(true)
	_run.set_paused(true)
	assert_eq(paused.emissions, [[true]])
	_run.set_paused(false)
	_run.set_paused(false)
	assert_eq(paused.emissions, [[true], [false]])
	_run.begin_attempt()
	assert_eq(paused.count(), 2, "an Attempt begun unpaused changes nothing")
	_run.set_paused(true)
	_run.begin_attempt()
	assert_eq(paused.emissions, [[true], [false], [true], [false]], "an Attempt begun while paused unpauses once")


func test_repeated_lifecycle_calls_report_each_transition_once() -> void:
	# A Boss defeat or a Pause-menu action can arrive twice; the Session must not see
	# two completions or two endings.
	var started := signal_recorder(_run, &"stage_started")
	var completed := signal_recorder(_run, &"stage_completed")
	var ended := signal_recorder(_run, &"run_ended")
	_run.end_run()
	assert_eq(ended.count(), 0, "there is no Run to end before start()")
	_run.advance(1)
	assert_eq(started.count(), 0, "there is no completed stage to leave before start()")
	_run.start(RunState.RunMode.CAMPAIGN, &"stage_01")
	_run.begin_attempt()
	_run.advance(1)
	assert_eq(started.count(), 1, "advance() while the stage is still in play does nothing")
	_run.complete_stage()
	_run.complete_stage()
	assert_eq(completed.count(), 1)
	_run.advance(1)
	_run.advance(1)
	assert_eq(started.emissions, [[&"stage_01"], [&"stage_02"]], "one advance, not two")
	_run.end_run()
	_run.end_run(true)
	assert_eq(ended.emissions, [[false]], "Return to Menu ends the Run once, without a victory")
	_run.complete_stage()
	assert_eq(completed.count(), 1, "an ended Run completes nothing")


func test_a_completed_stage_result_no_longer_changes() -> void:
	# Projectiles still in flight can Graze after the Boss falls; what stage_completed
	# reported must stay what advance() carries and what results show.
	var completed := signal_recorder(_run, &"stage_completed")
	_run.start(RunState.RunMode.CAMPAIGN, &"stage_01")
	_run.begin_attempt()
	_play(60)
	_run.add_score(1000)
	_run.complete_stage()
	var reported: Dictionary = completed.last()[0]
	_play(60)
	_run.add_score(100)
	_run.add_graze()
	_run.note_bomb_used()
	_run.commit_checkpoint()
	_run.rollback_attempt()
	_run.restart_stage()
	_run.begin_attempt()
	assert_eq(_run.stage_result(), reported)
	assert_eq(_run.get_attempt_index(), 1, "no Attempt begins after the stage is complete")
	_run.advance(1)
	assert_eq(_run.stage_result()["score"], 1000, "Stage 2 carries the reported score")


func test_a_capture_is_not_changed_by_later_play() -> void:
	# CONVENTIONS "Snapshots": a Snapshot cannot change after it is taken.
	_run.start(RunState.RunMode.CAMPAIGN, &"stage_01")
	_run.begin_attempt()
	_play(600)
	_run.add_score(300)
	_run.commit_checkpoint()
	var captured := _run.capture()
	var expected := captured.duplicate(true)
	_play(300)
	_run.add_score(100)
	_run.commit_checkpoint()
	_run.complete_stage()
	_run.advance(2)
	_run.start(RunState.RunMode.DIRECT_STAGE, &"stage_02")
	assert_eq(captured, expected)


func test_editing_a_capture_does_not_reach_the_core() -> void:
	_run.start(RunState.RunMode.CAMPAIGN, &"stage_01")
	_run.begin_attempt()
	var captured := _run.capture()
	var kept := captured.duplicate(true)
	_clear_collections(captured)
	# Compared before anything indexes the stage order: an aliased, emptied order would
	# otherwise abort the test with a runtime error the runner does not count.
	if not assert_eq(_run.capture(), kept, "the core's stage order is its own"):
		return
	_run.complete_stage()
	_run.advance(1)
	assert_eq(_run.stage_result()["stage"], &"stage_02", "the core's stage order is its own")


func test_restore_resumes_at_the_captured_checkpoint() -> void:
	# ENGINEERING_BRIEF Section 4.H: failed attempts cannot farm score or inflate the
	# duration, and Restart differs from Retry. Captured in Campaign Stage 2, so the
	# entry values are not the defaults: Power Level 3 and a score of 1000 carried in.
	_run.start(RunState.RunMode.CAMPAIGN, &"stage_01")
	_run.begin_attempt()
	_run.add_score(1000)
	_run.complete_stage()
	_run.advance(3)
	_run.begin_attempt()
	_play(600)
	_run.add_score(200)
	_run.add_graze(4)
	_run.note_bomb_used()
	_run.commit_checkpoint()
	var captured := _run.capture()
	_play(300)
	_run.add_score(500)
	_run.add_graze(9)
	_run.note_bomb_used()

	_run.restore(captured)
	_assert_stage_2_checkpoint(_run, "restored in place")

	var fresh := RunState.new()
	fresh.restore(captured)
	var kept := captured.duplicate(true)
	_clear_collections(captured)
	if not assert_eq(fresh.capture(), kept, "restore() copies its input instead of keeping it"):
		return
	_assert_stage_2_checkpoint(fresh, "restored into a new core")
	assert_eq(fresh.get_phase(), RunState.Phase.IN_STAGE)
	assert_eq(fresh.starting_power_level(), 3)
	fresh.restart_stage()
	assert_eq(fresh.stage_result()["score"], 1000, "Restart after a restore still knows the entry score")
	fresh.complete_stage()
	var ended := signal_recorder(fresh, &"run_ended")
	fresh.advance(3)
	assert_eq(ended.emissions, [[true]], "Stage 2 is still the last stage of the restored order")


## Checks the values [method test_restore_resumes_at_the_captured_checkpoint] captured.
func _assert_stage_2_checkpoint(run: RunState, context: String) -> void:
	var result := run.stage_result()
	assert_eq(result["stage"], &"stage_02", context)
	assert_eq(result["mode"], RunState.RunMode.CAMPAIGN, context)
	assert_almost_eq(result["clear_time"], 10.0, 0.0001, context)
	assert_eq(result["score"], 1200, context)
	assert_eq(result["graze"], 4, context)
	assert_eq(result["bombs_used"], 1, context)


## Empties every Array and Dictionary held in [param data], as a careless owner of a
## capture might, without depending on its key names.
func _clear_collections(data: Dictionary) -> void:
	for value: Variant in data.values():
		if value is Array:
			(value as Array).clear()
		elif value is Dictionary:
			(value as Dictionary).clear()


## Starts a Direct Stage 1 Run and its first Attempt.
func _start_direct_attempt() -> void:
	_run.start(RunState.RunMode.DIRECT_STAGE, &"stage_01")
	_run.begin_attempt()


## Ticks [param ticks] physics steps of [constant STEP] seconds, as the Session does.
func _play(ticks: int) -> void:
	for _tick: int in range(ticks):
		_run.tick_active(STEP)
