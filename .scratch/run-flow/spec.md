# F11 Run flow — spec

Status: ready-for-agent
Owner: Claude
Source: GUIDE.md Section 14 ("Scene and action registry", "Runtime text and presentation") and Section 7 ("Player defeated", "Stage completed"); STAGE_DESIGN.md "Time and score integrity"; PLANEJAMENTO.md Sections 2 (the five-minute rule) and 6; `.scratch/menus-session/issues/03-run-state-core.md` and its Outcome (`RunState`'s real API); `docs/engineering/menus-session.md` (MenuController params, Results modes).

## Goal

The loop closes from the main menu to victory:

- A stage clear shows Results over a frozen stage, with the real Clear Time, score, Graze and bombs used, and the layout for the Run Mode.
- Defeat names its retry location, and Pause shows the Attempt's score and Graze.
- Continuar carries a Campaign from Stage 1 into Stage 2 with its Power Level and score, and restores Health, the Shield and both Bombs.
- Jogar novamente replays a Direct Stage. A Direct Stage 2 starts at Power Level 2.
- The final victory shows `Jornada concluída`.

Tests prove that Active Time leaves out pauses, menus, Defeat and Results, and that Clear Time rolls back a failed segment. A manual protocol records an uninterrupted clear for the academic duration check.

## Tickets

1. `01-defeat-results-retry-restart-screens.md`: Results binding and modes, Run victory, the stage-result log line, and every Defeat, Results and Pause button except Continue and Replay.
2. `02-campaign-continuation-and-direct-stage.md`: Continuar, Jogar novamente, final victory, Direct Stage entry values.
3. `03-active-and-clear-time-verification.md`: time accounting tests and the uninterrupted-clear record in `docs/validation/`.

None of the three is parallel-safe. 01 and 02 edit `game_session.gd`. 03 drives the whole Session headless and must not share a test run with a Session edit.

## Cross-feature contracts

- **Results params** (`MenuController`, F11-01): `mode` (`campaign_stage_1`, `direct_stage` or `final_victory`), `clear_time: float` in seconds (shown as `M:SS`), `score`, `graze` and `bombs_used` (ints). They fill `Layout/TimeValue`, `ScoreValue`, `GrazeValue` and `BombsValue`; a missing param shows `—`.
- **Stage completion** (F11-01), `_on_stage_completed(result)`:
  1. `_set_paused(true)`.
  2. Push Results with the params above.
  3. When `result["is_final"]`, call `run_state.advance(combat_state.get_power_level())`, so `run_ended(true)` fires once. `_on_run_ended` no longer returns to the menu.
  4. Print one line: `STAGE_RESULT stage=<id> mode=<mode> clear_time=<s> score=<n> graze=<n> bombs=<n> attempt=<n>`.
- **Continuation** (F11-02): `continue_campaign` goes through `run_state.advance(power_level)`, loads Stage 2, then `combat_state.start(run_state.starting_power_level())`, `begin_attempt()`, the Director's `start_attempt` when there is one, and the HUD. The Power Level is carried and Power Progress resets (see F11-02). `replay_stage` calls `_start_run(DIRECT_STAGE, stage)`.
- **Defeat**: the `checkpoint` param is set by F10-03 (`retry_location_name()`); F11-01 only verifies it.
- **For F14**: the `STAGE_RESULT` line and `docs/validation/clear-time.md` (F11-03) are the evidence for the acceptance record.

## Cut pending the user, and what it costs here

- **F12-04.** Stage 2 has no Director, enemies, Seals, miniboss or boss, so the Campaign's final victory cannot be reached through gameplay. F11-02's test drives `RunState.complete_stage()` on Stage 2 directly and records the gap.
- **The academic five-minute rule.** PLANEJAMENTO Section 2 targets Stage 2, which cannot be measured. F11-03 measures Stage 1 only (target 240 s) and marks the Stage 2 check "not verified (cut)".
- **F3.** Options are not applied or persisted.
- **F13.** There is no results or victory audio.

## Done when

- All F11 tests pass.
- From the main menu, a Campaign plays Stage 1 to Results, then Continue, then Stage 2 flies with the carried Power. A Direct Stage offers Replay, Menu and Credits from Results. Defeat offers Retry and Menu.
- `docs/engineering/run-flow.md` documents Results, continuation and time accounting.
- GUIDE Section 14 "Runtime text" is bound. Section 10 "Main composition and session" and "Menus/options" advance.

## Out of scope

- Stage 2 gameplay (F12-04, cut).
- Settings (F3, cut).
- Audio (F13, cut).
- Persisting results, which PLANEJAMENTO excludes: only options persist.
- A per-Checkpoint place name, which is Astra's content value.
- Moving the Results buttons into the empty slot (an Astra layout request already in the roadmap).
