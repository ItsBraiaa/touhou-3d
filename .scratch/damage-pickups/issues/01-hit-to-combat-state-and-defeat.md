# F7-01 Hits to CombatState and defeat

Status: done
Type: integration
parallel-safe: no
Depends on: F6-02, F4-02 (F4-01 done)
Lane: trunk
Model: Claude Opus 5.5, 3-agent workflow (implementer, test-writer, reviewer)

## Goal

The ship can be hurt in the real game. This ticket wires five paths, all in `GameSession` (the "F7 combat adapter" that `combat-hud.md` refers to; no new Node):

- The `ProjectileSystem`'s Core hits reach `CombatState.take_hit`.
- Grazes reach `RunState` with their score.
- Invulnerability reaches the field, so no Graze is awarded during it, and the ship, which flickers.
- Excess-Power score reaches `RunState`.
- Defeat freezes the Attempt under the Defeat overlay.

Retry restarts the stage until F10-03 adds Checkpoints (PLANEJAMENTO Section 6: "Before any intermediate checkpoint, it restarts the stage").

## Read first

- `docs/engineering/combat-hud.md` "CombatState contract": the real API is `take_hit(damage) -> HitOutcome` (`REJECTED`, `ABSORBED`, `DAMAGED`, `DEFEATED`), the value signals, `invulnerability_changed`, `score_awarded`, `defeated` once per life, `tick`, `set_paused`. Also read F4-02's Outcome in `.scratch/combat-hud/issues/02-hud-binding-and-target-marker.md`: `_combat_state` is a Session-lifetime member with `get_combat_state()`, `start()` in `_start_run` and `_restart_stage`, and `set_paused()` in `_set_paused`.
- `docs/engineering/weapon-rendering.md` "ProjectileSystem contract" (F6-02): the typed export name on `GameSession`, `player_hit(projectile_id, damage)`, `grazed(projectile_id)`, `set_player_invulnerable(active)`, `spawn(ProjectileSpawn)`.
- `docs/engineering/menus-session.md` "GameSession contract" ("Pause", "Unloading") and Open issues.
- `docs/PLANEJAMENTO.md` Section 4 "Health and shield", "Graze and score"; `docs/ENGINEERING_BRIEF.md` Section 4.C.
- `docs/GUIDE.md` Section 7 "Player defeated", Section 14 Defeat rows.
- `scripts/session/game_session.gd`, `scripts/player/player_controller.gd`. `scenes/player/player_ship.tscn` is read only: `CoreVisual` sits under `DamageCore`, not `VisualRoot`.

## Files

- **Creates:** `tests/scene/test_game_session_combat.gd`, `tools/validate_combat.gd` (dev check that spawns hostile rings at the ship in the real main scene and captures screenshots), `docs/validation/combat.md`, `docs/engineering/damage-pickups.md`.
- **Edits:**
  - `scripts/session/game_session.gd`:
    - `_ready`: five connections, listed below.
    - `_physics_process`: add `_combat_state.tick(delta)` in the unpaused branch.
    - `const GRAZE_SCORE := 10`.
    - Handlers `_on_player_hit`, `_on_grazed`, `_on_invulnerability_changed`, `_on_score_awarded`, `_on_player_defeated`.
    - `_on_action_requested`: a `&"retry"` case calling `_restart_stage()`, marked `TODO(F10-03)`.
  - `scripts/player/player_controller.gd`: `set_invulnerable_visual(active: bool)`, an export `invulnerability_flicker_hz`, and the flicker in `_process`.
  - `tests/scene/test_game_session_flow.gd`: only where a case asserts that `retry` is unimplemented.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F7-01 row.
  - `docs/HANDOFF_LOG.md`: one entry.
  - `docs/engineering/damage-pickups.md`: new, and its line in `docs/engineering/README.md`.
  - `docs/GUIDE.md`: the Section 6 rows for `game_session.gd` and `player_controller.gd`, and the Section 7 "Player defeated" row.
- **Must not touch:** `scripts/combat/combat_state.gd` (F4-01 is done; a needed change is a note), `scripts/combat/projectile_system.gd` and `projectile_field.gd` (F5, F6), `scripts/ui/hud.gd`, `interface.gd`, `menu_controller.gd` (Defeat text is F10-03 and F11-01), `scenes/player/player_ship.tscn`, `scenes/ui/defeat.tscn`, `scenes/main.tscn` (F6-02 already added the ProjectileSystem export).
- **Conflicts with:**
  - `game_session.gd`: F4-02 and F6-02 come before (Depends on). F6-03 is not ordered against this ticket, so never run the two together; if F6-03 landed first, leave its per-ship weapon wiring as it is. F7-02, F10-01, F10-03, F11-01, F11-02 and F12-03 come after.
  - `player_controller.gd`: F6-03, if it adds a weapon reference there.
  - `test_game_session_flow.gd`: F4-02, F6-02.

## Deliverables

### Connections, made once in `_ready` beside the RunState ones

`_combat_state` lives as long as the Session and the `ProjectileSystem` is `Main/ProjectileRoot`, so a Restart can never double-connect. Handlers read `_player` when they run, so no connection is made per ship.

| Signal | Handler effect |
| --- | --- |
| `projectile_system.player_hit(projectile_id, damage)` | `_combat_state.take_hit(damage)`. Several hits in one tick arrive in field order: the first accepted one starts Invulnerability and the rest are `REJECTED` (combat-hud.md "Hit outcomes"). |
| `projectile_system.grazed(projectile_id)` | `_run_state.add_graze(1)` and `_run_state.add_score(GRAZE_SCORE)` (PLANEJAMENTO: "10 per graze"). The field already awards nothing during Invulnerability and never for a Projectile that hit (F5-02); no second filter here. |
| `_combat_state.invulnerability_changed(invulnerable)` | `projectile_system.set_player_invulnerable(invulnerable)`; when `_player != null`, `_player.set_invulnerable_visual(invulnerable)`. |
| `_combat_state.score_awarded(points)` | `_run_state.add_score(points)`. This is the only path from excess Power Pickups (F7-03) to the Run's score. |
| `_combat_state.defeated` | `_on_player_defeated()`. |

### Ticking

In `_physics_process`, inside the existing `if not get_tree().paused:` branch, after `tick_active`: `_combat_state.tick(delta)`.

### Defeat

`_on_player_defeated()`:

1. `_set_paused(true)` stops the tree (enemies, Projectiles, weapon, ship), stops Active Time in `RunState`, disables the controls and pauses `CombatState`. Since F6-03, `set_controls_enabled(false)` also calls `weapon.set_fire_enabled(false)`, so controls and fire go off together. The signal arrives inside the ProjectileSystem's physics step. Pausing there is allowed; unloading is not, and nothing is unloaded here.
2. `interface.push_overlay(ScreenRouter.DEFEAT, {"checkpoint": ""})` shows `Início da fase` on `Layout/RetryLocation`.

Exactly once per life is CombatState's guarantee. With Defeat on top, `pause` is ignored (F2-04 acts only over the HUD or Pause) and `ui_cancel` is `back_refused`. `retry` calls `_restart_stage()`, which unpauses, restarts `RunState`, reloads, calls `_combat_state.start(...)` (F4-02), begins an Attempt and shows the HUD. `return_to_menu` from Defeat already works.

### Invulnerability feedback

`PlayerController.set_invulnerable_visual(active)`: while active, `_process` toggles `visual_root.visible` at `invulnerability_flicker_hz` (export, 12.0, Claude's proposal, Astra tunes); inactive restores `visible = true`. The Core's `CoreVisual` is under `DamageCore`, so it never flickers (PLANEJAMENTO "Focus and vulnerable core"). A new ship starts visible.

## Tests required

`tests/scene/test_game_session_combat.gd` loads `main.tscn` headless and starts `start_direct_stage` on `stage_01` with the ship at `PlayerStart`. Hostile Projectiles come from `projectile_system.spawn(...)`, aimed at the Core with damage 10. The defeat tests reach 0 Health through `get_combat_state().take_hit(...)`; they test the Session's reaction, and the Projectile path is covered by the first tests.

- `test_first_hit_breaks_the_shield_and_spares_health` (4.C "a shielded hit never damages health", end to end)
- `test_hit_during_invulnerability_is_rejected`
- `test_hit_after_invulnerability_takes_ten_health`
- `test_two_hits_in_one_tick_count_once`
- `test_graze_adds_one_graze_and_ten_score`
- `test_no_graze_while_invulnerable`
- `test_invulnerability_flickers_the_visual_root_but_not_the_core`
- `test_pause_freezes_the_invulnerability_countdown`
- `test_defeat_freezes_the_attempt_and_shows_defeat`: the tree is paused, controls are off, DEFEAT is on top with `Início da fase`, and Active Time is unchanged after 60 ticks.
- `test_defeat_overlay_is_pushed_once`
- `test_retry_restarts_the_stage_with_entry_resources`: a new ship at `PlayerStart`, 100 Health, Shield, two Bombs, `clear_time()` 0, HUD on top.
- `test_menu_from_defeat_returns_to_the_main_menu`
- `test_excess_power_score_reaches_run_state`: ten `collect_power_pickup()` calls, then an eleventh adds 50 once.
- `test_restart_does_not_double_connect`: after two Restarts, one Graze adds 1 Graze and 10 score.

Grep the run for `SCRIPT ERROR`: an error after an assertion still reports PASS.

## Out of scope

The Bomb (F7-02), Pickups (F7-03), Retry from a Checkpoint and its name on Defeat (F10-03), Results (F11-01), a delay or animation before Defeat, hit sounds (F13 is cut pending the user), and a physical-device pass.

## Definition of Done

- `tools/test.ps1` green with no `SCRIPT ERROR`. Named tests exist for the Section 8 items "shield hit, immediate repeated hit, post-invulnerability damage", "no rewards from invulnerability", and exactly-once defeat. No Error-level warnings.
- `tools/validate_combat.gd` run headless first, then windowed. It captures `docs/validation/combat-hit-flicker.png` and `combat-defeat.png`, recorded in `docs/validation/combat.md`.
- `docs/engineering/damage-pickups.md` written from `TEMPLATE.md` ("Session combat wiring", "Defeat"). GUIDE Section 6 rows are updated; the handoff log has an entry; this ticket is `Status: done` with an Outcome; the ROADMAP row is updated.
- One commit: `combat: wire hits, graze and defeat into GameSession`.

## Handoff notes for Astra

The ship's `VisualRoot` flickers at 12 Hz while Invulnerable; the rate is the export `invulnerability_flicker_hz` on `PlayerShip`. The Core stays lit. Defeat freezes the stage under the overlay.

## Outcome (2026-09-23)

Delivered in lane trunk as implementer, verifier and reviewer. `GameSession` makes the five connections once in `_ready`, ticks `CombatState` beside Active Time, turns Core hits into `take_hit`, Grazes into 1 Graze and `GRAZE_SCORE` 10, mirrors Invulnerability to the field and to the ship's blink, forwards excess-Power score, and freezes the Attempt under Defeat; `retry` restarts the stage (`TODO(F10-03)`). `PlayerController` blinks `VisualRoot` at `invulnerability_flicker_hz` 12 while Invulnerable, and shows it when the tree pauses.

- **No new tests** (the user's sprint rule): the fourteen listed cases are the checks of the new `tools/validate_combat.gd`, written and run by the verifier in the real main scene, `COMBAT_OK` headless and windowed with `combat-hit-flicker.png` and `combat-defeat.png`. No existing test needed a change; the suite stays green at 225.
- **Reviewer:** no defects. Its suggestions were applied (doc comments; `VisualRoot` shown on `NOTIFICATION_PAUSED`, so a ship paused mid-blink is not hidden), and a note for F9-02 is in `damage-pickups.md` Open issues: enemies should ignore damage while the tree is paused.
- **F6-03 was not landed** when this ran (its part 1 is oc-a's), so there is no weapon wiring to keep; F6-03 part 2 adds `set_fire_enabled` to `set_controls_enabled` later.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/damage-pickups/issues/01-hit-to-combat-state-and-defeat.md, then implement that ticket. Use /run to verify Shield, damage, flicker and the Defeat overlay in the real main scene. Finish with its Definition of Done and commit.
```
