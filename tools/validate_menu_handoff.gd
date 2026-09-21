extends SceneTree
## Offline menu rendering and scene-contract QA, never part of gameplay.

const SCENES := ["main_menu", "stage_select", "options", "controls", "pause_menu", "defeat", "results", "credits"]
var failures: PackedStringArray = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 720)
	for scene_name in SCENES:
		var packed := load("res://scenes/ui/" + scene_name + ".tscn") as PackedScene
		if packed == null:
			failures.append("Failed to load: " + scene_name)
			continue
		var menu := packed.instantiate()
		root.add_child(menu)
		await process_frame
		var controls := menu.find_children("*", "Control", true, false)
		var focus_count := 0
		for control in controls:
			if control.focus_mode == Control.FOCUS_ALL:
				focus_count += 1
				for property in ["focus_next", "focus_previous"]:
					var neighbor: NodePath = control.get(property)
					if not neighbor.is_empty() and not control.has_node(neighbor):
						failures.append(scene_name + ": invalid " + property + " on " + str(control.get_path()))
			if control is Label and control.visible and control.size.x < control.get_minimum_size().x - 1:
				failures.append(scene_name + ": clipped label " + control.name)
		if focus_count == 0:
			failures.append(scene_name + ": no focusable controls")
		print("MENU_LOADED ", scene_name, " controls=", controls.size(), " focusable=", focus_count)
		if DisplayServer.get_name() != "headless":
			for frame in range(5):
				await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var err := image.save_png("res://docs/validation/menu-" + scene_name + ".png")
			if err != OK:
				failures.append("Failed writing screenshot " + scene_name)
		menu.queue_free()
		await process_frame
	for failure in failures:
		push_error(failure)
	print("MENU_QA_COMPLETE failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
