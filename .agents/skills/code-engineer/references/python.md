# Python reference

Python here is offline tooling, not gameplay: the `tools/build_*.py` generators that author `.tscn`, `.obj` and shader files, and any helper script a ticket needs. It never runs inside the game.

There is no interpreter on `PATH` in the Claude session — Astra runs the generators. Confirm the version with `python --version` before relying on version-gated syntax: builtin generics (`list[str]`) need 3.9, `X | None` and `dataclass(slots=True)` need 3.10, `tomllib` needs 3.11.

## Shape

**A function until it needs state.** A class with one method and no fields is a function wearing a costume. A module of plain functions plus a `main()` is the right shape for a generator or a one-off script.

**A `@dataclass` when you need a record**, not a hand-written `__init__` that assigns five fields:

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class SpawnMarker:
    name: str
    position: tuple[float, float, float]
```

`frozen=True` when nothing should mutate it after construction — it turns an aliasing bug into an error at the line that caused it. `slots=True` (3.10+) when you build many of them.

**Module layout:** imports, module constants, functions, then the entry point.

```python
def main() -> int:
    ...
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
```

Returning an exit code instead of calling `sys.exit` mid-function keeps the function callable and testable. Errors go to `stderr`; only the actual output goes to `stdout`.

## Typing

Annotate public functions; skip the obvious locals. Type hints are for the reader and the next change, not for a type checker this repo does not run.

```python
def write_scene(path: Path, nodes: Sequence[str], external: Sequence[str] | None = None) -> None:
```

- Builtin generics (`list[str]`, `dict[str, int]`, `tuple[float, ...]`), not `typing.List`.
- `X | None`, not `Optional[X]`.
- Accept the widest sensible type (`Iterable`, `Sequence`, `Mapping`), return the concrete one (`list`, `dict`). A caller can always narrow; it cannot widen.
- `Any` means "genuinely anything". If you are reaching for it to silence a question, answer the question instead.

## Stdlib first

- `pathlib.Path` for every path. `Path(__file__).resolve().parents[1]` is how the tools find the repo root — never hardcode and never build paths with string concatenation.
- `dataclasses` for records, `enum.Enum` for closed sets of values, `itertools` and `functools` before hand-rolled loops, `textwrap.dedent` for embedded blocks.
- `argparse` the moment a script takes more than one argument.
- `subprocess.run([...], check=True)` with a list, never `shell=True` with an interpolated string.
- Reach outside the stdlib only when the task genuinely needs it. A dependency in a build tool is a dependency every future run has to have installed.

## Errors

- Raise specific exceptions with a message naming the offending value: `raise ValueError(f"marker {name!r} has {len(position)} coordinates, expected 3")`. `!r` shows quotes and type, which is what you need at 2am.
- Never `except:` bare, and never `except Exception: pass`. Catch the exception you can actually handle.
- One `except Exception` at the top of `main()` that prints to `stderr` and returns non-zero is fine. Anywhere else it hides the bug.
- `raise NewError(...) from err` preserves the chain.
- `assert` is for invariants you believe cannot fail — it is stripped under `-O`. Validate inputs with an `if` and a raise.

## Text files and encoding

This runs on Windows, where the defaults are wrong for this project:

```python
path.write_text(content, encoding="utf-8", newline="\n")
```

- **Always pass `encoding="utf-8"`.** Without it, Python uses the locale encoding on Windows (cp1252 unless UTF-8 mode is on), which mangles the Portuguese UI strings — `Opções`, `GUARDIÃ DOS VENTOS`, `Música`. `tools/build_menu_handoff.py` and `build_stage_02.py` pass it for the scene files; the `.obj` writer in `build_stage_02.py:21` gets away without it only because its output is pure ASCII. Do not copy that omission.
- **Pass `newline="\n"` for generated text** (3.10+ on `Path.write_text`). The default translates `\n` to `\r\n` on Windows. `.gitattributes` normalizes to LF so the git diff stays clean, but the file on disk is CRLF until the next checkout, and Godot's import of `.obj` and `.gdshader` assets is happier with what you intended to write.
- `open(..., newline="")` for anything going through the `csv` module.

## Determinism in the generators

A generator that produces a different file on each run makes every diff unreadable and every handoff a negotiation. The existing tools get this right; keep it that way:

- Seed explicitly: `rng = random.Random(2209)`, never the module-level `random.*` functions.
- Iterate in a defined order. `sorted(paths)` before writing, and never depend on `set` iteration order or on filesystem listing order.
- Round floats to a fixed precision (`round(x, 4)`, `f"{x:.4f}"`) so a harmless last-bit difference does not rewrite the file.
- No timestamps, absolute paths or usernames in generated output.

Never rerun a `tools/build_*.py` generator over an integrated scene without reconciling first — it rewrites the file whole and drops the script attachments, exported values and collision masks that were wired in afterwards.

## Traps worth knowing

| Trap | What actually happens |
| --- | --- |
| `def f(items=[])` | one list shared by every call |
| `-7 // 2` | `-4` — floors toward negative infinity, unlike C |
| `0.1 + 0.2 == 0.3` | `False`; use `math.isclose` |
| `a is b` for values | identity, not equality; only correct for `None`, `True`, `False` |
| `copy.copy(nested)` | shallow; inner lists are still shared |
| mutating a list while iterating | skips elements; iterate over a copy |
| lambdas in a loop | late binding — capture with a default argument |
| `str += s` in a loop | quadratic; collect and `"".join(parts)` |
| `except Exception: pass` | hides the bug you are about to spend an hour on |
| `open()` without `encoding` | locale encoding on Windows |

## Performance

Only after a measurement says it matters. Then, in order: a better algorithm, then `"".join` over `+=`, then comprehensions over `append` loops, then a generator when the data does not fit comfortably in memory. `asyncio`, threads and `multiprocessing` are not on this list — an offline generator that finishes in two seconds does not need concurrency, and adding it costs every future reader.

## Style

PEP 8, four spaces, `snake_case` functions, `PascalCase` classes, `UPPER_SNAKE` module constants. No formatter or linter is configured, so match the file you are editing rather than reformatting it — a whitespace-only diff on an Astra-owned tool buries the real change and costs a handoff entry for nothing.
