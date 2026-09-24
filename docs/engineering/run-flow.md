# Run flow

Feature F11: how a stage ends. Started with ticket F11-01 on 2026-09-24 (CODE_READY): a stage clear freezes the stage under Results with the real statistics, a final stage ends the Run with its one victory, and every Defeat, Results and Pause button works except Results' Continuar and Jogar novamente, which F11-02 adds.

## Purpose

The run flow is not a module of its own. It is the Session's end-of-stage handling in `GameSession` and the Results text in `MenuController`. It owns what happens between the Director's stage clear and the player's next choice: the frozen world, the Results layout for the Run Mode, the victory, and the one `STAGE_RESULT` line.

It does not own:
- the result's values (`RunState.stage_result()`, F2-03);
- when a stage is cleared (the `EncounterMachine` through the `StageDirector`, F10);
- navigation (`ScreenRouter`), which already refuses Back on Defeat and Results and keeps each screen's params for Credits → Back;
- Defeat's retry location (F10-03's `StageDirector.retry_location_name()`);
- the Results scene itself (Astra's `scenes/ui/results.tscn`).

## Files

- `scripts/session/game_session.gd`: `_on_stage_completed(result)` and `_results_params(result)`. The `run_ended` handler is gone: it only returned to the menu.
- `scripts/ui/menu_controller.gd`: `RESULTS_VALUE_PATHS`, `_find_results_values`, `_write_results_values` and `_format_clear_time`.
- `tests/scene/test_game_session_flow.gd`: `test_a_completed_stage_returns_to_the_menu_until_results_exist` became `test_a_completed_stage_shows_results` (minimal adjustment, sprint rule). No new test file: the ticket's test list is void under the sprint's no-new-tests rule, and so is `tools/validate_run_flow.gd`. A scratchpad driver checked it instead ([validation/run-flow.md](../validation/run-flow.md)).

## Public contract

### Results params (`MenuController.enter` on Results)

| Param | Type | Written to | Format |
| --- | --- | --- | --- |
| `mode` | `StringName` | ContinueButton, ReplayButton, `Layout/Heading`, the focus loop | `campaign_stage_1` (Continue), `direct_stage` (Replay), `final_victory` (neither; heading `Jornada concluída`). Absent means `campaign_stage_1`, as authored. |
| `clear_time` | `float`, seconds | `Layout/TimeValue` | `M:SS`, seconds floored after snapping to the millisecond, so 180 ticks read `0:03`, not `0:02`. Claude's proposal: say so if you prefer tenths. |
| `score` | `int` | `Layout/ScoreValue` | integer |
| `graze` | `int` | `Layout/GrazeValue` | integer |
| `bombs_used` | `int` | `Layout/BombsValue` | integer |

A missing param shows `—`. A missing label is reported once, in `_ready`, naming its path.

### `_on_stage_completed(result: Dictionary)`

It is connected to `RunState.stage_completed`, which `complete_stage()` emits. That call comes from the Director's `stage_cleared`, connected deferred, so it never runs inside a physics flush.

1. `_set_paused(true)`: the tree, the controls, the `CombatState` and the pause flag. Active Time already stopped, because the Run is `STAGE_COMPLETE`.
2. Any overlay on top is dropped (`show_home(HUD)`), then `push_overlay(RESULTS, _results_params(result))`. The only overlay that can be there is a Defeat raised in the same physics step as the last kill.
3. When `result["is_final"]`: `_run_state.advance(_combat_state.get_power_level())` ends the Run and emits `run_ended(true)` once. A later Menu principal calls `end_run(false)`, which is ignored in `RUN_ENDED`.
4. It prints one line, which F11-03 and F14-02 quote:
   `STAGE_RESULT stage=<id> mode=<CAMPAIGN|DIRECT_STAGE> clear_time=<s.ss> score=<n> graze=<n> bombs=<n> attempt=<n>`.
   `attempt` is `get_attempt_index()`: 1 means cleared without a Retry or a Restart.

`_results_params(result)` picks the mode:
- `campaign_stage_1` when the stage is not the last of the order;
- `direct_stage` when it is and the Run Mode is `DIRECT_STAGE`;
- `final_victory` when it is and the Run Mode is `CAMPAIGN`.

It also copies the four statistics.

### Buttons

| Screen | Button | Action | Effect |
| --- | --- | --- | --- |
| Results | Menu principal | `return_to_menu` | Unpauses, unloads the stage and the ship, `end_run(false)` (ignored after a victory), main menu |
| Results | Créditos | `open_credits` | Credits over Results; the tree stays paused; Back returns to Results with the same values |
| Results | Continuar, Jogar novamente | `continue_campaign`, `replay_stage` | Warn "not implemented yet" until F11-02 |
| Results, Defeat | Back (`ui_cancel`) | — | Nothing: the router refuses it and the Session ignores `back_refused` |
| Defeat | Tentar novamente | `retry` | F10-03's Retry, or Restart before any Checkpoint |
| Defeat | Menu principal | `return_to_menu` | As from Results |
| Pause | Continuar, Reiniciar fase, Opções, Menu principal | `resume`, `restart_stage`, `open_options`, `return_to_menu` | As in F2-04; Options keeps the game paused |

Defeat shows `Início da fase` before any Checkpoint, else `Último checkpoint · <display_name>`, for example `Portal Selado`. Pause shows the Attempt's score and Graze: `Pontos  <score>     Graze  <graze>`.

## Dependencies

- `RunState.stage_completed`, `stage_result()`, `advance()`, `end_run()` and `get_attempt_index()`.
- `CombatState.get_power_level()`.
- `Interface.push_overlay()`, `show_home()` and `current_screen()`.
- `MenuController.RESULTS_*` constants.
- `StageDirector.stage_cleared`, deferred (F10-01).

## Invariants and tests

| Invariant | Check |
| --- | --- |
| Results show active completion time, score, graze count and bombs used (PLANEJAMENTO Section 4) | Driven: values equal `stage_result()` |
| The world and Active Time are frozen under Results | Driven: `clear_time` and the ship unchanged after 90 ticks |
| A final stage ends the Run with a victory exactly once | Driven: `run_ended` is `[true]` and stays so after Menu principal |
| Back on Defeat and Results does nothing | Driven, plus the router's existing tests |

No test is added (the sprint's no-new-tests rule). Every row was checked by the driver in [validation/run-flow.md](../validation/run-flow.md).

## Setup for Astra

`Layout/TimeValue`, `ScoreValue`, `GrazeValue` and `BombsValue` in `results.tscn` are load-bearing now: announce a rename. Time shows as `M:SS`; say so if you prefer tenths.

## Open issues

- **The Campaign's real final victory needs Continuar (F11-02).** Here the `final_victory` layout was checked through the Session's own `_results_params` on a pushed Results.
- **Results over Defeat.** A Defeat raised in the same physics step as the last kill is replaced by Results: the stage was cleared. The player's defeated `CombatState` stays frozen under Results. Continuar (F11-02) starts a new `CombatState` anyway.
- **`menus-session.md` "Params"** still calls Defeat's `checkpoint` param an id; it is the Checkpoint's `display_name` (the doc comment in `menu_controller.gd` is fixed).
