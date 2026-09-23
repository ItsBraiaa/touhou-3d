# F12-07 Storm Guardian in S2-07

Status: todo
Type: integration
parallel-safe: no
Depends on: F12-06, D-04
Lane: sol
Model: GPT Sol (Codex)

## Goal

The Guardião da Tempestade replaces the last stand-in and ends Stage 2 and the Campaign.

- **Scene and content.** Astra's `scenes/enemies/storm_guardian.tscn` (D-04, `Dragon_Evolved.gltf`) gets `boss_controller.gd`. Its three-Phase `BossDefinition` and its patterns land as dev content.
- **The fight.** Entering S2-07 behind CP2-B spawns it at `Wave1_Boss1`. It fights the three STAGE_DESIGN Attacks: Espiral da Tempestade, Círculos do Trovão and Olho da Tormenta.
- **Completion.** It awards 1,000 score, and S2-07 completes exactly once from its final-Phase defeat, never from the ExitVolume. So Stage 2 clears.
- **Victory.** A Campaign reaches `Jornada concluída` through gameplay, closing the gap that F11-02 recorded.

No GDScript changes; F12-03's boss branch and HUD wiring already carry everything.

## Read first

- `docs/STAGE_DESIGN.md` Stage 2 "Final boss sequence":
  - Phase targets of 40, 40 and 50 s.
  - Espiral: rotating streams, a gradually moving emission height, and wide corridors.
  - Círculos: a cue at the next attack height, then expanding rings, alternating high and low.
  - Olho: aimed bursts alternating with spirals, then a repositioning window, with no simultaneous patterns whose safe gaps contradict.
  - Defeat "clears bullets, reduces storm intensity, and reveals the sky".
- `docs/PLANEJAMENTO.md` Section 4 (1,000 per final boss) and Section 12 ("Campaign runs from Stage 1 to final victory"). `docs/MODEL_SELECTION.md`, the Storm Guardian row.
- `docs/engineering/bosses.md` (F12-01 to F12-03, F12-06), `docs/engineering/stage-director.md` "Stage 2" (the test seam), and `docs/engineering/run-flow.md` (F11-01 Results modes and `final_victory`; the Open issue from F11-02).
- `.scratch/projectile-field/issues/04-pattern-emitter-core.md` Outcome table: Espiral is SPIRAL with `rotation_step_degrees`; Círculos is RING with `height_offsets`.
- The D-04 entry in `docs/HANDOFF_LOG.md`; `content/bosses/tempest_sentinel.tres` (F12-06), the file shape to copy.

## Files

- **Creates:** `content/bosses/storm_guardian.tres`; `content/patterns/storm_spiral.tres`, `storm_thunder_rings.tres` and `storm_aimed_burst.tres` (every file `metadata/dev = true`); `tests/unit/definitions/test_storm_guardian_content.gd`; `tests/scene/test_s2_07_boss_integration.gd`.
- **Edits:**
  - `scenes/enemies/storm_guardian.tscn` [shared]: the root script and its exports from D-04's handoff.
  - `scenes/stages/stage_02.tscn` [shared], StageDirector exports only. Remove the stand-in's `storm_guardian` entries. Set `actor_scenes[&"storm_guardian"]` to the scene above and `boss_definitions[&"storm_guardian"]` to `content/bosses/storm_guardian.tres`.
  - `tests/scene/test_stage_02_director.gd` and `test_s2_04_miniboss_integration.gd`: only the cases that cleared S2-07 through the stand-in.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F12-07 row.
  - `docs/HANDOFF_LOG.md`: a [shared] entry.
  - `docs/engineering/bosses.md`: a "Storm Guardian" section.
  - `docs/engineering/run-flow.md`: close the Stage 2 final-victory Open issue.
  - `docs/GUIDE.md`: Section 10 "Storm Guardian" and "Stage 2 progression".
- **Must not touch:**
  - Every `scripts/**` file.
  - Trunk's `game_session.gd`, `main.tscn` and `stage_01.tscn`.
  - `hud.gd`, `content/stages/**`, `tempest_sentinel.tscn`.
  - `tests/scene/test_campaign_flow.gd`: F11-02's direct `RunState` case stays as the Results-mode check.
  - Anything in `storm_guardian.tscn` beyond the root script and its exports.
- **Conflicts with:** none scheduled after it. F11-03's Stage 2 measurement needs this ticket landed.

## Deliverables

- **`storm_guardian.tres`.** kind `storm_guardian`, `display_name` `"Guardião da Tempestade"`, `score` 1000, `entry_seconds` 1.0, and three Phases:
  1. **`"Espiral da Tempestade"`**: `storm_spiral` (SPIRAL) with few projectiles per volley, which leaves wide corridors. Its `height_offsets` climb then descend across the volleys, so the emission height moves gradually. A short `reposition_seconds` follows.
  2. **`"Círculos do Trovão"`**: `storm_thunder_rings` (RING with `gap_degrees`) steps alternating a high and a low `height_offset`. Each ring waits for its `anticipation_seconds`, while `step_clip` plays as the cue.
  3. **`"Olho da Tormenta"`**: `storm_aimed_burst`, `storm_spiral`, `storm_aimed_burst` and `storm_spiral`, then `reposition_seconds`. `BossMachine` runs one step at a time, so no two patterns overlap.
  - **Health.** A proposal of about 40, 40 and 50 s of Power Level 3 fire, from F6-03's damage and cadence, with the Power Level 2 durations beside it. Pattern numbers are proposals as well. Astra tunes everything.
- **The root.** `boss_controller.gd` takes D-04's names for `visual_root`, `hit_volume`, `emitter`, `animation_player` and the three clips.
- **Victory without Session code.** F11-01's Results already chooses `final_victory` from `RunState.stage_result().is_final`. This ticket proves that path through play.

## Tests required

`tests/unit/definitions/test_storm_guardian_content.gd`:

- `test_storm_guardian_content_is_valid`
- `test_three_phases_carry_the_stage_design_attack_names`: the exact Portuguese strings.
- `test_final_boss_score_is_1000`
- `test_every_file_is_flagged_dev`

`tests/scene/test_s2_07_boss_integration.gd` runs headless on `main.tscn`, resumed at CP2-B through the test seam F12-05's Outcome names:

- `test_storm_guardian_prefab_follows_the_guide_tree`
- `test_entering_s2_07_spawns_the_guardian_at_its_marker`: (0, 113, -690).
- `test_boss_panel_shows_three_phases_and_the_first_attack`
- `test_each_phase_change_announces_the_next_attack`: `Círculos do Trovão`, then `Olho da Tormenta`, with the hostile count at 0 after each.
- `test_exit_volume_does_not_complete_s2_07`
- `test_final_phase_defeat_clears_stage_2_once`: +1000 once, `boss_defeated` once, `stage_cleared` once.
- `test_retry_during_the_fight_restores_cp2_b`: the boss is removed, the panel hidden, and a fresh Guardian spawns on entry (STAGE_DESIGN "death at the final boss restores CP2-B").
- `test_direct_stage_2_clear_offers_replay`
- `test_campaign_reaches_final_victory_through_gameplay`:
  1. Clear Stage 1 as F11-02's test does, then press Continuar.
  2. Resume Stage 2 at CP2-B and defeat the three Phases.
  3. Results shows `Jornada concluída`, and `run_ended(true)` fires once.
- `test_stand_in_is_gone`

## Out of scope

- **Storm-resolution presentation.** `defeat_presentation` stays empty until Astra authors a storm-calm clip in `stage_02.tscn`. After that it is a one-export change.
- **The ring-shaped world cue at the next attack height.** The Anticipation and `step_clip` stand in for it, and it stays an Astra request.
- **The five-minute efficient-clear measurement.** F11-03's protocol and the human pass own it.
- Music (F13).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR`.
- Named tests cover these, with no Error-level warnings:
  - ENGINEERING_BRIEF Section 8 "boss phase overflow and exactly-once defeat";
  - PLANEJAMENTO Section 12 "Campaign runs from Stage 1 to final victory" and "each final boss executes three named attacks".
- Verify headless: a scripted Campaign run from CP2-B through three Phases to `Jornada concluída`. Record it in `docs/validation/bosses.md` under "Storm Guardian".
- Docs, GUIDE rows, a handoff log entry naming every Astra-owned value, `Status: done` with an Outcome, and the ROADMAP row.
- One commit, `bosses: [shared] integrate the Storm Guardian in S2-07`, then the lane's land step from `docs/engineering/SPRINT.md`.

## Handoff notes for Astra

`storm_guardian.tscn` gained only its root script and exports.

- **Tuning.** Tune `storm_guardian.tres` and the three `storm_*.tres` files, then drop `metadata/dev`.
- **Storm resolution.** For the "reduces storm intensity, reveals the sky" resolution, author an `AnimationPlayer` clip in `stage_02.tscn` and send Claude its path and clip name. Claude sets `defeat_presentation` and `defeat_animation`.
- **Ring cue.** A ring-shaped cue at the next attack height is still an open presentation request.

## Kickoff prompt

```
In your lane worktree, read AGENTS.md, docs/engineering/SPRINT.md (your lane section), docs/engineering/ROADMAP.md and .scratch/bosses/issues/07-storm-guardian.md. Check its dependencies with tools/lane.ps1 status F12-06 D-04, implement it test-first, run tools/test.ps1 until green with no SCRIPT ERROR, finish its Definition of Done, commit, then run tools/lane.ps1 land.
```
