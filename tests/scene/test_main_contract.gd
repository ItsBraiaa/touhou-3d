extends TestCase
## Smoke test of `scenes/main.tscn`, the composition root from ADR-0002: the five
## nodes and their types, the always-process flags, and the main menu appearing
## under `Interface` after one frame. No gameplay is checked here.


const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CHILD_TYPES: Dictionary = {
	"WorldRoot": "Node3D",
	"ProjectileRoot": "Node3D",
	"Interface": "CanvasLayer",
	"Audio": "Node",
}

var _main: Node


func before_each() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return
	_main = packed.instantiate()
	tree.root.add_child(_main)
	await tree.process_frame


func after_each() -> void:
	if _main == null:
		return
	tree.root.remove_child(_main)
	_main.free()
	_main = null


func test_root_is_main_with_game_session_attached() -> void:
	if not assert_not_null(_main, "%s loads" % MAIN_SCENE_PATH):
		return
	assert_eq(_main.name, "Main")
	assert_eq(_main.get_class(), "Node")
	assert_true(_main is GameSession, "root script is GameSession")


func test_four_children_with_the_documented_types() -> void:
	if not assert_not_null(_main, "%s loads" % MAIN_SCENE_PATH):
		return
	assert_eq(_main.get_child_count(), CHILD_TYPES.size())
	for child_name: String in CHILD_TYPES:
		var child := _main.get_node_or_null(child_name)
		if not assert_not_null(child, "%s is missing" % child_name):
			continue
		assert_eq(child.get_class(), CHILD_TYPES[child_name], "%s type" % child_name)


func test_main_interface_and_audio_process_while_paused() -> void:
	if not assert_not_null(_main, "%s loads" % MAIN_SCENE_PATH):
		return
	assert_eq(_main.process_mode, Node.PROCESS_MODE_ALWAYS, "Main")
	assert_eq(_main.get_node("Interface").process_mode, Node.PROCESS_MODE_ALWAYS, "Interface")
	assert_eq(_main.get_node("Audio").process_mode, Node.PROCESS_MODE_ALWAYS, "Audio")


func test_main_menu_is_instanced_under_interface() -> void:
	if not assert_not_null(_main, "%s loads" % MAIN_SCENE_PATH):
		return
	var menu := _main.get_node_or_null("Interface/MainMenu")
	if not assert_not_null(menu, "Interface/MainMenu after one frame"):
		return
	assert_true(menu is Control)
	assert_eq(menu.scene_file_path, "res://scenes/ui/main_menu.tscn")
