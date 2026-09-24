extends SceneTree
## Offline combat QA for `scenes/main.tscn` (Claude, F7-01). Not gameplay code and not
## attached to any node: it starts Direct Stage 1 through the real Session, fires hostile
## Projectiles at the ship's Core through the real [ProjectileSystem], and checks what
## reached [CombatState], [RunState], the ship and the Interface: the Shield, damage,
## Invulnerability and its flicker, Graze, pause, Defeat, Retry, Return to Menu,
## excess-Power score and Restart, and since F7-02 the Bomb: one press, one Bomb, the
## clear within the radius that awards no Graze, the damage to a target in range, the
## blast visual, the 2 s of Invulnerability, and no Bomb under Pause, from the B press
## that resumes it, with none left or when defeated. It captures the screenshots recorded in
## `docs/validation/combat.md` and exits non-zero when a check fails.
##
## Run it headless first, then with a display for the PNGs:
## `tools/godot.ps1 --headless --path . --script res://tools/validate_combat.gd`
## `tools/godot.ps1 --path . --script res://tools/validate_combat.gd`
##
## Expected values come from PLANEJAMENTO Section 4 and the F7-01 ticket, not from the
## cores: a common bullet takes 10 of 100 Health, the Shield absorbs one whole hit,
## Invulnerability lasts 1 second, a Graze is worth 10 and an excess Power Pickup 50, and
## a Bomb grants 2 seconds and clears only hostile fire within its radius.


const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SHOT_PREFIX := "res://docs/validation/combat-"
const STAGE := &"stage_01"

## PLANEJAMENTO Section 4 "Health and shield" and Section 6 "Start".
const FULL_HEALTH := 100
const BULLET_DAMAGE := 10
const ENTRY_BOMBS := 2
const INVULNERABILITY_SECONDS := 1.0
## PLANEJAMENTO Section 4 "Graze and score".
const GRAZE_POINTS := 10
const EXCESS_PICKUP_POINTS := 50
## Power Pickups from Power Level 1 to the highest, 3: five per level (PLANEJAMENTO
## Section 4).
const PICKUPS_TO_MAX_POWER := 10

## Where a test Projectile starts, from the Core's center, and how fast it flies back at
## it: two units at 20 per second touch the Core on the fifth tick.
const SPAWN_OFFSET := Vector3(2.0, 0.0, 0.0)
const PROJECTILE_SPEED := 20.0
const PROJECTILE_LIFETIME := 0.5
## A Graze pass's miss distance from the Core's center, across its flight: outside Core
## contact (Core 0.18 + Projectile 0.25) and inside Graze contact (Graze 0.55 + 0.25).
const GRAZE_MISS := Vector3(0.0, 0.6, 0.0)
## Physics ticks after a spawn before its effect is read: the pass plus a margin.
const FLIGHT_TICKS := 10
## Physics ticks the flicker is sampled for: half a second.
const FLICKER_TICKS := 30
const PAUSED_TICKS := 90
const DEFEAT_TICKS := 60
## Longest wait for an Invulnerability window to end.
const TIMEOUT_TICKS := 180
const RETRY_LOCATION_PATH := ^"Defeat/Layout/RetryLocation"
const CORE_VISUAL_PATH := ^"DamageCore/CoreVisual"
const TARGET_DUMMY_PATH := "res://scenes/dev/target_dummy.tscn"
## F7-02: distances from the Core inside the Bomb radius, a ring inside it, and how far
## beyond it the outside ones sit; the ring size; how long static test Projectiles live.
const BOMB_INSIDE := 4.0
const BOMB_INSIDE_RING := 6.0
const BOMB_OUTSIDE_MARGIN := 2.0
const RING_SIZE := 16
const STATIC_LIFETIME := 3.0
## Ticks a Bomb press is held; one press must spend one Bomb however long it is held.
const BOMB_HELD_TICKS := 30
## Seconds after the Bomb of a hit it rejects and of one that lands (PLANEJAMENTO: 2 s).
const BOMB_EARLY_HIT := 1.5
const BOMB_LATE_HIT := 2.1
## Ticks a [method _fire] Projectile takes from its spawn to the Core.
const FLIGHT_TICKS_TO_CORE := 5

var _session: GameSession
var _failures: int = 0
## Emissions seen by this tool's own connections, made after the Session's.
var _hits_reported: int = 0
var _grazes_reported: int = 0
var _defeats_reported: int = 0
## Physics frame of the latest Invulnerability start and end, or -1.
var _invulnerable_from: int = -1
var _invulnerable_to: int = -1


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Main scene could not be loaded: " + MAIN_SCENE_PATH)
		quit(1)
		return
	var main := packed.instantiate()
	root.add_child(main)
	current_scene = main
	_session = main as GameSession
	if _session == null:
		push_error("Main needs the GameSession script")
		quit(1)
		return
	_session.projectile_system.player_hit.connect(_on_player_hit)
	_session.projectile_system.grazed.connect(_on_grazed)
	_session.get_combat_state().invulnerability_changed.connect(_on_invulnerability_changed)
	_session.get_combat_state().defeated.connect(_on_defeated)
	print("COMBAT note: %d physics ticks per second, display '%s'" % [Engine.physics_ticks_per_second, DisplayServer.get_name()])
	await process_frame

	_request(&"start_direct_stage", {"stage": STAGE})
	await _ticks(10)
	if _ship() == null:
		_report(false, "start_direct_stage on %s put no PlayerShip under WorldRoot" % STAGE)
		_finish()
		return
	await _hits_and_invulnerability()
	await _grazes()
	await _defeat()
	await _retry()
	await _menu_from_defeat()
	await _excess_power()
	await _restart_twice()
	await _bombs()
	_finish()


## Checks 1, 2, 7, 3, 8 and 4, in the order their Invulnerability windows allow.
func _hits_and_invulnerability() -> void:
	var combat := _session.get_combat_state()
	var hits := _hits_reported
	_fire(SPAWN_OFFSET)
	await _ticks(FLIGHT_TICKS)
	_report(not combat.has_shield() and combat.get_health() == FULL_HEALTH and combat.is_invulnerable(),
			"1 first Core hit breaks the Shield and spares Health: shield %s, health %d, invulnerable %s, %d hit reported" % [
				combat.has_shield(), combat.get_health(), combat.is_invulnerable(), _hits_reported - hits])
	var first_start := _invulnerable_from

	hits = _hits_reported
	_fire(SPAWN_OFFSET)
	await _ticks(FLIGHT_TICKS)
	# The field knows about the window too, so the Projectile passes through unreported.
	_report(combat.is_invulnerable() and not combat.has_shield() and combat.get_health() == FULL_HEALTH
			and _hits_reported == hits,
			"2 a hit during Invulnerability is rejected: health %d, shield %s, %d hit reported" % [
				combat.get_health(), combat.has_shield(), _hits_reported - hits])

	await _flicker()
	var window := _invulnerable_to - first_start
	_report(_ticks_match(window, INVULNERABILITY_SECONDS),
			"3a Invulnerability after the Shield hit lasted %d ticks (%.3f s)" % [window, _seconds(window)])

	hits = _hits_reported
	_fire(SPAWN_OFFSET)
	await _ticks(FLIGHT_TICKS)
	_report(combat.get_health() == FULL_HEALTH - BULLET_DAMAGE and combat.is_invulnerable(),
			"3 after Invulnerability a hit takes %d Health: health %d, invulnerable %s, %d hit reported" % [
				BULLET_DAMAGE, combat.get_health(), combat.is_invulnerable(), _hits_reported - hits])

	await _pause_freezes_invulnerability()

	hits = _hits_reported
	_fire(SPAWN_OFFSET)
	_fire(-SPAWN_OFFSET)
	await _ticks(FLIGHT_TICKS)
	_report(combat.get_health() == FULL_HEALTH - 2 * BULLET_DAMAGE and combat.is_invulnerable(),
			"4 two Projectiles on the Core in one tick count once: health %d, %d hit reported" % [
				combat.get_health(), _hits_reported - hits])


## Check 7: samples `VisualRoot` and the Core every frame for [constant FLICKER_TICKS]
## while Invulnerable, captures the flicker screenshot on a hidden frame, then waits for
## the window to end.
func _flicker() -> void:
	var combat := _session.get_combat_state()
	var ship := _ship()
	var core_visual := ship.get_node(CORE_VISUAL_PATH) as Node3D
	var shown := 0
	var hidden := 0
	var core_hidden := 0
	var captured := false
	var until := Engine.get_physics_frames() + FLICKER_TICKS
	while Engine.get_physics_frames() < until:
		if _windowed():
			await RenderingServer.frame_post_draw
		else:
			await process_frame
		if not combat.is_invulnerable():
			break
		if ship.visual_root.visible:
			shown += 1
		else:
			hidden += 1
		if not core_visual.is_visible_in_tree():
			core_hidden += 1
		# After frame_post_draw the state read is the one just drawn.
		if _windowed() and not captured and not ship.visual_root.visible:
			captured = true
			_save_shot("hit-flicker", "visual_root hidden, shield %s, health %d" % [combat.has_shield(), combat.get_health()])
	var sampled_while_invulnerable := combat.is_invulnerable()
	if _windowed() and not captured:
		_save_shot("hit-flicker", "no hidden frame caught; visual_root %s" % ship.visual_root.visible)
	await _until_vulnerable()
	_report(sampled_while_invulnerable and shown > 0 and hidden > 0 and core_hidden == 0 and ship.visual_root.visible,
			"7 Invulnerability flickers VisualRoot (%d shown, %d hidden frames in %d ticks) but not the Core (%d hidden); visible after: %s" % [
				shown, hidden, FLICKER_TICKS, core_hidden, ship.visual_root.visible])


## Check 8: pauses with the `pause` action right after a hit, holds for
## [constant PAUSED_TICKS], resumes, and measures the unpaused part of the window.
func _pause_freezes_invulnerability() -> void:
	var combat := _session.get_combat_state()
	var window_start := _invulnerable_from
	await _push_action(&"pause")
	var paused_at := Engine.get_physics_frames()
	var on_pause := _session.interface.current_screen() == ScreenRouter.PAUSE and paused
	await _ticks(PAUSED_TICKS)
	var held := combat.is_invulnerable()
	await _push_action(&"pause")
	var resumed := _session.interface.current_screen() == ScreenRouter.HUD and not paused
	var paused_for := Engine.get_physics_frames() - paused_at
	var ended := await _until_vulnerable()
	var running := _invulnerable_to - window_start - paused_for
	_report(on_pause and held and resumed and ended and _ticks_match(running, INVULNERABILITY_SECONDS),
			"8 pause freezes the Invulnerability countdown: paused on Pause %s, still invulnerable after %d paused ticks %s, resumed %s, then ended after %d running ticks (%.3f s)" % [
				on_pause, PAUSED_TICKS, held, resumed, running, _seconds(running)])


## Checks 6 and 5: a Graze pass while Invulnerable (right after check 4's hit), then one
## after the window.
func _grazes() -> void:
	var combat := _session.get_combat_state()
	var graze := _graze()
	var score := _score()
	var reported := _grazes_reported
	var invulnerable := combat.is_invulnerable()
	_fire(SPAWN_OFFSET, GRAZE_MISS)
	await _ticks(FLIGHT_TICKS)
	_report(invulnerable and _graze() == graze and _score() == score,
			"6 no Graze while invulnerable (%s): graze +%d, score +%d, %d reported" % [
				invulnerable, _graze() - graze, _score() - score, _grazes_reported - reported])

	await _until_vulnerable()
	var health := combat.get_health()
	graze = _graze()
	score = _score()
	reported = _grazes_reported
	_fire(SPAWN_OFFSET, GRAZE_MISS)
	await _ticks(FLIGHT_TICKS)
	_report(_graze() - graze == 1 and _score() - score == GRAZE_POINTS and combat.get_health() == health,
			"5 a Graze at %.2f from the Core adds graze +%d and score +%d (%d reported), health %d unchanged" % [
				GRAZE_MISS.length(), _graze() - graze, _score() - score, _grazes_reported - reported, combat.get_health()])


## Check 9: Health to 0 through the core, then the Session's reaction.
func _defeat() -> void:
	var combat := _session.get_combat_state()
	var defeats := _defeats_reported
	var hits := 0
	var outcome := CombatState.HitOutcome.REJECTED
	while combat.get_health() > 0 and hits < 20:
		combat.tick(CombatState.HIT_INVULNERABILITY)
		outcome = combat.take_hit(BULLET_DAMAGE)
		hits += 1
	var time := _session.get_run_state().clear_time()
	var label := _session.interface.get_node_or_null(RETRY_LOCATION_PATH) as Label
	var location := label.text if label != null else "<no %s>" % RETRY_LOCATION_PATH
	var on_defeat := _session.interface.current_screen() == ScreenRouter.DEFEAT
	var late := combat.take_hit(1000)
	await _push_action(&"pause")
	var pause_ignored := _session.interface.current_screen() == ScreenRouter.DEFEAT and paused
	await _ticks(DEFEAT_TICKS)
	var frozen := _session.get_run_state().clear_time() == time
	var defeat_count := _session.interface._router.visible_stack().count(ScreenRouter.DEFEAT)
	_report(outcome == CombatState.HitOutcome.DEFEATED and paused and on_defeat and location == "Início da fase"
			and frozen and defeat_count == 1 and _defeats_reported - defeats == 1
			and late == CombatState.HitOutcome.REJECTED and pause_ignored,
			"9 Defeat after %d hits: tree paused %s, top %s, RetryLocation '%s', clear_time %.3f s unchanged after %d ticks %s, Defeat on the stack %d time(s), defeated %d time(s), later hit %s, pause ignored %s" % [
				hits, paused, _session.interface.current_screen(), location, time, DEFEAT_TICKS, frozen,
				defeat_count, _defeats_reported - defeats, CombatState.HitOutcome.keys()[late], pause_ignored])
	await _capture("defeat")


## Check 10: Retry from Defeat restarts the stage with the entry resources.
func _retry() -> void:
	var combat := _session.get_combat_state()
	var old_ship := _ship()
	var old_id := old_ship.get_instance_id() if old_ship != null else 0
	_request(&"retry")
	var ship := _ship()
	var start := _session.world_root.get_node_or_null(^"Stage/PlayerStart") as Node3D
	var fresh := ship != null and ship.get_instance_id() != old_id
	var at_start := fresh and start != null and ship.global_position.is_equal_approx(start.global_position)
	var time := _session.get_run_state().clear_time()
	_report(at_start and combat.get_health() == FULL_HEALTH and combat.has_shield() and combat.get_bombs() == ENTRY_BOMBS
			and time == 0.0 and _session.interface.current_screen() == ScreenRouter.HUD and not paused
			and not combat.is_invulnerable() and ship.visual_root.visible,
			"10 retry restarts the stage: new ship %s at PlayerStart %s, health %d, shield %s, bombs %d, clear_time %.3f, top %s, paused %s" % [
				fresh, at_start, combat.get_health(), combat.has_shield(), combat.get_bombs(), time,
				_session.interface.current_screen(), paused])
	await _ticks(5)


## Check 11: a new Defeat, then Menu principal from it.
func _menu_from_defeat() -> void:
	var combat := _session.get_combat_state()
	var absorbed := combat.take_hit()
	combat.tick(CombatState.HIT_INVULNERABILITY)
	var outcome := combat.take_hit(1000)
	var on_defeat := _session.interface.current_screen() == ScreenRouter.DEFEAT
	await process_frame
	_request(&"return_to_menu")
	await process_frame
	var emptied := _session.world_root.get_child_count() == 0
	_report(absorbed == CombatState.HitOutcome.ABSORBED and outcome == CombatState.HitOutcome.DEFEATED and on_defeat
			and _session.interface.current_screen() == ScreenRouter.MAIN_MENU and emptied and not paused,
			"11 return_to_menu from Defeat (on Defeat %s) returns to %s, WorldRoot empty %s, paused %s" % [
				on_defeat, _session.interface.current_screen(), emptied, paused])


## Check 12: a new Direct Stage 1, Power to the top, then one excess Pickup.
func _excess_power() -> void:
	var combat := _session.get_combat_state()
	_request(&"start_direct_stage", {"stage": STAGE})
	await _ticks(5)
	var score := _score()
	for _pickup: int in PICKUPS_TO_MAX_POWER:
		combat.collect_power_pickup()
	var after_ten := _score()
	var level := combat.get_power_level()
	combat.collect_power_pickup()
	var gained := _score() - after_ten
	_report(after_ten == score and level == 3 and gained == EXCESS_PICKUP_POINTS,
			"12 ten Power Pickups reach Power Level %d with score +%d, the eleventh adds +%d" % [
				level, after_ten - score, gained])


## Check 13: two Restarts, then one Graze.
func _restart_twice() -> void:
	_request(&"restart_stage")
	_request(&"restart_stage")
	await _ticks(5)
	var graze := _graze()
	var score := _score()
	var reported := _grazes_reported
	_fire(SPAWN_OFFSET, GRAZE_MISS)
	await _ticks(FLIGHT_TICKS)
	_report(_graze() - graze == 1 and _score() - score == GRAZE_POINTS,
			"13 after two restart_stage requests one Graze adds graze +%d and score +%d (%d reported)" % [
				_graze() - graze, _score() - score, _grazes_reported - reported])


## Checks 14 to 21 (F7-02): the Bomb through the real input path, on a fresh stage entry
## with two Bombs. The press is a `bomb` event, which only [PlayerWeapon] reads.
func _bombs() -> void:
	var combat := _session.get_combat_state()
	_request(&"restart_stage")
	await _ticks(5)
	# 14: a press with Pause on top, then gamepad B on Pause, which resumes; neither bombs.
	await _push_action(&"pause")
	_push_bomb(true)
	_push_bomb(false)
	await _push_action(&"pause")
	await _ticks(10)
	var after_paused_press := combat.get_bombs()
	await _push_action(&"pause")
	_push_joypad_b()
	var resumed := not paused
	await _ticks(10)
	_report(after_paused_press == ENTRY_BOMBS and resumed and combat.get_bombs() == ENTRY_BOMBS,
			"14 a bomb press under Pause and the B press that resumes Pause spend nothing: %d then %d of %d Bombs, resumed %s" % [
				after_paused_press, combat.get_bombs(), ENTRY_BOMBS, resumed])
	# 15 to 17: one held press, with hostile fire inside and outside the radius, a hostile in
	# the Graze Volume, a player shot, and a target dummy inside and one outside.
	var weapon := _ship().weapon
	var core := _ship().damage_core.global_position
	var inside_dummy := _add_dummy(core + Vector3(BOMB_INSIDE, 0.0, 0.0))
	var outside_dummy := _add_dummy(core + Vector3(0.0, 0.0, -weapon.bomb_radius - BOMB_OUTSIDE_MARGIN))
	await _ticks(2)
	var graze := _graze()
	var reported_grazes := _grazes_reported
	var bombs_used := _bombs_used()
	await physics_frame
	# Spawned in the tick the Bomb goes off, before the field moves: the Graze-Volume one
	# would graze on this very tick if the clear did not come first.
	core = _ship().damage_core.global_position
	_spawn_static(core + Vector3(BOMB_INSIDE, 1.0, 0.0), ProjectileSpawn.Faction.HOSTILE)
	_spawn_static(core + GRAZE_MISS, ProjectileSpawn.Faction.HOSTILE)
	_spawn_static(core + Vector3(-weapon.bomb_radius - BOMB_OUTSIDE_MARGIN, 0.0, 0.0), ProjectileSpawn.Faction.HOSTILE)
	_spawn_static(core + Vector3(0.0, 0.0, -BOMB_INSIDE), ProjectileSpawn.Faction.PLAYER)
	for index: int in RING_SIZE:
		var angle := TAU * index / RING_SIZE
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		_spawn_static(core + direction * BOMB_INSIDE_RING, ProjectileSpawn.Faction.HOSTILE)
		_spawn_static(core + direction * (weapon.bomb_radius + BOMB_OUTSIDE_MARGIN), ProjectileSpawn.Faction.HOSTILE)
	var hostile_before := _session.projectile_system.count(ProjectileSpawn.Faction.HOSTILE)
	# The Bomb's own Invulnerability would hide the Graze on its own; lifted for the Bomb's
	# tick only, so check 16b fails if the clear does not come first.
	combat.bomb_activated.connect(_lift_invulnerability_for_one_tick, CONNECT_ONE_SHOT)
	_push_bomb(true)
	await _ticks(1)
	var bomb_frame := Engine.get_physics_frames()
	_session.projectile_system.set_player_invulnerable(combat.is_invulnerable())
	var hostile_after := _session.projectile_system.count(ProjectileSpawn.Faction.HOSTILE)
	var player_after := _session.projectile_system.count(ProjectileSpawn.Faction.PLAYER)
	# Read now: by the time the checks below run the blast has already freed itself.
	var blast_seen := _blast() != null
	await _capture("bomb")
	await _ticks(BOMB_HELD_TICKS)
	_push_bomb(false)
	await _ticks(2)
	var outside_count := 1 + RING_SIZE
	_report(combat.get_bombs() == ENTRY_BOMBS - 1 and _bombs_used() - bombs_used == 1,
			"15 one press held %d ticks spends one Bomb: %d left, bombs_used +%d" % [
				BOMB_HELD_TICKS, combat.get_bombs(), _bombs_used() - bombs_used])
	_report(hostile_after == outside_count and player_after == 1 and hostile_before == outside_count + 2 + RING_SIZE,
			"16 the Bomb clears hostile fire within %.1f only: hostile %d -> %d (%d outside kept), player shots %d kept; Graze +%d (%d reported)" % [
				weapon.bomb_radius, hostile_before, hostile_after, outside_count, player_after,
				_graze() - graze, _grazes_reported - reported_grazes])
	_report(_graze() == graze and _grazes_reported == reported_grazes,
			"16b the cleared Projectile in the Graze Volume awards no Graze")
	_report(inside_dummy.damage_taken == weapon.bomb_damage and inside_dummy.hit_count == 1 and outside_dummy.damage_taken == 0,
			"17 the Bomb damages the target in range once (%d damage in %d hit, %d expected) and not the one outside (%d)" % [
				inside_dummy.damage_taken, inside_dummy.hit_count, weapon.bomb_damage, outside_dummy.damage_taken])
	# 18: the visual appears at the Core and frees itself.
	await _ticks(roundi(BombBlast.FADE_SECONDS * Engine.physics_ticks_per_second) + 10)
	_report(blast_seen and _blast() == null,
			"18 the blast visual appeared (%s) and freed itself within %.1f s" % [blast_seen, BombBlast.FADE_SECONDS])
	# 19: 2 s of Invulnerability from the Bomb: a hit at 1.5 s passes, one at 2.1 s lands.
	var hits := _hits_reported
	await _until_frame(bomb_frame + roundi(BOMB_EARLY_HIT * Engine.physics_ticks_per_second) - FLIGHT_TICKS_TO_CORE)
	_fire(SPAWN_OFFSET)
	await _ticks(FLIGHT_TICKS)
	var early := _hits_reported - hits
	await _until_frame(bomb_frame + roundi(BOMB_LATE_HIT * Engine.physics_ticks_per_second) - FLIGHT_TICKS_TO_CORE)
	_fire(SPAWN_OFFSET)
	await _ticks(FLIGHT_TICKS)
	var late := _hits_reported - hits - early
	_report(early == 0 and late == 1,
			"19 after the Bomb a hit at %.1f s is rejected (%d reported) and one at %.1f s lands (%d reported)" % [
				BOMB_EARLY_HIT, early, BOMB_LATE_HIT, late])
	# 20: the second press spends the last Bomb, a third does nothing.
	await _until_vulnerable()
	await _press_bomb()
	var after_second := combat.get_bombs()
	await _press_bomb()
	_report(after_second == 0 and combat.get_bombs() == 0 and _bombs_used() - bombs_used == 2,
			"20 the second press spends the last Bomb (%d left) and a third does nothing (%d left, bombs_used +%d)" % [
				after_second, combat.get_bombs(), _bombs_used() - bombs_used])
	# 21: defeated with two Bombs, a press spends nothing.
	_request(&"restart_stage")
	await _ticks(5)
	combat.take_hit()
	combat.tick(CombatState.HIT_INVULNERABILITY)
	combat.take_hit(1000)
	var defeated := combat.is_defeated() and _session.interface.current_screen() == ScreenRouter.DEFEAT
	await _press_bomb()
	_report(defeated and combat.get_bombs() == ENTRY_BOMBS,
			"21 defeated (%s), a bomb press spends nothing: %d of %d Bombs" % [defeated, combat.get_bombs(), ENTRY_BOMBS])
	_request(&"return_to_menu")
	await process_frame


## Connected after the Session, so it runs once its Bomb handler has set the field.
func _lift_invulnerability_for_one_tick() -> void:
	_session.projectile_system.set_player_invulnerable(false)


func _press_bomb() -> void:
	_push_bomb(true)
	await _ticks(BOMB_HELD_TICKS)
	_push_bomb(false)
	await _ticks(2)


func _push_bomb(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"bomb"
	event.pressed = pressed
	root.push_input(event)


## Gamepad B, which is `ui_cancel` and `bomb` (CONVENTIONS "Input actions").
func _push_joypad_b() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_B
		event.pressed = pressed
		root.push_input(event)


func _add_dummy(at: Vector3) -> TargetDummy:
	var dummy := (load(TARGET_DUMMY_PATH) as PackedScene).instantiate() as TargetDummy
	_session.world_root.add_child(dummy)
	dummy.global_position = at
	dummy.setup(_session.projectile_system)
	return dummy


func _spawn_static(at: Vector3, faction: ProjectileSpawn.Faction) -> void:
	var request := ProjectileSpawn.new(at, Vector3.ZERO, faction, STATIC_LIFETIME)
	if _session.projectile_system.spawn(request) == ProjectileField.NO_PROJECTILE:
		_report(false, "the field refused a test Projectile")


func _blast() -> BombBlast:
	for child: Node in _session.world_root.get_children():
		if child is BombBlast:
			return child as BombBlast
	return null


func _bombs_used() -> int:
	return _session.get_run_state().stage_result()["bombs_used"]


func _until_frame(frame: int) -> void:
	while Engine.get_physics_frames() < frame:
		await physics_frame


## Spawns a hostile Projectile at the Core's center plus [param from], flying back
## toward the center, displaced by [param miss] across its flight.
func _fire(from: Vector3, miss: Vector3 = Vector3.ZERO) -> void:
	var core := _ship().damage_core.global_position
	var request := ProjectileSpawn.new(core + from + miss, -from.normalized() * PROJECTILE_SPEED,
			ProjectileSpawn.Faction.HOSTILE, PROJECTILE_LIFETIME)
	if _session.projectile_system.spawn(request) == ProjectileField.NO_PROJECTILE:
		_report(false, "the field refused a test Projectile")


## Waits until the Invulnerability window ends; false when it outlasts
## [constant TIMEOUT_TICKS].
func _until_vulnerable() -> bool:
	var combat := _session.get_combat_state()
	var waited := 0
	while combat.is_invulnerable() and waited < TIMEOUT_TICKS:
		await physics_frame
		waited += 1
	return not combat.is_invulnerable()


## Whether [param ticks] is [param seconds] of physics, within one tick of rounding.
func _ticks_match(ticks: int, seconds: float) -> bool:
	return absi(ticks - roundi(seconds * Engine.physics_ticks_per_second)) <= 1


func _seconds(ticks: int) -> float:
	return float(ticks) / Engine.physics_ticks_per_second


func _request(action: StringName, payload: Dictionary = {}) -> void:
	_session.interface.action_requested.emit(action, payload)


## Presses and releases [param action] through the root viewport.
func _push_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event)
	await process_frame


func _ticks(count: int) -> void:
	for _tick: int in count:
		await physics_frame


func _ship() -> PlayerController:
	return _session.world_root.get_node_or_null(^"PlayerShip") as PlayerController


func _graze() -> int:
	return _session.get_run_state().stage_result()["graze"]


func _score() -> int:
	return _session.get_run_state().stage_result()["score"]


func _windowed() -> bool:
	return DisplayServer.get_name() != "headless"


func _capture(name_suffix: String) -> void:
	if not _windowed():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	_save_shot(name_suffix, "")


func _save_shot(name_suffix: String, note: String) -> void:
	var path := SHOT_PREFIX + name_suffix + ".png"
	var result := root.get_texture().get_image().save_png(path)
	_report(result == OK, "screenshot %s %s%s" % [path, error_string(result), "" if note.is_empty() else " (%s)" % note])


func _report(passed: bool, label: String) -> void:
	if not passed:
		_failures += 1
	print("COMBAT %s %s" % ["ok  " if passed else "FAIL", label])


func _finish() -> void:
	if _failures > 0:
		print("COMBAT_FAILED %d" % _failures)
	else:
		print("COMBAT_OK")
	quit(1 if _failures > 0 else 0)


func _on_player_hit(_projectile_id: int, _damage: int) -> void:
	_hits_reported += 1


func _on_grazed(_projectile_id: int) -> void:
	_grazes_reported += 1


func _on_invulnerability_changed(invulnerable: bool) -> void:
	if invulnerable:
		_invulnerable_from = Engine.get_physics_frames()
	else:
		_invulnerable_to = Engine.get_physics_frames()


func _on_defeated() -> void:
	_defeats_reported += 1
