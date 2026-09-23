# F10 Stage Director in Stage 1 — spec

Status: ready-for-agent
Owner: Claude
Source: STAGE_01_HANDOFF.md (the actual scene paths); STAGE_DESIGN.md ("Shared encounter rules", Stage 1 table, "Checkpoint contract", "Agent implementation contract", acceptance checks); GUIDE.md Sections 5 "Stages", 6, 7, 8; ENGINEERING_BRIEF Sections 4.G and 4.H; the F8 contracts in `.scratch/progression-core/` (`EncounterMachine`, `CheckpointStore`, Definitions, `content/stages/stage_01/stage_01.tres`); the F9-02 `EnemyActor` contract; F7-03 `Pickup`.

## Goal

The real `scenes/stages/stage_01.tscn` plays from the main menu as a complete route with dev enemies:

- S1-01 to S1-07 activate in order, and flying over triggers skips nothing.
- Waves spawn under `RuntimeActors`, and defeats score once.
- Rewards drop exactly once, and Gates open when their Encounter completes.
- CP1-A and CP1-B refill and snapshot on first activation only.
- Defeat's Retry resumes from the latest Checkpoint; Restart returns to Stage Entry.

Every rule is already in the F8 cores. The Director only resolves markers, spawns, forwards events and applies state to the scene. A headless contract test catches any drift between the scene and the content.

## Tickets

1. `01-stage-director-adapter.md`: `StageDirector` on `Stage`, Encounters, Waves, rewards, score, threats, stage clear, active-Encounter bounds, content refusal.
2. `02-gate-and-checkpoint-adapters.md`: `Gate`, `Checkpoint`, PortalLinks, the Director's `CheckpointStore`, hostile clears on gate opening and checkpoint activation. No Session edit.
3. `03-retry-restart-flow.md`: in-place Retry from the latest Checkpoint, the ship re-instanced at its `Respawn`, and the Defeat retry location. Restart keeps F2-04's full reload.
4. `04-stage-01-contract-smoke-test.md` (**parallel-safe**): scene against content, one new test file. It can run as soon as F8-04 is done, beside any other parallel-safe core.

01 to 03 are serialized: they share `stage_director.gd`, `stage_01.tscn` and `game_session.gd`.

## Cross-feature contracts

- **`StageDirector`** (`scripts/progression/stage_director.gd`, `class_name StageDirector extends Node3D`, on the `Stage` root of `stage_01.tscn`):
  - Exports: `stage_definition: StageDefinition`, `actor_scenes: Dictionary[StringName, PackedScene]`, `enemy_definitions: Dictionary[StringName, EnemyDefinition]`, `power_pickup_scene`, `shield_pickup_scene`, `reward_spread: float`, and `guard_links: Dictionary[StringName, NodePath]` (F10-02).
  - `check_setup() -> PackedStringArray` works before the stage enters the tree. The Session refuses the stage on any error.
  - `setup(run_state: RunState, combat_state: CombatState, projectile_system: ProjectileSystem, player: PlayerController)`, once.
  - `start_attempt(attempt_seed: int)`.
  - `get_active_encounter_bounds() -> AABB`.
  - `get_encounter_machine() -> EncounterMachine`, for tests.
  - Signals: `stage_cleared()`, `threat_reported(side: int)`, `pickup_accepted(pickup_id: StringName, kind: Pickup.Kind, score: int)`, and `checkpoint_activated(checkpoint_id: StringName)` (F10-02).
  - F10-03 adds `retry_from_checkpoint(player: PlayerController, attempt_seed: int) -> bool`, `get_respawn_transform() -> Transform3D` and `retry_location_name() -> String`.
- **`Gate`** (`scripts/progression/gate.gd`, `extends Node3D`, on `Gates/Gate_S1_0N`): `set_open(open: bool)`, idempotent both ways (the `BarrierBody/Collision` shape is disabled deferred, `ClosedVisual` is hidden); `is_open() -> bool`.
- **`Checkpoint`** (`scripts/progression/checkpoint.gd`, `extends Area3D`, on `Checkpoints/CP1-*`): export `checkpoint_id: StringName`; `signal entered(checkpoint_id: StringName)`, emitted for the player's body only; `set_armed(armed: bool)`; `get_respawn_transform() -> Transform3D` (`Respawn`'s global transform).
- **Session slices in `game_session.gd`**:
  - F10-01: `_director`, the `check_setup()` pre-check in `_load_stage`, `setup` and the two connections (`stage_cleared` deferred → `run_state.complete_stage()`; `threat_reported` → `Hud.show_threat(side, 1.0)`), `start_attempt()` after `begin_attempt()` in `_start_run` and `_restart_stage`, and `_attempt_seed(attempt_index)`.
  - F10-03: `_spawn_player(at: Transform3D)` factored out of `_load_stage`; `retry` → `_retry()`; the Defeat `checkpoint` param.
  - F10-02 does not edit the Session.
- **Ids and ownership**:
  - Enemy ids come from `EncounterMachine.enemy_id(encounter_id, marker)`, for example `&"S1-02/Wave1_Spirit1"`.
  - Pickup ids are `&"<encounter_id>/power_<n>"` and `&"<encounter_id>/shield_<n>"`.
  - The Director owns its `CheckpointStore` and survives Retry. Restart and every stage load build a new Director and store, which is the Stage Entry Snapshot by construction, so `CheckpointStore.restart_into` is not used by F10.
- **For F12-03**: until then `actor_scenes[&"lantern_guardian"]` and `enemy_definitions[&"lantern_guardian"]` point at the dev Sentry as a documented stand-in, so S1-07 can be cleared. F12-03 removes both entries and adds its boss branch. `boss_defeated` and the boss HUD signals are F12-03's.
- **For F11**: `stage_cleared` reaches `RunState.complete_stage()` deferred, outside any physics flush, so F11-01's Results handler may pause and push overlays safely. `retry_location_name()` is `CheckpointDefinition.display_name` of the latest activated Checkpoint, or `""` at Stage Entry.

## Done when

- All F10 tests pass, including the full Stage 1 route with dev enemies and the retry matrix for Stage Entry, CP1-A and CP1-B.
- From the main menu, Stage 1 can be flown past every Gate on keyboard and gamepad, with Waves and rewards as STAGE_DESIGN says.
- `docs/engineering/stage-director.md` documents the Director, Gate, Checkpoint, Retry and the scene contract.
- GUIDE Section 6 rows for `stage_director.gd`, `gate.gd`, `checkpoint.gd` and `game_session.gd` are updated. Section 10 "Stage 1 progression" and "Checkpoints/gates/seals" advance.

## Out of scope

- The Lantern Guardian boss (F12-03).
- Stage 2 gameplay: no Director, Seals, miniboss or CP2-*. This is cut with F12-04 pending the user; Stage 2 keeps flying as a static stage.
- Results and Campaign continuation (F11).
- Checkpoint glow and sound: the glow is requested from Astra, and F13 is cut.
- Boss-arena retreat containment beyond exposing `get_active_encounter_bounds()` (requested from Astra).
