# F8-02 EncounterMachine core

Status: todo
Type: core
parallel-safe: yes
Depends on: F8-01
Lane: glm-b

## Goal

A Node-free `EncounterMachine` that owns Encounter progression for one loaded Stage, as STAGE_DESIGN's "Agent implementation contract" asks. Each Encounter is inactive, active or completed; entry is accepted only in route order and behind its Checkpoint; Waves are scheduled; completion conditions are checked; Gate opening and one-time rewards are reported. Duplicate callbacks are idempotent, and Retry state is rebuilt from a capture. Enemies report outcomes and this core decides progression (ENGINEERING_BRIEF 4.G). The Director (F10-01) turns its signals into spawns, Gates and pickups.

## Read first

- `docs/STAGE_DESIGN.md` "Shared encounter rules", Stage 1 table, "Checkpoint contract", "Agent implementation contract"
- `docs/STAGE_01_HANDOFF.md` "Checkpoints" (CP1-B at Z -450 lies inside S1-06, Z -430 to -457; the next combat entry is 15 units past each Checkpoint)
- `docs/ENGINEERING_BRIEF.md` Sections 4.G and 8 ("Idempotent encounter completion and all seal orders")
- `.scratch/progression-core/issues/01-definition-schemas-and-content-validation.md` and its Outcome; `docs/engineering/progression-core.md`
- `docs/engineering/CONVENTIONS.md` "Architecture rules", "Snapshots"

## Files

- **Creates:** `scripts/progression/encounter_machine.gd`, `tests/unit/progression/test_encounter_machine.gd`.
- **Edits:** none.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F8-02 row), `docs/HANDOFF_LOG.md`, `docs/engineering/progression-core.md` (EncounterMachine contract).
- **Must not touch:** `scripts/definitions/*` (a schema gap is a dependency note in the Outcome, not an edit), `scripts/session/run_state.gd`, `scripts/combat/combat_state.gd`, `content/`.
- **Conflicts with:** none. F8-04 runs alongside on disjoint files.

## Deliverables

`scripts/progression/encounter_machine.gd`, `class_name EncounterMachine extends RefCounted`, with no Node, timer or RNG (nothing in progression is random).

- `enum State { INACTIVE, ACTIVE, COMPLETED }`. `static func enemy_id(encounter_id: StringName, marker: NodePath) -> StringName` returns `"<encounter_id>/<last name of marker>"`, for example `&"S1-02/Wave1_Spirit1"`.
- `setup(stage: StageDefinition)`: asserts `stage.validate()` is empty; every Encounter INACTIVE, no Checkpoint activated.
- `notify_entered(encounter_id) -> bool`: activates only the next Encounter, meaning the first one not COMPLETED, with every earlier one COMPLETED and its `checkpoint_id` (if any) activated. Emits `encounter_activated(id)`, then schedules every ON_ENTRY wave; a wave with `delay` 0 is requested inside this call through `wave_requested(id, wave_index)`. Returns false with no signal when the Encounter is out of order, behind an inactive Checkpoint, already ACTIVE or COMPLETED (re-entering a trigger never spawns again), or unknown.
- `notify_exited(encounter_id)`: only while ACTIVE. TRAVERSAL completes; with `requires_exit` it latches the exit and completes if the enemy or objective condition already holds. Otherwise ignored, so the S1-07 ExitVolume never completes the boss.
- `notify_enemy_defeated(enemy_id, encounter_id)`: counts an enemy once, only while its Encounter is ACTIVE and only if it belongs to a wave already requested (`get_wave_enemy_ids`). Duplicates and strangers are ignored. When every enemy of wave i is defeated, the next AFTER_PREVIOUS_WAVE wave is scheduled after its `delay`. ALL_REQUIRED_ENEMIES completes when every wave has been requested and every enemy counted, plus the exit latch when `requires_exit`. So a Bomb that defeats the last three in one tick, with repeated reports, completes exactly once.
- `notify_objective(objective_id) -> bool`: records the flag once, only when the ACTIVE Encounter lists it; OBJECTIVES completes when every listed id is recorded, in any order.
- `notify_checkpoint_entered(checkpoint_id) -> bool`: true only on the first activation, and only when its `after_encounter_id` is COMPLETED. Records the flag. Refill and snapshot belong to `CheckpointStore` (F8-03), which calls this first.
- `tick(delta)`: counts down scheduled waves of the ACTIVE Encounter and requests each one when due. The Director calls it only while the tree runs.
- Completion emits, in this order: `gate_opened(gate_id)` if set, `rewards_requested(id)` if the Encounter has rewards and they were not requested before, `encounter_completed(id)`, then `stage_cleared()` after the last Encounter. Each fires at most once per Encounter until a `restore` or `reset`.
- Getters: `get_active_encounter_id() -> StringName` (`&""` when none; at most one is ACTIVE by the ordering rule), `get_state(id)`, `is_completed(id)`, `is_checkpoint_activated(id)`, `get_wave_enemy_ids(encounter_id, wave_index) -> Array[StringName]`, `get_open_gate_ids() -> Array[StringName]` (gates of COMPLETED Encounters, for rebuilding the Gates after a restore).
- `capture() -> Dictionary`: a new Dictionary of primitives with `completed`, `rewarded`, `objectives` and `checkpoints` (each a `PackedStringArray`), plus `resume_encounter_id` (String). That last one is the resume Encounter of the latest activated Checkpoint in route order, or the first Encounter.
- `restore(data)`: every Encounter before `resume_encounter_id` becomes COMPLETED and rewarded ("Previous content remains complete"), including an Encounter that was still ACTIVE at capture, such as S1-06 at CP1-B. Every other Encounter becomes INACTIVE. The flags come back from the capture. Scheduled waves, counted enemies and exit latches are cleared (queued-spawn cancellation, core side). No signal is emitted, and `data` is not kept.
- `reset()`: back to `setup` state (Restart).

## Tests required

`tests/unit/progression/test_encounter_machine.gd`, with a code-built fixture shaped like Stage 1: a traversal, a two-wave Encounter with a delay, a `requires_exit` Encounter, a Checkpoint-guarded Encounter, a traversal holding a Checkpoint, a three-objective Encounter and a one-enemy final Encounter.

- Order and triggers: `test_first_encounter_activates_on_entry_and_requests_its_first_wave`, `test_entry_out_of_order_is_refused`, `test_reentering_a_completed_encounter_spawns_nothing`, `test_entry_waits_for_the_guarding_checkpoint`.
- Waves: `test_second_wave_waits_for_the_first_to_be_defeated_and_its_delay`.
- Idempotent completion: `test_duplicate_defeat_callbacks_count_once`, `test_bomb_kill_of_the_last_enemy_advances_exactly_once`, `test_defeats_outside_requested_waves_are_ignored`, `test_rewards_are_requested_once`, `test_last_encounter_clears_the_stage_once`.
- Conditions: `test_traversal_completes_on_exit_only_while_active`, `test_requires_exit_completes_in_either_order`, `test_exit_volume_does_not_complete_an_enemy_encounter`, `test_all_six_objective_orders_complete_once` (every permutation of three objective ids completes once, and a repeat does nothing).
- Signal order: `test_completion_opens_gate_then_requests_rewards_then_completes`.
- Checkpoints: `test_checkpoint_needs_its_preceding_encounter_and_activates_once`.
- Restore: `test_capture_is_not_changed_by_later_mutations`, `test_restore_completes_every_encounter_before_the_resume_point`, `test_restore_cancels_scheduled_waves` (a restore during a pending delay, then 10 s of ticks, requests nothing), `test_restore_emits_no_signals`, `test_reset_returns_to_stage_entry`.

## Out of scope

Refill, commit and snapshot (F8-03); Seal guard activation and the shield rule (F9-03, `SealRules`); per-Objective rewards and Seal-approach Wave activation (Stage 2 integration, cut with F12-04); marker resolution, spawning, Gate nodes, PortalLinks, hostile Projectile clears on gate opening or Checkpoint activation, and score for defeats (all F10-01/02).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR` in the output; the ENGINEERING_BRIEF Section 8 invariants "idempotent encounter completion and all seal orders" and "bomb kill of the last guard/enemy advances exactly once" (STAGE_DESIGN acceptance) are named tests.
- No Error-level warnings. `docs/engineering/progression-core.md` updated with the contract, the signal order and the invariant table.
- Handoff log entry; `Status: done` with an Outcome; ROADMAP row.
- One commit: `progression: add EncounterMachine core`.

## Handoff notes for Astra

None for scenes. For F10, note that CP1-B sits inside S1-06, so a Retry from CP1-B restores S1-06 as completed. If `PlayerStart` lies inside S1-01's EntryVolume, the Director should call `notify_entered(&"S1-01")` in `start_attempt()` rather than wait for a `body_entered`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/progression-core/issues/02-encounter-machine-core.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
