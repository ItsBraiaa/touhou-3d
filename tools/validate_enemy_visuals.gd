extends SceneTree
## Offline visual scene verification; no combat simulation.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 720)
	var preview := (load("res://scenes/tests/enemy_variants_preview.tscn") as PackedScene).instantiate()
	root.add_child(preview)
	var failures: int = 0
	for name_value: String in ["SpiritLume", "SpiritTwilight", "SentryLantern", "SentrySeal"]:
		var visual: Node = preview.get_node(name_value)
		var player := visual.get_node("Model/AnimationPlayer") as AnimationPlayer
		if not player.has_animation("Flying_Idle") or visual.get_script() != null:
			failures += 1
		if not visual.find_children("*", "CollisionObject3D", true, false).is_empty():
			failures += 1
		player.play("Flying_Idle")
		player.advance(0.5)
		if not player.is_playing():
			failures += 1
		print(name_value, " idle_playing=", player.is_playing(), " animation_length=", player.current_animation_length)
	if DisplayServer.get_name() != "headless":
		for frame: int in range(20):
			await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png("res://docs/validation/enemy-variants.png") != OK:
			failures += 1
	print("ENEMY_VISUAL_QA failures=", failures, " variants=4; no health or collision components")
	quit(1 if failures else 0)
