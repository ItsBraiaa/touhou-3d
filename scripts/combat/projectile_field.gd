class_name ProjectileField
extends RefCounted
## Rules Core that holds every Projectile of both factions in one set of packed arrays,
## moves them each physics tick and removes them (ADR-0004).
##
## Node-free (ADR-0001): no Node, SceneTree, physics or timer. F6-02's ProjectileSystem
## ticks it from `_physics_process`, implements the obstacle query with a physics ray
## against collision layer 1 and draws it from [method get_positions] and
## [method get_radii].
##
## [b]Tick order.[/b] [method tick] makes one pass over the alive Projectiles in
## ascending slot order. For each one:
## [br]1. Its lifetime goes down by the delta. At 0 or below it is removed without moving.
## [br]2. Otherwise its segment runs from its position to position + velocity × delta.
## [br]3. When the obstacle query says scenery or a closed Gate blocks that segment, it
## is removed where it stands, before any Core or target sweep: a wall between a bullet
## and the player protects the player, and the error is under one tick of travel and
## never in the bullet's favor.
## [br]4. F5-02 adds the Core sweep here, and F5-03 the target sweep.
## [br]5. It moves to the segment's end, and is removed when that end is outside the
## bounds (the Flight Volume).
##
## [b]Events rule[/b] (for F5-02 and F5-03, which add the signals): events decided during
## the pass are buffered and emitted after it, in ascending slot order. A listener may
## call [method spawn], [method despawn] or a clear; a Projectile spawned then is first
## moved on the next tick. [method clear_all] from a listener also drops the tick's
## events not yet emitted. The obstacle query itself must not call back into the field.
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
## Free slots in ascending order, so a spawn takes the first.
var _free_slots := PackedInt32Array()
## Alive Projectiles per [enum ProjectileSpawn.Faction].
var _counts := PackedInt32Array([0, 0])
## One past the highest slot that may be alive; loops stop there.
var _high_water: int = 0
## Spawns ever made by this field: the upper part of the next id.
var _spawn_serial: int = 0
var _refused_count: int = 0


## Sizes the field for [param capacity] Projectiles (1 to [constant MAX_CAPACITY]),
## empties it and resets the refusal counter. Ids handed out before stay dead.
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
	_refused_count = 0
	clear_all()


## Spawns a Projectile from a copy of [param request] and returns its id, or
## [constant NO_PROJECTILE] when every slot is alive (the request is refused and
## counted). The request's lifetime and radius must be above 0. A request outside the
## bounds is accepted and culled on its first [method tick]. The new Projectile first
## moves on the next [method tick].
func spawn(request: ProjectileSpawn) -> int:
	# Constant messages: an assert message is built on every call, and spawn is hot.
	assert(_capacity > 0, "ProjectileField: setup() must run before spawn()")
	assert(request.lifetime > 0.0, "ProjectileField: a spawn's lifetime must be positive")
	assert(request.radius > 0.0, "ProjectileField: a spawn's radius must be positive")
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
	_alive[slot] = 1
	_counts[request.faction] += 1
	_high_water = maxi(_high_water, slot + 1)
	return id


## Advances every alive Projectile by one physics step of [param delta] seconds, in the
## tick order of the class description: lifetime, obstacle, move, bounds.
func tick(delta: float) -> void:
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
		_positions[slot] = to
		if not _bounds.has_point(to):
			_remove(slot)
			continue
		last_alive = slot
	_high_water = last_alive + 1


## Removes the Projectile [param id] and returns true. An unknown, dead or recycled id
## changes nothing and returns false.
func despawn(id: int) -> bool:
	var slot := _slot_of(id)
	if slot == -1:
		return false
	_remove(slot)
	return true


## Removes every Projectile of both factions, awarding nothing. The id counter is kept,
## so an old id stays dead after its slot is reused.
func clear_all() -> void:
	_alive.fill(0)
	_free_slots.resize(_capacity)
	for slot: int in _capacity:
		_free_slots[slot] = slot
	_counts.fill(0)
	_high_water = 0


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
