# Engineering Conventions

Decisions from the planning grill of 2026-09-20. Every coding session reads this page before touching `scripts/`. Vocabulary is in [CONTEXT.md](../../CONTEXT.md); architectural decisions with their reasons are in [docs/adr/](../adr/). Scene and script contracts are in [GUIDE.md](../GUIDE.md).

## Language

- Code identifiers, comments, docs, commit messages, tickets: English.
- Player-facing text: Portuguese literals. No `tr()`, no translation CSV. A `scripts/ui/strings.gd` constants file is optional and used only when a string is needed from more than one script.

## Typing and warnings

- Strict static typing: every `var`, parameter, and return type is declared. `:=` is allowed only when the right-hand side makes the type obvious (a constructor, a literal, a typed call).
- `project.godot` sets these GDScript warnings to Error: `untyped_declaration`, `unused_variable`, `unused_parameter`, `shadowed_variable`. The `unsafe_*` family stays at its default.
- No gdlint or gdformat. Editor formatting is the standard.

## Style

Follows the official GDScript style guide (tabs, `snake_case` files and members, `PascalCase` classes, `UPPER_SNAKE` constants) plus:

- Member order: `class_name`, `extends`, doc comment, signals, enums, constants, `@export` groups, public vars, private vars, `@onready`, lifecycle callbacks, public methods, private methods.
- Every script in `scripts/` declares `class_name`, without prefixes.
- Private members start with `_`.
- Signals are past-tense events (`enemy_defeated`, `phase_changed`), never imperatives.
- One class per file. `##` doc comments on every public method and signal.
- No upward `get_node("../..")` paths. Collaborators arrive through `@export` references or a `setup()` call.

## Architecture rules

- **Rules Core versus Adapter** (ADR-0001). Gameplay rules live in `RefCounted` classes with an explicit `tick(delta)` and no Node, SceneTree, or physics dependency. Scene-attached scripts are Adapters: they read input and scene state, drive a core, and render its result. Cores never hold a Node reference.
- **Cores report through signals.** `RefCounted` declares signals; the adapter connects in `setup()`; tests connect lambdas.
- **Signals flow outward and upward, calls flow downward.** Producer to observer and child to owner by signal; owner to owned by direct typed call. No global event bus.
- **Every connection is made in exactly one place**, in code, in the owner's `setup()`. Authored scene signal connections are not used for gameplay. Retry and stage swaps must never double-connect.
- **No autoloads** (ADR-0002). `scenes/main.tscn` is the composition root. `Main` (game session) owns the Run and injects references downward.
- **Setup errors are loud.** Each Adapter validates required exports in `_ready`, calls `push_error` with its own node path and the missing field, then disables its own processing. `assert` is only for programmer invariants inside cores; it is stripped in release builds.

## Time and randomness

- All gameplay simulation runs in `_physics_process` at the default fixed step; cores are ticked with that delta. `_process` only interpolates visuals and reads camera-relative input.
- Active Time is accumulated in physics ticks and only while the tree is not paused. `RunState` also refuses to accumulate while its own paused flag is set.
- One `RandomNumberGenerator` per Attempt, seeded by the Stage Director and injected into patterns and enemies. No global `randf()`/`randi()` anywhere. Tests pass a fixed seed.

## Data and content

- Authored content is typed `Resource` Definitions (ADR-0003): schema scripts in `scripts/definitions/`, `.tres` values under `content/` (Astra's, tuned by Astra; Claude may write first drafts flagged `dev`).
- IDs are `StringName` values that match STAGE_DESIGN.md exactly (`S1-01`, `CP1-A`).
- Scene markers are referenced by paths relative to the Encounter root (`Spawns/Wave1_Spirit1`), resolved by the Director. Never absolute scene paths.
- Every Definition has `validate() -> PackedStringArray` (empty means valid). One test loads every `.tres` under `content/` and asserts validity. The Director refuses to start a stage with invalid content and reports the errors.

## Snapshots

`Snapshot` is a `RefCounted` value object holding only primitives, packed arrays, and dictionaries of primitives. Mutable collections are deep-copied on capture so a Snapshot cannot change afterwards. Each core exposes `capture()` and `restore(snapshot)`. `to_dict()` and `from_dict()` exist for tests and equality. A Snapshot never references a Node or a live core.

## Collision

| Layer | Bit | Use |
| --- | --- | --- |
| 1 | 1 | Scenery, Flight Volume walls, closed Gate barriers |
| 2 | 2 | Player body (`CharacterBody3D`, mask = layer 1 only) |
| 3 | 4 | Player Core (geometry source only, monitoring off) |
| 4 | 8 | Graze Volume (geometry source only, monitoring off) |
| 5 | 16 | Enemy and target hit volumes (geometry source for registered hit spheres) |

- Player body uses `move_and_slide` against layer 1, no gravity; velocity comes from `FlightModel`. Flight Volume limits are enforced by `FlightModel` clamping plus edge feedback, in addition to the authored walls.
- Projectiles are simulated by the Projectile Field (ADR-0004). They die on scenery and closed Gates through the injected obstacle query, on lifetime end, or on leaving the Flight Volume. Aim Assist respects obstacles for the whole travel.
- Enemy adapters register a hit sphere (center, radius from their `HitVolume` shape) with the field every physics tick.

## Input actions

Names in `project.godot`; bindings from PLANEJAMENTO.md Section 8. Dead zone 0.2. No mouse camera in this delivery.

`move_forward`, `move_back`, `move_left`, `move_right`, `ascend`, `descend`, `camera_left`, `camera_right`, `camera_up`, `camera_down`, `fire`, `focus`, `lock_target`, `next_target`, `bomb`, `pause`. Menus use the built-in `ui_*` actions; because Godot 4.7 binds `ui_accept` and `ui_cancel` to keys only, `project.godot` adds gamepad A to `ui_accept` and B to `ui_cancel` (F2-02). B is therefore also Back in menus while it is `bomb` in play.

## Tests

- Runner: `tests/run_tests.gd` (extends `SceneTree`), executed by `tools/test.ps1`, which wraps `tools/godot.ps1 --headless --path . --script res://tests/run_tests.gd`. Non-zero exit on any failure.
- Framework: `tests/framework/test_case.gd` with `assert_*` helpers and `before_each`/`after_each`.
- Layout: `tests/unit/<area>/test_<core>.gd` mirrors `scripts/`; `tests/scene/test_<scene>_contract.gd` instances a `.tscn` headless and checks its contract only.
- Cores are tested directly. Scene tests are smoke tests, never gameplay tests.

## Definition of Done for CODE_READY

1. `tools/test.ps1` passes.
2. Every ENGINEERING_BRIEF Section 8 invariant that belongs to the ticket has a named test.
3. No Error-level GDScript warnings.
4. `docs/engineering/<module>.md` written or updated (template in `docs/engineering/TEMPLATE.md`), GUIDE.md Section 6 row updated when an attached script changed, and a `docs/HANDOFF_LOG.md` entry added.
5. Committed.

## Git

- One integration branch, the one checked out in the primary tree (`main` until 2026-09-23, `dev-01` for the sprint). The remote and pushes are the user's.
- **Sprint lanes (2026-09-23 onward, [SPRINT.md](SPRINT.md)):** every agent works in its own `git worktree` on its own `lane/<name>` branch, never in the primary tree and never on another lane's branch. Work lands with `tools/lane.ps1 land`: merge the integration branch in, tests green, fast-forward the primary tree. `docs/HANDOFF_LOG.md` and `docs/engineering/README.md` merge with the union driver (`.gitattributes`).
- Message format: `area: summary` (`combat: add CombatState shield ordering`). Commits touching Astra-owned files carry `[shared]` in the summary.
- Claude commits only Claude's own changes at each CODE_READY and at every doc or ADR update. Never include another agent's unfinished work; never amend, rebase, or reset.

## Sessions

- One ticket per session. The ticket's kickoff line is pasted into a fresh session.
- A session ends with: tests green, ticket `Status: done` (or the blocker recorded and `Status: blocked`), roadmap row updated, handoff log entry, commit.
- Up to two sessions may run in parallel, only on tickets marked `parallel-safe: yes` (Node-free cores with tests on disjoint files). Shared-file edits and commits are serialized.
- **During the sprint ([SPRINT.md](SPRINT.md)) these three rules are relaxed:**
  - Four lane sessions run at once, each in its own worktree.
  - Each lane works only its pre-assigned queue, so `parallel-safe` stops mattering between lanes; within one lane, tickets still run one at a time.
  - A lane session may chain up to four tickets. Each ticket still ends with its own Definition of Done, its own commit and a `land`.

## Shared-file protocol

Claude owns `project.godot`, `export_presets.cfg`, `default_bus_layout.tres`, `scenes/main.tscn`, `scenes/dev/`, and, inside any `.tscn`, script attachment, exported values, collision layers, masks, monitoring flags, and instancing of Claude's prefabs. Astra owns geometry, visuals, layout, markers, materials, and `content/*.tres` values. Every change to an Astra-owned file is announced in `docs/HANDOFF_LOG.md`. The `tools/build_*.py` generators must be reconciled before any rerun over integrated scenes. During the sprint, lane `sol` (Astra) and lanes `glm-a` and `glm-b` also implement Claude-owned code tickets under these same conventions. A ticket's Files section is its edit boundary whoever runs it, and SPRINT.md "Shared files" lists which lane may touch the scenes and session files.
