extends SceneTree
## Offline static-scene QA. Does not implement stage progression or player movement.
var failures := 0
## The only script a Stage root may carry: the StageDirector (F10-01 on Stage 1, F12-05 on Stage 2).
const DIRECTOR_SCRIPT_PATH := "res://scripts/progression/stage_director.gd"

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/tests/stage_01_preview.tscn") as PackedScene
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var stage: Node3D = scene.get_node("Stage")
	check(stage.get_node("Encounters").get_child_count() == 7, "Expected seven encounters")
	var expected_spawns := [0, 6, 2, 3, 6, 0, 1]
	for i in range(1, 8):
		var encounter := stage.get_node("Encounters/S1-0" + str(i))
		check(encounter.has_node("EntryVolume/Collision") and encounter.has_node("ExitVolume/Collision"), "Missing entry/exit volume")
		check(encounter.get_node("Spawns").get_child_count() == expected_spawns[i-1], "Incorrect enemy marker count")
		for spawn in encounter.get_node("Spawns").get_children():
			check(absf(spawn.position.x) < 44 and spawn.position.y < 75, "Spawn outside flight bounds")
	check(stage.get_node("Checkpoints").get_child_count() == 2, "Expected two checkpoints")
	for pair: Array in [["CP1-A", "S1-05"], ["CP1-B", "S1-07"]]:
		var checkpoint: Area3D = stage.get_node("Checkpoints/" + pair[0])
		var entry: Area3D = stage.get_node("Encounters/" + pair[1] + "/EntryVolume")
		check(checkpoint.global_position.z - entry.global_position.z > 10, "Checkpoint overlaps next encounter")
		check(checkpoint.has_node("Respawn"), "Missing retry marker")
	for gate in stage.get_node("Gates").get_children():
		var shape: BoxShape3D = gate.get_node("BarrierBody/Collision").shape
		check(shape.size.x == 90 and shape.size.y == 75, "Gate does not span allowed flight cross-section")
	var stage_script: Script = stage.get_script() as Script
	check(stage_script == null or stage_script.resource_path == DIRECTOR_SCRIPT_PATH, "Stage root carries a script other than the StageDirector")
	if DisplayServer.get_name() != "headless" and failures == 0:
		var camera: Camera3D = scene.get_node("PreviewCamera")
		var views := [
			["entrance", Vector3(0,12,29), Vector3(0,13,-70)],
			["ascent", Vector3(-12,23,-148), Vector3(5,30,-236)],
			["portal", Vector3(27,42,-247), Vector3(0,33,-317)],
			["arena", Vector3(28,56,-475), Vector3(0,35,-529)],
			["overview", Vector3(210,265,-145), Vector3(0,5,-270)]
		]
		for view: Array in views:
			camera.position = view[1]
			camera.look_at(view[2])
			for frame in range(10):
				await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://docs/validation/stage-01-" + view[0] + ".png") == OK, "Screenshot failed")
	print("STAGE_01_QA_COMPLETE failures=", failures, " encounters=7 spawns=18 checkpoints=2 gates=4")
	quit(1 if failures else 0)
