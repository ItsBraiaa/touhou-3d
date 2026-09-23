# F8-01 Definition schemas and content validation

Status: todo
Type: core
parallel-safe: yes
Depends on: F0-02

## Goal

Typed `Resource` Definitions (ADR-0003) that express every Stage 1 and Stage 2 Encounter, Wave, reward bundle and Checkpoint in STAGE_DESIGN.md without inventing progression logic. Each Definition has a `validate()` that names what is wrong, and one test validates every `.tres` under `content/`, so broken content fails the suite before the Director ever refuses it. This ticket writes only the schemas; the Stage 1 values are F8-04.

## Read first

- `docs/adr/0003-typed-resources-for-authored-content.md`, `docs/engineering/CONVENTIONS.md` "Data and content"
- `docs/STAGE_DESIGN.md` "Shared encounter rules", both stage tables, "Checkpoint contract", "Agent implementation contract"
- `docs/STAGE_01_HANDOFF.md` (marker names relative to `Encounters/<ID>`: `Spawns/Wave1_Spirit1`, `RewardOrigin`, `ShieldPickup`; `Gates/Gate_S1_0N`; `Checkpoints/CP1-A`) and `docs/STAGE_02_HANDOFF.md` "Encounters and markers" (so the schema also fits Stage 2)
- `docs/GUIDE.md` Section 8; `CONTEXT.md` "Run and progression", "Content and structure"

## Files

- **Creates:** `scripts/definitions/encounter_definition.gd`, `scripts/definitions/wave_definition.gd`, `scripts/definitions/reward_definition.gd`, `scripts/definitions/checkpoint_definition.gd`, `scripts/definitions/stage_definition.gd`, `tests/unit/definitions/test_definitions.gd`, `tests/unit/definitions/test_content_validation.gd`, `docs/engineering/progression-core.md`.
- **Edits:** none.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F8-01 row), `docs/HANDOFF_LOG.md` (one entry), `docs/engineering/progression-core.md` (new) and its line in `docs/engineering/README.md`.
- **Must not touch:** `scripts/definitions/pattern_definition.gd` (F5-04), `enemy_definition.gd` (F9-01), `boss_definition.gd`, `boss_phase_definition.gd`, `attack_definition.gd` (F12-01), anything under `content/` (F8-04, F9-02, F12-03), every scene.
- **Conflicts with:** none. F5-04, F9-01 and F12-01 create other files in `scripts/definitions/`. Only the README line is shared, and it is written at session end.

## Deliverables

Every class is `extends Resource` with a `class_name`, `@export` fields and `validate() -> PackedStringArray`. An empty array means valid. Each message starts with the Definition's id, for example `"S1-02: wave 2 has 3 markers but 2 enemy kinds"`. Plain data only: no Node and no scene paths beyond relative `NodePath`s.

- `WaveDefinition`: `spawn_markers: Array[NodePath]` (relative to the Encounter root), `enemy_kinds: Array[StringName]` (one per marker: `&"spirit"`, `&"sentry"`, `&"lantern_guardian"`), `enemy_kind_at(index: int) -> StringName`, `enum Activation { ON_ENTRY, AFTER_PREVIOUS_WAVE }`, `activation`, `delay: float` (seconds after the activation event). Valid when there is at least one marker, the two arrays have the same size, no kind is empty, no marker is empty or repeated, and `delay >= 0`. Mixed Waves such as S1-05's two Spirits and one Sentry need a kind per marker, which is why this is not the sheet's single `enemy_kind`.
- `RewardDefinition`: `enum Kind { POWER, SHIELD }`, `kind`, `count: int` (≥ 1), `origin_marker: NodePath` (non-empty, for example `RewardOrigin` or `ShieldPickup`). Rewards are granted when their Encounter completes.
- `EncounterDefinition`: `id: StringName`, `next_id: StringName` (empty for the last Encounter), `enum Completion { TRAVERSAL, ALL_REQUIRED_ENEMIES, OBJECTIVES }`, `completion`, `requires_exit: bool` (the completion also needs the ExitVolume reached, in either order; S1-03 "both defeated and player reaches upper exit", S2-01), `waves: Array[WaveDefinition]`, `rewards: Array[RewardDefinition]`, `gate_id: StringName` (the node name under `Gates/`, empty for none), `checkpoint_id: StringName` (the Checkpoint that must be active before this Encounter can be entered, empty for none), `required_objective_ids: Array[StringName]`. Rules: a non-empty id; TRAVERSAL has no waves and no objectives; ALL_REQUIRED_ENEMIES has at least one wave; OBJECTIVES has at least one objective id; the first wave is ON_ENTRY; marker names are unique across all waves, because enemy ids come from them; and every wave and reward is valid.
- `CheckpointDefinition`: `id`, `after_encounter_id`, `resume_encounter_id`, `node_path: NodePath` (for example `Checkpoints/CP1-A`), `display_name: String` (Portuguese text for Defeat's retry location). All are non-empty.
- `StageDefinition`: `id: StringName` (`&"stage_01"`), `encounters: Array[EncounterDefinition]` in route order, `checkpoints: Array[CheckpointDefinition]`. Lookups: `find_encounter(id) -> EncounterDefinition` (null when missing), `encounter_index(id) -> int` (-1 when missing), `find_checkpoint(id) -> CheckpointDefinition`. `validate()` collects every child's errors and adds these: at least one Encounter; unique Encounter, Checkpoint and non-empty gate ids; each `next_id` equals the following Encounter's id and the last one is empty; each Checkpoint's `after_encounter_id` and `resume_encounter_id` exist with after < resume; the resume Encounter's `checkpoint_id` names that Checkpoint; and every non-empty `checkpoint_id` names a Checkpoint of this stage.
- `tests/unit/definitions/test_content_validation.gd` holds a static helper `collect_errors(root: String) -> PackedStringArray`. It walks `root` recursively, loads every `.tres`, and for each Resource that has `validate()` adds its errors prefixed with the file path; a file that fails to load is an error too. A missing `root` yields no errors, because `content/` does not exist until F8-04.
- Stage entry resources are **not** in `StageDefinition`: `RunState.ENTRY_POWER_LEVEL` and `CombatState.start()` stay their single source.

## Tests required

`tests/unit/definitions/test_definitions.gd` builds Definitions in code:

- `test_valid_stage_has_no_errors`: a two-Encounter fixture shaped like S1-01 and S1-02.
- `test_wave_kinds_must_match_markers`, `test_wave_rejects_empty_or_repeated_markers`, `test_first_wave_must_be_on_entry`.
- `test_traversal_rejects_waves`, `test_all_required_enemies_needs_a_wave`, `test_objectives_needs_objective_ids`.
- `test_reward_needs_a_count_and_an_origin`.
- `test_stage_rejects_duplicate_encounter_ids`, `test_next_id_must_follow_route_order`, `test_checkpoint_must_resume_after_its_encounter`, `test_resume_encounter_names_its_checkpoint`.
- `test_errors_name_the_definition`.

`tests/unit/definitions/test_content_validation.gd`:

- `test_every_content_resource_is_valid`: `collect_errors("res://content/")` is empty.
- `test_invalid_content_is_reported_with_its_path`: saves an invalid `EncounterDefinition` to `user://content_validation_fixture/bad.tres`, and `collect_errors` returns one message naming that file. Delete the fixture in `after_each`.

## Out of scope

`PatternDefinition`, `EnemyDefinition`, boss Definitions; per-Objective rewards (S2-03 "each seal drops 1 power item") and Wave activation by Seal approach, both Stage 2 integration, cut with F12-04; the Stage 1 values (F8-04); the Director's refusal of invalid content (F10-01 calls `validate()`).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR` in the output (an error after an assertion still reports PASS).
- A named test for every rule above; no Error-level GDScript warnings (`untyped_declaration`, `unused_variable`, `unused_parameter`, `shadowed_variable`).
- `docs/engineering/progression-core.md` written from `TEMPLATE.md` (the Definition schemas and validation rules), with its line in `docs/engineering/README.md`.
- Handoff log entry; this ticket set to `Status: done` with an Outcome section; ROADMAP row updated.
- One commit: `progression: add Definition schemas and content validation`.

## Handoff notes for Astra

The schema is what `content/*.tres` must follow. Enemy kinds are `spirit`, `sentry` and `lantern_guardian`; marker paths are relative to `Encounters/<ID>`; gate ids are the node names under `Gates/`. Any content that breaks a rule fails `tools/test.ps1` with the file path and the reason.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/progression-core/issues/01-definition-schemas-and-content-validation.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
