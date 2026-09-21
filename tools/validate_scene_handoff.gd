extends SceneTree
## Offline scene QA utility, not a gameplay script or Claude implementation.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var packed := load("res://scenes/tests/combat_arena.tscn") as PackedScene
	if packed == null:
		push_error("Arena could not be loaded")
		quit(1)
		return
	var arena := packed.instantiate()
	root.add_child(arena)
	current_scene = arena
	var required := ["PlayerShip/BodyCollision", "PlayerShip/DamageCore/CollisionShape3D", "PlayerShip/GrazeVolume/CollisionShape3D", "PlayerShip/Muzzle", "PlayerShip/FamiliarAnchors/Left", "PlayerShip/CameraRig/Camera3D", "Targets/Low", "Targets/Middle", "Targets/High", "Environment/WorldEnvironment"]
	for path in required:
		if not arena.has_node(path):
			push_error("Missing scene contract: " + path)
			quit(1)
			return
	var meshes := arena.get_node("PlayerShip/VisualRoot/Model").find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		push_error("Imported ship has no meshes")
		quit(1)
		return
	for mesh_instance in meshes:
		print("SHIP_MESH ", mesh_instance.get_path(), " AABB=", mesh_instance.get_aabb(), " WORLD=", mesh_instance.global_position)
	print("SCENE_CONTRACT_OK: ", required.size(), " required nodes; targets=", get_nodes_in_group("targetable").size())
	if DisplayServer.get_name() != "headless":
		for frame in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png("res://docs/validation/arena-preview.png")
		if result != OK:
			push_error("Preview write failed: " + str(result))
			quit(1)
			return
		print("PREVIEW_SAVED")
	quit(0)
