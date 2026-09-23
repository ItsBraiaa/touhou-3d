# F9-02 EnemyActor adapter and dev Spirit and Sentry prefabs

Status: todo
Type: adapter
parallel-safe: no
Depends on: F9-01, F6-02
Lane: sol

## Goal

A Spirit and a Sentry that fight in a real scene. `EnemyActor` is the thin Adapter around `EnemyModel`: it copies the model's position, forwards its spawns to the `ProjectileSystem`, registers its hit sphere every physics tick, joins `targetable` so Target Lock and Aim Assist find it, shows a dev Anticipation cue, warns when it starts an attack from off-screen, and reports `defeated(enemy_id, encounter_id)` once before freeing itself. The dev prefabs follow GUIDE Section 5 with Astra's visual variants as `VisualRoot`, so her final prefabs can replace them one to one. The spawn API is what the Director (F10-01) calls.

## Read first

- `docs/GUIDE.md` Section 5 "Enemy and boss prefabs", Section 6 row `enemy_actor.gd`, Section 7 "Enemy defeated"
- `docs/ENEMY_VISUAL_HANDOFF.md` (instance a visual scene as `VisualRoot`; keep `HitVolume` and `Emitters` outside the scaled `Model`; clips `Flying_Idle` and `Death`; no casting clip); `docs/MODEL_SELECTION.md` "Boss alternatives and verified animation metadata"
- `docs/engineering/enemies.md` (F9-01); `docs/engineering/weapon-rendering.md` (F6-02 `ProjectileSystem`: `spawn`, `register_target(target_id, center, radius, on_damage)`, `targets_in_radius`, `count`; it runs at `process_physics_priority` 10, so enemies register at the default 0 or lower)
- `docs/engineering/player-flight.md` "Targeting" (every lockable is a `Node3D` in `targetable` with a `HitVolume` child, its volumes off layer 1)
- `docs/engineering/CONVENTIONS.md` "Collision" (layer 5, bit 16), "Architecture rules" (loud setup errors, one connection place)

## Files

- **Creates:** `scripts/enemies/enemy_actor.gd`, `scenes/dev/spirit.tscn`, `scenes/dev/sentry.tscn`, `content/enemies/spirit.tres`, `content/enemies/sentry.tres`, `content/patterns/spirit_aimed_burst.tres`, `content/patterns/sentry_fan.tres` (every `.tres` has `metadata/dev = true`), `tests/scene/test_enemy_actor_contract.gd`, `docs/validation/enemies.md`, `docs/validation/enemies-arena.png`.
- **Edits:** `scenes/dev/arena_harness.gd` and `scenes/dev/arena_harness.tscn`: spawn one Spirit and one Sentry in front of the ship with a harness-owned seeded RNG, through the harness's `ProjectileSystem` (from F6-02/F6-03; if the harness has none, add one under its root here), and show `hp` and `threat` in the readout.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F9-02 row), `docs/HANDOFF_LOG.md`, `docs/engineering/enemies.md` (EnemyActor contract, Setup for Astra), `docs/GUIDE.md` Section 6 row `enemy_actor.gd`, Section 7 "Enemy defeated" (final signature), Section 10 "Common enemies and miniboss".
- **Must not touch:** `scenes/enemies/visuals/*.tscn` (Astra's: instanced, never edited), `scenes/tests/combat_arena.tscn`, `scenes/stages/*.tscn`, `scenes/main.tscn`, `scripts/combat/projectile_system.gd` (an API gap is a dependency note), `scripts/enemies/enemy_model.gd` (F9-01's; a fix is a note in the Outcome), `scripts/session/game_session.gd`, `scripts/progression/*`.
- **Conflicts with:** F6-03, F7-03 and F12-02 edit `scenes/dev/arena_harness.*` too. They are serialized because none of them is parallel-safe.

## Deliverables

- `class_name EnemyActor extends Node3D` on the `Enemy` root. Exports (required, checked in `_ready` with `push_error` naming the node path and the field): `visual_root: Node3D`, `hit_volume: Area3D` (its first `CollisionShape3D` must hold a `SphereShape3D`, whose radius is the hit radius), `emitter: Marker3D` (`Emitters/Main`). Physics processing stays off until `spawn_setup`.
- `spawn_setup(definition: EnemyDefinition, enemy_id: StringName, encounter_id: StringName, rng: RandomNumberGenerator, projectile_system: ProjectileSystem, player: Node3D, bounds: AABB)`. The Director calls it after `add_child` under `RuntimeActors`, with the actor at its marker's global transform. It validates every argument (a null or an invalid definition is reported, and the actor stays inert), builds the `EnemyModel` from `global_position`, connects the model's signals once, joins `targetable` and starts physics.
- `_physics_process(delta)` at priority 0: `model.tick(delta, player.global_position, emitter.global_position - global_position)`, then `global_position = model.get_position()`, then `projectile_system.spawn()` for each request, then `register_target(get_instance_id(), hit_volume.global_position, radius, take_damage)`.
- `take_damage(damage: int)` is the `on_damage` Callable and forwards to the model.
- Anticipation cue (dev): a `Tween` pulse of `visual_root.scale` over `anticipation_seconds` (Claude's placeholder until Astra picks a clip). `Flying_Idle` keeps autoplaying.
- Off-screen warning: on `anticipation_started`, if `get_viewport().get_camera_3d()` exists and `not camera.is_position_in_frustum(global_position)`, emit `threat_reported(threat_side(camera.global_transform, global_position))`. `static func threat_side(camera_transform: Transform3D, point: Vector3) -> int` returns -1 when the point is left of the camera and +1 otherwise.
- Defeat: leave `targetable`, stop physics, emit `defeated(enemy_id, encounter_id)` once, `queue_free()`. Death clip playback is deferred. Score is the Director's (`definition.score` to `RunState.add_score`, F10-01).
- `scenes/dev/spirit.tscn` and `scenes/dev/sentry.tscn`: an `Enemy` root (Node3D, `enemy_actor.gd`); `VisualRoot`, an instance of `scenes/enemies/visuals/spirit_lume.tscn` or `sentry_lantern.tscn`; `HitVolume` (Area3D, layer 16, mask 0, monitoring and monitorable off) with a `CollisionShape3D` sphere (Claude's proposal: Spirit radius 1.0 at y 1.1, Sentry 0.9 at y 0.8; Astra tunes); `Emitters/Main` (Marker3D at the hit center). No `AnimationPlayer` of their own: the visual's `Model/AnimationPlayer` is used.
- Dev content: `spirit.tres` (kind `spirit`, DRIFT, `score` 100, `anticipation_seconds` 1.0, pattern `spirit_aimed_burst.tres`) and `sentry.tres` (kind `sentry`, HOVER, 100, 1.0, `sentry_fan.tres`). Health, `attack_interval`, movement and pattern numbers are Claude's proposals, derived in-session from F6-03's recorded shot damage and cadence (roughly 2 s of Power Level 1 fire for a Spirit, 3 s for a Sentry). Astra tunes them.
- F6-03 (`PlayerWeapon`) is expected to be done first in roadmap order, but this ticket only depends on F6-02. If F6-03 is not done, the harness damages enemies by spawning PLAYER-faction `ProjectileSpawn`s from the ship on a dev key, the health proposal uses the projectile damage `weapon-rendering.md` documents, and the Outcome records both.

## Tests required

`tests/scene/test_enemy_actor_contract.gd`, headless, with a real `ProjectileSystem` and the real `player_ship.tscn`:

- `test_dev_prefabs_follow_the_guide_tree` (both prefabs: root `EnemyActor`, `VisualRoot`, `HitVolume` sphere, `Emitters/Main`)
- `test_hit_volume_is_a_geometry_source_on_layer_5`
- `test_actor_is_inert_until_spawn_setup` (not in `targetable`, registers nothing)
- `test_spawn_setup_joins_targetable_and_registers_its_hit_sphere` (after one physics frame, `targets_in_radius` finds `get_instance_id()`)
- `test_first_shots_follow_the_anticipation` (no hostile Projectile before 1 s, some after)
- `test_damage_defeats_once_and_frees_the_actor` (overkill twice: one `defeated` with both ids, out of `targetable`, queued for deletion)
- `test_missing_setup_argument_is_reported` (the expected `push_error` lines; grep `SCRIPT ERROR` separately)
- `test_threat_side_is_left_or_right`
- `test_dev_enemy_content_is_valid`

## Out of scope

Spawning from Encounters, score awarding, PortalLinks (F10-01/02); per-wave visual variants (lume or twilight); Death and HitReact playback; vertical off-screen warnings (GUIDE Section 15: the samples are left and right only); Tempest Sentinel (F12, cut); Seal guards (F9-03).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR` in the output; named tests above; no Error-level warnings.
- `/run`, headless first, then windowed: in the arena harness a Spirit and a Sentry appear, pulse for 1 s, fire their patterns, lose health to player shots, and vanish on defeat with one report each; an enemy behind the camera reports its side. Recorded in `docs/validation/enemies.md` with `enemies-arena.png`.
- `docs/engineering/enemies.md` updated (contract, Setup for Astra); GUIDE Section 6 `enemy_actor.gd` row with the exact exports; Section 7 and 10 rows.
- Handoff log entry; `Status: done` with an Outcome; ROADMAP row.
- One commit: `enemies: [shared] add EnemyActor and dev Spirit and Sentry prefabs` (`content/*.tres` values are Astra's).

## Handoff notes for Astra

Your final `scenes/enemies/spirit.tscn` and `sentry.tscn` can copy the dev tree exactly: an `Enemy` root with `enemy_actor.gd` and its three references, your visual as `VisualRoot`, and `HitVolume` and `Emitters` outside the scaled `Model`. Tune the hit radius on the `HitVolume` sphere and the values in `content/enemies/*.tres` and `content/patterns/*.tres` (drop `metadata/dev` when reviewed). Pick an Anticipation gesture if one of the clips reads well; the Tween pulse is a placeholder.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/enemies/issues/02-dev-prefabs-and-enemy-actor.md, then implement that ticket. Use /run to verify a Spirit and a Sentry spawning, anticipating, firing and being defeated in the arena harness. Finish with its Definition of Done and commit.
```
