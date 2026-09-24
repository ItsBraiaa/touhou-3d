extends SceneTree
## Sprint gate (docs/engineering/SPRINT.md): loads every .tres and .tscn under res://content
## and res://scenes, and runs validate() on each loaded resource that defines it.
##
## A file that does not load (a text parse error, a missing dependency) is always a failure.
## validate() problems are failures only with --strict-validate; otherwise they are printed
## as warnings, because dev content drafts may be knowingly incomplete. Run by
## tools/lane.ps1 land; exits 1 on any failure.

const ROOTS: Array[String] = ["res://content", "res://scenes"]
const EXTENSIONS: Array[String] = ["tres", "tscn"]


func _initialize() -> void:
	var strict := OS.get_cmdline_user_args().has("--strict-validate")
	var files: Array[String] = []
	for root: String in ROOTS:
		_collect(root, files)
	var load_failures := 0
	var invalid := 0
	for path: String in files:
		var resource := ResourceLoader.load(path)
		if resource == null:
			print("RESOURCE_LOAD_FAILED %s" % path)
			load_failures += 1
			continue
		if resource.has_method(&"validate"):
			var problems: PackedStringArray = resource.call(&"validate")
			for problem: String in problems:
				print("RESOURCE_INVALID %s: %s" % [path, problem])
			invalid += problems.size()
	print("RESOURCES_CHECKED %d LOAD_FAILED %d INVALID %d" % [files.size(), load_failures, invalid])
	var failed := load_failures > 0 or (strict and invalid > 0)
	quit(1 if failed else 0)


func _collect(dir_path: String, files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var entry_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect(entry_path, files)
		elif EXTENSIONS.has(entry.get_extension()):
			files.append(entry_path)
		entry = dir.get_next()
	dir.list_dir_end()
