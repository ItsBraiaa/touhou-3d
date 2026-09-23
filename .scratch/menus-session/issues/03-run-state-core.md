# F2-03 RunState core

Status: done (2026-09-22)
Type: core
parallel-safe: yes
Depends on: F0-02

## Goal

A Node-free `RunState` that owns the Run: Run Mode, stage order, the current Attempt, Active Time and Clear Time accounting with a pause flag, committed statistics, and the run lifecycle signals the Session reacts to. Snapshot contents beyond time and score are added in F8-03; this ticket defines the shape so that later work extends rather than rewrites.

## Read first

- `CONTEXT.md`: Run, Run Mode, Attempt, Retry, Restart, Active Time, Clear Time, Session
- `docs/STAGE_DESIGN.md` "Checkpoint contract" and "Time and score integrity"
- `docs/ENGINEERING_BRIEF.md` Section 4.H
- `docs/PLANEJAMENTO.md` Section 6 (Direct Stage 2 starts at Power Level 2; only settings persist across launches)
- `docs/engineering/CONVENTIONS.md`: "Time and randomness", "Snapshots"

## Deliverables

`scripts/session/run_state.gd`, `class_name RunState extends RefCounted`.

- Enums: `RunMode { CAMPAIGN, DIRECT_STAGE }`, `Phase { IDLE, IN_STAGE, STAGE_COMPLETE, RUN_ENDED }`.
- `start(mode: RunMode, first_stage: StringName)`: Campaign order is `[&"stage_01", &"stage_02"]` starting at `first_stage`; Direct Stage order is `[first_stage]`. Resets everything, `attempt_index = 0`.
- `begin_attempt()`: increments `attempt_index`, zeroes current-attempt Active Time and current-attempt score and graze deltas, unpauses.
- `set_paused(paused: bool)`; `tick_active(delta: float)` accumulates current-attempt Active Time only while `Phase.IN_STAGE` and not paused. It is the adapter's duty to call it from `_physics_process`, and the core refuses anyway when paused.
- `commit_checkpoint()`: folds the current Attempt's Active Time, score, graze, and bombs used into the committed totals for this stage (`committed_active_time`, `committed_score`, ...). Called by the Director on first Checkpoint activation.
- `rollback_attempt()`: discards the current Attempt's uncommitted deltas (used by Retry). `restart_stage()`: discards committed values for the current stage too and returns to the stage-entry values (Restart).
- `add_score(points: int)`, `add_graze(count := 1)`, `note_bomb_used()` affect the current Attempt's deltas.
- `clear_time() -> float` = committed Active Time plus current Attempt Active Time. `stage_result() -> Dictionary` with `clear_time`, `score`, `graze`, `bombs_used`, `mode`, `stage`, `is_final` (true when the last stage of the order completed).
- `complete_stage()`: `Phase.STAGE_COMPLETE`, emits `stage_completed(result)`. `advance()`: next stage in order or `end_run(victory := true)`. `end_run(victory := false)` emits `run_ended(victory)`.
- `starting_power_level() -> int`: 1 for Campaign Stage 1 and Direct Stage 1, 2 for Direct Stage 2; Campaign Stage 2 carries the Power Level over (a parameter the Session passes at `advance()`).
- `capture() -> Dictionary` / `restore(data: Dictionary)` of the committed values and stage position, deep-copied; F8-03 turns this into the `Snapshot` class.
- Signals: `stage_started(stage: StringName)`, `stage_completed(result: Dictionary)`, `run_ended(victory: bool)`, `paused_changed(paused: bool)`.

## Tests required

`tests/unit/session/test_run_state.gd`:

- Campaign: start at stage_01, complete, advance starts stage_02, complete, advance ends the run with victory; `is_final` false then true.
- Direct Stage 2: one stage; `starting_power_level()` is 2; completing it ends with victory and `is_final` true.
- Active Time: 120 ticks of 1/60 give 2.0 s; ticks while paused add nothing; ticks in `IDLE` add nothing.
- Clear Time: commit after 10 s, play 5 s more, `clear_time()` is 15; `rollback_attempt()` makes it 10; `restart_stage()` makes it 0.
- Score and graze follow the same commit and rollback rules; `bombs_used` survives a commit and is rolled back with a failed Attempt.
- `capture()` result is not affected by later mutations of the core (deep copy).
- Signals fire once per transition.

## Out of scope

Snapshot of combat resources and Encounter flags (F8-03), results screen (F11), Power carry-over UI.

## Definition of Done

- Tests green.
- `docs/engineering/menus-session.md` updated with the `RunState` contract.
- Handoff log entry; commit `session: add RunState core`.

## Handoff notes for Astra

None.

## Outcome (2026-09-22)

Delivered test-first as specified, with these additions and differences, each pinned by a test and listed in `docs/engineering/menus-session.md` Open issues:

- **Score is carried, the rest is per stage.** Campaign Stage 2 starts with Stage 1's final score, and Restart there returns to it; Clear Time, Graze and bombs used start at zero in every stage. PLANEJAMENTO Section 6 names only power and score as carried.
- **Only `Phase.IN_STAGE` accepts Attempt changes.** After `complete_stage()` the result is final: late Grazes, commits, rollbacks, restarts and `begin_attempt` do nothing, so replaying a completed Direct Stage (F11) calls `start()` again. `complete_stage`, `advance` and `end_run` are ignored out of phase, so each signal fires once per transition.
- **The Attempt index is per stage** and resets to 0 when `advance()` enters Stage 2.
- **`advance(power_level: int)` takes the Power Level as a required argument**, so the Session cannot silently drop the carry-over.
- **`start()` unpauses**, so a Run ended from the Pause menu does not leak its pause into the next one.
- **Getters instead of public fields:** `get_phase()`, `get_attempt_index()`, `is_paused()`; `committed_*` are `capture()` keys. F2-04 reads score and Graze for the Pause overlay from `stage_result()`.
- `capture()` also records the stage-entry values (`entry_power_level`, `entry_score`), so a Restart after a restore still returns to the right entry score.

Tests: 19 in `tests/unit/session/test_run_state.gd`; suite green at 125; twelve mutations each caught by a named assertion.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/menus-session/issues/03-run-state-core.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
