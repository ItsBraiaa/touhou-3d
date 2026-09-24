# F7-03 Pickup adapter and rewards

Status: done
Type: adapter
parallel-safe: no
Depends on: F7-01
Lane: trunk
Model: Claude Opus 5.5, solo

> **Sprint note (D-02, F13):** F13 is reinstated; `accepted` reaches audio through `StageDirector.pickup_accepted` in F13-03. Hold `Visual` as a `Node3D`, not a `MeshInstance3D`, so D-02's `power_pickup_visual.tscn` and `shield_pickup_visual.tscn` can be instanced as `Visual`. Instance them if they have landed; otherwise keep the dev meshes and log "swap pending: D-02". Collision, layers, masks, monitoring and the script stay in the Claude-owned prefab.

## Goal

`Pickup` is the Adapter on a Power Pickup or Shield Pickup root `Area3D`. It floats in space and attracts toward the player at short range. It is accepted exactly once, on contact, through `CombatState.collect_power_pickup()` or `collect_shield_pickup()`. A Shield Pickup stays in the world while the player already has a Shield (PLANEJAMENTO Section 4). This ticket ships dev prefabs for both kinds and proves them in the arena harness. The Stage Director (F10-01) spawns them from rewards; this ticket does not edit the Session.

## Read first

- `docs/PLANEJAMENTO.md` Section 4 "Shots, power, and familiars": five Power Pickups per level, excess awards score, pickups float and attract at short range, and have distinct shapes and colors. Also "Health and shield".
- `docs/engineering/combat-hud.md`:
  - "Power": `collect_power_pickup()` returns false only while not live, and at Power Level 3 it emits `score_awarded(50)`.
  - `collect_shield_pickup()` returns false while not live or already shielded.
  - Open issues (d) and (g): dedup is this adapter's job.
- `docs/engineering/damage-pickups.md`: `score_awarded` reaches `RunState` through F7-01's one connection.
- `docs/ENGINEERING_BRIEF.md` Section 4.E and Section 8 ("duplicate pickup callbacks").
- `docs/GUIDE.md` Section 6 `pickup.gd` row and Section 7 "Pickup accepted"; `docs/engineering/CONVENTIONS.md` "Collision" (player body is layer 2).
- `scenes/dev/arena_harness.gd` and `.tscn`: F4-02 gives the harness its own `CombatState`.

## Files

- **Creates:** `scripts/combat/pickup.gd`, `scenes/dev/power_pickup.tscn`, `scenes/dev/shield_pickup.tscn`, `tests/scene/test_pickup.gd`, `docs/validation/pickups-arena.png` (the capture).
- **Edits:**
  - `scenes/dev/arena_harness.gd` and `scenes/dev/arena_harness.tscn`: on `_ready` the harness spawns eleven Power Pickups in a row and one Shield Pickup, bound to its `CombatState` and ship. A readout line shows Power Level, Power Progress, Shield and the score awarded.
  - `docs/validation/combat.md`: a "Pickups" section.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F7-03 row, plus the "Requests to Astra" F7 row, which now points at the contract.
  - `docs/HANDOFF_LOG.md`: one entry.
  - `docs/engineering/damage-pickups.md`: a "Pickup contract" section.
  - `docs/GUIDE.md`: the Section 6 `pickup.gd` row and the Section 7 "Pickup accepted" row.
- **Must not touch:** `scripts/session/game_session.gd` (the Director spawns pickups in F10-01), `scripts/combat/combat_state.gd`, `scenes/stages/*.tscn`, `scripts/progression/*`, `scenes/tests/combat_arena.tscn` (Astra's; the harness adds its pickups at runtime).
- **Conflicts with:** `arena_harness.*`, edited by F4-02 and F6-02 (before) and F6-03 (not ordered against this ticket, so never run the two together).

## Deliverables

`scripts/combat/pickup.gd`, `class_name Pickup extends Area3D`:

- **Type and signal.** `enum Kind { POWER, SHIELD }`, and `signal accepted(pickup_id: StringName, kind: Kind, score_awarded: int)`, emitted exactly once, just before the pickup frees itself.
- **Exports.** `kind: Kind = POWER`, `attraction_range: float = 6.0` and `attraction_speed: float = 14.0`. The two numbers are Claude's proposal, Astra tunes them; PLANEJAMENTO says only "short range".
- **`setup(pickup_id: StringName, combat_state: CombatState, player: Node3D)`.** It is called by the spawner after `add_child`. A null argument or an empty id is reported with `push_error` naming the node path, and the pickup stays inert. Before `setup` it does nothing.
- **Contact.** `_ready` connects its own `body_entered` and `body_exited` to track whether the `player` body is inside; other bodies are ignored. Acceptance runs in `_physics_process`: every tick the player overlaps and the pickup is not yet accepted, it tries once. This is why a Shield Pickup touched while shielded is collected on the first tick after the Shield breaks, without a new `body_entered`.
  - POWER: read `was_max := combat_state.get_power_level() == CombatState.MAX_POWER_LEVEL`. If `collect_power_pickup()` returns true, accept with `score_awarded = CombatState.EXCESS_PICKUP_SCORE if was_max else 0`.
  - SHIELD: if `collect_shield_pickup()` returns true, accept with 0. Otherwise it stays: not freed, not consumed.
- **Accept.** Set `_accepted`, `set_deferred("monitoring", false)` and `set_physics_process(false)`, emit `accepted`, then `queue_free()`. A second attempt returns at once, which makes duplicate callbacks harmless. `score_awarded` is informational: the 50 points already reached `RunState` through `CombatState.score_awarded`, and no consumer may add them again.
- **Attraction.** While not accepted, within `attraction_range` of the player, and takeable, the pickup moves toward `player.global_position` by `attraction_speed * delta` without overshooting. A Power Pickup is takeable while `CombatState` is live. A Shield Pickup is takeable only while the player has no Shield, so it never trails a shielded ship (Claude's proposal).
- **Pause.** The pickup sits under `WorldRoot` or `RuntimeActors`, which are PAUSABLE, so it freezes while paused. CombatState also refuses while paused or defeated.

Dev prefabs (Claude's `scenes/dev/`):

- **Common tree.** Root `Pickup` (`Area3D` with `pickup.gd`, `collision_layer` 0, `collision_mask` 2, `monitoring` true, `monitorable` false), a `Collision` `CollisionShape3D` with a 0.9-radius sphere, and a `Visual` `MeshInstance3D` with an unshaded emissive material.
- **Distinct shapes and colors.** `power_pickup.tscn` (kind POWER) is a gold rotated cube, 0.6 across. `shield_pickup.tscn` (kind SHIELD) is a cyan torus. A slow spin of `Visual` in `_process` is optional.

Spawner id convention for F10-01: `&"<encounter_id>/power_<n>"` and `&"<encounter_id>/shield_<n>"`, with n from 1.

## Tests required

`tests/scene/test_pickup.gd` builds a small tree in code. A `CharacterBody3D` on layer 2 with a sphere collider stands in for the player. A `CombatState` is started at Power Level 1. Pickups come from the dev prefabs, and the test awaits physics frames.

- `test_power_pickup_is_accepted_once_on_contact`: progress becomes 1, `accepted` fires once, and the pickup is freed.
- `test_duplicate_callbacks_credit_once`: `body_entered` is emitted twice in one tick, plus a second overlapping tick; progress is 1 (ENGINEERING_BRIEF Section 8).
- `test_five_pickups_raise_the_power_level`
- `test_eleventh_pickup_awards_fifty_once`: the payload is 50 and `CombatState.score_awarded` fires once.
- `test_shield_pickup_stays_while_shielded`: not freed, not accepted, not attracted. After `take_hit` breaks the Shield, it is collected on the next tick.
- `test_pickup_attracts_within_range_only`: at distance 4 it gets closer; at distance 10 it stays put.
- `test_pickup_ignores_other_bodies`
- `test_nothing_is_accepted_while_combat_is_paused_or_defeated`
- `test_pickup_without_setup_is_inert_and_reports_bad_setup`
- `test_dev_prefabs_follow_the_contract`: root script, layer 0, mask 2, monitoring on, and the right kind.

## Out of scope

- Spawning reward bundles at `RewardOrigin` and `ShieldPickup`, and which Encounter drops what (F10-01 with F8-04 content).
- A pickup sound or `pickup_accepted` audio routing (F13 is cut pending the user; the signal has no audio consumer).
- Final pickup art (Astra).
- Bomb and Health pickups, none in this delivery.

## Definition of Done

- `tools/test.ps1` green with no `SCRIPT ERROR`.
- Named tests exist for "duplicate pickup callbacks", "power thresholds" and "excess score" (Section 8) and for the Shield-pickup rule. No Error-level warnings.
- The harness verified with `/run`, headless first, then windowed: flying the row takes Power 1 → 2 → 3, then +50, and the Shield Pickup stays while shielded. Captured as `docs/validation/pickups-arena.png`.
- Module doc, GUIDE Section 6 and 7 rows; handoff log entry; `Status: done` with an Outcome; ROADMAP row.
- One commit: `combat: add Pickup adapter and dev pickup prefabs`.

## Handoff notes for Astra

- For final Power Pickup and Shield Pickup scenes, keep the dev prefab's root contract: an `Area3D` with `pickup.gd`, `kind` set, `collision_layer` 0, `collision_mask` 2, `monitoring` on, and a `CollisionShape3D` child.
- Tune `attraction_range` and `attraction_speed` there. Shapes and colors must differ between the two kinds.
- Tell Claude the paths, and F10's Director exports will point at them.

## Outcome

Done 2026-09-23 by trunk (Claude, solo).

`Pickup` (`scripts/combat/pickup.gd`) follows the Deliverables as written: `Kind`, `accepted(pickup_id, kind, score_awarded)` once before `queue_free()`, the three exports, `setup()` with a loud inert failure, contact tracked from its own `body_entered` and `body_exited` and polled in `_physics_process`, attraction with `move_toward`, and a Shield Pickup that is refused, unattracted and kept while shielded.

- **D-02 had landed**, so both dev prefabs instance `scenes/combat/visuals/power_pickup_visual.tscn` and `shield_pickup_visual.tscn` as `Visual` (a `Node3D`); no swap is pending. The roots are named `PowerPickup` and `ShieldPickup`, so a remote tree tells them apart.
- **No new tests** (the user's sprint rule): `tests/scene/test_pickup.gd` was not written. A throwaway script outside the repo drove the real arena harness through the ticket's ten cases, `PICKUPS_OK` headless and in a window; results and `pickups-arena.png` are in `docs/validation/combat.md` "Pickups". The suite stays green at 225.
- **Harness additions beyond the spawn and the readout:** the dev key H calls `take_hit()` once, so the Shield Pickup can be taken by hand (the harness never ticks its core, so the Invulnerability lasts until a 1/2/3 restart). It is inside the harness files.
- **One guard beyond the text:** each tick checks the `player` with `is_instance_valid`, so a ship replaced while Pickups stay (F10-03) cannot crash them; such a Pickup needs a new `setup`.
- **For F10-01:** spawn under the stage's `RuntimeActors` (PAUSABLE), call `setup(## Kickoff prompt"<encounter_id>/power_<n>", combat_state, ship)` after `add_child`, and connect `accepted`; never add its `score_awarded` to the Run.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/damage-pickups/issues/03-pickup-adapter-and-rewards.md, then implement that ticket. Use /run to verify pickups attract, upgrade Power 1 to 3 then award 50, and a Shield Pickup stays while shielded in the arena harness. Finish with its Definition of Done and commit.
```
