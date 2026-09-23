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
## Defeat when the player is defeated.
##
## Nothing here decides gameplay: movement, targeting and the Run's accounting belong to
## their cores. Stage completion and results arrive with F10 and F11.


## Marker every stage root has, where the player enters (GUIDE Section 5 "Stages").
const PLAYER_START_PATH := ^"PlayerStart"
## Marker whose `min` and `max` Vector3 metadata hold a stage's Flight Volume, in stage
## coordinates, when its scene records one (`docs/STAGE_02_HANDOFF.md`).
const FLIGHT_LIMITS_PATH := ^"FlightBounds/Limits"
## Score one Graze is worth (PLANEJAMENTO Section 4 "Graze and score").
const GRAZE_SCORE := 10
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
			# TODO(F10-03): retry from the latest Checkpoint; until then Retry restarts the
			# stage (PLANEJAMENTO Section 6, "before any intermediate checkpoint").
			_restart_stage()
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
	interface.show_home(ScreenRouter.HUD)


## Pause's Restart, and Defeat's Retry until F10-03: the stage from its entry values, with
## a new stage and a new ship.
func _restart_stage() -> void:
	if not _is_in_stage():
		return
	var stage: StringName = _run_state.stage_result()["stage"]
	_set_paused(false)
	_run_state.restart_stage()
	_combat_state.start(_run_state.starting_power_level())
	_load_stage(stage)
	_run_state.begin_attempt()
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
## `PlayerStart`, kept inside its Flight Volume. When the stage has no scene, no
## `PlayerStart` or no Flight Volume, or the ship is not a [PlayerController], reports
## it, changes nothing and returns false.
func _load_stage(stage_id: StringName) -> bool:
	var scene: PackedScene = stage_scenes.get(stage_id)
	if scene == null:
		push_error("%s: stage '%s' has no scene in 'stage_scenes'; it is unavailable" % [get_path(), stage_id])
		return false
	var stage := scene.instantiate()
	var player := player_scene.instantiate()
	var start := stage.get_node_or_null(PLAYER_START_PATH) as Node3D
	var bounds := _flight_bounds(stage_id, stage)
	var problem := ""
	if start == null:
		problem = "stage '%s' has no Node3D at '%s'" % [stage_id, PLAYER_START_PATH]
	elif not bounds.has_volume():
		problem = "stage '%s' has no Flight Volume: no '%s' min/max metadata and no 'stage_flight_bounds' entry" % [stage_id, FLIGHT_LIMITS_PATH]
	elif not player is PlayerController:
		problem = "'player_scene' %s does not have a PlayerController root" % player_scene.resource_path
	if not problem.is_empty():
		push_error("%s: %s; the stage is not started" % [get_path(), problem])
		stage.free()
		player.free()
		return false
	_unload_stage()
	world_root.add_child(stage)
	_player = player as PlayerController
	# Placed before it enters the tree, so its camera rig starts behind it at the marker
	# instead of easing in from the origin.
	_player.transform = start.global_transform
	world_root.add_child(_player)
	_player.setup(bounds)
	interface.get_hud().bind(_combat_state, _player.targeting, _player.camera_rig.camera)
	projectile_system.setup(bounds, _player)
	return true


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


## The only path from an excess Power Pickup (F7-03) to the Run's score.
func _on_score_awarded(points: int) -> void:
	_run_state.add_score(points)


## Freezes the Attempt under Defeat: the tree, Active Time, the controls and the
## [CombatState] stop, and nothing is unloaded, because this arrives inside the
## ProjectileSystem's physics step. Once per life is the core's guarantee. Retry and
## Return to Menu leave from the overlay.
func _on_player_defeated() -> void:
	_set_paused(true)
	# TODO(F10-03): name the latest Checkpoint once there is one.
	interface.push_overlay(ScreenRouter.DEFEAT, {"checkpoint": ""})


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
