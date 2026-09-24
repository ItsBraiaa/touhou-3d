# Engineering Brief — Touhou 3D

**Audience:** Claude and engineering agents refining the project with mattpocock skills.
**Status:** Engineering handoff. Gameplay design is approved; architecture is not yet selected. No game code was implemented during this planning task.
**Language:** Engineering documents and code identifiers in English. Player-facing UI in Portuguese.
**Delivery deadline:** September 24, 2026.
**Workspace:** `C:/Users/Braia/Documents/touhou-3d`.

**Updated ownership:** Astra is Lead Game Designer and authors Godot scenes, environments, camera composition, visual/audio presentation, and scene integration. Claude is Lead Code Engineer, refines technical details, and implements production GDScript and tests. Read [GUIDE.md](GUIDE.md) first for script attachment points, scene contracts, and the per-scene handoff. Workstreams below describe the whole engineering problem, not permission for Claude to replace Astra's scene work.

## 1. Objective and source of truth

Deliver a playable single-player third-person 3D bullet hell with two complete stages, reusable combat systems, reliable checkpoints, keyboard/gamepad support, and a clean interface.

Read these documents before refining the architecture:

1. [PLANEJAMENTO.md](PLANEJAMENTO.md): approved game rules, menus, art direction, scope boundaries, and academic requirements.
2. [STAGE_DESIGN.md](STAGE_DESIGN.md): encounter IDs, stage progression, boss/miniboss structure, checkpoint semantics, rewards, and acceptance checks.
3. This brief: engineering problems, subsystem boundaries to evaluate, validation requirements, and expected outputs of refinement.

The earlier [implementation draft](docs/superpowers/plans/2026-09-20-touhou-3d-implementation.md) is non-authoritative. It contains unvalidated file layouts, signatures, and implementation suggestions. It is not an instruction to use Superpowers, delegate work, or follow a specific architecture. Use GUIDE.md for the current scene/script division and integration contracts.

Preserve approved gameplay while refining technical choices. Treat numeric balance values and encounter durations as playtesting defaults. Record any proposed gameplay change explicitly instead of changing it through an implementation shortcut.

## 2. Current repository and assets

Observed on September 20, 2026:

- An initial Godot project exists. No gameplay implementation was found during planning.
- `project.godot` declares 4.7 features, Forward Plus, Jolt, and D3D12. Verify the installed editor and export environment; this configuration is not proof of compatibility.
- Godot was not discoverable through `godot` or `godot4` on PATH. Locate the existing installation before considering installation changes.
- A `.git` directory was not visible at the workspace root. Verify repository status before assuming branches, worktrees, or commits are available.
- Models are in `All models/kenney_space-kit`, `All models/Ultimate Monsters`, and `All models/Ultimate nature`.
- Sound packs are in `all-sounds/kenney_digital-audio`, `all-sounds/kenney_impact-sounds`, `all-sounds/kenney_interface-sounds`, and `all-sounds/kenney_sci-fi-sounds`.
- Five MP3 files exist in `music/`, named after the suggested Touhou compositions. Their recording provenance and permission to distribute are not established by the filenames.
- Asset packs contain duplicate formats and source files. Select only runtime assets and their dependencies for integration. Preserve the downloaded originals.

Approved models: `craft_speederA.glb` for the player ship, `Ghost.gltf` for the Lantern Guardian, and `Dragon_Evolved.gltf` for the Storm Guardian. Read [MODEL_SELECTION.md](MODEL_SELECTION.md) before importing or adapting these assets; it provides exact source paths, art direction, and inspected animation metadata. Preserve these approved choices. Runtime import and animation playback still require validation.

## 3. Non-negotiable product constraints

- Flight, collision, and dodging use real 3D volumes. The player can orbit bosses and change altitude and distance.
- Aim assist and target lock work on keyboard and gamepad. Keyboard gameplay does not require a mouse.
- Implement health percentage, one-hit shield, focus, visible vulnerable core, bombs, power pickups, familiars, graze, and segmented named boss attacks.
- Stage 1 has progression challenges and a final boss. Stage 2 adds three seals in any order and one two-phase miniboss before its final boss.
- Each stage has an intermediate checkpoint and a checkpoint before the final boss.
- First checkpoint activation and retry restore full health, one shield, and two bombs. Revisiting a checkpoint does not refill again.
- Stage 2 must last at least five minutes of active gameplay in a successful clear. Menus, pauses, failed attempts, and artificial waiting do not satisfy this requirement.
- Main menu: Iniciar, Selecionar fase, Opções, Sair. Both stages are selectable immediately.
- Interface is concise and visually readable. No mandatory tutorials, long dialogue, or written objective lists during combat.
- At least one boss must visibly animate its model. A moving static mesh alone is not the intended animation deliverable.
- Full project and exported build must be testable on the presentation computer.

## 4. Engineering workstreams

These are responsibility boundaries to evaluate, not a prescribed folder structure or class hierarchy. Prefer modules whose public interfaces are substantially simpler than their internals. Avoid one global controller that owns movement, UI, combat, stage progression, and resource management.

### A. Runtime and asset pipeline

**Owns:** engine compatibility, project launch, import conventions, selected resource dependencies, and export reproducibility.

**Must solve:** loading the selected ship and animated bosses with correct scale/orientation, retaining glTF textures and buffers, avoiding duplicate-format imports, preserving source licenses, and reopening the project from a clean extracted package.

**Completion evidence:** a selected model and animation render correctly in a running scene; an initial exported executable starts outside the editor.

### B. Player flight, camera, and targeting

**Owns:** three-axis movement, focus speed, scenery collision, camera framing, target acquisition/switch/release, and visual ship banking.

**Must solve:** frame-rate-independent movement, bounded diagonal speed, stable horizon, consistent ascent/descent, joystick dead zones, target disappearance, scenery occlusion, and camera behavior near geometry.

**Key boundary:** visual banking cannot move the damage core or rotate the camera. Aim assist cannot hit through scenery. Player navigation and aiming should not require continuously correcting an unstable camera.

**Completion evidence:** orbit targets at different heights and distances on keyboard and gamepad; dodge visible projectiles while maintaining orientation.

### C. Combat state and event ordering

**Owns:** health, shield, invulnerability, bomb charges, power and partial power progress, damage acceptance, and defeat.

**Must solve:** deterministic ordering for multiple collisions in one frame, shield consumption, post-hit immunity, one-time pickup consumption, bomb input edges, and exactly-once defeat.

**Required invariants:** a shielded hit never damages health; invulnerability rejects immediate follow-up hits; power does not decrease on damage; bombs cannot activate while paused or defeated; one press consumes one bomb.

**Completion evidence:** focused automated tests of the invariants, plus visible feedback in a combat scene.

### D. Projectiles, patterns, and graze

**Owns:** projectile spawning, movement, collision, lifetime, cleanup, ownership, pattern generation, and near-miss detection.

**Must solve:** fast bullets crossing the core between frames, frame-rate variation, large bullet populations, simultaneous hit/graze, bomb clearing, and cleanup when encounters end.

**Required invariants:** each hostile projectile awards graze at most once; a hit takes precedence over graze; invulnerability does not enable graze farming; cleared bullets award no graze; a local bomb does not clear the entire stage.

**Refinement question:** choose the simplest measured collision/rendering approach that supports the needed density. Evaluate node-based, centrally managed, and pooled representations with a small spike before selecting one. Do not assume an advanced rendering system is necessary.

**Completion evidence:** fast-projectile and graze tests, cleanup tests, and profiling of representative boss patterns.

### E. Weapons, pickups, and familiars

**Owns:** continuous firing, power-dependent shot configuration, familiar presentation, collectible attraction, and reward application.

**Must solve:** reachable drops in a volume, correct partial upgrade progress, no duplicate collection, handling a shield pickup while protected, and limiting repetitive SFX.

**Completion evidence:** progress from power 1 through power 3; verify excess power awards score and familiars do not introduce damage collision volumes.

### F. Enemy and boss behavior

**Owns:** common enemy behavior, visible anticipation, phase state, damage reception, pattern selection, and defeat signals.

**Must solve:** aimed attacks that permit reaction, alternate-height threats, boss segment overflow, phase transitions, animation-to-attack cues, and avoidable combinations of patterns.

**Required invariants:** excess damage cannot skip boss phases; phase transitions clear previous threats; enemies needed for progression remain reachable; off-screen attacks are warned.

**Completion evidence:** two common behaviors, the two-phase miniboss, and two three-phase bosses tested from different player heights.

### G. Encounter director and stage progression

**Owns:** encounter activation/completion, wave scheduling, one-time rewards, gate state, objective flags, and stage completion.

**Must solve:** duplicate death callbacks, returning through triggers, pending spawns during restore, arbitrary seal order, guard activation, and preventing barrier bypass through vertical movement.

**Key boundary:** enemies report outcomes; the stage director decides progression. Use stable encounter IDs from the stage design. Completion conditions are gameplay events, not time targets.

**Completion evidence:** both complete routes; all six seal orders; last-enemy bomb kills; no duplicated rewards or softlocks.

### H. Session and checkpoint restoration

**Owns:** campaign versus direct-stage mode, stage-entry state, latest checkpoint, committed statistics, and reconstruction of the current attempt.

**Must solve:** snapshots that do not alias live mutable state, resource refills, saved partial power, active-time accounting, completed objectives, and removal of failed-attempt objects/events.

**Snapshot content:** stage and resume encounter identifiers, combat resources/power progress, score, graze count, successful-path time, bombs-used statistic, completed encounters, and objective flags.

**Required invariants:** failed attempts cannot farm score or inflate completed-stage duration; restarting a stage differs from retrying a checkpoint; replaying a trigger does not refill resources; only settings persist across application launches.

**Completion evidence:** test deaths before/after every checkpoint and between the miniboss and final boss. Compare restored values and world state against the saved snapshot.

### I. Menus, HUD, settings, and audio

**Owns:** Portuguese navigation, essential feedback, input prompts, settings persistence, pause behavior, and sound/music transitions.

**Must solve:** visible focus on gamepad menus, controller disconnect recovery, input mode selection, corrupt settings fallback, independent volume buses, and transition-safe audio.

**Key boundary:** UI observes gameplay state and invokes explicit actions; it should not independently modify health, score, or progression flags.

**Completion evidence:** navigate all menus and complete each game mode without a mouse; verify pause freezes timers and world state; save/reload options; confirm credits access.

## 5. Decisions to resolve with the engineering skills

For each decision, write a short rationale, the chosen boundary, and the observable test. Use an ADR only when alternatives affect multiple systems or are costly to reverse.

| Decision | Evidence needed before choosing |
| --- | --- |
| Scene composition and state ownership | Draw responsibilities and identify who owns each mutable value |
| Projectile representation/collision | Profile realistic counts and validate fast moving collisions |
| Camera/target-lock strategy | Playable orbit and altitude prototype with both control methods |
| Pattern data versus scripted behavior | Express one ring, one aimed burst, and one spiral without duplicating lifecycle code |
| Encounter data model | Represent sequential waves, any-order seals, checkpoints, and segmented bosses |
| Snapshot reconstruction strategy | Demonstrate deep snapshot isolation and removal of queued failed-attempt work |
| Test harness | Run behavioral tests in the available Godot environment without a heavy dependency setup |
| Model/animation selection | Inspect actual clips, scale, textures, and import behavior |
| Renderer/export settings | Run an exported build on the target computer |

Balance values are tunable data. Product rules such as one-hit shields and three-axis flight are not technical tradeoffs to remove.

## 6. Suggested mattpocock skill sequence

Use the installed skills when their work is relevant; read their instructions before applying them. This brief does not require parallel agents or change the user's chosen toolchain.

1. **domain-modeling:** establish a short shared vocabulary for Stage, Encounter, Wave, Boss Phase, Checkpoint, Attempt, Run, Power, and Graze. Resolve ambiguous ownership and names before designing contracts.
2. **codebase-design:** propose deep modules with small interfaces, explicit dependencies, and clear ownership. The project is nearly empty; design for the two-stage scope rather than a general-purpose game framework.
3. **prototype:** answer uncertain camera/flight and projectile-density questions with disposable experiments. Record the question, observed result, and recommendation before deciding what becomes production code.
4. **tdd:** implement high-risk behavioral contracts such as collision ordering, shield/invulnerability, graze uniqueness, encounter completion, and snapshot restore through meaningful tests.
5. **diagnosing-bugs:** investigate failed behavior or performance regressions before choosing a fix.
6. **code-review:** compare completed changes against both the approved specs and the project's engineering conventions at working milestones.

## 7. Implementation milestones to derive after refinement

| Milestone | Deliverable | Exit criterion |
| --- | --- | --- |
| M0 — Environment | Reproducible project launch and initial export | Selected model renders and executable launches |
| M1 — Flight | Ship, camera, target lock, keyboard/gamepad | Player can orbit and change altitude without camera instability |
| M2 — Combat slice | All player mechanics, projectiles, one enemy pattern | Behavioral tests pass and dodge readability is demonstrated |
| M3 — Progression | Encounter gates, session modes, checkpoints | Restore tests pass and a short route can be replayed reliably |
| M4 — Complete stages | Both routes, seals, miniboss, final bosses | Both modes complete without progression blockers |
| M5 — Presentation | Final art/audio, menus/options, clean HUD | Full keyboard/gamepad flow works in an exported build |
| M6 — Delivery | Measured acceptance and packaged project | Stage 2 meets duration, package reopens, target-machine checks recorded |

These milestones specify outcomes rather than time estimates. Refine them into small tasks with files, dependencies, interfaces, tests, and completion evidence after the architecture questions are resolved. Keep the first playable milestone early; do not postpone export verification until the final day.

## 8. Validation strategy

### Automated behavior tests

Prioritize rules with expensive failure consequences:

- Movement normalization and focus scaling on all axes.
- Shield hit, immediate repeated hit, and post-invulnerability damage.
- Fast projectile segment crossing the core and hit-before-graze priority.
- Graze once per projectile; no rewards from cleanup or invulnerability.
- Power thresholds, excess score, duplicate pickup callbacks, bomb charge consumption.
- Boss phase overflow and exactly-once defeat.
- Idempotent encounter completion and all seal orders.
- Deep checkpoint snapshots, resource restoration, queued-spawn cancellation, and statistics rollback.
- Settings defaults, validation, and persistence.

Tests should observe public behavior and state transitions rather than mirror implementation details. Keep manual visual checks for art/layout changes instead of inventing brittle screenshot assertions.

### Manual and integration checks

Use the acceptance lists in both design documents. In addition, record the actual test environment, device availability, build used, and any unverified checks. A simulated gamepad event does not replace testing a physical controller.

Measure complete, uninterrupted Stage 2 runs with direct-stage starting power and campaign upgrades. Record successful-path duration separately from total play-session time. Diagnose short duration through encounter pacing rather than adding artificial waits.

Profile a dense final-boss encounter on the presentation computer. Initial target is 60 FPS, not a verified result. Record resolution and observed behavior before optimizing.

### Packaging

Retain the selected runtime models, external texture/buffer dependencies, audio, scripts, scenes, credits, and project configuration. Exclude generated caches and unused source-pack duplicates from the submission package. Reopen an extracted copy and run the exported executable independently before claiming delivery readiness.

## 9. Expected output from Claude's refinement

Produce engineering documentation before starting the full build:

- A concise shared domain vocabulary and state ownership map.
- A module design with responsibilities, public contracts, dependencies, and the reason for important boundaries.
- Results of the narrowly scoped flight/camera and projectile feasibility experiments, if needed.
- An ordered task plan tied to the milestone exit criteria and the two source specs.
- A test strategy with concrete cases for the invariants above.
- An asset selection/import list based on inspected files and animation clips.
- A short list of unresolved blockers, separating user decisions from environment issues and tunable defaults.

Keep documents in English and link them from this brief. Preserve the game design as the product source of truth. Do not mark a milestone complete solely because scripts exist or a headless import succeeds.

## 10. Suggested prompt for Claude

Use the current prompt in [GUIDE.md, Section 12](GUIDE.md#12-prompt-for-claude). It reflects Astra's scene ownership and Claude's responsibility for production GDScript, technical refinement, and tests.
