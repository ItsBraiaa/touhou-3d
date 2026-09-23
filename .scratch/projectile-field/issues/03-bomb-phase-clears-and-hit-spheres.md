# F5-03 Bomb and Phase clears, hit spheres

Status: todo
Type: core
parallel-safe: yes
Depends on: F5-02
Lane: path
Model: Claude Opus 5.5, 3-agent workflow (implementer, test-writer, reviewer)

## Goal

`ProjectileField` gains two capabilities. The first is the hostile clears the design asks for, which award nothing: a local clear around the player for a Bomb, and a full clear for when a Gate opens, before a Checkpoint activates, and between boss Phases. The second is the enemy side of collision: enemies register a hit sphere for the next tick, player Projectiles are swept against those spheres, and each contact is reported as `enemy_hit(target_id, projectile_id, damage)`. `targets_in_radius` lets the Bomb find the enemies inside its blast (F7-02). This ticket owns the ENGINEERING_BRIEF invariants "cleared bullets award no graze" and "a local bomb does not clear the entire stage".

## Read first

- `docs/adr/0004-central-projectile-field.md` ("test enemy hits against hit spheres the enemies register; apply cleanup in one place")
- `docs/PLANEJAMENTO.md` Section 4 "Spiritual bomb" (a spherical blast removes hostile bullets within its radius, and removed bullets award no Graze)
- `docs/STAGE_DESIGN.md` "Shared encounter rules" (clear remaining hostile bullets when a combat Gate opens, before a Checkpoint activates, and between boss Phases, with no Graze for cleared bullets; Bombs damage enemies normally)
- `docs/ENGINEERING_BRIEF.md` Section 4.D and Section 8
- `docs/engineering/CONVENTIONS.md` "Collision" (enemy adapters register a hit sphere every physics tick)
- `docs/engineering/projectile-field.md` (F5-01 and F5-02)

## Files

- **Creates:** nothing.
- **Edits:** `scripts/combat/projectile_field.gd` (the clears, the target registry, the target sweep, `enemy_hit`); `tests/unit/combat/test_projectile_field.gd` (new cases).
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F5-03 row), `docs/HANDOFF_LOG.md`, `docs/engineering/projectile-field.md` ("Clears" and "Hit spheres" sections and invariant rows).
- **Must not touch:** `scripts/combat/pattern_emitter.gd` and `scripts/definitions/pattern_definition.gd` (F5-04 may be running beside this ticket), `scripts/combat/combat_state.gd`, anything under `scenes/`.
- **Conflicts with:** F5-01 and F5-02 (the same two files; serialized by Depends on). Disjoint from F5-04.

## Deliverables

On `ProjectileField`:

- `clear_hostile_in_radius(center: Vector3, radius: float) -> int`: removes every HOSTILE Projectile whose sphere overlaps the blast (`distance <= radius + projectile radius`) and returns how many it removed. PLAYER Projectiles and hostile ones outside the blast are untouched. It emits no signal. A removed Projectile never grazes, including a Graze queued in the current pass if the clear is called from a listener.
- `clear_hostile_all() -> int`: the same with no radius limit, for Gates, Checkpoints and boss Phases.
- `register_target(target_id: int, center: Vector3, radius: float)`: a hit sphere valid for the next `tick` only. Registrations are consumed and emptied at the end of that tick, so a target that stops registering (defeated, freed) cannot be hit afterwards. Registering the same id twice before a tick keeps the last sphere. The id is the actor's `get_instance_id()`. The field never holds a Node.
- The target sweep is step 4 of the tick order, beside the Core sweep. It applies to PLAYER Projectiles only, and the target is treated as static during the tick. When the segment `from → to` touches a target sphere (`distance <= target radius + projectile radius`), the Projectile is removed and `enemy_hit(target_id, projectile_id, damage)` is queued for the target reached first along the segment, the smallest segment parameter, with ties going to the lower registration order. One Projectile hits at most one target. Hostile Projectiles never hit targets. The obstacle check still comes first (F5-01), so Aim Assist shots die on scenery for their whole travel (ADR-0004).
- `targets_in_radius(center: Vector3, radius: float) -> PackedInt64Array`: ids of the spheres registered for the coming tick that overlap the radius, in registration order. It reads the registry and changes nothing.
- The signal `enemy_hit(target_id: int, projectile_id: int, damage: int)` follows the events rule (emitted after the pass, in slot order).

## Tests required

In `tests/unit/combat/test_projectile_field.gd`:

- `test_local_clear_leaves_projectiles_outside_the_radius` (ENGINEERING_BRIEF 8: a local Bomb does not clear the entire stage)
- `test_local_clear_leaves_player_projectiles`
- `test_clears_return_how_many_they_removed`
- `test_cleared_projectiles_never_graze` (ENGINEERING_BRIEF 8: clear a Projectile that would have grazed next tick, then sweep; also a clear from a `player_hit` listener drops that tick's queued Graze of a cleared Projectile)
- `test_clear_hostile_all_removes_every_hostile_projectile_and_awards_nothing`
- `test_player_projectile_hits_a_registered_target`
- `test_fast_player_projectile_does_not_tunnel_through_a_target`
- `test_a_projectile_hits_only_the_nearest_target_along_its_path`
- `test_registration_lasts_one_tick` (no registration, no hit)
- `test_hostile_projectiles_never_hit_targets`
- `test_obstacle_before_a_target_blocks_the_shot`
- `test_targets_in_radius_lists_overlapping_registered_targets`

Grep the output for `SCRIPT ERROR`.

## Out of scope

- The Bomb itself: the input, the radius value, enemy damage and its visual (F6-03, F7-02).
- Enemy health and defeat (F9-01).
- Who calls `clear_hostile_all` and when (F10-01, F10-02, F12-02).
- Registering spheres from scene nodes (F6-02 `ProjectileSystem.register_target`, F6-03's dev target dummy, F9-02 `EnemyActor`).
- Moving-target sweeps. Targets are static for one tick, which is accurate enough at enemy speeds; this is recorded as an Open issue.

## Definition of Done

- `tools/test.ps1` is green with no `SCRIPT ERROR`, every test above exists, and there are no Error-level warnings.
- `docs/engineering/projectile-field.md` is updated with the clears, the registry lifetime, the sweep order and the invariant rows.
- A handoff log entry, ticket `Status: done` with an Outcome, and the roadmap row.
- One commit: `combat: add ProjectileField clears and hit spheres`.

## Handoff notes for Astra

None: this is code only. Each enemy's hit sphere is read from its `HitVolume` shape (layer 5, monitoring off) by its adapter, so the authored sphere is the hit area.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/projectile-field/issues/03-bomb-phase-clears-and-hit-spheres.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
