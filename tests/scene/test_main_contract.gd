extends TestCase
## Smoke test of `scenes/main.tscn`, the composition root from ADR-0002: the five
## nodes and their types, which roots keep processing while the tree is paused and
## which stop, and the main menu appearing under `Interface` after one frame. No
## gameplay is checked here.


## Counts the engine callbacks it receives, so a test can observe whether the
## branch it was added to processes while the tree is paused.
class ProcessProbe:
	extends Node

	var process_calls: int = 0
	var physics_calls: int = 0

	func _process(_delta: float) -> void:
		process_calls += 1

	func _physics_process(_delta: float) -> void:
		physics_calls += 1


const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CHILD_TYPES: Dictionary = {
	"WorldRoot": "Node3D",
	"ProjectileRoot": "Node3D",
	"Interface": "CanvasLayer",
	"Audio": "Node",
}
## Roots that must keep processing while the tree is paused: menus and audio.
const ALWAYS_ROOTS: Array[String] = ["Interface", "Audio"]
## Roots holding gameplay; they must stop with the tree.
const PAUSABLE_ROOTS: Array[String] = ["WorldRoot", "ProjectileRoot"]
## Frames observed in each pause state. More than one, so a probe added in the
## middle of a frame is seen by at least one full frame.
const OBSERVED_FRAMES := 3

var _main: Node


func before_each() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return
	_main = packed.instantiate()
	IsolatedSettings.isolate(_main)
	tree.root.add_child(_main)
	await tree.process_frame


func after_each() -> void:
	tree.paused = false
	if _main == null:
		return
	tree.root.remove_child(_main)
	_main.free()
	_main = null
	IsolatedSettings.clean()


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
	for root_name: String in ALWAYS_ROOTS:
		assert_eq(_main.get_node(root_name).process_mode, Node.PROCESS_MODE_ALWAYS, root_name)


## `Main` is ALWAYS, so a gameplay root left at INHERIT would also run while paused.
func test_world_and_projectile_roots_are_pausable() -> void:
	if not assert_not_null(_main, "%s loads" % MAIN_SCENE_PATH):
		return
	for root_name: String in PAUSABLE_ROOTS:
		assert_eq(_main.get_node(root_name).process_mode, Node.PROCESS_MODE_PAUSABLE, root_name)


## Behavioural check of the same contract: with the tree paused, nodes under the
## gameplay roots receive no `_process` or `_physics_process`, nodes under
## `Interface` and `Audio` keep receiving them, and the gameplay roots resume once
## the tree is unpaused.
func test_only_interface_and_audio_keep_processing_while_paused() -> void:
	if not assert_not_null(_main, "%s loads" % MAIN_SCENE_PATH):
		return
	var probes: Dictionary = {}
	for root_name: String in CHILD_TYPES:
		var probe := ProcessProbe.new()
		probes[root_name] = probe
		_main.get_node(root_name).add_child(probe)

	tree.paused = true
	for _frame in range(OBSERVED_FRAMES):
		await tree.process_frame
	for root_name: String in PAUSABLE_ROOTS:
		var root: Node = _main.get_node(root_name)
		var probe: ProcessProbe = probes[root_name]
		assert_false(root.can_process(), "%s can_process() while paused" % root_name)
		assert_eq(probe.process_calls, 0, "%s _process calls while paused" % root_name)
		assert_eq(probe.physics_calls, 0, "%s _physics_process calls while paused" % root_name)
	for root_name: String in ALWAYS_ROOTS:
		var root: Node = _main.get_node(root_name)
		var probe: ProcessProbe = probes[root_name]
		assert_true(root.can_process(), "%s can_process() while paused" % root_name)
		assert_true(probe.process_calls > 0, "%s _process calls while paused" % root_name)

	tree.paused = false
	for _frame in range(OBSERVED_FRAMES):
		await tree.process_frame
	for root_name: String in PAUSABLE_ROOTS:
		var probe: ProcessProbe = probes[root_name]
		assert_true(probe.process_calls > 0, "%s _process calls after unpause" % root_name)


func test_main_menu_is_instanced_under_interface() -> void:
	if not assert_not_null(_main, "%s loads" % MAIN_SCENE_PATH):
		return
	var menu := _main.get_node_or_null("Interface/MainMenu")
	if not assert_not_null(menu, "Interface/MainMenu after one frame"):
		return
	assert_true(menu is Control)
	assert_eq(menu.scene_file_path, "res://scenes/ui/main_menu.tscn")
