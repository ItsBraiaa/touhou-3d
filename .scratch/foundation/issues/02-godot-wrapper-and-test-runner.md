# F0-02 Godot wrapper and test runner

Status: done
Type: core
parallel-safe: no
Depends on: F0-01

## Goal

Give every session one command to run Godot and one command to run tests, with a tiny dependency-free test framework that the Rules Cores from ADR-0001 can be tested with headless.

## Read first

- `docs/engineering/CONVENTIONS.md`, sections "Tests", "Typing and warnings", "Style"
- `docs/adr/0001-gameplay-rules-in-node-free-cores.md`
- `tools/validate_scene_handoff.gd` (existing example of a `SceneTree` script that exits with a code)
- `docs/validation/first-scene.md` "Environment" (verified engine path)

## Facts already established

- Godot 4.7.2 stable console binary: `C:\Users\Braia\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`. Not on PATH. No addons installed. No Python available.
- Headless mode runs GDScript and the physics server; it does not render.

## Deliverables

### `tools/godot.ps1` and `tools/godot.cmd`

- Resolve the binary from `$env:GODOT_BIN` if set, else the Downloads path above. If neither exists, print a clear error naming both locations and exit 2.
- Print `Using Godot: <path>` to stderr once, then forward all arguments unchanged and return Godot's exit code.
- `tools/godot.cmd` simply calls the `.ps1` with `-ExecutionPolicy Bypass`.

### `tools/test.ps1`

- Runs `tools/godot.ps1 --headless --path <repo root> --script res://tests/run_tests.gd -- <extra args>` and exits with Godot's code.
- Accepts `-Filter <substring>` and passes it as `--filter=<substring>` after `--`.

### `tests/framework/test_case.gd`

`class_name TestCase extends RefCounted`.

- Hooks: `before_each()`, `after_each()` (virtual, empty).
- Assertions: `assert_true(v, msg := "")`, `assert_false`, `assert_eq(a, b, msg := "")`, `assert_ne`, `assert_almost_eq(a: float, b: float, eps := 0.0001, msg := "")`, `assert_null`, `assert_not_null`, `assert_in(item, collection)`, `fail(msg)`.
- Failures are collected in an array with the assertion message and the calling test name; the runner reads them. An assertion never throws.
- `signal_recorder(obj: Object, signal_name: StringName) -> Callable`-style helper that records emissions into an array the test can inspect (needed by core tests that assert on signals).

### `tests/run_tests.gd`

`extends SceneTree`.

- Discovers `res://tests/unit/**` and `res://tests/scene/**` recursively for files named `test_*.gd`.
- For each file: `load()`, instantiate, list methods starting with `test_`, run each with `before_each`/`after_each`, print `PASS <file>::<method>` or `FAIL <file>::<method>: <message>`.
- Supports `--filter=<substring>` from `OS.get_cmdline_user_args()` on `<file>::<method>`.
- Exposes itself to tests as `test.tree = self` so scene tests can `add_child` to `root` and `await process_frame`. Test methods may be coroutines; the runner `await`s them.
- Ends with `TESTS_PASSED <n>` / `TESTS_FAILED <n>` and `quit(0)` or `quit(1)`. A script that fails to load counts as a failure and is reported.

### `tests/unit/framework/test_self_check.gd`

Exercises each assertion in both passing and failing form (the failing form is checked by inspecting the collected failures of a nested `TestCase` instance, so the suite itself passes), plus one coroutine test and one signal-recorder test.

## Tests required

The self-check above. `tools/test.ps1` must exit 0 with it, and exit 1 when a deliberately failing test file is temporarily added (verify once, then remove the file).

## Out of scope

GUT, gdUnit, JUnit output, coverage, CI.

## Definition of Done

- `tools/test.ps1` prints `TESTS_PASSED` and exits 0; the exit-1 path was verified.
- `docs/engineering/testing.md` written from `TEMPLATE.md` (purpose, how to run, how to write a test, how to filter).
- Roadmap row updated, handoff log entry, commit `tools: add godot wrapper and headless test runner`.

## Handoff notes for Astra

`tools/godot.ps1` replaces "set `$godotExe` first" in the validation docs. Existing `tools/validate_*.gd` scripts keep working unchanged.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/foundation/issues/02-godot-wrapper-and-test-runner.md, then implement that ticket. Finish with its Definition of Done and commit.
```

## Outcome (2026-09-21)

- Delivered as specified, with three additions. `tools/test.ps1` refreshes the Godot class cache with a headless import (about three seconds) when a `.gd` file is newer than its last import stamp, because `class_name` resolution only works through `.godot/global_script_class_cache.cfg` and a fresh checkout would otherwise fail to load `extends TestCase`. The runner fails a test that makes no assertions and ends the run when one test exceeds a 30 s watchdog (`--timeout=<seconds>`). `signal_recorder()` returns a `SignalRecorder` object (`emissions`, `count()`, `last()`, `clear()`, `stop()`) instead of a bare Callable, held weakly on both sides so no reference cycle leaks.
- `assert_eq` and `assert_ne` treat values of unrelated types as unequal; in Godot 4.7.2 `1 == "1"` is a runtime operand error, not `false`.
- Verified: 14 self-check tests green with exit 0; exit 1 with a deliberately failing file and with a non-compiling file (both removed afterwards); `-Filter` through `tools/test.ps1` and `--` through `tools/godot.cmd`; no re-import on a plain rerun; no leaked ObjectDB instances; a clean run with every GDScript warning treated as an error via a temporary `project.godot` that was restored. Details in `docs/engineering/testing.md`.
