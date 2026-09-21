# F1 Player flight — spec

Status: ready-for-agent
Owner: Claude
Source: GUIDE.md Section 13 "Next assignment for Claude"; ENGINEERING_BRIEF Section 4.B; PLANEJAMENTO Section 3.

## Goal

The player can fly the authored ship through `scenes/tests/combat_arena.tscn` on keyboard and gamepad: three-axis movement with bounded diagonal speed, Focus slowdown, camera-relative horizontal movement with world-vertical ascent and descent, a stable-horizon follow camera that orbits and frames a Target Lock, and target acquisition, switching, and release against the three static targets. Visual banking never moves the Core or the camera.

## Tickets

1. `01-flight-model-core.md` (parallel-safe)
2. `02-player-controller-adapter.md`
3. `03-camera-rig.md`
4. `04-target-selector-and-targeting.md`

## Done when

- All F1 tests pass; manual checklist in ticket 03 recorded in `docs/validation/player-flight.md` for keyboard and physical gamepad.
- GUIDE.md Section 13 "Authored player values" metadata rows are replaced by real exports and the registry rows for the three player scripts are complete.
- Weapon behavior is untouched (F6).

## Out of scope

Firing, damage, HUD target marker (F4-02), enemy targets (F9).
