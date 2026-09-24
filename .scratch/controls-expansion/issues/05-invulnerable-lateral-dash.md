# F16-05 invulnerable-lateral-dash

Status: todo
Type: core+adapter
Owner: Claude
Lane: trunk
Depends on: F16-03
Parallel-safe: no

## Read first

- [Spec](../spec.md): product rules, exact widget paths, data shapes and proposed APIs.
- [Execution plan](../../../docs/engineering/controls-expansion-plan.md): ownership, task steps and review focus.
- docs/engineering/SPRINT.md in the worktree: no-new-tests rule and lane loop.

## Goal

Ship short collision-aware lateral bursts protected through the existing CombatState/ProjectileSystem pipeline.

## Files

- scripts/player/dash_model.gd (new)
- scripts/player/player_controller.gd
- scripts/combat/combat_state.gd
- scripts/session/game_session.gd (dash wiring/lifecycle only)
- scripts/combat/projectile_system.gd (only if needed for proven activation ordering; no new hit/Graze rules)
- scripts/ui/hud.gd
- scenes/ui/hud.tscn (cooldown component wiring)
- scenes/player/player_ship.tscn (numeric dash exports and visual component wiring)
- docs/engineering/player-flight.md (F16 dash section)
- docs/engineering/combat-hud.md (protection/cooldown contract)
- docs/validation/controls-expansion.md (dash observations)

Also update this ticket's Outcome, only its own docs/engineering/ROADMAP.md row, and append a newest-first docs/HANDOFF_LOG.md entry. New production scripts/assets include their generated .uid/.import sidecars. No files outside this boundary without first coordinating the owner and recording the expansion.

## Work

- [ ] Implement DashModel configure/request/timers and PlayerController's direction snapshot/replacement velocity; stop on obstruction without tangent slide or teleport.
- [ ] Use 3.0 units /0.15 s, 0.8 s shared cooldown from activation, one press, opposite simultaneous rejection and no Focus scaling.
- [ ] Add max-duration CombatState grant and synchronous Session dash_started connection. Verify actual Session/player/field ordering before claiming activation safety.
- [ ] Instance and drive Astra's dash and cooldown components in trunk-owned scenes; keep Core/Graze geometry and existing longer protection intact.
- [ ] Freeze all timing on Pause; cancel and reset transient movement/cooldown/protection across the documented lifecycle.

## Manual acceptance / existing gate

- Measure unobstructed 3-unit travel and 0.15-second duration; wall/Gate/edge attempts cannot tunnel or slide.
- Cross hostile fire with/without Shield: protected window loses neither resource and awards no Graze.
- Activate during Bomb/hit protection and end the dash: longer protection remains, no false vulnerability signal.
- Hold/spam/opposite inputs; cooldown is shared and no press queues; pause freezes timers.
- Retry/Restart/defeat/unload produce no residual movement, VFX or double signal connections.

Write no new tests or disposable test drivers. Run the existing tools/lane.ps1 land gate after the scoped commit. A static/headless result does not certify physical device feel. Failures belong in Outcome and the handoff; never bypass the gate.

## Outcome

Not started. Do not edit CameraRig while path is implementing F16-04. Any unproven first/last protection tick is a blocker, not a visual-only issue.
