extends SceneTree
## Offline visual authoring only. Never rerun over integrated scene edits.

func _initialize() -> void:
	build.call_deferred()

func own_nodes(parent: Node, owner_node: Node) -> void:
	for child: Node in parent.get_children():
		child.owner = owner_node
		own_nodes(child, owner_node)

func build() -> void:
	var variants: Array = [
		["spirit_lume", "Hywirl", Color(0.35,1,0.85), 2.2, 0],
		["spirit_twilight", "Hywirl", Color(0.8,0.55,1), 2.64, 0],
		["sentry_lantern", "Goleling", Color(1,0.68,0.28), 1.6, 1],
		["sentry_seal", "Goleling", Color(0.8,0.4,1), 2.0, 2]
	]
	for variant: Array in variants:
		var visual_root := Node3D.new()
		visual_root.name = "VisualRoot"
		root.add_child(visual_root)
		var model := (load("res://assets/models/enemies/" + variant[1] + ".gltf") as PackedScene).instantiate() as Node3D
		model.name = "Model"
		visual_root.add_child(model)
		var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
		var bounds := AABB()
		var first := true
		for mesh_node: Node in meshes:
			var mesh_instance := mesh_node as MeshInstance3D
			var mesh_bounds: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
			bounds = mesh_bounds if first else bounds.merge(mesh_bounds)
			first = false
			for surface: int in range(mesh_instance.mesh.get_surface_count()):
				var original := mesh_instance.get_active_material(surface) as StandardMaterial3D
				var recolored := original.duplicate() as StandardMaterial3D if original else StandardMaterial3D.new()
				recolored.albedo_color = variant[2]
				mesh_instance.set_surface_override_material(surface, recolored)
		var factor: float = float(variant[3]) / maxf(bounds.size.y, 0.01)
		model.scale = Vector3.ONE * factor
		model.position = -bounds.get_center() * factor
		var magic := StandardMaterial3D.new()
		magic.albedo_color = variant[2]
		magic.emission_enabled = true
		magic.emission = variant[2]
		magic.emission_energy_multiplier = 1.4
		for ring_index: int in range(int(variant[4])):
			var ring := MeshInstance3D.new()
			ring.name = "MagicRing" + str(ring_index + 1)
			var torus := TorusMesh.new()
			torus.inner_radius = float(variant[3]) * 0.56
			torus.outer_radius = torus.inner_radius + 0.065
			torus.rings = 48
			torus.ring_segments = 8
			torus.material = magic
			ring.mesh = torus
			ring.rotation_degrees = Vector3(15 if ring_index == 0 else -35, 0, 0)
			visual_root.add_child(ring)
		var animations: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
		root.remove_child(visual_root)
		for animation_node: Node in animations:
			var player := animation_node as AnimationPlayer
			if player.has_animation("Flying_Idle"):
				player.get_animation("Flying_Idle").loop_mode = Animation.LOOP_LINEAR
				player.autoplay = "Flying_Idle"
			print(variant[0], " animation path=", visual_root.get_path_to(player), " clips=", player.get_animation_list())
		own_nodes(visual_root, visual_root)
		var packed := PackedScene.new()
		if packed.pack(visual_root) != OK or ResourceSaver.save(packed, "res://scenes/enemies/visuals/" + variant[0] + ".tscn") != OK:
			quit(1)
			return
		print("VISUAL_SAVED ", variant[0], " source_height=", bounds.size.y, " visual_height=", variant[3])
		visual_root.free()
	quit(0)
