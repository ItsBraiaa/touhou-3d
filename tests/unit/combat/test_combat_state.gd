extends TestCase
## Behavior of the [CombatState] Rules Core: Health, the one-charge shield, post-hit and
## Bomb invulnerability, Bomb charges and the Bomb input edge, Power level and partial
## progress, the Checkpoint refill, capture and restore, and the change signals.
##
## Expected values come from the design documents, not from the implementation.
## PLANEJAMENTO Section 4: a common bullet deals 10 percentage points of Health; a
## one-charge shield absorbs one complete hit and excess damage does not reach Health;
## post-hit invulnerability lasts 1 second; two Bomb charges per stage, each activation
## consumes one and grants 2 seconds of invulnerability, never while paused or defeated;
## five Power Pickups per level up to level 3, then 50 points per excess pickup; taking
## damage does not reduce Power. PLANEJAMENTO Section 6: a stage begins at 100% Health,
## one shield, two bombs and Power Level 1, Direct Stage 2 at Power Level 2, and Campaign
## transitions keep Power. ENGINEERING_BRIEF Sections 4.C and 8 list the invariants.
## STAGE_DESIGN "Checkpoint contract": a refill restores Health, shield and bombs; Retry
## restores the saved Power and progress and removes damage timers.

var _state: CombatState


func before_each() -> void:
	_state = CombatState.new()


func test_new_state_holds_the_stage_entry_resources() -> void:
	# PLANEJAMENTO Section 6: "Start begins the campaign at Stage 1 with 100% health, one
	# shield, two bombs, and power level 1".
	assert_eq(_state.get_health(), 100)
	assert_true(_state.has_shield(), "one shield")
	assert_eq(_state.get_bombs(), 2, "two bombs")
	assert_eq(_state.get_power_level(), 1)
	assert_eq(_state.get_power_progress(), 0)
	assert_false(_state.is_invulnerable())
	assert_false(_state.is_defeated())
	assert_false(_state.is_paused())
	assert_false(_state.update_bomb_input(true), "a new core treats the bomb button as already held")
	assert_eq(_state.get_bombs(), 2)


func test_start_sets_the_power_level_and_refills_everything() -> void:
	# A spent life: a Bomb, the shield, all Health, and some Power progress.
	assert_true(_press_bomb(), "setup: the first Bomb goes off")
	_state.collect_power_pickup()
	_state.tick(2.0)
	_break_shield()
	assert_eq(_state.take_hit(100), CombatState.HitOutcome.DEFEATED, "setup")
	_state.set_paused(true)
	_state.update_bomb_input(false)

	# PLANEJAMENTO Section 6: "direct Stage 2 starts at power level 2, 100% health, one
	# shield, and two bombs".
	_state.start(2)
	assert_eq(_state.get_health(), 100)
	assert_true(_state.has_shield())
	assert_eq(_state.get_bombs(), 2)
	assert_eq(_state.get_power_level(), 2)
	assert_eq(_state.get_power_progress(), 0, "the progress gained in the old life is gone")
	assert_false(_state.is_defeated(), "stage entry begins a new life")
	assert_false(_state.is_paused(), "stage entry unpauses")
	assert_false(_state.update_bomb_input(true), "start() treats the bomb button as held, even after a release")
	assert_eq(_state.get_bombs(), 2)

	# PLANEJAMENTO Section 6: "Campaign transitions preserve power and score while
	# restoring health, shield, and two bombs"; the partial progress is part of Power.
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED, "setup: the shield breaks")
	_state.start(2, 3)
	assert_eq(_state.get_power_level(), 2)
	assert_eq(_state.get_power_progress(), 3)
	assert_true(_state.has_shield())
	assert_false(_state.is_invulnerable(), "stage entry clears the post-hit invulnerability")
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED, "hits are accepted at once after start()")
	assert_eq(_collect_power_pickups(2), 2)
	assert_eq(_state.get_power_level(), 3, "the carried progress of 3 plus 2 pickups completes the level")
	assert_eq(_state.get_power_progress(), 0)


func test_shielded_hit_never_damages_health() -> void:
	# ENGINEERING_BRIEF 4.C invariant: "a shielded hit never damages health".
	var health := signal_recorder(_state, &"health_changed")
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED)
	assert_eq(_state.get_health(), 100, "a shielded hit never damages health")
	assert_false(_state.has_shield(), "PLANEJAMENTO Section 4: the shield has one charge")
	assert_true(_state.is_invulnerable(), "PLANEJAMENTO Section 4: a shield break grants invulnerability")
	_state.tick(1.0)
	assert_true(_state.collect_shield_pickup(), "setup: the shield is restored")
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED)
	assert_eq(_state.get_health(), 100, "a restored shield protects Health the same way")
	assert_eq(health.count(), 0)


func test_shield_absorbs_a_hit_of_any_size() -> void:
	# PLANEJAMENTO Section 4: "A one-charge shield absorbs one complete hit; excess damage
	# does not reach health". 250 is more than the whole Health bar.
	assert_eq(_state.take_hit(250), CombatState.HitOutcome.ABSORBED)
	assert_eq(_state.get_health(), 100, "excess damage does not reach Health")
	assert_false(_state.is_defeated())


func test_unshielded_hit_deals_its_damage() -> void:
	_break_shield()
	assert_eq(_state.take_hit(), CombatState.HitOutcome.DAMAGED)
	assert_eq(_state.get_health(), 90, "PLANEJAMENTO Section 4: a common bullet deals 10 percentage points")
	assert_true(_state.is_invulnerable(), "PLANEJAMENTO Section 4: damage grants invulnerability")
	_state.tick(1.0)
	assert_eq(_state.take_hit(25), CombatState.HitOutcome.DAMAGED)
	assert_eq(_state.get_health(), 65, "a hit deals the damage it carries")


func test_invulnerability_rejects_follow_up_hits() -> void:
	# ENGINEERING_BRIEF 4.C invariant: "invulnerability rejects immediate follow-up hits".
	# The shield is gone after the first hit, so an accepted follow-up would cost Health.
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED, "a follow-up right after a shield break")
	_state.tick(0.5)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED, "half a second into the 1 s window")
	assert_eq(_state.get_health(), 100)
	_state.tick(0.5)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.DAMAGED, "setup: the window has ended")
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED, "a follow-up right after damage")
	_state.tick(0.5)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED)
	assert_eq(_state.get_health(), 90, "only the first unshielded hit cost Health")


func test_hits_land_again_once_invulnerability_ends() -> void:
	# PLANEJAMENTO Section 4: "post-hit invulnerability lasts 1 second".
	var invulnerable := signal_recorder(_state, &"invulnerability_changed")
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED)
	_state.tick(0.5)
	assert_true(_state.is_invulnerable(), "0.5 s of the 1 s window")
	_state.tick(0.5)
	assert_false(_state.is_invulnerable(), "the window ends at 1 s")
	assert_eq(invulnerable.emissions, [[true], [false]])
	assert_eq(_state.take_hit(), CombatState.HitOutcome.DAMAGED)
	for _quarter: int in range(3):
		_state.tick(0.25)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED, "0.75 s into the second window")
	_state.tick(0.25)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.DAMAGED, "four quarters make the full second")
	assert_eq(_state.get_health(), 80)


func test_two_hits_in_one_tick_count_once() -> void:
	# ENGINEERING_BRIEF 4.C: "deterministic ordering for multiple collisions in one frame".
	# Contacts are applied in call order and the first accepted one starts invulnerability.
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED, "the second contact meets the first one's invulnerability")
	assert_eq(_state.get_health(), 100)
	_state.tick(1.0)
	assert_eq(_state.take_hit(10), CombatState.HitOutcome.DAMAGED)
	assert_eq(_state.take_hit(50), CombatState.HitOutcome.REJECTED)
	assert_eq(_state.get_health(), 90, "only the first hit in call order lands")

	var other_order := CombatState.new()
	other_order.take_hit()
	other_order.tick(1.0)
	assert_eq(other_order.take_hit(50), CombatState.HitOutcome.DAMAGED)
	assert_eq(other_order.take_hit(10), CombatState.HitOutcome.REJECTED)
	assert_eq(other_order.get_health(), 50, "the same two contacts in the other order")


func test_invulnerability_does_not_count_down_while_paused() -> void:
	# CONTEXT "Active Time": pauses do not count, so a pause cannot spend a damage timer.
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED)
	_state.set_paused(true)
	_state.tick(1.0)
	_state.tick(1.0)
	_state.set_paused(false)
	assert_true(_state.is_invulnerable(), "two paused seconds spent none of the window")
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED)
	_state.tick(0.5)
	assert_true(_state.is_invulnerable())
	_state.tick(0.5)
	assert_false(_state.is_invulnerable(), "one unpaused second ends it")
	assert_eq(_state.take_hit(), CombatState.HitOutcome.DAMAGED)


func test_paused_state_rejects_hits_and_pickups() -> void:
	_break_shield()
	_state.set_paused(true)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED, "no damage while paused")
	assert_eq(_state.get_health(), 100)
	assert_false(_state.collect_power_pickup(), "no Power Pickup while paused")
	assert_eq(_state.get_power_progress(), 0)
	assert_false(_state.collect_shield_pickup(), "no Shield Pickup while paused")
	assert_false(_state.has_shield())
	_state.set_paused(false)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.DAMAGED, "hits land again after unpausing")
	assert_true(_state.collect_power_pickup())
	assert_eq(_state.get_power_progress(), 1)
	assert_true(_state.collect_shield_pickup())


func test_power_never_decreases_on_damage() -> void:
	# ENGINEERING_BRIEF 4.C invariant: "power does not decrease on damage"; PLANEJAMENTO
	# Section 4: "Taking damage does not reduce power".
	_state.start(2, 3)
	var power := signal_recorder(_state, &"power_changed")
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED)
	assert_eq(_state.get_power_level(), 2, "a shield break keeps Power")
	assert_eq(_state.get_power_progress(), 3)
	_state.tick(1.0)
	assert_eq(_state.take_hit(50), CombatState.HitOutcome.DAMAGED)
	assert_eq(_state.get_power_level(), 2, "damage keeps the level")
	assert_eq(_state.get_power_progress(), 3, "damage keeps the partial progress")
	_state.tick(1.0)
	assert_eq(_state.take_hit(50), CombatState.HitOutcome.DEFEATED)
	assert_eq(_state.get_power_level(), 2, "not even the defeating hit reduces Power")
	assert_eq(_state.get_power_progress(), 3)
	assert_eq(power.count(), 0)


func test_health_stops_at_zero_and_defeat_fires_exactly_once() -> void:
	# ENGINEERING_BRIEF 4.C: "exactly-once defeat".
	_break_shield()
	var defeats := signal_recorder(_state, &"defeated")
	var order: Array[String] = []
	_state.health_changed.connect(func(value: int) -> void: order.append("health_changed(%d)" % value))
	_state.defeated.connect(func() -> void: order.append("defeated()"))
	assert_eq(_state.take_hit(150), CombatState.HitOutcome.DEFEATED)
	assert_eq(_state.get_health(), 0, "Health is a 0..100 percentage and never goes negative")
	assert_true(_state.is_defeated())
	assert_false(_state.is_invulnerable(), "a defeating hit starts no invulnerability")
	assert_eq(order, ["health_changed(0)", "defeated()"], "the HUD sees 0% before the defeat is reported")
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED)
	_state.tick(1.0)
	assert_eq(_state.take_hit(10), CombatState.HitOutcome.REJECTED)
	assert_eq(_state.get_health(), 0)
	assert_eq(defeats.count(), 1, "defeat is reported once per life")


func test_defeated_state_accepts_nothing() -> void:
	assert_true(_press_bomb(), "setup: one Bomb spent")
	_state.tick(2.0)
	_break_shield()
	assert_eq(_state.take_hit(100), CombatState.HitOutcome.DEFEATED, "setup")
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED)
	assert_false(_state.collect_power_pickup())
	assert_eq(_state.get_power_progress(), 0)
	assert_false(_state.collect_shield_pickup())
	assert_false(_state.has_shield())
	_state.refill()
	assert_eq(_state.get_health(), 0, "a defeated player is not refilled")
	assert_false(_state.has_shield())
	assert_eq(_state.get_bombs(), 1)
	_state.tick(1.0)
	assert_true(_state.is_defeated(), "nothing but start() or restore() ends the defeat")


func test_one_press_consumes_one_bomb() -> void:
	# ENGINEERING_BRIEF 4.C invariant: "one press consumes one bomb"; PLANEJAMENTO
	# Section 4: "Each activation consumes one charge".
	var activated := signal_recorder(_state, &"bomb_activated")
	assert_true(_press_bomb())
	assert_eq(_state.get_bombs(), 1)
	# The button stays down for 3 s of ticks, past the end of the Bomb's invulnerability.
	var repeats := 0
	for _quarter: int in range(12):
		if _state.update_bomb_input(true):
			repeats += 1
		_state.tick(0.25)
	assert_eq(repeats, 0, "holding the button does not fire again")
	assert_eq(_state.get_bombs(), 1, "one press, one charge")
	assert_eq(activated.count(), 1)
	assert_false(_state.update_bomb_input(false), "a release activates nothing")
	assert_true(_state.update_bomb_input(true), "a new press is a new Bomb")
	assert_eq(_state.get_bombs(), 0)
	assert_eq(activated.count(), 2)


func test_bomb_grants_two_seconds_of_invulnerability() -> void:
	# PLANEJAMENTO Section 4: a Bomb "initially grant[s] 2 seconds of invulnerability".
	assert_true(_press_bomb())
	assert_true(_state.is_invulnerable())
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED)
	assert_true(_state.has_shield(), "a hit during the Bomb does not break the shield")
	_state.tick(1.5)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED, "1.5 s of the 2 s window")
	_state.tick(0.5)
	assert_false(_state.is_invulnerable())
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED, "hits land again after 2 s")

	# A Bomb during the 1 s post-hit window still grants its full 2 seconds.
	var invulnerable := signal_recorder(_state, &"invulnerability_changed")
	_state.tick(0.5)
	assert_true(_press_bomb())
	assert_eq(invulnerable.count(), 0, "already invulnerable, so nothing changed")
	_state.tick(1.5)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED, "the post-hit window alone would have ended")
	_state.tick(0.5)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.DAMAGED)
	assert_eq(invulnerable.emissions, [[false], [true]])


func test_bombs_cannot_activate_while_paused() -> void:
	# ENGINEERING_BRIEF 4.C invariant and PLANEJAMENTO Section 4: "Bombs cannot activate
	# while paused". The release is seen while paused, so the press is a real edge.
	var activated := signal_recorder(_state, &"bomb_activated")
	_state.set_paused(true)
	assert_false(_state.update_bomb_input(false))
	assert_false(_state.update_bomb_input(true), "a press while paused")
	assert_eq(_state.get_bombs(), 2)
	assert_false(_state.is_invulnerable())
	assert_eq(activated.count(), 0)
	_state.set_paused(false)
	assert_true(_press_bomb(), "a new press after unpausing")
	assert_eq(_state.get_bombs(), 1)


func test_press_begun_while_paused_does_not_bomb_on_resume() -> void:
	# B is Back on the Pause menu and resumes the game; the press that closed the menu
	# must not also fire a Bomb.
	_state.update_bomb_input(false)
	_state.set_paused(true)
	assert_false(_state.update_bomb_input(true))
	_state.set_paused(false)
	assert_false(_state.update_bomb_input(true), "the press begun while paused is still held")
	assert_eq(_state.get_bombs(), 2)

	# The adapter may not tick at all while the tree is paused.
	_state.update_bomb_input(false)
	_state.set_paused(true)
	_state.set_paused(false)
	assert_false(_state.update_bomb_input(true), "pausing marks the button as held")
	assert_eq(_state.get_bombs(), 2)

	assert_false(_state.update_bomb_input(false))
	assert_true(_state.update_bomb_input(true), "a release, then a fresh press")
	assert_eq(_state.get_bombs(), 1)


func test_bombs_cannot_activate_while_defeated() -> void:
	# ENGINEERING_BRIEF 4.C invariant and PLANEJAMENTO Section 4: "Bombs cannot activate
	# while paused or defeated".
	var activated := signal_recorder(_state, &"bomb_activated")
	_break_shield()
	assert_eq(_state.take_hit(100), CombatState.HitOutcome.DEFEATED, "setup")
	assert_false(_state.update_bomb_input(false))
	assert_false(_state.update_bomb_input(true), "a fresh press while defeated")
	assert_eq(_state.get_bombs(), 2)
	assert_false(_state.is_invulnerable())
	assert_eq(activated.count(), 0)


func test_no_bomb_without_charges() -> void:
	# PLANEJAMENTO Section 4: two charges per stage and no Bomb pickups in this delivery.
	var activated := signal_recorder(_state, &"bomb_activated")
	var bombs := signal_recorder(_state, &"bombs_changed")
	assert_true(_press_bomb())
	assert_true(_press_bomb())
	_state.tick(2.0)
	assert_false(_press_bomb(), "no charge left")
	assert_eq(_state.get_bombs(), 0, "charges never go negative")
	assert_false(_state.is_invulnerable(), "an empty press grants no invulnerability")
	assert_eq(activated.count(), 2)
	assert_eq(bombs.emissions, [[1], [0]])


func test_five_power_pickups_raise_the_power_level() -> void:
	# PLANEJAMENTO Section 4: "five power pickups per level increase".
	var power := signal_recorder(_state, &"power_changed")
	assert_eq(_collect_power_pickups(4), 4)
	assert_eq(_state.get_power_level(), 1, "four pickups are not a level")
	assert_eq(_state.get_power_progress(), 4)
	assert_true(_state.collect_power_pickup())
	assert_eq(_state.get_power_level(), 2)
	assert_eq(_state.get_power_progress(), 0, "the progress starts over for the next level")
	assert_eq(power.emissions, [[1, 1], [1, 2], [1, 3], [1, 4], [2, 0]])


func test_power_level_stops_at_3_and_excess_pickups_award_score() -> void:
	# PLANEJAMENTO Section 4: "At maximum power, additional pickups award score", and
	# "Graze and score": "50 per excess power pickup".
	var power := signal_recorder(_state, &"power_changed")
	var score := signal_recorder(_state, &"score_awarded")
	assert_eq(_collect_power_pickups(10), 10)
	assert_eq(_state.get_power_level(), 3, "ten pickups raise level 1 to level 3")
	assert_eq(_state.get_power_progress(), 0)
	assert_eq(score.count(), 0)
	assert_true(_state.collect_power_pickup(), "an excess pickup is still collected")
	assert_true(_state.collect_power_pickup())
	assert_eq(_state.get_power_level(), 3, "level 3 is the maximum")
	assert_eq(_state.get_power_progress(), 0, "no progress beyond the maximum")
	assert_eq(score.emissions, [[50], [50]])
	assert_eq(power.count(), 10, "excess pickups change no Power")


func test_shield_pickup_stays_available_while_shielded() -> void:
	# PLANEJAMENTO Section 4: "A shield pickup stays available while the player already
	# has a shield", and the shield "does not regenerate over time or stack".
	var shield := signal_recorder(_state, &"shield_changed")
	assert_false(_state.collect_shield_pickup(), "refused while shielded, so it stays in the world")
	assert_eq(shield.count(), 0)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED)
	_state.tick(2.0)
	assert_false(_state.has_shield(), "the shield does not regenerate over time")
	assert_true(_state.collect_shield_pickup())
	assert_true(_state.has_shield())
	assert_false(_state.collect_shield_pickup(), "a second pickup does not stack")
	assert_eq(shield.emissions, [[false], [true]])
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED)
	_state.tick(1.0)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.DAMAGED, "one charge, however many pickups were touched")


func test_refill_restores_health_shield_and_bombs_but_not_power() -> void:
	# STAGE_DESIGN "Checkpoint contract": first activation restores "100% health, one
	# shield, and two bombs"; Power and its partial progress are kept.
	_state.start(2, 3)
	assert_true(_press_bomb(), "setup")
	_state.tick(2.0)
	_break_shield()
	assert_eq(_state.take_hit(30), CombatState.HitOutcome.DAMAGED, "setup")
	assert_true(_state.collect_power_pickup(), "setup")
	var power := signal_recorder(_state, &"power_changed")
	_state.refill()
	assert_eq(_state.get_health(), 100)
	assert_true(_state.has_shield())
	assert_eq(_state.get_bombs(), 2)
	assert_eq(_state.get_power_level(), 2, "a refill is not a Power reset")
	assert_eq(_state.get_power_progress(), 4)
	assert_eq(power.count(), 0)
	assert_true(_state.is_invulnerable(), "a refill leaves the running invulnerability alone")


func test_capture_is_not_changed_by_later_mutations() -> void:
	# CONVENTIONS "Snapshots": a Snapshot cannot change after it is taken.
	_state.start(2, 3)
	_break_shield()
	_state.take_hit()
	var kept := _state.capture()
	var captured_life := {"health": 90, "has_shield": false, "bombs": 2, "power_level": 2, "power_progress": 3}
	if not assert_eq(kept, captured_life, "capture() holds the five resource values"):
		return
	_state.tick(1.0)
	_state.take_hit(30)
	_press_bomb()
	_collect_power_pickups(2)
	_state.collect_shield_pickup()
	var current_life := {"health": 60, "has_shield": true, "bombs": 1, "power_level": 3, "power_progress": 0}
	if not assert_eq(_state.capture(), current_life, "setup: every captured value has changed"):
		return
	assert_eq(kept, captured_life, "the kept capture still describes the moment it was taken")
	var edited := _state.capture()
	edited.clear()
	assert_eq(_state.capture(), current_life, "each capture is a new Dictionary the core does not read back")


func test_restore_returns_to_the_captured_life() -> void:
	# STAGE_DESIGN "Checkpoint contract": Retry restores the saved Power and partial
	# progress with full resources and removes the failed segment's damage timers.
	var defeats := signal_recorder(_state, &"defeated")
	_state.start(2, 3)
	var data := _state.capture()
	var checkpoint_life := {"health": 100, "has_shield": true, "bombs": 2, "power_level": 2, "power_progress": 3}
	if not assert_eq(data, checkpoint_life, "setup"):
		return
	# The failed segment: both Bombs, Power gained, the shield and all Health lost.
	assert_true(_press_bomb(), "setup")
	assert_true(_press_bomb(), "setup")
	_collect_power_pickups(2)
	_state.tick(2.0)
	_break_shield()
	assert_eq(_state.take_hit(100), CombatState.HitOutcome.DEFEATED, "setup")
	_state.update_bomb_input(false)

	_state.restore(data)
	assert_eq(_state.capture(), checkpoint_life, "Retry puts the captured values back")
	assert_eq(_state.get_power_level(), 2, "Power gained in the failed segment is not kept")
	assert_false(_state.is_defeated(), "Retry begins a new life")
	assert_false(_state.is_invulnerable())
	assert_false(_state.update_bomb_input(true), "restore() treats the bomb button as held")

	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED, "the restored shield takes the hit")
	_state.restore(data)
	assert_false(_state.is_invulnerable(), "Retry removes the damage timers")
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED, "accepted at once, with the shield back")
	_state.tick(1.0)
	assert_eq(_state.take_hit(100), CombatState.HitOutcome.DEFEATED)
	assert_eq(defeats.count(), 2, "each life can be lost once")

	var fresh := CombatState.new()
	fresh.restore(data)
	assert_eq(fresh.capture(), checkpoint_life, "restored into a new core")


func test_signals_fire_only_on_change() -> void:
	var recorders := _record_value_signals()
	_state.refill()
	_assert_silent(recorders, "refill() at full resources")
	_state.set_paused(true)
	_state.set_paused(false)
	_assert_silent(recorders, "set_paused()")
	_state.start(1)
	_assert_silent(recorders, "start() with the values already held")
	_state.set_paused(true)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED)
	_state.set_paused(false)
	_assert_silent(recorders, "a hit rejected while paused")

	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED)
	_clear(recorders)
	assert_eq(_state.take_hit(), CombatState.HitOutcome.REJECTED)
	_assert_silent(recorders, "a hit rejected by invulnerability")
	_state.tick(1.0)
	_state.tick(1.0)
	assert_eq(recorders[&"invulnerability_changed"].emissions, [[false]], "the window ends once")
	_clear(recorders)

	assert_eq(_state.take_hit(), CombatState.HitOutcome.DAMAGED)
	assert_eq(recorders[&"health_changed"].emissions, [[90]], "a damaging hit reports the new Health once")
	assert_eq(recorders[&"shield_changed"].count(), 0)
	assert_eq(recorders[&"bombs_changed"].count(), 0)
	assert_eq(recorders[&"power_changed"].count(), 0)
	assert_eq(recorders[&"invulnerability_changed"].emissions, [[true]])


## Spends the shield on one hit and waits out the 1 s of invulnerability it grants, so
## the next hit reaches Health.
func _break_shield() -> void:
	assert_eq(_state.take_hit(), CombatState.HitOutcome.ABSORBED, "setup: the shield absorbs the first hit")
	_state.tick(1.0)


## Releases, then presses the Bomb button, as two physics ticks of input would. Returns
## whether the press activated a Bomb.
func _press_bomb() -> bool:
	_state.update_bomb_input(false)
	return _state.update_bomb_input(true)


## Collects [param pickups] Power Pickups and returns how many the core accepted.
func _collect_power_pickups(pickups: int) -> int:
	var accepted := 0
	for _pickup: int in range(pickups):
		if _state.collect_power_pickup():
			accepted += 1
	return accepted


## Connects a recorder to each signal that reports a resource value, keyed by signal name.
func _record_value_signals() -> Dictionary[StringName, TestCase.SignalRecorder]:
	var names: Array[StringName] = [&"health_changed", &"shield_changed", &"bombs_changed", &"power_changed", &"invulnerability_changed"]
	var recorders: Dictionary[StringName, TestCase.SignalRecorder] = {}
	for signal_name: StringName in names:
		recorders[signal_name] = signal_recorder(_state, signal_name)
	return recorders


## Passes when none of [param recorders] recorded an emission; names each one that did.
func _assert_silent(recorders: Dictionary[StringName, TestCase.SignalRecorder], context: String) -> void:
	for signal_name: StringName in recorders:
		assert_eq(recorders[signal_name].emissions, [], "%s emitted %s" % [context, signal_name])


## Forgets what every recorder in [param recorders] has seen.
func _clear(recorders: Dictionary[StringName, TestCase.SignalRecorder]) -> void:
	for recorder: TestCase.SignalRecorder in recorders.values():
		recorder.clear()
