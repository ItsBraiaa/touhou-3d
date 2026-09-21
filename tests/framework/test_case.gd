class_name TestCase
extends RefCounted
## Base class for headless tests executed by `tests/run_tests.gd`.
##
## Put subclasses under `tests/unit/` or `tests/scene/` in files named `test_*.gd`
## and name test methods `test_*`. Assertions never throw: a failure is appended to
## [member failures] with the running test's name and the runner reports it after
## the method returns. Every assertion returns true when it passed, so a test can
## stop early with `if not assert_not_null(x): return`. Test methods and hooks may
## `await`; the runner awaits them. [member tree] is the running [SceneTree], for
## scene tests that add nodes to `tree.root`.


## One recorded assertion failure.
class Failure:
	extends RefCounted

	## Name of the `test_` method that was running when the failure was recorded.
	var test_name: String
	## What went wrong: the assertion name, the values, and the caller's message.
	var message: String

	func _init(p_test_name: String, p_message: String) -> void:
		test_name = p_test_name
		message = p_message


## Records every emission of one signal so a test can inspect them afterwards.
## Created through [method TestCase.signal_recorder], which keeps it alive for the
## duration of the test. The recorder holds the source only by instance id and the
## connection holds the recorder only by instance id, so neither keeps the other alive.
class SignalRecorder:
	extends RefCounted

	## Highest signal argument count the recorder can connect to.
	const MAX_ARGS: int = 6

	## One entry per emission, each holding the emitted arguments in order.
	var emissions: Array[Array] = []
	## Empty when connected; otherwise why the recorder could not connect.
	var error: String = ""

	var _source_id: int = 0
	var _signal_name: StringName
	var _handler: StringName

	func _init(source: Object, signal_name: StringName) -> void:
		_signal_name = signal_name
		if source == null:
			error = "signal_recorder: source is null"
			return
		_source_id = source.get_instance_id()
		var arg_count := _signal_arg_count(source, signal_name)
		if arg_count < 0:
			error = "signal_recorder: %s has no signal named %s" % [source, signal_name]
			return
		if arg_count > MAX_ARGS:
			error = "signal_recorder: signal %s has %d arguments; at most %d are supported" % [signal_name, arg_count, MAX_ARGS]
			return
		_handler = StringName("_on_emitted_%d" % arg_count)
		source.connect(signal_name, Callable(self, _handler))

	## Number of emissions recorded so far.
	func count() -> int:
		return emissions.size()

	## Arguments of the most recent emission, or an empty array when nothing was emitted.
	func last() -> Array:
		if emissions.is_empty():
			return []
		return emissions[emissions.size() - 1]

	## Forgets the recorded emissions but stays connected.
	func clear() -> void:
		emissions.clear()

	## Disconnects from the source signal. Later emissions are not recorded.
	func stop() -> void:
		if _handler.is_empty():
			return
		var source := instance_from_id(_source_id)
		if source == null:
			return
		var callable := Callable(self, _handler)
		if source.is_connected(_signal_name, callable):
			source.disconnect(_signal_name, callable)

	func _on_emitted_0() -> void:
		emissions.append([])

	func _on_emitted_1(a: Variant) -> void:
		emissions.append([a])

	func _on_emitted_2(a: Variant, b: Variant) -> void:
		emissions.append([a, b])

	func _on_emitted_3(a: Variant, b: Variant, c: Variant) -> void:
		emissions.append([a, b, c])

	func _on_emitted_4(a: Variant, b: Variant, c: Variant, d: Variant) -> void:
		emissions.append([a, b, c, d])

	func _on_emitted_5(a: Variant, b: Variant, c: Variant, d: Variant, e: Variant) -> void:
		emissions.append([a, b, c, d, e])

	func _on_emitted_6(a: Variant, b: Variant, c: Variant, d: Variant, e: Variant, f: Variant) -> void:
		emissions.append([a, b, c, d, e, f])

	static func _signal_arg_count(source: Object, signal_name: StringName) -> int:
		for info: Dictionary in source.get_signal_list():
			if StringName(info["name"]) == signal_name:
				return (info["args"] as Array).size()
		return -1


## The running [SceneTree]. Set by the runner before any hook is called.
var tree: SceneTree
## Name of the `test_` method currently running. Set by the runner.
var current_test: String = ""
## Failures recorded since [method begin_test]. The runner reads and reports them.
var failures: Array[Failure] = []
## Number of assertions, including [method fail], made since [method begin_test].
var assertion_count: int = 0

var _recorders: Array[SignalRecorder] = []


## Runs before each test method. Override to build fixtures; may `await`.
func before_each() -> void:
	pass


## Runs after each test method, also when it failed. Override to release fixtures; may `await`.
func after_each() -> void:
	pass


## Resets the per-test state. Called by the runner before [method before_each].
func begin_test(test_name: String) -> void:
	current_test = test_name
	failures.clear()
	assertion_count = 0
	_recorders.clear()


## Passes when [param condition] is true.
func assert_true(condition: bool, message: String = "") -> bool:
	return _check(condition, "assert_true: expected true, got false", message)


## Passes when [param condition] is false.
func assert_false(condition: bool, message: String = "") -> bool:
	return _check(not condition, "assert_false: expected false, got true", message)


## Passes when [param actual] equals [param expected]: `==` semantics, deep for arrays
## and dictionaries, int and float or String and StringName interchangeable. Values of
## otherwise different types are unequal instead of raising the engine's operand error.
func assert_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	return _check(_equal(actual, expected), "assert_eq: expected %s, got %s" % [_repr(expected), _repr(actual)], message)


## Passes when [param actual] differs from [param unexpected] (same rules as [method assert_eq]).
func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> bool:
	return _check(not _equal(actual, unexpected), "assert_ne: got %s, expected something else" % _repr(actual), message)


## Passes when [param actual] is within [param eps] of [param expected].
func assert_almost_eq(actual: float, expected: float, eps: float = 0.0001, message: String = "") -> bool:
	var passed := absf(actual - expected) <= eps
	return _check(passed, "assert_almost_eq: expected %s within %s, got %s" % [expected, eps, actual], message)


## Passes when [param value] is null.
func assert_null(value: Variant, message: String = "") -> bool:
	return _check(value == null, "assert_null: expected null, got %s" % _repr(value), message)


## Passes when [param value] is not null.
func assert_not_null(value: Variant, message: String = "") -> bool:
	return _check(value != null, "assert_not_null: got null", message)


## Passes when [param item] is contained in [param collection]: an Array or packed array
## element, a Dictionary key, or a substring of a String or StringName.
func assert_in(item: Variant, collection: Variant, message: String = "") -> bool:
	if _is_searchable(collection):
		return _check(item in collection, "assert_in: %s not found in %s" % [_repr(item), _repr(collection)], message)
	return _check(false, "assert_in: a %s cannot be searched" % type_string(typeof(collection)), message)


## Records a failure unconditionally. Returns false so it can end a test early.
func fail(message: String) -> bool:
	return _check(false, "fail: %s" % message, "")


## Connects a recorder to [param signal_name] on [param source] and returns it.
## Inspect `recorder.emissions`, `recorder.count()`, or `recorder.last()`. The test
## keeps the recorder alive until the next test starts. A missing signal, or one
## with more than six arguments, records a failure and returns an inert recorder.
func signal_recorder(source: Object, signal_name: StringName) -> SignalRecorder:
	var recorder := SignalRecorder.new(source, signal_name)
	if not recorder.error.is_empty():
		fail(recorder.error)
	_recorders.append(recorder)
	return recorder


func _check(passed: bool, failure_text: String, message: String) -> bool:
	assertion_count += 1
	if passed:
		return true
	var full_message := failure_text
	if not message.is_empty():
		full_message += " (%s)" % message
	failures.append(Failure.new(current_test, full_message))
	return false


## `==` on values of unrelated types (int and String, Array and PackedInt32Array,
## Vector2 and Vector2i) is a runtime error in GDScript, so only comparable pairs
## reach the operator: same type, null against anything, int against float, or
## String against StringName. Array and Dictionary contents compare safely inside.
static func _equal(a: Variant, b: Variant) -> bool:
	var type_a := typeof(a)
	var type_b := typeof(b)
	if type_a == type_b or type_a == TYPE_NIL or type_b == TYPE_NIL:
		return a == b
	var numeric_a := type_a == TYPE_INT or type_a == TYPE_FLOAT
	var numeric_b := type_b == TYPE_INT or type_b == TYPE_FLOAT
	if numeric_a and numeric_b:
		return a == b
	var stringy_a := type_a == TYPE_STRING or type_a == TYPE_STRING_NAME
	var stringy_b := type_b == TYPE_STRING or type_b == TYPE_STRING_NAME
	if stringy_a and stringy_b:
		return a == b
	return false


static func _is_searchable(collection: Variant) -> bool:
	match typeof(collection):
		TYPE_ARRAY, TYPE_DICTIONARY, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			return true
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return true
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return true
	return false


static func _repr(value: Variant) -> String:
	if value is Object:
		return str(value)
	return var_to_str(value).replace("\n", " ")
