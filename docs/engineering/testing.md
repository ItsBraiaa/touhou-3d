# Testing

Headless test framework, runner, and Godot wrappers. CODE_READY with ticket F0-02 on 2026-09-21.

## Purpose

Owns how tests are discovered, executed, and reported: `TestCase` (assertions, hooks, signal recorder), the `SceneTree` runner, and the PowerShell wrappers that give every session one command for Godot and one for the tests. It does not own test content: Rules Core tests live next to their feature under `tests/unit/<area>/`, scene smoke tests under `tests/scene/`. Deliberately out of scope: GUT, gdUnit, JUnit output, coverage, CI.

## Files

- `tools/godot.ps1`: resolves the Godot 4.7.2 console binary from `$env:GODOT_BIN`, else the verified Downloads path; prints `Using Godot: <path>` to stderr once; forwards every argument; returns Godot's exit code, or 2 when no binary exists at either location.
- `tools/godot.cmd`: the same from `cmd.exe`, with `-ExecutionPolicy Bypass`.
- `tools/test.ps1`: runs the suite headless and exits with the runner's code.
- `tools/godot.sh`, `tools/test.sh`: POSIX mirrors of the two wrappers for hosts without PowerShell (this Linux machine, since F0-03). Same resolution order (`$GODOT_BIN`, then `~/Documents/Godot/Godot_v4.7.2-stable_linux.x86_64`), same import heuristic and stamp, same exit codes; the flags are `-f <substring>` and `-i`.
- `tests/run_tests.gd`: the runner, `extends SceneTree`.
- `tests/framework/test_case.gd`: `class_name TestCase`, the base class of every test.
- `tests/unit/framework/test_self_check.gd`: exercises every assertion in passing and failing form, one coroutine test, the exposed tree, and the signal recorder.

## How to run

```powershell
tools/test.ps1                       # whole suite
tools/test.ps1 -Filter flight_model  # only tests whose "<file>::<method>" contains the substring
tools/test.ps1 -Import               # force the class-cache refresh first
tools/test.ps1 --timeout=60          # per-test watchdog in seconds (default 30)
```

On Linux (no PowerShell):

```sh
tools/test.sh                        # whole suite
tools/test.sh -f flight_model        # filter
tools/test.sh -i                     # force the class-cache refresh first
tools/test.sh --timeout=60           # per-test watchdog in seconds
```

Output is one `PASS res://tests/unit/<area>/test_x.gd::test_y` or `FAIL <label>: <message>` line per test, then `TESTS_PASSED <n>` and `TESTS_FAILED <n>`. Exit 0 only when nothing failed and at least one test ran; a filter that matches nothing is exit 1.

Class cache: a script that names a `class_name` type (`TestCase`, the Rules Cores) resolves it only through `.godot/global_script_class_cache.cfg`, which the editor writes when it scans the project. `tools/test.ps1` therefore runs `godot --headless --import` (about three seconds) when that cache is missing, when `-Import` is given, or when a `.gd` under `scripts/`, `tests/`, `tools/`, `scenes/`, `content/`, or `addons/` is newer than its last import stamp (`.godot/test_import.stamp`). The import also creates `.uid` files next to new scripts and imports new assets, exactly as opening the editor would. Commit `.uid` files together with their scripts.

Running Godot directly:

```powershell
tools/godot.ps1 --headless --path . --script res://tools/validate_scene_handoff.gd
```

```sh
tools/godot.sh --headless --path . --script res://tools/validate_scene_handoff.gd
```

From a PowerShell prompt, PowerShell itself removes the first bare `--` of a direct `.ps1` call, so Godot user arguments need `-- --` there. `tools/godot.cmd` and `tools/test.ps1` forward `--` correctly.

## How to write a test

Illustration for a future core; `FlightModel` does not exist yet.

```gdscript
extends TestCase
## Tests FlightModel (scripts/player/flight_model.gd).


var _model: FlightModel


func before_each() -> void:
	_model = FlightModel.new()


func test_ascend_is_clamped_to_volume_top() -> void:
	_model.tick(0.5)
	assert_almost_eq(_model.position.y, 12.0)


func test_boundary_hit_is_reported_once() -> void:
	var hits := signal_recorder(_model, &"boundary_hit")
	_model.tick(1.0)
	_model.tick(1.0)
	assert_eq(hits.count(), 1)
	assert_eq(hits.last(), [Vector3.UP])
```

Rules:

- File `tests/unit/<area>/test_<core>.gd` mirrors `scripts/<area>/<core>.gd`; scene smoke tests are `tests/scene/test_<scene>_contract.gd`. Only files named `test_*.gd` are discovered.
- Methods are named `test_*`, take no parameters, and return `void`. One instance per file; `before_each` rebuilds fixtures, `after_each` releases them.
- Assertions never throw and return `true` when they pass, so `if not assert_not_null(x): return` ends a test early. Every `assert_*` takes an optional trailing message.
- A test that makes no assertions fails with "test made no assertions". This also catches tests aborted by a runtime error before their first assertion; the `SCRIPT ERROR` lines appear above the FAIL line.
- Coroutines: `await tree.process_frame` or `await tree.create_timer(0.1).timeout`. The runner awaits the method and both hooks. A test that awaits longer than the watchdog fails and ends the run.
- Scene tests: `tree.root.add_child(instance)`, `await tree.process_frame`, check the contract, then `tree.root.remove_child(instance)` and `instance.free()`.
- Randomness: pass a seeded `RandomNumberGenerator` to the core (CONVENTIONS "Time and randomness").

## How to filter

`tools/test.ps1 -Filter <substring>` forwards `--filter=<substring>`; the runner keeps the tests whose `<file>::<method>` label contains it. `-Filter test_self_check` runs one file, `-Filter ::test_assert_in` runs one method, `-Filter tests/scene/` runs the scene smoke tests. Every file is still loaded, so a compile error anywhere is reported even under a filter.

## Public contract

### TestCase

| Member | Meaning |
| --- | --- |
| `tree: SceneTree` | The running tree, set by the runner before any hook. |
| `before_each()`, `after_each()` | Virtual hooks around every test method; may `await`. |
| `assert_true(c, msg = "")`, `assert_false(c, msg = "")` | Boolean checks. |
| `assert_eq(actual, expected, msg = "")`, `assert_ne(actual, unexpected, msg = "")` | `==` semantics, deep for Array and Dictionary; int and float, String and StringName compare by value; values of unrelated types are unequal instead of raising the engine's operand error. |
| `assert_almost_eq(actual, expected, eps = 0.0001, msg = "")` | Float tolerance. |
| `assert_null(v, msg = "")`, `assert_not_null(v, msg = "")` | Null checks. |
| `assert_in(item, collection, msg = "")` | Array or packed array element, Dictionary key, or substring of a String or StringName. |
| `fail(msg)` | Unconditional failure; returns `false`. |
| `signal_recorder(obj, &"signal") -> SignalRecorder` | `emissions: Array[Array]`, `count()`, `last()`, `clear()`, `stop()`, `error`. Signals with up to six arguments. The test keeps the recorder alive until the next test starts; a missing signal records a failure and returns an inert recorder. |
| `failures: Array[Failure]`, `assertion_count`, `current_test`, `begin_test(name)` | Runner-facing state. Tests read `failures` only when probing a nested `TestCase`, as the self-check does. |

### Runner

| Behaviour | Detail |
| --- | --- |
| Discovery | `res://tests/unit/**` and `res://tests/scene/**`, files `test_*.gd`, sorted by path; methods `test_*` in declaration order. |
| Failure sources | assertion failures, `fail()`, no assertions, a script that fails to load or does not extend `TestCase`, watchdog timeout. |
| User args | `--filter=<substring>`, `--timeout=<seconds>`; unknown arguments are printed and ignored. |
| Exit code | 0 when `TESTS_FAILED 0` and at least one test ran; 1 otherwise. |

## Dependencies

Godot 4.7.2 console binary at the path recorded in `docs/validation/first-scene.md` "Environment", or `$env:GODOT_BIN`; on Linux `~/Documents/Godot/Godot_v4.7.2-stable_linux.x86_64` or `$GODOT_BIN`. No addons, no Python.

## Invariants and tests

| Invariant | Test |
| --- | --- |
| Every assertion returns true in its passing form and records a failure carrying the test name in its failing form | `test_self_check.gd::test_assert_*`, `test_fail_records_and_returns_false` |
| `begin_test` resets failures, the assertion count, and recorders | `test_begin_test_resets_state` |
| Coroutine tests are awaited; `tree` is the live tree | `test_coroutine_is_awaited`, `test_tree_root_accepts_nodes` |
| Signal recorder captures zero, one, and two argument emissions, stops on request, reports missing signals, stays alive without a local reference, and does not leak | `test_signal_recorder_*`; leak check is the absence of "ObjectDB instances were leaked" at exit |
| `tools/test.ps1` exits 1 on a failing test, on a file that fails to compile, and on a filter that matches nothing; `tools/godot.cmd` forwards `--` | Verified manually on 2026-09-21 (ticket F0-02 "Tests required"); not automated |
| The framework compiles with every GDScript warning treated as an error | Verified manually on 2026-09-21 with a temporary `project.godot`. Since F0-03 `project.godot` treats the four CONVENTIONS warnings as errors permanently, so every run re-verifies them |

## Setup for Astra

Nothing to attach. Run a validation script with `tools/godot.ps1 --headless --path . --script res://tools/validate_scene_handoff.gd` (`tools/godot.sh` on Linux). Before handing off a scene that has a contract test, run `tools/test.ps1 -Filter <scene>` (`tools/test.sh -f <scene>`). Your scripts compile under the four warnings-as-errors: type `for` iterators over untyped arrays (`for path: String in paths`).

## Open issues

- A runtime error inside a test is printed by Godot but not attributed to the test. The "no assertions" rule catches the common case (error before the first assertion); a test that errors after its assertions passed still passes.
- The watchdog ends the whole run, because a suspended GDScript coroutine cannot be cancelled from outside.
- `Engine.get_process_frames()` increments after each iteration, so it lags one frame behind `process_frame`; count awaited frames instead of comparing frame numbers exactly.
- The import heuristic watches only the listed code folders; a `class_name` script elsewhere needs `tools/test.ps1 -Import`.
- The exit-2 path of `tools/godot.ps1` (no binary anywhere) was reviewed but not executed, since the default binary is present on this machine.
- The headless import prints `Attempting to parent and popup a dialog that already has a parent` a few times while "Reopening scenes" from the editor layout saved in `.godot/editor/`. Editor noise: the import exits 0 and the tests are unaffected.
