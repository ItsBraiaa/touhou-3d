# GDScript reference (Godot 4.7)

Language-level idiom and traps. Project rules that override anything here live in `docs/engineering/CONVENTIONS.md`.

## Typing

Static typing is not decoration — it is how the engine catches a mistake at parse time instead of at frame 4000, and here `untyped_declaration` is an Error, so an untyped `var` stops the run.

```gdscript
var speed: float = 0.0                  # explicit when the literal is ambiguous
var bounds := AABB()                    # := when the right-hand side names the type
var targets: Array[Node3D] = []         # typed arrays, not bare Array
var scores: Dictionary[StringName, int] = {}
for info: Dictionary in source.get_signal_list():
	pass
```

- `:=` only where the type is obvious from the right-hand side: a constructor, a literal, a typed call. `var count := 0` is an int; `var ratio := 0` is also an int, which is usually the bug.
- Annotate every parameter and every return, including `-> void`.
- `Variant` belongs only at genuine boundaries — engine dictionaries, mixed signal payloads, test helpers. Everywhere else it disables the checks you are paying for.
- `is` tests, `as` casts. `as` yields `null` on a failed object cast rather than erroring, so `var body := node as CharacterBody3D` followed by a null check is the safe downcast.
- `@export var rig: Node3D` is null until the scene sets it. That is the one null check that always earns its line — validate it in `_ready` (see the skeleton below).

## File and class layout

One class per file. `class_name` on every script in `scripts/`, no prefix. Member order (CONVENTIONS): `class_name`, `extends`, `##` doc comment, signals, enums, constants, `@export` groups, public vars, private vars, `@onready`, lifecycle callbacks, public methods, private methods. Private members start with `_`.

- Small value objects that belong to one class go in it as inner classes — `TestCase.Failure` and `TestCase.SignalRecorder` are the pattern. A separate file for a three-field record is a file the reader has to go find.
- `static func` for helpers that touch no state; it documents the absence of state better than a comment does.
- `const` is compile-time. `preload("res://...")` works in a `const`; `load()` is runtime and does not.
- A `const` Array or Dictionary is shared by every instance — treat it as read-only. Class-level `var items: Array = []` is fine: each instance gets its own array, and default parameter values are re-evaluated on every call, so GDScript has no equivalent of Python's mutable-default trap.

## Signals and connections

```gdscript
signal edge_proximity_changed(value: float)     # past tense: an event that happened
edge_proximity_changed.emit(value)
source.edge_proximity_changed.connect(_on_edge_proximity_changed)
```

- Past-tense names only. `enemy_defeated`, not `defeat_enemy` — a signal announces, it does not command.
- Signals flow outward and upward (producer to observer, child to owner). Owner to owned is a direct typed call. No global bus.
- Every connection is made in exactly one place, in code, in the owner's `setup()`. Authored `.tscn` signal connections are not used for gameplay, because then there are two places to look and a retry or stage swap silently double-connects.
- Guard re-entry paths with `if not sig.is_connected(callable): sig.connect(callable)`, or use `CONNECT_ONE_SHOT` when one emission is all you want. `disconnect` needs a `Callable` equal to the one you connected: rebuilding it from the object and method name works (`TestCase.SignalRecorder.stop` relies on it), but a freshly written lambda never compares equal, so a lambda connection can only be undone by keeping its `Callable` in a field.
- Lambdas capture their locals **by value** at creation. A lambda that closes over a loop variable keeps the value it had on that iteration, not the last one.
- `await sig` suspends until the next emission; `await get_tree().process_frame` yields a frame. An `await` inside `_physics_process` splits your tick across frames — almost never what you want in simulation code.

## Nodes, lifetime and ownership

Order on instancing: `_init` (no tree, no children resolved) → `_enter_tree` → children become ready → `@onready` assignments → `_ready` → ... → `_exit_tree`.

- `@onready var mesh: MeshInstance3D = $Body/Mesh` — resolve once, not every frame. `$Path` is `get_node`, `%Name` is a scene-unique name, `^"path"` is a `NodePath` literal and `&"name"` a `StringName` literal.
- No upward paths. `get_node("../..")` couples a script to a scene layout it does not own; collaborators arrive through `@export` or `setup()`.
- `queue_free()` frees at the end of the frame and is safe to call from a signal handler or physics callback. `free()` is immediate and will crash anything still holding the node during that call.
- A freed `Object` does **not** compare equal to `null`. Use `is_instance_valid(node)`.
- `RefCounted` frees itself when the last reference drops, but a reference cycle leaks. Hold the other side by `get_instance_id()` and resolve with `instance_from_id()` when you need a back-reference — `TestCase.SignalRecorder` does exactly this so neither side keeps the other alive.
- Cores are `RefCounted` and never hold a `Node` (ADR-0001). Never subclass bare `Object` unless you are prepared to `free()` it yourself.
- `process_mode` controls pause behaviour: `PROCESS_MODE_ALWAYS` for menus and HUD, `PROCESS_MODE_DISABLED` to switch a misconfigured adapter off after `push_error`.

## Numbers and math

- **Integer division.** `5 / 2` is `2` when both sides are ints. Write `5.0 / 2`, or `float(a) / b`. This is the single most common silent GDScript bug.
- Use the typed global functions — `absf`, `absi`, `minf`, `maxi`, `clampf`, `clampi`, `roundi`, `snappedf`, `lerpf`. They keep static typing and skip the Variant path that `abs`/`min`/`clamp` take.
- Never compare floats with `==`. `is_equal_approx(a, b)`, `is_zero_approx(a)`, `Vector3.is_equal_approx`. In tests, `assert_almost_eq` with an explicit epsilon.
- `==` between unrelated types (int and String, Vector2 and Vector2i, Array and PackedInt32Array) is a runtime error, not `false`. Compare like with like, or go through `TestCase._equal` in tests.
- Angles are radians. `deg_to_rad` / `rad_to_deg` at the boundary; `lerp_angle` and `wrapf(angle, -PI, PI)` when a value wraps.
- Framerate independence: `lerp(a, b, rate * delta)` is framerate-dependent and wrong. Use `move_toward(a, b, rate * delta)` for a constant rate, or exponential smoothing `lerpf(a, b, 1.0 - exp(-rate * delta))` for an eased one.
- Simulation runs in `_physics_process` with the fixed step; `_process` only interpolates visuals and reads camera-relative input. Never mix the two deltas.
- No global `randf()` / `randi()` anywhere. One `RandomNumberGenerator` per Attempt, seeded by the Stage Director and injected. Tests pass a fixed seed.

## Per-frame cost

Measure before optimising, but do not create obvious waste:

- `Vector2`/`Vector3`/`Color`/`Transform3D` are value types — passing them allocates nothing. `Array`, `Dictionary` and `String` do allocate.
- `range(n)` builds an Array. In a hot loop, iterate the container directly or use `while`.
- Cache `get_node` results in `@onready`; never call `get_nodes_in_group()` or `find_child()` per frame.
- Build strings once, not per tick. `"%s: %d" % [name, value]` beats repeated `+`.
- Emit signals on change, not every tick. `FlightModel.edge_proximity_changed` fires only past `EDGE_PROXIMITY_EPSILON` — the same pattern applies to any continuous value feeding the HUD.
- Packed arrays (`PackedVector3Array`, `PackedFloat32Array`) for bulk numeric data; typed `Array[T]` for object collections.

## Traps worth knowing

| Trap | What actually happens |
| --- | --- |
| `5 / 2` | `2` — integer division |
| `float == float` | true only on exact bit equality |
| `freed_node == null` | `false`; use `is_instance_valid` |
| `==` on unrelated types | runtime error, not `false` |
| `lerp(a, b, rate * delta)` | framerate-dependent easing |
| lambda over a loop variable | captures by value at creation |
| connecting in both editor and code | double-connect, handler runs twice |
| `Array` assignment | shares the same array; `duplicate(true)` to copy |
| `@export` before `_ready` | still null; validate, do not assume |
| `assert` in release | stripped; never use it for input validation |

## Adapter skeleton

The shape CONVENTIONS asks for: validate exports loudly, wire once in `setup()`, tick the core in physics, render the result.

```gdscript
class_name PlayerController
extends CharacterBody3D
## Adapter: reads input and camera yaw, drives [FlightModel], renders the result.

@export var camera_rig: Node3D
@export var base_speed: float = 12.0
@export var focus_multiplier: float = 0.45
@export var edge_margin: float = 4.0

var _model: FlightModel


func _ready() -> void:
	if camera_rig == null:
		push_error("%s: required export 'camera_rig' is not set" % get_path())
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_model = FlightModel.new()
	_model.configure(base_speed, focus_multiplier, edge_margin)
	_model.edge_proximity_changed.connect(_on_edge_proximity_changed)


func _physics_process(_delta: float) -> void:
	var move := Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	var vertical := Input.get_axis(&"descend", &"ascend")
	var focus := Input.is_action_pressed(&"focus")
	velocity = _model.compute_velocity(move, vertical, focus, camera_rig.rotation.y)
	move_and_slide()
	global_position = _model.clamp_position(global_position)


func _on_edge_proximity_changed(value: float) -> void:
	pass  # render the edge feedback
```

## Repo mechanics

- `.gd.uid` files are generated by the editor and committed. Never hand-edit one, never delete one while the `.gd` still exists.
- `class_name` types resolve only through Godot's global class cache in `.godot/`. `tools/test.ps1` refreshes it automatically when a `.gd` file is newer than the last import, which is why a brand-new core resolves on the first run.
- `@tool` scripts execute in the editor. Guard anything with side effects behind `Engine.is_editor_hint()`.
- Tests: `tests/unit/<area>/test_<core>.gd` mirrors `scripts/`, methods named `test_*`, fixtures in `before_each`. Assertions record failures instead of throwing, so `if not assert_not_null(x): return` is how a test stops early. Cores are tested directly; scene tests are contract smoke tests, never gameplay tests.
