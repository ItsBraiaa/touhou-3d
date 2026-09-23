# Damage, Bomb and Pickups

Feature F7: what hostile fire, the Bomb and Pickups do in the running game. Started with ticket F7-01 on 2026-09-23. The Session combat wiring and Defeat are CODE_READY (F7-01); the Bomb clear (F7-02) and Pickups (F7-03) are not built yet, and each appends its own section here.

## Purpose

F7-01 makes the ship vulnerable. `GameSession` is the "F7 combat adapter" the combat cores name, with no new Node: it turns the `ProjectileSystem`'s Core hits into `CombatState.take_hit`, its Grazes into Graze and score on `RunState`, mirrors Invulnerability to the field and to the ship's blink, forwards excess-Power score, and freezes the Attempt under the Defeat overlay. `PlayerController` gains the Invulnerability blink of `VisualRoot`.

It does not own any hit, Shield, Invulnerability or Graze rule (`CombatState` and `ProjectileField`), the Bomb (F7-02), Pickups (F7-03), Retry from a Checkpoint and its name on Defeat (F10-03), Results (F11-01), hit sounds (F13-03), or a delay or animation before Defeat.

## Files

- `scripts/session/game_session.gd` (Adapter on `Main`): the connections, the tick, the handlers, `GRAZE_SCORE`, the `retry` action.
- `scripts/player/player_controller.gd` (Adapter on `PlayerShip`): `set_invulnerable_visual()`, the export `invulnerability_flicker_hz`, the blink in `_process`.
- `tools/validate_combat.gd`: the dev check, run in the real main scene (see [validation/combat.md](../validation/combat.md)).
- No test file: the sprint's no-new-tests rule (2026-09-23).

## Session combat wiring

### Connections

Made once in `GameSession._ready`, beside the `RunState` ones. `_combat_state` lives as long as the Session and the `ProjectileSystem` is `Main/ProjectileRoot`, so no Restart or Retry can double them; the handlers read `_player` when they run.

| Signal | Handler effect |
| --- | --- |
| `projectile_system.player_hit(projectile_id, damage)` | `_combat_state.take_hit(damage)`. The field reports at most one hit per tick and treats the rest of that tick as Invulnerable; the core rejects any hit it receives while Invulnerable. |
| `projectile_system.grazed(projectile_id)` | `_run_state.add_graze(1)` and `_run_state.add_score(GRAZE_SCORE)` (10, PLANEJAMENTO Section 4). The field already awards nothing during Invulnerability; nothing is filtered here. |
| `_combat_state.invulnerability_changed(invulnerable)` | `projectile_system.set_player_invulnerable(invulnerable)`, and `_player.set_invulnerable_visual(invulnerable)` while a ship is loaded. |
| `_combat_state.score_awarded(points)` | `_run_state.add_score(points)`: the only path from an excess Power Pickup to the Run's score. |
| `_combat_state.defeated` | `_on_player_defeated()` (below). |

### Ticking

`GameSession._physics_process`, only while the tree is not paused: `_run_state.tick_active(delta)`, then `_combat_state.tick(delta)`. `Main` has the default physics priority and `ProjectileRoot` 100, so an Invulnerability window that ends this tick is already off in the field's sweep of the same tick.

### Invulnerability feedback

`PlayerController.set_invulnerable_visual(active: bool)`: while active, `_process` shows `VisualRoot` for the first half of each cycle of `invulnerability_flicker_hz` (export in the new "Feedback" group, 12.0, Claude's proposal) and hides it for the second; stopping shows it again. `CoreVisual` is under `DamageCore`, not `VisualRoot`, so the Core never blinks (PLANEJAMENTO "Focus and vulnerable core"). A new ship starts shown and still. When the tree pauses (Pause, Defeat) the ship shows `VisualRoot`, since `_process` stops and a hidden frame would stay hidden.

## Defeat

`_on_player_defeated()`, once per life (the core's guarantee):

1. `_set_paused(true)`: the tree stops (the stage, enemies, Projectiles, the ship), `RunState` stops Active Time, the ship's controls go off, and `CombatState` pauses. The signal arrives inside the ProjectileSystem's physics step; pausing there is allowed, unloading is not, and nothing is unloaded.
2. `interface.push_overlay(ScreenRouter.DEFEAT, {"checkpoint": ""})`, so `Layout/RetryLocation` reads `Início da fase`.

With Defeat on top, `pause` is ignored (the Session acts on it only over the HUD or Pause) and `ui_cancel` is `back_refused`. `retry` calls `_restart_stage()` until F10-03 adds Checkpoints (PLANEJAMENTO Section 6: before any intermediate Checkpoint, Retry restarts the stage): it unpauses, restarts `RunState`, calls `_combat_state.start(...)`, reloads the stage and the ship, begins an Attempt and shows the HUD. `return_to_menu` from Defeat unloads everything and shows the main menu.

## Dependencies

- `CombatState` (F4-01), owned by the Session since F4-02.
- `ProjectileSystem` (F6-02): `player_hit`, `grazed`, `set_player_invulnerable`.
- `RunState` (F2-03): `add_graze`, `add_score`.
- `Interface` (F2-02) and the Defeat screen's `MenuController`, which writes the retry location from the `checkpoint` parameter.

## Invariants and tests

The sprint's no-new-tests rule (2026-09-23) replaced the ticket's fourteen scene tests with `tools/validate_combat.gd`, a check of the same behaviours in the real main scene; results in [validation/combat.md](../validation/combat.md).

| Invariant (ENGINEERING_BRIEF Section 8, the ticket) | Evidence |
| --- | --- |
| A shielded hit never damages Health, end to end | `validate_combat.gd` |
| An immediate repeated hit is rejected; a hit after Invulnerability takes 10 | `validate_combat.gd` |
| Two hits in one tick count once | `validate_combat.gd` |
| A Graze adds 1 Graze and 10 score; none while invulnerable (no rewards from Invulnerability) | `validate_combat.gd` |
| `VisualRoot` blinks while invulnerable, the Core does not | `validate_combat.gd` |
| Pause freezes the Invulnerability countdown | `validate_combat.gd` |
| Defeat freezes the Attempt and shows Defeat once (exactly-once defeat) | `validate_combat.gd` |
| Retry restarts with the entry resources; Menu from Defeat returns to the main menu | `validate_combat.gd` |
| Excess-Power score reaches `RunState` once | `validate_combat.gd` |
| Restarts never double a connection | `validate_combat.gd` |

## Setup for Astra

- `PlayerShip` has a new export, `invulnerability_flicker_hz` (12.0), in the "Feedback" group: tune it in the Inspector. The Core stays lit.
- Keep `CoreVisual` under `DamageCore`, outside `VisualRoot`, or the Core would blink too.
- Defeat freezes the stage under the overlay; there is no death animation yet.

## Open issues

- **No scene tests** (sprint rule); `validate_combat.gd` is the evidence.
- **Pausing mid-blink.** `_process` stops while the tree is paused, so `PlayerController` shows `VisualRoot` on `NOTIFICATION_PAUSED`; the blink resumes with the tree.
- **Every Core hit is preceded by a Graze** a few ticks earlier on a head-on path (weapon-rendering.md Open issues); a ruling for D-07 Part B or a field change, not a Session filter.
- **Retry restarts the stage** until F10-03; the Defeat screen always names `Início da fase`.
- **For F9-02 (reviewer note):** a player shot that meets an enemy later in the same tick as the defeating hit still reaches that enemy's `on_damage`, because the field emits the tick's events after the pause starts. Enemy adapters should ignore damage while the tree is paused.
