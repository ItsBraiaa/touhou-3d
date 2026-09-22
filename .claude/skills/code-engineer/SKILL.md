---
name: code-engineer
description: Senior engineering discipline for writing, reviewing and refactoring GDScript (scripts/, tests/, tools/*.gd) and Python (tools/*.py) in this repo — idiomatic Godot 4 and modern Python, strict static typing, the smallest design that actually works, and precision about the details that silently break things. Use this whenever you are about to create or change a .gd or .py file: a new Rules Core or Adapter, a test, a build or validation tool, a bug fix, a refactor, a code review, or a "quick edit" — even when the request says nothing about style, cleanliness or best practices.
---

# Code Engineer

The job is not code that works once. It is code the next session can read, trust and change. Three things get you there: **fit the surrounding code**, **ship the smallest design that works**, and **be precise about the details that break silently**.

## 1. Read before you write

Open the two or three files closest to the change first — the sibling core, its test, the adapter that will drive it. Idiom is local, and this repo has a strong one: node-free `RefCounted` cores with an explicit tick, `@export` injection instead of `get_node("../..")`, `##` doc comments using `[method x]` BBCode, tests whose expected values come from the design documents. `scripts/player/flight_model.gd` and `tests/unit/player/test_flight_model.gd` are the reference pair — read them once per session before writing new gameplay code.

Then:

- **Say the change in one sentence.** If it needs two, it is two changes. Do them one at a time so each one is reviewable and revertable.
- **Search before you add.** `grep` for an existing helper before writing a new one. A second `clamp_to_bounds` is worse than an imperfect first one.
- **Place the logic before you write it.** Decide whether it belongs in a core (rules, node-free, directly testable) or an adapter (reads the scene, drives the core, renders the result). Logic that drifts into an adapter stops being testable, which is the whole reason ADR-0001 exists.

## 2. Ship the smallest design that works

Over-engineering is the default failure mode and its cost is invisible at review time: every layer is a layer every future reader must hold in their head, and it constrains the shape of the real requirement when it finally arrives. These heuristics keep the design small without making it sloppy.

**Write the call site first.** Decide the API by writing the line that will use it. If `configure(12.0, 0.45, 4.0)` reads fine, you do not need a config object, a builder, or a dictionary of options.

**One caller means no parameter.** A parameter every caller passes the same value for is a constant. A hook nobody calls is dead code with a comment attached. Serve today's callers — the second caller will tell you what the abstraction actually needs, and it is never what you guessed.

**Two is not a pattern.** Extract a base class, a shared helper or a generic on the third occurrence. Two similar things are often two different things that happen to look alike this week.

Do not reach for these unless a concrete, present requirement demands it:

- factories, builders, registries or `*Manager` classes for an object with a single construction site
- a base class, interface or `Protocol` with one implementation
- an event bus or signal relay where a direct typed call does the job (a global bus is banned outright here — CONVENTIONS, "Signals flow outward and upward")
- config dictionaries or `**kwargs` passthroughs standing in for named parameters
- a wrapper whose methods forward one-to-one to the thing they wrap
- an enum, flag or `mode` parameter with one real value
- caching, pooling or a fast path with no measurement behind it (the projectile field is the exception — ADR-0004 makes the pooling the point)

**Defensive code has to earn its line.** Validate what a caller can genuinely get wrong: an unset `@export`, an out-of-range Definition value, a file that may not exist. Do not validate what your own code just guaranteed — a null check on a value you assigned three lines above is noise that camouflages the checks that matter. In this repo setup errors are loud (`push_error` with the node path, then disable processing) and `assert` is reserved for programmer invariants inside cores, because it is stripped from release builds.

**Delete in the same change.** When a refactor orphans something, remove it now. "Leave it in case" is how a file grows to a thousand lines nobody dares touch.

**Short is not terse.** The offline generators in `tools/*.py` are deliberately dense; gameplay code is not. Clear names and straight-line flow beat cleverness — do not fold three steps into a nested ternary to save two lines.

## 3. Be precise

Precision is where "works on my machine" and "correct" part ways.

- **Know exactly what an API does before calling it.** `AABB` is a position plus a size, not two corners. `move_and_slide` reads `velocity` instead of taking an argument. `sort_custom` wants a "less than" predicate. One documentation lookup is cheaper than the bug.
- **Watch the silent conversions.** GDScript integer division (`5 / 2` is `2`), Python's `//` flooring toward negative infinity, float equality, radians against degrees, angles that wrap. Each language reference lists the traps.
- **Know what is shared by reference.** Arrays, dictionaries, `Resource`s, Python lists and dicts are passed by reference. Copy at the boundary when the receiver must not see later edits — `Snapshot` deep-copies on capture for exactly this reason.
- **Derive test expectations from the design documents, not from the implementation.** A test that records what the code currently returns detects change, not wrongness. `test_flight_model.gd` includes a test that would fail if the model hardcoded the authored values instead of reading them from `configure`.
- **Report what you verified, not what you expect.** "Tests pass" means `tools/test.ps1` exited zero and you saw it. If you changed behaviour you could not test, name that part.

## 4. Comment for the reader who lacks your context

- A `##` doc comment on every public method and signal (CONVENTIONS). Spend it on what the signature cannot say: units, ranges, sign conventions, what happens before `configure` is called, who owns a returned object. `## Sets the speed.` above `set_speed(speed: float)` earns nothing.
- Inline comments explain **why** — a decision, a trap, a non-obvious source. When a comment has to explain *what* a line does, a better name usually removes the need for it.
- No changelog comments. `# new`, `# changed` and a bare `# TODO: fix later` belong in the commit message or a ticket file under `.scratch/`.

## 5. Verify

- GDScript: `tools/test.ps1` — non-zero exit on any failure, and it refreshes Godot's class cache first. Use `tools/test.ps1 -Filter flight_model` while iterating.
- Zero Error-level warnings. `untyped_declaration`, `unused_variable`, `unused_parameter` and `shadowed_variable` are errors in `project.godot`, so an untyped `var` fails the run rather than producing a warning you can ignore.
- Python: run the tool on a real input and diff the result. Never rerun a `tools/build_*.py` generator over an integrated scene without reconciling first — it rewrites the whole file and drops the wiring.

## Language references

Read the one that matches the file you are about to touch, before writing rather than after. Both are short; they live beside this file.

- `references/gdscript.md` — typing, class layout, signals and connections, node lifetime and ownership, numbers, per-frame cost, the Godot 4 traps, and the adapter skeleton this repo expects.
- `references/python.md` — module and function shape, typing, stdlib choices, error handling, encoding on Windows, determinism in the generators, and the Python traps.

## This repo's rules win

Where this skill and the project documents disagree, the project documents are authoritative: `docs/engineering/CONVENTIONS.md` for style, typing, architecture, time and randomness, collision layers and the Definition of Done; `CONTEXT.md` for vocabulary; `docs/adr/` for the four decisions and their reasons; `docs/GUIDE.md` Section 3 for what you may edit and what belongs to Astra. Changing a file you do not own means a `docs/HANDOFF_LOG.md` entry and `[shared]` in the commit summary.
