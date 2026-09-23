# F8-04 Stage 1 content draft (dev)

Status: todo
Type: content
parallel-safe: yes
Depends on: F8-01
Lane: oc-b
Model: DeepSeek V4.1 Flash (fallback GLM-5.3-Flash)

## Goal

Transcribe STAGE_DESIGN.md's Stage 1 table (S1-01 to S1-07) and the CP1-A and CP1-B rows into `content/stages/stage_01/` as typed `.tres` Definitions that validate. Every value is flagged dev, so Astra can tune the numbers while the structure stays exactly as approved. The Director (F10-01) loads `stage_01.tres`; F10-04 checks it against the scene.

## Read first

- `docs/STAGE_DESIGN.md` Stage 1 table, "Shared encounter rules", "Checkpoint contract" (table)
- `docs/STAGE_01_HANDOFF.md` "Spatial contract" (the markers per Encounter), "Gates and portal presentation", "Checkpoints"
- `docs/ENEMY_VISUAL_HANDOFF.md` (the visual variants are presentation only and not part of `enemy_kinds`)
- `docs/engineering/progression-core.md` (F8-01 schema and rules); `docs/engineering/CONVENTIONS.md` "Data and content"
- Grep `scenes/stages/stage_01.tscn` for `parent="Encounters/`, `Gates/Gate_S1_`, `Checkpoints/`: read the scene, do not edit it

## Files

- **Creates:** `content/stages/stage_01/stage_01.tres` (StageDefinition); `s1_01.tres` to `s1_07.tres` (one EncounterDefinition each, with waves and rewards as sub-resources); `cp1_a.tres` and `cp1_b.tres` (CheckpointDefinition), all in `content/stages/stage_01/`; `tests/unit/definitions/test_stage_01_content.gd`.
- **Edits:** none.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F8-04 row; the "Requests to Astra" row F8-04 already asks for the tuning), `docs/HANDOFF_LOG.md` (a `dev` entry announcing the draft), `docs/engineering/progression-core.md` (a "Stage 1 content" section).
- **Must not touch:** `scenes/stages/stage_01.tscn`, `scripts/definitions/*` (a schema gap is a dependency note), `content/enemies/`, `content/patterns/`, `content/bosses/` (F9-02, F12-03).
- **Conflicts with:** none. F10-04 adds its own test file later.

## Deliverables

Write the `.tres` files as Godot 4 text resources (`[gd_resource type="Resource" script_class=... format=3]`, `ExtResource` for the script, sub-resources for waves and rewards). Or create them once with a scratch headless script that is **not** committed: no generator may ever overwrite Astra's tuning. Every file carries `metadata/dev = true`.

| ID | Completion | Waves: markers under `Spawns/` → kinds, activation | Rewards | Gate | Checkpoint needed |
| --- | --- | --- | --- | --- | --- |
| S1-01 | TRAVERSAL | none | none | none | none |
| S1-02 | ALL_REQUIRED_ENEMIES | 1: `Wave1_Spirit1..3` spirit, ON_ENTRY; 2: `Wave2_Spirit1..3` spirit, AFTER_PREVIOUS_WAVE | POWER 5 at `RewardOrigin` | `Gate_S1_02` | none |
| S1-03 | ALL_REQUIRED_ENEMIES, `requires_exit` | 1: `Wave1_Sentry1..2` sentry, ON_ENTRY | SHIELD 1 at `ShieldPickup` | `Gate_S1_03` | none |
| S1-04 | ALL_REQUIRED_ENEMIES | 1: `Wave1_Sentry1..3` sentry, ON_ENTRY | none (crossing the gate activates CP1-A) | `Gate_S1_04` | none |
| S1-05 | ALL_REQUIRED_ENEMIES | 1: `Wave1_Spirit1`, `Wave1_Spirit2` spirit + `Wave1_Sentry1` sentry, ON_ENTRY; 2: the same with `Wave2_`, AFTER_PREVIOUS_WAVE | POWER 5 at `RewardOrigin` | `Gate_S1_05` | CP1-A |
| S1-06 | TRAVERSAL | none | none | none | none |
| S1-07 | ALL_REQUIRED_ENEMIES | 1: `Wave1_Boss1` lantern_guardian, ON_ENTRY | none (boss score is F12's) | none | CP1-B |

- `next_id` chains S1-01 → S1-07; S1-07's is empty.
- `cp1_a.tres`: `after_encounter_id` S1-04, `resume_encounter_id` S1-05, `node_path` `Checkpoints/CP1-A`. `cp1_b.tres`: after S1-05, resume S1-07, `Checkpoints/CP1-B`. CP1-B lies inside S1-06, which is a plain traversal completed by its ExitVolume. `display_name` is the id itself (`"CP1-A"`, `"CP1-B"`), matching MenuController's `Último checkpoint · <id>`, until Astra names the places.
- Wave delays: 0 for ON_ENTRY. The AFTER_PREVIOUS_WAVE delay is Claude's proposal, 1.0 s, for Astra to tune. The Anticipation (1 s) belongs to the enemy, not the Wave.
- 17 common enemies plus one boss, and 10 Power Pickups: exactly Power Level 1 to 3 at `CombatState.PICKUPS_PER_LEVEL` = 5 (STAGE_DESIGN S1-02 and S1-05).

## Tests required

`tests/unit/definitions/test_stage_01_content.gd` loads `res://content/stages/stage_01/stage_01.tres`:

- `test_stage_01_content_is_valid` (`validate()` is empty)
- `test_encounters_follow_the_stage_design_order` (ids S1-01 to S1-07 and `next_id`)
- `test_completion_conditions_match_the_stage_design`
- `test_waves_match_the_handoff_markers` (the marker paths and kinds in the table, 17 plus 1)
- `test_second_waves_start_after_the_first` (S1-02 and S1-05)
- `test_power_rewards_reach_level_three` (10 POWER in total, S1-02 and S1-05 each 5; one SHIELD at S1-03 `ShieldPickup`)
- `test_gates_follow_their_encounters`
- `test_checkpoints_resume_where_the_design_says` (CP1-A resumes S1-05, CP1-B resumes S1-07, and the guarded Encounters name them)
- `test_every_file_is_flagged_dev`

`tests/unit/definitions/test_content_validation.gd` (F8-01) must stay green over the new files.

## Out of scope

Enemy health, patterns and boss phases (F9-02, F12-03); the scene-versus-content check (F10-04); Stage 2 content (cut with F12-04, pending the user); tuning any number beyond transcription.

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR` in the output; the named tests above; no Error-level warnings.
- `docs/engineering/progression-core.md` gains "Stage 1 content" (file list and the dev flag).
- Handoff log entry, State `dev`, announcing the draft and naming each value Astra owns; `Status: done` with an Outcome; ROADMAP row.
- One commit: `content: [shared] draft Stage 1 encounter content (dev)`. `content/*.tres` values are Astra's.

## Handoff notes for Astra

These files are yours to tune (values), and `metadata/dev = true` marks them as Claude's draft. Structure that is approved and must stay: seven Encounters in order, the completion conditions, the wave counts and markers, 5 + 5 Power Pickups, one Shield Pickup, the Gates, and the CP1-A and CP1-B resume points. Free to change: the second-wave delay, and the checkpoint `display_name` (Portuguese place names welcome). Delete the `dev` flag once you have reviewed a file. `tools/test.ps1` tells you if an edit breaks a rule.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/progression-core/issues/04-stage-01-content-draft.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
