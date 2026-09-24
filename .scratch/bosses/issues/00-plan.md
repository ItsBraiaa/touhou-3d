# F12-00 Plan the Bosses feature

Status: done (2026-09-23)
Type: docs
parallel-safe: no
Depends on: F9-02, F10-01; ticket 04 also depends on Astra's Stage 2 and boss scenes

## Goal

Write `.scratch/bosses/spec.md` and the full tickets for F12.

## Planned tickets

1. `01-boss-machine-core` (parallel-safe): `BossMachine`: Phases with their own health, excess damage never skips a Phase, Phase transition clears hostile Projectiles and announces the next Attack name, defeat exactly once, two-Phase and three-Phase configurations, `AttackDefinition` sequencing with the injected RNG.
2. `02-boss-controller-adapter`: `boss_controller.gd` on the boss root; runs Attacks through `PatternEmitter` from `Emitters/*`; animation cue hooks by actual clip names from `AnimationPlayer`; HUD boss panel API from F4-03; dev boss prefab under `scenes/dev/` until Astra's scenes arrive.
3. `03-lantern-guardian-in-s1-07`: content for Ritual das Lanternas, Fios de Luz, Dança do Crepúsculo; integration in `Encounters/S1-07` with `Wave1_Boss1`; boss completion from final Phase defeat, not the exit volume; defeat changes shrine lighting through a signal Astra's presentation can consume.
4. `04-tempest-sentinel-and-storm-guardian`: two-Phase Sentinel reusing the Sentry prefab; Storm Guardian's three Attacks; Stage 2 integration. Blocked until Stage 2 and the boss scenes exist; record the blocker rather than building placeholders for Stage 2 geometry.

## Read first when planning

- `docs/STAGE_DESIGN.md` both "Final boss sequence" sections and "Miniboss"
- `docs/PLANEJAMENTO.md` Section 4 "Bosses and named attacks"
- `docs/ENGINEERING_BRIEF.md` Section 4.F
- `docs/MODEL_SELECTION.md` (clip metadata), `docs/GUIDE.md` Section 5 "Enemy and boss prefabs", Section 6 row `boss_controller.gd`
- `docs/HANDOFF_LOG.md` and roadmap "Received from Astra" for boss scenes and Stage 2

## Definition of Done

- `spec.md` and four ticket files; roadmap rows replaced; commit `plan: write F12 bosses tickets`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/bosses/issues/00-plan.md, then write the F12 spec and tickets as described. Finish with its Definition of Done and commit.
```

## Outcome (2026-09-23)

The tickets and `spec.md` were written in the one-pass planning session (commit "plan: write F4-F14 tickets"), not in a session of their own: `01-boss-machine-core.md` (parallel-safe), `02-boss-controller-adapter.md`, `03-lantern-guardian-in-s1-07.md`, and `04-tempest-sentinel-and-storm-guardian.md` as a stub.

**F12-04 is cut, pending the user (2026-09-23).** It also carries all Stage 2 gameplay integration. Stage 2 has no content, and the Sentinel and Storm Guardian scenes do not exist. The stub records its scope, the consequences (Campaign final victory unreachable, F9-03 without a consumer, the Stage 2 duration check not verified), and what un-cuts it: the user's decision plus Astra's Stage 2 gameplay markers and boss scenes.

Deviations from the planned list above:

- 01 depends on F5-04 only. It owns four Definitions, adding `AttackStepDefinition`, because Attacks are ordered Pattern steps with their own Anticipation and height. The step signal is `step_started(step_index)`.
- 02 depends on F4-03 too, and proves the HUD panel payloads in its scene test. `spawn_setup` mirrors `EnemyActor`'s but takes a `BossDefinition`, so the Director gets a separate `boss_definitions` export in 03.
- 03 removes F10-01's Sentry stand-in for `lantern_guardian`. The shrine lighting hook is `StageDirector.boss_defeated` plus an optional Astra-authored `AnimationPlayer` clip.

**Reinstated (2026-09-23).** The product owner reinstated Stage 2 gameplay in a reduced but real form (`docs/engineering/SPRINT.md`), because the cut broke the assignment's five-minute stage requirement. The stub `04-tempest-sentinel-and-storm-guardian.md` is replaced by four tickets, and `spec.md` now covers F12-01 to F12-07:

- `04-stage-02-content-draft.md` (F12-04, glm-b, parallel-safe), which also carries the Stage 2 scene/content contract test;
- `05-stage-02-director-integration.md` (F12-05, sol): the Director, Gates, Checkpoints and Seals on `stage_02.tscn`, with Sentry stand-ins for both bosses;
- `06-tempest-sentinel-miniboss.md` (F12-06, sol), which also depends on F12-03 for `boss_definitions` and the HUD wiring, and on D-04;
- `07-storm-guardian.md` (F12-07, sol), which ends with Campaign victory through gameplay.

Astra's boss scenes are the design tickets D-03 (`lantern_guardian.tscn`, for F12-03) and D-04 (`tempest_sentinel.tscn` and `storm_guardian.tscn`, for F12-06 and F12-07) in `.scratch/design-sprint/issues/`.
