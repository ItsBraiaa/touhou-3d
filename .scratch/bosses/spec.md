# F12 Bosses and Stage 2 gameplay — spec

Status: ready-for-agent (F12-04 to F12-07 reinstated 2026-09-23, [SPRINT.md](../../docs/engineering/SPRINT.md))
Owner: Claude. The tickets run in the sprint lanes named in each ticket.
Source:
- STAGE_DESIGN.md:
  - Stage 1 "Final boss sequence";
  - the Stage 2 table, "Three-seal progression challenge", "Miniboss" and "Final boss sequence";
  - the "Checkpoint contract" and the acceptance checks.
- STAGE_02_HANDOFF.md.
- PLANEJAMENTO.md Section 4 "Bosses and named attacks" and "Graze and score", Section 6.
- ENGINEERING_BRIEF Section 4.F and Section 8.
- GUIDE.md Section 5 "Enemy and boss prefabs", Section 15 (boss panel).
- MODEL_SELECTION.md (models and clip names).

## Goal

**Both stages end with their real Boss.**

- Every Phase has its own health bar and a named Attack.
- Excess damage never carries into the next Phase.
- Each transition clears hostile Projectiles and briefly announces the next Attack in Portuguese.
- A Boss is defeated exactly once, and its Encounter completes from that defeat, never from its ExitVolume.
- The rules live in the Node-free `BossMachine`. `BossController` is the thin Adapter the Director spawns like any enemy.

**Stage 2 plays as a real route.**

- S2-01 to S2-07 in order, with Waves, five Gates, and CP2-A and CP2-B.
- The three-Seal challenge in any order, with passive Guard pairs.
- The two-Phase Sentinela da Tempestade in S2-04, and the three-Phase Guardião da Tempestade in S2-07.
- The Campaign's final victory, reached through gameplay.

This is the stage PLANEJAMENTO Section 2 uses for the five-minute rule.

## Tickets

| # | Ticket | Lane | Depends on |
| --- | --- | --- | --- |
| 1 | `01-boss-machine-core.md`: boss Definitions and `BossMachine` (parallel-safe) | glm-a | F5-04 |
| 2 | `02-boss-controller-adapter.md`: `BossController`, `scenes/dev/dev_boss.tscn` | sol | F12-01, F9-02, F4-03 |
| 3 | `03-lantern-guardian-in-s1-07.md`: Lantern Guardian content and S1-07 integration | trunk | F12-02, F10-03 |
| 4 | `04-stage-02-content-draft.md`: `content/stages/stage_02/`, plus the scene/content contract test (parallel-safe) | glm-b | F8-01, F9-01 |
| 5 | `05-stage-02-director-integration.md`: Director, Gates, Checkpoints and Seals on `stage_02.tscn`, with Sentry stand-ins for the bosses | sol | F10-03, F9-03, F12-04 |
| 6 | `06-tempest-sentinel-miniboss.md`: the Sentinel in S2-04 | sol | F12-05, F12-02, F12-03, D-04 |
| 7 | `07-storm-guardian.md`: the Storm Guardian in S2-07, and Campaign victory | sol | F12-06, D-04 |

Astra's scenes are in `.scratch/design-sprint/issues/`:
- D-03 `lantern_guardian.tscn`, consumed by F12-03.
- D-04 `tempest_sentinel.tscn` and `storm_guardian.tscn`, consumed by F12-06 and F12-07.

Neither D ticket attaches a script: the consumer does.

Ordering notes:
- F12-05 and F12-03 may run at the same time. Both edit `stage_director.gd`; the second to land merges both.
- F12-06 waits for F12-03's `boss_definitions` and the Session's boss wiring to the HUD.

## Cross-feature contracts

**Definitions** (F12-01, `scripts/definitions/`):
- `BossDefinition`: `kind`, `display_name`, `score`, `entry_seconds`, and `phases` (2 or 3).
- `BossPhaseDefinition`: `health`, `attack`, `transition_seconds`.
- `AttackDefinition`: `display_name`, `steps`, `reposition_seconds`.
- `AttackStepDefinition`: `pattern`, `anticipation_seconds`, `height_offset`, `follow_player_height`, `pause_after`.

**`BossMachine`** (`scripts/enemies/boss_machine.gd`):
- `setup(definition, enemy_id, encounter_id, rng)`, `start()`, `tick(delta, origin, player_position) -> Array[ProjectileSpawn]`, `take_damage(amount) -> int`.
- Signals: `phase_changed(phase_index, attack_display_name)`, `phase_health_changed(phase_index, ratio)`, `step_started(step_index)`, `hostile_clear_requested()`, and `defeated(enemy_id, encounter_id)` once.

**`BossController`** (`scripts/enemies/boss_controller.gd`):
- `spawn_setup(definition: BossDefinition, enemy_id, encounter_id, rng, projectile_system, player, bounds)`. It has EnemyActor's signature except for the Definition type.
- Exports: `visual_root`, `hit_volume`, `emitter`, `animation_player`, `idle_clip`, `step_clip`, `defeat_clip`.
- Signals: `boss_started(display_name, phase_count)`, `phase_changed`, `phase_health_changed`, `defeated`, `threat_reported(side)`.
- `get_score()`.

**StageDirector boss additions** (F12-03):
- `boss_definitions: Dictionary[StringName, BossDefinition]`.
- Signals `boss_started`, `boss_phase_changed`, `boss_health_changed` and `boss_defeated(boss_id)`.
- Optional `defeat_presentation: AnimationPlayer` plus `defeat_animation: StringName`, played on `boss_defeated`. This is the hook for Stage 1's shrine lighting and Stage 2's storm resolution.
- A kind listed in both `enemy_definitions` and `boss_definitions` is a setup error.

**Boss kinds**, used as wave kinds and as `boss_definitions` keys:
- `lantern_guardian`: `content/bosses/lantern_guardian.tres`, 1,000.
- `tempest_sentinel`: `tempest_sentinel.tres`, 500.
- `storm_guardian`: `storm_guardian.tres`, 1,000.

**Stage 2 content** (F12-04): `content/stages/stage_02/stage_02.tres`, `s2_01..s2_07.tres`, `cp2_a.tres`, `cp2_b.tres`.
- The objective ids are the Seals' `seal_id` values `S2-03-Seal1..3`.
- Each Seal's Power Pickup is a S2-03 reward whose `origin_marker` is `Seals/SealN/RewardOrigin`.
- The six Guards are three ON_ENTRY Waves `SealN_Sentry1..2`.

**StageDirector Stage 2 additions** (F12-05):
- Seals are found under `Encounters/<id>/Seals` of each OBJECTIVES Encounter.
- A per-Seal reward spawns when its Seal is destroyed.
- Guards are passive until `guards_activated`.
- Exports `portal_lights: Dictionary[StringName, NodePath]`, `resolved_light_material: Material`, and `activate_checkpoint_on_entry: bool` (true on Stage 2).

**`EnemyActor`** (F12-05): `set_engaged(engaged: bool)`, and `signal damaged(enemy_id: StringName)`.

**`Gate`** (F12-05): an optional `OpenVisual` child is shown while open.

**HUD** (F4-03, consumed only): `Hud.show_boss(display_name, phase_count)` hides `Phase3` for two Phases; also `set_phase_health`, `show_attack_cue`, `hide_boss`, `show_threat`. The Session wires the Director's boss signals to it once per stage load (F12-03), for both stages.

**Boss prefabs** (D-03, D-04):
- `scenes/enemies/<kind>.tscn` has an `Enemy` root, `VisualRoot`, `HitVolume` (layer 16 sphere) and `Emitters/Main`.
- Clip names arrive through the D-ticket handoff entry, together with a Phase-change clip that has no export yet (a future `phase_clip`).

## Done when

- All F12-01 to F12-07 tests pass, and `test_stage_02_content_contract.gd` keeps content and scene in agreement.
- From CP1-B the player defeats the Lantern Guardian's three Phases, sees the panel and the three Attack names, and Stage 1 clears once with 1,000 boss score.
- A Direct Stage 2 plays the whole route:
  - S2-01 to S2-03, with the Seals in any order;
  - CP2-A, then the Sentinel's two Phases, for 500 and a Shield Pickup;
  - S2-05 and CP2-B, then the Storm Guardian's three Phases, for 1,000;
  - one stage clear.
- A Campaign reaches `Jornada concluída` through gameplay.
- `docs/engineering/bosses.md` maps "excess damage cannot skip boss phases", "phase transitions clear previous threats" and "exactly-once defeat" to named tests. `stage-director.md` gains "Stage 2". The GUIDE Section 6 and Section 10 rows are updated.

## Out of scope

- Boss-arena retreat containment.
- The ring-shaped world cue before Círculos do Trovão: the Anticipation and `step_clip` stand in for it.
- Shrine-lighting and storm-resolution clips until Astra authors them. Each is then a one-export change.
- The final portal-light material: a dev one ships.
- Boss music (F13).
- The five-minute efficient-clear measurement, which is F11-03's protocol and the human pass. D-06 tunes toward it.
