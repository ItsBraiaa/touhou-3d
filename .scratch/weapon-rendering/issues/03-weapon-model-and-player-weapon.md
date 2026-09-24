# F6-03 WeaponModel and PlayerWeapon

Status: done
Type: core+adapter
parallel-safe: no
Depends on: F6-02, F4-01, F4-02
Lane: trunk (part 1: oc-a)
Model: part 1 GPT 5.6 Luna (fallback DeepSeek V4.1 Flash); part 2 Claude Opus 5.5, 2-agent workflow (implementer, reviewer)

> **Split (SPRINT.md):**
> - **Part 1, lane oc-a** (depends only on F4-01): the WeaponModel core `scripts/combat/weapon_model.gd` and its unit tests only. No scene, no `player_weapon.gd`, and no `docs/engineering/weapon-rendering.md`: put its contract in doc comments and the handoff entry. Commit with `(F6-03 part 1)`.
> - **Part 2, lane trunk** (after F6-02 and part 1): PlayerWeapon, `player_ship.tscn` `[shared]`, the arena harness and the module-doc section. It closes the ticket.

> **Sprint note (D-02, F13):** if D-02's `scenes/combat/visuals/familiar.tscn` (Node3D root, no collision) has landed, set `familiar_scene` to it; otherwise ship the dev Familiar and log "swap pending: D-02". F13 is reinstated: F13-03 adds `shots_fired(count: int)` to this script later, so keep the fire path in one function.

## Goal

The ship shoots. A Node-free `WeaponModel` decides, for each physics tick, which shots fire while fire is held:

- the main shot at its cadence;
- two Familiars from Power Level 2;
- faster Familiars with a wider Aim Assist cone at Power Level 3.

`PlayerWeapon` on `PlayerShip/Weapon` turns those shots into player Projectiles through `ProjectileSystem`. They leave from `Muzzle` and the Familiar anchors, rotated by the camera yaw, and correct toward the Target Lock inside the assist cone. The field kills a shot on scenery for its whole travel (ADR-0004). The weapon shows the dev Familiars and feeds the Bomb button to `CombatState` from input events. A dev target dummy registers a hit sphere and flashes, so the arena harness shows it all working. What a Bomb clears and damages is F7-02's.

## Read first

- `docs/PLANEJAMENTO.md` Section 4:
  - "Shots, power, and familiars": hold to fire; Power Level 1 forward shot with aim assist; Power Level 2 adds two orbiting Familiars; Power Level 3 Familiars fire more often with stronger tracking; Familiars have no collision.
  - "Spiritual bomb".
- `docs/ENGINEERING_BRIEF.md` Section 4.E: progress from power 1 through power 3; Familiars do not introduce damage collision volumes.
- `CONTEXT.md` Player terms (Power Level, Familiar, Target Lock, Aim Assist).
- `docs/GUIDE.md` Section 5 "Player", Section 6 row `player_weapon.gd`, Section 13 "Authored player values": `Muzzle` at (0, 0, -1.25), anchors at (∓1.6, 0.25, 0.1).
- `docs/engineering/combat-hud.md` "Bomb input" (`update_bomb_input(held)` once per physics tick; pause and `start()` mark the button held).
- `docs/engineering/menus-session.md` Open issues, the F2-04 bomb finding: B is also `ui_cancel`, so take the Bomb from the event, never from `Input.is_action_just_pressed`.
- `docs/engineering/weapon-rendering.md` (F6-02). `scripts/player/player_controller.gd` (the body and `VisualRoot` never yaw), `scripts/player/camera_rig.gd` (`get_yaw()`, `camera`), `scripts/player/targeting.gd`.

## Files

- **Creates:**
  - `scripts/combat/weapon_model.gd`
  - `scenes/dev/familiar.tscn`: a `Node3D` root and a small emissive `MeshInstance3D`, with no collision object anywhere
  - `scenes/dev/target_dummy.tscn` and `scenes/dev/target_dummy.gd`
  - `tests/unit/combat/test_weapon_model.gd`
  - `tests/scene/test_player_weapon_contract.gd`
  - `tests/scene/test_target_dummy_contract.gd`
- **Edits:**
  - `scripts/combat/player_weapon.gd`: replace Astra's placeholder with `class_name PlayerWeapon extends Node`.
  - `scripts/player/player_controller.gd`: a required export `weapon: PlayerWeapon`, validated; `set_controls_enabled()` also calls `weapon.set_fire_enabled()`.
  - `scenes/player/player_ship.tscn` [shared]: `PlayerShip` `weapon = NodePath("Weapon")`, and the `Weapon` exports `muzzle`, `familiar_anchors`, `camera_rig` and `familiar_scene`. No geometry, transform or visual changes.
  - `tests/scene/test_player_ship_contract.gd`: the new wiring.
  - `scripts/session/game_session.gd`: `_player.weapon.setup(_combat_state, projectile_system, _player.targeting)` at the end of `_load_stage`.
  - `tests/scene/test_game_session_flow.gd`: one new case.
  - `scenes/dev/arena_harness.gd` and `.tscn`:
    - reuse F4-02's `_combat_state` and HUD;
    - `weapon.setup(...)`;
    - three `target_dummy.tscn` instances, set up with the harness `ProjectileSystem`;
    - dev keys `1`, `2` and `3` call `_combat_state.start(n)`;
    - readout: Power Level, player Projectile count, hits per dummy, Bombs.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F6-03 row), `docs/HANDOFF_LOG.md` [shared] entry for `player_ship.tscn`, `docs/engineering/weapon-rendering.md` ("WeaponModel", "PlayerWeapon" and "TargetDummy" sections), `docs/GUIDE.md` Section 6 rows `player_weapon.gd` and `player_controller.gd`, and Section 13 "Familiar anchors" row.
- **Must not touch:**
  - `player_ship.tscn`'s transforms, meshes, shapes, layers and monitoring.
  - `scenes/tests/combat_arena.tscn` (its `Targets/*` stay static targets).
  - `scripts/combat/combat_state.gd` and `scripts/combat/projectile_system.gd`. If an API is missing, record it as an Outcome note.
  - The Bomb radius, damage and visual, which F7-02 adds to `PlayerWeapon`.
- **Conflicts with:**
  - F4-02, F6-02, F7-01 and F7-02, for `game_session.gd` and `test_game_session_flow.gd`.
  - F4-02 and F6-02, for `arena_harness.*`.
  - F7-02, for `player_weapon.gd`.
  - All of these are serialized.

## Deliverables

### `WeaponModel` (`scripts/combat/weapon_model.gd`)

A Rules Core with no Node and no input.

- `enum Source { MAIN, FAMILIAR_LEFT, FAMILIAR_RIGHT }`.
- Inner class `Shot`, with `source: Source` and `assist_degrees: float`.
- Inner class `Tuning`, whose defaults are all Claude's proposals for Astra to tune:
  - `main_interval = 0.1`
  - `familiar_interval_level_2 = 0.25`
  - `familiar_interval_level_3 = 0.15`
  - `main_assist_degrees = 10.0`
  - `familiar_assist_degrees_level_2 = 10.0`
  - `familiar_assist_degrees_level_3 = 20.0`
- `configure(tuning: Tuning)`.
- `tick(delta: float, fire_held: bool, power_level: int) -> Array[Shot]`:
  - It asserts that the level is in 1..3.
  - Each source has a cooldown that counts down every tick and stops at 0.
  - While fire is held, a source whose cooldown is at 0 or below fires and adds its interval. It loops, so a long `delta` fires every due shot and the cadence is frame-rate independent.
  - The first shot of a press fires at once when cooled.
  - Familiars fire only while `familiar_count(power_level)` is above 0.
- `familiar_count(power_level) -> int`: 0 at level 1, 2 at levels 2 and 3.
- `static assist_direction(origin: Vector3, forward: Vector3, target_point: Vector3, max_degrees: float) -> Vector3`: the direction to the target when it is within `max_degrees` of `forward`, otherwise `forward`, always normalized. There is no homing: a shot flies straight.
- `reset()`.
- It has no Bomb logic. The Bomb edge lives in `CombatState`.

### `PlayerWeapon` (`scripts/combat/player_weapon.gd`)

`class_name PlayerWeapon extends Node`, an Adapter.

**Exports:**

- Scene references, all required and validated in `_ready`: `muzzle: Marker3D`, `familiar_anchors: Node3D` (with `Left` and `Right` children), `camera_rig: CameraRig`, `familiar_scene: PackedScene`.
- Shot values, Claude's proposals: `shot_speed = 60.0`, `shot_lifetime = 1.2` (range 72, beyond the 60-unit lock range), `shot_radius = 0.15`, `shot_damage = 1`, `familiar_shot_damage = 1`.
- The six `Tuning` values.

**`setup(combat_state: CombatState, projectile_system: ProjectileSystem, targeting: Targeting)`:**

- Disconnects any previous setup.
- Connects `targeting.target_changed` (and keeps the target) and `combat_state.power_changed` (Familiar visibility).
- Resets the model and shows the Familiars for the current level.
- Enables fire.

**`set_fire_enabled(enabled: bool)`:** when false, no shots and no Bomb feed, and `_bomb_held = false`.

**`_unhandled_input(event)`:** `bomb` pressed sets `_bomb_held` to true, and released sets it to false. Nothing is consumed.

**`_physics_process(delta)`**, which does nothing unless set up and enabled:

- `_model.tick(delta, Input.is_action_pressed(&"fire"), combat_state.get_power_level())`.
- For each shot:
  - Origin: ship position + `Basis(Vector3.UP, camera_rig.get_yaw())` × the local offset (`muzzle.position`, or the `Left` / `Right` anchor position under `familiar_anchors`). The body never yaws (F1-02), so the authored offsets are rotated in code, and no authored node is moved.
  - Forward: `-camera_rig.camera.global_basis.z`, which is where the view looks.
  - Target point: the locked target's `HitVolume` global position while `is_instance_valid`.
  - Direction: `WeaponModel.assist_direction(...)`.
  - `projectile_system.spawn(ProjectileSpawn.new(origin, direction × shot_speed, PLAYER, shot_lifetime, shot_radius, damage))`.
- Then, once per tick, `combat_state.update_bomb_input(_bomb_held)`. A Bomb shows up as `CombatState.bomb_activated()`, which F7-02 connects in the Session. There is no `bomb_requested` signal.

**Familiars:**

- Two `familiar_scene` instances as `top_level` children of `Left` and `Right`, visible while `familiar_count` is above 0.
- In `_process` they sit at the yaw-rotated anchor points with a small visual orbit (Claude's proposal: radius 0.3, one turn per second).
- Shots leave from the anchor point, not the orbiting visual, which keeps them deterministic.

### `PlayerController`

It gains a required export `weapon: PlayerWeapon`. `set_controls_enabled(enabled)` also calls `weapon.set_fire_enabled(enabled)`, so pause, defeat and transitions stop firing with one call.

### `TargetDummy` (dev)

`scenes/dev/target_dummy.gd`, `class_name TargetDummy extends Node3D`, is the root of `target_dummy.tscn`:

- It is in `targetable`.
- It has a `HitVolume` (`Area3D`, layer 5 = 16, mask 0, monitoring off, `SphereShape3D` radius 0.8) and a `Visual` mesh.
- `setup(projectile_system)`.
- Every physics tick it calls `register_target(get_instance_id(), hit_volume.global_position, radius, _on_damage)`.
- `_on_damage(damage)` increments `hit_count` and `damage_taken`, and flashes the material's emission for 0.1 s. It never dies.

## Tests required

`tests/unit/combat/test_weapon_model.gd`:

- `test_holding_fire_shoots_at_the_main_cadence`
- `test_first_shot_fires_on_the_press`
- `test_releasing_fire_stops_shots_and_tapping_cannot_beat_the_cadence`
- `test_large_delta_fires_every_due_shot`
- `test_power_level_1_has_no_familiars`
- `test_power_levels_2_and_3_add_two_familiars` (4.E: progress from power 1 through 3)
- `test_power_level_3_familiars_fire_faster_and_assist_harder`
- `test_assist_aims_at_a_target_inside_the_cone`
- `test_assist_keeps_forward_outside_the_cone`
- `test_reset_clears_cooldowns`

`tests/scene/test_player_weapon_contract.gd`, with the ship, a `ProjectileSystem` and a `CombatState`:

- `test_weapon_exports_are_wired_in_the_ship_scene`
- `test_holding_fire_spawns_player_projectiles_from_the_yaw_rotated_muzzle` (yaw 90°)
- `test_no_shots_before_setup_or_while_fire_is_disabled`
- `test_power_level_2_shows_two_familiars_with_no_collision_object` (ENGINEERING_BRIEF 4.E)
- `test_familiars_add_shots_at_power_level_2`
- `test_assist_aims_shots_at_the_locked_target` (emit `target_changed` with a dummy)
- `test_one_bomb_press_spends_one_bomb` (`tree.root.push_input` of a `bomb` pressed `InputEventAction`, held for 30 ticks: 1 Bomb left)
- `test_bomb_press_begun_while_the_core_is_paused_does_not_bomb`
- `test_set_controls_enabled_false_stops_the_weapon`

`tests/scene/test_target_dummy_contract.gd`:

- `test_dummy_is_targetable_with_a_layer_5_hit_volume`
- `test_shot_at_the_dummy_counts_a_hit`

`test_game_session_flow.gd`: `test_holding_fire_in_a_run_spawns_player_projectiles`.

Release every pressed action in `after_each`. Grep the output for `SCRIPT ERROR`.

## Out of scope

- What a Bomb clears and damages, its radius and its visual (F7-02).
- Hits on the player, Graze and defeat (F7-01).
- Pickups that raise the Power Level in play (F7-03). The harness keys stand in.
- Enemy targets (F9-02).
- Final Familiar and shot art (Astra).
- Shot sounds (F13, cut pending the user).
- Yawing the ship model toward the camera (the F1 design pass).

## Definition of Done

- `tools/test.ps1` is green with no `SCRIPT ERROR`, every test above exists, and there are no Error-level warnings.
- Verified with `/run` in the dev arena harness, headless first and then windowed:
  - holding J fires;
  - locking a dummy with K bends the shots onto it, and it flashes;
  - keys 2 and 3 show Familiars and more shots;
  - shots die on the arena's layer-1 walls;
  - L spends one Bomb per press on the HUD.
- The result is recorded in `docs/validation/weapon-rendering.md` with `docs/validation/weapon-rendering-familiars.png`.
- `docs/engineering/weapon-rendering.md` is updated. The GUIDE Section 6 rows and the Section 13 row are complete. There is a [shared] handoff log entry for `player_ship.tscn`, ticket `Status: done` with an Outcome, and the roadmap row.
- One commit: `combat: [shared] add WeaponModel and PlayerWeapon`.

## Handoff notes for Astra

- In `player_ship.tscn`, only the `PlayerShip` `weapon` reference and the four `Weapon` exports changed.
- Shot values, cadences and assist cones are Claude's proposals, and are Inspector exports on `Weapon`.
- `scenes/dev/familiar.tscn` is a placeholder. A final Familiar scene must have a `Node3D` root and no `CollisionObject3D` (ENGINEERING_BRIEF 4.E).
- The ship's body and `VisualRoot` never yaw today. Shots and Familiars follow the camera yaw in code, so if the F1 pass turns `VisualRoot` toward the view, nothing here changes.
- Aim Assist aims at the target's `HitVolume`, so keep it centered on the visible body.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/weapon-rendering/issues/03-weapon-model-and-player-weapon.md, then implement that ticket. Use /run to verify firing, Aim Assist, Familiars and one-press Bombs in the dev arena harness. Finish with its Definition of Done and commit.
```

## Outcome

Part 1 implementation is committed as `combat: add WeaponModel core (F6-03 part 1)`: the Node-free `WeaponModel` emits cadence-based main/Familiar shots, counts Familiars by Power Level, and provides normalized static Aim Assist direction. No tests were added per the sprint rule. **The land blocker is resolved by the `tools/lane.ps1` fix on `dev-01` (`6a5d801`), synced into this worktree; the generated UID files are handled by sync/land.** F6-03 remains todo for trunk's part 2 (`PlayerWeapon` and scene integration).

**Part 2, lane trunk, 2026-09-23 (closes the ticket).** Implementer and reviewer (the 2-agent shape). `PlayerWeapon` on `PlayerShip/Weapon` fires the `WeaponModel`'s shots through the `ProjectileSystem`:
- from `Muzzle` and the two Familiar anchors, rotated by the camera yaw;
- toward the view point at the lock's depth, bent onto the locked `HitVolume` inside each cone;
- shows two dev Familiars from Power Level 2;
- feeds the `bomb` button from events to `CombatState` once per tick.

Around the weapon:
- `PlayerController` has the required `weapon` export, and `set_controls_enabled()` also toggles fire.
- `player_ship.tscn` [shared] changed only the `weapon` reference and the four `Weapon` exports.
- The Session calls `weapon.setup(...)` in `_load_stage`.
- The dev `familiar.tscn` and `TargetDummy` are added; the arena harness gets the dummies, keys 1 to 3 and the readout.

- **No new tests** (the user's sprint rule); the suite stays green at 225. Verified by a throwaway run in the arena harness, headless and windowed (`WEAPONCHECK_OK`). Shots per 30 ticks were 5, 9 and 13 at levels 1, 2 and 3. A locked dummy took 10 hits in 60 ticks. After a 90° orbit shots fly along the view. No shot passed a wall, and three presses spent the 2 Bombs. Recorded in `docs/validation/weapon-rendering.md` with `weapon-rendering-familiars.png`.
- **Reading beyond the ticket: forward is the view point, not the camera axis.** With `-camera.global_basis.z` from the Muzzle, the camera's parallax put a locked dummy 12.4° off, outside the 10° main cone, and the dummy took 0 hits. Forward now aims at the point on the view's center ray at the target's depth along the view, or at shot range with no lock, at least 8 units ahead of the origin.
- **Reviewer fixes before landing:**
  - the aim point could fall behind the Muzzle for a close target;
  - a collision object at a Familiar scene's root passed the check;
  - `_exit_tree` now disconnects;
  - a target out of the tree is ignored.
- **Swap pending: D-02** (the Familiar scene).
