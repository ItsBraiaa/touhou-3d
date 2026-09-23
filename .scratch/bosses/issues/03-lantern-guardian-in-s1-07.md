# F12-03 Lantern Guardian in S1-07

Status: todo
Type: integration
parallel-safe: no
Depends on: F12-02, F10-03
Lane: trunk (part 1: oc-a)
Model: part 1 GPT 5.6 Luna (fallback DeepSeek V4.1 Flash); part 2 Claude Opus 5.5, 3-agent workflow (implementer, test-writer, reviewer)

> **Split (SPRINT.md):**
> - **Part 1, lane oc-a** (depends on F12-01, F5-04 and F6-03 part 1): `content/bosses/lantern_guardian.tres`, the three `content/patterns/lantern_*.tres` and the content unit test only. Commit with `(F12-03 part 1)`.
> - **Part 2, lane trunk** (after F12-02, F10-03 and part 1): the Director boss branch, the Session wiring, the `stage_01.tscn` exports and the integration test. It closes the ticket. Part 2 only references part 1's files; a needed value change becomes a note.

> **Sprint notes:**
> 1. **D-03** (lane sol) delivers `scenes/enemies/lantern_guardian.tscn` with no root script. If it has landed, attach `boss_controller.gd` to it `[shared]`, set its references and D-03's clip names, and point `actor_scenes[&"lantern_guardian"]` at it. Otherwise ship the dev boss and log "swap pending: D-03". Do not wait for D-03.
> 2. **`scripts/progression/stage_director.gd`** is also edited by F12-05 (lane sol), which may land first. Run `tools/lane.ps1 sync` before starting, and keep your additions in separate functions.
> 3. **Shrine lighting.** Keep the `defeat_presentation` / `defeat_animation` exports empty by default: D-07 fills them through F14-01's swap step.
> 4. **Results timing.** D-07 sets the shrine `AnimationPlayer` to `process_mode = ALWAYS`, because Results pauses the tree right after `boss_defeated`.

## Goal

Stage 1 ends with its real boss. The Guardião das Lanternas spawns at `Encounters/S1-07/Spawns/Wave1_Boss1` when S1-07 is entered behind CP1-B. It fights its three STAGE_DESIGN Attacks (Ritual das Lanternas, Fios de Luz, Dança do Crepúsculo), shows the HUD boss panel and each Attack cue, awards 1,000 score and completes S1-07 exactly once from its final-Phase defeat, never from the ExitVolume. The Director's `boss_defeated` signal is the hook for Astra's shrine lighting change from corrupted to calm. A Retry during the fight removes the boss and hides the panel.

## Read first

- `docs/STAGE_DESIGN.md` Stage 1 "Final boss sequence" (the three Attacks, about 25/25/35 s, "defeat clears hostile fire and changes the shrine's lighting"), Stage 1 table row S1-07
- `docs/PLANEJAMENTO.md` Section 4 "Bosses and named attacks", "Graze and score" (1,000 per final boss)
- `docs/STAGE_01_HANDOFF.md` ("boss completion comes from final phase defeat, not its ExitVolume"; `Wave1_Boss1` at (0, 43, -520); no retreat containment yet)
- `docs/engineering/bosses.md` (F12-01, F12-02), `docs/engineering/stage-director.md` (F10-01 to F10-03: `StageDirector` exports, spawn path, Retry and Restart, and the test seam its Outcome names), `docs/engineering/combat-hud.md` (F4-02 binding, F4-03 boss API), `docs/engineering/weapon-rendering.md` (F6-03 shot damage and cadence, for the health proposal)
- `content/stages/stage_01/s1_07.tres` (F8-04: wave kind `lantern_guardian`, ALL_REQUIRED_ENEMIES, CP1-B)

## Files

- **Creates:** `content/bosses/lantern_guardian.tres` (BossDefinition with its Phases, Attacks and steps as sub-resources); `content/patterns/lantern_ring.tres`, `lantern_aimed_burst.tres`, `lantern_paired_fan.tres`, all `metadata/dev = true`; `tests/unit/definitions/test_lantern_guardian_content.gd`; `tests/scene/test_s1_07_boss_integration.gd`.
- **Edits:** `scripts/progression/stage_director.gd`: a `boss_definitions: Dictionary[StringName, BossDefinition]` export; a spawn branch for kinds found there (`actor_scenes[kind]` with a `BossController` root, `spawn_setup` with the `BossDefinition`); boss signals connected once and forwarded as `boss_started(display_name: String, phase_count: int)`, `boss_phase_changed(phase_index: int, attack_display_name: String)`, `boss_health_changed(phase_index: int, ratio: float)`, `boss_defeated(boss_id: StringName)`; `run_state.add_score(controller.get_score())` on defeat; the boss's `threat_reported` goes into the Director's existing `threat_reported` (F10-01 already routes it to `Hud.show_threat`); optional exports `defeat_presentation: AnimationPlayer` and `defeat_animation: StringName`, played on `boss_defeated`. `scripts/session/game_session.gd`: once per stage load, Director boss signals go to `interface.get_hud()`: `show_boss`, `show_attack_cue(name, ATTACK_CUE_SECONDS)` (2.0 s, Claude's proposal), `set_phase_health`, and `hide_boss` on `boss_defeated`, Retry and Restart. `scenes/stages/stage_01.tscn` [shared]: StageDirector exports only. **Remove F10-01's dev stand-in**: both `actor_scenes[&"lantern_guardian"]` = `scenes/dev/sentry.tscn` and `enemy_definitions[&"lantern_guardian"]` = `content/enemies/sentry.tres`, which let F10 and F11 clear S1-07 with a Sentry. Then set `actor_scenes[&"lantern_guardian"]` = `scenes/dev/dev_boss.tscn` and `boss_definitions[&"lantern_guardian"]` = `content/bosses/lantern_guardian.tres`. A kind present in both `enemy_definitions` and `boss_definitions` is a setup error the Director reports. Also edited: the F10 and F11 scene tests that clear S1-07 through the stand-in (their files are named in the F10-03 and F11 Outcomes).
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F12-03 row), `docs/HANDOFF_LOG.md` ([shared] entry), `docs/engineering/bosses.md` ("Lantern Guardian" section), `docs/engineering/stage-director.md` (boss additions), `docs/GUIDE.md` Section 6 rows `stage_director.gd` and `boss_controller.gd`, Section 10 "Lantern Guardian".
- **Must not touch:** `scripts/enemies/boss_machine.gd` and `boss_controller.gd` (a defect is a separate fix, logged), `scripts/progression/encounter_machine.gd`, `content/stages/stage_01/*.tres` (F8-04, Astra's values), `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`, anything in `stage_01.tscn` beyond StageDirector exports (geometry, markers and lighting are Astra's), `scenes/stages/stage_02.tscn`.
- **Conflicts with:** F10-01 to F10-03 (`stage_director.gd`, `stage_01.tscn`, `game_session.gd`), F11-01 and F11-02 (`game_session.gd`). Serialized: none is parallel-safe. F14-01 waits for this ticket.

## Deliverables

- `lantern_guardian.tres`: kind `lantern_guardian`, `display_name` `"Guardião das Lanternas"`, `score` 1000, `entry_seconds` 1.0, three Phases:
  1. `"Ritual das Lanternas"`: a ring at a high `height_offset`, a sparse aimed burst, a ring at a low offset with the gap rotated, a sparse aimed burst (STAGE_DESIGN: expanding rings at alternating heights with broad gaps, and an aimed burst so one height is never safe).
  2. `"Fios de Luz"`: an aimed burst after a brief charge (a longer `anticipation_seconds`), alternating with paired fans using `follow_player_height`.
  3. `"Dança do Crepúsculo"`: a ring sequence and aimed bursts, then a `reposition_seconds` window. It raises coordination without doubling bullet counts.
  Phase health is Claude's proposal: about 25, 25 and 35 s of Power Level 3 fire from F6-03's recorded damage and cadence, with the Power Level 2 durations recorded beside it. Pattern numbers and transition times are proposals too. Astra tunes everything.
- S1-07 completes only through `EncounterMachine.notify_enemy_defeated`, fed by the boss's `defeated`. Its ExitVolume changes nothing.

## Tests required

`tests/unit/definitions/test_lantern_guardian_content.gd`: `test_lantern_guardian_content_is_valid`, `test_three_phases_carry_the_stage_design_attack_names` (exact Portuguese strings), `test_final_boss_score_is_1000`, `test_every_file_is_flagged_dev`.

`tests/scene/test_s1_07_boss_integration.gd` (headless, `main.tscn`, Direct Stage 1, resumed at CP1-B through F10-03's test seam):

- `test_entering_s1_07_spawns_the_guardian_at_its_marker` (one BossController under `RuntimeActors` at (0, 43, -520))
- `test_boss_panel_shows_three_phases_and_the_first_attack`
- `test_exit_volume_does_not_complete_s1_07`
- `test_each_phase_change_announces_the_next_attack` (`Fios de Luz`, then `Dança do Crepúsculo`; hostile count 0 after each)
- `test_final_phase_defeat_clears_the_stage_once` (`boss_defeated` once, `stage_cleared` once, score +1000)
- `test_retry_during_the_fight_removes_the_boss_and_hides_the_panel` (the Director survives Retry and empties `RuntimeActors`; the Session re-instances the ship at `get_respawn_transform()` and calls `hide_boss`)
- `test_sentry_stand_in_is_gone` (`enemy_definitions` has no `lantern_guardian` entry)

The existing F10 and F11 tests that cleared S1-07 with the Sentry stand-in are updated here to defeat the boss through its three Phases, using the same test seam.

## Out of scope

Astra's `lantern_guardian.tscn` and its clips (a one-export swap when it lands); shrine lighting authoring (Astra's `AnimationPlayer`; until it exists `defeat_presentation` stays empty and the gap is logged); boss-arena retreat containment; Results (F11); boss music (F13, cut); the Tempest Sentinel and Storm Guardian (F12-04, cut).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR` in the output; the tests above; no Error-level warnings.
- `/run`, headless first, then windowed: from CP1-B, enter the arena, see `Guardião das Lanternas` with three bars and each Attack cue, defeat the three Phases, and see the stage clear once. Recorded in `docs/validation/bosses.md` with a screenshot.
- `docs/engineering/bosses.md` and `stage-director.md` updated; GUIDE Section 6 rows and Section 10 "Lantern Guardian".
- Handoff log entry naming the `stage_01.tscn` export changes and every Astra-owned value; `Status: done` with an Outcome; ROADMAP row.
- One commit: `bosses: [shared] integrate the Lantern Guardian in S1-07`.

## Handoff notes for Astra

`stage_01.tscn`: only StageDirector exports changed. Tune `content/bosses/lantern_guardian.tres` and the three `content/patterns/lantern_*.tres`. For the shrine lighting, author an `AnimationPlayer` in the stage (for example under `Environment`) with a corrupted-to-calm clip and tell Claude its path and clip name. Claude sets `defeat_presentation` and `defeat_animation`, and the Director plays it on `boss_defeated`. When `scenes/enemies/lantern_guardian.tscn` exists, Claude swaps it for the dev boss in `actor_scenes`. Retreat containment for the arena is still an open request.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/bosses/issues/03-lantern-guardian-in-s1-07.md, then implement that ticket. Use /run to verify the Lantern Guardian fight from CP1-B through its three Phases to a single stage clear. Finish with its Definition of Done and commit.
```
