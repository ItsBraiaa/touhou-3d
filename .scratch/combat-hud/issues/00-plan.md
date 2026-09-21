# F4-00 Plan the Combat state and HUD feature

Status: todo
Type: docs
parallel-safe: no
Depends on: F2-04 (F3 may run in parallel)

## Goal

Write `.scratch/combat-hud/spec.md` and the full tickets for F4.

## Planned tickets

1. `01-combat-state-core` (parallel-safe): `CombatState` Rules Core: Health 0 to 100, one-charge Shield, Invulnerability window, two Bombs, Power Level 1 to 3 with Power Progress (5 per level), excess pickups award score, defeat exactly once, `capture()`/`restore()`. Invariants from ENGINEERING_BRIEF Section 4.C and Section 8: shielded hit never damages Health; Invulnerability rejects follow-up hits; Power never decreases on damage; Bombs cannot activate while paused or defeated; one press consumes one Bomb.
2. `02-hud-binding-and-target-marker`: `hud.gd` observes `CombatState` signals and renders the GUIDE Section 15 paths; target marker projected from `Targeting.target_changed` and hidden when behind the camera; nothing in the HUD mutates state.
3. `03-boss-panel-and-attack-cue-api`: `show_boss(name, phase_count)`, `set_phase_health(index, ratio)`, `show_attack_cue(text, seconds)`, `hide_boss()`; two-phase layout for the Tempest Sentinel; threat indicators left and right fed by a `threat_reported(direction)` signal to be produced in F9.

## Read first when planning

- `docs/GUIDE.md` Section 15, Section 7 rows "Combat state changed", "Boss phase changed", "Target changed"
- `docs/PLANEJAMENTO.md` Section 4 and Section 7 "HUD"
- `docs/ENGINEERING_BRIEF.md` Sections 4.C, 4.I, 8
- `CONTEXT.md` Combat and Player terms

## Definition of Done

- `spec.md` and three ticket files exist; roadmap rows replaced; commit `plan: write F4 combat and HUD tickets`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/combat-hud/issues/00-plan.md, then write the F4 spec and tickets as described. Finish with its Definition of Done and commit.
```
