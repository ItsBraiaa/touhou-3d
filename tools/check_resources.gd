extends SceneTree
## Sprint gate (docs/engineering/SPRINT.md). Loads every .tres and .tscn under res://content
## and res://scenes, runs validate() on each loaded resource that defines it, and compiles
## every .gd under res://scripts, res://tools and res://tests (a test file that stops
## compiling is otherwise skipped silently by the runner, which still reports 0 failures).
##
## A resource that does not load (a text parse error, a missing dependency) and a script that
## does not compile are always failures: a script no test or scene references is otherwise
## never compiled before the lane that first uses it. validate() problems are failures only
## with --strict-validate, and printed as warnings otherwise. Run by tools/lane.ps1 land;
## exits 1 on any failure.

const RESOURCE_ROOTS: Array[String] = ["res://content", "res://scenes"]
const RESOURCE_EXTENSIONS: Array[String] = ["tres", "tscn"]
const SCRIPT_ROOTS: Array[String] = ["res://scripts", "res://tools", "res://tests"]
const SCRIPT_EXTENSIONS: Array[String] = ["gd"]


func _initialize() -> void:
	var strict := OS.get_cmdline_user_args().has("--strict-validate")
	var failures := 0
	var invalid := 0

	var scripts: Array[String] = []
	for root: String in SCRIPT_ROOTS:
		_collect(root, SCRIPT_EXTENSIONS, scripts)
	for path: String in scripts:
		var script := ResourceLoader.load(path) as Script
		if script == null:
			print("SCRIPT_LOAD_FAILED %s" % path)
			failures += 1
		elif not script.can_instantiate():
			print("SCRIPT_COMPILE_FAILED %s" % path)
			failures += 1

	var resources: Array[String] = []
	for root: String in RESOURCE_ROOTS:
		_collect(root, RESOURCE_EXTENSIONS, resources)
	for path: String in resources:
		var resource := ResourceLoader.load(path)
		if resource == null:
			print("RESOURCE_LOAD_FAILED %s" % path)
			failures += 1
			continue
		if resource.has_method(&"validate"):
			var problems: PackedStringArray = resource.call(&"validate")
			for problem: String in problems:
				print("RESOURCE_INVALID %s: %s" % [path, problem])
			invalid += problems.size()

	print("RESOURCES_CHECKED %d SCRIPTS_CHECKED %d FAILED %d INVALID %d" % [resources.size(), scripts.size(), failures, invalid])
	quit(1 if failures > 0 or (strict and invalid > 0) else 0)


func _collect(dir_path: String, extensions: Array[String], files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var entry_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect(entry_path, extensions, files)
		elif extensions.has(entry.get_extension()):
			files.append(entry_path)
		entry = dir.get_next()
	dir.list_dir_end()
