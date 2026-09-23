# F7 Damage, bomb, pickups — spec

Status: ready-for-agent
Owner: Claude
Source: PLANEJAMENTO.md Section 4; ENGINEERING_BRIEF Sections 4.C, 4.E, 8; GUIDE.md Sections 6 (`pickup.gd`, `player_weapon.gd`, `projectile_system.gd`) and 7 ("Player defeated", "Pickup accepted"); STAGE_DESIGN.md "Shared encounter rules"; `docs/engineering/combat-hud.md` (the real `CombatState` API, F4-01); `docs/engineering/menus-session.md` Open issues (gamepad B is both `ui_cancel` and `bomb`).

## Goal

After F7 the real game has a complete shooting-and-damage loop. Hostile Projectiles that reach the Core break the Shield or take Health, and Invulnerability rejects the follow-up hits. Grazes count and score. Defeat freezes the Attempt under the Defeat overlay. A Bomb press spends one Bomb: it clears hostile fire around the ship, damages enemies in range and grants 2 s of Invulnerability. Power and Shield Pickups upgrade the ship exactly once each.

`CombatState` (F4-01) already owns every rule. F7 adds no new Rules Core. `GameSession` is the "F7 combat adapter" that `combat-hud.md` refers to: it forwards hits, Grazes, Bombs and score between the `ProjectileSystem`, `CombatState` and `RunState`. `Pickup` is the only new Adapter.

## Tickets

1. `01-hit-to-combat-state-and-defeat.md`: hits, Graze, Invulnerability feedback, excess-Power score, defeat and Defeat overlay (Retry = Restart until F10-03).
2. `02-bomb-clear-and-invulnerability.md`: Bomb input edge, hostile clear, radius damage, `bombs_used`, dev blast visual.
3. `03-pickup-adapter-and-rewards.md`: `Pickup` adapter, dev Power and Shield prefabs, proven in the arena harness.

None of the three is parallel-safe. 01 and 02 edit `game_session.gd`, and 03 adds an `Area3D` Adapter and dev scenes. 03 may run right after 01. 02 also needs F6-03 (`PlayerWeapon`).

## Cross-feature contracts

- **Session connections** (all made once in `GameSession._ready`, because the `CombatState` lives as long as the Session (F4-02) and `ProjectileSystem` is `Main/ProjectileRoot` (F6-02)):
  - `projectile_system.player_hit` → `_combat_state.take_hit(damage)`.
  - `projectile_system.grazed` → `run_state.add_graze(1)` and `run_state.add_score(GRAZE_SCORE)`, with `GRAZE_SCORE = 10` (PLANEJAMENTO Section 4).
  - `_combat_state.invulnerability_changed` → `projectile_system.set_player_invulnerable()` and `PlayerController.set_invulnerable_visual()`.
  - `_combat_state.score_awarded` → `run_state.add_score()`. This is the only path for excess-Power score.
  - `_combat_state.defeated` → the defeat handler (F7-01).
  - `_combat_state.bomb_activated` → the Bomb handler (F7-02).
- **Defeat** (F7-01): `_set_paused(true)`, then `interface.push_overlay(DEFEAT, {"checkpoint": ""})`. The `retry` action calls `_restart_stage()` until F10-03 replaces it with Retry from a Checkpoint.
- **Bomb input**: `CombatState.update_bomb_input(held)` is the only edge detector. `PlayerWeapon` (F6-03) is its only caller: it calls it once per physics tick, with `held` tracked from `bomb` events in its `_unhandled_input`. The Session never feeds it, and nothing polls `Input.is_action_just_pressed(&"bomb")`. The B press that resumes Pause is consumed by `Interface`, and pausing marks the button as held, so that press never bombs. F7-02 reacts to `bomb_activated` only.
- **`ProjectileSystem.damage_targets_in_radius(center: Vector3, radius: float, damage: int) -> int`** (F7-02). It calls each registered target's `on_damage` once.
- **`PlayerWeapon` Bomb exports**, added by F7-02 (F6-03 leaves them out): `bomb_radius: float`, `bomb_damage: int`, `bomb_visual_scene: PackedScene`. The Session reaches the weapon as `_player.weapon`, a required `PlayerController` export added by F6-03.
- **`PlayerController.set_invulnerable_visual(active: bool)`** (F7-01). It flickers `VisualRoot` only, so the Core stays visible.
- **`Pickup`** (F7-03), `scripts/combat/pickup.gd`, `class_name Pickup extends Area3D`:
  - `enum Kind { POWER, SHIELD }`; exports `kind`, `attraction_range`, `attraction_speed`.
  - `setup(pickup_id: StringName, combat_state: CombatState, player: Node3D)`.
  - Signal `accepted(pickup_id: StringName, kind: Kind, score_awarded: int)`, emitted exactly once. `score_awarded` is informational only: the points already went to `RunState` through `CombatState.score_awarded`.
  - Dev prefabs: `scenes/dev/power_pickup.tscn`, `scenes/dev/shield_pickup.tscn`. The Stage Director (F10-01) spawns them with ids `&"<encounter_id>/power_<n>"` and `&"<encounter_id>/shield_<n>"`.

## Done when

- All F7 tests pass.
- In the real main scene: a hostile Projectile breaks the Shield, the next ones take 10 Health each, the ship flickers while Invulnerable, and defeat shows Defeat over a frozen stage.
- A Bomb clears a ring of hostile fire around the ship and spends one charge.
- In the arena harness, eleven Power Pickups take Power Level 1 to 3 and then award 50.
- `docs/engineering/damage-pickups.md` holds the Session combat wiring, the Bomb path and the `Pickup` contract.
- GUIDE Section 6 rows for `game_session.gd`, `player_controller.gd`, `player_weapon.gd`, `projectile_system.gd` and `pickup.gd` are updated. Section 10 "Player combat and projectiles" advances.

## Out of scope

- Retry from a Checkpoint and the Checkpoint name on Defeat (F10-03).
- Spawning reward Pickups in a stage (F10-01).
- Results (F11).
- Hit, Bomb and Pickup sounds: F13 Audio is cut pending the user, so `accepted` and `bomb_activated` have no audio consumer.
- Final pickup and blast art (requested from Astra).
- Bomb pickups: none in this delivery (PLANEJAMENTO Section 4).
