# Bosses validation

Engine: Godot 4.7.2.stable.official.ed1daf0bf, Windows 11, D3D12 Forward+, Jolt physics.
Contract in [engineering/bosses.md](../engineering/bosses.md). The boss scenes' own QA
(D-03, D-04) is in [boss-scenes.log](boss-scenes.log).

# BossController and the dev boss — 2026-09-23 (F12-02)

## Automated

`tools/test.ps1`: 225 passed, 0 failed, no `SCRIPT ERROR`. F12-02 adds no test file (the
sprint's no-new-tests rule of 2026-09-23); the ticket's seven named tests were replaced by
the scripted runs below.

## Scripted runs

Throwaway `SceneTree` scripts, deleted after use, drove `scenes/dev/arena_harness.tscn` with
`spawn_dev_boss` on, headless and then in a 1280 × 720 window. The `DevSpray` was stopped
and the dev Spirit and Sentry defeated first, so every hostile Projectile came from the
boss. No `SCRIPT ERROR` line. The only `ERROR:` lines were the expected `spawn_setup`
refusals and the Lantern Guardian content failure below.

| Check | Result |
| --- | --- |
| Prefab tree | `Enemy` root is `BossController`; `VisualRoot` (sphere and halo), `HitVolume` (`Area3D`, layer 16, mask 0, monitoring and monitorable off, `SphereShape3D` radius 2.5), `Emitters/Main`; no `AnimationPlayer` |
| Dev Definition | `scenes/dev/dev_boss_definition.tres` validates; `metadata/dev = true`, `"Guardião (dev)"`, three Phases of 40 |
| Start | Spawned at `EnemySpawns/DevBoss` (0, 13, −26), in `targetable`. HUD `BossStatus` visible with `BossName` "Guardião (dev)", three bars, `AttackName` "Anel de Teste" |
| Signal order | A second boss with a recorder: `boss_started("Guardião (dev)", 3)`, then `phase_changed(0, "Anel de Teste")` |
| First attack | Entry 1 s + Anticipation 1 s: 15 hostile Projectiles (18-shot ring, 60° gap) at 2.2 s |
| Locked fire, real weapon | Boss locked at 44.6 units, `fire` held: Phase 1 bar 100 → 92.5 in 60 ticks; in the windowed run Phase 2 fell to 0.55 in 130 ticks |
| Phase 1 depleted | Hostile Projectiles 28 → 0 in the same call; one `phase_changed(1, "Leque de Teste")`; HUD Phase 1 at 0 and dimmed, cue "Leque de Teste" |
| Transition | 5 damage one tick into the 0.75 s transition: Phase 2 stayed full; 5 damage 61 ticks later: accepted |
| Phase 3 | `phase_changed(2, "Chuva de Teste")`; its aimed step follows the ship's height |
| Defeat | Two overkills in one tick: one `defeated(&"dev_boss_1", &"arena")`, out of `targetable`, queued for deletion at once (no `defeat_clip`), hostile count 0, HUD boss panel hidden; readout `boss defeated` |
| Clips checked by name | An `AnimationPlayer` holding only `Flying_Idle` and a 0.5 s `Death`, with `step_clip` `Punch` and `phase_clip` `Yes`: one `push_warning` each for `Punch` and `Yes`, then skipped; `Flying_Idle` playing after spawn; on defeat `Death` played and the boss stayed until it ended, freed after 0.5 s |
| Refused setup | `spawn_setup(null, &"", &"", null, null, null, AABB())` returned false with one error per argument; the boss stayed inert and out of `targetable` |
| Astra's Lantern Guardian scene | `scenes/enemies/lantern_guardian.tscn` with `boss_controller.gd` attached at runtime and the exports set as F12-03 will set them (`VisualRoot`, `HitVolume`, `Emitters/Main`, `VisualRoot/Model/AnimationPlayer`, clips `Flying_Idle`, `Punch`, `Yes`, `Death`): no clip warning, `boss_started` and Phase 0, 30 hostile Projectiles after 2.5 s. Driven with the dev Definition, because the real one does not load (next row) |
| `content/bosses/lantern_guardian.tres` (F12-03 part 1, not this ticket) | **Does not load:** `Parse Error` at line 14, where `Phase_Ritual` references `SubResource("Attack_Ritual")` before that sub-resource is declared. Reported to the orchestrator for trunk's F12-03 part 2 |

![Dev boss at the Phase 2 transition](bosses-dev-boss.png)

`bosses-dev-boss.png`: the dev boss locked at 44.5 units, 20 ticks after Phase 1 was
depleted. Hostile count 0 (the clear), the boss panel with Phase 1 empty and dimmed and
Phases 2 and 3 full, the cue "Leque de Teste", and the readout's `boss phase 2 of 3`.

## Not verified here

- The Session and Director wiring (F12-03), score awarding and S1-07.
- A physical keyboard or controller pass (owed by the human pass).
