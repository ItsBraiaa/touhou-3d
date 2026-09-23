# F10-00 Plan the Stage Director feature

Status: done (2026-09-23)
Type: docs
parallel-safe: no
Depends on: F8-04, F9-02

## Goal

Write `.scratch/stage-director/spec.md` and the full tickets for F10: attach the Director to the real `scenes/stages/stage_01.tscn` and make the whole Stage 1 route, gates, checkpoints, retry, and restart work with dev enemies.

## Planned tickets

1. `01-stage-director-adapter`: `stage_director.gd` on `Stage`: loads the `StageDefinition`, validates content, resolves `Encounters/<ID>` roots and their `EntryVolume`, `ExitVolume`, `Spawns/*`, `RewardOrigin`, `ShieldPickup` by relative path, enables Area monitoring once, spawns under `RuntimeActors`, drives `EncounterMachine`, exposes active-Encounter bounds, refuses out-of-order completion (flying over triggers).
2. `02-gate-and-checkpoint-adapters`: `gate.gd` on `Gates/Gate_S1_0N` (disable `BarrierBody` collision, hide `ClosedVisual`, idempotent), `checkpoint.gd` on `Checkpoints/CP1-*` (activation once per Attempt, requires preceding completion, `Respawn` marker), `Environment/PortalLinks/GuardLink1..3` hidden as guards die and reconstructed on restore.
3. `03-retry-restart-flow`: defeat leads to Retry from the latest Checkpoint Snapshot or Restart from Stage Entry; cleanup of `RuntimeActors`, `ProjectileRoot`, locks, timers, queued spawns; respawn facing -Z with no incoming Projectiles; Session and Director responsibilities split as in GUIDE Section 8.
4. `04-stage-01-contract-smoke-test`: headless test that the Stage 1 scene and the Stage 1 content agree (every encounter id, marker path, gate, and checkpoint referenced by content exists in the scene) so a scene regeneration by Astra is caught immediately.

## Read first when planning

- `docs/STAGE_01_HANDOFF.md` entirely
- `docs/STAGE_DESIGN.md` "Checkpoint contract", "Agent implementation contract", Stage 1 table
- `docs/GUIDE.md` Sections 5 "Stages", 6 rows `stage_director.gd`, `checkpoint.gd`, `gate.gd`, 7, 8
- `docs/ENGINEERING_BRIEF.md` Sections 4.G, 4.H
- `.scratch/progression-core/` tickets (the core contracts)

## Definition of Done

- `spec.md` and four ticket files; roadmap rows replaced; commit `plan: write F10 stage director tickets`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/stage-director/issues/00-plan.md, then write the F10 spec and tickets as described. Finish with its Definition of Done and commit.
```

## Outcome (2026-09-23)

The tickets were written in the one-pass planning session (commit "plan: write F4-F14 tickets"): `spec.md`, `01-stage-director-adapter.md`, `02-gate-and-checkpoint-adapters.md`, `03-retry-restart-flow.md`, `04-stage-01-contract-smoke-test.md`. They differ from the planned list above in these ways:

- **01.** It depends on F4-03 too (`Hud.show_threat`). `setup()` takes no seed; `start_attempt(attempt_seed)` does. `check_setup()` lets the Session refuse invalid content before loading. `lantern_guardian` maps to the dev Sentry as a stand-in until F12-03.
- **02.** It depends on F7-02 too, for the bomb-kill-of-the-last-guard test. The Director owns the `CheckpointStore`, and this ticket makes no Session edit.
- **03.** Retry is in place: the Director survives, and the Session re-instances only the ship at `get_respawn_transform()`. Restart keeps F2-04's full reload, so there is no `restart_from_entry()`. `retry_from_checkpoint(player, attempt_seed)` takes two arguments.
- **04.** Parallel-safe, needing only F8-04.
