class_name ProjectileField
extends RefCounted
## Rules Core that holds every Projectile of both factions in one set of packed arrays,
## moves them each physics tick, removes them, and sweeps the hostile ones against the
## player's Core and Graze Volume (ADR-0004).
##
## Node-free (ADR-0001): no Node, SceneTree, physics or timer. F6-02's ProjectileSystem
## ticks it from `_physics_process`, feeds [method set_player] before every tick,
## implements the obstacle query with a physics ray against collision layer 1 and draws
## it from [method get_positions] and [method get_radii]. The field only decides
## contact: F7-01 turns [signal player_hit] into [method CombatState.take_hit] and
## [signal grazed] into Graze and score.
##
## [b]Tick order.[/b] [method tick] makes one pass over the alive Projectiles in
## ascending slot order. For each one:
## [br]1. Its lifetime goes down by the delta. At 0 or below it is removed without moving.
## [br]2. Otherwise its segment runs from its position to position + velocity × delta.
## [br]3. When the obstacle query says scenery or a closed Gate blocks that segment, it
## is removed where it stands, before any Core or target sweep: a wall between a bullet
## and the player protects the player, and the error is under one tick of travel and
## never in the bullet's favor.
## [br]4. A HOSTILE Projectile is swept against the player (below); F5-03 adds the target
## sweep for PLAYER ones.
## [br]5. It moves to the segment's end, and is removed when that end is outside the
## bounds (the Flight Volume).
##
## [b]Core sweep and Graze.[/b] With a player set, each HOSTILE Projectile's segment is
## taken in the player's frame, from `from - previous_center` to `to - center`, and its
## closest distance d to the origin decides contact, so neither a fast bullet nor a fast
## player can tunnel through. PLAYER Projectiles never touch the player.
## [br]- [b]Core contact[/b], d <= core radius + Projectile radius: the Projectile is
## removed and [signal player_hit] queued. It never also grazes: hit before Graze.
## [br]- [b]Graze contact[/b], d <= Graze radius + Projectile radius without Core
## contact: if the Projectile's Graze is not spent, it is spent and [signal grazed]
## queued. Each Projectile grazes at most once in its life.
## [br]- [b]Invulnerable[/b]: a Core contact reports nothing and the Projectile passes
## through. Any contact, Core or Graze, spends the Projectile's Graze for good, so
## Invulnerability can never pre-load a Graze for later (the strict reading of
## PLANEJAMENTO Section 4, "disable new graze awards during invulnerability").
## [br]- [b]The first hit of a tick makes the rest of that tick invulnerable.[/b] The hit
## reaches CombatState only after the pass, where it starts Invulnerability or defeat, so
## Core contacts in higher slots of the same pass pass through, their contacts are spent,
## and the tick queues no further Graze. A Graze already queued by a lower slot stands.
##
## [b]Events rule.[/b] Events decided during the pass are buffered and emitted after it,
## in ascending slot order. A listener may call [method spawn], [method despawn] or a
## clear; a Projectile spawned then is first moved on the next tick. [method clear_all]
## from a listener also drops the tick's events not yet emitted. Neither a listener nor
## the obstacle query may call [method tick], and the obstacle query must not call back
## into the field at all.
##
## [b]Capacity.[/b] Fixed at [method setup]. When every slot is alive a new request is
## refused and counted ([method get_refused_count]); an existing Projectile is never
## evicted, because a bullet the player is reading must not vanish. A spawn takes the
## lowest free slot, so the alive Projectiles stay packed at the start of the arrays.
##
## [b]Ids.[/b] Every spawn returns a new id, never handed out again for this field's
## lifetime, across slot reuse, [method clear_all] and [method setup]. An id packs the
## slot in its low [constant SLOT_BITS] bits and a field-wide spawn serial above them, so
## it is a 64-bit int: keep it in an int or a PackedInt64Array.

## A HOSTILE Projectile met the player's Core while the player was not invulnerable, and
## was removed. [param damage] is its [member ProjectileSpawn.damage]. Emitted after the
## pass; at most once per tick.
signal player_hit(projectile_id: int, damage: int)
## A HOSTILE Projectile passed through the player's Graze Volume without touching the
## Core, while the player was not invulnerable, for the first time in its life. Emitted
## after the pass.
signal grazed(projectile_id: int)

## What the player sweep found for one Projectile in one tick.
enum _Contact { NONE, GRAZE, CORE }
## A buffered event.
enum _Event { PLAYER_HIT, GRAZED }

## Returned by [method spawn] when the field is full. Never a valid id.
const NO_PROJECTILE := -1
## Bits of an id that hold the slot.
const SLOT_BITS := 16
## Largest capacity [method setup] accepts.
const MAX_CAPACITY := 1 << SLOT_BITS
const _SLOT_MASK := MAX_CAPACITY - 1

var _capacity: int = 0
var _bounds := AABB()
var _obstacle_query := Callable()
var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
## Seconds left per slot.
var _lifetimes := PackedFloat32Array()
var _radii := PackedFloat32Array()
var _damages := PackedInt32Array()
## A [enum ProjectileSpawn.Faction] per slot.
var _factions := PackedInt32Array()
## The id each slot was last spawned with.
var _ids := PackedInt64Array()
## 1 for an alive slot, 0 for a free one.
var _alive := PackedByteArray()
## 1 once the slot's Projectile has spent its Graze.
var _graze_spent := PackedByteArray()
## Free slots in ascending order, so a spawn takes the first.
var _free_slots := PackedInt32Array()
## Alive Projectiles per [enum ProjectileSpawn.Faction].
var _counts := PackedInt32Array([0, 0])
## One past the highest slot that may be alive; loops stop there.
var _high_water: int = 0
## Spawns ever made by this field: the upper part of the next id.
var _spawn_serial: int = 0
var _refused_count: int = 0

var _has_player: bool = false
var _player_previous_center := Vector3.ZERO
var _player_center := Vector3.ZERO
var _core_radius: float = 0.0
var _graze_radius: float = 0.0
var _player_invulnerable: bool = false

## The events of the current tick, in slot order: one [enum _Event], the Projectile id
## and the damage (0 for a Graze) per entry.
var _event_kinds := PackedInt32Array()
var _event_ids := PackedInt64Array()
var _event_damages := PackedInt32Array()


## Sizes the field for [param capacity] Projectiles (1 to [constant MAX_CAPACITY]),
## empties it and resets the refusal counter. Ids handed out before stay dead. The player
## set by [method set_player] is kept.
## [param bounds] is the Flight Volume as an AABB (a position and a size, which must be
## positive). [param obstacle_query] is `func(from: Vector3, to: Vector3) -> bool`,
## true when scenery or a closed Gate blocks the segment; an invalid Callable means
## there are no obstacles.
func setup(capacity: int, bounds: AABB, obstacle_query: Callable) -> void:
	assert(capacity > 0 and capacity <= MAX_CAPACITY,
			"ProjectileField: capacity %d is outside 1..%d" % [capacity, MAX_CAPACITY])
	_capacity = capacity
	set_bounds(bounds)
	_obstacle_query = obstacle_query
	_positions.resize(capacity)
	_velocities.resize(capacity)
	_lifetimes.resize(capacity)
	_radii.resize(capacity)
	_damages.resize(capacity)
	_factions.resize(capacity)
	_ids.resize(capacity)
	_alive.resize(capacity)
	_graze_spent.resize(capacity)
	_refused_count = 0
	clear_all()


## Spawns a Projectile from a copy of [param request] and returns its id, or
## [constant NO_PROJECTILE] when every slot is alive (the request is refused and
## counted). The request's lifetime and radius must be above 0. A request outside the
## bounds is accepted and culled on its first [method tick]. The new Projectile first
## moves on the next [method tick], with its Graze unspent.
func spawn(request: ProjectileSpawn) -> int:
	# Constant messages: an assert message is built on every call, and spawn is hot.
	assert(_capacity > 0, "ProjectileField: setup() must run before spawn()")
	assert(request.lifetime > 0.0, "ProjectileField: a spawn's lifetime must be positive")
	assert(request.radius > 0.0, "ProjectileField: a spawn's radius must be positive")
	# CombatState.take_hit asserts a positive damage; catch a bad one where it is made.
	assert(request.damage > 0, "ProjectileField: a spawn's damage must be positive")
	if _free_slots.is_empty():
		_refused_count += 1
		return NO_PROJECTILE
	var slot := _free_slots[0]
	_free_slots.remove_at(0)
	var id := (_spawn_serial << SLOT_BITS) | slot
	_spawn_serial += 1
	_ids[slot] = id
	_positions[slot] = request.position
	_velocities[slot] = request.velocity
	_lifetimes[slot] = request.lifetime
	_radii[slot] = request.radius
	_damages[slot] = request.damage
	_factions[slot] = request.faction
	_graze_spent[slot] = 0
	_alive[slot] = 1
	_counts[request.faction] += 1
	_high_water = maxi(_high_water, slot + 1)
	return id


## Advances every alive Projectile by one physics step of [param delta] seconds, in the
## tick order of the class description (lifetime, obstacle, player sweep, move, bounds),
## then emits the tick's events in slot order.
func tick(delta: float) -> void:
	# A hit this tick reaches CombatState only after the pass, so the rest of the pass
	# treats the player as invulnerable (class description).
	var invulnerable := _player_invulnerable
	var last_alive := -1
	for slot: int in _high_water:
		if _alive[slot] == 0:
			continue
		var lifetime := _lifetimes[slot] - delta
		if lifetime <= 0.0:
			_remove(slot)
			continue
		_lifetimes[slot] = lifetime
		var from := _positions[slot]
		var to := from + _velocities[slot] * delta
		if _obstacle_query.is_valid() and _obstacle_query.call(from, to):
			_remove(slot)
			continue
		if _has_player and _factions[slot] == ProjectileSpawn.Faction.HOSTILE:
			var contact := _player_contact(from, to, _radii[slot])
			if contact == _Contact.CORE and not invulnerable:
				_queue_event(_Event.PLAYER_HIT, _ids[slot], _damages[slot])
				_remove(slot)
				invulnerable = true
				continue
			if contact != _Contact.NONE and _graze_spent[slot] == 0:
				_graze_spent[slot] = 1
				if contact == _Contact.GRAZE and not invulnerable:
					_queue_event(_Event.GRAZED, _ids[slot], 0)
		_positions[slot] = to
		if not _bounds.has_point(to):
			_remove(slot)
			continue
		last_alive = slot
	_high_water = last_alive + 1
	_emit_events()


## Sets the player for the sweep of every later [method tick], until called again: the
## Core's center at the previous tick ([param previous_center]) and now ([param center]),
## the Core and Graze Volume radii in world units (Graze at least Core, both above 0),
## and whether the player is invulnerable. The adapter calls it before every tick.
func set_player(previous_center: Vector3, center: Vector3, core_radius: float,
		graze_radius: float, invulnerable: bool) -> void:
	assert(core_radius > 0.0 and graze_radius >= core_radius,
			"ProjectileField: set_player needs 0 < core_radius <= graze_radius")
	_has_player = true
	_player_previous_center = previous_center
	_player_center = center
	_core_radius = core_radius
	_graze_radius = graze_radius
	_player_invulnerable = invulnerable


## Removes the player: later ticks sweep nothing against it (between stages, after the
## ship is freed). A new field starts with no player.
func clear_player() -> void:
	_has_player = false


## Removes the Projectile [param id] and returns true. An unknown, dead or recycled id
## changes nothing and returns false.
func despawn(id: int) -> bool:
	var slot := _slot_of(id)
	if slot == -1:
		return false
	_remove(slot)
	return true


## Removes every Projectile of both factions, awarding nothing. The id counter is kept,
## so an old id stays dead after its slot is reused. Called from a listener, it also
## drops the tick's events not yet emitted (a defeat that unloads the stage).
func clear_all() -> void:
	_alive.fill(0)
	_free_slots.resize(_capacity)
	for slot: int in _capacity:
		_free_slots[slot] = slot
	_counts.fill(0)
	_high_water = 0
	_clear_events()


## Replaces the Flight Volume, a position and a positive size. Projectiles outside it
## are removed on the next [method tick], not by this call.
func set_bounds(bounds: AABB) -> void:
	assert(bounds.has_volume(), "ProjectileField: bounds %s have no volume" % bounds)
	_bounds = bounds


## Alive Projectiles of [param faction].
func count(faction: ProjectileSpawn.Faction) -> int:
	return _counts[faction]


## Whether [param id] names an alive Projectile.
func is_alive(id: int) -> bool:
	return _slot_of(id) != -1


## World position of the Projectile [param id], or [constant Vector3.ZERO] when it is
## not alive.
func get_position(id: int) -> Vector3:
	var slot := _slot_of(id)
	if slot == -1:
		return Vector3.ZERO
	return _positions[slot]


## Spawn requests refused because the field was full, since the last [method setup].
func get_refused_count() -> int:
	return _refused_count


## Slots the field was sized for in [method setup].
func get_capacity() -> int:
	return _capacity


## Positions of the alive Projectiles of [param faction] in ascending slot order, as a new
## array; parallel to [method get_radii]. For rendering.
func get_positions(faction: ProjectileSpawn.Faction) -> PackedVector3Array:
	var positions := PackedVector3Array()
	positions.resize(_counts[faction])
	var index := 0
	for slot: int in _high_water:
		if _alive[slot] != 0 and _factions[slot] == faction:
			positions[index] = _positions[slot]
			index += 1
	return positions


## Radii of the alive Projectiles of [param faction] in ascending slot order, as a new
## array; parallel to [method get_positions]. For rendering.
func get_radii(faction: ProjectileSpawn.Faction) -> PackedFloat32Array:
	var radii := PackedFloat32Array()
	radii.resize(_counts[faction])
	var index := 0
	for slot: int in _high_water:
		if _alive[slot] != 0 and _factions[slot] == faction:
			radii[index] = _radii[slot]
			index += 1
	return radii


## The slot of the alive Projectile [param id], or -1.
func _slot_of(id: int) -> int:
	if id < 0:
		return -1
	var slot := id & _SLOT_MASK
	if slot >= _capacity or _alive[slot] == 0 or _ids[slot] != id:
		return -1
	return slot


func _remove(slot: int) -> void:
	_alive[slot] = 0
	_counts[_factions[slot]] -= 1
	_free_slots.insert(_free_slots.bsearch(slot), slot)


## Which of the player's spheres a Projectile of [param radius] touches while it moves
## from [param from] to [param to], taken relative to the player moving from its previous
## center to its current one.
func _player_contact(from: Vector3, to: Vector3, radius: float) -> _Contact:
	var start := from - _player_previous_center
	var travel := (to - _player_center) - start
	# The point of the relative segment closest to the Core's center.
	var along := 0.0
	var travel_length_squared := travel.length_squared()
	if travel_length_squared > 0.0:
		along = clampf(-start.dot(travel) / travel_length_squared, 0.0, 1.0)
	var distance_squared := (start + travel * along).length_squared()
	if distance_squared <= (_core_radius + radius) * (_core_radius + radius):
		return _Contact.CORE
	if distance_squared <= (_graze_radius + radius) * (_graze_radius + radius):
		return _Contact.GRAZE
	return _Contact.NONE


func _queue_event(kind: _Event, id: int, damage: int) -> void:
	_event_kinds.append(kind)
	_event_ids.append(id)
	_event_damages.append(damage)


## Emits the buffered events in order. A listener's [method clear_all] empties the
## buffer, which ends the loop.
func _emit_events() -> void:
	var index := 0
	while index < _event_ids.size():
		var id := _event_ids[index]
		match _event_kinds[index]:
			_Event.PLAYER_HIT:
				player_hit.emit(id, _event_damages[index])
			_Event.GRAZED:
				grazed.emit(id)
		index += 1
	_clear_events()


func _clear_events() -> void:
	_event_kinds.clear()
	_event_ids.clear()
	_event_damages.clear()
