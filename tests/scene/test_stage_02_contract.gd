extends TestCase
## Static layout checks; runtime progression is tested by its future adapters.

func test_stage_02_spatial_contract() -> void:
	var packed: PackedScene = load("res://scenes/stages/stage_02.tscn") as PackedScene
	if not assert_not_null(packed, "Stage 2 loads"):
		return
	var stage: Node3D = packed.instantiate() as Node3D
	var encounters: Node = stage.get_node("Encounters")
	assert_eq(encounters.get_child_count(), 7, "Seven encounters")
	var counts: Array[int] = [2, 6, 6, 1, 6, 0, 1]
	for i: int in range(1, 8):
		var encounter: Node = encounters.get_node("S2-0" + str(i))
		assert_true(encounter.has_node("EntryVolume/Collision"), "Entry shape")
		assert_true(encounter.has_node("ExitVolume/Collision"), "Exit shape")
		assert_eq(encounter.get_node("Spawns").get_child_count(), counts[i - 1], "Spawn count")
		for child: Node in encounter.get_node("Spawns").get_children():
			var spawn: Marker3D = child as Marker3D
			assert_true(absf(spawn.position.x) < 53.0 and spawn.position.y < 158.0, "Spawn inside walls")
			assert_true(spawn.position.y > _floor_at(spawn.position.z) + 3.0, "Spawn above terrain")
	assert_eq(stage.get_node("Gates").get_child_count(), 5, "Five progression gates")
	for gate: Node in stage.get_node("Gates").get_children():
		var barrier: StaticBody3D = gate.get_node("BarrierBody") as StaticBody3D
		var shape: BoxShape3D = barrier.get_node("Collision").shape as BoxShape3D
		assert_eq(shape.size, Vector3(110, 160, 1), "Barrier covers whole flight cross-section")
		assert_eq(barrier.position.y, 80.0, "Barrier reaches floor and ceiling")
		assert_eq(barrier.collision_layer, 1, "Scenery layer")
	var checkpoints: Node = stage.get_node("Checkpoints")
	assert_eq(checkpoints.get_child_count(), 2, "Two checkpoints")
	for pair: Array in [["CP2-A", "S2-04"], ["CP2-B", "S2-07"]]:
		var checkpoint: Area3D = checkpoints.get_node(pair[0]) as Area3D
		var entry: Area3D = encounters.get_node(pair[1] + "/EntryVolume") as Area3D
		var respawn: Marker3D = checkpoint.get_node("Respawn") as Marker3D
		var position: Vector3 = checkpoint.position + respawn.position
		assert_eq(checkpoint.get_meta("resume_encounter_id"), pair[1], "Retry encounter")
		assert_true(position.z - entry.position.z > 10, "Retry safely before combat trigger")
		assert_true(position.y > _floor_at(position.z) + 3, "Retry above terrain")
	var basin: Node = encounters.get_node("S2-03")
	assert_eq(basin.get_node("Seals").get_child_count(), 3, "Three seals")
	for i: int in range(1, 4):
		var seal: Node = basin.get_node("Seals/Seal" + str(i))
		for path: String in ["Core", "ShieldVisual", "HitVolume/Collision", "ApproachVolume/Collision", "RewardOrigin"]:
			assert_true(seal.has_node(path), "Seal contract: " + path)
		assert_eq(seal.get_node("GuardLinks").get_child_count(), 2, "Two linked guards")
		for link: Node in seal.get_node("GuardLinks").get_children():
			assert_true(basin.has_node(link.get_meta("guard_spawn")), "Guard reference resolves relative to Encounter")
		assert_true(stage.has_node("Gates/Gate_S2_03/PortalLights/Seal" + str(i)), "One light per seal")
	assert_eq(stage.get_node("RuntimeActors").get_child_count(), 0, "No authored runtime actors")
	assert_true(stage.get_script() == null, "Stage remains static")
	stage.free()

func _floor_at(z: float) -> float:
	if z >= -90:
		return 0
	if z >= -195:
		return 14
	if z >= -345:
		return 25
	if z >= -450:
		return 48
	if z >= -570:
		return 65
	return 83

func test_sculpted_terrain_keeps_spawns_and_checkpoints_clear() -> void:
	var packed: PackedScene = load("res://scenes/stages/stage_02.tscn") as PackedScene
	var stage: Node3D = packed.instantiate() as Node3D
	tree.root.add_child(stage)
	await tree.physics_frame
	await tree.physics_frame
	var positions: Array[Vector3] = []
	for encounter: Node in stage.get_node("Encounters").get_children():
		for spawn: Node3D in encounter.get_node("Spawns").get_children():
			positions.append(spawn.global_position)
	for checkpoint: Node in stage.get_node("Checkpoints").get_children():
		var respawn: Marker3D = checkpoint.get_node("Respawn") as Marker3D
		positions.append(respawn.global_position)
	for position: Vector3 in positions:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(position, position + Vector3.DOWN * 180.0, 1)
		var hit: Dictionary = stage.get_world_3d().direct_space_state.intersect_ray(query)
		if assert_false(hit.is_empty(), "Authored terrain exists under spawn"):
			var ground: Vector3 = hit["position"]
			assert_true(position.y - ground.y > 3.0, "Spawn clears sculpted terrain")
	# The ramp must collide at its visible surface, not the old flat foundation.
	var ramp_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(0, 40, -76), Vector3(0, -10, -76), 1)
	ramp_query.hit_back_faces = false
	var ramp_hit: Dictionary = stage.get_world_3d().direct_space_state.intersect_ray(ramp_query)
	if assert_false(ramp_hit.is_empty(), "Ramp top faces upward"):
		var ramp_position: Vector3 = ramp_hit["position"]
		assert_almost_eq(ramp_position.y, 7.0, 0.1, "Ramp collision matches visible mesh")
	stage.queue_free()
	await tree.process_frame
