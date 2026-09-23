# F12-02 BossController adapter and dev boss prefab

Status: todo
Type: adapter
parallel-safe: no
Depends on: F12-01, F9-02, F4-03
Lane: path
Model: Claude Opus 5.5, solo

> **Sprint note (D-03, D-04):** add an optional `phase_clip: StringName` export, played on `phase_changed` for any index above 0, so the phase-change clip named by D-03 and D-04 has a consumer. Astra's boss scenes come without a root script; F12-03, F12-06 and F12-07 attach this controller to them.

## Goal

`BossController` is the thin Adapter on a boss root. It drives `BossMachine` from `Emitters/Main`, forwards its spawns, registers its hit sphere, joins `targetable`, clears hostile Projectiles when the machine asks, plays animation cues only by clip names that actually exist in the assigned `AnimationPlayer`, warns when a step starts off-screen, and reports the boss's start, Phase changes, Phase health and defeat as signals that fit the HUD boss panel API (F4-03). The Director (F10-01, extended in F12-03) spawns it like an `EnemyActor`. A dev prefab stands in until Astra's `lantern_guardian.tscn` exists.

## Read first

- `docs/GUIDE.md` Section 5 "Enemy and boss prefabs", Section 6 row `boss_controller.gd`, Section 7 "Boss phase changed", Section 15 (`BossStatus`, `Phase1..3`, `AttackName`)
- `docs/MODEL_SELECTION.md` "Boss alternatives and verified animation metadata" (`Flying_Idle` hover, `Fast_Flying` reposition, `Death` defeat; no casting clip; do not assume `Punch` or `Headbutt`)
- `docs/engineering/bosses.md` (F12-01), `docs/engineering/enemies.md` (F9-02 `EnemyActor`: same spawn flow, `threat_side()`), `docs/engineering/weapon-rendering.md` (`ProjectileSystem`: `spawn`, `register_target`, `clear_hostile_all`, priority 10), `docs/engineering/combat-hud.md` (F4-03 `Hud.show_boss`, `set_phase_health`, `show_attack_cue`, `hide_boss`, `show_threat`)

## Files

- **Creates:** `scripts/enemies/boss_controller.gd`, `scenes/dev/dev_boss.tscn`, `scenes/dev/dev_boss_definition.tres` (a three-Phase dev `BossDefinition` kept in `scenes/dev/` so no `content/` value is touched), `tests/scene/test_boss_controller_contract.gd`, `docs/validation/bosses.md`, `docs/validation/bosses-dev-boss.png`.
- **Edits:** `scenes/dev/arena_harness.gd` and `scenes/dev/arena_harness.tscn`: an export `spawn_dev_boss: bool` (off by default) spawns the dev boss in front of the ship; the readout shows its Phase, ratio and current Attack name.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F12-02 row), `docs/HANDOFF_LOG.md`, `docs/engineering/bosses.md` (BossController contract, Setup for Astra), `docs/GUIDE.md` Section 6 row `boss_controller.gd` and Section 7 "Boss phase changed".
- **Must not touch:** `scripts/enemies/boss_machine.gd` (a defect is a note in the Outcome), `scripts/enemies/enemy_actor.gd` (reuse its static `threat_side`, never edit it), `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`, `scripts/progression/stage_director.gd` and `scripts/session/game_session.gd` (F12-03), `scenes/stages/*.tscn`, `content/`.
- **Conflicts with:** F6-03, F7-03 and F9-02 edit `scenes/dev/arena_harness.*`. They are serialized because none of them is parallel-safe.

## Deliverables

- `class_name BossController extends Node3D` on the `Enemy` root. Required exports: `visual_root: Node3D`, `hit_volume: Area3D` (a `SphereShape3D`, whose radius is the hit radius), `emitter: Marker3D`. Optional: `animation_player: AnimationPlayer`, `idle_clip`, `step_clip` and `defeat_clip: StringName` (empty means no cue). At `spawn_setup` a configured clip missing from `animation_player.has_animation()` is reported once with `push_warning` and skipped: clips are chosen by actual names, never assumed.
- `spawn_setup(definition: BossDefinition, enemy_id: StringName, encounter_id: StringName, rng: RandomNumberGenerator, projectile_system: ProjectileSystem, player: Node3D, bounds: AABB)` has EnemyActor's order and meaning. It validates everything (loud and inert on failure), joins `targetable`, connects the machine once, emits `boss_started(definition.display_name, phase_count)`, then calls `machine.start()`, so `phase_changed(0, …)` follows `boss_started`.
- `_physics_process` at priority 0: hover within `bounds` (a slow vertical bob around the marker, Claude's placeholder), `machine.tick(delta, emitter.global_position, player.global_position)`, spawn every request, and `register_target(get_instance_id(), hit_volume.global_position, radius, take_damage)` while not defeated.
- Machine wiring: `hostile_clear_requested` calls `projectile_system.clear_hostile_all()`. `step_started` plays `step_clip`, and emits `threat_reported(EnemyActor.threat_side(...))` when the boss is outside the camera frustum. `phase_changed` and `phase_health_changed` are re-emitted unchanged. `defeated` leaves `targetable`, stops registering, re-emits `defeated(enemy_id, encounter_id)` once, then frees the boss after `defeat_clip` finishes, or at once when there is none.
- `get_score() -> int` returns the definition's score for the Director (F12-03).
- `scenes/dev/dev_boss.tscn`: an `Enemy` root (`boss_controller.gd`), `VisualRoot` (a dev primitive mesh, placeholder policy), `HitVolume` (layer 16, mask 0, monitoring and monitorable off, sphere radius 2.5 as Claude's proposal), `Emitters/Main`. No `AnimationPlayer`.
- `dev_boss_definition.tres`: three Phases with dev patterns and short health for the harness, `metadata/dev = true`, named `"Guardião (dev)"` so it can never be mistaken for real content.

## Tests required

`tests/scene/test_boss_controller_contract.gd`, headless, with a real `ProjectileSystem` and `player_ship.tscn`:

- `test_dev_boss_follows_the_guide_tree`
- `test_spawn_setup_starts_the_boss_and_joins_targetable` (`boss_started(name, 3)` before `phase_changed(0, …)`)
- `test_phase_change_clears_hostile_projectiles` (hostile count 0 after Phase 1 is depleted)
- `test_defeat_reports_once_and_frees_the_boss`
- `test_missing_clip_warns_and_is_skipped` (an `AnimationPlayer` with a library holding only `Flying_Idle`)
- `test_boss_signals_drive_the_hud_panel`: instance `scenes/ui/hud.tscn`, connect the signals to `Hud` in the test the way F12-03's Session will; assert `BossStatus` visible, `BossName`, three bars, the `Phase1` value falls, and `AttackName` shows the next Attack
- `test_missing_setup_argument_is_reported`

## Out of scope

Director spawning, boss score, `boss_defeated` presentation and Session-to-HUD wiring (F12-03); Astra's Lantern Guardian scene; retreat containment; the two-Phase Sentinel (F12-04, cut, although the code supports two Phases).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR` in the output; the tests above; no Error-level warnings.
- `/run`, headless first, then windowed: `spawn_dev_boss` on, the dev boss runs its three Phases, clears Projectiles at each transition, reports its Attack names in the readout, and disappears once on defeat. Recorded in `docs/validation/bosses.md` with `bosses-dev-boss.png`.
- `docs/engineering/bosses.md` updated; GUIDE Section 6 `boss_controller.gd` row with the exact exports; Section 7 row.
- Handoff log entry; `Status: done` with an Outcome; ROADMAP row.
- One commit: `enemies: add BossController and dev boss prefab`.

## Handoff notes for Astra

Your `scenes/enemies/lantern_guardian.tscn` needs the same tree: an `Enemy` root with `boss_controller.gd`, the Ghost as `VisualRoot`, and `HitVolume` and `Emitters/Main` outside the scaled model, with an `AnimationPlayer` reference. Tell Claude which clips to use for idle, a step cue and defeat after inspecting their motion; any name that is not in the player is reported, not silently ignored.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/bosses/issues/02-boss-controller-adapter.md, then implement that ticket. Use /run to verify the dev boss's three Phases, Projectile clears, Attack names and single defeat in the arena harness. Finish with its Definition of Done and commit.
```
