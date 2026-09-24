class_name Pickup
extends Area3D
## Adapter on a Power Pickup or Shield Pickup root: it floats where it was spawned, drifts
## toward the player at short range, and is accepted exactly once, on contact, through
## [method CombatState.collect_power_pickup] or [method CombatState.collect_shield_pickup]
## (PLANEJAMENTO Section 4). A Shield Pickup the player touches while shielded is refused
## and stays in the world; it is collected on the first tick after the Shield breaks.
##
## The spawner (the Stage Director from F10-01, the arena harness before it) adds it to a
## PAUSABLE parent, then calls [method setup]; before that, or after a bad setup, it does
## nothing. Contact is read from its own [signal Area3D.body_entered] and
## [signal Area3D.body_exited], and acceptance runs in `_physics_process`, so duplicate
## contact callbacks credit once. No rule lives here: the Power thresholds, the excess
## score and the Shield rule are [CombatState]'s.


## Emitted exactly once, just before the pickup frees itself. [param score_awarded] is
## [constant CombatState.EXCESS_PICKUP_SCORE] for a Power Pickup taken at
## [constant CombatState.MAX_POWER_LEVEL], else 0. It is informational: those points
## already reached the Run through [signal CombatState.score_awarded], and no consumer may
## add them again.
signal accepted(pickup_id: StringName, kind: Kind, score_awarded: int)

enum Kind { POWER, SHIELD }

## Which collect call contact makes. Fixed per prefab.
@export var kind: Kind = Kind.POWER
## Distance from the player, in world units, inside which the pickup drifts toward it.
## Claude's proposal (PLANEJAMENTO says only "short range"); Astra tunes it.
@export var attraction_range: float = 6.0
## Drift speed toward the player, in units per second. Claude's proposal; Astra tunes it.
@export var attraction_speed: float = 14.0

var _pickup_id: StringName = &""
var _combat_state: CombatState
var _player: Node3D
var _player_inside: bool = false
var _accepted: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	# The ship can be replaced while the pickup stays (a respawn), so it is checked, not
	# assumed, every tick.
	if _combat_state == null or _accepted or not is_instance_valid(_player):
		return
	if _player_inside:
		_try_accept()
		if _accepted:
			return
	if _is_takeable():
		_attract(delta)


## Binds the pickup to the [param combat_state] it credits and the [param player] body
## whose contact takes it. Called once by the spawner after `add_child`. [param pickup_id]
## names it in [signal accepted]: `&"<encounter_id>/power_<n>"` or
## `&"<encounter_id>/shield_<n>"`, with n from 1. An empty id or a null argument is
## reported and the pickup stays inert.
func setup(pickup_id: StringName, combat_state: CombatState, player: Node3D) -> void:
	if pickup_id.is_empty() or combat_state == null or player == null:
		push_error("%s: setup needs a pickup id, a CombatState and the player body; the pickup stays inert" % get_path())
		return
	_pickup_id = pickup_id
	_combat_state = combat_state
	_player = player


## One collect call per tick of contact. A refused call (not live, or a Shield Pickup
## while shielded) leaves the pickup where it is, to try again next tick.
func _try_accept() -> void:
	match kind:
		Kind.POWER:
			var was_max := _combat_state.get_power_level() == CombatState.MAX_POWER_LEVEL
			if _combat_state.collect_power_pickup():
				_accept(CombatState.EXCESS_PICKUP_SCORE if was_max else 0)
		Kind.SHIELD:
			if _combat_state.collect_shield_pickup():
				_accept(0)


func _accept(score_awarded: int) -> void:
	_accepted = true
	set_deferred(&"monitoring", false)
	set_physics_process(false)
	accepted.emit(_pickup_id, kind, score_awarded)
	queue_free()


## A Power Pickup can be taken while [CombatState] is live; a Shield Pickup only while the
## player also has no Shield, so it never trails a shielded ship.
func _is_takeable() -> bool:
	if _combat_state.is_paused() or _combat_state.is_defeated():
		return false
	return kind == Kind.POWER or not _combat_state.has_shield()


## Moves toward the player at [member attraction_speed] without overshooting, only while
## within [member attraction_range].
func _attract(delta: float) -> void:
	var target := _player.global_position
	if global_position.distance_to(target) > attraction_range:
		return
	global_position = global_position.move_toward(target, attraction_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if body == _player:
		_player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player_inside = false
