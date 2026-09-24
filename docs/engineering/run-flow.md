# Run flow

Feature F11: how a stage ends. Started with ticket F11-01 on 2026-09-24 (CODE_READY): a stage clear freezes the stage under Results with the real statistics, a final stage ends the Run with its one victory, and every Defeat, Results and Pause button works. F11-02 (CODE_READY the same day) added Results' Continuar and Jogar novamente ("Continuation and Direct Stage").

## Purpose

The run flow is not a module of its own. It is the Session's end-of-stage handling in `GameSession` and the Results text in `MenuController`. It owns what happens between the Director's stage clear and the player's next choice: the frozen world, the Results layout for the Run Mode, the victory, and the one `STAGE_RESULT` line.

It does not own:
- the result's values (`RunState.stage_result()`, F2-03);
- when a stage is cleared (the `EncounterMachine` through the `StageDirector`, F10);
- navigation (`ScreenRouter`), which already refuses Back on Defeat and Results and keeps each screen's params for Credits → Back;
- Defeat's retry location (F10-03's `StageDirector.retry_location_name()`);
- the Results scene itself (Astra's `scenes/ui/results.tscn`).

## Files

- `scripts/session/game_session.gd`: `_on_stage_completed(result)` and `_results_params(result)`. The `run_ended` handler is gone: it only returned to the menu. Since F11-02 also `_continue_campaign()`, `_replay_stage()` and `_begin_first_attempt()`, the shared tail of `_start_run` and `_continue_campaign`.
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
| Results | Continuar | `continue_campaign` | F11-02: the next Campaign stage (below) |
| Results | Jogar novamente | `replay_stage` | F11-02: the same stage as a new Direct Stage Run (below) |
| Results, Defeat | Back (`ui_cancel`) | — | Nothing: the router refuses it and the Session ignores `back_refused` |
| Defeat | Tentar novamente | `retry` | F10-03's Retry, or Restart before any Checkpoint |
| Defeat | Menu principal | `return_to_menu` | As from Results |
| Pause | Continuar, Reiniciar fase, Opções, Menu principal | `resume`, `restart_stage`, `open_options`, `return_to_menu` | As in F2-04; Options keeps the game paused |

Defeat shows `Início da fase` before any Checkpoint, else `Último checkpoint · <display_name>`, for example `Portal Selado`. Pause shows the Attempt's score and Graze: `Pontos  <score>     Graze  <graze>`.

## Continuation and Direct Stage (F11-02)

### `_continue_campaign()` (Continuar)

It acts only when the Run is `STAGE_COMPLETE`, the mode is `CAMPAIGN` and the stage is not the last of the order. Anywhere else it warns and does nothing: no Run, a stage in play, Direct Stage Results, or the final victory.
1. It reads the Power Level: `_combat_state.get_power_level()`.
2. `_set_paused(false)`.
3. `_run_state.advance(power)` enters the next stage with that Power Level and the score carried. Clear Time, Graze and bombs used start from zero, and the Attempt index from 0.
4. `_load_stage(<the next stage>)` loads the stage and the ship at its `PlayerStart`. If the load fails, it calls `_return_to_menu()`.
5. `_begin_first_attempt()` runs, which does four things: `_combat_state.start(starting_power_level())` (100 % Health, one Shield, two Bombs, Power Progress 0), `begin_attempt()`, the Director's `start_attempt`, and the HUD.

Only the Power Level carries. A Stage 1 run ending at, for example, level 2 with 3 of 5 Progress loses those 3. This is Claude's reading: `RunState` carries only the level, so a Restart of Campaign Stage 2 returns to the same entry. Carrying Progress would need an entry-progress value in `RunState`, which is the user's call (Open issues).

### `_replay_stage()` (Jogar novamente)

It acts only when the Run is `RUN_ENDED` from a `DIRECT_STAGE` clear whose stage is still loaded under Results. Anywhere else it warns and does nothing.
1. It unpauses.
2. It calls `_start_run(DIRECT_STAGE, <that stage>)`: a new `RunState.start()`, Attempt 1, score 0, the stage's entry Power Level. It is not a Restart.
3. If the stage no longer loads, it returns to the menu.

### Entry values

| Entry | Power Level | Health, Shield, Bombs | Score |
| --- | --- | --- | --- |
| Direct Stage 1, Campaign Stage 1 | 1 | 100 %, one, two | 0 |
| Direct Stage 2 | 2 | 100 %, one, two | 0 |
| Campaign Stage 2 (Continuar) | Stage 1's final Power Level | 100 %, one, two | Stage 1's final score |
| Restart of any of these | the same entry | 100 %, one, two | the same entry score |

### Final victory

Campaign Stage 2's clear shows the `final_victory` layout: heading `Jornada concluída`, Continue and Replay hidden, focus on Menu principal, Créditos reachable. It also emits `run_ended(true)` once. Stage 2 has had its Director since F12-05, so this is its real clear path. Its bosses (F12-06, F12-07) are still dev stand-ins or unintegrated, so the driver cleared it through `stage_cleared`.

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

- **Power Progress is not carried into Campaign Stage 2** (F11-02, Claude's reading above). Tell Claude if it should be; it needs an entry-progress value in `RunState`.
- **The Campaign's final victory through play:** F12-06 and F12-07 replaced both Stage 2 boss stand-ins. S2-07's final-Phase defeat now feeds the Director's `stage_cleared` route used by F11-02. A full manual Campaign flight remains a delivery verification step.
- **Results over Defeat.** A Defeat raised in the same physics step as the last kill is replaced by Results: the stage was cleared. The player's defeated `CombatState` stays frozen under Results. Continuar (F11-02) starts a new `CombatState` anyway.
- **`menus-session.md` "Params"** still calls Defeat's `checkpoint` param an id; it is the Checkpoint's `display_name` (the doc comment in `menu_controller.gd` is fixed).
