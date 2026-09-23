# F12 Bosses — spec

Status: ready-for-agent (F12-04 cut pending the user, 2026-09-23)
Owner: Claude
Source: STAGE_DESIGN.md Stage 1 "Final boss sequence", Stage 2 "Miniboss" and "Final boss sequence"; PLANEJAMENTO.md Section 4 "Bosses and named attacks", "Graze and score"; ENGINEERING_BRIEF Section 4.F and 8; GUIDE.md Section 5 "Enemy and boss prefabs", Section 15 (boss panel); MODEL_SELECTION.md (clip names).

## Goal

The Lantern Guardian ends Stage 1. Its three Phases each have their own health bar and a named Attack. Depleting a Phase never carries excess damage into the next. Each transition clears hostile Projectiles and briefly announces the next Attack in Portuguese. The boss is defeated exactly once, and S1-07 completes from that defeat rather than from its ExitVolume. The rules live in a Node-free `BossMachine`; `BossController` is the thin Adapter the Director spawns like any enemy. The Tempest Sentinel and the Storm Guardian (F12-04) are cut pending the user, because they need Stage 2 gameplay and Astra's boss scenes.

## Tickets

1. `01-boss-machine-core.md` (parallel-safe): the boss Definitions and `BossMachine`.
2. `02-boss-controller-adapter.md`: `BossController` and the dev prefab `scenes/dev/dev_boss.tscn`.
3. `03-lantern-guardian-in-s1-07.md`: Lantern Guardian content and the integration in `Encounters/S1-07`.
4. `04-tempest-sentinel-and-storm-guardian.md`: **cut (pending the user)**, stub only.

01 can run in parallel with F8 and F9-01 once F5-04 is done.

## Cross-feature contracts

- Definitions (F12-01, `scripts/definitions/`): `BossDefinition` (`kind`, `display_name`, `score`, `entry_seconds`, `phases`, 2 or 3 of them), `BossPhaseDefinition` (`health`, `attack`, `transition_seconds`), `AttackDefinition` (`display_name`, `steps`, `reposition_seconds`), `AttackStepDefinition` (`pattern`, `anticipation_seconds`, `height_offset`, `follow_player_height`, `pause_after`).
- `BossMachine` (`scripts/enemies/boss_machine.gd`): `setup(definition, enemy_id, encounter_id, rng)`, `start()`, `tick(delta, origin, player_position) -> Array[ProjectileSpawn]`, `take_damage(amount) -> int`. Signals: `phase_changed(phase_index, attack_display_name)`, `phase_health_changed(phase_index, ratio)`, `step_started(step_index)`, `hostile_clear_requested()`, `defeated(enemy_id, encounter_id)` once.
- `BossController` (`scripts/enemies/boss_controller.gd`): `spawn_setup(definition: BossDefinition, enemy_id, encounter_id, rng, projectile_system, player, bounds)`. This is EnemyActor's signature except for the Definition type, so the Director keeps boss Definitions in their own `boss_definitions` export. Signals: `boss_started(display_name, phase_count)`, `phase_changed(phase_index, attack_display_name)`, `phase_health_changed(phase_index, ratio)`, `defeated(enemy_id, encounter_id)`, `threat_reported(side)`.
- StageDirector additions (F12-03): `boss_definitions: Dictionary[StringName, BossDefinition]`, signals `boss_started(display_name, phase_count)`, `boss_phase_changed(phase_index, attack_display_name)`, `boss_health_changed(phase_index, ratio)`, `boss_defeated(boss_id)`, and optional `defeat_presentation: AnimationPlayer` plus `defeat_animation: StringName`. `boss_defeated` is the hook for Astra's shrine lighting.
- HUD (F4-03, consumed only): `Hud.show_boss`, `set_phase_health`, `show_attack_cue`, `hide_boss`, `show_threat`.

## Done when

- All F12-01 to F12-03 tests pass. From CP1-B the player defeats the Lantern Guardian's three Phases, sees the panel and the three Attack names, and the stage clears once with 1,000 boss score.
- `docs/engineering/bosses.md` maps "excess damage cannot skip boss phases", "phase transitions clear previous threats" and "exactly-once defeat" to named tests; GUIDE Section 6 `boss_controller.gd` and Section 10 "Lantern Guardian" are updated.

## Out of scope

F12-04 (cut): the Tempest Sentinel, the Storm Guardian, and all Stage 2 gameplay integration. Also out: boss-arena retreat containment (an Astra request in the ROADMAP), Astra's `lantern_guardian.tscn` (the dev prefab stands in; swapping it in is a one-export change), boss music (F13, cut).
