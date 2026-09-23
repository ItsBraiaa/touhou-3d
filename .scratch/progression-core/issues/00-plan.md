# F8-00 Plan the Progression cores and content feature

Status: done (2026-09-23)
Type: docs
parallel-safe: no
Depends on: F4-01, F2-03 (can start before F7 is finished; its tickets are Node-free)

## Goal

Write `.scratch/progression-core/spec.md` and the full tickets for F8: the Definition schemas, the `EncounterMachine`, the `Snapshot`, and the Stage 1 content draft.

## Planned tickets

1. `01-definition-schemas-and-content-validation` (parallel-safe): `scripts/definitions/`: `EncounterDefinition` (id, next id, completion condition enum: traversal, all required enemies, objectives; waves; rewards; gate id; checkpoint id; required objective ids), `WaveDefinition` (enemy type, spawn marker relative paths such as `Spawns/Wave1_Spirit1`, activation rule: on entry or after previous wave), `RewardDefinition` (kind, count, origin marker path), `PatternDefinition`, `AttackDefinition`, `BossDefinition`, `StageDefinition` (ordered encounter ids, checkpoints, entry values). Each has `validate()`; a test loads every `.tres` under `content/`.
2. `02-encounter-machine-core` (parallel-safe): inactive, active, completed states; wave scheduling; completion conditions; Gate open events; one-time rewards; Objective flags and Seal logic hooks; idempotent duplicate death callbacks; bomb kill of the last enemy advances exactly once; injected RNG; signals for the Director.
3. `03-snapshot-capture-restore` (parallel-safe): `Snapshot` value object per CONVENTIONS "Snapshots" (deep copies), `capture()` and `restore()` across `CombatState`, `RunState`, `EncounterMachine`; refill rules (first activation and Retry restore full Health, one Shield, two Bombs; revisits do not); queued spawn cancellation contract; statistics rollback tests from STAGE_DESIGN "Checkpoint contract".
4. `04-stage-01-content-draft`: `content/stages/stage_01/*.tres` transcribed from STAGE_DESIGN.md S1-01 to S1-07 and the CP1-A, CP1-B table, marked dev in the handoff log for Astra to tune; validation test green.

## Read first when planning

- `docs/adr/0003-typed-resources-for-authored-content.md`
- `docs/STAGE_DESIGN.md` entirely (shared rules, both stage tables, checkpoint contract, agent implementation contract)
- `docs/STAGE_01_HANDOFF.md` (actual marker names and Z ranges)
- `docs/GUIDE.md` Section 8
- `docs/ENGINEERING_BRIEF.md` Sections 4.G, 4.H, 8
- `CONTEXT.md` Run and progression terms

## Definition of Done

- `spec.md` and four ticket files; roadmap rows replaced; commit `plan: write F8 progression core tickets`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/progression-core/issues/00-plan.md, then write the F8 spec and tickets as described. Finish with its Definition of Done and commit.
```

## Outcome (2026-09-23)

The four tickets and `spec.md` were written in the one-pass planning session (commit "plan: write F4-F14 tickets"), not in a session of their own: `01-definition-schemas-and-content-validation.md`, `02-encounter-machine-core.md`, `03-snapshot-capture-restore.md`, `04-stage-01-content-draft.md`, all parallel-safe. Deviations from the planned list above:

- `PatternDefinition` moved to F5-04, and `AttackDefinition` and `BossDefinition` to F12-01. F8-01 adds `CheckpointDefinition`.
- `WaveDefinition` holds one enemy kind per marker (`enemy_kinds`), because S1-05's Waves are mixed. `EncounterDefinition` gains `requires_exit` (S1-03, S2-01). `StageDefinition` carries no entry resources: `RunState` and `CombatState.start()` stay their source.
- The EncounterMachine takes no RNG, since nothing in progression is random. Seal logic is F9-03's `SealRules`; the machine only records Objectives.
- F8-03 is built on the real F4-01 `CombatState` (`start`, `refill`, `capture`/`restore`), so Retry restores the refilled Snapshot rather than calling `refill()`. `restart_into()` was added.
