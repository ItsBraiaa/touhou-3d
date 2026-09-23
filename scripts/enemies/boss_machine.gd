class_name BossMachine
extends RefCounted
## Node-free Rules Core that runs a Boss's Phases and named Attacks (PLANEJAMENTO
## Section 4 "Bosses and named attacks"). Two-Phase and three-Phase Bosses use the same
## code.
##
## F12-02's BossController ticks it from `_physics_process`, spawns the requests
## [method tick] returns, forwards the hits its hit sphere takes to [method take_damage],
## clears hostile Projectiles on [signal hostile_clear_requested] and plays cues on
## [signal step_started]. The Director awards [method get_score] on [signal defeated].
##
## [b]Timeline.[/b] [method start] begins the entry window of
## [member BossDefinition.entry_seconds]: the Boss is visible and takes damage, but
## fires nothing. Then the current Phase's Attack plays its steps in order. Each step:
## [br]1. [signal step_started] as its Anticipation of
## [member AttackStepDefinition.anticipation_seconds] begins;
## [br]2. when the Anticipation ends, the player's position is sampled once, as the aim
## point and, for [member AttackStepDefinition.follow_player_height], the emission
## altitude;
## [br]3. its Pattern runs to the end, emitting from the Boss origin raised by
## [member AttackStepDefinition.height_offset] (or at the sampled altitude), toward the
## sampled aim point;
## [br]4. [member AttackStepDefinition.pause_after] seconds of quiet.
## [br]After the last step, [member AttackDefinition.reposition_seconds] of quiet, then
## step 0 again.
##
## [b]Phases.[/b] Each Phase has its own health. A hit is capped at what the current
## Phase has left, so excess damage never skips a Phase. Depleting a Phase stops the
## Attack, asks for a hostile clear, and starts the next Phase with a transition of
## [member BossPhaseDefinition.transition_seconds] (at most 0.75 s) during which the Boss
## takes no damage and fires nothing; its Attack then starts at step 0. Depleting the
## last Phase defeats the Boss, exactly once.

## Phase [param phase_index] began and its Attack [param attack_name] is announced:
## Phase 0 on [method start], each later one when the previous is depleted, before its
## transition.
signal phase_changed(phase_index: int, attack_name: String)
## Phase [param phase_index]'s health changed to [param ratio] of its full value, 0.0
## to 1.0. Emitted on every accepted hit, with 0.0 for the hit that depletes it.
signal phase_health_changed(phase_index: int, ratio: float)
## Step [param step_index] of the current Attack began its Anticipation.
signal step_started(step_index: int)
## A Phase was depleted: the owner clears every hostile Projectile. Emitted before
## [signal phase_changed] or [signal defeated].
signal hostile_clear_requested
## The last Phase was depleted. Emitted once, after [signal hostile_clear_requested].
## The ids are the ones given to [method setup].
signal defeated(enemy_id: StringName, encounter_id: StringName)

enum _State { IDLE, ENTRY, ANTICIPATION, FIRING, PAUSE, REPOSITION, TRANSITION, DEFEATED }

var _definition: BossDefinition
var _enemy_id: StringName = &""
var _encounter_id: StringName = &""
var _rng: RandomNumberGenerator
var _emitter := PatternEmitter.new()
var _state: _State = _State.IDLE
## Seconds the current timed state lasts, and seconds spent in it so far (for FIRING,
## the span of the step's volleys).
var _state_seconds: float = 0.0
var _state_elapsed: float = 0.0
var _phase_index: int = 0
var _phase_health: int = 0
var _step_index: int = 0
## The player's position sampled when the current step's Anticipation ended.
var _aim_point := Vector3.ZERO


## Injects a valid [param definition] (asserted), the ids reported by
## [signal defeated], and the Attempt's [param rng], which every Pattern draws from.
## Every Phase starts full; nothing runs until [method start].
func setup(definition: BossDefinition, enemy_id: StringName, encounter_id: StringName,
		rng: RandomNumberGenerator) -> void:
	assert(definition != null, "BossMachine: definition is required")
	assert(rng != null, "BossMachine: rng is required")
	var errors := definition.validate()
	assert(errors.is_empty(), "BossMachine: invalid definition: %s" % ", ".join(errors))
	_definition = definition
	_enemy_id = enemy_id
	_encounter_id = encounter_id
	_rng = rng
	_emitter.reset()
	_state = _State.IDLE
	_enter_phase(0)


## Starts, or restarts, the fight at Phase 0 with every Phase full: emits
## [signal phase_changed] for Phase 0 and begins the entry window.
func start() -> void:
	assert(_definition != null, "BossMachine: setup must be called before start")
	_emitter.reset()
	_enter_phase(0)
	_begin_wait(_State.ENTRY, _definition.entry_seconds)
	phase_changed.emit(0, _phase().attack.display_name)


## Advances the timeline by [param delta] seconds and returns the hostile spawn requests
## it produced, in firing order. [param origin] is the Boss's emission origin this tick
## and [param player_position] the player's position, sampled when an Anticipation ends.
## Returns nothing before [method start], during a transition and once defeated.
func tick(delta: float, origin: Vector3, player_position: Vector3) -> Array[ProjectileSpawn]:
	assert(_definition != null, "BossMachine: setup must be called before tick")
	assert(delta >= 0.0, "BossMachine: delta must not be negative")
	var spawns: Array[ProjectileSpawn] = []
	var remaining := delta
	while true:
		match _state:
			_State.IDLE, _State.DEFEATED:
				break
			_State.FIRING:
				var fire_left := maxf(0.0, _state_seconds - _state_elapsed)
				var emitter_delta := minf(remaining, fire_left)
				var emission_origin := _emission_origin(origin)
				spawns.append_array(_emitter.tick(emitter_delta, emission_origin,
						_aim_point - emission_origin, _aim_point))
				_state_elapsed += emitter_delta
				remaining -= emitter_delta
				if not _emitter.is_finished():
					break
				_begin_wait(_State.PAUSE, _step().pause_after)
			_:
				var wait_left := maxf(0.0, _state_seconds - _state_elapsed)
				if wait_left > remaining:
					_state_elapsed += remaining
					break
				remaining -= wait_left
				_finish_wait(player_position)
	return spawns


## Applies a hit of [param amount] (above 0) to the current Phase and returns the damage
## it took, capped at what the Phase had left; the excess is discarded. Returns 0 and
## changes nothing before [method start], during a transition and once defeated.
## Emits [signal phase_health_changed]; a depleting hit then emits
## [signal hostile_clear_requested] and [signal phase_changed] or, on the last Phase,
## [signal defeated]. The state has already moved on when those signals fire.
func take_damage(amount: int) -> int:
	assert(amount > 0, "BossMachine: damage must be positive")
	if _state == _State.IDLE or _state == _State.TRANSITION or _state == _State.DEFEATED:
		return 0
	var hit_phase := _phase_index
	var applied := mini(amount, _phase_health)
	_phase_health -= applied
	if _phase_health > 0:
		phase_health_changed.emit(hit_phase, get_phase_ratio(hit_phase))
		return applied
	_emitter.reset()
	var is_last := hit_phase == _definition.phases.size() - 1
	if is_last:
		_state = _State.DEFEATED
	else:
		_enter_phase(hit_phase + 1)
		_begin_wait(_State.TRANSITION, _phase().transition_seconds)
	phase_health_changed.emit(hit_phase, 0.0)
	hostile_clear_requested.emit()
	if is_last:
		defeated.emit(_enemy_id, _encounter_id)
	else:
		phase_changed.emit(_phase_index, _phase().attack.display_name)
	return applied


## Index of the current Phase, from 0; the last one once defeated.
func get_phase_index() -> int:
	return _phase_index


## Phases of this Boss, 2 or 3.
func get_phase_count() -> int:
	return _definition.phases.size()


## Health left in Phase [param index] as a fraction of its full value: 0.0 for a
## depleted Phase, 1.0 for one not reached yet.
func get_phase_ratio(index: int) -> float:
	assert(index >= 0 and index < get_phase_count(), "BossMachine: no Phase %d" % index)
	if index < _phase_index:
		return 0.0
	if index > _phase_index:
		return 1.0
	return float(_phase_health) / float(_phase().health)


## Whether a Phase transition is running: no damage and no fire.
func is_in_transition() -> bool:
	return _state == _State.TRANSITION


## Whether the last Phase was depleted.
func is_defeated() -> bool:
	return _state == _State.DEFEATED


## Score the Director awards on defeat, from the Definition.
func get_score() -> int:
	return _definition.score


func _phase() -> BossPhaseDefinition:
	return _definition.phases[_phase_index]


func _step() -> AttackStepDefinition:
	return _phase().attack.steps[_step_index]


## Makes Phase [param index] current and full, with its Attack back at step 0.
func _enter_phase(index: int) -> void:
	_phase_index = index
	_phase_health = _phase().health
	_step_index = 0


func _begin_wait(state: _State, seconds: float) -> void:
	_state = state
	_state_seconds = seconds
	_state_elapsed = 0.0


## Leaves a timed wait whose time is up and enters what follows it.
func _finish_wait(player_position: Vector3) -> void:
	match _state:
		_State.ENTRY, _State.TRANSITION, _State.REPOSITION:
			_begin_step(0)
		_State.ANTICIPATION:
			_begin_firing(player_position)
		_State.PAUSE:
			if _step_index + 1 < _phase().attack.steps.size():
				_begin_step(_step_index + 1)
			else:
				_begin_wait(_State.REPOSITION, _phase().attack.reposition_seconds)


func _begin_step(index: int) -> void:
	_step_index = index
	_begin_wait(_State.ANTICIPATION, _step().anticipation_seconds)
	step_started.emit(index)


## Samples the aim point and starts the step's Pattern. The FIRING state lasts the span
## of its volleys; the emitter decides when each one is due.
func _begin_firing(player_position: Vector3) -> void:
	_aim_point = player_position
	var pattern := _step().pattern
	_emitter.setup(pattern, _rng)
	_emitter.start()
	_begin_wait(_State.FIRING, float(pattern.volley_count - 1) * pattern.volley_interval)


func _emission_origin(origin: Vector3) -> Vector3:
	var step := _step()
	if step.follow_player_height:
		return Vector3(origin.x, _aim_point.y, origin.z)
	return origin + Vector3.UP * step.height_offset
