# F11-03 Active Time and Clear Time verification

Status: todo
Type: test
parallel-safe: no (drives the whole Session headless; runs after every Session edit it verifies)
Depends on: F11-02
Lane: path
Model: Claude Opus 5.5, solo

> **Sprint note:** Stage 2 is reinstated, so item 5 is no longer "not verified (cut)":
> - If F12-07 has landed, measure Stage 2 with this protocol.
> - If it has not, record "pending F12-07" and leave the measurement to F14-02's human pass. Do not wait for F12-07.
>
> The four worktrees share one `user://`, so any test here that writes under `user://` uses a per-process file name.

## Goal

This ticket proves, through the real Session, the time rules the academic delivery depends on:

- Active Time counts only unpaused gameplay. Pause, Options from Pause, Defeat, Results and the menus add nothing.
- Clear Time is the committed time through the last Checkpoint plus the current Attempt, so a Retry rolls back the failed segment and a Restart zeroes it.
- Each stage of a Campaign accounts for its own Clear Time.

It also writes and runs the manual protocol for STAGE_DESIGN's "separate uninterrupted-clear measurement for the academic duration check". An uninterrupted clear is one that ends with `attempt=1` on the `STAGE_RESULT` line (F11-01), so its Clear Time is its total Active Time. The protocol records starting power, bombs used, Checkpoints retried and the measured time, as STAGE_DESIGN asks.

## Read first

- `docs/STAGE_DESIGN.md` "Time and score integrity".
- `docs/PLANEJAMENTO.md` Section 2: the five-minute rule is Stage 2's. Exclude menus, pauses, repeated deaths and artificial waiting, and measure a normal clear and an efficient clear.
- `docs/ENGINEERING_BRIEF.md` Section 8 "Manual and integration checks".
- `docs/engineering/menus-session.md` "RunState contract", `docs/engineering/run-flow.md` (F11-01, F11-02), `docs/engineering/stage-director.md` "Retry and Restart".
- `docs/engineering/CONVENTIONS.md` "Time and randomness".

## Files

- **Creates:** `tests/scene/test_time_accounting.gd`, `docs/validation/clear-time.md`.
- **Edits:** `scripts/session/run_state.gd` and `tests/unit/session/test_run_state.gd`, only to fix a defect these tests expose, with a regression unit test. Nothing else.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F11-03 row.
  - `docs/HANDOFF_LOG.md`: one entry.
  - `docs/engineering/run-flow.md`: a "Time accounting evidence" section with the invariant-to-test table.
- **Must not touch:** `scripts/session/game_session.gd` (not in this ticket's slice; a Session defect is recorded as a follow-up for the user, and the ticket becomes `blocked` if it breaks a rule), `stage_director.gd`, `combat_state.gd`, and every scene and content file.
- **Conflicts with:** `run_state.gd`, only if a fix is needed; no other open ticket edits it.

## Deliverables

### Automated tests

`tests/scene/test_time_accounting.gd` runs headless on `main.tscn`, ticking physics frames at the default 60 Hz and comparing times with a tolerance of one tick.

- `test_active_time_counts_only_unpaused_play`: 60 ticks give 1.0 s. 60 ticks paused add nothing, and 60 ticks with Options open from Pause add nothing.
- `test_defeat_screen_adds_no_active_time`
- `test_results_screen_adds_no_active_time`
- `test_main_menu_and_stage_select_add_no_active_time`
- `test_retry_rolls_back_the_failed_segment`: commit at CP1-A after T1, play T2, die, Retry. `clear_time()` is T1; play T3 and it is T1 + T3.
- `test_restart_zeroes_clear_time`, and after a Checkpoint too.
- `test_campaign_stage_2_clear_time_starts_at_zero`, with the score carried.
- `test_uninterrupted_clear_time_equals_total_active_time`: with no Retry, the result shows `attempt=1` and Clear Time equals the sum of the ticks.
- `test_failed_attempts_do_not_inflate_clear_time`: three defeats before CP1-A, then a clear. Clear Time equals the last Attempt's Active Time (ENGINEERING_BRIEF 4.H).

### Manual protocol and record: `docs/validation/clear-time.md`

1. **Environment.** Host, date, build (editor or exported), input device, and whether the input was physical or scripted. A simulated gamepad is not a physical pass.
2. **Stage 1, uninterrupted efficient clear.** Direct Stage 1 at starting power, no death, Bombs used freely. Record the Results time, the `STAGE_RESULT` line (`attempt=1`) and the bombs used, and compare with STAGE_DESIGN's target of 240 s.
3. **Stage 1, normal clear with Campaign upgrades.** Same record.
4. **Retry exclusion.** One clear with a deliberate defeat after CP1-A and a Retry: a stopwatch time next to the Results time, showing the failed segment is excluded.
5. **Stage 2 five-minute requirement.** Not verified (cut): F12-04 is cut pending the user, so Stage 2 has no gameplay to measure. The academic requirement stays unmet and unclaimed.

Steps 2 to 4 need a person to play the stage. If no human pass happens in this session, record them as "not measured" and leave the protocol ready. Never claim a duration that was not measured (ENGINEERING_BRIEF Section 3).

## Out of scope

- Tuning pacing to reach a duration (Astra's content values).
- Stage 2 measurement (cut).
- A new in-game timer display, excluded by PLANEJAMENTO Section 7 (no tutorial or extra HUD text).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR`.
- Named tests exist for ENGINEERING_BRIEF 4.H "failed attempts cannot inflate completed-stage duration", CONVENTIONS "Active Time is accumulated only while the tree is not paused", and STAGE_DESIGN "Pauses, menus, and failed attempts do not inflate the displayed completion time". No Error-level warnings.
- `docs/validation/clear-time.md` is written: measured rows filled, or marked "not measured" with the reason, and Stage 2 marked "not verified (cut)".
- Module doc section, handoff log, `Status: done` with an Outcome, ROADMAP row.
- One commit: `test: verify Active Time and Clear Time accounting`.

## Handoff notes for Astra

`docs/validation/clear-time.md` gives Stage 1's measured clear times against the 240 s target, for pacing and tuning of the `content/stages/stage_01/*.tres` values.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/run-flow/issues/03-active-and-clear-time-verification.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
