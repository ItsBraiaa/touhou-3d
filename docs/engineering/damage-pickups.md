# Damage, Bomb and Pickups

Feature F7: what hostile fire, the Bomb and Pickups do in the running game. Started with ticket F7-01 on 2026-09-23. The Session combat wiring and Defeat are CODE_READY (F7-01), and so is the Bomb (F7-02); Pickups (F7-03) append their own section here.

## Purpose

F7-01 makes the ship vulnerable. `GameSession` is the "F7 combat adapter" the combat cores name, with no new Node: it turns the `ProjectileSystem`'s Core hits into `CombatState.take_hit`, its Grazes into Graze and score on `RunState`, mirrors Invulnerability to the field and to the ship's blink, forwards excess-Power score, and freezes the Attempt under the Defeat overlay. `PlayerController` gains the Invulnerability blink of `VisualRoot`.

It does not own any hit, Shield, Invulnerability or Graze rule (`CombatState` and `ProjectileField`), the Bomb (F7-02), Pickups (F7-03), Retry from a Checkpoint and its name on Defeat (F10-03), Results (F11-01), hit sounds (F13-03), or a delay or animation before Defeat.

## Files

- `scripts/session/game_session.gd` (Adapter on `Main`): the connections, the tick, the handlers, `GRAZE_SCORE`, the `retry` action.
- `scripts/player/player_controller.gd` (Adapter on `PlayerShip`): `set_invulnerable_visual()`, the export `invulnerability_flicker_hz`, the blink in `_process`.
- `scripts/combat/projectile_system.gd`: `damage_targets_in_radius` (F7-02). `scripts/combat/player_weapon.gd`: the "Bomb" export group and the physics priority (F7-02).
- `scenes/dev/bomb_blast.gd` and `.tscn` (`BombBlast`, dev only, F7-02).
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

## Bomb

F7-02. A Bomb press in play spends exactly one Bomb and clears hostile fire around the Core, damages the enemies in range, counts in the Run and shows a dev blast.

### Bomb input: not the Session's

`PlayerWeapon` (F6-03) is the only caller of `CombatState.update_bomb_input(held)`: once per physics tick, with `held` tracked from `bomb` press and release events. The rules follow from that:

- The weapon sits under `WorldRoot` (PAUSABLE), so it reads nothing while paused.
- `Interface` consumes the gamepad B press that resumes Pause, so the weapon never sees that press.
- `set_paused(true)` marks the button as held anyway, and a defeated core refuses every edge.

The edge, the charges, the refusal while paused, defeated or empty, and the 2 s of Invulnerability are all `CombatState`'s (F4-01). Nothing polls `Input.is_action_just_pressed(&"bomb")`, and the Session never feeds the edge.

Since F7-02 the weapon's `process_physics_priority` is 50: after every actor (0) has registered its hit sphere and moved, and before the `ProjectileSystem` (100). So a Bomb sees this tick's enemies, and its clear comes before this tick's sweep.

### `GameSession._on_bomb_activated()`

Connected once in `_ready` to `_combat_state.bomb_activated`. With the ship's weapon as `weapon`:

1. `center` is `_player.damage_core.global_position`, the Core's center.
2. `projectile_system.clear_hostile_in_radius(center, weapon.bomb_radius)`: only hostile fire, awarding nothing. A cleared Projectile never grazes, including one inside the Graze Volume in the Bomb's own tick, because the clear runs before the field's sweep.
3. `_run_state.note_bomb_used()`. A later Checkpoint refill does not undo it.
4. If `weapon.bomb_visual_scene` is set, it is instanced under `WorldRoot` at `center` with `setup(bomb_radius)`. Its root must be a `BombBlast`; anything else is reported and dropped.
5. Last, `projectile_system.damage_targets_in_radius(center, weapon.bomb_radius, weapon.bomb_damage)`: every enemy registered in range, once. Bombs damage enemies normally and skip no progression flag (STAGE_DESIGN "Shared encounter rules"). A kill may end the stage (F10), so nothing may follow the damage.

Invulnerability needs no call: `CombatState` already granted `max(remaining, 2.0)` s, and F7-01's `invulnerability_changed` path tells the field and starts the blink.

### `ProjectileSystem.damage_targets_in_radius(center, radius, damage) -> int`

It takes the ids from the field's `targets_in_radius`, the spheres registered for the coming tick, and calls each target's `on_damage.call(damage)` once: the field keeps one sphere per id, so a target registered twice is damaged once. It returns the number of callbacks called. A target that stopped registering is not damaged. It must run after the actors have registered this tick, which the weapon's priority guarantees.

### Weapon exports (the "Bomb" group on `PlayerShip/Weapon`)

| Export | Default | Meaning |
| --- | --- | --- |
| `bomb_radius` | 10.0 | Radius around the Core of the clear and the damage. Claude's proposal. |
| `bomb_damage` | 20 | Damage to every enemy in range. Claude's proposal; it must stay below the smallest boss Phase health (F12). |
| `bomb_visual_scene` | `scenes/dev/bomb_blast.tscn` | The blast, a `BombBlast` scene; swap pending D-02. Unset shows nothing. |

### `BombBlast` (dev)

`scenes/dev/bomb_blast.gd` and `.tscn`, `class_name BombBlast extends Node3D`: a translucent unshaded sphere of radius 1 (`sphere` export) scaled to the Bomb radius by `setup(radius)`. It fades out over `FADE_SECONDS` (0.4) and frees itself. It has no collision, pauses with the tree, and keeps its own copy of the material. It is unloaded with the stage.

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
| One press spends one Bomb, however long it is held (F7-02) | `validate_combat.gd` check 15 |
| A Bomb clears hostile fire within its radius only, and a player shot survives | check 16 |
| Cleared Projectiles award no Graze, even one in the Graze Volume that tick | check 16b |
| A Bomb damages each target in range once, and none outside | check 17 |
| The blast visual appears and frees itself | check 18 |
| A Bomb grants 2 s of Invulnerability: a hit at 1.5 s passes, one at 2.1 s lands | check 19 |
| No Bomb under Pause, from the B press that resumes it, with none left, or when defeated | checks 14, 20, 21 |

## Setup for Astra

- `PlayerShip` has a new export, `invulnerability_flicker_hz` (12.0), in the "Feedback" group: tune it in the Inspector. The Core stays lit.
- Keep `CoreVisual` under `DamageCore`, outside `VisualRoot`, or the Core would blink too.
- Defeat freezes the stage under the overlay; there is no death animation yet.
- `PlayerShip/Weapon` has a "Bomb" group: `bomb_radius` (10.0), `bomb_damage` (20) and `bomb_visual_scene` (dev `scenes/dev/bomb_blast.tscn`). Tune the numbers, or replace the visual with a final effect (D-02) that keeps later attacks readable (PLANEJAMENTO: "The blast effect must preserve visibility of subsequent attacks"). A final effect is wrapped in a `BombBlast` root with `setup(radius)`.

## Open issues

- **No scene tests** (sprint rule); `validate_combat.gd` is the evidence.
- **Pausing mid-blink.** `_process` stops while the tree is paused, so `PlayerController` shows `VisualRoot` on `NOTIFICATION_PAUSED`; the blink resumes with the tree.
- **Every Core hit is preceded by a Graze** a few ticks earlier on a head-on path (weapon-rendering.md Open issues); a ruling for D-07 Part B or a field change, not a Session filter.
- **Retry restarts the stage** until F10-03; the Defeat screen always names `Início da fase`.
- **Bomb damage never empties a boss Phase** is F12's to prove (BossMachine caps overflow); `bomb_damage` must stay below the smallest Phase health.
- **Swap pending: D-02** (the blast visual).
- **A target the Bomb kills stays registered for the rest of that tick**, so a player shot in the same tick can damage it again: enemy adapters (F9-02, F12-02) must ignore damage once defeated (reviewer note).
- **For F9-02 (reviewer note):** a player shot that meets an enemy later in the same tick as the defeating hit still reaches that enemy's `on_damage`, because the field emits the tick's events after the pause starts. Enemy adapters should ignore damage while the tree is paused.
