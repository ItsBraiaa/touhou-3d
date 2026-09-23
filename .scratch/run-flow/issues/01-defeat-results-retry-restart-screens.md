# F11-01 Defeat, Results, Retry and Restart screens

Status: todo
Type: integration
parallel-safe: no
Depends on: F10-03

## Goal

The three overlays do what GUIDE Section 14 says, with real values:

- **Results.** A stage clear freezes the stage under Results. Results shows `RunState.stage_result()` (Clear Time, score, Graze, bombs used) in the layout for the Run Mode: Continue after Campaign Stage 1, Replay after a Direct Stage, neither on the final victory. A final stage ends the Run with a victory exactly once.
- **Defeat** names its retry location.
- **Pause** shows the Attempt's score and Graze.
- **Buttons.** Every button on Defeat, Results and Pause works: Retry, Menu principal, Créditos, Reiniciar fase, Opções, Continuar (resume). The exceptions are Continuar on Results and Jogar novamente (F11-02). Back on Defeat and Results does nothing.

## Read first

- `docs/GUIDE.md` Section 14: "Scene and action registry" and "Runtime text and presentation" (Results must populate `TimeValue`, `ScoreValue`, `GrazeValue` and `BombsValue`; em dashes mean "not bound").
- `docs/GUIDE.md` Section 7 "Stage completed".
- `docs/engineering/menus-session.md`:
  - "MenuController contract" "Params": Results `mode` and its three constants, Defeat `checkpoint`, Pause `score`/`graze`.
  - "RunState contract": `stage_result()` keys and `advance(power_level)`; after `complete_stage()` the result is final and Attempt calls are ignored.
  - "GameSession contract".
- `docs/engineering/stage-director.md`: `stage_cleared` reaches `complete_stage()` deferred, and `retry_location_name()`.
- `docs/STAGE_DESIGN.md` "Time and score integrity".
- `scripts/ui/menu_controller.gd`, `scripts/session/game_session.gd`. `scenes/ui/results.tscn` and `defeat.tscn` are read only.

## Files

- **Creates:** `tests/scene/test_run_flow_screens.gd`, `tools/validate_run_flow.gd` (dev: drives the real Session to Defeat and to Results through its public getters and captures screenshots), `docs/validation/run-flow.md`, `docs/engineering/run-flow.md`.
- **Edits:**
  - `scripts/ui/menu_controller.gd`:
    - `RESULTS_VALUE_PATHS`, resolved in `_ready`; a missing label is reported once.
    - `enter()` writes the Results params: `clear_time` as `M:SS` (`"%d:%02d"` with seconds floored; Claude's proposal), and `score`, `graze` and `bombs_used` as integers. A missing param writes `—`.
    - Defeat: unchanged (`Último checkpoint · <name>` or `Início da fase`).
  - `scripts/session/game_session.gd`:
    - `_on_stage_completed(result)` replaces its TODO (below).
    - `_on_run_ended(victory)` no longer calls `_return_to_menu()`.
    - A new `_results_params(result) -> Dictionary`.
  - `tests/scene/test_menu_registry_contract.gd`: add the four value labels to the load-bearing paths.
  - `tests/scene/test_game_session_flow.gd`: only a case that expects a stage completion or a victory to return to the menu, which is now Results.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F11-01 row.
  - `docs/HANDOFF_LOG.md`: one entry.
  - `docs/engineering/run-flow.md`: new, and its line in `docs/engineering/README.md`.
  - `docs/GUIDE.md`: the Section 6 rows `game_session.gd` and `menu_controller.gd`; Section 14 "Runtime text and presentation" (now bound; the four value labels are load-bearing); the Section 7 row "Stage completed".
- **Must not touch:** `scenes/ui/*.tscn` (Astra's), `scripts/ui/interface.gd`, `screen_router.gd`, `scripts/session/run_state.gd` (a gap is a note), `stage_director.gd`, `combat_state.gd`.
- **Conflicts with:**
  - `game_session.gd`: F10-03 before and F11-02 after. F12-03 also depends only on F10-03, so it is not ordered against this ticket; never run the two together, and whichever lands second keeps the other's handlers.
  - `menu_controller.gd`: no other ticket is scheduled.

## Deliverables

### `_on_stage_completed(result: Dictionary)`

It is reached from `stage_cleared` deferred (F10-01), never inside a physics flush.

1. `_set_paused(true)`. The world freezes under Results. Active Time already stopped, because the phase is `STAGE_COMPLETE`.
2. `interface.push_overlay(ScreenRouter.RESULTS, _results_params(result))`. Mode: `campaign_stage_1` when not `is_final`; `direct_stage` when `is_final` and the mode is `DIRECT_STAGE`; `final_victory` when `is_final` and the mode is `CAMPAIGN`.
3. When `result["is_final"]`: `_run_state.advance(_combat_state.get_power_level())`, which ends the Run and emits `run_ended(true)` once. A later Menu press calls `end_run(false)`, which is ignored in `RUN_ENDED`.
4. `print("STAGE_RESULT stage=%s mode=%s clear_time=%.2f score=%d graze=%d bombs=%d attempt=%d" % [...])`. `attempt` is `get_attempt_index()`, and 1 means cleared without a Retry or Restart. F11-03 and F14-02 quote this line.

### Buttons, verified end to end

- **Results → Menu principal:** `_return_to_menu()` unpauses, unloads, and shows the main menu.
- **Results → Créditos:** Credits opens; Back returns to Results with its values, and the tree stays paused.
- **Defeat → Tentar novamente:** `_retry()` (F10-03). **Defeat → Menu principal:** `_return_to_menu()`.
- **Pause:** Resume, Restart, Options (the game stays paused) and Menu, as in F2-04.
- **Results → Continuar** and **Jogar novamente** still warn "not implemented" until F11-02.

## Tests required

`tests/scene/test_run_flow_screens.gd` runs headless on `main.tscn`. A clear comes from `director.stage_cleared.emit()`. Values come from real ticks plus `get_run_state().add_score` and `add_graze`.

- `test_stage_clear_shows_results_with_the_run_values`: 120 ticks become `0:02`, and score, Graze and bombs are shown.
- `test_results_freeze_the_world_and_active_time`
- `test_campaign_stage_1_results_show_continue_first`: Continue is visible and focused; Replay is hidden.
- `test_direct_stage_results_show_replay`
- `test_final_stage_ends_the_run_with_victory_once`: after that, Menu emits no `run_ended(false)`.
- `test_menu_from_results_returns_to_the_main_menu`: `WorldRoot` ends up empty.
- `test_credits_from_results_returns_to_results`
- `test_back_on_results_and_defeat_does_nothing`
- `test_defeat_names_the_retry_location`: `Início da fase`, then `Último checkpoint · CP1-A` after CP1-A.
- `test_retry_and_menu_from_defeat`
- `test_pause_shows_the_attempt_score_and_graze`
- `test_results_value_without_a_param_shows_a_dash`: a `MenuController` unit case.
- `test_stage_result_line_is_printed_once_per_clear`

## Out of scope

- Continue and Replay (F11-02), and time verification (F11-03).
- A results jingle (F13, cut).
- Persisted high scores, excluded by PLANEJAMENTO.
- Moving Results' buttons into the empty slot (Astra's layout call).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR`.
- Named tests for GUIDE Section 14's runtime text, the results statistics (PLANEJAMENTO Section 4: "Results show active completion time, score, graze count, and bombs used") and exactly-once victory. No Error-level warnings.
- `tools/validate_run_flow.gd` run headless first, then windowed. It captures `docs/validation/run-flow-results.png` and `run-flow-defeat.png`, recorded in `docs/validation/run-flow.md`.
- Module doc, GUIDE rows, handoff log, `Status: done` with an Outcome, ROADMAP row.
- One commit: `session: bind Results and Defeat and end the stage through Results`.

## Handoff notes for Astra

- `Layout/TimeValue`, `ScoreValue`, `GrazeValue` and `BombsValue` in `results.tscn` are now load-bearing; announce a rename.
- Time shows as `M:SS`. Say so if you prefer tenths.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/run-flow/issues/01-defeat-results-retry-restart-screens.md, then implement that ticket. Use /run to verify Results shows the real values over a frozen Stage 1 and that every Defeat, Results and Pause button does what GUIDE Section 14 says. Finish with its Definition of Done and commit.
```
