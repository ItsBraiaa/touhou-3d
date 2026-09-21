extends SceneTree
## Headless test runner. Started by `tools/test.ps1`; never attached to a scene.
##
## Discovers `test_*.gd` files under `res://tests/unit/` and `res://tests/scene/`,
## instantiates each (they must extend [TestCase]), and runs every `test_*` method
## between `before_each()` and `after_each()`, awaiting coroutines. Prints one
## `PASS <file>::<method>` or `FAIL <file>::<method>: <message>` line per test, then
## `TESTS_PASSED <n>` and `TESTS_FAILED <n>`, and quits with 0 when nothing failed.
##
## User arguments (after `--`): `--filter=<substring>` runs only the tests whose
## `<file>::<method>` label contains the substring; `--timeout=<seconds>` replaces
## the per-test watchdog limit (default 30). A file that fails to load, a test that
## makes no assertions, and a test that exceeds the watchdog all count as failures.

## The framework is preloaded by path so the runner itself never depends on the
## global class cache; test files may still `extends TestCase`.
const TestCaseScript := preload("res://tests/framework/test_case.gd")
const TEST_ROOTS: Array[String] = ["res://tests/unit", "res://tests/scene"]
const TEST_FILE_PREFIX := "test_"
const TEST_METHOD_PREFIX := "test_"
const DEFAULT_TIMEOUT_SECONDS := 30.0


## Fails the run when one test awaits longer than the configured limit.
## A stuck coroutine cannot be cancelled, so the whole run is ended instead.
class Watchdog:
	extends Node

	var on_timeout: Callable
	var deadline_msec: int = -1

	func _process(_delta: float) -> void:
		if deadline_msec >= 0 and Time.get_ticks_msec() > deadline_msec:
			deadline_msec = -1
			on_timeout.call()


var _filter: String = ""
var _timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS
var _passed: int = 0
var _failed: int = 0
var _current_label: String = ""
var _finished: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_user_args(OS.get_cmdline_user_args())
	var watchdog := Watchdog.new()
	watchdog.name = "TestWatchdog"
	watchdog.on_timeout = _on_test_timed_out
	root.add_child(watchdog)
	var files := _discover_test_files()
	if files.is_empty():
		print("No test files found under %s" % ", ".join(TEST_ROOTS))
	for file in files:
		if _finished:
			return
		await _run_file(file, watchdog)
	_finish()


func _parse_user_args(user_args: PackedStringArray) -> void:
	for arg in user_args:
		if arg.begins_with("--filter="):
			_filter = arg.trim_prefix("--filter=")
		elif arg.begins_with("--timeout="):
			var value := arg.trim_prefix("--timeout=")
			if value.is_valid_float() and value.to_float() > 0.0:
				_timeout_seconds = value.to_float()
			else:
				print("Ignoring invalid --timeout value: %s" % value)
		else:
			print("Ignoring unknown user argument: %s" % arg)


func _discover_test_files() -> Array[String]:
	var files: Array[String] = []
	for test_root in TEST_ROOTS:
		if DirAccess.dir_exists_absolute(test_root):
			_collect_test_files(test_root, files)
	files.sort()
	return files


func _collect_test_files(dir_path: String, files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		print("Cannot open %s: %s" % [dir_path, error_string(DirAccess.get_open_error())])
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var entry_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_test_files(entry_path, files)
		elif entry.begins_with(TEST_FILE_PREFIX) and entry.ends_with(".gd"):
			files.append(entry_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _run_file(path: String, watchdog: Watchdog) -> void:
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		_report_load_failure(path, "script failed to load or compile (see the errors above)")
		return
	var instance: Variant = script.new()
	if not instance is TestCaseScript:
		if instance is Node:
			(instance as Node).free()
		_report_load_failure(path, "script does not extend TestCase")
		return
	var test: TestCaseScript = instance
	test.tree = self
	for method in _list_test_methods(script):
		if _finished:
			return
		var label := "%s::%s" % [path, method]
		if not _filter.is_empty() and not _filter in label:
			continue
		await _run_test(test, method, label, watchdog)


func _list_test_methods(script: GDScript) -> Array[String]:
	var methods: Array[String] = []
	for info: Dictionary in script.get_script_method_list():
		var method: String = info["name"]
		if method.begins_with(TEST_METHOD_PREFIX) and not methods.has(method):
			methods.append(method)
	return methods


func _run_test(test: TestCaseScript, method: String, label: String, watchdog: Watchdog) -> void:
	_current_label = label
	test.begin_test(method)
	watchdog.deadline_msec = Time.get_ticks_msec() + int(_timeout_seconds * 1000.0)
	await test.call(&"before_each")
	await test.call(method)
	await test.call(&"after_each")
	watchdog.deadline_msec = -1
	if _finished:
		return
	if test.assertion_count == 0:
		test.fail("test made no assertions (a runtime error may have aborted it; see the errors above)")
	if test.failures.is_empty():
		_passed += 1
		print("PASS %s" % label)
		return
	_failed += 1
	print("FAIL %s: %s" % [label, test.failures[0].message])
	for index in range(1, test.failures.size()):
		print("     also: %s" % test.failures[index].message)


func _report_load_failure(path: String, reason: String) -> void:
	_failed += 1
	print("FAIL %s: %s" % [path, reason])


func _on_test_timed_out() -> void:
	_failed += 1
	print("FAIL %s: timed out after %.1f s (raise the limit with --timeout=<seconds>)" % [_current_label, _timeout_seconds])
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("TESTS_PASSED %d" % _passed)
	print("TESTS_FAILED %d" % _failed)
	if _passed + _failed == 0:
		var filter_note := "" if _filter.is_empty() else " (filter: %s)" % _filter
		print("No tests ran%s" % filter_note)
		quit(1)
		return
	quit(1 if _failed > 0 else 0)
