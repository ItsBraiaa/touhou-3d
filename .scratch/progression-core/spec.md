# F8 Progression cores and content — spec

Status: ready-for-agent
Owner: Claude
Source: STAGE_DESIGN.md ("Shared encounter rules", Stage 1 table, "Checkpoint contract", "Agent implementation contract"); STAGE_01_HANDOFF.md (marker names, Z ranges, checkpoint table); GUIDE.md Section 8; ENGINEERING_BRIEF Sections 4.G, 4.H, 8; ADR-0001, ADR-0003; CONTEXT.md "Run and progression".

## Goal

Every rule of Stage progression and Checkpoint restoration lives in Node-free, tested code before the Stage Director (F10) touches a scene. That means typed Definitions that can express STAGE_DESIGN exactly, an `EncounterMachine` with inactive → active → completed states, a deep `Snapshot` with a `CheckpointStore` that holds the refill, commit, Retry and Restart rules, and a validated Stage 1 content draft transcribed from STAGE_DESIGN. After F8 the Director only resolves markers, spawns actors and forwards events.

## Tickets

1. `01-definition-schemas-and-content-validation.md` (parallel-safe): `EncounterDefinition`, `WaveDefinition`, `RewardDefinition`, `CheckpointDefinition` and `StageDefinition`, each with `validate()`, plus the test that validates every `.tres` under `content/`.
2. `02-encounter-machine-core.md` (parallel-safe): `EncounterMachine`.
3. `03-snapshot-capture-restore.md` (parallel-safe): `Snapshot` and `CheckpointStore`, built on the real `CombatState` (F4-01) and `RunState` (F2-03) capture shapes.
4. `04-stage-01-content-draft.md` (parallel-safe): `content/stages/stage_01/*.tres`, flagged dev for Astra to tune.

01 can run in parallel with F5 and F9-01/F12-01. After 01, tickets 02 and 04 can run in parallel with each other. 03 follows 02.

## Cross-feature contracts

- **Definitions** (`scripts/definitions/`, each `extends Resource` with `validate() -> PackedStringArray`): `EncounterDefinition` (`id`, `next_id`, `completion: Completion { TRAVERSAL, ALL_REQUIRED_ENEMIES, OBJECTIVES }`, `requires_exit`, `waves`, `rewards`, `gate_id`, `checkpoint_id` = the Checkpoint that must be active before this Encounter can be entered, `required_objective_ids`); `WaveDefinition` (`spawn_markers: Array[NodePath]` relative to the Encounter root, `enemy_kinds: Array[StringName]` with one kind per marker, `enemy_kind_at(index)`, `activation: Activation { ON_ENTRY, AFTER_PREVIOUS_WAVE }`, `delay`); `RewardDefinition` (`kind: Kind { POWER, SHIELD }`, `count`, `origin_marker`); `CheckpointDefinition` (`id`, `after_encounter_id`, `resume_encounter_id`, `node_path`, `display_name`); `StageDefinition` (`id`, ordered `encounters`, `checkpoints`, lookups). F8 does not own `PatternDefinition` (F5-04), `EnemyDefinition` (F9-01) or the boss Definitions (F12-01).
- **Enemy ids**: `EncounterMachine.enemy_id(encounter_id, marker) -> StringName` gives `"<encounter_id>/<marker name>"`, for example `&"S1-02/Wave1_Spirit1"`. The Director passes it to `EnemyActor.spawn_setup` and back to `notify_enemy_defeated`.
- **EncounterMachine** (`scripts/progression/encounter_machine.gd`): `setup(stage)`, `notify_entered(id) -> bool`, `notify_exited(id)`, `notify_enemy_defeated(enemy_id, encounter_id)`, `notify_objective(objective_id) -> bool`, `notify_checkpoint_entered(checkpoint_id) -> bool`, `tick(delta)`, `get_active_encounter_id()`, `get_state(id)`, `is_completed(id)`, `is_checkpoint_activated(id)`, `get_wave_enemy_ids(id, wave_index)`, `get_open_gate_ids()`, `reset()`, `capture()`/`restore()`. Signals: `encounter_activated(encounter_id)`, `wave_requested(encounter_id, wave_index)`, `gate_opened(gate_id)`, `rewards_requested(encounter_id)`, `encounter_completed(encounter_id)`, `stage_cleared()`.
- **Snapshot** and **CheckpointStore** (`scripts/progression/`): `Snapshot.capture_from(combat, run, encounters, checkpoint_id)`, `restore_into(...)`, `to_dict()`/`from_dict()`. `CheckpointStore.activate(checkpoint_id, combat, run, encounters) -> bool`, `latest() -> Snapshot` (null at stage entry), `latest_checkpoint_id()`, `retry_into(...) -> bool`, `restart_into(...)`, `reset()`.
- **Stage 1 content**: `content/stages/stage_01/stage_01.tres`, which F10-01 assigns to `StageDirector.stage_definition`.

## Done when

- All F8 tests pass and the content validation test is green over `content/`.
- `docs/engineering/progression-core.md` documents every contract above, with the ENGINEERING_BRIEF Section 8 invariants mapped to named tests: idempotent encounter completion, objective (seal) orders, bomb kill of the last enemy, deep checkpoint snapshots, resource restoration, queued-spawn cancellation, statistics rollback.
- The Stage 1 draft is announced in `docs/HANDOFF_LOG.md` for Astra to tune.

## Out of scope

Everything that needs a Node: the Director, Gates, Checkpoint areas, PortalLinks and actor cleanup (F10), enemies (F9), Seals (F9-03), bosses (F12), and Stage 2 content (cut with F12-04, pending the user).
