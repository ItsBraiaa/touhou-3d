# Progression Definitions and EncounterMachine

## Purpose

The progression module owns the authored Stage route as typed Resources and the `EncounterMachine` Rules Core that plays it: Encounter lifecycle (inactive → active → completed), route-ordered entry behind its Checkpoint, Wave scheduling, completion conditions, one-time rewards, Gate opening, Objective and Checkpoint flags, and capture/restore for Retry and Restart — all idempotent. The Stage Director (F10-01) drives the machine and turns its signals into spawns, Gate nodes and Pickups; this module holds no Node and no scene.

## Files

- `scripts/definitions/encounter_definition.gd` (`EncounterDefinition` Resource)
- `scripts/definitions/wave_definition.gd` (`WaveDefinition` Resource)
- `scripts/definitions/reward_definition.gd` (`RewardDefinition` Resource)
- `scripts/definitions/checkpoint_definition.gd` (`CheckpointDefinition` Resource)
- `scripts/definitions/stage_definition.gd` (`StageDefinition` Resource)
- `scripts/progression/encounter_machine.gd` (`EncounterMachine` Rules Core, ADR-0001)
- `content/stages/stage_01/*.tres` (Stage 1 dev draft; values are Astra's)

## Public contract

### Definition exports

| Resource | Exported data |
| --- | --- |
| `WaveDefinition` | Relative `spawn_markers`, matching `enemy_kinds`, `activation` (`ON_ENTRY` / `AFTER_PREVIOUS_WAVE`), non-negative `delay`; `enemy_kind_at(index)`. |
| `RewardDefinition` | `kind` (`POWER` / `SHIELD`), positive `count`, relative `origin_marker`. |
| `EncounterDefinition` | Stable `id` and `next_id`, `completion` (`TRAVERSAL` / `ALL_REQUIRED_ENEMIES` / `OBJECTIVES`), `requires_exit`, `waves`, `rewards`, `gate_id`, `checkpoint_id`, `required_objective_ids`. |
| `CheckpointDefinition` | Stable `id`, `after_encounter_id`, `resume_encounter_id`, relative `node_path`, Portuguese `display_name`. |
| `StageDefinition` | Stable `id`, ordered `encounters`, `checkpoints`; `find_encounter`, `encounter_index`, `find_checkpoint`. |

### EncounterMachine signals

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `encounter_activated` | `id: StringName` | Entry into the next route Encounter was accepted (its Checkpoint, if any, activated). Before its Waves are scheduled. |
| `wave_requested` | `id: StringName, wave_index: int` | A Wave is due: inside the scheduling call when its delay is 0, otherwise when `tick` counts the delay down. |
| `gate_opened` | `gate_id: StringName` | A completing Encounter's Gate must open. Always the first completion signal. |
| `rewards_requested` | `id: StringName` | A completing Encounter's one-time rewards must be granted; never twice for the same Encounter. |
| `encounter_completed` | `id: StringName` | The Encounter completed; re-entering its volumes changes nothing. |
| `stage_cleared` | — | The last Encounter of the Stage completed. |

Completion emits in this order: `gate_opened` (if the Encounter has a gate) → `rewards_requested` (if it has rewards) → `encounter_completed` → `stage_cleared` (after the last Encounter). Each fires at most once per Encounter until a `restore` or `reset`.

### Methods

| Method | Effect |
| --- | --- |
| `StageDefinition.validate()` and each Definition's `validate()` | Empty array when valid; otherwise messages prefixed by the Definition's id. |
| `EncounterMachine.setup(stage)` | Loads the Stage with every Encounter INACTIVE and no Checkpoint activated; asserts `stage.validate()` is empty. |
| `notify_entered(id) -> bool` | Accepts only the next route Encounter, while INACTIVE and behind its activated Checkpoint; activates it, emits `encounter_activated`, requests the ON_ENTRY Waves (delay 0 inside the call). Every refusal returns false with no signal. |
| `notify_exited(id)` | TRAVERSAL completes; `requires_exit` latches the exit and completes when the enemy/Objective condition already holds; otherwise ignored (the boss ExitVolume never completes the boss). |
| `notify_enemy_defeated(enemy_id, encounter_id)` | Counts an enemy once, only while its Encounter is ACTIVE and only in an already-requested Wave; a fully defeated Wave schedules the next `AFTER_PREVIOUS_WAVE` Wave after its delay; ALL_REQUIRED_ENEMIES completes when every Wave was requested and every enemy counted. |
| `notify_objective(objective_id) -> bool` | Records a listed Objective once, in any order; OBJECTIVES completes when every listed id is recorded. |
| `notify_checkpoint_entered(checkpoint_id) -> bool` | First activation only, and only once the Checkpoint's `after_encounter_id` is COMPLETED. |
| `tick(delta)` | Counts the ACTIVE Encounter's scheduled Waves down and requests each when due. |
| `capture() -> Dictionary` | New Dictionary of primitives: `completed`, `rewarded`, `objectives`, `checkpoints` (PackedStringArrays) and `resume_encounter_id` (String; the latest activated Checkpoint's resume Encounter, or the first Encounter). |
| `restore(data)` | Every Encounter before `resume_encounter_id` becomes COMPLETED and rewarded (including one still ACTIVE at capture, such as S1-06 at CP1-B); the rest INACTIVE; Objective and Checkpoint flags return from the capture; scheduled Waves, counted enemies and exit latches clear; no signal; `data` is not kept. |
| `reset()` | Back to setup state (Restart). |
| `enemy_id(encounter_id, marker)` (static) | `"<encounter_id>/<last marker name>"`, for example `S1-02/Wave1_Spirit1`. |
| `get_active_encounter_id()`, `get_state(id)`, `is_completed(id)`, `is_checkpoint_activated(id)`, `get_wave_enemy_ids(id, wave_index)`, `get_open_gate_ids()` | Read-outs for the Director; open gates are the COMPLETED Encounters' gates in route order. |

## Dependencies

Each Definition is plain Resource data: relative `NodePath`s, no Nodes, no scene loading, no Director behavior. `EncounterMachine` is Node-free, timer-free and RNG-free (nothing in progression is random): the Stage Director (F10-01) calls `setup` first, ticks it from `_physics_process` only while the tree runs, reports volumes, defeats, Objectives and Checkpoints, and connects the six signals once in its own `setup()`. Refill, commit and the Snapshot belong to CheckpointStore (F8-03), which calls `notify_checkpoint_entered` first and then captures.

## Invariants

| Invariant | Where it holds |
| --- | --- |
| A Wave has markers, one non-empty enemy kind per marker, unique non-empty marker paths, and a non-negative delay. | `WaveDefinition.validate()`, contextualized by the owning Encounter. |
| A Reward has a positive count and non-empty origin marker. | `RewardDefinition.validate()`, contextualized by the owning Encounter. |
| Completion modes have compatible Waves and objectives; the first Wave starts on entry; marker paths are unique across an Encounter; all child data is valid. | `EncounterDefinition.validate()`. |
| Every Checkpoint has an ID, route references, scene-relative marker path, and display name. | `CheckpointDefinition.validate()`. |
| Route IDs and gate/checkpoint IDs are unique; next IDs follow route order; Checkpoint references exist and resume after their activation. | `StageDefinition.validate()`. |
| Entry is accepted only for the next route Encounter, behind its activated Checkpoint; re-entering a trigger never spawns again. | `notify_entered` refusal paths. |
| An Encounter completes exactly once, whatever the order or duplication of reports (bomb kill of the last enemies, repeated defeat reports, all six seal orders). | `notify_enemy_defeated` / `notify_objective` counting and `_complete`'s ACTIVE guard. |
| Completion signals fire in the documented order, each at most once per Encounter until restore or reset. | `_complete`. |
| Restore completes and rewards exactly the route prefix before the resume Encounter, clears queued Waves, and emits no signal. | `restore`. |

## Setup for Astra

Create `.tres` Resources of the appropriate Definition class. Use spawn-marker `NodePath`s relative to `Encounters/<ID>` and checkpoint paths relative to the Stage root. Set `next_id` to the following route entry (empty on the final Encounter); set a resume Encounter's `checkpoint_id` to the Checkpoint ID. Encounter completion and one-time reward behavior remain runtime responsibilities of the Director.

For trunk's F10-01: call `setup` in the Director's `setup()`, connect the six signals there, tick from `_physics_process` while the tree runs, and report `enemy_id` values built from the Definition markers. CP1-B sits inside S1-06, so a Retry from CP1-B restores S1-06 as completed; if `PlayerStart` lies inside S1-01's EntryVolume, call `notify_entered(&"S1-01")` in `start_attempt()` rather than waiting for a `body_entered`.

## Stage 1 content

`content/stages/stage_01/` holds the dev draft (F8-04), every file flagged `metadata/dev = true`: `stage_01.tres` (`StageDefinition`, id `stage_01`), `s1_01.tres` to `s1_07.tres` (one `EncounterDefinition` each, Waves and Rewards as sub-resources) and `cp1_a.tres` / `cp1_b.tres` (`CheckpointDefinition`). The route follows STAGE_DESIGN: S1-01 traversal → S1-02 two waves of three Spirits (`Gate_S1_02`, 5 POWER at `RewardOrigin`) → S1-03 two Sentries with `requires_exit` (`Gate_S1_03`, 1 SHIELD at `ShieldPickup`) → S1-04 three Sentries (`Gate_S1_04`) → S1-05 two mixed waves behind CP1-A (`Gate_S1_05`, 5 POWER) → S1-06 traversal → S1-07 `lantern_guardian` behind CP1-B. Spawn markers are relative to `Encounters/<ID>` and match the scene. Totals: 17 common-enemy markers plus one boss, 10 POWER pickups (exactly Power Level 1 → 3 at 5 per level) and 1 SHIELD. Astra owns the values — the 1.0 s `AFTER_PREVIOUS_WAVE` delay and the checkpoint `display_name`s (`"CP1-A"`, `"CP1-B"`) are the draft's proposals; the structure is the approved design. The draft was produced by a one-off headless script that is not committed: no generator may ever overwrite Astra's tuning.

## Open issues

Stage-entry resources intentionally remain outside `StageDefinition`; `RunState.ENTRY_POWER_LEVEL` and `CombatState.start()` remain their single source. Per-Objective rewards and Wave activation by Seal approach are Stage 2 integration (F12-04+). No tests were written during the sprint (SPRINT "No new tests"); the land gate is the check.
