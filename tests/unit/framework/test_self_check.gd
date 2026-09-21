extends TestCase
## Exercises every TestCase assertion in its passing form directly and in its failing
## form through a nested probe instance, so this suite passes while proving that the
## failing forms are recorded. Also covers a coroutine test, the exposed tree, and the
## signal recorder.


## Emits the signals the recorder tests listen to.
class Emitter:
	extends RefCounted

	signal fired
	signal value_changed(value: int)
	signal pair_changed(index: int, label: String)


var _probe: TestCase


func before_each() -> void:
	_probe = TestCase.new()
	_probe.tree = tree
	_probe.begin_test("probe")


func after_each() -> void:
	_probe = null


func test_before_each_ran() -> void:
	assert_not_null(_probe)
	assert_eq(_probe.current_test, "probe")


func test_assert_true_and_false() -> void:
	assert_true(assert_true(true))
	assert_true(assert_false(false))
	assert_false(_probe.assert_true(false, "custom note"))
	assert_false(_probe.assert_false(true))
	assert_eq(_probe.failures.size(), 2)
	assert_eq(_probe.failures[0].test_name, "probe")
	assert_eq(_probe.failures[0].message, "assert_true: expected true, got false (custom note)")
	assert_eq(_probe.failures[1].message, "assert_false: expected false, got true")


func test_assert_eq_and_ne() -> void:
	assert_true(assert_eq(3, 3))
	assert_true(assert_eq("a", "a"))
	assert_true(assert_eq([1, {"k": 2.5}], [1, {"k": 2.5}]))
	assert_true(assert_eq(Vector3.ONE, Vector3(1, 1, 1)))
	assert_true(assert_eq(2, 2.0), "int and float compare by value")
	assert_true(assert_eq("id", &"id"), "String and StringName compare by value")
	assert_true(assert_eq(null, null))
	assert_true(assert_ne(3, 4))
	assert_true(assert_ne(1, "1"), "unrelated types are unequal, not an operand error")
	assert_true(assert_ne([1, 2], PackedInt32Array([1, 2])))
	assert_true(assert_ne(Vector2.ONE, Vector2i.ONE))
	assert_true(assert_ne(1, null))
	assert_false(_probe.assert_eq(3, 4))
	assert_false(_probe.assert_eq(1, "1"))
	assert_false(_probe.assert_ne("same", "same"))
	assert_eq(_probe.failures.size(), 3)
	assert_eq(_probe.failures[0].message, "assert_eq: expected 4, got 3")
	assert_eq(_probe.failures[1].message, 'assert_eq: expected "1", got 1')
	assert_eq(_probe.failures[2].message, 'assert_ne: got "same", expected something else')


func test_assert_almost_eq() -> void:
	assert_true(assert_almost_eq(1.0, 1.00005))
	assert_true(assert_almost_eq(10.0, 10.4, 0.5))
	assert_false(_probe.assert_almost_eq(1.0, 1.01))
	assert_false(_probe.assert_almost_eq(10.0, 10.6, 0.5))
	assert_eq(_probe.failures.size(), 2)
	assert_true(_probe.failures[0].message.begins_with("assert_almost_eq: expected 1.01 within 0.0001, got 1"))


func test_assert_null_and_not_null() -> void:
	assert_true(assert_null(null))
	assert_true(assert_not_null(self))
	assert_true(assert_not_null(0))
	assert_false(_probe.assert_null(0))
	assert_false(_probe.assert_not_null(null))
	assert_eq(_probe.failures.size(), 2)
	assert_eq(_probe.failures[0].message, "assert_null: expected null, got 0")
	assert_eq(_probe.failures[1].message, "assert_not_null: got null")


func test_assert_in() -> void:
	assert_true(assert_in(2, [1, 2, 3]))
	assert_true(assert_in("k", {"k": 1}))
	assert_true(assert_in("ell", "hello"))
	assert_true(assert_in("S1-01", PackedStringArray(["S1-01", "S1-02"])))
	assert_false(_probe.assert_in(9, [1, 2, 3]))
	assert_false(_probe.assert_in("zz", "hello"))
	assert_false(_probe.assert_in(1, 5))
	assert_eq(_probe.failures.size(), 3)
	assert_eq(_probe.failures[0].message, "assert_in: 9 not found in [1, 2, 3]")
	assert_eq(_probe.failures[2].message, "assert_in: a int cannot be searched")


func test_fail_records_and_returns_false() -> void:
	assert_false(_probe.fail("deliberate"))
	assert_eq(_probe.failures.size(), 1)
	assert_eq(_probe.failures[0].message, "fail: deliberate")
	assert_eq(_probe.assertion_count, 1)


func test_begin_test_resets_state() -> void:
	_probe.fail("old")
	_probe.begin_test("next")
	assert_eq(_probe.current_test, "next")
	assert_eq(_probe.failures.size(), 0)
	assert_eq(_probe.assertion_count, 0)


func test_coroutine_is_awaited() -> void:
	# The engine increments the frame counter after each iteration, so two awaited
	# process_frame signals advance it by one. Reaching this assertion at all also
	# proves the runner awaited: otherwise it would report "no assertions".
	var frame_before := Engine.get_process_frames()
	await tree.process_frame
	await tree.process_frame
	assert_true(Engine.get_process_frames() > frame_before, "the runner must await coroutine tests")


func test_tree_root_accepts_nodes() -> void:
	var node := Node.new()
	node.name = "SelfCheckNode"
	tree.root.add_child(node)
	await tree.process_frame
	assert_true(node.is_inside_tree(), "nodes added to tree.root must enter the tree")
	tree.root.remove_child(node)
	node.free()


func test_signal_recorder_records_arguments() -> void:
	var emitter := Emitter.new()
	var recorder := signal_recorder(emitter, &"value_changed")
	assert_eq(recorder.count(), 0)
	assert_eq(recorder.last(), [])
	emitter.value_changed.emit(1)
	emitter.value_changed.emit(2)
	assert_eq(recorder.count(), 2)
	assert_eq(recorder.emissions, [[1], [2]])
	assert_eq(recorder.last(), [2])
	recorder.clear()
	assert_eq(recorder.count(), 0)
	recorder.stop()
	emitter.value_changed.emit(3)
	assert_eq(recorder.count(), 0, "a stopped recorder must ignore emissions")


func test_signal_recorder_handles_zero_and_two_arguments() -> void:
	var emitter := Emitter.new()
	var fired := signal_recorder(emitter, &"fired")
	var pairs := signal_recorder(emitter, &"pair_changed")
	emitter.fired.emit()
	emitter.pair_changed.emit(7, "seven")
	assert_eq(fired.emissions, [[]])
	assert_eq(pairs.last(), [7, "seven"])


func test_signal_recorder_reports_missing_signal() -> void:
	var emitter := Emitter.new()
	var recorder := _probe.signal_recorder(emitter, &"missing")
	assert_not_null(recorder)
	assert_false(recorder.error.is_empty())
	assert_eq(_probe.failures.size(), 1)
	assert_true(_probe.failures[0].message.begins_with("fail: signal_recorder:"))
	emitter.fired.emit()
	assert_eq(recorder.count(), 0, "an inert recorder never records")


func test_signal_recorder_survives_without_a_local_reference() -> void:
	var emitter := Emitter.new()
	signal_recorder(emitter, &"fired")
	emitter.fired.emit()
	assert_eq(emitter.get_signal_connection_list(&"fired").size(), 1, "the test keeps unreferenced recorders alive")
