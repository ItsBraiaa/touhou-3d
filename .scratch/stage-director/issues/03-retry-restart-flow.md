# F10-03 Retry and Restart flow

Status: done
Type: integration
parallel-safe: no
Depends on: F10-02, F7-01
Lane: trunk
Model: Claude Opus 5.5, 3-agent workflow (implementer, test-writer, reviewer)

## Goal

Defeat's Retry resumes from the latest activated Checkpoint's Snapshot, as STAGE_DESIGN's retry matrix says.

- **Cleanup.** Every transient enemy, Projectile, Pickup, damage timer, Target Lock and queued spawn of the failed segment is removed.
- **Restore.** Resources are full, and Power, score, Graze, bombs used and Clear Time are the committed values. Encounters from the resume point on are rebuilt, while earlier ones, their rewards and their Gates stay resolved.
- **Respawn.** The ship appears at the Checkpoint's `Respawn`, facing -Z, with nothing incoming.

Before any Checkpoint, Retry is Restart (PLANEJAMENTO Section 6). Restart keeps F2-04's full reload, because a new stage, Director and `CheckpointStore` are the Stage Entry Snapshot by construction. Defeat names the retry location.

GUIDE Section 8 split: the Director restores its own actors, flags, Gates and links in place and survives the Retry. The Session re-instances the ship and clears the field.

## Read first

- `docs/STAGE_DESIGN.md` "Checkpoint contract" (the retry matrix and "Time and score integrity") and the acceptance checks.
- `docs/STAGE_01_HANDOFF.md` "Checkpoints": Respawn (0,27,-329) and (0,37,-454), facing -Z.
- `docs/engineering/progression-core.md` "CheckpointStore":
  - `retry_into(combat, run, encounters) -> bool` returns false when there is no Checkpoint, and does not refill (the Snapshot was recorded after the refill).
  - `latest_checkpoint_id()`.
  - Afterwards the caller calls `run.begin_attempt()`, and `combat.set_paused(false)`, because `CombatState.restore` leaves the pause flag.
- `docs/engineering/stage-director.md` (F10-01, F10-02: `_apply_progress()`, `_live_enemies`); `docs/engineering/damage-pickups.md` "Defeat".
- `docs/engineering/menus-session.md` "Starting a stage": the ship is placed before it enters the tree so the `CameraRig` starts behind it.
- `scripts/session/game_session.gd`: every per-ship line that F4-02 (HUD bind), F6-02 (`projectile_system.setup(bounds, player)`), F6-03 (`_player.weapon.setup(...)`) and F7 put in `_load_stage`.

## Files

- **Creates:** `tests/scene/test_retry_restart_flow.gd`.
- **Edits:**
  - `scripts/progression/stage_director.gd`: `retry_from_checkpoint`, `get_respawn_transform`, `retry_location_name`.
  - `scripts/session/game_session.gd`:
    - `_spawn_player(at: Transform3D)`, factored out of `_load_stage`.
    - `_retry()`; the `retry` case now calls it instead of F7-01's `_restart_stage()`.
    - The Defeat `checkpoint` param in `_on_player_defeated`.
    - A `_flight_volume: AABB` member kept from the load.
  - `tests/scene/test_game_session_flow.gd` and `test_game_session_combat.gd`: only where the refactor changes an assertion.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F10-03 row.
  - `docs/HANDOFF_LOG.md`: one entry.
  - `docs/engineering/stage-director.md`: a "Retry and Restart" section.
  - `docs/GUIDE.md`: the Section 6 rows `stage_director.gd` and `game_session.gd`, and a Section 8 note ("Retry is in place, Restart reloads").
- **Must not touch:** `checkpoint_store.gd`, `snapshot.gd`, `encounter_machine.gd` (F8; a capture gap is a dependency note), `combat_state.gd`, `run_state.gd`, `menu_controller.gd` (the Defeat text format is F11-01's), and `stage_01.tscn` (no scene change is needed).
- **Conflicts with:** `game_session.gd` (F11-01, F11-02 and F12-03 after); `stage_director.gd` (F12-03 after).

## Deliverables

### Director

`retry_from_checkpoint(player: PlayerController, attempt_seed: int) -> bool` returns false and changes nothing when `_checkpoint_store.latest()` is null. Otherwise it does five things in order:

1. Removes every child of `RuntimeActors` (`remove_child`, then `queue_free`) and clears `_live_enemies`. That covers enemies, reward Pickups and the S1-03 Shield Pickup.
2. Calls `_checkpoint_store.retry_into(_combat_state, _run_state, _machine)`. This restores combat resources, Power Progress, committed statistics, completed and rewarded Encounters, objectives and Checkpoint flags, and cancels queued waves.
3. Sets `_player = player` and creates a new `RandomNumberGenerator` from `attempt_seed`.
4. Calls `_apply_progress()`. Gates of completed Encounters are open and all others closed, including a Gate the failed Attempt opened. Guard links follow the same rule.
5. Returns true.

Its two helpers:

- `get_respawn_transform() -> Transform3D` gives the latest activated Checkpoint's `get_respawn_transform()`, or `PlayerStart`'s global transform at Stage Entry.
- `retry_location_name() -> String` gives the `display_name` of `stage_definition.find_checkpoint(_checkpoint_store.latest_checkpoint_id())`, or `""` at Stage Entry. It is `"CP1-A"` until Astra names the places.

There is no `restart_from_entry()`: Restart reloads, and `restart_into` is not used.

### Session

- **`_spawn_player(at: Transform3D)`.** The one place a ship is made:
  1. If a ship exists: `interface.get_hud().unbind()`, then `remove_child` and `queue_free` the old ship.
  2. Instance `player_scene`, set its transform to `at` before adding it, add it under `world_root`, and call `setup(_flight_volume)`.
  3. Run every per-ship binding moved from `_load_stage`, not duplicated: the F4-02 HUD bind, F6-02's `projectile_system.setup(...)` (or the per-ship call F6-02 documents), and F6-03's `weapon.setup(...)`.

  `_load_stage` calls it with `PlayerStart`.
- **`_retry()`.**
  1. If `_director == null` or `_director.retry_location_name().is_empty()`, call `_restart_stage()` and return.
  2. `_set_paused(false)`: the tree, `RunState` and `CombatState` all run again.
  3. `projectile_system.clear_all()`, so nothing is incoming.
  4. `_spawn_player(_director.get_respawn_transform())`. A new ship carries no velocity, no Target Lock and no flicker, and the camera starts behind it.
  5. `_director.retry_from_checkpoint(_player, _attempt_seed(_run_state.get_attempt_index() + 1))`.
  6. `_run_state.begin_attempt()`, after the restore, as F8-03 says.
  7. `interface.show_home(ScreenRouter.HUD)`.
- **Defeat.** `_on_player_defeated` pushes `{"checkpoint": _director.retry_location_name() if _director != null else ""}`. `MenuController` shows `Último checkpoint · <name>` or `Início da fase`.
- **Restart.** `_restart_stage` is unchanged: a full reload with `run_state.restart_stage()` and `combat_state.start(starting_power_level())`. The Director and store are new, so every Checkpoint is discarded (STAGE_DESIGN "Restart Stage explicitly discards checkpoint progress").

## Tests required

`tests/scene/test_retry_restart_flow.gd` runs headless on `main.tscn` with a Direct Stage 1. It teleports, kills through the public damage path, and forces defeat with `get_combat_state().take_hit(...)`. Each test names its STAGE_DESIGN matrix row.

- `test_retry_before_any_checkpoint_restarts_the_stage`
- `test_retry_after_cp1_a_resumes_at_s1_05`. The test checks:
  - the ship at CP1-A's `Respawn`, facing -Z;
  - 100 Health, Shield, two Bombs;
  - Power, score, Graze, bombs used and `clear_time()` equal to the values at activation;
  - `RuntimeActors` empty and `count(HOSTILE)` 0;
  - `Gate_S1_02..04` open and `Gate_S1_05` closed, with the guard links hidden;
  - Attempt index 2.
- `test_retry_rebuilds_a_gate_the_failed_attempt_opened`: complete S1-05 and die before CP1-B. After Retry `Gate_S1_05` is closed, and S1-05 spawns its waves and its five Power Pickups again. The rolled-back Power Progress is back at the snapshot value.
- `test_retry_after_cp1_b_resumes_at_the_boss_approach`: S1-07 is inactive, and entering it spawns the stand-in.
- `test_failed_attempt_score_and_time_do_not_survive_retry` (acceptance: "without farming failed attempts").
- `test_queued_wave_is_cancelled_on_retry`: die during S1-05's wave-2 delay; after Retry, 10 s pass with no stray wave.
- `test_revisiting_the_checkpoint_after_retry_does_not_refill`
- `test_target_lock_is_clear_after_retry`
- `test_defeat_names_the_latest_checkpoint`: `Início da fase` first, then `Último checkpoint · CP1-A`.
- `test_restart_after_a_checkpoint_returns_to_stage_entry`: all Gates are closed, Clear Time is 0 and the score is the entry score, and the next Retry restarts.
- `test_three_retries_do_not_double_connect`: one defeat adds 100 once, and one Graze counts once.

## Out of scope

- Results, Continue and Replay (F11).
- The boss's own Retry behavior (F12-03 inherits it, because the boss is an actor under `RuntimeActors`).
- Stage 2 checkpoints (cut with F12-04).
- Respawn Invulnerability (not specified; none is added).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR`.
- Named tests exist for ENGINEERING_BRIEF 4.H ("failed attempts cannot farm score or inflate duration", "restarting differs from retrying", "replaying a trigger does not refill") and Section 8 ("queued-spawn cancellation, statistics rollback"). No Error-level warnings.
- `/run`, headless first, then windowed: die on purpose after CP1-A, Retry, and see the arch ahead with no bullets. Defeat shows the Checkpoint. Recorded in `docs/validation/stage-01-progression.md`.
- Module doc, GUIDE rows, handoff log, `Status: done` with an Outcome, ROADMAP row.
- One commit: `progression: add Retry from Checkpoint and Restart flow`.

## Handoff notes for Astra

- Defeat shows `Último checkpoint · <display_name>`. Give CP1-A and CP1-B Portuguese place names in `content/stages/stage_01/cp1_*.tres` when you like.
- Respawn uses the `Respawn` markers as authored, facing -Z.

## Outcome

Done 2026-09-23 by trunk (Claude: implementer, plus a verifier agent that ran the game and a reviewer agent).

The Director's three methods and the Session's `_spawn_player`, `_retry`, Defeat param and `_flight_volume` follow the Deliverables. No scene file changed.

- **No new tests** (the user's sprint rule): `tests/scene/test_retry_restart_flow.gd` was not written. A throwaway driver ran the ticket's eleven cases in the real game headless, and the windowed `/run` from the main menu died after CP1-A: Defeat named `Último checkpoint · CP1-A`, and Retry put the ship at the arch with full resources and no bullets. Results and two captures are in `docs/validation/stage-01-progression.md`. The suite stays at 225; `test_game_session_flow.gd` and `test_game_session_combat.gd` needed no change; `validate_combat.gd` and the F10-01 and F10-02 passes still pass.
- **Deviation:** the ticket's `_spawn_player(at)` is `_spawn_player(ship, at)`. `_load_stage` still refuses a `player_scene` without a `PlayerController` root before anything unloads, and hands that same instance over, so the ship is not instanced twice. The reviewer agreed.
- **Reviewer hardening:** `_retry()` returns unless a stage is in play. This is not reachable today, but it guards a Retry after a same-tick stage clear once F11-01 keeps the stage under Results.
- **Open design question (in the handoff log):** Retry removes every runtime Pickup, as this ticket says, including rewards left uncollected before the Checkpoint. Their Encounters stay rewarded, so those Pickups never return. STAGE_DESIGN says "from the failed segment". The reviewer's fix, if wanted, stays inside the Director: record the live reward Pickups at each activation and respawn them after a Retry.
- **For F11-01:** `menu_controller.gd:144` calls the Defeat `checkpoint` param an id, but it is now the Checkpoint's `display_name`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/stage-director/issues/03-retry-restart-flow.md, then implement that ticket. Use /run to verify a defeat after CP1-A retries at the arch with full resources, no bullets and the right Gates, and that Restart returns to the stage entry. Finish with its Definition of Done and commit.
```
