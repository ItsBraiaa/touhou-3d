extends SceneTree
## Offline scene-contract and gallery check for Astra's combat visuals.

const VISUALS: String = "res://scenes/combat/visuals/"
const PROJECTILES: Array[String] = ["projectile_player_mesh.tres", "projectile_hostile_mesh.tres"]
const SCENES: Array[String] = ["familiar.tscn", "power_pickup_visual.tscn", "shield_pickup_visual.tscn", "bomb_blast_visual.tscn"]

var _failures: PackedStringArray = []
var _lines: PackedStringArray = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	_check_projectiles()
	for scene_name: String in SCENES:
		await _check_scene(scene_name)
	if DisplayServer.get_name() != "headless":
		await _render_gallery()
	_finish()

func _check_projectiles() -> void:
	for index: int in range(PROJECTILES.size()):
		var path: String = VISUALS + PROJECTILES[index]
		var mesh: Mesh = load(path) as Mesh
		if mesh == null or mesh.get_surface_count() != 1:
			_failures.append(path + " must be a one-surface Mesh")
			continue
		var surface: Material = mesh.surface_get_material(0)
		if not surface is StandardMaterial3D:
			_failures.append(path + " has no StandardMaterial3D surface material")
		else:
			var material: StandardMaterial3D = surface as StandardMaterial3D
			if material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED or material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
				_failures.append(path + " must be unshaded and free of alpha blending")
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for vertex: Vector3 in vertices:
			if vertex.length() > 1.001:
				_failures.append(path + " has a vertex outside unit radius")
				break
		var dev_name: String = "projectile_player_mesh.tres" if index == 0 else "projectile_hostile_mesh.tres"
		var dev: Mesh = load("res://scenes/dev/" + dev_name) as Mesh
		var dev_count: int = -1
		if dev != null:
			var dev_vertices: PackedVector3Array = dev.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			dev_count = dev_vertices.size()
			if vertices.size() > dev_vertices.size():
				_failures.append(path + " exceeds dev mesh vertex count")
		_lines.append(PROJECTILES[index] + ": vertices=" + str(vertices.size()) + ", dev_vertices=" + str(dev_count))
	var player_mesh: Mesh = load(VISUALS + PROJECTILES[0]) as Mesh
	var hostile_mesh: Mesh = load(VISUALS + PROJECTILES[1]) as Mesh
	if player_mesh != null and hostile_mesh != null and player_mesh.get_class() == hostile_mesh.get_class():
		_failures.append("Player and hostile Projectile mesh shapes must differ")

func _check_scene(scene_name: String) -> void:
	var path: String = VISUALS + scene_name
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_failures.append("Scene did not load: " + path)
		return
	var visual: Node3D = packed.instantiate() as Node3D
	if visual == null:
		_failures.append("Scene root is not Node3D: " + path)
		return
	root.add_child(visual)
	var expected_name: StringName = &"Visual" if scene_name.contains("pickup") else (&"Familiar" if scene_name == "familiar.tscn" else &"BombBlastVisual")
	if visual.name != expected_name or visual.transform != Transform3D.IDENTITY:
		_failures.append(path + " root name or transform is wrong")
	for child: Node in _all_nodes(visual):
		if child.get_script() != null or child is CollisionObject3D or child is CollisionShape3D:
			_failures.append(path + " has a script or collision object")
	var radius: float = _vertex_radius(visual)
	var limit: float = 0.75 if scene_name == "familiar.tscn" else (0.9 if scene_name.contains("pickup") else 1.0)
	if radius > limit + 0.002:
		_failures.append(path + " exceeds its visual radius " + str(limit) + ": " + str(radius))
	if scene_name == "bomb_blast_visual.tscn" and absf(radius - 1.0) > 0.02:
		_failures.append(path + " visible edge must be at unit radius")
	var player: AnimationPlayer = visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var clip_name: StringName = &"blast" if scene_name == "bomb_blast_visual.tscn" else (&"hover" if scene_name == "familiar.tscn" else &"float")
	if player == null or not player.has_animation(clip_name) or player.autoplay != clip_name:
		_failures.append(path + " animation clip or autoplay missing")
	else:
		var clip: Animation = player.get_animation(clip_name)
		var expected_loop: int = Animation.LOOP_NONE if clip_name == &"blast" else Animation.LOOP_LINEAR
		if clip.loop_mode != expected_loop:
			_failures.append(path + " animation loop setting is wrong")
		for track: int in range(clip.get_track_count()):
			var track_path: String = str(clip.track_get_path(track))
			if track_path.begins_with("..") or track_path.begins_with(".:" ) or track_path == ".":
				_failures.append(path + " animation moves its root")
		if clip_name == &"blast":
			if not is_equal_approx(clip.length, 0.4):
				_failures.append(path + " blast lifetime changed")
			var hidden_at_end: bool = false
			for track: int in range(clip.get_track_count()):
				if str(clip.track_get_path(track)).ends_with(":visible") and clip.track_get_key_value(track, clip.track_get_key_count(track) - 1) == false:
					hidden_at_end = true
			if not hidden_at_end:
				_failures.append(path + " does not hide at the end of blast")
			for child: Node in _all_nodes(visual):
				if child is MeshInstance3D:
					var mesh_node: MeshInstance3D = child as MeshInstance3D
					if mesh_node.mesh != null and mesh_node.mesh.surface_get_material(0) != null and not mesh_node.mesh.surface_get_material(0).resource_local_to_scene:
						_failures.append(path + " animated material is not local to scene")
	_lines.append(scene_name + ": radius=" + str(snappedf(radius, 0.001)) + ", clip=" + String(clip_name))
	visual.queue_free()
	await process_frame

func _all_nodes(parent: Node) -> Array[Node]:
	var nodes: Array[Node] = [parent]
	for child: Node in parent.get_children():
		nodes.append_array(_all_nodes(child))
	return nodes

func _vertex_radius(parent: Node3D) -> float:
	var result: float = 0.0
	for child: Node in _all_nodes(parent):
		if not child is MeshInstance3D:
			continue
		var mesh_node: MeshInstance3D = child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var relative: Transform3D = parent.global_transform.affine_inverse() * mesh_node.global_transform
		for surface: int in range(mesh_node.mesh.get_surface_count()):
			var vertices: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for vertex: Vector3 in vertices:
				result = maxf(result, (relative * vertex).length())
	return result

func _render_gallery() -> void:
	var gallery: Node3D = Node3D.new()
	root.add_child(gallery)
	var environment: WorldEnvironment = WorldEnvironment.new()
	var resource: Environment = Environment.new()
	resource.background_mode = Environment.BG_COLOR
	resource.background_color = Color(0.035, 0.065, 0.10)
	resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	resource.ambient_light_color = Color(0.7, 0.8, 1.0)
	environment.environment = resource
	gallery.add_child(environment)
	var sunlight: DirectionalLight3D = DirectionalLight3D.new()
	sunlight.rotation = Vector3(-0.5, -0.4, -0.25)
	sunlight.light_energy = 2.5
	gallery.add_child(sunlight)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.0
	camera.position = Vector3(0.0, 0.0, 18.0)
	camera.current = true
	gallery.add_child(camera)
	for index: int in range(2):
		var mesh: Mesh = load(VISUALS + PROJECTILES[index]) as Mesh
		for size: float in [0.15, 1.0]:
			var bullet: MeshInstance3D = MeshInstance3D.new()
			bullet.mesh = mesh
			bullet.scale = Vector3.ONE * size
			bullet.position = Vector3(-4.5 + float(index) * 3.0 + size, 2.1, 0.0)
			gallery.add_child(bullet)
	var ship_scene: PackedScene = load("res://assets/models/player/craft_speederA.glb") as PackedScene
	if ship_scene != null:
		var ship: Node3D = ship_scene.instantiate() as Node3D
		ship.position = Vector3(-2.2, -1.0, 0.0)
		ship.scale = Vector3.ONE * 0.9
		gallery.add_child(ship)
	for index: int in range(3):
		var scene: PackedScene = load(VISUALS + SCENES[index]) as PackedScene
		var visual: Node3D = scene.instantiate() as Node3D
		visual.position = Vector3(-0.8 + float(index) * 2.3, -1.2, 0.0)
		gallery.add_child(visual)
	var bomb_scene: PackedScene = load(VISUALS + "bomb_blast_visual.tscn") as PackedScene
	var bomb: Node3D = bomb_scene.instantiate() as Node3D
	bomb.position = Vector3(3.5, 1.0, 0.0)
	gallery.add_child(bomb)
	var bomb_player: AnimationPlayer = bomb.get_node("AnimationPlayer") as AnimationPlayer
	bomb_player.play(&"blast")
	bomb_player.advance(0.2)
	bomb_player.pause()
	for index: int in range(7):
		var ring_bullet: MeshInstance3D = MeshInstance3D.new()
		ring_bullet.mesh = load(VISUALS + "projectile_hostile_mesh.tres") as Mesh
		ring_bullet.scale = Vector3.ONE * 0.15
		var angle: float = TAU * float(index) / 7.0
		ring_bullet.position = Vector3(3.5 + cos(angle) * 1.3, 1.0 + sin(angle) * 1.3, -0.3)
		gallery.add_child(ring_bullet)
	for frame: int in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://docs/validation/combat-visuals.png") != OK:
		_failures.append("Gallery screenshot could not be saved")
	gallery.queue_free()
	await process_frame

func _finish() -> void:
	var report: FileAccess = FileAccess.open("res://docs/validation/combat-visuals.log", FileAccess.WRITE)
	if report != null:
		for line: String in _lines:
			report.store_line(line)
		for failure: String in _failures:
			report.store_line("FAIL " + failure)
		report.store_line("COMBAT_VISUALS_QA failures=" + str(_failures.size()))
		report.close()
	for failure: String in _failures:
		printerr("COMBAT_VISUALS_FAIL ", failure)
	print("COMBAT_VISUALS_QA failures=", _failures.size())
	quit(0 if _failures.is_empty() else 1)
