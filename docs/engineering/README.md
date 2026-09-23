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
| [player-flight.md](player-flight.md) | Module doc for player flight: the `FlightModel` Rules Core — velocity from input axes and camera yaw, Flight Volume clamping, edge proximity, and the visual bank angle — the `PlayerController` adapter that reads the input, moves the body and banks the visuals, the `CameraRig` adapter that follows, orbits, frames a Target Lock and shortens against scenery, the `TargetSelector` Rules Core — fresh lock, left-to-right switch, invalidation by death and range — and the `Targeting` adapter that describes the `targetable` nodes to it and reports the lock, with the dev arena harness. |
| [menus-session.md](menus-session.md) | Module doc for Feature F2, menus and the Session skeleton: the `Interface` adapter that instances the eight menus and the HUD and resolves Back, the `MenuController` adapter that wires each menu's Section 14 buttons, focus, runtime text and keyboard footer, the `ScreenRouter` Rules Core — one stack of full screens and overlays, where Back returns to, whether gameplay is covered, and per-entry focus memory — reported as `screen_hidden` and `screen_shown`, and the `RunState` Rules Core — Run Mode and stage order, the Attempt, Active Time and Clear Time, committed score, Graze and bombs used under Retry and Restart, stage-entry values, the Snapshot slice, and the lifecycle signals, and the `GameSession` adapter on `Main` — menu actions, starting a Campaign or Direct Stage with the stage and ship under `WorldRoot`, pause and resume of the tree, Active Time and controls, Restart, Return to Menu, Quit. |
| [combat-hud.md](combat-hud.md) | Module doc for Feature F4, combat state and HUD: the `CombatState` Rules Core — Health 0 to 100, the one-charge Shield, Invulnerability after a hit or a Bomb, two Bombs on the rising edge of the button, Power Level and Power Progress with excess pickups as score, exactly-once defeat, the Checkpoint refill, and the capture/restore slice; the HUD binding and boss panel follow in F4-02 and F4-03. |

## Module docs

Each module gets its own `docs/engineering/<module>.md`, written from TEMPLATE.md when the module reaches CODE_READY, and it is the contract Astra wires against. Add one line for it to the table above as it lands. Rules Cores are code-only and are documented here, not in GUIDE.md.
