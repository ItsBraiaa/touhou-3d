extends TestCase
## Behavior of the [ProjectileField] Rules Core, F5-01: spawn, move and cull, stable ids,
## the full-field policy and the render read-out.
##
## Expected values come from the design documents, not from the implementation.
## ADR-0004: every Projectile of both factions lives in one field; Projectiles collide
## with scenery and closed Gates through an injected obstacle query and are removed on
## contact. ENGINEERING_BRIEF Section 4.D: movement must survive frame-rate variation and
## Projectiles must be cleaned up when encounters end. CONVENTIONS "Collision":
## Projectiles die on scenery and closed Gates, on lifetime end, and on leaving the
## Flight Volume. The ticket (.scratch/projectile-field/issues/01) fixes the tick order,
## the full-field policy (refuse the new request, never evict) and the id rule (never
## reused).

const PLAYER := ProjectileSpawn.Faction.PLAYER
const HOSTILE := ProjectileSpawn.Faction.HOSTILE
## A 100-unit cube around the origin: the Flight Volume of most tests.
const WIDE_BOUNDS := AABB(Vector3(-50.0, -50.0, -50.0), Vector3(100.0, 100.0, 100.0))
const EPS := 0.0001

var _field: ProjectileField


func before_each() -> void:
	_field = ProjectileField.new()
	_field.setup(8, WIDE_BOUNDS, Callable())


func test_spawn_returns_distinct_ids_and_counts_by_faction() -> void:
	var request := ProjectileSpawn.new(Vector3(1.0, 2.0, 3.0), Vector3.ZERO, PLAYER)
	var first := _field.spawn(request)
	# The field copies the request: changing and reusing it leaves the first one alone.
	request.position = Vector3(4.0, 5.0, 6.0)
	var second := _field.spawn(request)
	var third := _field.spawn(_hostile(Vector3.ZERO))
	var fourth := _field.spawn(_hostile(Vector3.ZERO))
	var fifth := _field.spawn(_hostile(Vector3.ZERO))

	var ids: Array[int] = [first, second, third, fourth, fifth]
	var seen := {}
	for id: int in ids:
		assert_ne(id, ProjectileField.NO_PROJECTILE, "every spawn fits in a field of 8")
		assert_true(_field.is_alive(id))
		seen[id] = true
	assert_eq(seen.size(), 5, "every id is distinct")
	assert_eq(_field.count(PLAYER), 2)
	assert_eq(_field.count(HOSTILE), 3)
	assert_eq(_field.get_position(first), Vector3(1.0, 2.0, 3.0), "the field kept a copy, not the request")
	assert_eq(_field.get_position(second), Vector3(4.0, 5.0, 6.0))
	assert_eq(_field.get_refused_count(), 0)
	assert_eq(_field.get_capacity(), 8)


func test_projectile_moves_by_velocity_times_delta() -> void:
	var id := _field.spawn(ProjectileSpawn.new(Vector3(1.0, 2.0, 3.0), Vector3(4.0, -2.0, 6.0), HOSTILE, 10.0))
	_field.tick(0.5)
	assert_true(_vec_almost_eq(_field.get_position(id), Vector3(3.0, 1.0, 6.0)), "moved by velocity × 0.5 s")
	_field.tick(0.25)
	assert_true(_vec_almost_eq(_field.get_position(id), Vector3(4.0, 0.5, 7.5)), "then by velocity × 0.25 s")


func test_movement_is_independent_of_the_tick_rate() -> void:
	# ENGINEERING_BRIEF 4.D: frame-rate variation must not change where a bullet is.
	var start := Vector3(-3.0, 1.0, 2.0)
	var velocity := Vector3(7.0, -4.0, 11.0)
	var fine := ProjectileField.new()
	fine.setup(1, WIDE_BOUNDS, Callable())
	var coarse := ProjectileField.new()
	coarse.setup(1, WIDE_BOUNDS, Callable())
	var fine_id := fine.spawn(ProjectileSpawn.new(start, velocity, HOSTILE, 10.0))
	var coarse_id := coarse.spawn(ProjectileSpawn.new(start, velocity, HOSTILE, 10.0))

	for _tick: int in 120:
		fine.tick(1.0 / 120.0)
	for _tick: int in 60:
		coarse.tick(1.0 / 60.0)

	var expected := start + velocity
	assert_true(_vec_almost_eq(fine.get_position(fine_id), expected, 0.001), "120 ticks of 1/120 s travel one second")
	assert_true(_vec_almost_eq(coarse.get_position(coarse_id), expected, 0.001), "60 ticks of 1/60 s travel one second")
	assert_true(_vec_almost_eq(fine.get_position(fine_id), coarse.get_position(coarse_id), 0.001), "both end at the same point")


func test_projectile_is_removed_when_its_lifetime_ends() -> void:
	var id := _field.spawn(ProjectileSpawn.new(Vector3.ZERO, Vector3(0.0, 0.0, 4.0), HOSTILE, 1.0))
	for _tick: int in 3:
		_field.tick(0.25)
	assert_true(_field.is_alive(id), "0.25 s of its 1 s lifetime is left")
	assert_true(_vec_almost_eq(_field.get_position(id), Vector3(0.0, 0.0, 3.0)))

	_field.tick(0.25)
	assert_false(_field.is_alive(id), "the lifetime reached 0")
	assert_eq(_field.count(HOSTILE), 0)
	assert_eq(_field.get_position(id), Vector3.ZERO, "a dead id reads as the origin")


func test_projectile_leaving_the_bounds_is_removed() -> void:
	_field.set_bounds(AABB(Vector3(-10.0, -10.0, -10.0), Vector3(20.0, 20.0, 20.0)))
	var leaving := _field.spawn(ProjectileSpawn.new(Vector3(0.0, 0.0, 9.0), Vector3(0.0, 0.0, 2.0), HOSTILE, 10.0))
	var staying := _field.spawn(ProjectileSpawn.new(Vector3.ZERO, Vector3.ZERO, PLAYER, 10.0))
	# A request outside the Flight Volume is accepted and culled on its first tick.
	var outside := _field.spawn(ProjectileSpawn.new(Vector3(30.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), HOSTILE, 10.0))
	assert_ne(outside, ProjectileField.NO_PROJECTILE, "a spawn outside the bounds is accepted")

	_field.tick(0.25)
	assert_true(_field.is_alive(leaving), "z 9.5 is still inside")
	assert_false(_field.is_alive(outside), "culled on its first tick")
	_field.tick(0.5)
	assert_false(_field.is_alive(leaving), "z 10.5 is outside")
	assert_true(_field.is_alive(staying))
	assert_eq(_field.count(HOSTILE), 0)

	# New bounds apply from the next tick.
	_field.set_bounds(AABB(Vector3(5.0, 5.0, 5.0), Vector3(1.0, 1.0, 1.0)))
	assert_true(_field.is_alive(staying), "set_bounds culls nothing by itself")
	_field.tick(0.25)
	assert_false(_field.is_alive(staying), "the origin is outside the new bounds")


func test_projectile_meeting_an_obstacle_is_removed_before_it_passes() -> void:
	# ADR-0004: a Projectile that meets scenery or a closed Gate is removed on contact.
	# The fake wall is the plane z = 5; a fast Projectile jumps from z 0 to z 50 in one
	# tick, so only a query over the whole tick segment can stop it.
	_field.setup(8, WIDE_BOUNDS, _wall_at_z(5.0))
	var fast := _field.spawn(ProjectileSpawn.new(Vector3.ZERO, Vector3(0.0, 0.0, 200.0), HOSTILE, 10.0))
	var slow := _field.spawn(ProjectileSpawn.new(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 10.0), PLAYER, 10.0))
	var parallel := _field.spawn(ProjectileSpawn.new(Vector3(2.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0), HOSTILE, 10.0))

	_field.tick(0.25)
	assert_false(_field.is_alive(fast), "the wall stops a Projectile that would tunnel through it")
	assert_true(_field.is_alive(slow), "z 2.5 has not reached the wall")
	_field.tick(0.25)
	assert_false(_field.is_alive(slow), "the segment from z 2.5 to z 5 meets the wall")
	assert_true(_field.is_alive(parallel), "a Projectile flying along the wall never meets it")
	assert_eq(_field.count(PLAYER), 0)
	assert_eq(_field.count(HOSTILE), 1)


func test_obstacle_query_receives_the_tick_segment() -> void:
	var segments: Array[Array] = []
	var recording := func(from: Vector3, to: Vector3) -> bool:
		segments.append([from, to])
		return false
	_field.setup(8, WIDE_BOUNDS, recording)
	_field.spawn(ProjectileSpawn.new(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 8.0), HOSTILE, 10.0))
	_field.spawn(ProjectileSpawn.new(Vector3(2.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0), PLAYER, 10.0))
	# Its lifetime ends on the first tick, so it is removed without moving or asking.
	_field.spawn(ProjectileSpawn.new(Vector3(3.0, 0.0, 0.0), Vector3(1.0, 1.0, 1.0), HOSTILE, 0.1))

	_field.tick(0.5)
	if not assert_eq(segments.size(), 2, "one query per moving Projectile"):
		return
	assert_true(_vec_almost_eq(segments[0][0], Vector3(1.0, 0.0, 0.0)), "from is the position before the tick")
	assert_true(_vec_almost_eq(segments[0][1], Vector3(1.0, 0.0, 4.0)), "to is position + velocity × delta")
	assert_true(_vec_almost_eq(segments[1][0], Vector3(2.0, 0.0, 0.0)), "asked in ascending slot order")
	assert_true(_vec_almost_eq(segments[1][1], Vector3(4.0, 0.0, 0.0)))

	segments.clear()
	_field.tick(0.25)
	if not assert_eq(segments.size(), 2):
		return
	assert_true(_vec_almost_eq(segments[0][0], Vector3(1.0, 0.0, 4.0)), "the next segment starts where the last ended")
	assert_true(_vec_almost_eq(segments[0][1], Vector3(1.0, 0.0, 6.0)))


func test_full_field_refuses_new_spawns_and_counts_them() -> void:
	_field.setup(3, WIDE_BOUNDS, Callable())
	var ids: Array[int] = []
	for i: int in 3:
		ids.append(_field.spawn(_hostile(Vector3(float(i), 0.0, 0.0))))

	assert_eq(_field.spawn(_hostile(Vector3(9.0, 0.0, 0.0))), ProjectileField.NO_PROJECTILE, "a full field refuses the request")
	assert_eq(_field.spawn(ProjectileSpawn.new(Vector3.ZERO, Vector3.ZERO, PLAYER)), ProjectileField.NO_PROJECTILE)
	assert_eq(_field.get_refused_count(), 2, "each refusal is counted")
	assert_eq(_field.count(HOSTILE), 3)
	assert_eq(_field.count(PLAYER), 0)
	for i: int in 3:
		assert_true(_field.is_alive(ids[i]), "no existing Projectile is evicted")
		assert_eq(_field.get_position(ids[i]), Vector3(float(i), 0.0, 0.0))

	_field.despawn(ids[1])
	assert_ne(_field.spawn(_hostile(Vector3.ZERO)), ProjectileField.NO_PROJECTILE, "a freed slot takes the next request")
	assert_eq(_field.get_refused_count(), 2)

	_field.setup(3, WIDE_BOUNDS, Callable())
	assert_eq(_field.get_refused_count(), 0, "setup resets the refusal counter")


func test_ids_are_never_reused_after_a_slot_is_recycled() -> void:
	_field.setup(1, WIDE_BOUNDS, Callable())
	var seen := {}
	var previous := ProjectileField.NO_PROJECTILE
	# One slot, recycled by despawn, by lifetime end and by clear_all in turn.
	for i: int in 30:
		var id := _field.spawn(ProjectileSpawn.new(Vector3.ZERO, Vector3.ZERO, HOSTILE, 0.5))
		assert_false(seen.has(id), "id %d was handed out before" % id)
		seen[id] = true
		if previous != ProjectileField.NO_PROJECTILE:
			assert_false(_field.is_alive(previous), "the old id stays dead in the recycled slot")
			assert_false(_field.despawn(previous), "despawning the old id leaves the new one alone")
			assert_true(_field.is_alive(id))
		match i % 3:
			0:
				_field.despawn(id)
			1:
				_field.tick(0.5)
			_:
				_field.clear_all()
		previous = id

	# A new setup starts an empty field, and an id from before it is still dead.
	_field.setup(4, WIDE_BOUNDS, Callable())
	for _spawn: int in 4:
		var id := _field.spawn(_hostile(Vector3.ZERO))
		assert_false(seen.has(id), "an id from before setup() is not handed out again")
		seen[id] = true
	assert_false(_field.is_alive(previous))


func test_despawn_returns_false_for_a_dead_id() -> void:
	var id := _field.spawn(_hostile(Vector3.ZERO))
	var other := _field.spawn(_hostile(Vector3.ONE))
	assert_true(_field.despawn(id), "despawning a live Projectile removes it")
	assert_false(_field.is_alive(id))
	assert_eq(_field.count(HOSTILE), 1)

	assert_false(_field.despawn(id), "already dead")
	assert_false(_field.despawn(ProjectileField.NO_PROJECTILE), "the refusal id")
	assert_false(_field.despawn(987654321), "never handed out")
	var expired := _field.spawn(ProjectileSpawn.new(Vector3.ZERO, Vector3.ZERO, HOSTILE, 0.25))
	_field.tick(0.25)
	assert_false(_field.despawn(expired), "removed by its lifetime")
	assert_true(_field.is_alive(other), "the failed despawns changed nothing")
	assert_eq(_field.count(HOSTILE), 1)


func test_clear_all_empties_the_field_and_old_ids_stay_dead() -> void:
	# ENGINEERING_BRIEF 4.D: Projectiles are cleaned up when encounters end.
	var old: Array[int] = []
	for i: int in 3:
		old.append(_field.spawn(_hostile(Vector3(float(i), 0.0, 0.0))))
		old.append(_field.spawn(ProjectileSpawn.new(Vector3(float(i), 1.0, 0.0), Vector3.ZERO, PLAYER)))

	_field.clear_all()
	assert_eq(_field.count(PLAYER), 0)
	assert_eq(_field.count(HOSTILE), 0)
	assert_eq(_field.get_positions(HOSTILE).size(), 0, "nothing left to draw")
	assert_eq(_field.get_positions(PLAYER).size(), 0)
	for id: int in old:
		assert_false(_field.is_alive(id))

	var fresh: Array[int] = []
	for _spawn: int in 8:
		fresh.append(_field.spawn(_hostile(Vector3.ZERO)))
	assert_eq(_field.count(HOSTILE), 8, "the whole capacity is free again")
	for id: int in fresh:
		assert_false(old.has(id), "clear_all keeps the id counter")
	for id: int in old:
		assert_false(_field.is_alive(id), "an old id stays dead after its slot is reused")
		assert_false(_field.despawn(id))
	assert_eq(_field.count(HOSTILE), 8)


func test_render_read_out_lists_alive_projectiles_of_one_faction() -> void:
	var a := _field.spawn(ProjectileSpawn.new(Vector3(1.0, 0.0, 0.0), Vector3.ZERO, PLAYER, 1.0, 0.5))
	_field.spawn(ProjectileSpawn.new(Vector3(2.0, 0.0, 0.0), Vector3.ZERO, HOSTILE, 1.0, 0.1))
	_field.spawn(ProjectileSpawn.new(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, PLAYER, 1.0, 0.6))
	_field.spawn(ProjectileSpawn.new(Vector3(4.0, 0.0, 0.0), Vector3.ZERO, HOSTILE, 1.0, 0.2))
	_field.spawn(ProjectileSpawn.new(Vector3(5.0, 0.0, 0.0), Vector3.ZERO, PLAYER, 1.0, 0.7))
	# Freeing the lowest slot and spawning again puts the new Projectile first.
	_field.despawn(a)
	_field.spawn(ProjectileSpawn.new(Vector3(6.0, 0.0, 0.0), Vector3.ZERO, PLAYER, 1.0, 0.8))

	assert_eq(_field.get_positions(PLAYER), PackedVector3Array([Vector3(6.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0)]),
			"alive PLAYER Projectiles in ascending slot order")
	_assert_floats_almost_eq(_field.get_radii(PLAYER), [0.8, 0.6, 0.7], "radii parallel to the positions")
	assert_eq(_field.get_positions(HOSTILE), PackedVector3Array([Vector3(2.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0)]))
	_assert_floats_almost_eq(_field.get_radii(HOSTILE), [0.1, 0.2])


## A HOSTILE request at rest at [param position], with the default lifetime.
func _hostile(position: Vector3) -> ProjectileSpawn:
	return ProjectileSpawn.new(position, Vector3.ZERO, HOSTILE)


## A fake obstacle query: the plane z = [param z] blocks every segment that reaches it
## from either side.
func _wall_at_z(z: float) -> Callable:
	return func(from: Vector3, to: Vector3) -> bool:
		return (from.z < z and to.z >= z) or (from.z > z and to.z <= z)


func _vec_almost_eq(actual: Vector3, expected: Vector3, eps: float = EPS) -> bool:
	return (absf(actual.x - expected.x) <= eps and absf(actual.y - expected.y) <= eps
			and absf(actual.z - expected.z) <= eps)


func _assert_floats_almost_eq(actual: PackedFloat32Array, expected: Array[float], message: String = "") -> void:
	if not assert_eq(actual.size(), expected.size(), message):
		return
	for i: int in expected.size():
		assert_almost_eq(actual[i], expected[i], EPS, message)
