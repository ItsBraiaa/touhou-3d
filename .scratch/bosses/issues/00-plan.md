# F12-00 Plan the Bosses feature

Status: todo
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
