# F11-02 Campaign continuation and Direct Stage

Status: todo
Type: integration
parallel-safe: no
Depends on: F11-01

## Goal

Results' two remaining buttons work.

- **Continuar**, after Campaign Stage 1, loads Stage 2. It carries the Power Level and the score, and restores 100% Health, one Shield and two Bombs (PLANEJAMENTO Section 6: "Campaign transitions preserve power and score while restoring health, shield, and two bombs").
- **Jogar novamente**, after a Direct Stage, starts that stage again as a new Direct Stage Run.

This ticket also verifies:

- The final victory: heading `Jornada concluída`, Continue and Replay hidden, focus on Menu principal.
- Stage entry values: Direct Stage 1 starts from the stage-1 values; Direct Stage 2 starts at Power Level 2 with 100% Health, one Shield, two Bombs and score 0.

Stage 2 has no Director while F12-04 is cut, so the Campaign's real final victory cannot be reached through gameplay. The test drives `RunState.complete_stage()` on Stage 2 and records the gap.

## Read first

- `docs/PLANEJAMENTO.md` Section 6 and `docs/GUIDE.md` Section 14 (Results rows, final victory text).
- `docs/engineering/menus-session.md` "RunState contract": `advance(power_level)` enters the next stage, with the Power Level and score carried and the Attempt index back to 0. `starting_power_level()`. Replaying a completed Direct Stage must call `start()` again, not `restart_stage()`.
- `docs/engineering/combat-hud.md`: `start(power_level, power_progress := 0)`, and Open issue (f), which says the Session decides whether partial Power Progress is carried.
- `docs/engineering/run-flow.md` (F11-01): the Results modes and `_on_stage_completed`.
- `scripts/session/game_session.gd`.

## Files

- **Creates:** `tests/scene/test_campaign_flow.gd`.
- **Edits:**
  - `scripts/session/game_session.gd`: `continue_campaign` goes to `_continue_campaign()` and `replay_stage` to `_replay_stage()`. The shared tail of `_start_run`, `_restart_stage` and `_continue_campaign` (load, combat start, `begin_attempt`, the Director's `start_attempt`, HUD) may be factored into one `_enter_loaded_stage()`. Each caller keeps its own `RunState` call.
  - `tools/validate_run_flow.gd` and `docs/validation/run-flow.md`: a Continue and Replay step.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F11-02 row.
  - `docs/HANDOFF_LOG.md`: one entry.
  - `docs/engineering/run-flow.md`: a "Continuation and Direct Stage" section.
  - `docs/GUIDE.md`: the Section 6 row `game_session.gd`, and the Section 10 rows "Main composition and session" and "Menus/options".
- **Must not touch:** `scripts/session/run_state.gd`, `combat_state.gd`, `menu_controller.gd` (the final-victory layout and focus loop exist since F2-02), `scenes/ui/*.tscn`, `scenes/stages/stage_02.tscn`, `stage_director.gd`.
- **Conflicts with:** `game_session.gd`, with F11-01 before and F12-03 after. F12-03 is not ordered against this ticket, so never run the two together.

## Deliverables

- **`_continue_campaign()`** acts only when the phase is `STAGE_COMPLETE`, the mode is `CAMPAIGN` and `stage_result()["is_final"]` is false. Otherwise it is ignored, with a warning.
  1. `var power := _combat_state.get_power_level()`.
  2. `_set_paused(false)`.
  3. `_run_state.advance(power)` enters `stage_02` with the carried Power Level and score.
  4. `_load_stage(&"stage_02")`. If it fails, call `_return_to_menu()`.
  5. `_combat_state.start(_run_state.starting_power_level())`.
  6. `_run_state.begin_attempt()`; `_director.start_attempt(...)` when the stage has one, which Stage 2 does not.
  7. `interface.show_home(HUD)`.
- **Power Progress on a transition.** Only the Power Level carries; progress starts at 0. This is Claude's reading: `RunState` carries only the level, so a Restart of Campaign Stage 2 returns to the same entry. If a Stage 1 run ends at, for example, level 2 with 3 of 5 progress, those 3 are lost. It is recorded in Open issues for the user and Astra; carrying progress would need an entry-progress value in `RunState`.
- **`_replay_stage()`** acts only when the Run ended from a `DIRECT_STAGE` result. It calls `_start_run(RunState.RunMode.DIRECT_STAGE, stage_result()["stage"])`, which is a new `start()`, Attempt 1, score 0.
- **Final victory.** It was already produced by F11-01 (`final_victory` mode). Verify: heading `Jornada concluída`, Continue and Replay hidden, focus on Menu principal (the first visible focusable control), and Credits reachable.

## Tests required

`tests/scene/test_campaign_flow.gd` runs headless on `main.tscn`.

- `test_continue_loads_stage_2_with_power_and_score_carried`: the Campaign reaches Power 3 through `collect_power_pickup()` and score 500, then clears Stage 1. After Continue, the Stage 2 `Stage` is under `WorldRoot` and the ship at its `PlayerStart`. The Power Level is 3, the score 500, and `clear_time`, Graze and bombs used are 0. The Attempt index is 1 and the HUD is on top.
- `test_continue_restores_health_shield_and_bombs`: the Stage 1 clear happens after a hit and a Bomb.
- `test_restart_in_campaign_stage_2_returns_to_its_entry`: the carried Power Level and entry score come back.
- `test_campaign_stage_2_clear_shows_final_victory`: the test drives `get_run_state().complete_stage()`, because Stage 2 has no Director while F12-04 is cut. It checks the heading, the hidden buttons, focus on Menu principal, and `run_ended(true)` once.
- `test_replay_starts_a_fresh_direct_stage_run`
- `test_direct_stage_2_starts_at_power_2_with_full_resources`
- `test_direct_stage_1_uses_the_stage_1_entry_values`
- `test_continue_is_ignored_outside_campaign_stage_1_results`

## Out of scope

- Stage 2 gameplay and its real completion (F12-04, cut pending the user).
- Carrying Power Progress, which is the user's call.
- Transition audio (F13, cut).
- Any Stage 2 checkpoint.

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR`.
- Named tests for the PLANEJAMENTO Section 12 items "direct Stage 2 starts at power level 2" and "Restart Stage and isolated stage selection use the correct stage-entry values" (STAGE_DESIGN). No Error-level warnings.
- `tools/validate_run_flow.gd` Continue and Replay steps run headless, then windowed, and capture `docs/validation/run-flow-continue.png`.
- The Stage 2 final-victory gap is recorded in `run-flow.md` Open issues.
- Module doc, GUIDE rows, handoff log, `Status: done` with an Outcome, ROADMAP row.
- One commit: `session: add Campaign continuation, Replay and Direct Stage entry`.

## Handoff notes for Astra

None for scenes. Stage 2 flies with the carried Power but has no gameplay until F12-04 is reinstated.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/run-flow/issues/02-campaign-continuation-and-direct-stage.md, then implement that ticket. Use /run to verify Continuar carries Power and score into Stage 2, Jogar novamente replays a Direct Stage, and a Direct Stage 2 shows Power 2 on the HUD. Finish with its Definition of Done and commit.
```
