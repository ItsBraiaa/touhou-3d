class_name CombatState
extends RefCounted
## Rules Core for the player's combat resources during one life: Health, the Shield,
## Bombs, Power Level and Power Progress, Invulnerability and defeat, reported through
## change signals.
##
## Node-free (ADR-0001). The F7 combat adapter ticks it from `_physics_process`, feeds it
## the Bomb button through [method update_bomb_input] once per physics tick, and reports
## hits and collected Pickups; the Session calls [method start] at stage entry,
## [method refill] on a Checkpoint's first activation and [method capture] and
## [method restore] for Retry, and forwards [signal bomb_activated] and
## [signal score_awarded] to [RunState]. The HUD observes the signals and never mutates
## the core. Graze, score totals and the clearing of Projectiles are not held here.
##
## The core is live while it is neither paused nor defeated. Every call that changes the
## resources is ignored unless it is live; [method start], [method restore] and
## [method set_paused] always work. Each change signal is emitted only when its value
## actually changes, and carries the new value.


## Health changed to [param health], from 0 to [constant MAX_HEALTH].
signal health_changed(health: int)
## The Shield broke on a hit ([param shielded] false) or came back ([param shielded]
## true) through a Shield Pickup, [method refill], [method start] or [method restore].
signal shield_changed(shielded: bool)
## The Bomb count changed to [param bombs]: a Bomb went off, or [method refill],
## [method start] or [method restore] set it.
signal bombs_changed(bombs: int)
## The Power Level or the Power Progress changed. [param level] is the Power Level, from
## [constant MIN_POWER_LEVEL] to [constant MAX_POWER_LEVEL]; [param progress] is the
## Power Pickups collected toward the next one, always 0 at [constant MAX_POWER_LEVEL].
signal power_changed(level: int, progress: int)
## Invulnerability began ([param invulnerable] true) or ended. Not emitted when a Bomb
## extends a window that is already running.
signal invulnerability_changed(invulnerable: bool)
## A Bomb went off. The combat adapter clears hostile Projectiles around the player and
## the Session calls [method RunState.note_bomb_used].
signal bomb_activated
## A Power Pickup collected at [constant MAX_POWER_LEVEL] is worth [param points]; the
## Session forwards them to [method RunState.add_score].
signal score_awarded(points: int)
## Health reached 0 and the core is defeated. Emitted once per life, always after the
## [signal health_changed] that reports the 0.
signal defeated

## What [method take_hit] did with a hit.
enum HitOutcome {
	## Not live, or Invulnerable: nothing changed.
	REJECTED,
	## The Shield took the whole hit and broke; Health is untouched.
	ABSORBED,
	## Health dropped and Invulnerability began.
	DAMAGED,
	## Health reached 0 and the core is defeated.
	DEFEATED,
}

## Health at stage entry and after a refill. Health is a percentage (CONTEXT "Health").
const MAX_HEALTH := 100
## Health a common Projectile takes, the default damage of [method take_hit]
## (PLANEJAMENTO Section 4).
const HIT_DAMAGE := 10
## Seconds of Invulnerability after a hit the core survives, whether the Shield absorbed
## it or Health took it (PLANEJAMENTO Section 4).
const HIT_INVULNERABILITY := 1.0
## Seconds of Invulnerability a Bomb guarantees from its activation (PLANEJAMENTO
## Section 4).
const BOMB_INVULNERABILITY := 2.0
## Bombs at stage entry and after a refill.
const MAX_BOMBS := 2
## Lowest Power Level, the one Stage 1 starts at.
const MIN_POWER_LEVEL := 1
## Highest Power Level. Power Pickups collected there award score instead.
const MAX_POWER_LEVEL := 3
## Power Pickups that raise the Power Level by one (PLANEJAMENTO Section 4).
const PICKUPS_PER_LEVEL := 5
## Points a Power Pickup is worth at [constant MAX_POWER_LEVEL] (PLANEJAMENTO Section 4).
const EXCESS_PICKUP_SCORE := 50


var _health: int = MAX_HEALTH
var _shielded: bool = true
var _bombs: int = MAX_BOMBS
var _power_level: int = MIN_POWER_LEVEL
var _power_progress: int = 0
## Seconds of Invulnerability left; 0.0 when not Invulnerable.
var _invulnerability: float = 0.0
var _defeated: bool = false
var _paused: bool = false
## The Bomb button state [method update_bomb_input] last recorded. It starts held, and
## [method start], [method restore] and pausing set it held, so only a press that begins
## after them can activate a Bomb.
var _bomb_button_down: bool = true


## Enters a stage with full resources: [constant MAX_HEALTH] Health, the Shield,
## [constant MAX_BOMBS] Bombs and the given Power Level and Power Progress, with no
## Invulnerability, not defeated and unpaused. The Session calls it on Start, Direct
## Stage, Restart and a Campaign transition; a Direct Stage 2 starts at Power Level 2.
## A Bomb press already held when it is called activates nothing until it is released.
## Emits the change signals for what changed.
func start(power_level: int, power_progress: int = 0) -> void:
	assert(power_level >= MIN_POWER_LEVEL and power_level <= MAX_POWER_LEVEL,
			"CombatState: Power Level %d is out of range" % power_level)
	assert(power_progress >= 0 and power_progress < PICKUPS_PER_LEVEL,
			"CombatState: Power Progress %d is out of range" % power_progress)
	assert(power_level < MAX_POWER_LEVEL or power_progress == 0,
			"CombatState: Power Progress must be 0 at the highest Power Level")
	_set_health(MAX_HEALTH)
	_set_shielded(true)
	_set_bombs(MAX_BOMBS)
	_set_power(power_level, power_progress)
	_set_invulnerability(0.0)
	_defeated = false
	_paused = false
	_bomb_button_down = true


## Applies a hit of [param damage] Health and says what it did (PLANEJAMENTO Section 4).
## Rejected while not live or Invulnerable. Otherwise the Shield, when up, absorbs the
## whole hit whatever its damage and breaks; without it Health drops, never below 0. A
## hit the core survives starts [constant HIT_INVULNERABILITY] seconds of
## Invulnerability, so every later hit in the same tick is rejected and call order
## decides which one lands. A hit that takes Health to 0 defeats the core and starts no
## Invulnerability. Power Level and Power Progress never change on a hit.
func take_hit(damage: int = HIT_DAMAGE) -> HitOutcome:
	assert(damage > 0, "CombatState: hit damage must be positive, got %d" % damage)
	if not _is_live() or is_invulnerable():
		return HitOutcome.REJECTED
	if _shielded:
		_set_shielded(false)
		_set_invulnerability(HIT_INVULNERABILITY)
		return HitOutcome.ABSORBED
	_set_health(maxi(0, _health - damage))
	if _health == 0:
		_defeated = true
		defeated.emit()
		return HitOutcome.DEFEATED
	_set_invulnerability(HIT_INVULNERABILITY)
	return HitOutcome.DAMAGED


## Counts Invulnerability down by one physics step of [param delta] seconds, and emits
## [signal invulnerability_changed] when it runs out. Nothing counts while paused or
## defeated.
func tick(delta: float) -> void:
	if not _is_live() or not is_invulnerable():
		return
	_set_invulnerability(maxf(0.0, _invulnerability - delta))


## Records the Bomb button state for this physics tick and returns true when this call
## activated a Bomb. Only a press, [param held] true when the recorded state was
## released, can activate one, and only while live with a Bomb left: it spends the Bomb
## and grants [constant BOMB_INVULNERABILITY] seconds of Invulnerability, keeping a
## longer window that is already running. A press that cannot activate is spent anyway,
## so holding the button never fires later, and one press spends one Bomb however long
## it is held. [param held] is recorded on every call, live or not. [method start],
## [method restore] and pausing record the button as held, so a press begun before them
## (B on the Pause menu is Back and resumes the game) needs a release first.
func update_bomb_input(held: bool) -> bool:
	var pressed := held and not _bomb_button_down
	_bomb_button_down = held
	if not pressed or not _is_live() or _bombs <= 0:
		return false
	_set_bombs(_bombs - 1)
	_set_invulnerability(maxf(_invulnerability, BOMB_INVULNERABILITY))
	bomb_activated.emit()
	return true


## Collects a Power Pickup and returns whether it was taken, which is false only while
## not live. Below [constant MAX_POWER_LEVEL] it adds one to Power Progress, and every
## [constant PICKUPS_PER_LEVEL] raise the Power Level by one with Power Progress back at
## 0. At [constant MAX_POWER_LEVEL] it emits [signal score_awarded] with
## [constant EXCESS_PICKUP_SCORE] instead (PLANEJAMENTO Section 4).
func collect_power_pickup() -> bool:
	if not _is_live():
		return false
	if _power_level >= MAX_POWER_LEVEL:
		score_awarded.emit(EXCESS_PICKUP_SCORE)
		return true
	var progress := _power_progress + 1
	if progress >= PICKUPS_PER_LEVEL:
		_set_power(_power_level + 1, 0)
	else:
		_set_power(_power_level, progress)
	return true


## Collects a Shield Pickup and returns whether it was taken: false while not live or
## while the Shield is already up, in which case the Pickup stays in the world
## (PLANEJAMENTO Section 4). The Shield never stacks.
func collect_shield_pickup() -> bool:
	if not _is_live() or _shielded:
		return false
	_set_shielded(true)
	return true


## Restores [constant MAX_HEALTH] Health, the Shield and [constant MAX_BOMBS] Bombs. The
## Session calls it on a Checkpoint's first activation. Power Level, Power Progress and
## Invulnerability are left alone. Ignored unless live.
func refill() -> void:
	if not _is_live():
		return
	_set_health(MAX_HEALTH)
	_set_shielded(true)
	_set_bombs(MAX_BOMBS)


## Sets the pause flag. While it is set the core is not live: nothing counts down and no
## hit, Pickup or Bomb is accepted. Pausing records the Bomb button as held, so a press
## made on the Pause menu cannot activate a Bomb on resume. Emits no signal.
func set_paused(paused: bool) -> void:
	_paused = paused
	if paused:
		_bomb_button_down = true


## The resources of this life as a new Dictionary of primitives that shares nothing with
## this core (CONVENTIONS "Snapshots"): `health` (int), `has_shield` (bool), `bombs`,
## `power_level` and `power_progress` (int). Invulnerability, defeat, the pause flag and
## the Bomb button are transient and not in it, so a Retry removes damage timers
## (STAGE_DESIGN "Checkpoint contract").
func capture() -> Dictionary:
	return {
		"health": _health,
		"has_shield": _shielded,
		"bombs": _bombs,
		"power_level": _power_level,
		"power_progress": _power_progress,
	}


## Puts back what [method capture] returned, not defeated and with no Invulnerability.
## [param data] is read, not kept. The Bomb button is recorded as held and the pause
## flag is left alone. Emits the change signals for what changed. The Session calls it on
## Retry with the Checkpoint's capture.
func restore(data: Dictionary) -> void:
	_set_health(data["health"])
	_set_shielded(data["has_shield"])
	_set_bombs(data["bombs"])
	_set_power(data["power_level"], data["power_progress"])
	_set_invulnerability(0.0)
	_defeated = false
	_bomb_button_down = true


## Health, from 0 to [constant MAX_HEALTH].
func get_health() -> int:
	return _health


## Whether the Shield is up.
func has_shield() -> bool:
	return _shielded


## Bombs left, from 0 to [constant MAX_BOMBS].
func get_bombs() -> int:
	return _bombs


## Power Level, from [constant MIN_POWER_LEVEL] to [constant MAX_POWER_LEVEL].
func get_power_level() -> int:
	return _power_level


## Power Pickups collected toward the next Power Level: 0 to
## [constant PICKUPS_PER_LEVEL] - 1, and always 0 at [constant MAX_POWER_LEVEL].
func get_power_progress() -> int:
	return _power_progress


## Whether Invulnerability is running, so hits are rejected.
func is_invulnerable() -> bool:
	return _invulnerability > 0.0


## Whether Health reached 0 in this life. Cleared by [method start] and [method restore].
func is_defeated() -> bool:
	return _defeated


## Whether the pause flag is set.
func is_paused() -> bool:
	return _paused


func _is_live() -> bool:
	return not _paused and not _defeated


func _set_health(health: int) -> void:
	if health == _health:
		return
	_health = health
	health_changed.emit(health)


func _set_shielded(shielded: bool) -> void:
	if shielded == _shielded:
		return
	_shielded = shielded
	shield_changed.emit(shielded)


func _set_bombs(bombs: int) -> void:
	if bombs == _bombs:
		return
	_bombs = bombs
	bombs_changed.emit(bombs)


func _set_power(level: int, progress: int) -> void:
	if level == _power_level and progress == _power_progress:
		return
	_power_level = level
	_power_progress = progress
	power_changed.emit(level, progress)


## Sets the seconds of Invulnerability left and emits [signal invulnerability_changed]
## only when that starts or ends it.
func _set_invulnerability(seconds: float) -> void:
	var was_invulnerable := is_invulnerable()
	_invulnerability = seconds
	if is_invulnerable() != was_invulnerable:
		invulnerability_changed.emit(is_invulnerable())
