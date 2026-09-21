extends SceneTree
## Offline rendering only. Run tests/run_tests.gd for the static scene contract.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://scenes/tests/stage_02_preview.tscn") as PackedScene
	if packed == null:
		quit(1)
		return
	var scene: Node3D = packed.instantiate() as Node3D
	root.add_child(scene)
	if not scene.has_node("Stage/Encounters") or not scene.has_node("PreviewCamera"):
		push_error("Incomplete Stage 2 preview")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		print("STAGE_02_PREVIEW_LOAD_OK (no rendered evidence in headless mode)")
		quit(0)
		return
	var camera: Camera3D = scene.get_node("PreviewCamera") as Camera3D
	var views: Array = [
		["entrance", Vector3(0, 17, 34), Vector3(0, 27, -92)],
		["seals", Vector3(0, 61, -208), Vector3(0, 63, -281)],
		["duel", Vector3(30, 88, -373), Vector3(0, 66, -411)],
		["summit", Vector3(35, 129, -637), Vector3(0, 105, -700)],
		["overview", Vector3(360, 380, -80), Vector3(0, 45, -360)]
	]
	var failures: int = 0
	for view: Array in views:
		camera.position = view[1]
		camera.look_at(view[2])
		for frame: int in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		var result: Error = root.get_texture().get_image().save_png("res://docs/validation/stage-02-" + view[0] + ".png")
		if result != OK:
			failures += 1
	print("STAGE_02_RENDER_COMPLETE failures=", failures)
	quit(1 if failures else 0)
