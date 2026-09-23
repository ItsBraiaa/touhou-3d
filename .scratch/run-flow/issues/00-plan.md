# F11-00 Plan the Run flow feature

Status: done (2026-09-23)
Type: docs
parallel-safe: no
Depends on: F10-03

## Goal

Write `.scratch/run-flow/spec.md` and the full tickets for F11: the Defeat, Results, Retry, Restart, Campaign continuation, and time accounting that close the loop from menu to victory.

## Planned tickets

1. `01-defeat-results-retry-restart-screens`: Defeat overlay with `Layout/RetryLocation` (`Início da fase` or the Checkpoint name), Retry and Menu actions; Results with `TimeValue`, `ScoreValue`, `GrazeValue`, `BombsValue` from `RunState.stage_result()`; Pause score and graze.
2. `02-campaign-continuation-and-direct-stage`: Stage 1 Results `Continuar` loads Stage 2 with Power carry-over; Direct Stage shows `Replay`; final victory heading `Jornada concluída`, Continue and Replay hidden, focus on Menu or Credits; Direct Stage 2 starts at Power Level 2 with two Bombs and one Shield.
3. `03-active-and-clear-time-verification`: tests and a manual protocol proving Active Time excludes pauses and menus, Clear Time rolls back failed Attempts, and a separate uninterrupted-clear measurement exists for the academic five-minute check (recorded in `docs/validation/`).

## Read first when planning

- `docs/GUIDE.md` Section 14 "Runtime text and presentation", Section 7 rows "Player defeated", "Stage completed"
- `docs/STAGE_DESIGN.md` "Time and score integrity"
- `docs/PLANEJAMENTO.md` Sections 2 (five-minute rule), 6
- `.scratch/menus-session/issues/03-run-state-core.md`

## Definition of Done

- `spec.md` and three ticket files; roadmap rows replaced; commit `plan: write F11 run flow tickets`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/run-flow/issues/00-plan.md, then write the F11 spec and tickets as described. Finish with its Definition of Done and commit.
```

## Outcome (2026-09-23)

The tickets were written in the one-pass planning session (commit "plan: write F4-F14 tickets"): `spec.md`, `01-defeat-results-retry-restart-screens.md`, `02-campaign-continuation-and-direct-stage.md`, `03-active-and-clear-time-verification.md`. They differ from the planned list above in these ways:

- **01.** The Defeat retry location is written by F10-03, and 01 verifies it. A final stage completion calls `advance()` at once, so `run_ended(true)` fires once. A `STAGE_RESULT` log line records each clear.
- **02.** Only the Power Level is carried into Stage 2; Power Progress resets (Claude's reading). The Stage 2 final victory is test-driven through `RunState`, because Stage 2 has no gameplay while F12-04 is cut.
- **03.** Stage 1 only; the Stage 2 five-minute check is "not verified (cut)". Any fix it makes stays in `run_state.gd`.
