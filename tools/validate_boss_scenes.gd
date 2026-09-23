extends SceneTree
## Offline scene-contract and presentation check for Astra's boss prefabs.

const LANTERN_SCENE: String = "res://scenes/enemies/lantern_guardian.tscn"
const LANTERN_CLIPS: Array[StringName] = [&"Flying_Idle", &"Punch", &"Yes", &"Death"]

var _failures: PackedStringArray = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load(LANTERN_SCENE) as PackedScene
	if packed == null:
		_failures.append("Lantern Guardian scene did not load")
		_finish()
		return
	var enemy: Node3D = packed.instantiate() as Node3D
	if enemy == null:
		_failures.append("Lantern Guardian root is not Node3D")
		_finish()
		return
	_check_lantern(enemy)
	if DisplayServer.get_name() != "headless":
		await _render_lantern(enemy)
	else:
		enemy.free()
	_finish()

func _check_lantern(enemy: Node3D) -> void:
	if enemy.name != &"Enemy" or enemy.transform != Transform3D.IDENTITY or enemy.get_script() != null:
		_failures.append("Lantern root name, identity or script is wrong")
	var visual: Node3D = enemy.get_node_or_null("VisualRoot") as Node3D
	var model: Node3D = enemy.get_node_or_null("VisualRoot/Model") as Node3D
	var volume: Area3D = enemy.get_node_or_null("HitVolume") as Area3D
	var emitter: Marker3D = enemy.get_node_or_null("Emitters/Main") as Marker3D
	var player: AnimationPlayer = enemy.get_node_or_null("VisualRoot/Model/AnimationPlayer") as AnimationPlayer
	var ornament_player: AnimationPlayer = enemy.get_node_or_null("VisualRoot/LanternMotion") as AnimationPlayer
	if visual == null or model == null or volume == null or emitter == null or player == null or ornament_player == null:
		_failures.append("Lantern required tree path or type is missing")
		return
	if not visual.find_children("*", "CollisionObject3D", true, false).is_empty():
		_failures.append("Collision object under Lantern VisualRoot")
	if volume.collision_layer != 16 or volume.collision_mask != 0 or volume.monitoring or volume.monitorable:
		_failures.append("Lantern HitVolume collision flags are wrong")
	var collision: CollisionShape3D = volume.get_node_or_null("Collision") as CollisionShape3D
	if collision == null or not collision.shape is SphereShape3D:
		_failures.append("Lantern HitVolume needs a SphereShape3D")
	elif not is_equal_approx((collision.shape as SphereShape3D).radius, 3.0):
		_failures.append("Lantern gameplay hit radius changed from 3.0")
	if not volume.position.is_equal_approx(Vector3(0.0, 4.3, 0.0)):
		_failures.append("Lantern hit center is not on the model body")
	if not model.scale.is_equal_approx(Vector3(2.6, 2.6, 2.6)):
		_failures.append("Lantern model scale changed")
	for index: int in range(8):
		var lantern: MeshInstance3D = enemy.get_node_or_null("VisualRoot/Lanterns/Lantern%d" % (index + 1)) as MeshInstance3D
		if lantern == null or lantern.mesh == null:
			_failures.append("Lantern%d mesh missing" % (index + 1))
	for clip: StringName in LANTERN_CLIPS:
		if not player.has_animation(clip):
			_failures.append("Lantern model clip missing: " + String(clip))
			continue
		player.play(clip)
		player.advance(0.2)
		if not player.is_playing():
			_failures.append("Lantern model clip failed to advance: " + String(clip))
	if player.has_animation(&"Flying_Idle") and player.get_animation(&"Flying_Idle").loop_mode != Animation.LOOP_LINEAR:
		_failures.append("Lantern idle must loop")
	if player.autoplay != &"Flying_Idle":
		_failures.append("Lantern idle must autoplay")
	if player.has_animation(&"Death") and player.get_animation(&"Death").loop_mode != Animation.LOOP_NONE:
		_failures.append("Lantern defeat clip must not loop")
	if not ornament_player.has_animation(&"orbit") or ornament_player.autoplay != &"orbit":
		_failures.append("Lantern ornament orbit is missing or does not autoplay")
	elif ornament_player.get_animation(&"orbit").loop_mode != Animation.LOOP_LINEAR:
		_failures.append("Lantern ornament orbit does not loop")
	else:
		var lanterns: Node3D = enemy.get_node("VisualRoot/Lanterns") as Node3D
		ornament_player.play(&"orbit")
		ornament_player.advance(6.0)
		if absf(lanterns.rotation.y) < 2.0:
			_failures.append("Lantern orbit did not rotate the ornaments")
	print("LANTERN clips=", LANTERN_CLIPS, " hit_radius=3.0 hit_center=", volume.position, " model_scale=", model.scale)

func _render_lantern(enemy: Node3D) -> void:
	var stage_scene: PackedScene = load("res://scenes/stages/stage_01.tscn") as PackedScene
	if stage_scene == null:
		_failures.append("Stage 1 dusk preview did not load")
		enemy.free()
		return
	var stage: Node3D = stage_scene.instantiate() as Node3D
	root.add_child(stage)
	stage.get_node("RuntimeActors").add_child(enemy)
	var marker: Marker3D = stage.get_node("Encounters/S1-07/Spawns/Wave1_Boss1") as Marker3D
	enemy.global_position = marker.global_position
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.global_position = marker.global_position + Vector3(0.0, 5.0, 35.0)
	camera.look_at(marker.global_position + Vector3(0.0, 4.0, 0.0))
	camera.fov = 55.0
	camera.current = true
	var player: AnimationPlayer = enemy.get_node("VisualRoot/Model/AnimationPlayer") as AnimationPlayer
	player.play(&"Flying_Idle")
	for frame: int in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://docs/validation/lantern-guardian.png") != OK:
		_failures.append("Lantern screenshot could not be saved")
	stage.queue_free()
	await process_frame

func _finish() -> void:
	var report: FileAccess = FileAccess.open("res://docs/validation/boss-scenes.log", FileAccess.WRITE)
	if report == null:
		_failures.append("Boss scenes log could not be written")
	else:
		report.store_line("D-03 Lantern Guardian: Ghost model, eight amber lanterns, orbit animation, 3.0 hit radius at (0, 4.3, 0), scale 2.6.")
		report.store_line("Imported clips: idle Flying_Idle (loop/autoplay), step Punch, phase Yes, defeat Death (non-looping).")
		report.store_line("Windowed render: S1-07 dusk palette, approach camera 35 units ahead; lantern-guardian.png.")
		for failure: String in _failures:
			report.store_line("FAIL " + failure)
		report.store_line("BOSS_SCENES_QA failures=" + str(_failures.size()))
		report.close()
	for failure: String in _failures:
		printerr("BOSS_SCENES_FAIL ", failure)
	print("BOSS_SCENES_QA failures=", _failures.size())
	quit(1 if not _failures.is_empty() else 0)
