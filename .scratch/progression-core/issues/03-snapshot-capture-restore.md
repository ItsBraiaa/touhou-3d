# F8-03 Snapshot and CheckpointStore

Status: todo
Type: core
parallel-safe: yes
Depends on: F8-02, F4-01
Lane: oc-b
Model: GPT 5.6 Luna (fallback DeepSeek V4.1 Flash)

## Goal

The STAGE_DESIGN "Checkpoint contract" in two Node-free classes. `Snapshot` is an immutable, deep copy of the Run at Stage Entry or a Checkpoint. `CheckpointStore` holds the rules around it: a first activation refills resources, commits the Attempt and records a Snapshot; revisits do nothing; Retry restores the latest Snapshot; Restart discards every Checkpoint and returns to the stage-entry values. Both sit on the cores that already exist and use their real capture shapes. This ticket closes ENGINEERING_BRIEF Section 8's "deep checkpoint snapshots, resource restoration, queued-spawn cancellation, and statistics rollback".

## Read first

- `docs/STAGE_DESIGN.md` "Checkpoint contract" (activation, restore defaults, the retry table, "Time and score integrity") and the acceptance checks
- `docs/ENGINEERING_BRIEF.md` Section 4.H; `CONTEXT.md` Checkpoint, Attempt, Retry, Restart, Snapshot, Restore, Clear Time
- `docs/engineering/CONVENTIONS.md` "Snapshots"
- `scripts/combat/combat_state.gd` and `docs/engineering/combat-hud.md` "Snapshot slice" (the **real** API, see below)
- `scripts/session/run_state.gd` and `docs/engineering/menus-session.md` "RunState contract"
- `.scratch/progression-core/issues/02-encounter-machine-core.md` and its Outcome

## Files

- **Creates:** `scripts/progression/snapshot.gd`, `scripts/progression/checkpoint_store.gd`, `tests/unit/progression/test_snapshot.gd`, `tests/unit/progression/test_checkpoint_store.gd`.
- **Edits:** none. The store reads the other cores and never edits them. If a capture shape has to change, record it as a dependency note in the Outcome.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F8-03 row), `docs/HANDOFF_LOG.md`, `docs/engineering/progression-core.md` (Snapshot and CheckpointStore contract).
- **Must not touch:** `scripts/combat/combat_state.gd`, `scripts/session/run_state.gd`, `scripts/progression/encounter_machine.gd`, `scripts/session/game_session.gd` (wiring is F10-02/F10-03).
- **Conflicts with:** none. It uses the F8-02 file read-only.

## Deliverables

### The real collaborator API (F4-01 and F2-03, already built)

- `CombatState`: `start(power_level: int, power_progress := 0)` (stage entry, clears defeat, unpauses); `refill()`, which gives Health 100, the Shield and 2 Bombs but **is ignored unless live** (not paused and not defeated); `capture() -> {health, has_shield, bombs, power_level, power_progress}`; `restore(data)`, which clears defeat and Invulnerability, treats the bomb button as held and **leaves the pause flag**; `is_defeated()`, `is_paused()`, and the getters.
- `RunState`: `commit_checkpoint()`, `restart_stage()`, `starting_power_level()`, and `capture()` with keys `mode`, `stage_order` (an `Array[StringName]`), `stage_index`, `entry_power_level`, `entry_score`, `committed_active_time`, `committed_score`, `committed_graze` and `committed_bombs_used`. Uncommitted values are not in it. `restore(data)` puts the stage in play with nothing uncommitted and leaves the Attempt count and pause alone. Every Attempt call is ignored outside `Phase.IN_STAGE`.

### `Snapshot`, `class_name Snapshot extends RefCounted`

- `static func capture_from(combat: CombatState, run: RunState, encounters: EncounterMachine, checkpoint_id: StringName = &"") -> Snapshot` keeps `duplicate(true)` copies of the three `capture()` results.
- `restore_into(combat, run, encounters)` calls `combat.restore`, then `run.restore`, then `encounters.restore`, each with a fresh deep copy, so the same Snapshot can be restored many times.
- Getters: `get_checkpoint_id()` (`&""` at stage entry), `get_stage_id()` (from `stage_order[stage_index]`), `get_resume_encounter_id()`.
- `to_dict() -> Dictionary` returns a deep copy `{checkpoint_id, combat, run, encounters}`. `static func from_dict(data) -> Snapshot` deep-copies its input. No Node and no live core is ever referenced (CONVENTIONS "Snapshots").

### `CheckpointStore`, `class_name CheckpointStore extends RefCounted`

- `activate(checkpoint_id, combat, run, encounters) -> bool` returns false, changing nothing, when `combat.is_defeated()` or `combat.is_paused()` (refill would be ignored) or when `encounters.notify_checkpoint_entered(checkpoint_id)` refuses (the preceding Encounter is not complete, or it was already activated). Otherwise it calls `combat.refill()`, then `run.commit_checkpoint()`, then records `Snapshot.capture_from(..., checkpoint_id)` as the latest, and returns true. The refill comes before the record (STAGE_DESIGN), and the bombs-used statistic survives it.
- `latest() -> Snapshot` is null until a Checkpoint is activated in this stage (stage entry). `latest_checkpoint_id() -> StringName` feeds Defeat's retry location.
- `retry_into(combat, run, encounters) -> bool` returns false and changes nothing when `latest()` is null: the caller Restarts instead (PLANEJAMENTO Section 6, "before any intermediate checkpoint, it restarts the stage"). Otherwise it restores the latest Snapshot. It does **not** call `refill()`: the Snapshot was recorded after the refill, so the restore already brings back full Health, the Shield and 2 Bombs, while a `refill()` on a still-paused core would be dropped silently.
- `restart_into(combat, run, encounters)` calls `reset()`, `run.restart_stage()`, `combat.start(run.starting_power_level())` and `encounters.reset()`.
- `reset()` forgets every Snapshot (Restart, stage load).
- F10's split, from its tickets: the Director owns one `CheckpointStore`, created in its `setup`, and survives Retry, while Restart keeps F2-04's full stage reload. So F10 may never call `restart_into`. It stays here as the core-level proof that Restart differs from Retry, and for a reload-free Restart later.
- The caller (F10-03) then calls `run.begin_attempt()` and `combat.set_paused(false)`, and removes actors, Projectiles, Pickups, locks and queued spawns on the scene side.

## Tests required

`tests/unit/progression/test_snapshot.gd`:

- `test_snapshot_is_not_changed_by_later_mutations`: mutate all three cores after capture; `to_dict()` is unchanged.
- `test_to_dict_returns_a_copy`: mutating the returned Dictionary, including nested `stage_order` and `completed`, leaves the Snapshot unchanged.
- `test_from_dict_round_trips`, and `test_restore_can_be_applied_twice`.
- `test_snapshot_holds_the_checkpoint_contract_fields`: Power Level and Power Progress, score, Graze, committed Active Time, bombs used, stage id, resume Encounter, and completed Encounter and objective flags.

`tests/unit/progression/test_checkpoint_store.gd`, using the real cores and a fixture shaped like Stage 1 (CP-A after the portal, CP-B inside the sanctuary traversal):

- Refill: `test_first_activation_refills_before_recording` (Health 40, no Shield, 0 Bombs become 100, Shield, 2 in the Snapshot) and `test_refill_keeps_the_bombs_used_statistic`.
- Revisits: `test_revisiting_a_checkpoint_does_not_refill`, `test_checkpoint_before_its_encounter_is_refused`, `test_activation_is_refused_while_defeated_or_paused`.
- Statistics rollback: `test_retry_rolls_back_the_failed_segment` (commit at 10 s with score 300, Graze 4 and 1 bomb; play on to 15 s, 500, 7, 2; then Retry and `begin_attempt()` give 10, 300, 4, 1) and `test_failed_attempts_cannot_farm_score`.
- Resource restoration: `test_retry_restores_full_resources_and_saved_power` (Power 1 with progress 3 at the Checkpoint, level 2 at death, level 1 progress 3 after Retry, Health 100, Shield, 2 Bombs, not defeated).
- `test_retry_uses_the_latest_checkpoint`; `test_retry_before_any_checkpoint_is_refused`.
- `test_restart_differs_from_retry` (Restart: `latest()` null, every Encounter inactive, Clear Time 0, entry Power Level and score); `test_restart_after_a_checkpoint_discards_it`.
- `test_retry_cancels_queued_spawns` (a Retry during a pending wave delay, then ticks, requests no wave).
- `test_death_after_the_miniboss_restores_the_earlier_checkpoint`: a code-built fixture with Stage 2's shape (CP2-A resumes the miniboss, CP2-B resumes the final boss). Dying after the miniboss but before CP2-B resumes at the miniboss. This pins STAGE_DESIGN's rule even though Stage 2 content is cut.

## Out of scope

Scene-side cleanup, respawn at `Respawn`, Checkpoint Areas, Defeat and Retry UI (F10-02, F10-03, F11-01); persistence across launches (never: checkpoints are session-only); Stage 2 content.

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR` in the output. Named tests cover ENGINEERING_BRIEF Section 8 "deep checkpoint snapshots, resource restoration, queued-spawn cancellation, statistics rollback" and Section 4.H "failed attempts cannot farm score", "restart differs from retry", "replaying a trigger does not refill".
- No Error-level warnings. `docs/engineering/progression-core.md` updated with both contracts and the Retry and Restart call sequence F10-03 follows.
- Handoff log entry; `Status: done` with an Outcome; ROADMAP row.
- One commit: `progression: add Snapshot and CheckpointStore`.

## Handoff notes for Astra

None for scenes. Checkpoints are session-only; the refill happens once per Checkpoint per Attempt lineage, exactly as STAGE_DESIGN approves.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/progression-core/issues/03-snapshot-capture-restore.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
