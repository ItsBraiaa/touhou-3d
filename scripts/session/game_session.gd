class_name GameSession
extends Node
## Composition root of `scenes/main.tscn` (ADR-0002) and owner of the Run. Acts on the
## menus' requests from [member interface]: opens their screens, starts a Campaign or a
## Direct Stage by loading the stage and the player under [member world_root], pauses and
## resumes, restarts the stage, returns to the main menu and quits. Owns the [RunState]
## and ticks its Active Time from `_physics_process` while the tree runs, and owns the
## [CombatState], started at every stage entry and bound to the HUD with each new ship.
## It is also the combat adapter the combat cores name: it turns the [ProjectileSystem]'s
## Core hits and Grazes into [CombatState] and [RunState] changes, mirrors Invulnerability
## to the field and the ship, forwards excess-Power score, and freezes the Attempt under
## Defeat when the player is defeated. It also answers a Bomb with its clear, its damage
## and its visual.
##
## A stage whose root is a [StageDirector] is checked before it loads, set up with the
## Run, the [CombatState], the field and the ship, started at every Attempt, and its clear
## completes the stage; its off-screen threats reach the HUD (F10-01). Defeat's Retry
## resumes in place from the latest Checkpoint with a new ship at its `Respawn`, or
## restarts the stage before any (F10-03). The Director's boss fight drives the HUD boss
## panel: name and Phase bars, each Attack's cue and the Phase health, hidden again on the
## boss's defeat, on Retry and on Restart (F12-03).
##
## Nothing here decides gameplay: movement, targeting, progression and the Run's
## accounting belong to their cores. Results arrive with F11.


## Marker every stage root has, where the player enters (GUIDE Section 5 "Stages").
const PLAYER_START_PATH := ^"PlayerStart"
## Marker whose `min` and `max` Vector3 metadata hold a stage's Flight Volume, in stage
## coordinates, when its scene records one (`docs/STAGE_02_HANDOFF.md`).
const FLIGHT_LIMITS_PATH := ^"FlightBounds/Limits"
## Score one Graze is worth (PLANEJAMENTO Section 4 "Graze and score").
const GRAZE_SCORE := 10
## Seconds the HUD shows an off-screen threat cue for one report. Claude's proposal.
const THREAT_CUE_SECONDS := 1.0
## Seconds the HUD shows a boss Attack's name when its Phase begins. Claude's proposal:
## long enough to still show at each Lantern Guardian Phase's first shot (2.0 s after
## Phase 1 begins, 2.75 s after Phase 2).
const ATTACK_CUE_SECONDS := 3.0
## Menu actions that only open a full screen, which Back returns from.
const SCREEN_BY_ACTION: Dictionary[StringName, StringName] = {
	&"open_stage_select": ScreenRouter.STAGE_SELECT,
	&"open_options": ScreenRouter.OPTIONS,
	&"open_controls": ScreenRouter.CONTROLS,
	&"open_credits": ScreenRouter.CREDITS,
}

@export_group("Roots")
## Holds the loaded stage and the player. Stays at the world origin: stage coordinates
## are world coordinates.
@export var world_root: Node3D
## The [ProjectileSystem] on `ProjectileRoot` (ADR-0004): set up for every stage load,
## cleared on every unload.
@export var projectile_system: ProjectileSystem
## Holds menus and the HUD. Processes while the tree is paused.
@export var interface: Interface
## Root of the audio controller. Processes while the tree is paused.
@export var audio: Node

@export_group("Stages")
## The ship, `scenes/player/player_ship.tscn`. Its root must be a [PlayerController].
@export var player_scene: PackedScene
## Stage scene by stage id, the ids of [constant RunState.CAMPAIGN_ORDER]. A stage with
## no entry, or an empty one, is unavailable: starting it is reported and the menu stays.
@export var stage_scenes: Dictionary[StringName, PackedScene] = {}
## Flight Volume by stage id, as a position and a size in stage coordinates, for a stage
## whose scene records none on `FlightBounds/Limits`. The scene's own record wins.
@export var stage_flight_bounds: Dictionary[StringName, AABB] = {}

var _run_state := RunState.new()
## One for the Session's lifetime, started again at every stage entry.
var _combat_state := CombatState.new()
## The ship of the stage in play, or null while none is loaded.
var _player: PlayerController
## The loaded stage's root when it is a [StageDirector], else null: a stage without one
## loads and flies as a static stage (F10-01).
var _director: StageDirector
## The loaded stage's Flight Volume, kept for every ship spawned into it (F10-03).
var _flight_volume := AABB()


func _ready() -> void:
	if not _validate_exports():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_run_state.stage_completed.connect(_on_stage_completed)
	_run_state.run_ended.connect(_on_run_ended)
	# The Session, the CombatState and the ProjectileSystem live as long as each other, so
	# these are made once and a Restart can never double them. The handlers read _player
	# when they run.
	projectile_system.player_hit.connect(_on_player_hit)
	projectile_system.grazed.connect(_on_grazed)
	_combat_state.invulnerability_changed.connect(_on_invulnerability_changed)
	_combat_state.score_awarded.connect(_on_score_awarded)
	_combat_state.defeated.connect(_on_player_defeated)
	_combat_state.bomb_activated.connect(_on_bomb_activated)
	interface.action_requested.connect(_on_action_requested)
	interface.show_home(ScreenRouter.MAIN_MENU)


## `Main` processes while the tree is paused, so the tree has to be checked here: Active
## Time and the Invulnerability window only run while gameplay does (CONVENTIONS "Time and
## randomness"). `Main` ticks before `ProjectileRoot`, so a window that ends this tick is
## already off in the field's sweep.
func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		_run_state.tick_active(delta)
		_combat_state.tick(delta)


## `pause` (Escape, gamepad Start) pauses a stage in play from the HUD and resumes it from
## Pause. Any other screen on top ignores it: with Options open from Pause, Start must
## not resume under Options. Escape on Pause is `ui_cancel` as well, which [Interface]
## consumes first and turns into `resume`.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause") or not _is_in_stage():
		return
	var screen := interface.current_screen()
	if screen == ScreenRouter.HUD:
		_pause()
	elif screen == ScreenRouter.PAUSE:
		_resume()
	else:
		return
	get_viewport().set_input_as_handled()


## The Run's state, for tests and dev tools to read. The Session drives it; nothing else
## may.
func get_run_state() -> RunState:
	return _run_state


## The player's combat resources, for tests and dev tools to read. The Session starts
## and pauses it; the combat adapter (F7) feeds it.
func get_combat_state() -> CombatState:
	return _combat_state


func _on_action_requested(action: StringName, payload: Dictionary) -> void:
	if action in SCREEN_BY_ACTION:
		interface.show_screen(SCREEN_BY_ACTION[action])
		return
	match action:
		&"start_campaign":
			_start_run(RunState.RunMode.CAMPAIGN, RunState.CAMPAIGN_ORDER[0])
		&"start_direct_stage":
			_start_run(RunState.RunMode.DIRECT_STAGE, payload.get("stage", &""))
		&"resume":
			_resume()
		&"restart_stage":
			_restart_stage()
		&"retry":
			_retry()
		&"return_to_menu":
			_return_to_menu()
		&"quit":
			get_tree().quit()
		&"back_refused":
			pass  # The main menu, Defeat and Results stay where they are.
		_:
			push_warning("%s: menu action '%s' is not implemented yet" % [get_path(), action])


## Loads [param stage] and starts a new Run on it, or stays on the menu when it cannot
## be loaded.
func _start_run(mode: RunState.RunMode, stage: StringName) -> void:
	if not _load_stage(stage):
		return
	_run_state.start(mode, stage)
	_combat_state.start(_run_state.starting_power_level())
	_run_state.begin_attempt()
	if _director != null:
		_director.start_attempt(_attempt_seed(_run_state.get_attempt_index()))
	interface.show_home(ScreenRouter.HUD)


## Pause's Restart, and Defeat's Retry before any Checkpoint: the stage from its entry
## values, with a new stage, ship, Director and [CheckpointStore], so every Checkpoint is
## discarded (STAGE_DESIGN "Restart Stage explicitly discards checkpoint progress").
func _restart_stage() -> void:
	if not _is_in_stage():
		return
	var stage: StringName = _run_state.stage_result()["stage"]
	_set_paused(false)
	_run_state.restart_stage()
	_combat_state.start(_run_state.starting_power_level())
	_load_stage(stage)
	# A boss fight never survives a Restart. Binding the new ship clears the panel too; this
	# says so without relying on it. Before the Attempt starts, because a boss Wave in the
	# first Encounter would show its panel inside start_attempt.
	interface.get_hud().hide_boss()
	_run_state.begin_attempt()
	if _director != null:
		_director.start_attempt(_attempt_seed(_run_state.get_attempt_index()))
	interface.show_home(ScreenRouter.HUD)


## Leaves the Run for the main menu, from Pause and Defeat today and from Results in F11.
func _return_to_menu() -> void:
	_set_paused(false)
	_unload_stage()
	_run_state.end_run(false)
	interface.show_home(ScreenRouter.MAIN_MENU)


func _pause() -> void:
	_set_paused(true)
	var result := _run_state.stage_result()
	interface.push_overlay(ScreenRouter.PAUSE, {"score": result["score"], "graze": result["graze"]})


## Removes Pause and lets the stage run again. Ignored unless the Session paused it.
## Gamepad B resumes through `ui_cancel` and is `bomb` too: [Interface] consumes that
## press, so a reader of `bomb` events never sees it, but a poll of
## `Input.is_action_just_pressed(&"bomb")` on the first unpaused tick still would
## (menus-session.md Open issues).
func _resume() -> void:
	if not get_tree().paused:
		return
	interface.back()
	_set_paused(false)


## Freezes or releases everything a pause covers: the tree, and with it the stage, the
## ship and the projectiles; the Run's Active Time; and the ship's controls.
func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_run_state.set_paused(paused)
	_combat_state.set_paused(paused)
	if _player != null:
		_player.set_controls_enabled(not paused)


## Replaces whatever is loaded with the stage [param stage_id] and a new ship at its
## `PlayerStart`, kept inside its Flight Volume, and sets up the stage's [StageDirector]
## when its root is one. When the stage has no scene, no `PlayerStart` or no Flight
## Volume, the ship is not a [PlayerController], or the Director's
## [method StageDirector.check_setup] reports anything, reports it, changes nothing and
## returns false.
func _load_stage(stage_id: StringName) -> bool:
	var scene: PackedScene = stage_scenes.get(stage_id)
	if scene == null:
		push_error("%s: stage '%s' has no scene in 'stage_scenes'; it is unavailable" % [get_path(), stage_id])
		return false
	var stage := scene.instantiate()
	var player := player_scene.instantiate()
	var start := stage.get_node_or_null(PLAYER_START_PATH) as Node3D
	var bounds := _flight_bounds(stage_id, stage)
	var director := stage as StageDirector
	var problem := ""
	if start == null:
		problem = "stage '%s' has no Node3D at '%s'" % [stage_id, PLAYER_START_PATH]
	elif not bounds.has_volume():
		problem = "stage '%s' has no Flight Volume: no '%s' min/max metadata and no 'stage_flight_bounds' entry" % [stage_id, FLIGHT_LIMITS_PATH]
	elif not player is PlayerController:
		problem = "'player_scene' %s does not have a PlayerController root" % player_scene.resource_path
	elif director != null:
		problem = "; ".join(director.check_setup())
	if not problem.is_empty():
		push_error("%s: %s; the stage is not started" % [get_path(), problem])
		stage.free()
		player.free()
		return false
	_unload_stage()
	world_root.add_child(stage)
	_flight_volume = bounds
	_spawn_player(player as PlayerController, start.global_transform)
	_director = director
	if _director != null:
		_director.setup(_run_state, _combat_state, projectile_system, _player)
		# Deferred: the last defeat arrives inside a physics step, and completing the stage
		# unloads it.
		_director.stage_cleared.connect(_on_stage_cleared, CONNECT_DEFERRED)
		_director.threat_reported.connect(_on_threat_reported)
		_connect_boss_panel()
	return true


## The one place a ship enters play: replaces the current one, if any, with [param ship]
## at [param at], kept inside the stage's Flight Volume, and makes every per-ship binding
## (the HUD, the [ProjectileSystem] and the weapon). A new ship carries no velocity, no
## Target Lock and no blink. [param ship] is a fresh instance of [member player_scene].
func _spawn_player(ship: PlayerController, at: Transform3D) -> void:
	if _player != null:
		interface.get_hud().unbind()
		world_root.remove_child(_player)
		_player.queue_free()
	_player = ship
	# Placed before it enters the tree, so its camera rig starts behind it at the marker
	# instead of easing in from the origin.
	_player.transform = at
	world_root.add_child(_player)
	_player.setup(_flight_volume)
	interface.get_hud().bind(_combat_state, _player.targeting, _player.camera_rig.camera)
	projectile_system.setup(_flight_volume, _player)
	_player.weapon.setup(_combat_state, projectile_system, _player.targeting)


## Defeat's Retry: resumes from the latest activated Checkpoint's Snapshot in place, with
## a new ship at its `Respawn` and nothing incoming; the Director removes the failed
## Attempt's actors and Pickups, restores the cores and rebuilds its Gates and links.
## Before any Checkpoint, or on a stage without a Director, Retry is Restart (PLANEJAMENTO
## Section 6).
func _retry() -> void:
	if not _is_in_stage():
		return
	if _director == null or _director.retry_location_name().is_empty():
		_restart_stage()
		return
	_set_paused(false)
	projectile_system.clear_all()
	_spawn_player(player_scene.instantiate() as PlayerController, _director.get_respawn_transform())
	_director.retry_from_checkpoint(_player, _attempt_seed(_run_state.get_attempt_index() + 1))
	# After the restore, which puts back the committed statistics (F8-03).
	_run_state.begin_attempt()
	# The Director removed any boss mid-fight; as on Restart, its panel goes explicitly.
	interface.get_hud().hide_boss()
	interface.show_home(ScreenRouter.HUD)


## Takes the stage and the ship out of the tree at once, so a stage loaded in the same
## frame never shares it with them, frees them at the end of the frame, and removes every
## Projectile.
func _unload_stage() -> void:
	interface.get_hud().unbind()
	for child: Node in world_root.get_children():
		world_root.remove_child(child)
		child.queue_free()
	projectile_system.clear_all()
	_player = null
	_director = null


## The Flight Volume of [param stage]: the `min`/`max` metadata on its
## [constant FLIGHT_LIMITS_PATH] when authored (Stage 2), else [member stage_flight_bounds].
## An empty AABB when neither has one.
func _flight_bounds(stage_id: StringName, stage: Node) -> AABB:
	var limits := stage.get_node_or_null(FLIGHT_LIMITS_PATH)
	if limits != null and limits.has_meta(&"min") and limits.has_meta(&"max"):
		var low: Vector3 = limits.get_meta(&"min")
		var high: Vector3 = limits.get_meta(&"max")
		return AABB(low, high - low)
	return stage_flight_bounds.get(stage_id, AABB())


func _is_in_stage() -> bool:
	return _run_state.get_phase() == RunState.Phase.IN_STAGE


## The seed of Attempt [param attempt_index] of the stage in play: deterministic per
## stage and Attempt, with no global random state (CONVENTIONS "Time and randomness").
func _attempt_seed(attempt_index: int) -> int:
	return hash("%s#%d" % [_run_state.stage_result()["stage"], attempt_index])


## The Director reported its last Encounter complete.
func _on_stage_cleared() -> void:
	_run_state.complete_stage()


func _on_threat_reported(side: int) -> void:
	interface.get_hud().show_threat(side, THREAT_CUE_SECONDS)


## The Director's boss signals reach the HUD boss panel (F12-03). Once per stage load:
## every load builds a new Director, so a Restart cannot double them. The handlers read
## the HUD when they run.
func _connect_boss_panel() -> void:
	_director.boss_started.connect(_on_boss_started)
	_director.boss_phase_changed.connect(_on_boss_phase_changed)
	_director.boss_health_changed.connect(_on_boss_health_changed)
	_director.boss_defeated.connect(_on_boss_defeated)


func _on_boss_started(display_name: String, phase_count: int) -> void:
	interface.get_hud().show_boss(display_name, phase_count)


func _on_boss_phase_changed(_phase_index: int, attack_display_name: String) -> void:
	interface.get_hud().show_attack_cue(attack_display_name, ATTACK_CUE_SECONDS)


func _on_boss_health_changed(phase_index: int, ratio: float) -> void:
	interface.get_hud().set_phase_health(phase_index, ratio)


func _on_boss_defeated(_boss_id: StringName) -> void:
	interface.get_hud().hide_boss()


## A hostile Projectile met the Core. The field reports at most one per tick, and treats
## the rest of that tick as Invulnerable itself; the core rejects any hit it receives
## while Invulnerable.
func _on_player_hit(_projectile_id: int, damage: int) -> void:
	_combat_state.take_hit(damage)


## The field awards no Graze during Invulnerability, so nothing is filtered here.
func _on_grazed(_projectile_id: int) -> void:
	_run_state.add_graze(1)
	_run_state.add_score(GRAZE_SCORE)


func _on_invulnerability_changed(invulnerable: bool) -> void:
	projectile_system.set_player_invulnerable(invulnerable)
	if _player != null:
		_player.set_invulnerable_visual(invulnerable)


## A Bomb went off, its edge and its 2 s of Invulnerability already the core's. Clears
## the hostile fire within the weapon's radius of the Core (awarding nothing), counts the
## Bomb in the Attempt, shows the blast, and last damages every enemy registered in range
## once: a kill may end the stage (F10), so nothing may follow it. The weapon feeds the
## button after every actor has registered, so this tick's spheres count.
func _on_bomb_activated() -> void:
	if _player == null:
		return
	var weapon := _player.weapon
	var center := _player.damage_core.global_position
	projectile_system.clear_hostile_in_radius(center, weapon.bomb_radius)
	_run_state.note_bomb_used()
	_show_bomb_blast(weapon, center)
	projectile_system.damage_targets_in_radius(center, weapon.bomb_radius, weapon.bomb_damage)


## Instances the weapon's blast visual at [param center], if it has one.
func _show_bomb_blast(weapon: PlayerWeapon, center: Vector3) -> void:
	if weapon.bomb_visual_scene == null:
		return
	var blast := weapon.bomb_visual_scene.instantiate()
	if not blast is BombBlast:
		push_error("%s: 'bomb_visual_scene' %s does not have a BombBlast root" % [get_path(), weapon.bomb_visual_scene.resource_path])
		blast.free()
		return
	world_root.add_child(blast)
	(blast as BombBlast).global_position = center
	(blast as BombBlast).setup(weapon.bomb_radius)


## The only path from an excess Power Pickup (F7-03) to the Run's score.
func _on_score_awarded(points: int) -> void:
	_run_state.add_score(points)


## Freezes the Attempt under Defeat: the tree, Active Time, the controls and the
## [CombatState] stop, and nothing is unloaded, because this arrives inside the
## ProjectileSystem's physics step. Once per life is the core's guarantee. Retry and
## Return to Menu leave from the overlay.
func _on_player_defeated() -> void:
	_set_paused(true)
	# The Defeat screen shows "Último checkpoint · <name>", or "Início da fase" for "".
	var location := _director.retry_location_name() if _director != null else ""
	interface.push_overlay(ScreenRouter.DEFEAT, {"checkpoint": location})


func _on_stage_completed(_result: Dictionary) -> void:
	# TODO(F11): show Results with the result and wait for Continue, Replay or Menu.
	_return_to_menu()


## [method _return_to_menu] ends the Run itself, so only a victory needs handling here.
func _on_run_ended(victory: bool) -> void:
	# TODO(F11): a victory shows Results in its final_victory mode instead.
	if victory:
		_return_to_menu()


## Reports every unset export with this node's path (CONVENTIONS "Setup errors are loud").
## An unavailable stage is reported when it is started, so the others still play.
func _validate_exports() -> bool:
	var missing: PackedStringArray = []
	if world_root == null:
		missing.append("world_root")
	if projectile_system == null:
		missing.append("projectile_system")
	if interface == null:
		missing.append("interface")
	if audio == null:
		missing.append("audio")
	if player_scene == null:
		missing.append("player_scene")
	for field: String in missing:
		push_error("%s: required export '%s' is not set" % [get_path(), field])
	return missing.is_empty()
