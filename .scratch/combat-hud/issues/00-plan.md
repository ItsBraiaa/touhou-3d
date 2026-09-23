# F4-00 Plan the Combat state and HUD feature

Status: done (2026-09-23)
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

## Outcome (2026-09-23)

Tickets written in the one-pass planning session for F4 to F14 (commit `plan: write F4-F14 tickets`): `.scratch/combat-hud/spec.md`, `02-hud-binding-and-target-marker.md` and `03-boss-panel-and-attack-cue-api.md`. `01-combat-state-core.md` was written separately from its bullet above and delivered before this plan (commit `combat: add CombatState core`); it is not rewritten here, and 02, 03 and the spec use its real API (`start`, `HitOutcome`, `update_bomb_input`, the per-value change signals).

Deviations from the planned list:

- The `threat_reported(direction)` feed became `show_threat(side: int, seconds: float)` on `Hud` (side -1 left, +1 right); F9-02 produces `threat_reported(side)` and F10-01 routes it.
- 02 also gives `GameSession` its one `CombatState` for the Session's lifetime (not one per Run): `start()` at each stage entry, `set_paused()` with the tree, `get_combat_state()`.
- 03 adds a scripted dev harness, `scenes/dev/hud_harness.tscn`, for verification, because no boss exists yet.
