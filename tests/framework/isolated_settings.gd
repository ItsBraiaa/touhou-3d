class_name IsolatedSettings
extends RefCounted
## Keeps the scene tests off the player's real [code]user://settings.cfg[/code].
##
## Every worktree's suite shares one [code]user://[/code] folder with the real game (it is
## keyed by the project name), and since F16-03 the player can remap controls there. A scene
## test that instances [code]scenes/main.tscn[/code] calls [method isolate] after
## [code]instantiate()[/code] and before [code]add_child()[/code], so its [Interface] reads
## and writes a per-process file instead, and calls [method clean] once the scene is freed.
## With no file, [Settings] starts from its defaults, so key-driven tests always see the
## default bindings whatever the player saved.

const _SUFFIXES: Array[String] = ["", ".tmp", ".bak"]


## The per-process settings file the scene tests use.
static func path() -> String:
	return "user://test_settings_%d.cfg" % OS.get_process_id()


## Points [param main]'s [Interface] at [method path]. Does nothing when the scene has no
## Interface, so the test's own assertion reports that.
static func isolate(main: Node) -> void:
	if main == null:
		return
	var interface := main.get_node_or_null(^"Interface") as Interface
	if interface != null:
		interface.settings_path = path()


## Deletes the per-process file and the temporary and backup files a save leaves beside it.
static func clean() -> void:
	for suffix: String in _SUFFIXES:
		var file := path() + suffix
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
