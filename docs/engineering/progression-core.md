# Progression Definitions, EncounterMachine and CheckpointStore

## Purpose

The progression module owns the authored Stage route as typed Resources, the `EncounterMachine` Rules Core that plays it, and the Checkpoint pair: `Snapshot`, the immutable value object of one recorded point of the Run, and `CheckpointStore`, the Rules Core around it — first activation refills resources, commits the Attempt and records a Snapshot; revisits do nothing; Retry restores the latest Snapshot; Restart discards every Checkpoint and returns to the stage-entry values. Encounter lifecycle (inactive → active → completed), route-ordered entry behind its Checkpoint, Wave scheduling, completion conditions, one-time rewards, Gate opening, Objective and Checkpoint flags, and capture/restore for Retry and Restart — all idempotent. The Stage Director (F10-01) drives the machine and the store and turns their reports into spawns, Gate nodes and Pickups; this module holds no Node and no scene.

## Files

- `scripts/definitions/encounter_definition.gd` (`EncounterDefinition` Resource)
- `scripts/definitions/wave_definition.gd` (`WaveDefinition` Resource)
- `scripts/definitions/reward_definition.gd` (`RewardDefinition` Resource)
- `scripts/definitions/checkpoint_definition.gd` (`CheckpointDefinition` Resource)
- `scripts/definitions/stage_definition.gd` (`StageDefinition` Resource)
- `scripts/progression/encounter_machine.gd` (`EncounterMachine` Rules Core, ADR-0001)
- `scripts/progression/snapshot.gd` (`Snapshot` value object, F8-03)
- `scripts/progression/checkpoint_store.gd` (`CheckpointStore` Rules Core, ADR-0001, F8-03)
- `content/stages/stage_01/*.tres` (Stage 1 dev draft; values are Astra's)
- `content/stages/stage_02/*.tres` (Stage 2 dev draft; values are Astra's)

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

## Snapshot and CheckpointStore contract

`Snapshot` (F8-03) is the CONVENTIONS "Snapshots" value object: a deep copy of the three core captures beside the Checkpoint id, holding only primitives, packed arrays and Dictionaries of those — never a Node or a live core. `CheckpointStore` owns the rules around it (STAGE_DESIGN "Checkpoint contract").

### Snapshot

| Method | Effect |
| --- | --- |
| `Snapshot.capture_from(combat, run, encounters, checkpoint_id := &"")` (static) | A new Snapshot keeping `duplicate(true)` copies of `CombatState.capture()`, `RunState.capture()` and `EncounterMachine.capture()`, with the Checkpoint id (`&""` at Stage Entry). Nothing the cores do later changes it. |
| `restore_into(combat, run, encounters)` | `combat.restore`, then `run.restore`, then `encounters.restore`, each with a fresh deep copy, so one Snapshot restores any number of times and restoring never changes it. |
| `get_checkpoint_id()`, `get_stage_id()`, `get_resume_encounter_id()` | The Checkpoint id (`&""` at Stage Entry), the Stage from `stage_order[stage_index]`, and the resume Encounter from the Encounters slice. |
| `to_dict()` / `Snapshot.from_dict(data)` (static) | `{checkpoint_id, combat, run, encounters}`, deep-copied both ways; for tests and equality. |

### CheckpointStore

| Method | Effect |
| --- | --- |
| `activate(checkpoint_id, combat, run, encounters) -> bool` | False, changing nothing, while `combat` is defeated or paused (a refill would be silently ignored), or when `notify_checkpoint_entered` refuses (the preceding Encounter is not complete, or it was already activated — revisiting never refills again). Otherwise: `combat.refill()` first (before anything is recorded, STAGE_DESIGN), then `run.commit_checkpoint()`, then `Snapshot.capture_from(..., checkpoint_id)` as the latest. The bombs-used statistic survives the refill: it is committed before the record, and `refill()` never touches it. |
| `latest() -> Snapshot` | Null until a Checkpoint is activated in this stage (Stage Entry); Retry then means Restart. |
| `latest_checkpoint_id() -> StringName` | The latest Snapshot's Checkpoint, for Defeat's retry location; `&""` before any Checkpoint activated. |
| `retry_into(combat, run, encounters) -> bool` | False and nothing changes while `latest()` is null — the caller Restarts instead (PLANEJAMENTO Section 6: a death before the first intermediate Checkpoint restarts the stage). Otherwise restores the latest Snapshot. Never calls `refill()`: the Snapshot was recorded after its Checkpoint's refill, so the restore already brings back full Health, the Shield and two Bombs, and a refill on a still-defeated or still-paused core would be dropped silently. |
| `restart_into(combat, run, encounters)` | `reset()`, then `run.restart_stage()`, then `combat.start(run.starting_power_level())`, then `encounters.reset()`: stage-entry values and no Checkpoint left. F10 never calls it (Restart keeps F2-04's full stage reload); it is the core-level proof that Restart differs from Retry, and the reload-free Restart for later. |
| `reset()` | Forgets every Snapshot (Restart, stage load). |

### The call sequence F10-03 follows

- **Checkpoint activation** (Director, on a Checkpoint Area's first entry): `store.activate(id, combat, run, encounters)`. A false return changes nothing and the Area stays armed for a later, valid entry.
- **Retry** (Defeat screen): when `store.retry_into(combat, run, encounters)` returns true, then `run.begin_attempt()`, `combat.set_paused(false)`, and the scene-side removal of the failed Attempt's actors, Projectiles, Pickups, locks and queued spawns; respawn at the resume Encounter, facing the next destination. When it returns false, Restart instead.
- **Restart** (Defeat or Pause screen): the F2-04 full stage reload, which rebuilds the Director, its fresh `CheckpointStore` (`latest()` null) and the machine; `run.begin_attempt()` and `combat.set_paused(false)` afterwards.

The Director owns one `CheckpointStore`, created in its `setup()`, and it survives Retry: the Attempt that follows `retry_into` keeps the latest Snapshot. `restart_into` stays for a reload-free Restart later.

## Dependencies

Each Definition is plain Resource data: relative `NodePath`s, no Nodes, no scene loading, no Director behavior. `EncounterMachine` is Node-free, timer-free and RNG-free (nothing in progression is random): the Stage Director (F10-01) calls `setup` first, ticks it from `_physics_process` only while the tree runs, reports volumes, defeats, Objectives and Checkpoints, and connects the six signals once in its own `setup()`. `Snapshot` and `CheckpointStore` are equally Node-free: the store reads the three cores through their real capture shapes and never edits them, and it calls `notify_checkpoint_entered` first, then refills, commits and captures.

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
| A Checkpoint refills once per activation lineage: revisits and replayed triggers never refill again. | `CheckpointStore.activate` refusals + `EncounterMachine.notify_checkpoint_entered` first-activation flag. |
| Failed Attempts cannot farm score or inflate the Clear Time: a Retry rolls the current Attempt back to the latest committed values. | `CheckpointStore.retry_into` → `RunState.restore` (committed slices only) and the caller's `begin_attempt()`. |
| Restarting a stage differs from retrying a Checkpoint: no Snapshot survives a Restart and the stage returns to its entry values. | `CheckpointStore.restart_into` / `reset()`, and F2-04's full stage reload in F10. |

## Setup for Astra

Create `.tres` Resources of the appropriate Definition class. Use spawn-marker `NodePath`s relative to `Encounters/<ID>` and checkpoint paths relative to the Stage root. Set `next_id` to the following route entry (empty on the final Encounter); set a resume Encounter's `checkpoint_id` to the Checkpoint ID. Encounter completion and one-time reward behavior remain runtime responsibilities of the Director.

For trunk's F10-01: call `setup` in the Director's `setup()`, connect the six signals there, tick from `_physics_process` while the tree runs, and report `enemy_id` values built from the Definition markers. F8-03 adds: create the `CheckpointStore` in the same `setup()` (it survives Retry), call `store.activate(id, combat, run, encounters)` on a Checkpoint Area's entry, and follow the "The call sequence F10-03 follows" section for Retry and Restart. CP1-B sits inside S1-06, so a Retry from CP1-B restores S1-06 as completed; if `PlayerStart` lies inside S1-01's EntryVolume, call `notify_entered(&"S1-01")` in `start_attempt()` rather than waiting for a `body_entered`.

## Stage 1 content

`content/stages/stage_01/` holds the dev draft (F8-04), every file flagged `metadata/dev = true`: `stage_01.tres` (`StageDefinition`, id `stage_01`), `s1_01.tres` to `s1_07.tres` (one `EncounterDefinition` each, Waves and Rewards as sub-resources) and `cp1_a.tres` / `cp1_b.tres` (`CheckpointDefinition`). The route follows STAGE_DESIGN: S1-01 traversal → S1-02 two waves of three Spirits (`Gate_S1_02`, 5 POWER at `RewardOrigin`) → S1-03 two Sentries with `requires_exit` (`Gate_S1_03`, 1 SHIELD at `ShieldPickup`) → S1-04 three Sentries (`Gate_S1_04`) → S1-05 two mixed waves behind CP1-A (`Gate_S1_05`, 5 POWER) → S1-06 traversal → S1-07 `lantern_guardian` behind CP1-B. Spawn markers are relative to `Encounters/<ID>` and match the scene. Totals: 17 common-enemy markers plus one boss, 10 POWER pickups (exactly Power Level 1 → 3 at 5 per level) and 1 SHIELD. Astra owns the values — the 1.0 s `AFTER_PREVIOUS_WAVE` delay and the checkpoint `display_name`s (`"CP1-A"`, `"CP1-B"`) are the draft's proposals; the structure is the approved design. The draft was produced by a one-off headless script that is not committed: no generator may ever overwrite Astra's tuning.

## Stage 2 content

`content/stages/stage_02/` holds the dev draft (F12-04), every file flagged `metadata/dev = true`: `stage_02.tres` (id `stage_02`), `s2_01.tres` to `s2_07.tres` and `cp2_a.tres` / `cp2_b.tres`, same layout as Stage 1. The route follows STAGE_DESIGN: S2-01 two Spirits with `requires_exit` (`Gate_S2_01`) → S2-02 two mixed waves (`Gate_S2_02`, 2 POWER, 1 SHIELD) → S2-03 three storm seals (`Gate_S2_03`, 3 POWER) → S2-04 Tempest Sentinel behind CP2-A (`Gate_S2_04`, 1 SHIELD) → S2-05 two mixed waves (`Gate_S2_05`, 2 POWER) → S2-06 traversal → S2-07 Storm Guardian behind CP2-B. Totals: 20 common-enemy markers plus two bosses, 7 POWER pickups and 2 SHIELD pickups; Direct Stage 2 starts at Power 2, so the 2 ledge and 3 seal pickups reach Power 3 before the miniboss. The scratch run that wrote the files also cross-checked every marker, reward origin, gate and checkpoint against `stage_02.tscn`, including the Seals' `seal_id` and `guard_spawn` metadata; no test file was committed (sprint "No new tests").

Three schema readings the Director needs:

- **Per-Seal rewards.** The schema has no per-Objective reward, so each Seal's Power Pickup is a separate S2-03 `RewardDefinition` whose `origin_marker` is `Seals/SealN/RewardOrigin`. The Director (F12-05) spawns each one when that Seal is destroyed, not on Encounter completion.
- **Guard engagement.** Content has no approach-activated Wave: all three guard pairs are ON_ENTRY waves, and F12-05 keeps each pair passive until its Seal's approach volume or guard shot engages it.
- **Boss kinds.** `tempest_sentinel` and `storm_guardian` are new Wave kinds. F12-05 maps them to a stand-in; F12-06 and F12-07 map them to the real boss prefabs.

## Open issues

Stage-entry resources intentionally remain outside `StageDefinition`; `RunState.ENTRY_POWER_LEVEL` and `CombatState.start()` remain their single source. Per-Objective rewards and Wave activation by Seal approach are Stage 2 integration (F12-04+). No tests were written during the sprint (SPRINT "No new tests"); the land gate is the check.
