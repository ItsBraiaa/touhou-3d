# F9-03 SealRules core and Seal adapter

Status: done
Type: core+adapter
parallel-safe: no
Depends on: F9-02
Lane: oc-a
Model: part 1 GPT 5.6 Luna (fallback DeepSeek V4.1 Flash); part 2 GPT 5.6 Luna (fallback MiMo-V2.6-Pro)

> **Split (SPRINT.md):**
> - **Part 1, lane oc-a, GPT 5.6 Luna:** the SealRules core and its six-order test. Commit with `(F9-03 part 1)`.
> - **Part 2, lane oc-a, GPT 5.6 Luna:** the Seal adapter. It closes the ticket. No tests (SPRINT "No new tests").

## Goal

Consumed by F12-05 (Stage 2 S2-03). That ticket attaches `seal.gd` in `stage_02.tscn`, spawns the Guards and wires each Seal to the Director.

The Stage 2 three-seal rules. A Seal is shielded while either linked Guard lives. Its group of Guards activates once, on approach or when a Guard is shot. Once both Guards are dead the exposed Seal becomes a stationary `targetable` target with low health, destroyed exactly once by fire or a Bomb. A Bomb never reveals it early. All six destruction orders open the gate exactly once. Stage 1's S1-04 portal guards are **not** Seals: they are an ALL_REQUIRED_ENEMIES Encounter whose PortalLinks the Director hides (F10-02).

## Read first

- `docs/STAGE_DESIGN.md` "Three-seal progression challenge", "Shared encounter rules" (bombs "do not skip progression flags or reveal an objective before its guards have been cleared"), acceptance "All six seal orders"
- `docs/STAGE_02_HANDOFF.md` "Seals and gate": `Encounters/S2-03/Seals/Seal1..3` with `seal_id` metadata `S2-03-Seal1..3`, children `Core`, `ShieldVisual`, `OrbitRing`, `HitVolume/Collision` (sphere 1.7, layer 16, monitoring off), `ApproachVolume/Collision`, `RewardOrigin`, `GuardLinks/Guard1..2` whose `guard_spawn` metadata is a NodePath relative to S2-03 (`Spawns/Seal1_Sentry1`)
- `docs/GUIDE.md` Section 6 row `seal.gd`, Section 7 "Seal destroyed"; `docs/ENGINEERING_BRIEF.md` Section 4.G
- `docs/engineering/progression-core.md` (`EncounterMachine.enemy_id`, `notify_objective`), `docs/engineering/enemies.md` (EnemyActor ids), `docs/engineering/weapon-rendering.md` (`register_target`)

## Files

- **Creates:** `scripts/progression/seal_rules.gd`, `scripts/progression/seal.gd`, `tests/unit/progression/test_seal_rules.gd`, `tests/scene/test_seal_contract.gd`.
- **Edits:** none.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F9-03 row), `docs/HANDOFF_LOG.md`, `docs/engineering/enemies.md` ("Seal" section), `docs/GUIDE.md` Section 6 row `seal.gd` and Section 7 "Seal destroyed".
- **Must not touch:** `scenes/stages/stage_02.tscn` (attaching the script is F12-05's; the test attaches it at runtime and never saves), `scenes/stages/stage_01.tscn`, `scripts/progression/encounter_machine.gd`, `scripts/enemies/enemy_actor.gd` and `enemy_model.gd` (Guard passivity is F12-05's), `scripts/progression/stage_director.gd`.
- **Conflicts with:** none scheduled. It reads F8-02 and F9-02 files only.

## Deliverables

- `class_name SealRules extends RefCounted`, `enum State { DORMANT, GUARDED, EXPOSED, DESTROYED }`:
  - `setup(seal_id: StringName, guard_ids: Array[StringName], health: int)` asserts at least one guard and `health > 0`, and starts DORMANT, shielded.
  - `notify_approached() -> bool` and `notify_guard_shot(enemy_id) -> bool` move DORMANT to GUARDED and emit `guards_activated(seal_id)` once. True only for the activating call.
  - `notify_guard_defeated(enemy_id) -> bool` counts each linked Guard once (a Bomb kill of a dormant Guard counts and activates the group) and emits `guard_link_cleared(enemy_id)`. When every Guard is counted: EXPOSED, `shield_dropped(seal_id)` once.
  - `take_damage(amount: int)` is ignored unless EXPOSED. At 0: DESTROYED, `destroyed(seal_id)` once.
  - `is_shielded()`, `is_targetable()` (EXPOSED only), `get_state()`, and `capture()`/`restore()` of `{state, defeated_guards: PackedStringArray, health}`, deep-copied; restore emits nothing.
- `class_name Seal extends Node3D` on `Encounters/S2-03/Seals/SealN`:
  - Exports: `seal_id: StringName`, `health: int` (Claude's proposal, low, about 1 s of Power Level 2 fire; Astra tunes), `shield_visual: Node3D`, `core_visual: Node3D`, `hit_volume: Area3D`, `approach_volume: Area3D`, `guard_links: Node3D`. Each is checked in `_ready` with a loud `push_error`.
  - `setup(projectile_system: ProjectileSystem, encounter_id: StringName)` resolves the guard ids from each `guard_links` child's `guard_spawn` metadata via `EncounterMachine.enemy_id(encounter_id, path)`, builds the rules, turns `approach_volume` monitoring on and connects `body_entered` once (a `PlayerController` body means `notify_approached`).
  - `notify_guard_shot(enemy_id)` and `notify_guard_defeated(enemy_id)` are the Director's calls.
  - Renders the rules: hides the matching `GuardLinks/GuardN` on `guard_link_cleared`. On `shield_dropped` it hides `shield_visual`, joins `targetable` and registers `hit_volume`'s sphere with `take_damage` every physics tick at priority 0. On `destroyed` it leaves `targetable`, stops registering, hides `core_visual` (dev presentation) and emits `seal_destroyed(seal_id)` once. It forwards `guards_activated(seal_id)`.
  - `capture()` and `restore(data)` re-apply every visual from the rules' state, for Retry.

## Tests required

`tests/unit/progression/test_seal_rules.gd`:

- `test_seal_is_shielded_while_any_guard_lives`
- `test_damage_is_ignored_until_both_guards_die` (a Bomb cannot reveal the Seal)
- `test_group_activates_once_on_approach_or_guard_shot`
- `test_duplicate_guard_defeats_count_once`
- `test_exposed_seal_is_destroyed_once`
- `test_all_six_seal_orders_open_the_gate_once`: three `SealRules` plus an `EncounterMachine` OBJECTIVES Encounter; every permutation, with each `destroyed` fed to `notify_objective`, gives exactly one `gate_opened` and one `rewards_requested`
- `test_revisiting_a_destroyed_seal_changes_nothing`
- `test_capture_restore_round_trips`

`tests/scene/test_seal_contract.gd` instances `stage_02.tscn` without saving, attaches `seal.gd` to `Seal1` before it enters the tree, and uses a real `ProjectileSystem`:

- `test_guard_ids_come_from_guard_spawn_metadata` (`S2-03/Seal1_Sentry1`, `S2-03/Seal1_Sentry2`)
- `test_both_guard_defeats_expose_the_seal` (`ShieldVisual` hidden, in `targetable`, sphere radius 1.7 registered)
- `test_destroyed_seal_reports_once`

## Out of scope

Attaching `seal.gd` in `stage_02.tscn`, spawning the Guards, Guard passivity until activation (`EnemyActor.set_engaged()`), `Gates/Gate_S2_03/PortalLights` and the per-Seal Power rewards are all F12-05's. S2-03 content is F12-04's.

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR` in the output. Named tests cover ENGINEERING_BRIEF Section 8 "all seal orders" and STAGE_DESIGN "revisiting a seal cannot reset it or duplicate a reward". No Error-level warnings.
- There is no `/run` step here: F12-05 is the first ticket whose scene hosts a Seal. The scene contract test is the evidence.
- `docs/engineering/enemies.md` Seal section; GUIDE Section 6 row `seal.gd` and Section 7 row.
- Handoff log entry; `Status: done` with an Outcome; ROADMAP row.
- One commit: `progression: add SealRules and Seal adapter`.

## Outcome

Implemented `SealRules` and the `Seal` adapter. The core enforces one-time Guard
activation, duplicate-safe Guard defeat counting, shielded/exposed/destroyed
state transitions, early-damage refusal, and silent capture/restore. The adapter
resolves Guard ids from `guard_spawn` metadata, renders all state transitions,
registers the exposed hit sphere, and emits one destruction event. No tests were
added under the sprint rule; `tools/lane.ps1 land` passed.

## Handoff notes for Astra

Nothing to wire now. For F12-05, the Seal roots keep their children and `guard_spawn` metadata. Claude attaches `seal.gd` and sets `seal_id`, `health` and the node references. Portal-light presentation for a resolved seal is yours to author (an unresolved and a resolved state per `PortalLights/SealN`).

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/enemies/issues/03-seal-and-guard-rules.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
