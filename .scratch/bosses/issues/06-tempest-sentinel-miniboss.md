# F12-06 Tempest Sentinel miniboss in S2-04

Status: todo
Type: integration
parallel-safe: no
Depends on: F12-05, F12-02, F12-03, D-04
Lane: sol
Model: GPT Sol (Codex)

> **Ruling 3 follow-up (D-07 Part B), part of this ticket:** Astra authored `metadata/two_phase_offset_left` and `metadata/two_phase_offset_right` on `Phase1` and `Phase2` in `hud.tscn`. In `Hud.show_boss`, when `phase_count == 2`, apply those offsets. Keep the default layout for three Phases. This is `scripts/ui/hud.gd`, edited here with SPRINT's sprint permission. Name it in the handoff entry.

## Goal

The Sentinela da Tempestade replaces F12-05's stand-in in S2-04.

- **The scene.** Astra's `scenes/enemies/tempest_sentinel.tscn` (D-04: the Sentry look, enlarged, with rotating ornaments) gets `boss_controller.gd`.
- **The content.** Its two-Phase `BossDefinition` and patterns land as dev content.
- **The fight.** Entering S2-04 behind CP2-A spawns it at `Wave1_Boss1`. The HUD shows a two-Phase panel and each Attack cue, and the Phase change clears hostile fire.
- **Completion.** The final-Phase defeat awards 500 once, drops the Shield Pickup once, opens `Gate_S2_04` and completes S2-04. The ExitVolume never completes it.
- **No Checkpoint after it.** A death before CP2-B repeats the duel.

This ticket writes no GDScript. The Director's boss branch and the Session's boss HUD wiring are F12-03's, which is why F12-03 is a dependency.

## Read first

- `docs/STAGE_DESIGN.md`:
  - "Miniboss — Sentinela da Tempestade": 20 and 30 s targets; Phase 1 alternating aimed bursts with charge flashes; Phase 2 rotating fans with broad gaps and occasional altitude shifts; it tracks the player's general altitude.
  - The Stage 2 table row S2-04.
  - "Three-seal progression challenge": Power 3 before the miniboss.
- `docs/MODEL_SELECTION.md`: the Tempest Sentinel row.
- `docs/engineering/bosses.md`: F12-01 Definitions, F12-02 `BossController`, F12-03 boss branch, `boss_definitions` and Session wiring.
- `docs/engineering/stage-director.md` "Stage 2" (F12-05: the stand-in, the Retry test seam).
- `docs/engineering/weapon-rendering.md`: F6-03 shot damage and cadence, for the health proposal.
- `.scratch/projectile-field/issues/04-pattern-emitter-core.md` Outcome: `PatternDefinition` fields; "Sentinela phase 2 rotating fans" is FAN or SPIRAL with `rotation_step_degrees`.
- The D-04 entry in `docs/HANDOFF_LOG.md`: tree, `AnimationPlayer` path, clip names, radius.
- `content/bosses/lantern_guardian.tres` (F12-03): the file shape to copy.

## Files

- **Creates:**
  - `content/bosses/tempest_sentinel.tres`, with its Phases, Attacks and steps as sub-resources.
  - `content/patterns/sentinel_aimed_burst.tres` and `sentinel_rotating_fan.tres`. Every file is `metadata/dev = true`.
  - `tests/unit/definitions/test_tempest_sentinel_content.gd` and `tests/scene/test_s2_04_miniboss_integration.gd`.
- **Edits:**
  - `scenes/enemies/tempest_sentinel.tscn` [shared]: attach `boss_controller.gd` to `Enemy` and set its exports from D-04's handoff. Nothing else changes.
  - `scenes/stages/stage_02.tscn` [shared], StageDirector exports only:
    - Remove the stand-in's `actor_scenes` and `enemy_definitions` entries for `tempest_sentinel`.
    - Set `actor_scenes[&"tempest_sentinel"]` = `scenes/enemies/tempest_sentinel.tscn` and `boss_definitions[&"tempest_sentinel"]` = `content/bosses/tempest_sentinel.tres`.
  - `tests/scene/test_stage_02_director.gd` (F12-05): only the cases that fought the stand-in in S2-04.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F12-06 row.
  - `docs/HANDOFF_LOG.md`: a [shared] entry.
  - `docs/engineering/bosses.md`: a "Tempest Sentinel" section.
  - `docs/GUIDE.md`: Section 6 row `boss_controller.gd` and Section 10 "Common enemies and miniboss".
- **Must not touch:**
  - Every `scripts/**` file. A defect is a note in the Outcome and a separate fix.
  - Trunk's `game_session.gd`, `main.tscn` and `stage_01.tscn`.
  - `hud.gd` and `hud.tscn`; `content/stages/**` (F12-04).
  - Anything in `tempest_sentinel.tscn` beyond the root script and its exports.
- **Conflicts with:** F12-07 (`stage_02.tscn` exports, `test_stage_02_director.gd`), serialized by its Depends on.

## Deliverables

- **`tempest_sentinel.tres`.** kind `tempest_sentinel`, `display_name` `"Sentinela da Tempestade"`, `score` 500 (STAGE_DESIGN S2-04), `entry_seconds` 1.0. STAGE_DESIGN names no Attack for the miniboss, so the two Attack names are Claude's proposals, logged for Astra's approval. D-06 tunes numbers only, never names.
  1. `"Clarão Carregado"`: two `sentinel_aimed_burst` (AIMED) steps. Each has a long `anticipation_seconds`, which is the charge flash (`step_clip` plays), and they alternate a positive and a negative `height_offset`, then a short `reposition_seconds`.
  2. `"Leques do Vendaval"`: `sentinel_rotating_fan` (FAN with `rotation_step_degrees`, few projectiles per volley for broad gaps). The steps alternate `follow_player_height = true`, which tracks the player's general altitude, and a fixed `height_offset`, which is the occasional altitude shift. Then `reposition_seconds`.
  - Phase health is a proposal: about 20 s and 30 s of Power Level 3 fire, from F6-03's recorded damage and cadence, with the Power Level 2 durations recorded beside it. Pattern numbers and `transition_seconds` are proposals too. Astra tunes them all.
- **The root.** `boss_controller.gd` gets `visual_root`, `hit_volume`, `emitter`, `animation_player`, `idle_clip`, `step_clip` and `defeat_clip` exactly as D-04 names them. F12-02's missing-clip warning must not appear.
- **Behavior comes from landed code.**
  - S2-04's content (F12-04): SHIELD 1 at `ShieldPickup`, `Gate_S2_04`, CP2-A.
  - The Director's boss branch (F12-03): score from `get_score()`, the boss signals.
  - The Session's HUD wiring (F12-03): `show_boss(name, 2)` hides `Phase3`.

## Tests required

`tests/unit/definitions/test_tempest_sentinel_content.gd`: `test_tempest_sentinel_content_is_valid`, `test_two_phases_with_named_attacks`, `test_miniboss_score_is_500`, `test_every_file_is_flagged_dev`.

`tests/scene/test_s2_04_miniboss_integration.gd` runs headless on `main.tscn` with a Direct Stage 2, resumed at CP2-A through the test seam F12-05's Outcome names:

- `test_sentinel_prefab_follows_the_guide_tree`: a `BossController` root, `VisualRoot`, a `HitVolume` sphere on layer 16 with monitoring off, `Emitters/Main`, and every configured clip present.
- `test_entering_s2_04_spawns_the_sentinel_at_its_marker`: one boss under `RuntimeActors` at (0, 76, -408).
- `test_boss_panel_shows_two_phases`: the name, `Phase1` and `Phase2` visible, `Phase3` hidden, the first Attack cue.
- `test_phase_change_clears_hostile_fire_and_announces_phase_2`.
- `test_excess_damage_cannot_skip_the_second_phase`: one hit of ten times Phase 1's health leaves Phase 2 full.
- `test_defeat_completes_s2_04_once`: +500 once, one Shield Pickup, `Gate_S2_04` open, `boss_defeated` once, the panel hidden.
- `test_exit_volume_does_not_complete_s2_04`.
- `test_death_before_cp2_b_repeats_the_duel`: Retry resumes at CP2-A, `Gate_S2_04` is closed, and a fresh Sentinel with two full Phases returns. The 500 is rolled back.
- `test_stand_in_is_gone`.

## Out of scope

- GDScript changes.
- Astra's tuning (D-06).
- The Storm Guardian (F12-07).
- Retreat containment.
- Boss music (F13).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR`. Named tests cover ENGINEERING_BRIEF Section 8 "boss phase overflow and exactly-once defeat" and STAGE_DESIGN "includes one two-phase miniboss". No Error-level warnings.
- Verify headless: a scripted run from CP2-A through both Phases shows one clear per transition and both cue names, then one defeat and the Gate opening. Record it in `docs/validation/bosses.md` under "Tempest Sentinel".
- `bosses.md`, the GUIDE rows, the handoff log naming every Astra-owned value, `Status: done` with an Outcome, the ROADMAP row.
- One commit, `bosses: [shared] integrate the Tempest Sentinel in S2-04`, then the lane's land step from `docs/engineering/SPRINT.md`.

## Handoff notes for Astra

`tempest_sentinel.tscn` gained only its root script and exports. Keep its node names. Tune `tempest_sentinel.tres` and `sentinel_*.tres` (D-06) and drop `metadata/dev` once you have reviewed them. `Clarão Carregado` and `Leques do Vendaval` are proposals, because STAGE_DESIGN names no miniboss Attack: approve them, or send Claude the names you want in the handoff log.

## Kickoff prompt

```
In your lane worktree, read AGENTS.md, docs/engineering/SPRINT.md (your lane section), docs/engineering/ROADMAP.md and .scratch/bosses/issues/06-tempest-sentinel-miniboss.md. Check its dependencies with tools/lane.ps1 status F12-05 F12-02 F12-03 D-04, implement it test-first, run tools/test.ps1 until green with no SCRIPT ERROR, finish its Definition of Done, commit, then run tools/lane.ps1 land.
```
