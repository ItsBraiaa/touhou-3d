extends SceneTree
## Offline presentation QA; does not implement runtime HUD binding.

func _initialize() -> void:
	run.call_deferred()

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var err := root.get_texture().get_image().save_png("res://docs/validation/hud-" + name + ".png")
	assert(err == OK, "Screenshot write failed")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/tests/hud_preview.tscn") as PackedScene
	assert(packed != null)
	var scene := packed.instantiate()
	root.add_child(scene)
	var hud: Control = scene.get_node("Interface/HUD")
	for path in ["PlayerStatus/HealthBar", "PlayerStatus/HealthValue", "PlayerStatus/Shield", "PlayerStatus/Bomb1", "PlayerStatus/Bomb2", "PlayerStatus/PowerValue", "PlayerStatus/PowerProgress", "BossStatus/Phase1", "BossStatus/Phase2", "BossStatus/Phase3", "TargetMarker", "ThreatLeft", "ThreatRight"]:
		assert(hud.has_node(path), "Missing HUD node: " + path)
	assert(not hud.get_node("BossStatus").visible)
	for control in hud.find_children("*", "Control", true, false):
		assert(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD intercepts pointer: " + control.name)
	await capture("normal")
	hud.get_node("BossStatus").show()
	hud.get_node("AttackName").show()
	hud.get_node("PlayerStatus/HealthBar").value = 70
	hud.get_node("PlayerStatus/HealthValue").text = "70%"
	hud.get_node("PlayerStatus/Shield").modulate.a = 0.25
	hud.get_node("PlayerStatus/Bomb2").modulate.a = 0.2
	hud.get_node("PlayerStatus/PowerValue").text = "2"
	hud.get_node("PlayerStatus/PowerProgress").value = 3
	hud.get_node("BossStatus/Phase1").value = 40
	await capture("boss-example")
	print("HUD_CONTRACT_OK: 13 node paths, non-interactive overlay, normal and boss examples rendered")
	quit(0)
