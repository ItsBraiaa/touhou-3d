# F10-01 StageDirector adapter

Status: todo
Type: adapter
parallel-safe: no
Depends on: F8-02, F8-04, F9-02, F7-03, F4-03
Lane: trunk
Model: Claude Opus 5.5, 3-agent workflow (implementer, test-writer, reviewer)

## Goal

`StageDirector` on the `Stage` root of `scenes/stages/stage_01.tscn` runs Stage 1's Encounters with the dev enemies. Before the stage loads, it checks the `StageDefinition` and every node that definition names; the Session refuses the stage on any error. It arms the Entry and Exit volumes and forwards traversal and defeats to `EncounterMachine`. It spawns Waves and reward Pickups under `RuntimeActors`, scores each defeat once, and relays off-screen threats to the HUD and stage clear to the Session. It also exposes the active Encounter's bounds.

Gates, Checkpoints and PortalLinks come in F10-02, Retry in F10-03. Until F10-02, Stage 1 is flyable only to its first closed Gate, so the tests teleport the ship. A stage whose root is not a `StageDirector` (Stage 2, while F12-04 is cut) still loads and flies as a static stage.

## Read first

- `docs/STAGE_01_HANDOFF.md` entirely. It gives the `Encounters/<ID>/{EntryVolume,ExitVolume,Spawns,RewardOrigin,ShieldPickup}` paths and the monitoring rule: volumes are off in the file, enabled and connected once at integration, and are "not sufficient authority to complete an encounter".
- `docs/STAGE_DESIGN.md` "Shared encounter rules", Stage 1 table, "Agent implementation contract".
- `docs/GUIDE.md` Section 5 "Stages", Section 6 `stage_director.gd` row, Sections 7 and 8.
- `docs/ENGINEERING_BRIEF.md` Section 4.G.
- `docs/engineering/progression-core.md`:
  - Definitions: `WaveDefinition.enemy_kinds` holds one kind per marker, read with `enemy_kind_at(i)`.
  - `EncounterMachine`: static `enemy_id()`, `notify_entered() -> bool` (next Encounter only, and it waits for its Checkpoint), `notify_exited`, `notify_enemy_defeated`, `tick`, the signal order, and the note that `PlayerStart` lies inside S1-01's EntryVolume.
  - The content file `content/stages/stage_01/stage_01.tres`.
- `docs/engineering/enemies.md`: `EnemyActor.spawn_setup(definition, enemy_id, encounter_id, rng, projectile_system, player, bounds)` is called after `add_child` at the marker transform. The actor frees itself on defeat, and `EnemyDefinition.score` is awarded by the Director.
- `docs/engineering/damage-pickups.md`: `Pickup.setup` and the id convention.
- `docs/engineering/combat-hud.md`: `Hud.show_threat(side, seconds)`.
- `docs/engineering/menus-session.md` "Starting a stage" and "Unloading" (never unload or change physics state from inside a physics callback).

## Files

- **Creates:** `scripts/progression/stage_director.gd`, `tests/scene/test_stage_director.gd`, `docs/engineering/stage-director.md` (if F10-04 created it first, extend it instead).
- **Edits:**
  - `scenes/stages/stage_01.tscn` [shared]: attach `stage_director.gd` to `Stage` and set its exports. `stage_definition` → `content/stages/stage_01/stage_01.tres`. `actor_scenes`: `spirit` → `scenes/dev/spirit.tscn`, `sentry` → `scenes/dev/sentry.tscn`, `lantern_guardian` → `scenes/dev/sentry.tscn` (a stand-in until F12-03). `enemy_definitions`: `spirit` → `content/enemies/spirit.tres`, `sentry` and `lantern_guardian` → `content/enemies/sentry.tres`. `power_pickup_scene` and `shield_pickup_scene` → the F7-03 dev prefabs. Nothing else changes: no node is added or moved, and `monitoring` stays false in the file.
  - `scripts/session/game_session.gd`:
    - `var _director: StageDirector`.
    - `_load_stage`: when `stage is StageDirector`, `check_setup()`'s errors join the existing pre-check, so the stage is refused before anything is unloaded. After the ship and its F4, F6 and F7 bindings, call `_director.setup(_run_state, _combat_state, projectile_system, _player)`, connect `_director.stage_cleared` with `CONNECT_DEFERRED` to `_on_stage_cleared`, and connect `_director.threat_reported` to `_on_threat_reported`.
    - `_start_run` and `_restart_stage`: after `begin_attempt()`, `if _director != null: _director.start_attempt(_attempt_seed(_run_state.get_attempt_index()))`.
    - `_unload_stage`: `_director = null`.
    - `_on_stage_cleared()` → `_run_state.complete_stage()`.
    - `_on_threat_reported(side)` → `interface.get_hud().show_threat(side, THREAT_CUE_SECONDS)`, with `const THREAT_CUE_SECONDS := 1.0` (Claude's proposal).
    - `_attempt_seed(attempt_index: int) -> int` = `hash("%s#%d" % [stage id, attempt_index])`. The seed is deterministic, and no global RNG is used (CONVENTIONS "Time and randomness").
  - `tests/scene/test_game_session_flow.gd`: only where a case breaks because Stage 1 now has a Director.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F10-01 row.
  - `docs/HANDOFF_LOG.md`: one entry, announcing the `stage_01.tscn` wiring.
  - `docs/engineering/stage-director.md`, and its line in `docs/engineering/README.md`.
  - `docs/GUIDE.md`: the Section 6 rows for `stage_director.gd` and `game_session.gd`, the Section 7 rows "Enemy defeated" and "Stage completed", and the Section 10 row "Stage 1 progression".
- **Must not touch:**
  - `scripts/progression/encounter_machine.gd`, `checkpoint_store.gd` and `scripts/definitions/*` (F8; a gap is a dependency note).
  - `content/**` values (Astra's; a transcription error against STAGE_DESIGN is reported in the log, not silently fixed).
  - `scripts/enemies/*` and `scenes/dev/spirit.tscn`, `sentry.tscn` (F9-02); `scripts/combat/pickup.gd`; `scripts/ui/hud.gd`.
  - `gate.gd` and `checkpoint.gd`, which do not exist yet (F10-02); `scenes/stages/stage_02.tscn`; any node, marker or geometry in `stage_01.tscn`.
- **Conflicts with:**
  - `stage_01.tscn`: F10-02 and F12-03.
  - `stage_director.gd`: F10-02, F10-03 and F12-03.
  - `game_session.gd`: F4-02, F6-02 and F7-01 come before, through Depends on. F6-03 and F7-02 are not ordered against this ticket, so never run them together with it. F10-03, F11-01, F11-02 and F12-03 come after.
  - `stage-director.md`: F10-04, which is parallel-safe and may have created it.

## Deliverables

### `check_setup() -> PackedStringArray`

It uses only relative paths, so it works on a stage instance that is not yet in the tree. Every message names the stage id and the path. It reports:

- missing exports, and `stage_definition.validate()`;
- a missing `Encounters/<id>`, or one without an `EntryVolume` and `ExitVolume` `Area3D`;
- a wave marker that does not resolve to a `Node3D` under its Encounter root;
- a wave kind with no `actor_scenes` or no `enemy_definitions` entry;
- a reward `origin_marker` that does not resolve;
- a missing `RuntimeActors`.

### `setup(...)`, once per Director

A second call is `push_error` and nothing else. It then does four things:

1. Creates the `EncounterMachine`, calls `setup(stage_definition)`, and connects the machine's signals once.
2. For every Encounter, sets `monitoring = true` on its EntryVolume and ExitVolume and connects `body_entered` with `CONNECT_DEFERRED`, bound to the Encounter id. Deferred, because spawning `Area3D` actors, pickups and later gate changes must not run inside a physics flush.
3. Checks every handler for `is_instance_valid(body) and body == _player`.
4. Stores the four collaborators.

### `start_attempt(attempt_seed: int)`

It creates a new `RandomNumberGenerator` seeded with `attempt_seed`, one per Attempt, injected into every enemy. Then it calls `notify_entered(first Encounter id)`: Stage Entry begins S1-01, and `PlayerStart` (Z 20) already sits inside its EntryVolume, so no `body_entered` would arrive.

### Machine signals

- **`wave_requested(encounter_id, wave_index)`**, for each marker i:
  - `kind := wave.enemy_kind_at(i)` and `id := EncounterMachine.enemy_id(encounter_id, marker)`.
  - Instance `actor_scenes[kind]`, add it under `RuntimeActors`, and set its global transform to the marker's.
  - Call `spawn_setup(enemy_definitions[kind], id, encounter_id, _rng, _projectile_system, _player, get_active_encounter_bounds())`.
  - Connect `defeated` → `_on_enemy_defeated` and `threat_reported` → `threat_reported.emit`, then set `_live_enemies[id] = actor`.
- **`_on_enemy_defeated(enemy_id, encounter_id)`**, first report only (`enemy_id in _live_enemies`): erase the entry, call `_run_state.add_score(definition.score)` (100 per common enemy, PLANEJAMENTO Section 4), then `machine.notify_enemy_defeated(...)`. A repeat report scores nothing, and the actor frees itself.
- **`rewards_requested(encounter_id)`**: each `RewardDefinition` spawns `count` Pickups at its `origin_marker`, POWER from `power_pickup_scene` and SHIELD from `shield_pickup_scene`. They sit on a horizontal circle of `reward_spread` (export, 1.5, Claude's proposal; a single pickup sits on the marker), with ids `&"<encounter_id>/power_<n>"` and `shield_<n>`. Each goes under `RuntimeActors`, gets `setup(id, _combat_state, _player)`, and its `accepted` signal re-emits as `pickup_accepted`, which has no consumer while F13 is cut.
- **`stage_cleared`** → `stage_cleared.emit()`. **`gate_opened`** is ignored until F10-02.

### Volumes and ticking

EntryVolume forwards to `notify_entered(id)`, which refuses anything out of order, so flying over triggers does nothing. ExitVolume forwards to `notify_exited(id)`. `_physics_process(delta)` calls `machine.tick(delta)`. The Director sits under `WorldRoot`, which is PAUSABLE, so it stops while paused.

### `get_active_encounter_bounds() -> AABB`

The global merge of the active Encounter's EntryVolume and ExitVolume boxes. Both span the route cross-section, so the result is X -45..45, Y 0..75 and the Encounter's Z range. It is `AABB()` when no Encounter is active.

## Tests required

`tests/scene/test_stage_director.gd` runs headless on `main.tscn` with `start_direct_stage` on `stage_01`. It teleports the ship into volumes with `reset_to()` and awaits physics frames. It kills actors through the public damage path in `enemies.md`.

- `test_stage_entry_activates_s1_01`
- `test_entering_s1_02_spawns_wave_1_under_runtime_actors`: three actors, ids `S1-02/Wave1_Spirit1..3`, placed at their markers.
- `test_wave_2_spawns_after_wave_1_is_defeated`
- `test_s1_02_drops_five_power_pickups_at_reward_origin_once`
- `test_defeat_scores_once_per_enemy`: a duplicate `defeated` report adds 100 once.
- `test_entry_out_of_order_spawns_nothing`: flying into S1-03's EntryVolume first spawns nothing.
- `test_reentering_a_completed_encounter_spawns_nothing`: STAGE_DESIGN "Re-entering a trigger does not spawn another wave or award another reward".
- `test_s1_03_shield_pickup_spawns_at_its_marker`
- `test_active_encounter_bounds_span_the_encounter`
- `test_check_setup_names_a_missing_marker` and `test_invalid_content_refuses_the_stage`: a packed variant without the `spirit` entry, set in `stage_scenes`, leaves the menu up.
- `test_stage_cleared_completes_the_stage`: phase `STAGE_COMPLETE`, reached deferred.
- `test_threat_report_shows_the_hud_threat`
- `test_stage_02_without_a_director_still_flies`
- `test_restart_builds_a_new_director_without_double_connections`: after a Restart, one defeat adds 100 once.

## Out of scope

- Gates, Checkpoints, PortalLinks and hostile clears (F10-02); Retry (F10-03).
- The boss, `boss_definitions` and boss HUD signals (F12-03).
- Stage 2 (cut with F12-04).
- Enemy movement and patterns (F9).
- Pickup and threat audio (F13, cut).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR`.
- The STAGE_DESIGN acceptance item "flying over a locked gate cannot skip the required encounter" (trigger side) and ENGINEERING_BRIEF 4.G "duplicate death callbacks, returning through triggers" have named tests. No Error-level warnings.
- `/run`, headless first, then windowed: from the main menu, fly into S1-02 and watch both Waves spawn, fire and drop five pickups.
- Module doc, GUIDE rows, handoff log, `Status: done` with an Outcome, ROADMAP row.
- One commit: `progression: [shared] attach StageDirector to Stage 1`.

## Handoff notes for Astra

- Claude attached `stage_director.gd` to Stage 1's `Stage` and set its exports only. Keep the Encounter, Wave marker, `RewardOrigin` and `ShieldPickup` names: they are load-bearing.
- `get_active_encounter_bounds()` is the value for boss-arena retreat containment (STAGE_01_HANDOFF).
- `lantern_guardian` points at the dev Sentry until F12-03.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/stage-director/issues/01-stage-director-adapter.md, then implement that ticket. Use /run to verify S1-02's two Waves spawn, fire and drop five pickups in the real Stage 1 from the main menu. Finish with its Definition of Done and commit.
```
