# Engineering docs

Claude's engineering documentation for this Godot 4.7.2 project: how the GDScript is written, what work is planned, and the contract of every module that is already code-ready. Scene and script contracts shared with Astra stay in [GUIDE.md](../GUIDE.md), vocabulary in [CONTEXT.md](../../CONTEXT.md), and architectural decisions with their reasons in [docs/adr/](../adr/). Start a session with ROADMAP.md to pick a ticket, then read CONVENTIONS.md before touching `scripts/`.

## Pages

| Page | What it is |
| --- | --- |
| [CONVENTIONS.md](CONVENTIONS.md) | The rules a coding session follows: language, strict typing and warnings-as-errors, style, Rules Core versus Adapter, time and randomness, data, snapshots, collision, input actions, tests, the CODE_READY Definition of Done, Git, sessions, and the shared-file protocol. |
| [ROADMAP.md](ROADMAP.md) | The single "where are we" page: how to run a session, the F0 to F14 ticket table with status, planned tickets, risk, requests to Astra, and what Astra has delivered. |
| [TEMPLATE.md](TEMPLATE.md) | The skeleton copied to `docs/engineering/<module>.md` when a module reaches CODE_READY: purpose, files, public contract, dependencies, invariants and tests, setup for Astra, open issues. |
| [testing.md](testing.md) | Module doc for the test framework: `TestCase`, the `SceneTree` runner, the PowerShell and POSIX wrappers, how to run and filter the suite, and how to write a test. |
| [project.md](project.md) | Module doc for the project configuration and composition root: `project.godot`, `default_bus_layout.tres`, `export_presets.cfg`, `scenes/main.tscn`, and the `GameSession` adapter. |
| [player-flight.md](player-flight.md) | Module doc for player flight: the `FlightModel` Rules Core — velocity from input axes and camera yaw, Flight Volume clamping, edge proximity, and the visual bank angle. The `PlayerController` adapter section is filled by F1-02. |

## Module docs

Each module gets its own `docs/engineering/<module>.md`, written from TEMPLATE.md when the module reaches CODE_READY, and it is the contract Astra wires against. Add one line for it to the table above as it lands. Rules Cores are code-only and are documented here, not in GUIDE.md.
