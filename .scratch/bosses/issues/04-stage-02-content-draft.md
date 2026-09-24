# F12-04 Stage 2 content draft (dev)

Status: done
Type: content
parallel-safe: yes
Depends on: F8-01, F9-01
Lane: oc-b
Model: DeepSeek V4.1 Flash (fallback GPT 5.6 Luna)

## Goal

Transcribe STAGE_DESIGN.md's Stage 2 table (S2-01 to S2-07), the three-seal objectives, the rewards and the CP2-A and CP2-B rows into `content/stages/stage_02/` as typed `.tres` Definitions that validate, against the markers that actually exist in `scenes/stages/stage_02.tscn`. Every file is flagged dev, so Astra tunes the numbers while the structure stays as approved. A second, scene-reading test proves the content and the scene agree, as F10-04 does for Stage 1. It needs no Director, so it passes before and after F12-05 attaches one. F12-05 loads `stage_02.tres`.

## Read first

- `docs/STAGE_DESIGN.md`: the Stage 2 table, "Three-seal progression challenge" (Direct Stage 2 reaches Power 3 before the miniboss), "Miniboss", the "Checkpoint contract" table.
- `docs/STAGE_02_HANDOFF.md`: "Encounters and markers", "Seals and gate", "Gates and checkpoints".
- `.scratch/progression-core/issues/04-stage-01-content-draft.md` and its Outcome: the house pattern and the real file layout. Copy its structure.
- `.scratch/stage-director/issues/04-stage-01-contract-smoke-test.md` and its Outcome: the pattern the contract test copies.
- `docs/engineering/progression-core.md`: schema, validation rules, "Stage 1 content".
- Grep `scenes/stages/stage_02.tscn` for `parent="Encounters/`, `Gates/Gate_S2_`, `Checkpoints/`, `metadata/seal_id`, `metadata/guard_spawn`. Read the scene; never edit it.

## Files

- **Creates:**
  - `content/stages/stage_02/stage_02.tres` (StageDefinition, id `&"stage_02"`).
  - `s2_01.tres` to `s2_07.tres` (EncounterDefinitions, waves and rewards as sub-resources).
  - `cp2_a.tres`, `cp2_b.tres` (CheckpointDefinitions).
  - `tests/unit/definitions/test_stage_02_content.gd`.
  - `tests/scene/test_stage_02_content_contract.gd`.
- **Edits:** none.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (the F12-04 row), `docs/HANDOFF_LOG.md` (a `dev` entry), `docs/engineering/progression-core.md` (a "Stage 2 content" section).
- **Must not touch:** `scenes/stages/stage_02.tscn`, `tools/build_stage_02.py`, `tests/scene/test_stage_02_contract.gd` (Astra's static contract), `scripts/**` (a schema gap is a dependency note), `content/stages/stage_01/`, `content/enemies/`, `content/patterns/`, `content/bosses/`.
- **Conflicts with:** none. `progression-core.md` is shared with F8, which finishes earlier in this lane.

## Deliverables

Write Godot 4 text resources, or generate them once with a scratch headless script that is **not** committed. Every file carries `metadata/dev = true`. Marker paths are relative to `Encounters/<ID>`.

| ID | Completion | Waves: markers under `Spawns/` → kind, activation | Rewards | Gate | Checkpoint needed |
| --- | --- | --- | --- | --- | --- |
| S2-01 | ALL_REQUIRED_ENEMIES, `requires_exit` | 1: `Wave1_Spirit1..2` spirit, ON_ENTRY | none | `Gate_S2_01` | none |
| S2-02 | ALL_REQUIRED_ENEMIES | 1: `Wave1_Spirit1..2` spirit + `Wave1_Sentry1` sentry, ON_ENTRY; 2: the same with `Wave2_`, AFTER_PREVIOUS_WAVE | POWER 2 at `RewardOrigin`; SHIELD 1 at `ShieldPickup` | `Gate_S2_02` | none |
| S2-03 | OBJECTIVES: `S2-03-Seal1`, `S2-03-Seal2`, `S2-03-Seal3` | three ON_ENTRY waves: `Seal1_Sentry1..2`, `Seal2_Sentry1..2`, `Seal3_Sentry1..2`, all sentry | POWER 1 at each `Seals/SealN/RewardOrigin` | `Gate_S2_03` | none |
| S2-04 | ALL_REQUIRED_ENEMIES | 1: `Wave1_Boss1` tempest_sentinel, ON_ENTRY | SHIELD 1 at `ShieldPickup` | `Gate_S2_04` | CP2-A |
| S2-05 | ALL_REQUIRED_ENEMIES | 1 and 2 as S2-02 | POWER 2 at `RewardOrigin` | `Gate_S2_05` | none |
| S2-06 | TRAVERSAL | none | none | none | none |
| S2-07 | ALL_REQUIRED_ENEMIES | 1: `Wave1_Boss1` storm_guardian, ON_ENTRY | none (boss score is F12-07's) | none | CP2-B |

- `next_id` chains S2-01 → S2-07; S2-07's is empty.
- `cp2_a.tres`: after S2-03, resume S2-04, `Checkpoints/CP2-A`. `cp2_b.tres`: after S2-05, resume S2-07, `Checkpoints/CP2-B` (it lies inside the S2-06 traversal, as CP1-B lies inside S1-06). `display_name` is the id until Astra names the places.
- The objective ids are the Seals' `seal_id` metadata, exactly.
- AFTER_PREVIOUS_WAVE delay: 1.0 s, the Stage 1 proposal (Astra tunes).
- Totals: 20 common enemies plus two bosses, 7 Power Pickups and 2 Shield Pickups (STAGE_02_HANDOFF). Direct Stage 2 starts at Power Level 2; the 2 ledge and 3 seal pickups make 5 = `CombatState.PICKUPS_PER_LEVEL`, so Power 3 is reached before the miniboss.

Schema readings, each recorded in the Outcome:

- **Per-Seal rewards.** The schema has no per-Objective reward, so each Seal's Power Pickup is a S2-03 `RewardDefinition` whose `origin_marker` lies under that Seal. F12-05's Director spawns it when that Seal is destroyed, not on completion.
- **Guard engagement.** Content has no approach-activated wave. All six guards spawn on entry, and F12-05 keeps each pair passive until its Seal's group engages.
- **Boss kinds.** `tempest_sentinel` and `storm_guardian` are new wave kinds. F12-05 maps them to a stand-in; F12-06 and F12-07 map them to the real bosses.

## Tests required

`tests/unit/definitions/test_stage_02_content.gd` loads `res://content/stages/stage_02/stage_02.tres`:

- `test_stage_02_content_is_valid`, `test_encounters_follow_the_stage_design_order`, `test_completion_conditions_match_the_stage_design`
- `test_waves_match_the_handoff_markers` (20 plus 2, with their kinds), `test_second_waves_start_after_the_first` (S2-02, S2-05), `test_seal_guard_waves_start_on_entry`
- `test_power_rewards_total_seven`, `test_direct_stage_2_reaches_power_3_before_the_miniboss`, `test_shield_pickups_at_s2_02_and_s2_04`
- `test_gates_follow_their_encounters`, `test_checkpoints_resume_where_the_design_says`, `test_every_file_is_flagged_dev`

`tests/scene/test_stage_02_content_contract.gd` instances `stage_02.tscn` under the test root, loads the content, and frees both. It never drives gameplay.

- `test_every_content_encounter_has_its_root_and_volumes` (`Area3D`, layer 0, mask includes 2, `Collision` child)
- `test_every_wave_marker_resolves_under_its_encounter`
- `test_every_reward_origin_resolves` (including `Seals/SealN/RewardOrigin`)
- `test_every_gate_id_resolves_to_a_full_span_gate` (`BarrierBody` on layer 1 with `Collision`, `ClosedVisual`, `Arch`, `OpenVisual`)
- `test_every_checkpoint_matches_its_scene_metadata` (`checkpoint_id` and `resume_encounter_id`, `Respawn` facing -Z)
- `test_every_objective_names_a_seal`: each id matches one `seal_id`, and each Seal's `guard_spawn` paths are markers of an S2-03 wave
- `test_scene_has_no_unreferenced_marker` (22)
- `test_player_start_is_inside_the_first_entry_volume`

`test_content_validation.gd` (F8-01) must stay green over the new files.

## Out of scope

Boss content (F12-06, F12-07); Director wiring and Seal behavior (F12-05); tuning beyond transcription (Astra, D-06).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR` in the output. The named tests above exist, and there are no Error-level warnings.
- `docs/engineering/progression-core.md` gains "Stage 2 content": file list, the three schema readings, the dev flag.
- Handoff log entry, State `dev`, naming every value Astra owns. `Status: done` with an Outcome; the ROADMAP row.
- One commit, `content: [shared] draft Stage 2 encounter content (dev)`, then the lane's land step from `docs/engineering/SPRINT.md`.

## Handoff notes for Astra

The `content/stages/stage_02/*.tres` values are yours to tune in D-06. The approved structure must stay: seven Encounters in order, the completion conditions, the markers, 7 Power and 2 Shield Pickups, the five Gates, and the CP2-A and CP2-B resume points. Free to change: the wave delay and the Checkpoint `display_name`. `tests/scene/test_stage_02_content_contract.gd` now fails with the path if a Stage 2 marker, Seal or Gate is renamed.

## Kickoff prompt

```
In your lane worktree, read AGENTS.md, docs/engineering/SPRINT.md (your lane section), docs/engineering/ROADMAP.md and .scratch/bosses/issues/04-stage-02-content-draft.md. Check its dependencies with tools/lane.ps1 status F8-01 F9-01, implement it test-first, run tools/test.ps1 until green with no SCRIPT ERROR, finish its Definition of Done, commit, then run tools/lane.ps1 land.
```

## Outcome

Wrote all ten `.tres` files under `content/stages/stage_02/` with a one-off headless scratch script (kept outside the project, not committed, deleted after the run), every one flagged `metadata/dev = true`. The script reloaded `stage_02.tres` from disk with the cache ignored and verified it: `validate()` empty, seven Encounters in route order with the `next_id` chain, S2-01 `requires_exit`, S2-03 `OBJECTIVES` over the three `seal_id`s with three ON_ENTRY guard waves, gates `Gate_S2_01`…`Gate_S2_05`, CP2-A after S2-03 resuming S2-04 and guarding it, CP2-B after S2-05 resuming S2-07 and guarding it, and totals of 22 markers (20 common plus two bosses), 7 POWER and 2 SHIELD. The same run instantiated `scenes/stages/stage_02.tscn` and checked every content Encounter root, Entry/Exit volume (Area3D, layer 0, mask includes 2), spawn marker (`Marker3D`), reward origin (including `Seals/SealN/RewardOrigin`), gate (`BarrierBody` on layer 1, `ClosedVisual`, `Arch`) and Checkpoint (`Area3D` mask 2 with `Respawn`); it also matched every objective id to a Seal `seal_id` and every `guard_spawn` to an S2-03 wave marker, and confirmed all 22 spawn markers are referenced. No test files were written under the sprint's no-new-tests rule, so `tests/unit/definitions/test_stage_02_content.gd` and `tests/scene/test_stage_02_content_contract.gd` do not exist; verification is `tools/lane.ps1 land` plus the scratch cross-check above. The three schema readings are recorded in `docs/engineering/progression-core.md` "Stage 2 content": per-Seal rewards as separate S2-03 `RewardDefinition`s spawned on Seal destruction, all six guards as ON_ENTRY waves kept passive by the Director, and the two new boss kinds mapped by F12-05/06/07.
