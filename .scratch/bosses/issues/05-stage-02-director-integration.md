# F12-05 Stage 2 Director integration

Status: todo
Type: adapter
parallel-safe: no
Depends on: F10-03, F9-03, F12-04
Lane: sol

## Goal

Stage 2 plays as a full route from the menu:

- `StageDirector` sits on `stage_02.tscn`'s `Stage` root with the F12-04 content.
- The five Gates open, CP2-A and CP2-B refill and snapshot once, and Retry and Restart work as in Stage 1.
- S2-03's three Seals run through F9-03's `Seal` adapter. Each Guard pair stays passive until its group engages. Each broken Seal resolves its portal light and drops one Power Pickup. The third one opens `Gate_S2_03`.
- A Direct Stage 2 starts with its entry values.

The bosses are a dev stand-in, the dev Sentry mapped through `enemy_definitions` exactly as F10-01 did for S1-07. F12-06 and F12-07 replace it. Everything reuses F10's code; this ticket adds only what Stage 2 has and Stage 1 lacks.

## Read first

- `docs/STAGE_02_HANDOFF.md` entirely; `docs/STAGE_DESIGN.md` Stage 2 table, "Three-seal progression challenge", "Checkpoint contract" (CP2 rows), acceptance checks.
- `docs/engineering/stage-director.md` (F10-01 to F10-03: exports, spawn path, `_apply_progress()`, Retry, the test seam) and the three F10 Outcomes.
- `docs/engineering/enemies.md`: `EnemyActor`, and F9-03's "Seal" section (`setup(projectile_system, encounter_id)`, `notify_guard_shot`, `notify_guard_defeated`, `guards_activated`, `seal_destroyed`).
- `docs/engineering/progression-core.md` "Stage 2 content" (F12-04's schema readings); `docs/engineering/menus-session.md` "Starting a stage".

## Files

- **Creates:** `tests/scene/test_stage_02_director.gd`, `scenes/dev/portal_light_resolved.tres` (a dev emissive material), `docs/validation/stage-02-progression.md`.
- **Edits:**
  - `scenes/stages/stage_02.tscn` [shared], script attachment and exports only (see Deliverables). `monitoring` stays false in the file.
  - `scripts/progression/stage_director.gd`: the Stage 2 additions. Put them in private functions of their own, with one-line call sites in existing functions.
  - `scripts/enemies/enemy_actor.gd`: `set_engaged` and `damaged`. `scripts/progression/gate.gd`: optional `OpenVisual`.
  - `tests/scene/test_stage_02_contract.gd` [shared]: its "Stage remains static" assertion becomes `stage is StageDirector`.
  - `tests/scene/test_stage_director.gd`: `test_stage_02_without_a_director_still_flies` becomes `test_stage_02_loads_with_its_director`.
  - `tests/scene/test_enemy_actor_contract.gd`: two cases. Any other F10 or F11 scene test only where it breaks because Stage 2 now has a Director.
- **Serialized at session end:** ROADMAP (the F12-05 row); `docs/HANDOFF_LOG.md` ([shared] entry); `docs/engineering/stage-director.md` ("Stage 2" section); `docs/engineering/enemies.md` (EnemyActor additions); GUIDE Section 6 rows `stage_director.gd`, `gate.gd`, `checkpoint.gd`, `seal.gd`, `enemy_actor.gd`, and Section 10 "Stage 2 progression" and "Checkpoints/gates/seals".
- **Must not touch:**
  - Trunk's files: `game_session.gd`, `main.tscn`, `player_ship.tscn`, `stage_01.tscn`.
  - `seal.gd` and `seal_rules.gd`; F8's cores and `scripts/definitions/*`; `boss_*.gd`; `hud.gd`. A gap in any of them is a note.
  - `content/**`: a transcription error is logged for glm-b.
  - In `stage_02.tscn`, any node, marker, material or metadata.
  - `tools/build_stage_02.py`: never run it; it would erase the wiring.
- **Conflicts with:** `stage_director.gd` with F12-03 (trunk), which may run at the same time. The second to land merges both; name the merged functions in the handoff entry. `enemy_actor.gd` and `gate.gd` have no other scheduled editor.

## Deliverables

**Scene wiring:**
- `Stage` gets `stage_director.gd`:
  - `stage_definition` = `content/stages/stage_02/stage_02.tres`.
  - `actor_scenes` and `enemy_definitions` for `spirit` and `sentry`, and the two pickup scenes, take the same values as `stage_01.tscn`.
  - `tempest_sentinel` and `storm_guardian` map, in `actor_scenes` and `enemy_definitions`, to the Sentry scene and `content/enemies/sentry.tres` that F10-01's stand-in used.
  - `portal_lights`, `resolved_light_material` and `activate_checkpoint_on_entry = true` (below).
- `gate.gd` goes on `Gates/Gate_S2_01..05`. `checkpoint.gd` goes on `CP2-A` and `CP2-B`, with `checkpoint_id` from their metadata.
- `seal.gd` goes on `Encounters/S2-03/Seals/Seal1..3`: `seal_id` from its metadata, and its node references to `ShieldVisual`, `Core`, `HitVolume`, `ApproachVolume` and `GuardLinks`. `health` keeps F9-03's default.

**Seals.** For each OBJECTIVES Encounter, the Director collects the `Seal` children of `Encounters/<id>/Seals`, keyed by `seal_id`. `setup` calls `seal.setup(_projectile_system, id)` and connects `seal_destroyed` and `guards_activated` once. Guard ids use F9-03's own derivation, `EncounterMachine.enemy_id(id, guard_spawn)` for each `GuardLinks` child, which gives the map `_guard_seals[enemy_id] → Seal`.

**Guards.**
- A spawned actor whose id is a guard gets `set_engaged(false)` right after `spawn_setup`, and its `damaged` signal goes to `seal.notify_guard_shot(enemy_id)`.
- `guards_activated(seal_id)` engages that Seal's live guards.
- The first defeat report of a guard also calls `seal.notify_guard_defeated(enemy_id)`, after the existing score and machine calls, so a Bomb kill of a dormant guard counts.

**`seal_destroyed(seal_id)`:**
1. `portal_lights[seal_id].material_override = resolved_light_material`.
2. Spawn that Seal's reward.
3. `machine.notify_objective(seal_id)`. The third call completes S2-03, and F10-02's `gate_opened` clears hostile fire and opens `Gate_S2_03`.

**Per-Seal rewards.** A reward of an OBJECTIVES Encounter whose `origin_marker` lies under a Seal root belongs to that Seal. It spawns when that Seal breaks, with the id `&"<seal_id>/power_<n>"`, and `rewards_requested` skips it.

**Progress.** `_apply_progress()` also resolves the light of every recorded objective. Seals need no Snapshot: no Checkpoint lies inside S2-03, and before CP2-A a Retry is a Restart.

**Checkpoint on entry** (`@export var activate_checkpoint_on_entry := false`). When an EntryVolume's `notify_entered(id)` is refused only because `id`'s Checkpoint is inactive while its `after_encounter_id` is complete, the Director runs `Checkpoint.entered`'s activation (clear, `CheckpointStore.activate`, `checkpoint_activated`) and then enters. STAGE_02_HANDOFF: "Whole-section EntryVolumes alone must never bypass a checkpoint", including a player who crosses outside the 38 × 26 arch. Stage 1 keeps F10-02's arch-only rule.

**`check_setup()`** also reports an objective with no Seal or a Seal no objective names, a guard id no wave marker spawns, a per-Seal reward without its Seal, a `portal_lights` key that is not a Seal id or a path that is not a `GeometryInstance3D`, and `portal_lights` without a `resolved_light_material`.

**`EnemyActor`:**
- `set_engaged(engaged: bool)`, engaged by default. A disengaged actor stays in `targetable` and keeps registering its hit sphere, but skips `model.tick`, so it holds still and never anticipates or fires. Engaging starts its first Anticipation.
- `signal damaged(enemy_id: StringName)`, on every accepted hit.

**`Gate`:** an `OpenVisual` child, when present, is shown while open and hidden while closed (STAGE_02_HANDOFF "showing the clear beacon").

## Tests required

`tests/scene/test_stage_02_director.gd` runs headless on `main.tscn` with a Direct Stage 2. It teleports with `reset_to()` and kills through the public damage path.

- `test_direct_stage_2_starts_with_its_entry_values`: Power 2, Health 100, Shield, 2 Bombs, score 0, S2-01 active.
- `test_s2_01_needs_both_spirits_and_the_ledge`; `test_s2_02_drops_two_power_and_one_shield_once`.
- `test_seal_guards_hold_fire_until_their_group_engages`: six guards spawned, no hostile Projectile for 3 s; approaching Seal1 engages only its pair.
- `test_shooting_a_dormant_guard_engages_its_pair`; `test_bomb_cannot_reveal_a_shielded_seal`.
- `test_destroyed_seal_resolves_its_light_and_drops_one_power`; `test_revisiting_a_destroyed_seal_changes_nothing`.
- `test_two_seal_orders_open_gate_s2_03_once`. All six orders are F9-03's core test.
- `test_open_gate_shows_its_clear_beacon`; `test_crossing_outside_the_cp2_a_arch_commits_it_before_s2_04`.
- `test_death_after_the_miniboss_before_cp2_b_restores_cp2_a`; `test_death_at_the_final_boss_restores_cp2_b` (STAGE_DESIGN acceptance).
- `test_boss_encounters_ignore_their_exit_volumes`.
- `test_full_stage_2_route_with_stand_ins`: seven Encounters, five Gates, two Checkpoints, `stage_cleared` once.
- `test_check_setup_names_an_objective_without_a_seal`.

In `tests/scene/test_enemy_actor_contract.gd`: `test_disengaged_actor_holds_fire_but_takes_damage` and `test_damage_is_reported`.

## Out of scope

The real Sentinel and Storm Guardian (F12-06, F12-07); final portal-light, shield and storm presentation (open Astra requests, no D ticket carries them yet); boss-arena retreat containment; the five-minute measurement (F11-03 and the human pass); audio (F13-03).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR`. Named tests cover ENGINEERING_BRIEF Section 8 "all seal orders", plus the STAGE_DESIGN acceptance items for seals, gate bypass and CP2-A versus CP2-B. No Error-level warnings.
- Verify headless: a scripted Direct Stage 2 from the main menu clears S2-01 to S2-03 in two Seal orders and reaches CP2-A. Record it in `docs/validation/stage-02-progression.md`.
- Module docs, GUIDE rows, the handoff log, `Status: done` with an Outcome, the ROADMAP row.
- One commit, `progression: [shared] attach StageDirector and Seals to Stage 2`, then the lane's land step from `docs/engineering/SPRINT.md`.

## Handoff notes for Astra

`stage_02.tscn` changed only in scripts and exports. Now load-bearing: the Encounter roots and markers, `Seals/SealN` with its children and its `seal_id` and `guard_spawn` metadata, `Gates/*/BarrierBody/Collision`, `ClosedVisual`, `OpenVisual`, `PortalLights/Seal1..3`, and `Checkpoints/*/Respawn`. `scenes/dev/portal_light_resolved.tres` is a placeholder. Send Claude your resolved-light material, and Claude swaps the export. Opting Stage 1 into `activate_checkpoint_on_entry` is your call. Update `metadata/handoff_state` when you review.

## Kickoff prompt

```
In your lane worktree, read AGENTS.md, docs/engineering/SPRINT.md (your lane section), docs/engineering/ROADMAP.md and .scratch/bosses/issues/05-stage-02-director-integration.md. Check its dependencies with tools/lane.ps1 status F10-03 F9-03 F12-04, implement it test-first, run tools/test.ps1 until green with no SCRIPT ERROR, finish its Definition of Done, commit, then run tools/lane.ps1 land.
```
