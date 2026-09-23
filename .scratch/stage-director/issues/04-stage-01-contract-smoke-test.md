# F10-04 Stage 1 contract smoke test

Status: todo
Type: test
parallel-safe: yes (one new test file; reads the scene and the content, writes neither)
Depends on: F8-04
Lane: oc-a
Model: GPT 5.6 Luna (fallback DeepSeek V4.1 Flash)

## Goal

A headless test proves that `scenes/stages/stage_01.tscn` and `content/stages/stage_01/stage_01.tres` agree. Every Encounter, Wave marker, reward origin, Gate and Checkpoint the content names exists in the scene with the node types, collision layers and masks the Director relies on. The scene has no Encounter or spawn marker that the content forgets. A scene regeneration by Astra (`tools/build_stage_01.py` is not to be rerun without reconciling) or a content edit that breaks the link fails `tools/test.ps1` at once, with the path, before anyone flies the stage.

The test reads the scene and never drives gameplay. It is written so that it passes before F10-01 attaches the Director and still passes afterwards.

## Read first

- `docs/STAGE_01_HANDOFF.md` entirely: the spatial contract table, 18 spawn markers, four Gates, two Checkpoints, the PortalLinks.
- `docs/engineering/progression-core.md`: `StageDefinition`, `EncounterDefinition`, `WaveDefinition.spawn_markers` and `enemy_kinds`, `RewardDefinition.origin_marker`, `CheckpointDefinition.node_path`, `find_encounter` and `find_checkpoint`.
- `.scratch/progression-core/issues/04-stage-01-content-draft.md` and its Outcome (the real file names).
- `docs/engineering/CONVENTIONS.md` "Collision" (scenery layer 1, player body layer 2) and "Tests".
- `tests/scene/test_stage_02_contract.gd` (the house style for a stage contract test).

## Files

- **Creates:** `tests/scene/test_stage_01_contract.gd`.
- **Edits:** none.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F10-04 row.
  - `docs/HANDOFF_LOG.md`: one entry telling Astra the test exists.
  - `docs/engineering/stage-director.md`: a "Stage 1 scene contract" section. If F10-01 has not created the file yet, create it from `TEMPLATE.md` with only this section and add its line to `docs/engineering/README.md`.
- **Must not touch:** `scenes/stages/stage_01.tscn`, `content/**`, `scripts/**`, `tools/build_stage_01.py`, `tools/validate_stage_01.gd` (Astra's offline QA).
- **Conflicts with:** none among parallel-safe tickets. The module doc is shared with F10-01 to F10-03; those are not parallel-safe, so they never run at the same time as this one. A defect found in the scene or the content is reported, not fixed.

## Deliverables

`tests/scene/test_stage_01_contract.gd` extends `TestCase`. `before_each` instances `stage_01.tscn`, adds it under the test's root so global transforms work, and loads the `StageDefinition`. `after_each` frees the scene. Without `setup()`, the Director's `_ready` (after F10-01) does nothing. Each failure message names the node path or the content id.

## Tests required

- `test_scene_has_the_stage_layout`: `Stage` has `Environment`, `Geometry`, `PlayerStart` (a `Marker3D`), `Encounters`, `Checkpoints`, `Gates`, and an empty `RuntimeActors`, all at the origin.
- `test_every_content_encounter_has_its_root_and_volumes`: each `Encounters/<id>` has `EntryVolume` and `ExitVolume`. Each is an `Area3D` with a `Collision` `CollisionShape3D` child, `collision_layer` 0 and a `collision_mask` that includes the player body (value 2). Each root also has a `Spawns` node.
- `test_every_wave_marker_resolves_under_its_encounter`: each marker is a `Marker3D`.
- `test_every_reward_origin_resolves`: S1-02's and S1-05's `RewardOrigin`, and S1-03's `ShieldPickup`.
- `test_every_gate_id_resolves_to_a_full_span_gate`: `Gates/<id>` has a `BarrierBody` `StaticBody3D` on layer 1 with a `Collision` shape, a `ClosedVisual` and an `Arch`.
- `test_every_checkpoint_resolves_with_a_respawn`: the node at `node_path` is an `Area3D` named as the id, with mask 2 and a `Respawn` `Marker3D`.
- `test_scene_has_no_unreferenced_encounter_or_marker`: every child of `Encounters` is a content Encounter, and every child of every `Spawns` is used by exactly one wave, 18 in all.
- `test_s1_04_guard_links_exist`: `Environment/PortalLinks/GuardLink1..3`.
- `test_encounters_follow_the_route`: each EntryVolume's global Z is below the previous one's (route -Z).
- `test_respawns_face_the_route`: each `Respawn`'s forward (-Z basis) has a dot product above 0.99 with (0, 0, -1).
- `test_player_start_is_inside_the_first_entry_volume`: F10-01's `start_attempt()` relies on this.

## Out of scope

Gameplay, spawning and completion (F10-01 to F10-03), Stage 2 (its own contract test exists; gameplay is cut with F12-04), and the Director's runtime `check_setup()`, which overlaps this test on purpose, because this one runs without a Director.

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR`. Every check above is a named test. No Error-level warnings.
- Module doc section, handoff log entry, `Status: done` with an Outcome, ROADMAP row.
- One commit: `test: add Stage 1 scene and content contract test`.

## Handoff notes for Astra

`tests/scene/test_stage_01_contract.gd` now guards Stage 1. Run `tools/test.ps1 -Filter stage_01` after any scene edit. A rename of an Encounter, marker, Gate, Checkpoint, `Respawn` or `GuardLink` fails it with the path. Coordinate the matching content change with Claude.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/stage-director/issues/04-stage-01-contract-smoke-test.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
